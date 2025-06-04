import 'package:flutter/material.dart';
import 'refactored_calendar_screen.dart';
import '../services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final AuthService _authService = AuthService();
  bool _isLoading = false;

  void _handleGoogleSignIn() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final success = await _authService.signInWithGoogle();

      if (mounted) {
        setState(() {
          _isLoading = false;
        });

        if (success) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => const RefactoredCalendarScreen(),
            ),
          );
        } else {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('로그인이 취소되었거나 실패했습니다')));
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });

        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('로그인 오류: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('로그인')),
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
                    // Amatta 아이콘 이미지 (그림자 효과 제거)
                    Container(
                      width: 240, // 고정 너비
                      height: 240, // 고정 높이
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12), // 모서리 둥글게
                        // boxShadow 제거하여 그림자 효과 삭제
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.asset(
                          'assets/images/amatta_transparent.png',
                          width: 240,
                          height: 240,
                          fit: BoxFit.cover, // 이미지가 컨테이너에 맞게 조정
                        ),
                      ),
                    ),
                    const SizedBox(height: 20), // 고정 간격
                    // 고정 크기 텍스트
                    const Text(
                      // 'A.M.A.T.T.A.\n– Your Memory Assistant',
                      '– Your Memory Assistant',
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
                      child:
                          _isLoading
                              ? const Center(child: CircularProgressIndicator())
                              : OutlinedButton(
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
                                        borderRadius: BorderRadius.circular(
                                          4.0,
                                        ),
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
