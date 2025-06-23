import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_chat_types/flutter_chat_types.dart' as types;
import 'package:uuid/uuid.dart';
import 'event_storage_service.dart';
import '../models/event.dart';
import '../managers/event_manager.dart';

class ChatService {
  // 서버 URL을 적절히 변경해야 합니다

  final String baseUrl = 'https://5bf4-121-184-19-8.ngrok-free.app';

  final Uuid _uuid = const Uuid();

  // 카테고리 매핑 (LLM이 반환할 수 있는 카테고리 ID들)
  static const Map<int, String> _categoryNames = {
    1: '업무',
    2: '집안일',
    3: '기념일',
    4: '학교',
    5: '운동',
    6: '공부',
    7: '여행',
    8: '기타',
    9: '친구',
    10: '가족',
    11: '병원',
  };

  // 🚀 성능 최적화: 카테고리 분류 캐시
  static final Map<String, int> _categoryCache = {};
  static const int _maxCacheSize = 100; // 최대 캐시 크기

  // 🚀 성능 최적화: 카테고리 분류 캐시 관리
  static void _manageCacheSize() {
    if (_categoryCache.length > _maxCacheSize) {
      // 캐시 크기가 초과되면 첫 번째 항목들 제거 (LRU 방식)
      final keysToRemove = _categoryCache.keys.take(
        _categoryCache.length - _maxCacheSize + 10,
      );
      for (var key in keysToRemove) {
        _categoryCache.remove(key);
      }
      print('🗑️ 카테고리 캐시 정리 완료 (현재 크기: ${_categoryCache.length})');
    }
  }

