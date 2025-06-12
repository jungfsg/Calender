import 'package:flutter/material.dart';
import 'dart:async';
import 'package:permission_handler/permission_handler.dart';

import '../controllers/calendar_controller.dart';
import '../managers/event_manager.dart';
import '../managers/popup_manager.dart';
import '../widgets/calendar_widget.dart';
import '../services/auth_service.dart';
import '../services/weather_service.dart';
import 'login_screen.dart';
import '../services/tts_service.dart'; // TTS 서비스 임포트

/// 리팩토링된 캘린더 스크린 - Provider 없이 구성
class RefactoredCalendarScreen extends StatefulWidget {
  const RefactoredCalendarScreen({super.key});

  @override
  State<RefactoredCalendarScreen> createState() =>
      _RefactoredCalendarScreenState();
}

class _RefactoredCalendarScreenState extends State<RefactoredCalendarScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  // 핵심 컴포넌트들
  late CalendarController _controller;
  late EventManager _eventManager;
  late PopupManager _popupManager;

  // 서비스
  final AuthService _authService = AuthService();

  // 초기화 상태
  bool _isInitialized = false;

  // --- TTS 상태 변수 추가 ---
  bool _isTtsEnabled = false; // TTS 기본값은 '비활성화'

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeComponents();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _initializeApp();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _initializeComponents() {
    _controller = CalendarController();
    _eventManager = EventManager(_controller);
    _popupManager = PopupManager(_controller, _eventManager);
  }

  Future<void> _initializeApp() async {
    try {
      print('🚀 앱 초기화 시작...');
      await _requestPermissions();
      await _loadInitialData();
      await WeatherService.loadCalendarWeather(_controller);
      setState(() {
        _isInitialized = true;
      });
      print('✅ 앱 초기화 완료');
    } catch (e) {
      print('❌ 앱 초기화 중 오류: $e');
      _showSnackBar('앱 초기화 중 오류가 발생했습니다: $e');
    }
  }

  Future<void> _requestPermissions() async {
    try {
      await WeatherService.checkLocationPermission();
      final microphoneStatus = await Permission.microphone.request();
      if (microphoneStatus != PermissionStatus.granted) {
        print('⚠️ 마이크 권한이 거부되었습니다. 음성 기능을 사용할 수 없습니다.');
      }
      print('✅ 권한 요청 완료');
    } catch (e) {
      print('❌ 권한 요청 중 오류: $e');
    }
  }

  Future<void> _loadInitialData() async {
    try {
      print('📥 초기 데이터 로드 시작...');
      await _eventManager.loadInitialData();
      await _tryAutoConnectGoogleCalendar();
      print('✅ 초기 데이터 로드 완료');
    } catch (e) {
      print('❌ 초기 데이터 로드 중 오류: $e');
    }
  }

  Future<void> _tryAutoConnectGoogleCalendar() async {
    try {
      print('🔄 Google Calendar 자동 연결 시도...');
      await _eventManager.syncWithGoogleCalendar();
      _showSnackBar('Google Calendar가 자동으로 연결되었습니다! 📅');
      print('✅ Google Calendar 자동 연결 성공');
    } catch (e) {
      print('ℹ️ Google Calendar 자동 연결 실패 - 로컬 데이터만 사용: $e');
    }
  }

  Future<void> _handleLogout() async {
    try {
      await _authService.logout();
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const LoginScreen()),
        );
      }
    } catch (e) {
      _showSnackBar('로그아웃 중 오류가 발생했습니다: $e');
    }
  }

  /// 사이드 메뉴에서 TTS 스위치를 토글할 때 호출될 함수
  void _handleTtsToggle(bool isEnabled) {
    print("📢 TTS 스위치 변경: $isEnabled"); // 디버깅 로그
    // TtsService 싱글톤 인스턴스에 변경된 상태를 직접 전달합니다.
    TtsService.instance.setTtsEnabled(isEnabled);

    // UI 상태 업데이트
    setState(() {
      _isTtsEnabled = isEnabled;
    });

    _showSnackBar('AI 음성(TTS)이 ${isEnabled ? '활성화되었습니다' : '비활성화되었습니다'}.');
  }

  void _showSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), duration: const Duration(seconds: 3)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget mainCalendarWidget = CalendarWidget(
      controller: _controller,
      eventManager: _eventManager,
      popupManager: _popupManager,
      onLogout: _handleLogout,
      isTtsEnabled: _isTtsEnabled,
      onTtsToggle: _handleTtsToggle,
    );

    if (!_isInitialized) {
      return Stack(
        children: [
          mainCalendarWidget,
          Container(
            color: Colors.black38,
            child: const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                  SizedBox(height: 16),
                  Text(
                    '앱을 준비하는 중...',
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }
    return mainCalendarWidget;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // ... 기존 생명주기 코드는 동일 ...
  }
}
