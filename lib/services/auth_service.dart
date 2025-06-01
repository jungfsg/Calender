import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  // 서버 URL (chat_service.dart와 동일하게 맞추는 것이 좋습니다)
  final String baseUrl = 'https://c1b4-218-158-75-120.ngrok-free.app';

  // GoogleSignIn 설정을 명시적으로 구성
  final GoogleSignIn _googleSignIn = GoogleSignIn(scopes: ['email', 'profile']);
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // 토큰 저장 키
  static const String _tokenKey = 'auth_token';
  static const String _userIdKey = 'user_id';

  // Google 로그인 메서드 (개선된 버전)
  Future<bool> signInWithGoogle() async {
    try {
      print('Google 로그인 시작...');

      // Google 로그인 다이얼로그 표시
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        print('사용자가 로그인을 취소했습니다.');
        return false;
      }

      print('Google 계정 선택 완료: ${googleUser.email}');

      // 인증 세부 정보 가져오기
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      print('Google 인증 토큰 획득 완료');
      print('Access Token 존재: ${googleAuth.accessToken != null}');
      print('ID Token 존재: ${googleAuth.idToken != null}');

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      print('Firebase 인증 시작...');

      // Firebase에 로그인
      final UserCredential userCredential = await _auth.signInWithCredential(
        credential,
      );
      final User? user = userCredential.user;

      if (user != null) {
        print('Firebase 로그인 성공: ${user.email}');

        // Firebase 토큰을 직접 사용
        final String? token = await user.getIdToken();
        final String userId = user.uid;

        print('Firebase 토큰 획득: ${token != null}');

        // token이 null이 아닌 경우에만 저장
        if (token != null) {
          // 토큰과 사용자 ID 저장
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(_tokenKey, token);
          await prefs.setString(_userIdKey, userId);

          print('로그인 성공 및 토큰 저장 완료');
          return true;
        } else {
          print('Firebase 토큰을 가져올 수 없습니다.');
          return false;
        }
      } else {
        print('Firebase 사용자 정보를 가져올 수 없습니다.');
        return false;
      }
    } catch (e) {
      print('Google 로그인 중 상세 오류: $e');
      print('오류 타입: ${e.runtimeType}');
      if (e is FirebaseAuthException) {
        print('Firebase 오류 코드: ${e.code}');
        print('Firebase 오류 메시지: ${e.message}');
      }
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
        final String? token = data['token']?.toString();
        final String? userId = data['user_id']?.toString();

        if (token != null && userId != null) {
          // 토큰과 사용자 ID 저장
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(_tokenKey, token);
          await prefs.setString(_userIdKey, userId);

          return true;
        } else {
          return false;
        }
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
