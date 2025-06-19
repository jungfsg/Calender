// lib/main.dart (TtsService 생성자 오류 수정)
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:calander/services/tts_service.dart';
import 'package:calander/services/notification_service.dart';
import 'package:calander/services/daily_briefing_service.dart';
import 'firebase_options.dart';
import 'screens/login_screen.dart';
import 'screens/briefing_settings_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  try {
    await NotificationService.initialize();
    await NotificationService.requestPermissions();
    print('✅ 알림 서비스 초기화 완료');
  } catch (e) {
    print('⚠️ 알림 서비스 초기화 실패: $e');
  }

  try {
    await DailyBriefingService.updateBriefings();
    print('✅ 브리핑 서비스 초기화 완료');
  } catch (e) {
    print('⚠️ 브리핑 서비스 초기화 실패: $e');
  }

  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  // TtsService 인스턴스 생성 방법 수정
  final TtsService ttsService = TtsService.instance;

  MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    if (state == AppLifecycleState.resumed) {
      _updateBriefingsOnResume();
    }
  }

  void _updateBriefingsOnResume() async {
    try {
      await DailyBriefingService.updateBriefings();
      print('✅ 앱 재개 시 브리핑 업데이트 완료');
    } catch (e) {
      print('⚠️ 앱 재개 시 브리핑 업데이트 실패: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Calender vs2500604',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: LoginScreen(ttsService: widget.ttsService),
      routes: {
        '/briefing_settings': (context) => const BriefingSettingsScreen(),
      },
      debugShowCheckedModeBanner: false,
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(1.0)),
          child: child!,
        );
      },
    );
  }
}
