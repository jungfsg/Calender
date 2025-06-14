// lib/main.dart (최종 수정본 - TtsService 생성 및 전달)
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:calander/services/tts_service.dart'; // --- ★★★ 추가: TtsService 임포트 ★★★ ---
import 'firebase_options.dart';
import 'screens/login_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  // --- ★★★ 추가: 앱 전체에서 공유할 TtsService 인스턴스 생성 ★★★ ---
  final TtsService ttsService = TtsService();

  // --- ★★★ 수정: const 생성자 제거 ★★★ ---
  MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Calender vs2500604',
      theme: ThemeData(primarySwatch: Colors.blue),
      // --- ★★★ 수정: LoginScreen에 생성한 ttsService 인스턴스를 전달 ★★★ ---
      home: LoginScreen(ttsService: ttsService),
      debugShowCheckedModeBanner: false,
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(1.0)),
          child: child!,
        );
      },
    );
  }
}
