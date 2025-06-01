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
  final String baseUrl = 'https://c1b4-218-158-75-120.ngrok-free.app';
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
            print(
              '저장 후 확인 - 해당 날짜의 이벤트들: ${savedEvents.map((e) => e.toJson()).toList()}',
            );

            return true; // 캘린더가 업데이트되었음을 반환
          } catch (e) {
            print('❌ 날짜 파싱 오류: $e');
          }
        } else {
          print('❌ startDate가 null입니다');
        }
      }
      // 일정 삭제가 성공한 경우
      else if (intent == 'calendar_delete' &&
          calendarResult != null &&
          calendarResult['success'] == true &&
          extractedInfo != null) {
        print('🗑️ 일정 삭제 조건 만족! 이벤트 삭제 시작...');

        // 추출된 정보로 삭제할 이벤트 찾기
        final title = extractedInfo['title'] as String? ?? '';
        final startDate = extractedInfo['start_date'] as String?;
        final startTime = extractedInfo['start_time'] as String?;

        print('🔍 삭제할 Title: $title');
        print('🔍 삭제할 StartDate: $startDate');
        print('🔍 삭제할 StartTime: $startTime');

        if (startDate != null) {
          try {
            // 날짜 파싱
            final eventDate = DateTime.parse(startDate);
            print('📅 파싱된 삭제 날짜: $eventDate');

            // 해당 날짜의 모든 이벤트 가져오기
            final existingEvents = await EventStorageService.getEvents(
              eventDate,
            );
            print('📋 해당 날짜의 기존 이벤트들 (${existingEvents.length}개):');
            for (int i = 0; i < existingEvents.length; i++) {
              print('  $i: ${existingEvents[i].toJson()}');
            }

            // 삭제할 이벤트 찾기 (제목으로 검색)
            Event? eventToDelete;
            print('🔍 삭제할 이벤트 검색 중...');
            for (int i = 0; i < existingEvents.length; i++) {
              var event = existingEvents[i];
              print('  검색 $i: "${event.title}" vs "$title"');

              bool titleMatch = false;
              if (title.isNotEmpty) {
                titleMatch =
                    event.title.toLowerCase().contains(title.toLowerCase()) ||
                    title.toLowerCase().contains(event.title.toLowerCase());
                print('    제목 일치: $titleMatch');
              }

              // 제목이 일치하면 시간에 상관없이 삭제 (시간 정보가 부정확할 수 있음)
              if (titleMatch) {
                eventToDelete = event;
                print('✅ 삭제할 이벤트 찾음 (제목 기준): ${event.toJson()}');
                break;
              }
            }

            if (eventToDelete != null) {
              print('🗑️ 이벤트 삭제 실행 중...');
              // 로컬 캘린더에서 이벤트 삭제
              await EventStorageService.removeEvent(eventDate, eventToDelete);
              print(
                '✅ AI 채팅으로 요청된 일정이 로컬 캘린더에서 삭제되었습니다: ${eventToDelete.title}',
              );
              print('📅 삭제된 날짜: $eventDate');

              // 삭제 후 확인
              final remainingEvents = await EventStorageService.getEvents(
                eventDate,
              );
              print('🔍 삭제 후 확인 - 남은 이벤트들 (${remainingEvents.length}개):');
              for (int i = 0; i < remainingEvents.length; i++) {
                print('  $i: ${remainingEvents[i].toJson()}');
              }

              return true; // 캘린더가 업데이트되었음을 반환
            } else {
              print('❌ 삭제할 이벤트를 찾을 수 없습니다.');
              print('   검색한 제목: "$title"');
              print('   검색한 날짜: $eventDate');
              print('   검색한 시간: $startTime');
            }
          } catch (e) {
            print('❌ 일정 삭제 중 날짜 파싱 오류: $e');
          }
        } else {
          print('❌ 삭제할 일정의 startDate가 null입니다');
        }
      }
      // 일정 작업 조건 불만족
      else {
        print('일정 작업 조건 불만족:');
        print('- Intent: $intent');
        print('- Intent == calendar_add: ${intent == 'calendar_add'}');
        print('- Intent == calendar_delete: ${intent == 'calendar_delete'}');
        print('- CalendarResult != null: ${calendarResult != null}');
        print(
          '- CalendarResult[success] == true: ${calendarResult?['success'] == true}',
        );
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
