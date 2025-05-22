import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter_chat_types/flutter_chat_types.dart' as types;
import 'package:uuid/uuid.dart';
import 'weather_service.dart';

class ChatService {
  // 서버 URL을 적절히 변경해야 합니다
  final String baseUrl = 'https://847e-218-158-75-120.ngrok-free.app';
  final Uuid _uuid = Uuid();

  // 날씨 관련 키워드 목록
  final List<String> _weatherKeywords = [
    '날씨',
    '기온',
    '비',
    '눈',
    '맑음',
    '흐림',
    '예보',
    '오늘 날씨',
    '내일 날씨',
    '이번 주 날씨',
    '주간 날씨',
    '기후',
    '강수',
    '습도',
    '바람',
    '온도',
  ];

  // LLM 서버에 메시지를 보내고 응답을 받는 메서드
  Future<types.TextMessage> sendMessage(String text, String userId) async {
    try {
      // 날씨 관련 질문인지 확인
      Map<String, dynamic> requestBody = {
        'message': text,
        'session_id': userId,
      };

      // 날씨 관련 질문이면 날씨 데이터 추가
      if (_isWeatherRelatedQuestion(text)) {
        try {
          final weatherData = await WeatherService.get5DayForecast();
          requestBody['weather_context'] =
              weatherData
                  .map(
                    (w) => {
                      'date': w.date,
                      'condition': w.condition,
                      'temperature': w.temperature,
                      'lat': w.lat,
                      'lon': w.lon,
                    },
                  )
                  .toList();
        } catch (weatherError) {
          print('날씨 데이터 가져오기 실패: $weatherError');
          // 날씨 데이터 가져오기 실패해도 계속 진행
        }
      }

      final response = await http.post(
        Uri.parse('$baseUrl/api/v1/calendar/chat'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final botMessage = data['response'] as String;

        // 봇 메시지 생성
        return types.TextMessage(
          author: types.User(id: 'bot'),
          id: _uuid.v4(),
          text: botMessage,
          createdAt: DateTime.now().millisecondsSinceEpoch,
        );
      } else {
        throw Exception('메시지 전송 실패: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('서버 통신 중 오류 발생: $e');
    }
  }

  // 날씨 관련 질문인지 확인하는 메서드
  bool _isWeatherRelatedQuestion(String text) {
    return _weatherKeywords.any((keyword) => text.contains(keyword));
  }

  // 이미지를 서버에 전송하는 메서드
  Future<types.TextMessage> sendImage(File image, String userId) async {
    try {
      // 멀티파트 요청 생성
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/upload-image'),
      );

      // 파일 추가
      request.files.add(await http.MultipartFile.fromPath('image', image.path));

      // 사용자 ID 추가
      request.fields['user_id'] = userId;

      // 요청 전송
      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final botMessage = data['response'] as String;

        // 봇 메시지 생성
        return types.TextMessage(
          author: types.User(id: 'bot'),
          id: _uuid.v4(),
          text: botMessage,
          createdAt: DateTime.now().millisecondsSinceEpoch,
        );
      } else {
        throw Exception('이미지 전송 실패: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('서버 통신 중 오류 발생: $e');
    }
  }

  // OCR로 추출한 텍스트를 서버에 저장하는 메소드
  Future<void> storeOcrText(
    String text, {
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/v1/calendar/ocr_text'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'text': text,
          'metadata':
              metadata ??
              {'source': 'ocr', 'timestamp': DateTime.now().toIso8601String()},
        }),
      );

      if (response.statusCode != 200) {
        throw Exception('OCR 텍스트 저장 실패: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('OCR 텍스트 저장 중 오류 발생: $e');
    }
  }
}
