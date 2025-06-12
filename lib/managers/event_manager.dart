import '../models/event.dart';
import '../services/event_storage_service.dart';
import '../services/google_calendar_service.dart';
import '../controllers/calendar_controller.dart';
import 'package:flutter/material.dart';
import 'dart:math';
import 'sync_manager.dart';

/// 이벤트 관련 로직을 처리하는 매니저 클래스
class EventManager {
  final CalendarController _controller;
  final GoogleCalendarService _googleCalendarService = GoogleCalendarService();
  final Random _random = Random();
  // SyncManager 속성 추가
  late final SyncManager _syncManager;
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

  // 생성자 수정
  EventManager(this._controller) {
    // SyncManager 초기화 - 의존성 주입
    _syncManager = SyncManager(this, _controller);
  }

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

  /// 월 변경 시 호출되는 메서드 - 전체 월의 이벤트를 한번에 로드 (진짜 한번에)
  Future<void> loadEventsForMonth(DateTime month) async {
    try {
      print('📅 월별 이벤트 로딩 시작: ${month.year}년 ${month.month}월');

      final firstDay = DateTime(month.year, month.month, 1);
      final lastDay = DateTime(month.year, month.month + 1, 0);

      // 🔥 핵심: 전체 월의 모든 이벤트를 한 번의 쿼리로 가져오기
      final allMonthEvents = await EventStorageService.getEventsForDateRange(
        firstDay,
        lastDay,
      );

      // 날짜별로 그룹핑
      Map<DateTime, List<Event>> eventsByDate = {};

      for (var event in allMonthEvents) {
        final normalizedDate = DateTime(
          event.date.year,
          event.date.month,
          event.date.day,
        );
        eventsByDate[normalizedDate] ??= [];
        eventsByDate[normalizedDate]!.add(event);
      }

      // 각 날짜별로 캐시에 저장 및 색상 처리
      for (
        DateTime day = firstDay;
        day.isBefore(lastDay.add(Duration(days: 1)));
        day = day.add(Duration(days: 1))
      ) {
        final normalizedDay = DateTime(day.year, day.month, day.day);
        final dayEvents = eventsByDate[normalizedDay] ?? [];

        // 기존 이벤트 완전 교체
        _controller.clearEventsForDay(normalizedDay);

        // 새 이벤트들 추가 및 색상 처리
        for (var event in dayEvents) {
          _controller.addEvent(event);

          // 색상이 없는 이벤트에 색상 할당
          if (_controller.getEventIdColor(event.uniqueId) == null) {
            Color eventColor;
            if (event.source == 'holiday') {
              eventColor = Colors.deepOrange;
            } else if (event.source == 'google') {
              if (event.colorId != null &&
                  _controller.getColorIdColor(event.colorId!) != null) {
                eventColor = _controller.getColorIdColor(event.colorId!)!;
              } else {
                eventColor = Colors.lightBlue;
              }
            } else {
              eventColor =
                  _standardColors[_random.nextInt(_standardColors.length)];
            }

            _controller.setEventIdColor(event.uniqueId, eventColor);

            if (_controller.getEventColor(event.title) == null) {
              _controller.setEventColor(event.title, eventColor);
            }
          }
        }

        _controller.setDateLoading(normalizedDay, false);
      }

      print(
        '✅ 월별 이벤트 로딩 완료: ${month.year}년 ${month.month}월 - 총 ${allMonthEvents.length}개 이벤트',
      );
    } catch (e) {
      print('❌ 월별 이벤트 로딩 실패: $e');
    }
  }

