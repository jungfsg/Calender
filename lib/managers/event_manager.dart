import '../models/event.dart';
import '../services/event_storage_service.dart';
import '../services/google_calendar_service.dart';
import '../controllers/calendar_controller.dart';
import 'package:flutter/material.dart';
import 'dart:math';

/// 이벤트 관련 로직을 처리하는 매니저 클래스
class EventManager {
  final CalendarController _controller;
  final GoogleCalendarService _googleCalendarService = GoogleCalendarService();
  final Random _random = Random();
  // Google Calendar 표준 11가지 색상 (기존 7가지에서 11가지로 확장)
  final List<Color> _standardColors = [
    const Color(0xFF9AA0F5), // 라벤더
    const Color(0xFF33B679), // 세이지
    const Color(0xFF8E24AA), // 포도
    const Color(0xFFE67C73), // 플라밍고
    const Color(0xFFF6BF26), // 바나나
    const Color(0xFFFF8A65), // 귤
    const Color(0xFF039BE5), // 공작새
    const Color(0xFF616161), // 그래파이트
    const Color(0xFF3F51B5), // 블루베리
    const Color(0xFF0B8043), // 바질
    const Color(0xFFD50000), // 토마토
  ];

  EventManager(this._controller);

  /// 특정 날짜의 이벤트 로드 (중복 방지, 강제 새로고침 옵션 추가)
  Future<void> loadEventsForDay(
    DateTime day, {
    bool forceRefresh = false,
  }) async {
    final normalizedDay = DateTime(day.year, day.month, day.day);

    // 🔥 핵심 수정: 중복 로드 방지 (강제 새로고침 옵션 추가)
    if (!forceRefresh && !_controller.shouldLoadEventsForDay(normalizedDay)) {
      print('📋 이미 로드됨 또는 로딩 중, 스킵: ${normalizedDay.toString()}');
      return;
    }

    _controller.setDateLoading(normalizedDay, true);

    try {
      // 스토리지에서 날짜의 모든 이벤트 가져오기
      final events = await EventStorageService.getEvents(normalizedDay);

      // 🔥 중복 방지 및 참조 문제 해결: 기존 이벤트 완전 교체
      _controller.clearEventsForDay(normalizedDay);

      // 캐시에 이벤트 저장 (새로운 참조로)
      for (var event in events) {
        _controller.addEvent(event); // 색상이 없는 이벤트에 고유 ID 기반 색상 할당
        if (_controller.getEventIdColor(event.uniqueId) == null) {
          Color eventColor;
          if (event.source == 'holiday') {
            eventColor = Colors.deepOrange; // 공휴일은 주황색
          } else if (event.source == 'google') {
            // Google 이벤트의 경우 colorId를 확인
            if (event.colorId != null &&
                _controller.getColorIdColor(event.colorId!) != null) {
              eventColor = _controller.getColorIdColor(event.colorId!)!;
            } else {
              eventColor = Colors.lightBlue; // 기본 Google 이벤트 색상
            }
          } else {
            eventColor =
                _standardColors[_random.nextInt(_standardColors.length)];
          }
          // ID 기반 색상 설정 (새 방식)
          _controller.setEventIdColor(event.uniqueId, eventColor);

          // 기존 제목 기반 색상 설정 (호환성 유지)
          if (_controller.getEventColor(event.title) == null) {
            _controller.setEventColor(event.title, eventColor);
          }
        }
      }

      print('✅ 날짜별 이벤트 로드 완료: ${normalizedDay.toString()} - ${events.length}개');
    } catch (e) {
      print('❌ 이벤트 로드 실패: ${normalizedDay.toString()} - $e');
    } finally {
      _controller.setDateLoading(normalizedDay, false);
    }
  }

