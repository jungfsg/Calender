// lib/main.dart (TtsService 생성자 오류 수정)
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:calander/services/tts_service.dart';
import 'package:calander/services/notification_service.dart';
import 'package:calander/services/daily_briefing_service.dart';
import 'firebase_options.dart';
import 'screens/login_screen.dart';
import 'screens/briefing_settings_screen.dart';
//☑️ 테마 관리
import 'managers/theme_manager.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // .env 파일 로드
  await dotenv.load(fileName: ".env");

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

  
//☑️ 테마 초기화 추가
  await ThemeManager.init();

  runApp(MyApp());
}

// ☑️ 테마관련 추가 코드(ㅇ)
class MyApp extends StatefulWidget {
  final TtsService ttsService = TtsService.instance;

  MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {

  // ☑️ 테마 새로고침을 위한 키
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
  
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
      navigatorKey: navigatorKey,
      title: 'Calender vs2500604',
      // ☑️ 간단한 테마 설정
      theme: ThemeData(
        brightness: ThemeManager.isDarkMode ? Brightness.dark : Brightness.light,
        primarySwatch: Colors.blue,
        scaffoldBackgroundColor: ThemeManager.getBackgroundColor(),
        cardColor: ThemeManager.getCardColor(),
        textTheme: Theme.of(context).textTheme.apply(
          bodyColor: ThemeManager.getTextColor(),
          displayColor: ThemeManager.getTextColor(),
        ),
      ),
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
  
  // ☑️ 앱 전체 새로고침 메서드
  static void refreshApp() {
    navigatorKey.currentState?.pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => MyApp()),
      (route) => false,
    );
  }
} 



// ☑️ 이전 코드(x)
// class MyApp extends StatelessWidget {
//   // --- ★★★ 추가: 앱 전체에서 공유할 TtsService 인스턴스 생성 ★★★ ---
//   final TtsService ttsService = TtsService();

//   // --- ★★★ 수정: const 생성자 제거 ★★★ ---
//   MyApp({super.key});

//   @override
//   Widget build(BuildContext context) {
//     return MaterialApp(
//       title: 'Calender vs2500604',
//       theme: ThemeData(primarySwatch: Colors.blue),
//       // --- ★★★ 수정: LoginScreen에 생성한 ttsService 인스턴스를 전달 ★★★ ---
//       home: LoginScreen(ttsService: ttsService),
//       debugShowCheckedModeBanner: false,
//       builder: (context, child) {
//         return MediaQuery(
//           data: MediaQuery.of(
//             context,
//           ).copyWith(textScaler: TextScaler.linear(1.0)),
//           child: child!,
//         );
//       },
//     );
//   }
// }
