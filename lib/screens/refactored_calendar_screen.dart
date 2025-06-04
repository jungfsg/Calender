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

  @override
  void initState() {
    super.initState();

    // 앱 생명주기 관찰자 등록
    WidgetsBinding.instance.addObserver(this);

    // 컴포넌트 초기화
    _initializeComponents();

    // 위젯 빌드 후에 앱 초기화
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _initializeApp();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _popupManager.dispose();
    super.dispose();
  }

  /// 컴포넌트 초기화
  void _initializeComponents() {
    _controller = CalendarController();
    _eventManager = EventManager(_controller);
    _popupManager = PopupManager(_controller, _eventManager);
  }

  /// 앱 초기화
  Future<void> _initializeApp() async {
    try {
      print('🚀 앱 초기화 시작...');

      // 1. 권한 요청
      await _requestPermissions();

      // 2. STT 초기화
      await _popupManager.initializeSpeech();

      // 3. 초기 데이터 로드
      await _loadInitialData(); // 4. 날씨 정보 로드
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

  /// 권한 요청
  Future<void> _requestPermissions() async {
    try {
      // 위치 권한 요청
      await WeatherService.checkLocationPermission();

      // 마이크 권한 요청
      final microphoneStatus = await Permission.microphone.request();
      if (microphoneStatus != PermissionStatus.granted) {
        print('⚠️ 마이크 권한이 거부되었습니다. 음성 기능을 사용할 수 없습니다.');
      }

      print('✅ 권한 요청 완료');
    } catch (e) {
      print('❌ 권한 요청 중 오류: $e');
    }
  }

  /// 초기 데이터 로드
  Future<void> _loadInitialData() async {
    try {
      print('📥 초기 데이터 로드 시작...');

      // Google Calendar 자동 연결 시도
      await _tryAutoConnectGoogleCalendar();

      // 이벤트 데이터 로드
      await _eventManager.loadInitialData();

      print('✅ 초기 데이터 로드 완료');
    } catch (e) {
      print('❌ 초기 데이터 로드 중 오류: $e');
    }
  }

  /// Google Calendar 자동 연결 시도
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

  /// 로그아웃 처리
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

  /// 스낵바 표시
  void _showSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), duration: const Duration(seconds: 3)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // 초기화가 완료되지 않은 경우 로딩 화면 표시
    if (!_isInitialized) {
      return Scaffold(
        backgroundColor: const Color.fromARGB(255, 162, 222, 141),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
              SizedBox(height: 16),
              Text(
                '캘린더를 초기화하고 있습니다...',
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
            ],
          ),
        ),
      );
    } // 메인 캘린더 위젯 표시
    return CalendarWidget(
      controller: _controller,
      eventManager: _eventManager,
      popupManager: _popupManager,
      onLogout: _handleLogout,
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    switch (state) {
      case AppLifecycleState.resumed:
        print('📱 앱이 활성화됨');
        // 필요시 데이터 새로고침
        break;
      case AppLifecycleState.paused:
        print('📱 앱이 일시정지됨');
        break;
      case AppLifecycleState.detached:
        print('📱 앱이 종료됨');
        break;
      case AppLifecycleState.inactive:
        print('📱 앱이 비활성화됨');
        break;
      case AppLifecycleState.hidden:
        print('📱 앱이 숨겨짐');
        break;
    }
  }
}