  /// 월 변경 시 호출되는 메서드 - 전체 월의 이벤트를 한번에 로드 (중복 방지)
  Future<void> loadEventsForMonth(DateTime month) async {
    try {
      print('📅 월별 이벤트 로딩 시작: ${month.year}년 ${month.month}월');

      final firstDay = DateTime(month.year, month.month, 1);
      final lastDay = DateTime(month.year, month.month + 1, 0);

      // 🔥 핵심: 해당 월의 모든 이벤트를 한번에 로드하되, 중복 방지
      for (
        DateTime day = firstDay;
        day.isBefore(lastDay.add(Duration(days: 1)));
        day = day.add(Duration(days: 1))
      ) {
        await loadEventsForDay(day);
      }

      print('✅ 월별 이벤트 로딩 완료: ${month.year}년 ${month.month}월');
    } catch (e) {
      print('❌ 월별 이벤트 로딩 실패: $e');
    }
  }

  /// 이벤트 추가 (중복 체크 강화)
  Future<void> addEvent(Event event) async {
    try {
      // 1. 기존 이벤트와 중복 체크
      final existingEvents = await EventStorageService.getEvents(event.date);
      final isDuplicate = existingEvents.any(
        (e) =>
            e.title.trim().toLowerCase() == event.title.trim().toLowerCase() &&
            e.time == event.time &&
            e.date.year == event.date.year &&
            e.date.month == event.date.month &&
            e.date.day == event.date.day,
      );

      if (isDuplicate) {
        print('🚫 중복 이벤트로 추가하지 않음: ${event.title} (${event.time})');
        throw Exception('이미 동일한 일정이 존재합니다');
      }

      // 2. 컨트롤러 캐시에서도 중복 체크
      final cachedEvents = _controller.getEventsForDay(event.date);
      final isCacheDuplicate = cachedEvents.any(
        (e) =>
            e.title.trim().toLowerCase() == event.title.trim().toLowerCase() &&
            e.time == event.time &&
            e.date.year == event.date.year &&
            e.date.month == event.date.month &&
            e.date.day == event.date.day,
      );

      if (isCacheDuplicate) {
        print('🚫 캐시에 중복 이벤트 존재: ${event.title} (${event.time})');
        throw Exception('이미 동일한 일정이 존재합니다');
      }

      // 3. 중복이 없으면 저장
      await EventStorageService.addEvent(event.date, event);

      // 4. 컨트롤러에 추가
      _controller.addEvent(event);

      // 5. 색상 할당
      if (_controller.getEventColor(event.title) == null) {
        final color = _standardColors[_random.nextInt(_standardColors.length)];
        _controller.setEventColor(event.title, color);
      }

      print('✅ 이벤트 추가됨: ${event.title}');
    } catch (e) {
      print('❌ 이벤트 추가 중 오류: $e');
      rethrow;
    }
  }

  /// 색상 ID를 지정하여 이벤트 추가
  Future<void> addEventWithColorId(Event event, int colorId) async {
    try {
      // 색상 ID 적용된 이벤트 생성
      final coloredEvent = event.withColorId(colorId);

      // 기존 중복 체크 로직
      final existingEvents = await EventStorageService.getEvents(
        coloredEvent.date,
      );
      final isDuplicate = existingEvents.any(
        (e) =>
            e.title.trim().toLowerCase() ==
                coloredEvent.title.trim().toLowerCase() &&
            e.time == coloredEvent.time &&
            e.date.year == coloredEvent.date.year &&
            e.date.month == coloredEvent.date.month &&
            e.date.day == coloredEvent.date.day,
      );

      if (isDuplicate) {
        print(
          '🚫 중복 이벤트로 추가하지 않음: ${coloredEvent.title} (${coloredEvent.time})',
        );
        throw Exception('이미 동일한 일정이 존재합니다');
      }

      // 컨트롤러 캐시에서도 중복 체크
      final cachedEvents = _controller.getEventsForDay(coloredEvent.date);
      final isCacheDuplicate = cachedEvents.any(
        (e) =>
            e.title.trim().toLowerCase() ==
                coloredEvent.title.trim().toLowerCase() &&
            e.time == coloredEvent.time &&
            e.date.year == coloredEvent.date.year &&
            e.date.month == coloredEvent.date.month &&
            e.date.day == coloredEvent.date.day,
      );

      if (isCacheDuplicate) {
        print('🚫 캐시에 중복 이벤트 존재: ${coloredEvent.title} (${coloredEvent.time})');
        throw Exception('이미 동일한 일정이 존재합니다');
      }

      // 저장 및 캐시 추가
      await EventStorageService.addEvent(coloredEvent.date, coloredEvent);
      _controller.addEvent(coloredEvent); // 컨트롤러에 색상 정보도 저장 (중복 우선순위 간소화)
      _controller.setEventIdColor(
        coloredEvent.uniqueId,
        coloredEvent.getDisplayColor(),
      );

      print('✅ 색상 지정 이벤트 추가됨: ${coloredEvent.title} (색상 ID: $colorId)');
    } catch (e) {
      print('❌ 색상 지정 이벤트 추가 중 오류: $e');
      rethrow;
    }
  }

