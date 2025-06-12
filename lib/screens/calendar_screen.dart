// lib/screens/calendar_screen.dart (최종 수정본)
import 'package:flutter/material.dart';
import 'dart:async';
import 'package:permission_handler/permission_handler.dart';
import '../managers/event_manager.dart';
import '../services/tts_service.dart';
import '../controllers/calendar_controller.dart';
import '../managers/popup_manager.dart';
import '../widgets/calendar_widget.dart';
import '../services/auth_service.dart';
import '../services/weather_service.dart';
import 'login_screen.dart';

class RefactoredCalendarScreen extends StatefulWidget {
  // 상위 위젯으로부터 TtsService를 전달받기 위한 변수
  final TtsService ttsService;

  // 생성자에서 TtsService를 필수로 받도록 변경
  const RefactoredCalendarScreen({super.key, required this.ttsService});

  @override
  State<RefactoredCalendarScreen> createState() =>
      _RefactoredCalendarScreenState();
}

class _RefactoredCalendarScreenState extends State<RefactoredCalendarScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  late CalendarController _controller;
  late EventManager _eventManager;
  late PopupManager _popupManager;
  final AuthService _authService = AuthService();
  bool _isInitialized = false;

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
    // EventManager 생성 시 TtsService 인스턴스 전달
    _eventManager = EventManager(_controller, ttsService: widget.ttsService);
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
        // 로그아웃 후 LoginScreen으로 이동 시 TtsService 인스턴스 전달
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => LoginScreen(ttsService: widget.ttsService)),
        );
      }
    } catch (e) {
      _showSnackBar('로그아웃 중 오류가 발생했습니다: $e');
    }
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
    // CalendarWidget으로 ttsService 전달
    Widget mainCalendarWidget = CalendarWidget(
      controller: _controller,
      eventManager: _eventManager,
      popupManager: _popupManager,
      onLogout: _handleLogout,
      ttsService: widget.ttsService,
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
  }
}
