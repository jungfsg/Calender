import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  // 서버 URL (chat_service.dart와 동일하게 맞추는 것이 좋습니다)
  final String baseUrl = 'https://847e-218-158-75-120.ngrok-free.app';

  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // 토큰 저장 키
  static const String _tokenKey = 'auth_token';
  static const String _userIdKey = 'user_id';

  // Google 로그인 메서드
  Future<bool> signInWithGoogle() async {
    try {
      // Google 로그인 다이얼로그 표시
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        return false; // 사용자가 로그인을 취소함
      }

      // 인증 세부 정보 가져오기
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Firebase에 로그인
      final UserCredential userCredential = await _auth.signInWithCredential(
        credential,
      );
      final User? user = userCredential.user;

      if (user != null) {
        // 서버에 토큰 검증 요청
        final response = await http.post(
          Uri.parse('$baseUrl/api/v1/auth/google'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'id_token': googleAuth.idToken}),
        );

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final token = data['token'];
          final userId = data['user_id'] ?? user.uid;

          // 토큰과 사용자 ID 저장
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(_tokenKey, token);
          await prefs.setString(_userIdKey, userId);

          return true;
        }
      }
      return false;
    } catch (e) {
      print('Google 로그인 중 오류 발생: $e');
      return false;
    }
  }

  // 로그인 메서드
  Future<bool> login(String username, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/v1/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'username': username, 'password': password}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final token = data['token'];
        final userId = data['user_id'];

        // 토큰과 사용자 ID 저장
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_tokenKey, token);
        await prefs.setString(_userIdKey, userId);

        return true;
      } else {
        return false;
      }
    } catch (e) {
      print('로그인 중 오류 발생: $e');
      return false;
    }
  }

  // 로그아웃 메서드
  Future<void> logout() async {
    try {
      // Google 로그아웃
      await _googleSignIn.signOut();
      // Firebase 로그아웃
      await _auth.signOut();

      // 로컬 데이터 삭제
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_tokenKey);
      await prefs.remove(_userIdKey);
    } catch (e) {
      print('로그아웃 중 오류 발생: $e');
    }
  }

  // 토큰 가져오기
  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  // 사용자 ID 가져오기
  Future<String?> getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_userIdKey);
  }

  // 인증 여부 확인
  Future<bool> isAuthenticated() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }
}

// test