  /// 이벤트 제거
  Future<void> removeEvent(Event event) async {
    try {
      // 로컬 스토리지에서 삭제
      await EventStorageService.removeEvent(event.date, event);

      // 컨트롤러에서 제거
      _controller.removeEvent(event);

      // 구글 이벤트인 경우 구글 캘린더에서도 삭제
      if (event.source == 'google') {
        try {
          // 구글 캘린더 서비스가 초기화되었는지 확인
          if (await _googleCalendarService.initialize()) {
            final deleted = await _googleCalendarService
                .deleteEventFromGoogleCalendar(event);
            if (deleted) {
              print('✅ 구글 캘린더에서 이벤트 삭제됨: ${event.title}');
            } else {
              print('⚠️ 구글 캘린더에서 이벤트 삭제 실패: ${event.title}');
            }
          }
        } catch (googleError) {
          print('❌ 구글 캘린더 삭제 중 오류: $googleError');
          // 구글 삭제 실패해도 로컬 삭제는 완료된 것으로 처리
        }
      }

      print('이벤트 삭제됨: ${event.title}');
    } catch (e) {
      print('이벤트 삭제 중 오류: $e');
      rethrow;
    }
  }

  /// 특정 이벤트 삭제 후 컨트롤러 갱신
  Future<void> removeEventAndRefresh(DateTime date, Event event) async {
    try {
      print('🗑️ EventManager: 이벤트 삭제 및 새로고침 시작...');
      print('   삭제할 이벤트: ${event.title} (${date.toString().substring(0, 10)})');

      // 1. 스토리지에서 이벤트 삭제
      await EventStorageService.removeEvent(date, event);

      // 2. 컨트롤러에서도 이벤트 제거
      _controller.removeEvent(event);

      // 구글 이벤트인 경우 구글 캘린더에서도 삭제
      if (event.source == 'google') {
        try {
          // 구글 캘린더 서비스가 초기화되었는지 확인
          if (await _googleCalendarService.initialize()) {
            final deleted = await _googleCalendarService
                .deleteEventFromGoogleCalendar(event);
            if (deleted) {
              print('✅ 구글 캘린더에서 이벤트 삭제됨: ${event.title}');
            } else {
              print('⚠️ 구글 캘린더에서 이벤트 삭제 실패: ${event.title}');
            }
          }
        } catch (googleError) {
          print('❌ 구글 캘린더 삭제 중 오류: $googleError');
          // 구글 삭제 실패해도 로컬 삭제는 완료된 것으로 처리
        }
      }

      // 3. 해당 날짜 이벤트 다시 로드하여 동기화
      await loadEventsForDay(date);

      print('✅ EventManager: 이벤트 삭제 및 새로고침 완료');
    } catch (e) {
      print('❌ EventManager: 이벤트 삭제 중 오류: $e');
      rethrow;
    }
  }

  /// 현재 월의 모든 이벤트 새로고침
  Future<void> refreshCurrentMonthEvents() async {
    final currentMonth = _controller.focusedDay;
    final startOfMonth = DateTime(currentMonth.year, currentMonth.month, 1);
    final endOfMonth = DateTime(currentMonth.year, currentMonth.month + 1, 0);

    // 해당 월의 모든 날짜에 대해 이벤트 로드
    for (int day = startOfMonth.day; day <= endOfMonth.day; day++) {
      final date = DateTime(currentMonth.year, currentMonth.month, day);
      await loadEventsForDay(date);
    }
  }

