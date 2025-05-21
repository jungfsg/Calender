import 'package:flutter/material.dart';
import 'calendar_screen.dart';
import '../services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  void _handleGoogleSignIn() async {
  final user = await AuthService().signInWithGoogle();
  if (user != null) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => const PixelArtCalendarScreen(),
      ),
    );
  } else {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('로그인이 취소되었습니다')),
    );
  }
}


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('로그인'),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          return Container(
            width: constraints.maxWidth,
            height: constraints.maxHeight,
            color: Colors.white,
            child: Center(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // 고정 크기 아이콘
                    const Icon(
                      Icons.calendar_month,
                      size: 80, // 고정 크기
                      color: Colors.blue,
                    ),
                    const SizedBox(height: 20), // 고정 간격
                    // 고정 크기 텍스트
                    const Text(
                      '퀵 캘린더',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 24, // 고정 크기
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 40), // 고정 간격
                    // 고정 너비 버튼
                    SizedBox(
                      width: 280, // 고정된 버튼 너비
                      height: 50, // 고정된 버튼 높이
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.grey),
                        ),
                        onPressed: _handleGoogleSignIn,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // 구글 로고 이미지 - 고정 크기
                            Container(
                              padding: const EdgeInsets.all(8.0),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(4.0),
                              ),
                              child: Image.asset(
                                'assets/images/google_login.png',
                                height: 24, // 고정 크기
                                width: 24, // 고정 크기
                                fit: BoxFit.contain,
                              ),
                            ),
                            const SizedBox(width: 10), // 고정 간격
                            // 고정 크기 텍스트
                            const Text(
                              'Google로 로그인',
                              style: TextStyle(fontSize: 16), // 고정 크기
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
} 