  // LLM을 통한 카테고리 분류 함수 (캐싱 최적화)
  Future<int> _getCategoryFromLLM(String title) async {
    final cacheKey = title.toLowerCase().trim();

    // 🚀 캐시에서 먼저 확인
    if (_categoryCache.containsKey(cacheKey)) {
      final cachedCategory = _categoryCache[cacheKey]!;
      print(
        '⚡ 카테고리 캐시 히트: "$title" -> $cachedCategory (${_categoryNames[cachedCategory]})',
      );
      return cachedCategory;
    }

    try {
      print('🎯 LLM 카테고리 분류 요청: "$title"');

      final requestBody = {'title': title, 'categories': _categoryNames};

      final response = await http.post(
        Uri.parse('$baseUrl/api/v1/calendar/categorize'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final categoryId = data['category_id'] as int?;

        print('🎯 LLM 카테고리 분류 결과: $categoryId (${_categoryNames[categoryId]})');

        // 유효한 카테고리 ID인지 확인
        if (categoryId != null && _categoryNames.containsKey(categoryId)) {
          // 🚀 캐시에 저장
          _categoryCache[cacheKey] = categoryId;
          _manageCacheSize();
          print('💾 카테고리 캐시 저장: "$title" -> $categoryId');
          return categoryId;
        }
      } else {
        print('❌ HTTP 오류: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ LLM 카테고리 분류 실패: $e');
    }

    // 실패 시 폴백 함수 사용
    print('⚠️ LLM 카테고리 분류 실패 - 폴백 함수 사용');
    final fallbackCategory = _getFallbackCategoryFromText(title);

    // 🚀 폴백 결과도 캐시에 저장 (빠른 재사용을 위해)
    _categoryCache[cacheKey] = fallbackCategory;
    _manageCacheSize();

    print(
      '🔄 폴백 카테고리 결과: $fallbackCategory (${_categoryNames[fallbackCategory]})',
    );
    return fallbackCategory;
  }

  // 폴백용 간단한 카테고리 분류 함수 (LLM 실패 시 사용)
  static int _getFallbackCategoryFromText(String text) {
    final originalText = text;
    text = text.toLowerCase();

    print('🔍 폴백 카테고리 분류 시작: "$originalText" -> "$text"');

    // 핵심 키워드로만 간단하게 분류
    if (text.contains('회의') ||
        text.contains('업무') ||
        text.contains('미팅') ||
        text.contains('회사')) {
      print('✅ 폴백: 업무 카테고리(1) 매칭');
      return 1;
    }
    if (text.contains('청소') ||
        text.contains('빨래') ||
        text.contains('요리') ||
        text.contains('집안일')) {
      print('✅ 폴백: 집안일 카테고리(2) 매칭');
      return 2;
    }
    if (text.contains('생일') ||
        text.contains('기념일') ||
        text.contains('결혼') ||
        text.contains('축하')) {
      print('✅ 폴백: 기념일 카테고리(3) 매칭');
      return 3;
    }
    if (text.contains('수업') ||
        text.contains('강의') ||
        text.contains('시험') ||
        text.contains('학교')) {
      print('✅ 폴백: 학교 카테고리(4) 매칭');
      return 4;
    }
    if (text.contains('운동') ||
        text.contains('헬스') ||
        text.contains('피트니스') ||
        text.contains('요가')) {
      print('✅ 폴백: 운동 카테고리(5) 매칭');
      return 5;
    }
    if (text.contains('공부') ||
        text.contains('학습') ||
        text.contains('스터디') ||
        text.contains('독서')) {
      print('✅ 폴백: 공부 카테고리(6) 매칭');
      return 6;
    }
    if (text.contains('여행') ||
        text.contains('휴가') ||
        text.contains('관광') ||
        text.contains('호텔')) {
      print('✅ 폴백: 여행 카테고리(7) 매칭');
      return 7;
    }
    if (text.contains('친구') ||
        text.contains('만남') ||
        text.contains('약속') ||
        text.contains('술자리')) {
      print('✅ 폴백: 친구 카테고리(9) 매칭');
      return 9;
    }
    if (text.contains('가족') ||
        text.contains('부모') ||
        text.contains('엄마') ||
        text.contains('아빠')) {
      print('✅ 폴백: 가족 카테고리(10) 매칭');
      return 10;
    }
    if (text.contains('병원') ||
        text.contains('의원') ||
        text.contains('검진') ||
        text.contains('진료')) {
      print('✅ 폴백: 병원 카테고리(11) 매칭');
      return 11;
    }

    print('⚠️ 폴백: 매칭되는 키워드 없음 - 기타 카테고리(8) 사용');
    return 8; // 기타
  }

  // 날씨 관련 키워드 목록// LLM 서버에 메시지를 보내고 응답을 받는 메서드
  Future<types.TextMessage> sendMessage(
    String text,
    String userId, {
    Function()? onCalendarUpdate, // 캘린더 업데이트 콜백 추가
    EventManager? eventManager, // EventManager 추가
  }) async {
    print('📨 ChatService: sendMessage 호출됨');
    print('   메시지: "$text"');
    print('   userId: $userId');
    print('   eventManager 존재: ${eventManager != null}');

    try {
      Map<String, dynamic> requestBody = {
        'message': text,
        'session_id': userId,
      };

      // 일정 조회 관련 질문이면 캘린더 데이터 추가
      if (_isCalendarQueryQuestion(text)) {
        try {
          final calendarData = await _getCalendarDataForAI();
          requestBody['calendar_context'] = calendarData;
          print('🗓️ 캘린더 컨텍스트 추가: ${calendarData.length}개 이벤트');
        } catch (calendarError) {
          print('캘린더 데이터 가져오기 실패: $calendarError');
          // 캘린더 데이터 가져오기 실패해도 계속 진행
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

        final botMessage =
            data['response'] as String; // 일정 추가/수정/삭제 관련 응답인지 확인하고 로컬 캘린더에 저장
        final calendarUpdated = await _handleCalendarResponse(
          data,
          onCalendarUpdate: onCalendarUpdate,
          eventManager: eventManager,
        );

        // 일정 조회인 경우 로컬에서 직접 조회해서 응답 생성
        final intent = data['intent'] as String?;
        final extractedInfo = data['extracted_info'] as Map<String, dynamic>?;
        final calendarResult = data['calendar_result'] as Map<String, dynamic>?;

        String finalMessage = botMessage;

        // 삭제 의도인 경우 실제 삭제 결과에 따른 메시지 처리
        if (intent == 'calendar_delete' &&
            calendarResult != null &&
            calendarResult['success'] == true &&
            extractedInfo != null) {
          print('🔄 일정 삭제 인텐트 감지 - 실제 삭제 결과 확인');

          if (!calendarUpdated) {
            // 실제로는 삭제되지 않았으면 적절한 메시지로 대체
            print('❌ 실제 삭제 실패 - 메시지 수정');
            finalMessage =
                '😔 죄송합니다. 요청하신 일정을 찾을 수 없어 삭제할 수 없습니다.\n\n삭제하려는 일정의 제목이나 날짜를 다시 확인해 주세요.';
          } else {
            print('✅ 실제 삭제 성공 - 백엔드 응답 사용');
          }
        } // 일정 조회인 경우 캘린더 업데이트 플래그를 별도로 관리
        bool isQueryOperation = false;

        if ((intent == 'calendar_query' || intent == 'calendar_search') &&
            extractedInfo != null) {
          print('🔄 일정 조회 인텐트 감지 - 로컬에서 직접 조회');
          isQueryOperation = true; // 조회 작업임을 표시

          final queryDate = extractedInfo['start_date'] as String?;
          final queryDateEnd = extractedInfo['end_date'] as String?;

          if (queryDate != null) {
            try {
              final startDate = DateTime.parse(queryDate);
              final endDate =
                  queryDateEnd != null
                      ? DateTime.parse(queryDateEnd)
                      : startDate;

              final eventsMap = await _getEventsInDateRange(
                startDate,
                endDate,
                eventManager,
              );

              if (eventsMap.isNotEmpty) {
                final formattedSchedule = _formatScheduleForUser(
                  eventsMap,
                  startDate,
                  endDate,
                );
                finalMessage = formattedSchedule; // 백엔드 응답 대신 우리가 생성한 일정 브리핑 사용
                print('✅ 로컬 일정 조회 성공 - 일정 브리핑으로 응답 대체');
              } else {
                final dayOfWeek =
                    ['일', '월', '화', '수', '목', '금', '토'][startDate.weekday % 7];
                finalMessage =
                    '📅 ${startDate.month}월 ${startDate.day}일 ($dayOfWeek)에는 등록된 일정이 없습니다.';
                print('📭 해당 날짜에 일정 없음 - 빈 일정 메시지로 응답');
              }
            } catch (e) {
              print('❌ 로컬 일정 조회 실패: $e');
              // 오류 시 백엔드 응답 그대로 사용
            }
          }
        }

        // 캘린더가 업데이트되었고 조회 작업이 아닌 경우에만 콜백 호출
        if (calendarUpdated && !isQueryOperation && onCalendarUpdate != null) {
          onCalendarUpdate();
        }

        // 봇 메시지 생성
        return types.TextMessage(
          author: types.User(id: 'bot'),
          id: _uuid.v4(),
          text: finalMessage,
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
  Future<bool> _handleCalendarResponse(
    Map<String, dynamic> data, {
    Function()? onCalendarUpdate,
    EventManager? eventManager,
  }) async {
    try {
      print('=== 캘린더 응답 처리 시작 ===');
      print('받은 데이터: $data');

      final intent = data['intent'] as String?;
      final extractedInfo = data['extracted_info'] as Map<String, dynamic>?;
      final calendarResult = data['calendar_result'] as Map<String, dynamic>?;

      print('Intent: $intent');
      print('ExtractedInfo: $extractedInfo');
      print('CalendarResult: $calendarResult'); // 일정 추가가 성공한 경우
      if (intent == 'calendar_add' &&
          calendarResult != null &&
          calendarResult['success'] == true &&
          extractedInfo != null) {
        print('일정 추가 조건 만족! 이벤트 생성 시작...');

        // Multi Day Event 처리 확인
        final isMultiDay = extractedInfo['is_multi_day'] as bool? ?? false;
        final isMultiple = extractedInfo['is_multiple'] as bool? ?? false;

        if (isMultiDay) {
          // Multi Day Event 처리
          print('📅 Multi Day Event 처리 시작...');
          final events = extractedInfo['events'] as List<dynamic>? ?? [];

          if (events.isNotEmpty) {
            final eventData = events[0] as Map<String, dynamic>;
            final title = eventData['title'] as String? ?? '새 일정';
            final startDate = eventData['start_date'] as String?;
            final endDate = eventData['end_date'] as String?;
            final startTime = eventData['start_time'] as String?;
            final endTime = eventData['end_time'] as String?;
            final description = eventData['description'] as String? ?? '';

            print('Multi Day Event 데이터:');
            print('  Title: $title');
            print('  StartDate: $startDate');
            print('  EndDate: $endDate');
            print('  StartTime: $startTime');
            print('  EndTime: $endTime');
            print('  Description: $description');

            if (startDate != null && endDate != null) {
              try {
                final parsedStartDate = DateTime.parse(startDate);
                final parsedEndDate = DateTime.parse(
                  endDate,
                ); // 🚀 성능 최적화: 폴백 우선 사용 후 LLM 카테고리 분류
                int categoryColorId = _getFallbackCategoryFromText(title);
                String colorId = categoryColorId.toString();
                print(
                  '🎨 Multi Day Event 폴백 카테고리 사용: $colorId (${_categoryNames[categoryColorId]}, 제목: $title)',
                );

                // 백그라운드에서 LLM 카테고리 분류 실행 (UI 블로킹 방지)
                _getCategoryFromLLM(title)
                    .then((llmCategoryId) {
                      if (llmCategoryId != categoryColorId) {
                        print(
                          '💡 LLM 카테고리 분류 완료 (다음에 적용): $llmCategoryId (${_categoryNames[llmCategoryId]})',
                        );
                      }
                    })
                    .catchError((e) {
                      print('❌ 백그라운드 LLM 카테고리 분류 실패: $e');
                    });

                // Multi Day Event 객체 생성
                final event = Event.multiDay(
                  title: title,
                  startDate: parsedStartDate,
                  endDate: parsedEndDate,
                  description: description,
                  colorId: colorId,
                );

                print('생성된 Multi Day Event 객체: ${event.toJson()}');

                // EventManager가 전달되었다면 이벤트 매니저를 통해 추가
                if (eventManager != null) {
                  print(
                    '🔄 ChatService: EventManager의 addEvent로 Multi Day Event 추가 중',
                  );
                  await eventManager.addEvent(event, syncWithGoogle: true);
                  print('✅ AI 채팅으로 추가된 Multi Day Event가 저장되었습니다: $title');
                } else {
                  print('⚠️ EventManager가 없어 Multi Day Event를 추가할 수 없습니다');
                }

                return true;
              } catch (e) {
                print('❌ Multi Day Event 추가 오류: $e');
                return false;
              }
            }
          }
        } else if (isMultiple) {
          // 다중 일정 처리
          print('📋 다중 일정 처리 시작...');
          final events = extractedInfo['events'] as List<dynamic>? ?? [];
          int addedCount = 0;

          for (int i = 0; i < events.length; i++) {
            final eventData = events[i] as Map<String, dynamic>;
            final title = eventData['title'] as String? ?? '새 일정 ${i + 1}';
            final startDate = eventData['start_date'] as String?;
            final startTime = eventData['start_time'] as String?;
            final endTime = eventData['end_time'] as String?; // 종료 시간 추가
            final description = eventData['description'] as String? ?? '';

            print('다중 일정 ${i + 1}: $title, $startDate, $startTime, $endTime');

            if (startDate != null) {
              try {
                // 날짜 파싱
                final eventDate = DateTime.parse(startDate);
                final eventTime =
                    (startTime == null || startTime.isEmpty)
                        ? '종일'
                        : startTime; // 시간이 없으면 '종일'로 처리

                // 중복 체크
                final existingEvents = await EventStorageService.getEvents(
                  eventDate,
                );
                final isDuplicate = existingEvents.any(
                  (e) =>
                      e.title.trim().toLowerCase() ==
                          title.trim().toLowerCase() &&
                      e.time == eventTime &&
                      e.date.year == eventDate.year &&
                      e.date.month == eventDate.month &&
                      e.date.day == eventDate.day,
                );

                if (isDuplicate) {
                  print(
                    '🚫 다중 일정 ${i + 1}: 중복된 일정이므로 추가하지 않음: $title ($eventTime)',
                  );
                  continue; // 다음 일정으로 건너뛰기
                } // 🚀 성능 최적화: 폴백 우선 사용 후 LLM 카테고리 분류
                int categoryColorId = _getFallbackCategoryFromText(title);
                String colorId = categoryColorId.toString();
                print(
                  '🎨 다중 일정 폴백 카테고리 사용: $colorId (${_categoryNames[categoryColorId]}, 제목: $title)',
                );

                // 백그라운드에서 LLM 카테고리 분류 실행 (UI 블로킹 방지)
                _getCategoryFromLLM(title)
                    .then((llmCategoryId) {
                      if (llmCategoryId != categoryColorId) {
                        print(
                          '💡 LLM 카테고리 분류 완료 (다음에 적용): $llmCategoryId (${_categoryNames[llmCategoryId]})',
                        );
                      }
                    })
                    .catchError((e) {
                      print('❌ 백그라운드 LLM 카테고리 분류 실패: $e');
                    });

                // Event 객체 생성
                final event = Event(
                  title: title,
                  time: eventTime,
                  endTime: endTime, // 종료 시간 추가
                  date: eventDate,
                  description: description,
                  source: 'local', // 로컬에서 생성된 이벤트
                  colorId: colorId, // 카테고리 기반 colorId 사용
                );

                print('생성된 Event 객체: ${event.toJson()}');

                // EventManager가 전달되었다면 이벤트 매니저를 통해 추가 (Google 동기화 포함)
                if (eventManager != null) {
                  print(
                    '🔄 ChatService: EventManager의 addEvent로 일정 추가 중 (Google 동기화 포함)',
                  );
                  await eventManager.addEvent(event, syncWithGoogle: true);
                  print('✅ AI 채팅으로 추가된 일정이 로컬 및 Google 캘린더에 저장되었습니다: $title');
                } else {
                  // EventManager가 없는 경우 폴백: 로컬 저장소에만 저장
                  print('⚠️ EventManager가 없어 로컬에만 저장합니다');
                  await EventStorageService.addEvent(eventDate, event);
                  print('✅ AI 채팅으로 추가된 일정이 로컬 캘린더에만 저장되었습니다: $title');
                }
                addedCount++;
              } catch (e) {
                print('❌ 다중 일정 ${i + 1} 추가 오류: $e');
              }
            }
          }

          print('📊 다중 일정 처리 완료: $addedCount/${events.length}개 추가');
          return addedCount > 0; // 하나라도 추가되었으면 true
        } else {
          // 단일 일정 처리 (기존 로직)
          final title = extractedInfo['title'] as String? ?? '새 일정';
          final startDate = extractedInfo['start_date'] as String?;
          final startTime = extractedInfo['start_time'] as String?;
          final endTime = extractedInfo['end_time'] as String?; // 종료 시간 추가
          final description = extractedInfo['description'] as String? ?? '';

          print('Title: $title');
          print('StartDate: $startDate');
          print('StartTime: $startTime');
          print('EndTime: $endTime'); // 종료 시간 로그 추가
          print('Description: $description');

          if (startDate != null) {
            try {
              // 날짜 파싱
              final eventDate = DateTime.parse(startDate);
              final eventTime =
                  (startTime == null || startTime.isEmpty)
                      ? '종일'
                      : startTime; // 시간이 없으면 '종일'로 처리

              print('파싱된 날짜: $eventDate');
              print('파싱된 시간: $eventTime');

              // 🔥 중복 체크 추가
              final existingEvents = await EventStorageService.getEvents(
                eventDate,
              );
              final isDuplicate = existingEvents.any(
                (e) =>
                    e.title.trim().toLowerCase() ==
                        title.trim().toLowerCase() &&
                    e.time == eventTime &&
                    e.date.year == eventDate.year &&
                    e.date.month == eventDate.month &&
                    e.date.day == eventDate.day,
              );
              if (isDuplicate) {
                print('🚫 AI 채팅: 중복된 일정이므로 추가하지 않음: $title ($eventTime)');
                return false; // 중복이므로 추가하지 않음
              } // 🚀 성능 최적화: 폴백 우선 사용 후 LLM 카테고리 분류
              int categoryColorId = _getFallbackCategoryFromText(title);
              String colorId = categoryColorId.toString();
              print(
                '🎨 단일 일정 폴백 카테고리 사용: $colorId (${_categoryNames[categoryColorId]}, 제목: $title)',
              );

              // 백그라운드에서 LLM 카테고리 분류 실행 (UI 블로킹 방지)
              _getCategoryFromLLM(title)
                  .then((llmCategoryId) {
                    if (llmCategoryId != categoryColorId) {
                      print(
                        '💡 LLM 카테고리 분류 완료 (다음에 적용): $llmCategoryId (${_categoryNames[llmCategoryId]})',
                      );
                    }
                  })
                  .catchError((e) {
                    print('❌ 백그라운드 LLM 카테고리 분류 실패: $e');
                  });

              // Event 객체 생성
              final event = Event(
                title: title,
                time: eventTime,
                endTime: endTime, // 종료 시간 추가
                date: eventDate,
                description: description,
                source: 'local', // 로컬에서 생성된 이벤트
                colorId: colorId, // 카테고리 기반 colorId 사용
              );

              print('생성된 Event 객체: ${event.toJson()}');

              // EventManager가 전달되었다면 이벤트 매니저를 통해 추가 (Google 동기화 포함)
              if (eventManager != null) {
                print(
                  '🔄 ChatService: EventManager의 addEvent로 일정 추가 중 (Google 동기화 포함)',
                );
                await eventManager.addEvent(event, syncWithGoogle: true);
                print('✅ AI 채팅으로 추가된 일정이 로컬 및 Google 캘린더에 저장되었습니다: $title');
              } else {
                // EventManager가 없는 경우 폴백: 로컬 저장소에만 저장
                print('⚠️ EventManager가 없어 로컬에만 저장합니다');
                await EventStorageService.addEvent(eventDate, event);
                print('✅ AI 채팅으로 추가된 일정이 로컬 캘린더에만 저장되었습니다: $title');
              }

              print('저장된 날짜: $eventDate');

              // 저장 후 확인
              final savedEvents = await EventStorageService.getEvents(
                eventDate,
              );
              print(
                '저장 후 확인 - 해당 날짜의 이벤트들: ${savedEvents.map((e) => e.toJson()).toList()}',
              );

              return true; // 캘린더가 업데이트되었음을 반환
            } catch (e) {
              print('❌ AI 채팅 이벤트 추가 오류: $e');
              return false;
            }
          } else {
            print('❌ startDate가 null입니다');
            return false;
          }
        }
      }
      // 일정 수정이 성공한 경우
      else if (intent == 'calendar_update' &&
          calendarResult != null &&
          calendarResult['success'] == true &&
          extractedInfo != null) {
        print('✏️ 일정 수정 조건 만족! 이벤트 수정 시작...');

        final updateType = extractedInfo['update_type'] as String? ?? 'single';
        print('🔍 수정 타입: $updateType');

        if (updateType == 'multiple') {
          // 다중 수정 처리
          return await _handleMultipleUpdate(
            extractedInfo,
            eventManager,
            onCalendarUpdate,
          );
        } else {
          // 단일 수정 처리 (기존 로직)
          final target = extractedInfo['target'] as Map<String, dynamic>? ?? {};
          final changes =
              extractedInfo['changes'] as Map<String, dynamic>? ?? {};

          // 기존 필드명과의 호환성을 위한 매핑
          final originalTitle =
              target['title'] as String? ??
              extractedInfo['original_title'] as String? ??
              extractedInfo['title'] as String? ??
              '';
          final targetDate =
              target['date'] as String? ??
              extractedInfo['start_date'] as String?;
          // 변경 사항 추출
          final newTitle =
              changes['title'] as String? ??
              extractedInfo['new_title'] as String? ??
              extractedInfo['title'] as String?;
          final newStartTime =
              changes['start_time'] as String? ??
              extractedInfo['new_start_time'] as String? ??
              extractedInfo['start_time'] as String?;
          final newEndTime =
              changes['end_time'] as String? ??
              extractedInfo['new_end_time'] as String? ??
              extractedInfo['end_time'] as String?;
          final newDescription =
              changes['description'] as String? ??
              extractedInfo['new_description'] as String? ??
              extractedInfo['description'] as String?;
          final newDate =
              changes['start_date'] as String? ??
              extractedInfo['start_date'] as String?;

          print('🔍 ExtractedInfo 전체 구조: $extractedInfo');
          print('🔍 수정 대상 원본 Title: "$originalTitle"');
          print('🔍 새로운 Title: "$newTitle"');
          print('🔍 대상 날짜: "$targetDate"');
          print('🔍 새로운 날짜: "$newDate"');
          print('🔍 새로운 StartTime: "$newStartTime"');
          print('🔍 새로운 EndTime: "$newEndTime"');
          print('🔍 새로운 Description: "$newDescription"');

          // 검색할 날짜 설정
          final searchDate = targetDate;
          if (searchDate != null) {
            try {
              // 날짜 파싱
              final eventDate = DateTime.parse(searchDate);
              print('📅 파싱된 검색 날짜: $eventDate');

              // 해당 날짜의 모든 이벤트 가져오기
              final existingEvents = await EventStorageService.getEvents(
                eventDate,
              );
              print('📋 해당 날짜의 기존 이벤트들 (${existingEvents.length}개):');
              for (int i = 0; i < existingEvents.length; i++) {
                print('  $i: ${existingEvents[i].toJson()}');
              }

              // 수정할 이벤트 찾기 (Google Event ID 우선, 제목으로 폴백)
              Event? eventToUpdate;
              print('🔍 수정할 이벤트 검색 중...');

              // Google Event ID가 있다면 우선적으로 검색
              final googleEventId = extractedInfo['google_event_id'] as String?;
              if (googleEventId != null && googleEventId.isNotEmpty) {
                print('🔗 Google Event ID로 검색 시도: $googleEventId');
                for (var event in existingEvents) {
                  if (event.googleEventId == googleEventId) {
                    eventToUpdate = event;
                    print('✅ Google Event ID로 이벤트 찾음: ${event.toJson()}');
                    break;
                  }
                }
              }

              // Google Event ID로 찾지 못했거나 ID가 없는 경우 제목으로 검색
              if (eventToUpdate == null) {
                print('🔍 제목으로 이벤트 검색...');
                for (int i = 0; i < existingEvents.length; i++) {
                  var event = existingEvents[i];
                  print('  검색 $i: "${event.title}" vs "$originalTitle"');

                  bool titleMatch = false;
                  if (originalTitle.isNotEmpty) {
                    // 정확한 일치 우선
                    if (event.title.toLowerCase() ==
                        originalTitle.toLowerCase()) {
                      titleMatch = true;
                      print('    정확한 제목 일치: $titleMatch');
                    }
                    // 포함 관계 검사
                    else if (event.title.toLowerCase().contains(
                          originalTitle.toLowerCase(),
                        ) ||
                        originalTitle.toLowerCase().contains(
                          event.title.toLowerCase(),
                        )) {
                      titleMatch = true;
                      print('    부분 제목 일치: $titleMatch');
                    }
                  } else {
                    // originalTitle이 비어있는 경우, 해당 날짜의 첫 번째 이벤트를 수정 대상으로 선택
                    print('    originalTitle이 비어있음 - 첫 번째 이벤트 선택');
                    titleMatch = true;
                  }

                  if (titleMatch) {
                    eventToUpdate = event;
                    print('✅ 수정할 이벤트 찾음 (제목 기준): ${event.toJson()}');
                    break;
                  }
                }
              }

              if (eventToUpdate != null) {
                print('✏️ 이벤트 수정 실행 중...');

                // 새로운 날짜가 지정된 경우 파싱
                DateTime updatedDate = eventToUpdate.date;
                if (newDate != null && newDate != targetDate) {
                  try {
                    updatedDate = DateTime.parse(newDate);
                    print('📅 새로운 날짜로 변경: $updatedDate');
                  } catch (e) {
                    print('⚠️ 새로운 날짜 파싱 실패, 기존 날짜 유지: $e');
                  }
                }

                // 시간 수정 처리 - 시작 시간만 변경되고 종료 시간이 명시되지 않은 경우 자동으로 1시간으로 설정
                String finalStartTime =
                    (newStartTime != null && newStartTime != eventToUpdate.time)
                        ? newStartTime
                        : eventToUpdate.time;
                String? finalEndTime;

                if (newStartTime != null &&
                    newStartTime != eventToUpdate.time) {
                  // 시작 시간이 변경된 경우
                  if (newEndTime != null &&
                      newEndTime != eventToUpdate.endTime) {
                    // 종료 시간도 명시적으로 변경된 경우
                    finalEndTime = newEndTime;
                  } else {
                    // 시작 시간만 변경되고 종료 시간이 명시되지 않은 경우 -> 기본 1시간으로 설정
                    try {
                      final startTimeParts = finalStartTime.split(':');
                      if (startTimeParts.length == 2) {
                        final startHour = int.parse(startTimeParts[0]);
                        final startMinute = int.parse(startTimeParts[1]);
                        final endHour = (startHour + 1) % 24;
                        finalEndTime =
                            '${endHour.toString().padLeft(2, '0')}:${startMinute.toString().padLeft(2, '0')}';
                        print(
                          '⏰ 시작 시간만 변경됨 - 종료 시간 자동 설정: $finalStartTime → $finalEndTime',
                        );
                      }
                    } catch (e) {
                      print('⚠️ 종료 시간 자동 설정 실패: $e');
                      finalEndTime = eventToUpdate.endTime; // 기존 종료 시간 유지
                    }
                  }
                } else {
                  // 시작 시간이 변경되지 않은 경우
                  finalEndTime =
                      (newEndTime != null &&
                              newEndTime != eventToUpdate.endTime)
                          ? newEndTime
                          : eventToUpdate.endTime;
                }

                // 수정된 이벤트 생성 (기존 값들을 더 잘 보존)
                final updatedEvent = eventToUpdate.copyWith(
                  title:
                      (newTitle != null && newTitle != eventToUpdate.title)
                          ? newTitle
                          : eventToUpdate.title,
                  time: finalStartTime,
                  endTime: finalEndTime,
                  date: updatedDate,
                  description:
                      (newDescription != null &&
                              newDescription != eventToUpdate.description)
                          ? newDescription
                          : eventToUpdate.description,
                );

                print('🔄 수정 전 이벤트: ${eventToUpdate.toJson()}');
                print('🔄 적용할 변경사항:');
                print('   제목: ${eventToUpdate.title} -> ${updatedEvent.title}');
                print('   시간: ${eventToUpdate.time} -> ${updatedEvent.time}');
                print(
                  '   종료시간: ${eventToUpdate.endTime} -> ${updatedEvent.endTime}',
                );
                print('   날짜: ${eventToUpdate.date} -> ${updatedEvent.date}');
                print(
                  '   설명: "${eventToUpdate.description}" -> "${updatedEvent.description}"',
                );

                print('🔄 수정된 Event 객체: ${updatedEvent.toJson()}');

                // EventManager를 통해 수정
                if (eventManager != null) {
                  await eventManager.updateEvent(
                    eventToUpdate,
                    updatedEvent,
                    syncWithGoogle: true,
                  );
                  print('✅ EventManager를 통해 일정 수정 및 Google Calendar 동기화 완료');
                } else {
                  // 폴백: 로컬에서만 수정
                  await EventStorageService.removeEvent(
                    eventToUpdate.date,
                    eventToUpdate,
                  );
                  await EventStorageService.addEvent(updatedDate, updatedEvent);
                  print(
                    '⚠️ EventManager가 없어 로컬에서만 수정되었습니다 (Google Calendar 동기화 없음)',
                  );
                }

                print(
                  '✅ AI 채팅으로 요청된 일정이 수정되었습니다: ${eventToUpdate.title} -> ${updatedEvent.title}',
                );
                print('📅 수정된 날짜: $updatedDate');

                // 수정 후 확인
                final updatedEvents = await EventStorageService.getEvents(
                  updatedDate,
                );
                print('🔍 수정 후 확인 - 해당 날짜의 이벤트들 (${updatedEvents.length}개):');
                for (int i = 0; i < updatedEvents.length; i++) {
                  print('  $i: ${updatedEvents[i].toJson()}');
                }

                // 캘린더 업데이트 콜백 호출
                if (onCalendarUpdate != null) {
                  onCalendarUpdate();
                  print('📱 캘린더 업데이트 콜백 호출됨');
                }

                return true; // 캘린더가 업데이트되었음을 반환
              } else {
                print('❌ 수정할 이벤트를 찾을 수 없습니다.');
                print('   검색한 제목: "$originalTitle"');
                print('   검색한 날짜: $eventDate');
              }
            } catch (e) {
              print('❌ 일정 수정 중 날짜 파싱 오류: $e');
            }
          } else {
            print('❌ 수정할 일정의 날짜 정보가 없습니다');
          }
        }
      } // 일정 조회가 성공한 경우 (calendar_query 또는 calendar_search)
      else if ((intent == 'calendar_query' || intent == 'calendar_search') &&
          extractedInfo != null) {
        print('📅 일정 조회 조건 만족! 일정 조회 시작...');

        // 추출된 날짜 정보로 일정 조회
        final queryDate =
            extractedInfo['query_date'] as String? ??
            extractedInfo['start_date'] as String? ??
            extractedInfo['date'] as String?;
        final queryDateEnd =
            extractedInfo['query_date_end'] as String? ??
            extractedInfo['end_date'] as String?;

        print('🔍 조회할 날짜: "$queryDate"');
        print('🔍 조회 종료날짜: "$queryDateEnd"');
        print('🔍 ExtractedInfo 전체: $extractedInfo');

        if (queryDate != null) {
          try {
            // 시작 날짜 파싱
            final startDate = DateTime.parse(queryDate);
            print('📅 파싱된 조회 시작 날짜: $startDate');

            // 종료 날짜 파싱 (없으면 시작 날짜와 동일)
            final endDate =
                queryDateEnd != null ? DateTime.parse(queryDateEnd) : startDate;
            print('📅 파싱된 조회 종료 날짜: $endDate');

            // 로컬에서 직접 일정 조회 (백엔드 결과에 의존하지 않음)
            final eventsMap = await _getEventsInDateRange(
              startDate,
              endDate,
              eventManager,
            );

            if (eventsMap.isNotEmpty) {
              final totalEvents = eventsMap.values.fold<int>(
                0,
                (sum, events) => sum + events.length,
              );
              print('📋 조회된 총 일정 개수: $totalEvents개');

              // 일정 목록을 사용자 친화적으로 포맷팅
              final formattedSchedule = _formatScheduleForUser(
                eventsMap,
                startDate,
                endDate,
              );
              print('📝 포맷팅된 일정 브리핑: $formattedSchedule');

              // 일정 조회는 캘린더를 수정하지 않으므로 false 반환
              return false; // 캘린더 조회 완료 (수정 없음)
            } else {
              print('📭 해당 기간에 일정이 없습니다.');
              // 일정이 없어도 응답 생성하지만 캘린더 수정은 없음
              return false; // 빈 일정도 조회 작업이므로 수정 없음
            }
          } catch (e) {
            print('❌ 일정 조회 중 날짜 파싱 오류: $e');
            return false;
          }
        } else {
          print('❌ 조회할 날짜 정보가 없습니다');
          return false;
        }
      }
      // 일정 삭제가 성공한 경우
      else if (intent == 'calendar_delete' &&
          calendarResult != null &&
          calendarResult['success'] == true &&
          extractedInfo != null) {
        print('🗑️ 일정 삭제 조건 만족! 이벤트 삭제 시작...');

        final deleteType = extractedInfo['delete_type'] as String? ?? 'single';
        print('🔍 삭제 타입: $deleteType');

        if (deleteType == 'bulk') {
          // 전체 삭제 처리
          return await _handleBulkDelete(
            extractedInfo,
            eventManager,
            onCalendarUpdate,
          );
        } else if (deleteType == 'multiple') {
          // 다중 개별 삭제 처리
          return await _handleMultipleDelete(
            extractedInfo,
            eventManager,
            onCalendarUpdate,
          );
        } else if (deleteType == 'mixed') {
          // 혼합 삭제 처리 (개별 삭제 + 전체 삭제)
          return await _handleMixedDelete(
            extractedInfo,
            eventManager,
            onCalendarUpdate,
          );
        } else {
          // 단일 삭제 처리 (기존 로직)
          final title = extractedInfo['title'] as String? ?? '';
          final startDate =
              extractedInfo['date'] as String? ??
              extractedInfo['start_date'] as String?;
          final startTime =
              extractedInfo['time'] as String? ??
              extractedInfo['start_time'] as String?;

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

              // 삭제할 이벤트 찾기 (Google Event ID 우선, 제목으로 폴백)
              Event? eventToDelete;
              print('🔍 삭제할 이벤트 검색 중...');

              // Google Event ID가 있다면 우선적으로 검색
              final googleEventId = extractedInfo['google_event_id'] as String?;
              if (googleEventId != null && googleEventId.isNotEmpty) {
                print('🔗 Google Event ID로 검색 시도: $googleEventId');
                for (var event in existingEvents) {
                  if (event.googleEventId == googleEventId) {
                    eventToDelete = event;
                    print('✅ Google Event ID로 이벤트 찾음: ${event.toJson()}');
                    break;
                  }
                }
              }

              // Google Event ID로 찾지 못했거나 ID가 없는 경우 제목으로 검색
              if (eventToDelete == null) {
                print('🔍 제목으로 이벤트 검색...');
                for (int i = 0; i < existingEvents.length; i++) {
                  var event = existingEvents[i];
                  print('  검색 $i: "${event.title}" vs "$title"');

                  bool titleMatch = false;
                  if (title.isNotEmpty) {
                    titleMatch =
                        event.title.toLowerCase().contains(
                          title.toLowerCase(),
                        ) ||
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
              }
              if (eventToDelete != null) {
                print(
                  '🗑️ 이벤트 삭제 실행 중...',
                ); // EventManager를 통해 삭제 (컨트롤러 갱신 및 Google 동기화 포함)
                if (eventManager != null) {
                  await eventManager.removeEventAndRefresh(
                    eventDate,
                    eventToDelete,
                    syncWithGoogle: true, // Google 캘린더에서도 삭제
                  );
                  print('✅ EventManager를 통해 일정 삭제 및 Google Calendar 동기화 완료');
                } else {
                  // 폴백: EventStorageService로 삭제 (Google Calendar 동기화 없음)
                  await EventStorageService.removeEvent(
                    eventDate,
                    eventToDelete,
                  );
                  print(
                    '⚠️ EventManager가 없어 로컬에서만 삭제되었습니다 (Google Calendar 동기화 없음)',
                  );
                }

                print('✅ AI 채팅으로 요청된 일정이 삭제되었습니다: ${eventToDelete.title}');
                print('📅 삭제된 날짜: $eventDate');

                // 삭제 후 확인
                final remainingEvents = await EventStorageService.getEvents(
                  eventDate,
                );
                print('🔍 삭제 후 확인 - 남은 이벤트들 (${remainingEvents.length}개):');
                for (int i = 0; i < remainingEvents.length; i++) {
                  print('  $i: ${remainingEvents[i].toJson()}');
                }

                // 캘린더 업데이트 콜백 호출
                if (onCalendarUpdate != null) {
                  onCalendarUpdate();
                  print('📱 캘린더 업데이트 콜백 호출됨');
                }

                return true; // 캘린더가 업데이트되었음을 반환
              } else {
                print('❌ 삭제할 이벤트를 찾을 수 없습니다.');
                print('   검색한 제목: "$title"');
                print('   검색한 날짜: $eventDate');
                print('   검색한 시간: $startTime');
                print('   기존 이벤트 개수: ${existingEvents.length}개');
                return false; // 삭제할 이벤트가 없음을 명시적으로 반환
              }
            } catch (e) {
              print('❌ 일정 삭제 중 날짜 파싱 오류: $e');
            }
          } else {
            print('❌ 삭제할 일정의 startDate가 null입니다');
          }
          return false;
        }
      }
      // 일정 작업 조건 불만족
      else {
        print('일정 작업 조건 불만족:');
        print('- Intent: $intent');
        print('- Intent == calendar_add: ${intent == 'calendar_add'}');
        print('- Intent == calendar_update: ${intent == 'calendar_update'}');
        print('- Intent == calendar_delete: ${intent == 'calendar_delete'}');
        print('- Intent == calendar_query: ${intent == 'calendar_query'}');
        print('- Intent == calendar_search: ${intent == 'calendar_search'}');
        print('- CalendarResult != null: ${calendarResult != null}');
        print('- ExtractedInfo != null: ${extractedInfo != null}');
        if (calendarResult != null) {
          print('- CalendarResult keys: ${calendarResult.keys.toList()}');
          print('- CalendarResult: $calendarResult');
        }
      }

      print('=== 캘린더 응답 처리 종료 ===');
      return false; // 캘린더 업데이트 없음
    } catch (e) {
      print('❌ 캘린더 응답 처리 중 오류: $e');
      return false;
    }
  }

  // 전체 삭제 처리 메서드
  Future<bool> _handleBulkDelete(
    Map<String, dynamic> extractedInfo,
    EventManager? eventManager,
    Function()? onCalendarUpdate,
  ) async {
    try {
      final targetDate = extractedInfo['target_date'] as String?;
      final dateDescription =
          extractedInfo['date_description'] as String? ?? '해당 날짜';

      print('📋 전체 삭제 처리 시작: $targetDate ($dateDescription)');

      if (targetDate != null) {
        final eventDate = DateTime.parse(targetDate);
        final existingEvents = await EventStorageService.getEvents(eventDate);

        print('🔍 삭제할 이벤트들: ${existingEvents.length}개');

        if (existingEvents.isNotEmpty) {
          int deletedCount = 0;

          for (var event in existingEvents) {
            try {
              if (eventManager != null) {
                await eventManager.removeEventAndRefresh(
                  eventDate,
                  event,
                  syncWithGoogle: true,
                );
              } else {
                await EventStorageService.removeEvent(eventDate, event);
              }
              deletedCount++;
              print('✅ 삭제 완료: ${event.title}');
            } catch (e) {
              print('❌ 삭제 실패: ${event.title} - $e');
            }
          }

          print('📊 전체 삭제 완료: $deletedCount/${existingEvents.length}개');

          if (onCalendarUpdate != null && deletedCount > 0) {
            onCalendarUpdate();
          }

          return deletedCount > 0;
        } else {
          print('📭 해당 날짜에 삭제할 일정이 없습니다');
          return false;
        }
      } else {
        print('❌ 삭제할 날짜 정보가 없습니다');
        return false;
      }
    } catch (e) {
      print('❌ 전체 삭제 처리 중 오류: $e');
      return false;
    }
  }

  // 다중 개별 삭제 처리 메서드
  Future<bool> _handleMultipleDelete(
    Map<String, dynamic> extractedInfo,
    EventManager? eventManager,
    Function()? onCalendarUpdate,
  ) async {
    try {
      final targets = extractedInfo['targets'] as List<dynamic>? ?? [];

      print('📋 다중 개별 삭제 처리 시작: ${targets.length}개 일정');

      int deletedCount = 0;
      bool anyDeleted = false;

      for (int i = 0; i < targets.length; i++) {
        final target = targets[i] as Map<String, dynamic>;
        final title = target['title'] as String? ?? '';
        final date = target['date'] as String?;
        final time = target['time'] as String?;

        print('🗑️ 개별 삭제 ${i + 1}: $title ($date $time)');

        if (date != null) {
          try {
            final eventDate = DateTime.parse(date);
            final existingEvents = await EventStorageService.getEvents(
              eventDate,
            );

            Event? eventToDelete;

            // 제목으로 이벤트 찾기
            for (var event in existingEvents) {
              if (title.isNotEmpty) {
                bool titleMatch =
                    event.title.toLowerCase().contains(title.toLowerCase()) ||
                    title.toLowerCase().contains(event.title.toLowerCase());

                // 시간이 지정된 경우 시간도 확인
                if (titleMatch) {
                  if (time != null && time.isNotEmpty) {
                    if (event.time == time) {
                      eventToDelete = event;
                      break;
                    }
                  } else {
                    eventToDelete = event;
                    break;
                  }
                }
              }
            }
            if (eventToDelete != null) {
              if (eventManager != null) {
                await eventManager.removeEventAndRefresh(
                  eventDate,
                  eventToDelete,
                  syncWithGoogle: true,
                );
              } else {
                await EventStorageService.removeEvent(eventDate, eventToDelete);
              }

              deletedCount++;
              anyDeleted = true;
              print('✅ 개별 삭제 ${i + 1} 완료: ${eventToDelete.title}');
            } else {
              print('❌ 개별 삭제 ${i + 1} 실패: 일정을 찾을 수 없음 ($title)');
              // 일정을 찾을 수 없는 경우에도 로그만 출력하고 계속 진행
            }
          } catch (e) {
            print('❌ 개별 삭제 ${i + 1} 처리 중 오류: $e');
          }
        } else {
          print('❌ 개별 삭제 ${i + 1}: 날짜 정보가 없음');
        }
      }

      print('📊 다중 개별 삭제 완료: $deletedCount/${targets.length}개');

      if (onCalendarUpdate != null && anyDeleted) {
        onCalendarUpdate();
      }

      return anyDeleted;
    } catch (e) {
      print('❌ 다중 개별 삭제 처리 중 오류: $e');
      return false;
    }
  }

  // 혼합 삭제 처리 메서드 (개별 삭제 + 전체 삭제)
  Future<bool> _handleMixedDelete(
    Map<String, dynamic> extractedInfo,
    EventManager? eventManager,
    Function()? onCalendarUpdate,
  ) async {
    try {
      final actions = extractedInfo['actions'] as List<dynamic>? ?? [];

      print('📋 혼합 삭제 처리 시작: ${actions.length}개 액션');

      bool anyDeleted = false;
      int totalDeletedCount = 0;

      for (int i = 0; i < actions.length; i++) {
        final action = actions[i] as Map<String, dynamic>;
        final actionType = action['type'] as String?;

        print('🎯 액션 ${i + 1}: $actionType');

        if (actionType == 'individual') {
          // 개별 일정 삭제
          final title = action['title'] as String? ?? '';
          final date = action['date'] as String?;
          final time = action['time'] as String?;

          print('🗑️ 개별 삭제: $title ($date $time)');

          if (date != null) {
            try {
              final eventDate = DateTime.parse(date);
              final existingEvents = await EventStorageService.getEvents(
                eventDate,
              );

              Event? eventToDelete;

              // 제목으로 이벤트 찾기
              for (var event in existingEvents) {
                if (title.isNotEmpty) {
                  bool titleMatch =
                      event.title.toLowerCase().contains(title.toLowerCase()) ||
                      title.toLowerCase().contains(event.title.toLowerCase());

                  if (titleMatch) {
                    eventToDelete = event;
                    break;
                  }
                }
              }

              if (eventToDelete != null) {
                if (eventManager != null) {
                  await eventManager.removeEventAndRefresh(
                    eventDate,
                    eventToDelete,
                    syncWithGoogle: true,
                  );
                } else {
                  await EventStorageService.removeEvent(
                    eventDate,
                    eventToDelete,
                  );
                }

                totalDeletedCount++;
                anyDeleted = true;
                print('✅ 개별 삭제 완료: ${eventToDelete.title}');
              } else {
                print('❌ 개별 삭제 실패: 일정을 찾을 수 없음 ($title)');
              }
            } catch (e) {
              print('❌ 개별 삭제 처리 중 오류: $e');
            }
          } else {
            print('❌ 개별 삭제: 날짜 정보가 없음');
          }
        } else if (actionType == 'bulk') {
          // 전체 일정 삭제
          final targetDate = action['target_date'] as String?;
          final dateDescription =
              action['date_description'] as String? ?? '해당 날짜';

          print('📋 전체 삭제: $targetDate ($dateDescription)');

          if (targetDate != null) {
            try {
              final eventDate = DateTime.parse(targetDate);
              final existingEvents = await EventStorageService.getEvents(
                eventDate,
              );

              print('🔍 전체 삭제할 이벤트들: ${existingEvents.length}개');

              int bulkDeletedCount = 0;

              for (var event in existingEvents) {
                try {
                  if (eventManager != null) {
                    await eventManager.removeEventAndRefresh(
                      eventDate,
                      event,
                      syncWithGoogle: true,
                    );
                  } else {
                    await EventStorageService.removeEvent(eventDate, event);
                  }
                  bulkDeletedCount++;
                  print('✅ 전체 삭제 완료: ${event.title}');
                } catch (e) {
                  print('❌ 전체 삭제 실패: ${event.title} - $e');
                }
              }

              totalDeletedCount += bulkDeletedCount;
              if (bulkDeletedCount > 0) {
                anyDeleted = true;
              }

              print('📊 전체 삭제 완료: $bulkDeletedCount/${existingEvents.length}개');
            } catch (e) {
              print('❌ 전체 삭제 처리 중 오류: $e');
            }
          } else {
            print('❌ 전체 삭제: 날짜 정보가 없음');
          }
        } else {
          print('❌ 알 수 없는 액션 타입: $actionType');
        }
      }

      print('📊 혼합 삭제 총 완료: $totalDeletedCount개');

      if (onCalendarUpdate != null && anyDeleted) {
        onCalendarUpdate();
      }

      return anyDeleted;
    } catch (e) {
      print('❌ 혼합 삭제 처리 중 오류: $e');
      return false;
    }
  }

  // 일정 조회 관련 키워드 목록
  final List<String> _calendarQueryKeywords = [
    '일정',
    '스케줄',
    '계획',
    '약속',
    '미팅',
    '회의',
    '오늘 일정',
    '내일 일정',
    '이번 주 일정',
    '다음 주 일정',
    '일정 알려줘',
    '일정 확인',
    '뭐 있어',
    '뭐있어',
    '무슨 일',
    '캘린더',
    '달력',
    '확인',
  ];

  // 일정 조회 관련 질문인지 확인하는 메서드
  bool _isCalendarQueryQuestion(String text) {
    return _calendarQueryKeywords.any((keyword) => text.contains(keyword));
  }

  // AI에게 제공할 캘린더 데이터 가져오기
  Future<List<Map<String, dynamic>>> _getCalendarDataForAI() async {
    try {
      final now = DateTime.now();
      final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
      final endOfWeek = startOfWeek.add(const Duration(days: 13)); // 2주치 데이터

      List<Map<String, dynamic>> calendarData = [];

      for (
        DateTime date = startOfWeek;
        date.isBefore(endOfWeek) || date.isAtSameMomentAs(endOfWeek);
        date = date.add(const Duration(days: 1))
      ) {
        final events = await EventStorageService.getEvents(date);

        for (var event in events) {
          calendarData.add({
            'id': event.uniqueId,
            'google_event_id': event.googleEventId,
            'title': event.title,
            'date': event.date.toIso8601String().split('T')[0], // yyyy-MM-dd 형식
            'time': event.time,
            'end_time': event.endTime,
            'description': event.description,
            'source': event.source,
            'color_id': event.colorId,
          });
        }
      }

      print('🗓️ AI용 캘린더 데이터 준비 완료: ${calendarData.length}개 이벤트');
      return calendarData;
    } catch (e) {
      print('❌ AI용 캘린더 데이터 준비 실패: $e');
      return [];
    }
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

  // 특정 날짜 범위의 일정 조회
  Future<Map<String, List<Event>>> _getEventsInDateRange(
    DateTime startDate,
    DateTime endDate,
    EventManager? eventManager,
  ) async {
    try {
      // EventStorageService를 직접 사용하여 날짜 범위의 이벤트 가져오기
      List<Event> events = [];
      final currentDate = DateTime(
        startDate.year,
        startDate.month,
        startDate.day,
      );
      final endDateOnly = DateTime(endDate.year, endDate.month, endDate.day);

      for (
        DateTime date = currentDate;
        date.isBefore(endDateOnly.add(Duration(days: 1)));
        date = date.add(Duration(days: 1))
      ) {
        final dayEvents = await EventStorageService.getEvents(date);
        events.addAll(dayEvents);
      }

      final eventsByDate = <String, List<Event>>{};

      // 날짜별로 그룹화
      for (final event in events) {
        final dateKey =
            '${event.date.year}-${event.date.month.toString().padLeft(2, '0')}-${event.date.day.toString().padLeft(2, '0')}';
        eventsByDate.putIfAbsent(dateKey, () => []).add(event);
      }

      return eventsByDate;
    } catch (e) {
      print('날짜 범위 일정 조회 오류: $e');
      return {};
    }
  }

  // 일정을 사용자 친화적으로 포맷팅
  String _formatScheduleForUser(
    Map<String, List<Event>> eventsMap,
    DateTime startDate,
    DateTime endDate,
  ) {
    final buffer = StringBuffer();

    // 단일 날짜인지 날짜 범위인지 확인
    final isSingleDate =
        startDate.year == endDate.year &&
        startDate.month == endDate.month &&
        startDate.day == endDate.day;

    if (isSingleDate) {
      final dayOfWeek =
          ['일', '월', '화', '수', '목', '금', '토'][startDate.weekday % 7];
      buffer.writeln(
        '📅 ${startDate.month}월 ${startDate.day}일 ($dayOfWeek)의 일정:',
      );
    } else {
      buffer.writeln(
        '📅 ${startDate.month}월 ${startDate.day}일 ~ ${endDate.month}월 ${endDate.day}일의 일정:',
      );
    }

    final sortedDates = eventsMap.keys.toList()..sort();

    for (final dateKey in sortedDates) {
      final events = eventsMap[dateKey]!;
      final date = DateTime.parse(dateKey);
      final dayOfWeek = ['일', '월', '화', '수', '목', '금', '토'][date.weekday % 7];

      if (!isSingleDate) {
        buffer.writeln('\n🗓️ ${date.month}월 ${date.day}일 ($dayOfWeek):');
      }

      // 시간순으로 정렬
      events.sort((a, b) {
        if (a.time.isEmpty && b.time.isEmpty) return 0;
        if (a.time.isEmpty) return 1;
        if (b.time.isEmpty) return -1;

        // HH:mm 형식의 시간을 분으로 변환하여 비교
        final aTime = _parseTimeToMinutes(a.time);
        final bTime = _parseTimeToMinutes(b.time);
        return aTime.compareTo(bTime);
      });

      for (int i = 0; i < events.length; i++) {
        final event = events[i];
        final startTime = event.time.isNotEmpty ? event.time : '시간 미정';
        final endTime = event.endTime ?? '';
        final timeStr = endTime.isNotEmpty ? '$startTime~$endTime' : startTime;

        buffer.writeln('  ${i + 1}. ${event.title}');
        buffer.writeln('     ⏰ $timeStr');

        // 마지막 일정이 아니면 줄바꿈 추가
        if (i < events.length - 1) {
          buffer.writeln();
        }
      }
    }

    final totalEvents = eventsMap.values.fold<int>(
      0,
      (sum, events) => sum + events.length,
    );
    buffer.writeln('\n📊 총 $totalEvents개의 일정이 있습니다.');

    return buffer.toString();
  }

  // HH:mm 형식의 시간을 분으로 변환하는 헬퍼 메서드
  int _parseTimeToMinutes(String timeStr) {
    try {
      if (timeStr.isEmpty) return 9999; // 시간이 없는 이벤트는 맨 뒤로

      final parts = timeStr.split(':');
      if (parts.length != 2) return 9999;

      final hour = int.parse(parts[0]);
      final minute = int.parse(parts[1]);

      return hour * 60 + minute;
    } catch (e) {
      return 9999; // 파싱 실패시 맨 뒤로
    }
  }

  // 다중 수정 처리 메서드
  Future<bool> _handleMultipleUpdate(
    Map<String, dynamic> extractedInfo,
    EventManager? eventManager,
    VoidCallback? onCalendarUpdate,
  ) async {
    try {
      final updates = extractedInfo['updates'] as List<dynamic>? ?? [];
      print('🔍 처리할 수정 요청 개수: ${updates.length}');

      int successCount = 0;
      List<Map<String, dynamic>> updateResults = [];

      for (int i = 0; i < updates.length; i++) {
        final updateRequest = updates[i] as Map<String, dynamic>;
        final target = updateRequest['target'] as Map<String, dynamic>? ?? {};
        final changes = updateRequest['changes'] as Map<String, dynamic>? ?? {};

        print('🔄 수정 요청 ${i + 1} 처리 중...');
        print('  대상: $target');
        print('  변경사항: $changes');

        final originalTitle = target['title'] as String? ?? '';
        final targetDate = target['date'] as String?;

        if (targetDate != null) {
          try {
            final eventDate = DateTime.parse(targetDate);
            print('📅 수정 대상 날짜: $eventDate');

            // 해당 날짜의 모든 이벤트 가져오기
            final existingEvents = await EventStorageService.getEvents(
              eventDate,
            );
            print('📋 해당 날짜의 이벤트들 (${existingEvents.length}개)');

            // 수정할 이벤트 찾기
            Event? eventToUpdate;

            // Google Event ID가 있다면 우선적으로 검색
            final googleEventId = target['google_event_id'] as String?;
            if (googleEventId != null && googleEventId.isNotEmpty) {
              print('🔗 Google Event ID로 검색: $googleEventId');
              for (var event in existingEvents) {
                if (event.googleEventId == googleEventId) {
                  eventToUpdate = event;
                  print('✅ Google Event ID로 이벤트 찾음');
                  break;
                }
              }
            }

            // Google Event ID로 찾지 못했거나 ID가 없는 경우 제목으로 검색
            if (eventToUpdate == null) {
              print('🔍 제목으로 이벤트 검색: $originalTitle');
              for (var event in existingEvents) {
                bool titleMatch =
                    event.title.toLowerCase() == originalTitle.toLowerCase() ||
                    event.title.toLowerCase().contains(
                      originalTitle.toLowerCase(),
                    ) ||
                    originalTitle.toLowerCase().contains(
                      event.title.toLowerCase(),
                    );

                if (titleMatch) {
                  eventToUpdate = event;
                  print('✅ 제목으로 이벤트 찾음: ${event.title}');
                  break;
                }
              }
            }

            if (eventToUpdate != null) {
              // 변경사항 적용
              final newTitle = changes['title'] as String?;
              final newStartTime = changes['start_time'] as String?;
              final newEndTime = changes['end_time'] as String?;
              final newDate = changes['start_date'] as String?;
              final newDescription = changes['description'] as String?;

              // 새로운 날짜 파싱
              DateTime updatedDate = eventToUpdate.date;
              if (newDate != null && newDate != targetDate) {
                try {
                  updatedDate = DateTime.parse(newDate);
                  print('📅 새로운 날짜로 변경: $updatedDate');
                } catch (e) {
                  print('⚠️ 새로운 날짜 파싱 실패, 기존 날짜 유지: $e');
                }
              }

              // 시간 수정 처리 - 시작 시간만 변경되고 종료 시간이 명시되지 않은 경우 자동으로 1시간으로 설정
              String finalStartTime =
                  (newStartTime != null && newStartTime != eventToUpdate.time)
                      ? newStartTime
                      : eventToUpdate.time;
              String? finalEndTime;

              if (newStartTime != null && newStartTime != eventToUpdate.time) {
                // 시작 시간이 변경된 경우
                if (newEndTime != null && newEndTime != eventToUpdate.endTime) {
                  // 종료 시간도 명시적으로 변경된 경우
                  finalEndTime = newEndTime;
                } else {
                  // 시작 시간만 변경되고 종료 시간이 명시되지 않은 경우 -> 기본 1시간으로 설정
                  try {
                    final startTimeParts = finalStartTime.split(':');
                    if (startTimeParts.length == 2) {
                      final startHour = int.parse(startTimeParts[0]);
                      final startMinute = int.parse(startTimeParts[1]);
                      final endHour = (startHour + 1) % 24;
                      finalEndTime =
                          '${endHour.toString().padLeft(2, '0')}:${startMinute.toString().padLeft(2, '0')}';
                      print(
                        '⏰ 시작 시간만 변경됨 - 종료 시간 자동 설정: $finalStartTime → $finalEndTime',
                      );
                    }
                  } catch (e) {
                    print('⚠️ 종료 시간 자동 설정 실패: $e');
                    finalEndTime = eventToUpdate.endTime; // 기존 종료 시간 유지
                  }
                }
              } else {
                // 시작 시간이 변경되지 않은 경우
                finalEndTime =
                    (newEndTime != null && newEndTime != eventToUpdate.endTime)
                        ? newEndTime
                        : eventToUpdate.endTime;
              }

              // 수정된 이벤트 생성
              final updatedEvent = eventToUpdate.copyWith(
                title:
                    (newTitle != null && newTitle != eventToUpdate.title)
                        ? newTitle
                        : eventToUpdate.title,
                time: finalStartTime,
                endTime: finalEndTime,
                date: updatedDate,
                description:
                    (newDescription != null &&
                            newDescription != eventToUpdate.description)
                        ? newDescription
                        : eventToUpdate.description,
              );

              print('🔄 수정 전: ${eventToUpdate.toJson()}');
              print('🔄 적용할 변경사항:');
              print('   제목: ${eventToUpdate.title} -> ${updatedEvent.title}');
              print('   시간: ${eventToUpdate.time} -> ${updatedEvent.time}');
              print(
                '   종료시간: ${eventToUpdate.endTime} -> ${updatedEvent.endTime}',
              );
              print('   날짜: ${eventToUpdate.date} -> ${updatedEvent.date}');
              print(
                '   설명: "${eventToUpdate.description}" -> "${updatedEvent.description}"',
              );

              print('🔄 수정된 Event 객체: ${updatedEvent.toJson()}');

              // EventManager를 통해 수정
              if (eventManager != null) {
                await eventManager.updateEvent(
                  eventToUpdate,
                  updatedEvent,
                  syncWithGoogle: true,
                );
                print('✅ EventManager를 통해 일정 수정 및 Google Calendar 동기화 완료');
              } else {
                // 폴백: 로컬에서만 수정
                await EventStorageService.removeEvent(
                  eventToUpdate.date,
                  eventToUpdate,
                );
                await EventStorageService.addEvent(updatedDate, updatedEvent);
                print(
                  '⚠️ EventManager가 없어 로컬에서만 수정되었습니다 (Google Calendar 동기화 없음)',
                );
              }

              print(
                '✅ AI 채팅으로 요청된 일정이 수정되었습니다: ${eventToUpdate.title} -> ${updatedEvent.title}',
              );
              print('📅 수정된 날짜: $updatedDate');

              // 수정 후 확인
              final updatedEvents = await EventStorageService.getEvents(
                updatedDate,
              );
              print('🔍 수정 후 확인 - 해당 날짜의 이벤트들 (${updatedEvents.length}개):');
              for (int i = 0; i < updatedEvents.length; i++) {
                print('  $i: ${updatedEvents[i].toJson()}');
              }

              // 캘린더 업데이트 콜백 호출
              if (onCalendarUpdate != null) {
                onCalendarUpdate();
                print('📱 캘린더 업데이트 콜백 호출됨');
              }

              successCount++;
              updateResults.add({
                'success': true,
                'original_title': eventToUpdate.title,
                'updated_title': updatedEvent.title,
                'original_date': eventToUpdate.date.toString(),
                'updated_date': updatedEvent.date.toString(),
              });

              print(
                '✅ 수정 요청 ${i + 1} 완료: ${eventToUpdate.title} -> ${updatedEvent.title}',
              );
            } else {
              print('❌ 수정 요청 ${i + 1} 실패: 이벤트를 찾을 수 없음');
              updateResults.add({
                'success': false,
                'error': '이벤트를 찾을 수 없음',
                'target_title': originalTitle,
                'target_date': targetDate,
              });
            }
          } catch (e) {
            print('❌ 수정 요청 ${i + 1} 처리 중 오류: $e');
            updateResults.add({
              'success': false,
              'error': e.toString(),
              'target_title': originalTitle,
              'target_date': targetDate,
            });
          }
        } else {
          print('❌ 수정 요청 ${i + 1} 실패: 날짜 정보가 없음');
          updateResults.add({
            'success': false,
            'error': '날짜 정보가 없음',
            'target_title': originalTitle,
          });
        }
      }

      print('🎯 다중 수정 완료: 총 ${updates.length}개 중 $successCount개 성공');

      // 캘린더 업데이트 콜백 호출
      if (onCalendarUpdate != null) {
        onCalendarUpdate();
        print('📱 캘린더 업데이트 콜백 호출됨');
      }

      return successCount > 0; // 하나라도 성공하면 true 반환
    } catch (e) {
      print('❌ 다중 수정 처리 중 오류: $e');
      return false;
    }
  }
}