  /// Google 캘린더와 동기화 (중복 방지 시스템 적용)
  Future<void> syncWithGoogleCalendar() async {
    try {
      print('🔄 EventManager: Google Calendar 동기화 시작...');

      if (!await _googleCalendarService.initialize()) {
        throw Exception('Google Calendar 초기화 실패');
      }

      // 색상 정보 동기화 (새로 추가)
      await _googleCalendarService.syncColorMappingsToController(_controller);

      // 현재 연도의 시작과 끝 날짜 계산
      final DateTime startOfYear = DateTime(_controller.focusedDay.year, 1, 1);
      final DateTime endOfYear = DateTime(_controller.focusedDay.year, 12, 31);

      // 🔥 1단계: 스토리지에서 구글 이벤트 맵 구성 (ID 기반 빠른 참조용)
      print('🔍 기존 Google 이벤트 맵 구축 중...');
      Map<String, List<Event>> oldGoogleEventsMap = {};

      // 날짜별로 기존 구글 이벤트 수집
      DateTime currentDate = startOfYear;
      while (currentDate.isBefore(endOfYear) ||
          currentDate.isAtSameMomentAs(endOfYear)) {
        final dateEvents = await EventStorageService.getEvents(currentDate);
        final googleEvents =
            dateEvents
                .where((e) => e.source == 'google' || e.source == 'holiday')
                .toList();

        if (googleEvents.isNotEmpty) {
          oldGoogleEventsMap[_formatDateKey(currentDate)] = googleEvents;
        }

        currentDate = currentDate.add(const Duration(days: 1));
      }

      print('📊 기존 구글 이벤트 맵 구축 완료: ${oldGoogleEventsMap.length}일치 데이터');

      // 2단계: 기존 Google/공휴일 이벤트들을 메모리에서 먼저 정리
      print('🧹 기존 Google/공휴일 이벤트 메모리에서 정리 중...');
      _controller.removeEventsBySource('google');
      _controller.removeEventsBySource('holiday');

      // 3단계: Google Calendar에서 새로운 이벤트 가져오기
      print('📥 Google Calendar에서 새 이벤트 가져오기...');
      final List<Event> googleEvents = await _googleCalendarService
          .syncWithGoogleCalendarIncludingHolidays(
            startDate: startOfYear,
            endDate: endOfYear,
          );

      // 4단계: 새로 가져온 구글 이벤트를 날짜별로 매핑
      print('🗺️ 새 Google 이벤트 맵 구축 중...');
      Map<String, List<Event>> newGoogleEventsMap = {};
      for (var event in googleEvents) {
        final dateKey = _formatDateKey(event.date);
        if (!newGoogleEventsMap.containsKey(dateKey)) {
          newGoogleEventsMap[dateKey] = [];
        }
        newGoogleEventsMap[dateKey]!.add(event);
      } // 5단계: 삭제된 이벤트 처리 및 새 이벤트 저장
      print('🔄 Google 이벤트 동기화 적용 중...');
      int addedCount = 0;
      int skippedCount = 0;
      int removedCount = 0;

      // 메모리에서 구글 이벤트 명시적 제거 (기존 참조 깨기)
      _controller.removeEventsBySource('google');
      _controller.removeEventsBySource('holiday');

      // 스토리지에서 구글 이벤트 전체 삭제
      print('🧹 스토리지에서 구글 이벤트 정리 중...');
      await _clearGoogleEventsFromStorage(startOfYear, endOfYear);

      // 날짜별로 새 이벤트 저장
      for (var dateKey in newGoogleEventsMap.keys) {
        final events = newGoogleEventsMap[dateKey]!;
        final date = _parseDateKey(dateKey);

        for (var event in events) {
          // 로컬 이벤트와 중복 체크
          final existingEvents = await EventStorageService.getEvents(date);
          final isDuplicateWithLocal = existingEvents.any(
            (existingEvent) =>
                existingEvent.title.trim().toLowerCase() ==
                    event.title.trim().toLowerCase() &&
                existingEvent.time == event.time &&
                existingEvent.source != 'google' &&
                existingEvent.source != 'holiday',
          );

          if (isDuplicateWithLocal) {
            print(
              '🚫 로컬 이벤트와 중복되어 Google 이벤트 제외: ${event.title} (${event.time})',
            );
            skippedCount++;
            continue;
          }

          // Google 소스로 명시하여 저장
          final googleEvent = Event(
            title: event.title,
            time: event.time,
            date: event.date,
            source: event.source == 'holiday' ? 'holiday' : 'google',
            description: event.description,
            colorId: event.colorId,
            color: event.color,
          );
          await EventStorageService.addEvent(date, googleEvent);
          _controller.addEvent(googleEvent);
          addedCount++;

          // 색상 처리
          if (_controller.getEventIdColor(googleEvent.uniqueId) == null) {
            Color eventColor;
            if (googleEvent.source == 'holiday') {
              eventColor = Colors.deepOrange; // 공휴일은 주황색
            } else if (googleEvent.colorId != null &&
                _controller.getColorIdColor(googleEvent.colorId!) != null) {
              eventColor = _controller.getColorIdColor(googleEvent.colorId!)!;
            } else {
              eventColor = Colors.lightBlue; // 기본 Google 이벤트 색상
            }

            _controller.setEventIdColor(googleEvent.uniqueId, eventColor);
            if (_controller.getEventColor(googleEvent.title) == null) {
              _controller.setEventColor(googleEvent.title, eventColor);
            }
          }
        }
      }

      // 삭제된 이벤트 분석
      final oldDateKeys = oldGoogleEventsMap.keys.toSet();
      final newDateKeys = newGoogleEventsMap.keys.toSet();
      final datesWithRemovedEvents = oldDateKeys.difference(newDateKeys);
      removedCount = datesWithRemovedEvents.length;
      // 6단계: 현재 표시 중인 월의 이벤트 강제 새로고침
      print('🔄 현재 월 이벤트 강제 새로고침 중...');
      final currentMonth = _controller.focusedDay;
      final startOfMonth = DateTime(currentMonth.year, currentMonth.month, 1);
      final endOfMonth = DateTime(currentMonth.year, currentMonth.month + 1, 0);

      // 날짜별로 이벤트 강제 새로고침
      for (int day = startOfMonth.day; day <= endOfMonth.day; day++) {
        final date = DateTime(currentMonth.year, currentMonth.month, day);
        await loadEventsForDay(date, forceRefresh: true);
      }

      print(
        '✅ EventManager: Google Calendar 동기화 완료\n'
        '- 추가: $addedCount개\n'
        '- 중복 제외: $skippedCount개\n'
        '- 삭제된 이벤트 포함 날짜: $removedCount일\n'
        '- 총 ${newGoogleEventsMap.length}일치 데이터 동기화됨',
      );
    } catch (e) {
      print('❌ EventManager: Google Calendar 동기화 중 오류: $e');
      rethrow;
    }
  }