  /// 이벤트 추가 (중복 체크 강화, 동기화 개선)
  Future<void> addEvent(Event event, {bool syncWithGoogle = true}) async {
    try {
      // 멀티데이 이벤트인 경우 특별 처리
      if (event.isMultiDay && event.startDate != null && event.endDate != null) {
        await addMultiDayEvent(event, syncWithGoogle: syncWithGoogle);
        return;
      }

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
        print('⚠️ 중복 이벤트 감지되었지만 계속 진행: ${event.title} (${event.time})');
        // 중복이어도 계속 진행
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
        print('⚠️ 캐시에 중복 이벤트 감지되었지만 계속 진행: ${event.title} (${event.time})');
        // 중복이어도 계속 진행
      } // 3. 색상 ID가 없는 경우 랜덤 색상 ID 할당 (Google Calendar와 동기화를 위해)
      Event eventToSave = event;
      if (event.colorId == null) {
        // 랜덤 색상 ID 할당 (1-11)
        final randomColorId = (1 + _random.nextInt(11)).toString();
        eventToSave = Event(
          title: event.title,
          time: event.time,
          date: event.date,
          description: event.description,
          source: event.source,
          colorId: randomColorId, // 랜덤 색상 ID 할당
          uniqueId: event.uniqueId,
          endTime: event.endTime,
        );
        print('🎨 랜덤 색상 ID 할당: ${event.title} -> colorId: $randomColorId');
      }

      // 4. 저장
      await EventStorageService.addEvent(eventToSave.date, eventToSave);

      // 5. 컨트롤러에 추가
      _controller.addEvent(eventToSave);

      // 6. 색상 할당
      if (_controller.getEventColor(eventToSave.title) == null) {
        final color =
            eventToSave.colorId != null
                ? _standardColors[int.parse(eventToSave.colorId!) -
                    1] // colorId에 해당하는 색상
                : _standardColors[_random.nextInt(
                  _standardColors.length,
                )]; // 랜덤 색상
        _controller.setEventColor(eventToSave.title, color);
      }

      // 7. 이벤트 ID 기반 색상 매핑 (신규)
      if (eventToSave.colorId != null) {
        final colorId = int.tryParse(eventToSave.colorId!);
        if (colorId != null && colorId >= 1 && colorId <= 11) {
          final color = _standardColors[colorId - 1];
          _controller.setEventIdColor(eventToSave.uniqueId, color);
        }
      }

      // 8. Google 동기화 진행 (옵션에 따라)
      if (syncWithGoogle && eventToSave.source == 'local') {
        await _syncManager.syncEventAddition(eventToSave);
      }

      print('✅ 이벤트 추가됨: ${event.title}');
    } catch (e) {
      print('❌ 이벤트 추가 중 오류: $e');
      rethrow;
    }
  }

  /// 🆕 멀티데이 이벤트 추가 (영구 저장 포함)
  Future<void> addMultiDayEvent(Event event, {bool syncWithGoogle = true}) async {
    try {
      if (!event.isMultiDay || event.startDate == null || event.endDate == null) {
        throw Exception('유효하지 않은 멀티데이 이벤트입니다.');
      }

      print('📅 멀티데이 이벤트 추가 시작: ${event.title} (${event.startDate} ~ ${event.endDate})');

      final startDate = event.startDate!;
      final endDate = event.endDate!;
      
      // 각 날짜에 멀티데이 이벤트 저장
      for (int i = 0; i <= endDate.difference(startDate).inDays; i++) {
        final currentDate = startDate.add(Duration(days: i));
        
        // 해당 날짜용 이벤트 생성
        final dailyEvent = event.copyWith(
          date: currentDate,
          // 멀티데이 이벤트임을 식별할 수 있도록 uniqueId에 특별한 패턴 추가
          uniqueId: event.uniqueId.contains('_multiday_') 
              ? event.uniqueId 
              : '${event.uniqueId}_multiday_${i}',
        );

        // 중복 체크
        final existingEvents = await EventStorageService.getEvents(currentDate);
        final isDuplicate = existingEvents.any(
          (e) => e.uniqueId == dailyEvent.uniqueId || 
                 (e.title.trim().toLowerCase() == dailyEvent.title.trim().toLowerCase() &&
                  e.time == dailyEvent.time &&
                  e.isMultiDay),
        );

        if (!isDuplicate) {
          // 스토리지에 저장
          await EventStorageService.addEvent(currentDate, dailyEvent);
          
          // 컨트롤러에 추가
          _controller.addEvent(dailyEvent);
          
          // 색상 설정
          if (_controller.getEventIdColor(dailyEvent.uniqueId) == null) {
            final color = event.color ?? Colors.purple;
            _controller.setEventIdColor(dailyEvent.uniqueId, color);
            _controller.setEventColor(dailyEvent.title, color);
          }
          
          print('✅ 멀티데이 이벤트 날짜별 저장: ${currentDate.toString().substring(0, 10)}');
        } else {
          print('⚠️ 멀티데이 이벤트 중복 감지: ${currentDate.toString().substring(0, 10)}');
        }
      }

      // Google 동기화 (필요한 경우)
      if (syncWithGoogle && event.source == 'local') {
        await _syncManager.syncEventAddition(event);
      }

      print('✅ 멀티데이 이벤트 추가 완료: ${event.title}');
    } catch (e) {
      print('❌ 멀티데이 이벤트 추가 중 오류: $e');
      rethrow;
    }
  }

  /// 이벤트 수정
  Future<void> updateEvent(
    Event originalEvent,
    Event updatedEvent, {
    bool syncWithGoogle = true,
  }) async {
    try {
      print(
        '🔄 EventManager: 이벤트 수정 시작 - ${originalEvent.title} -> ${updatedEvent.title}',
      );

      // 1. 원본 이벤트 삭제
      await EventStorageService.removeEvent(originalEvent.date, originalEvent);
      _controller.removeEvent(originalEvent);

      // 2. 수정된 이벤트를 원래 날짜가 아닌 경우 새로운 날짜에 추가
      final eventToSave = updatedEvent.copyWith(
        uniqueId: originalEvent.uniqueId, // 고유 ID 유지
      );

      // 3. 새 이벤트 저장
      await EventStorageService.addEvent(eventToSave.date, eventToSave);
      _controller.addEvent(eventToSave);

      // 4. 색상 정보 유지
      final originalColor = _controller.getEventIdColor(originalEvent.uniqueId);
      if (originalColor != null) {
        _controller.setEventIdColor(eventToSave.uniqueId, originalColor);
      }

      // 5. Google 동기화 진행 (옵션에 따라)
      if (syncWithGoogle) {
        await _syncManager.syncEventUpdate(originalEvent, eventToSave);
      }

      print('✅ EventManager: 이벤트 수정 완료 - ${eventToSave.title}');
    } catch (e) {
      print('❌ EventManager: 이벤트 수정 실패 - ${originalEvent.title}: $e');
      rethrow;
    }
  }

  /// 색상 ID를 지정하여 이벤트 추가 (동기화 추가)
  Future<void> addEventWithColorId(
    Event event,
    int colorId, {
    bool syncWithGoogle = true,
  }) async {
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
          '⚠️ 중복 이벤트 감지되었지만 계속 진행: ${coloredEvent.title} (${coloredEvent.time})',
        );
        // 중복이어도 계속 진행
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
        print('⚠️ 캐시에 중복 이벤트 감지되었지만 계속 진행: ${coloredEvent.title} (${coloredEvent.time})');
        // 중복이어도 계속 진행
      }

      // 저장 및 캐시 추가
      await EventStorageService.addEvent(coloredEvent.date, coloredEvent);
      _controller.addEvent(coloredEvent); // 컨트롤러에 색상 정보도 저장 (중복 우선순위 간소화)
      _controller.setEventIdColor(
        coloredEvent.uniqueId,
        coloredEvent.getDisplayColor(),
      );

      // Google 동기화 진행 (옵션에 따라)
      if (syncWithGoogle && coloredEvent.source == 'local') {
        await _syncManager.syncEventAddition(coloredEvent);
      }

      print('✅ 색상 지정 이벤트 추가됨: ${coloredEvent.title} (색상 ID: $colorId)');
    } catch (e) {
      print('❌ 색상 지정 이벤트 추가 중 오류: $e');
      rethrow;
    }
  }

  /// 이벤트 제거 (동기화 개선)
  Future<void> removeEvent(Event event, {bool syncWithGoogle = true}) async {
    try {
      // 멀티데이 이벤트인 경우 특별 처리
      if (event.isMultiDay && event.startDate != null && event.endDate != null) {
        await removeMultiDayEvent(event, syncWithGoogle: syncWithGoogle);
        return;
      }

      // 로컬 스토리지에서 삭제
      await EventStorageService.removeEvent(event.date, event);

      // 컨트롤러에서 제거
      _controller.removeEvent(event);

      // Google 동기화 진행 (옵션에 따라)
      if (syncWithGoogle) {
        await _syncManager.syncEventDeletion(event);
      }

      print('✅ 이벤트 삭제됨: ${event.title}');
    } catch (e) {
      print('❌ 이벤트 삭제 중 오류: $e');
      rethrow;
    }
  }

  /// 🆕 멀티데이 이벤트 제거 (영구 저장소에서도 제거)
  Future<void> removeMultiDayEvent(Event event, {bool syncWithGoogle = true}) async {
    try {
      if (!event.isMultiDay || event.startDate == null || event.endDate == null) {
        throw Exception('유효하지 않은 멀티데이 이벤트입니다.');
      }

      print('🗑️ 멀티데이 이벤트 제거 시작: ${event.title}');

      final startDate = event.startDate!;
      final endDate = event.endDate!;
      
      // 각 날짜에서 멀티데이 이벤트 제거
      for (int i = 0; i <= endDate.difference(startDate).inDays; i++) {
        final currentDate = startDate.add(Duration(days: i));
        
        // 해당 날짜의 모든 이벤트 가져오기
        final existingEvents = await EventStorageService.getEvents(currentDate);
        
        // 같은 uniqueId 패턴을 가진 이벤트들 찾기
        final eventsToRemove = existingEvents.where((e) => 
          e.uniqueId.contains(event.uniqueId.split('_multiday_')[0]) && 
          e.isMultiDay &&
          e.title == event.title
        ).toList();
        
        // 스토리지에서 제거
        for (final eventToRemove in eventsToRemove) {
          await EventStorageService.removeEvent(currentDate, eventToRemove);
          print('🗑️ 멀티데이 이벤트 날짜별 제거: ${currentDate.toString().substring(0, 10)}');
        }
        
        // 컨트롤러에서도 제거
        _controller.removeMultiDayEvent(event);
      }

      // Google 동기화 (필요한 경우)
      if (syncWithGoogle) {
        await _syncManager.syncEventDeletion(event);
      }

      print('✅ 멀티데이 이벤트 제거 완료: ${event.title}');
    } catch (e) {
      print('❌ 멀티데이 이벤트 제거 중 오류: $e');
      rethrow;
    }
  }

  /// 특정 이벤트 삭제 후 컨트롤러 갱신 (동기화 개선)
  Future<void> removeEventAndRefresh(
    DateTime date,
    Event event, {
    bool syncWithGoogle = true,
  }) async {
    try {
      print('🗑️ EventManager: 이벤트 삭제 및 새로고침 시작...');
      print('   삭제할 이벤트: ${event.title} (${date.toString().substring(0, 10)})');

      // 1. 스토리지에서 이벤트 삭제
      await EventStorageService.removeEvent(date, event);

      // 2. 컨트롤러에서도 이벤트 제거
      _controller.removeEvent(event);

      // 3. Google 동기화 진행 (옵션에 따라)
      if (syncWithGoogle) {
        await _syncManager.syncEventDeletion(event);
      }

      // 4. 해당 날짜 이벤트 다시 로드하여 동기화
      await loadEventsForDay(date, forceRefresh: true);

      print('✅ EventManager: 이벤트 삭제 및 새로고침 완료');
    } catch (e) {
      print('❌ EventManager: 이벤트 삭제 중 오류: $e');
      rethrow;
    }
  }

  /// 현재 월의 모든 이벤트 새로고침 (강제 갱신 옵션 추가)
  Future<void> refreshCurrentMonthEvents({bool forceRefresh = true}) async {
    print('🔄 EventManager: 현재 월 이벤트 새로고침 시작 (강제 갱신: $forceRefresh)');
    final currentMonth = _controller.focusedDay;
    final startOfMonth = DateTime(currentMonth.year, currentMonth.month, 1);
    final endOfMonth = DateTime(currentMonth.year, currentMonth.month + 1, 0);

    // 현재 선택된 날짜는 우선적으로 갱신 (가장 중요한 UI 영역)
    final selectedDay = _controller.selectedDay;
    if (selectedDay.month == currentMonth.month &&
        selectedDay.year == currentMonth.year) {
      print('🎯 EventManager: 선택된 날짜 ($selectedDay) 강제 갱신');
      await loadEventsForDay(selectedDay, forceRefresh: true);
    }

    // 해당 월의 모든 날짜에 대해 이벤트 로드
    for (int day = startOfMonth.day; day <= endOfMonth.day; day++) {
      final date = DateTime(currentMonth.year, currentMonth.month, day);
      // 이미 갱신한 선택된 날짜는 건너뜀
      if (date.day == selectedDay.day &&
          date.month == selectedDay.month &&
          date.year == selectedDay.year) {
        continue;
      }
      await loadEventsForDay(date, forceRefresh: forceRefresh);
    }

    print('✅ EventManager: 현재 월 이벤트 새로고침 완료');
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
          final googleEventId = await _googleCalendarService
              .addEventToGoogleCalendar(localEvent);
          if (googleEventId != null) {
            print(
              '✅ 업로드 성공: ${localEvent.title} (${localEvent.date.toString().substring(0, 10)} ${localEvent.time})',
            );
            uploadedCount++;

            // 로컬 이벤트에 Google Event ID 저장
            try {
              final updatedEvent = localEvent.copyWith(
                googleEventId: googleEventId,
              );
              await EventStorageService.removeEvent(
                localEvent.date,
                localEvent,
              );
              await EventStorageService.addEvent(localEvent.date, updatedEvent);
              _controller.removeEvent(localEvent);
              _controller.addEvent(updatedEvent);
              print(
                '🔗 Google Event ID 저장: ${localEvent.title} -> $googleEventId',
              );
            } catch (e) {
              print('⚠️ Google Event ID 저장 실패: $e');
            }
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
