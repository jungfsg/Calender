import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter_chat_types/flutter_chat_types.dart' as types;
import 'package:uuid/uuid.dart';
import 'weather_service.dart';
import 'event_storage_service.dart';
import '../models/event.dart';

class ChatService {
  // 서버 URL을 적절히 변경해야 합니다
  final String baseUrl = 'https://efb3-59-17-140-26.ngrok-free.app';
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
  Future<types.TextMessage> sendMessage(
    String text, 
    String userId, {
    Function()? onCalendarUpdate, // 캘린더 업데이트 콜백 추가
  }) async {
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
        Uri.parse('$baseUrl/api/v1/calendar/ai-chat'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('🔍 백엔드 응답 전체 데이터:');
        print(data);
        print('🔍 응답 키들: ${data.keys.toList()}');
        
        final botMessage = data['response'] as String;
        
        // 일정 추가 관련 응답인지 확인하고 로컬 캘린더에 저장
        final calendarUpdated = await _handleCalendarResponse(data);
        
        // 캘린더가 업데이트되었으면 콜백 호출
        if (calendarUpdated && onCalendarUpdate != null) {
          onCalendarUpdate();
        }

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

  // 캘린더 관련 응답 처리
  Future<bool> _handleCalendarResponse(Map<String, dynamic> data) async {
    try {
      print('=== 캘린더 응답 처리 시작 ===');
      print('받은 데이터: $data');
      
      final intent = data['intent'] as String?;
      final extractedInfo = data['extracted_info'] as Map<String, dynamic>?;
      final calendarResult = data['calendar_result'] as Map<String, dynamic>?;

      print('Intent: $intent');
      print('ExtractedInfo: $extractedInfo');
      print('CalendarResult: $calendarResult');

      // 일정 추가가 성공한 경우
      if (intent == 'calendar_add' && 
          calendarResult != null && 
          calendarResult['success'] == true && 
          extractedInfo != null) {
        
        print('일정 추가 조건 만족! 이벤트 생성 시작...');
        
        // 추출된 정보로 Event 객체 생성
        final title = extractedInfo['title'] as String? ?? '새 일정';
        final startDate = extractedInfo['start_date'] as String?;
        final startTime = extractedInfo['start_time'] as String?;
        final description = extractedInfo['description'] as String? ?? '';

        print('Title: $title');
        print('StartDate: $startDate');
        print('StartTime: $startTime');
        print('Description: $description');

        if (startDate != null) {
          try {
            // 날짜 파싱
            final eventDate = DateTime.parse(startDate);
            final eventTime = startTime ?? '10:00';

            print('파싱된 날짜: $eventDate');
            print('파싱된 시간: $eventTime');

            // Event 객체 생성
            final event = Event(
              title: title,
              time: eventTime,
              date: eventDate,
              description: description,
            );

            print('생성된 Event 객체: ${event.toJson()}');

            // 로컬 캘린더에 이벤트 저장
            await EventStorageService.addEvent(eventDate, event);
            print('✅ AI 채팅으로 추가된 일정이 로컬 캘린더에 저장되었습니다: $title');
            print('저장된 날짜: $eventDate');
            
            // 저장 후 확인
            final savedEvents = await EventStorageService.getEvents(eventDate);
            print('저장 후 확인 - 해당 날짜의 이벤트들: ${savedEvents.map((e) => e.toJson()).toList()}');
            
            return true; // 캘린더가 업데이트되었음을 반환
            
          } catch (e) {
            print('❌ 날짜 파싱 오류: $e');
          }
        } else {
          print('❌ startDate가 null입니다');
        }
      } else {
        print('일정 추가 조건 불만족:');
        print('- Intent == calendar_add: ${intent == 'calendar_add'}');
        print('- CalendarResult != null: ${calendarResult != null}');
        print('- CalendarResult[success] == true: ${calendarResult?['success'] == true}');
        print('- ExtractedInfo != null: ${extractedInfo != null}');
      }
      
      print('=== 캘린더 응답 처리 종료 ===');
      return false; // 캘린더 업데이트 없음
    } catch (e) {
      print('❌ 캘린더 응답 처리 중 오류: $e');
      return false;
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
