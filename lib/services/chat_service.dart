import 'dart:convert';
import 'package:http/http.dart' as http;

class ChatService {
  // 서버 URL을 적절히 변경해야 합니다
  final String baseUrl = 'http://localhost:8000';

  // LLM 서버에 메시지를 보내고 응답을 받는 메서드
  Future<String> sendMessage(String text, String userId) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/chat'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'message': text, 'user_id': userId}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['response'] as String;
      } else {
        throw Exception('메시지 전송 실패: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('서버 통신 중 오류 발생: $e');
    }
  }
}
