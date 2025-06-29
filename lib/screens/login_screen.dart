// lib/screens/login_screen.dart (최종 수정본)
import 'package:flutter/material.dart';
import 'calendar_screen.dart';
import '../services/auth_service.dart';
import '../services/tts_service.dart'; // TtsService 임포트
import '../managers/theme_manager.dart'; // ThemeManager 임포트

class LoginScreen extends StatefulWidget {
  // 상위 위젯(main.dart)으로부터 TtsService를 전달받기 위한 변수
  final TtsService ttsService;

  // 생성자에서 ttsService를 필수로 받도록 변경
  const LoginScreen({super.key, required this.ttsService});

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
            PageRouteBuilder(
              // RefactoredCalendarScreen으로 ttsService 인스턴스를 전달
              pageBuilder: (context, animation, secondaryAnimation) =>
                  RefactoredCalendarScreen(ttsService: widget.ttsService),
              transitionsBuilder: (context, animation, secondaryAnimation, child) {
                return FadeTransition(opacity: animation, child: child);
              },
              transitionDuration: const Duration(milliseconds: 300),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('로그인이 취소되었거나 실패했습니다'))
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('로그인 오류: $e'))
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ThemeManager.getLoginScreenBackgroundColor(), // ☑️ _HE_250623_로그인 화면 전용 배경색
      body: LayoutBuilder(
        builder: (context, constraints) {
          return Container(
            width: constraints.maxWidth,
            height: constraints.maxHeight,
            color: ThemeManager.getLoginScreenBackgroundColor(), // ☑️ _HE_250623_로그인 화면 전용 배경색
            child: Center(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 240,
                      height: 240,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: ColorFiltered( // ☑️ _HE_250623_로그인 화면 다크 모드 적용 관련련
                          colorFilter: ThemeManager.isDarkMode
                              ? const ColorFilter.mode(
                                  Color(0xFFBBBBBB), // ☑️ 다크 모드에서 밝은 회색
                                  BlendMode.srcIn,
                                )
                              : const ColorFilter.mode(
                                  Colors.transparent,
                                  BlendMode.multiply,
                                ),
                          child: Image.asset(
                            'assets/images/amatta_transparent.png',
                            width: 240,
                            height: 240,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Your Memory Assistant',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: ThemeManager.getTextColor(),
                      ),
                    ),
                    const SizedBox(height: 40),
                    SizedBox(
                      width: 280,
                      height: 50,
                      child: _isLoading
                          ? Center(
                              child: CircularProgressIndicator(
                                color: ThemeManager.getTextColor(), // ☑️ _HE_250623_로그인 화면 다크 모드 적용 관련 추가 
                              ),
                            )
                          : OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                // side: const BorderSide(color: Colors.grey),
                                side: BorderSide(color: ThemeManager.getPopupBorderColor()),
                                shape: const RoundedRectangleBorder(
                                  borderRadius: BorderRadius.zero,
                                ),
                                backgroundColor: ThemeManager.getCardColor(), //_HE_250623_로그인 화면 다크 모드 적용 관련 추가 
                              ),
                              onPressed: _handleGoogleSignIn,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8.0),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(4.0),
                                    ),
                                    child: Image.asset(
                                      'assets/images/google_login.png',
                                      height: 24,
                                      width: 24,
                                      fit: BoxFit.contain,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    'Google로 로그인',
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: ThemeManager.getTextColor(), // ☑️ _HE_250623_로그인 화면 다크 모드 적용 관련 추가 
                                    ),
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