  // 날짜 키 포맷팅 헬퍼 (YYYY-MM-DD 형식)
  String _formatDateKey(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  // 날짜 키 파싱 헬퍼
  DateTime _parseDateKey(String key) {
    final parts = key.split('-');
    return DateTime(
      int.parse(parts[0]),
      int.parse(parts[1]),
      int.parse(parts[2]),
    );
  }

  /// 스토리지에서 Google/공휴일 이벤트들을 제거하는 메서드
  Future<void> _clearGoogleEventsFromStorage(
    DateTime startDate,
    DateTime endDate,
  ) async {
    try {
      // 지정된 기간의 모든 날짜에 대해 Google/공휴일 이벤트 삭제
      DateTime currentDate = startDate;
      while (currentDate.isBefore(endDate) ||
          currentDate.isAtSameMomentAs(endDate)) {
        final events = await EventStorageService.getEventsForDate(currentDate);
        final localEvents =
            events
                .where(
                  (event) =>
                      event.source != 'google' && event.source != 'holiday',
                )
                .toList();

        // 로컬 이벤트만 남기고 다시 저장
        if (localEvents.length != events.length) {
          await EventStorageService.clearEventsForDate(currentDate);
          for (var localEvent in localEvents) {
            await EventStorageService.addEvent(currentDate, localEvent);
          }
        }

        final nextDate = DateTime(
          currentDate.year,
          currentDate.month,
          currentDate.day + 1,
        );
        if (nextDate == currentDate) break; // 무한 루프 방지
        currentDate = nextDate;
      }
    } catch (e) {
      print('❌ 기존 Google 이벤트 정리 실패: $e');
    }
  }

  /// 로컬 이벤트를 Google Calendar에 업로드 (중복 방지 포함)
  Future<void> uploadToGoogleCalendar({bool cleanupExisting = false}) async {
    try {
      print('🔄 EventManager: Google Calendar 업로드 시작...');

      if (!await _googleCalendarService.initialize()) {
        throw Exception('Google Calendar 초기화 실패');
      }

      // 색상 정보 먼저 동기화
      await _googleCalendarService.syncColorMappingsToController(
        _controller,
      ); // 현재 월의 모든 로컬 이벤트 가져오기
      final currentMonth = _controller.focusedDay;
      final startOfMonth = DateTime(currentMonth.year, currentMonth.month, 1);
      final endOfMonth = DateTime(currentMonth.year, currentMonth.month + 1, 0);

      // 이벤트 초기화 옵션이 켜져있는 경우, 기존 이벤트를 모두 삭제
      if (cleanupExisting) {
        print('🧹 구글 캘린더 이벤트 초기화 시작...');
        try {
          // 기존 이벤트 가져오기
          final googleEvents = await _googleCalendarService
              .getEventsFromGoogleCalendar(
                startDate: startOfMonth,
                endDate: endOfMonth,
              );

          if (googleEvents.isNotEmpty) {
            print('🗑️ ${googleEvents.length}개의 기존 구글 이벤트 삭제 시도');
            final results = await _googleCalendarService
                .deleteMultipleEventsFromGoogle(googleEvents);
            final successCount = results.values.where((v) => v).length;
            print(
              '✅ $successCount개 삭제 완료, ${results.length - successCount}개 삭제 실패',
            );
          }
        } catch (e) {
          print('⚠️ 구글 캘린더 초기화 중 오류: $e');
          // 초기화 실패해도 계속 진행
        }
      }

      List<Event> localEvents = [];
      // 로컬 이벤트만 필터링 (구글/공휴일 제외)
      for (int day = startOfMonth.day; day <= endOfMonth.day; day++) {
        final date = DateTime(currentMonth.year, currentMonth.month, day);
        final dayEvents =
            _controller
                .getEventsForDay(date)
                .where((e) => e.source == 'local')
                .toList();
        localEvents.addAll(dayEvents);
      }

      print('📤 업로드 대상 로컬 이벤트 수: ${localEvents.length}');

      // Google Calendar에서 같은 기간의 기존 이벤트 가져오기
      final List<Event> googleEvents = await _googleCalendarService
          .getEventsFromGoogleCalendar(
            startDate: startOfMonth,
            endDate: endOfMonth,
          );

      print('📥 Google Calendar 기존 이벤트 수: ${googleEvents.length}');

      int uploadedCount = 0;
      int skippedCount = 0;

      // 각 로컬 이벤트에 대해 중복 체크 후 업로드
      for (var localEvent in localEvents) {
        // 중복 체크: 제목, 날짜, 시간이 모두 같은 이벤트가 있는지 확인
        bool isDuplicate = googleEvents.any((googleEvent) {
          return googleEvent.title == localEvent.title &&
              googleEvent.date.year == localEvent.date.year &&
              googleEvent.date.month == localEvent.date.month &&
              googleEvent.date.day == localEvent.date.day &&
              googleEvent.time == localEvent.time;
        });

        if (isDuplicate) {
          print(
            '⏭️ 중복 이벤트 업로드 건너뜀: ${localEvent.title} (${localEvent.date.toString().substring(0, 10)} ${localEvent.time})',
          );
          skippedCount++;
          continue;
        }

        // 중복이 아니면 Google Calendar에 업로드
        try {
          final success = await _googleCalendarService.addEventToGoogleCalendar(
            localEvent,
          );
          if (success) {
            print(
              '✅ 업로드 성공: ${localEvent.title} (${localEvent.date.toString().substring(0, 10)} ${localEvent.time})',
            );
            uploadedCount++;
          } else {
            print('❌ 업로드 실패: ${localEvent.title}');
          }
        } catch (e) {
          print('❌ 업로드 중 오류: ${localEvent.title} - $e');
        }
      }
      print('📊 Google Calendar 업로드 완료:');
      print('   • 신규 업로드: $uploadedCount개');
      print('   • 중복으로 건너뜀: $skippedCount개');
      print('   • 총 로컬 이벤트: ${localEvents.length}개');

      // 색상 매핑 정보를 컨트롤러에 동기화
      await _googleCalendarService.syncColorMappingsToController(_controller);
      print('🎨 색상 매핑 동기화 완료');
    } catch (e) {
      print('❌ Google Calendar 업로드 중 오류: $e');
      rethrow;
    }
  }

  /// 초기 데이터 로드 (중복 방지 개선)
  Future<void> loadInitialData() async {
    try {
      print('📥 초기 데이터 로드 시작...');

      // 1. 먼저 전체 중복 이벤트 정리
      await EventStorageService.cleanupAllDuplicateEvents();

      // 2. 🔥 현재 월만 로드 (중복 방지)
      final today = DateTime.now();
      await loadEventsForMonth(today);

      // 3. 로드된 로컬 일정 개수 확인
      final currentMonthEvents = _controller.getEventsForDay(today);
      final localEvents =
          currentMonthEvents.where((e) => e.source == 'local').toList();
      print('📊 초기 로드 완료 - 오늘 날짜 로컬 일정: ${localEvents.length}개');

      if (localEvents.isNotEmpty) {
        print('💾 저장된 로컬 일정들:');
        for (var event in localEvents) {
          print('   - ${event.title} (${event.time})');
        }
      }

      print('✅ 초기 데이터 로드 완료');
    } catch (e) {
      print('❌ 초기 데이터 로드 중 오류: $e');
    }
  }

  /// 수동 중복 정리 메서드
  Future<void> cleanupDuplicateEvents() async {
    try {
      print('🧹 수동 중복 정리 시작...');

      await EventStorageService.cleanupAllDuplicateEvents();

      // 컨트롤러 캐시도 새로고침
      await refreshCurrentMonthEvents();

      print('✅ 수동 중복 정리 완료');
    } catch (e) {
      print('❌ 중복 정리 중 오류: $e');
      rethrow;
    }
  }

  /// 기존 이벤트의 색상을 11가지 Google 표준 색상으로 마이그레이션
  Future<void> migrateEventsToStandardColors() async {
    try {
      print('🎨 기존 이벤트 색상 마이그레이션 시작...');

      final now = DateTime.now();
      final startOfYear = DateTime(now.year, 1, 1);
      final endOfYear = DateTime(now.year, 12, 31);

      int migratedCount = 0;
      DateTime currentDate = startOfYear;

      while (currentDate.isBefore(endOfYear) ||
          currentDate.isAtSameMomentAs(endOfYear)) {
        final events = await EventStorageService.getEvents(currentDate);
        bool hasChanges = false;

        for (var event in events) {
          // 로컬 이벤트만 마이그레이션 (Google/공휴일 이벤트 제외)
          if (event.source == 'local' && !event.hasCustomColor()) {
            // 랜덤 색상 ID 할당 (1-11)
            final randomColorId = (_random.nextInt(11) + 1);
            final migratedEvent = event.withColorId(randomColorId);

            // 기존 이벤트 제거 후 새 이벤트 추가
            await EventStorageService.removeEvent(currentDate, event);
            await EventStorageService.addEvent(currentDate, migratedEvent);

            print('🎨 마이그레이션: ${event.title} -> colorId: $randomColorId');
            migratedCount++;
            hasChanges = true;
          }
        }

        // 변경사항이 있으면 컨트롤러 캐시 갱신
        if (hasChanges) {
          await loadEventsForDay(currentDate);
        }

        currentDate = currentDate.add(const Duration(days: 1));
      }

      print('✅ 색상 마이그레이션 완료: $migratedCount개 이벤트 처리됨');
    } catch (e) {
      print('❌ 색상 마이그레이션 중 오류: $e');
      rethrow;
    }
  }
}
