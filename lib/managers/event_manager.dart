// lib/managers/event_manager.dart (최종 수정본 - 전체 코드 복원)
import '../models/event.dart';
import '../services/event_storage_service.dart';
import '../services/google_calendar_service.dart';
import '../controllers/calendar_controller.dart';
import 'package:flutter/material.dart';
import 'dart:math';
import 'sync_manager.dart';
import '../services/tts_service.dart'; // TtsService 임포트

class EventManager {
  final CalendarController _controller;
  final GoogleCalendarService _googleCalendarService = GoogleCalendarService();
  final Random _random = Random();
  late final SyncManager _syncManager;
  
  // TtsService 인스턴스를 저장할 변수
  final TtsService ttsService; 

  final List<Color> _standardColors = [
    const Color(0xFF9AA0F5), const Color(0xFF33B679), const Color(0xFF8E24AA),
    const Color(0xFFE67C73), const Color(0xFFF6BF26), const Color(0xFFFF8A65),
    const Color(0xFF039BE5), const Color(0xFF616161), const Color(0xFF3F51B5),
    const Color(0xFF0B8043), const Color(0xFFD50000),
  ];

  // 생성자에서 TtsService를 필수로 받도록 변경
  EventManager(this._controller, {required this.ttsService}) {
    _syncManager = SyncManager(this, _controller);
  }
  
  // (이하 보내주신 700줄 이상의 모든 기존 함수들은 수정 없이 그대로 유지됩니다)

  Future<void> loadEventsForDay(DateTime day, {bool forceRefresh = false}) async {
    final normalizedDay = DateTime(day.year, day.month, day.day);
    if (!forceRefresh && !_controller.shouldLoadEventsForDay(normalizedDay)) {
      print('📋 이미 로드됨 또는 로딩 중, 스킵: ${normalizedDay.toString()}');
      return;
    }
    _controller.setDateLoading(normalizedDay, true);
    try {
      final events = await EventStorageService.getEvents(normalizedDay);
      _controller.clearEventsForDay(normalizedDay);
      for (var event in events) {
        _controller.addEvent(event);
        if (_controller.getEventIdColor(event.uniqueId) == null) {
          Color eventColor;
          if (event.source == 'holiday') {
            eventColor = Colors.deepOrange;
          } else if (event.source == 'google') {
            if (event.colorId != null && _controller.getColorIdColor(event.colorId!) != null) {
              eventColor = _controller.getColorIdColor(event.colorId!)!;
            } else {
              eventColor = Colors.lightBlue;
            }
          } else {
            eventColor = _standardColors[_random.nextInt(_standardColors.length)];
          }
          _controller.setEventIdColor(event.uniqueId, eventColor);
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

  Future<void> loadEventsForMonth(DateTime month) async {
    try {
      print('📅 월별 이벤트 로딩 시작: ${month.year}년 ${month.month}월');
      final firstDay = DateTime(month.year, month.month, 1);
      final lastDay = DateTime(month.year, month.month + 1, 0);
      final allMonthEvents = await EventStorageService.getEventsForDateRange(firstDay, lastDay);
      Map<DateTime, List<Event>> eventsByDate = {};
      for (var event in allMonthEvents) {
        final normalizedDate = DateTime(event.date.year, event.date.month, event.date.day);
        eventsByDate.putIfAbsent(normalizedDate, () => []).add(event);
      }
      for (DateTime day = firstDay; day.isBefore(lastDay.add(const Duration(days: 1))); day = day.add(const Duration(days: 1))) {
        final normalizedDay = DateTime(day.year, day.month, day.day);
        final dayEvents = eventsByDate[normalizedDay] ?? [];
        _controller.clearEventsForDay(normalizedDay);
        for (var event in dayEvents) {
          _controller.addEvent(event);
          if (_controller.getEventIdColor(event.uniqueId) == null) {
            Color eventColor;
            if (event.source == 'holiday') {
              eventColor = Colors.deepOrange;
            } else if (event.source == 'google') {
              if (event.colorId != null && _controller.getColorIdColor(event.colorId!) != null) {
                eventColor = _controller.getColorIdColor(event.colorId!)!;
              } else {
                eventColor = Colors.lightBlue;
              }
            } else {
              eventColor = _standardColors[_random.nextInt(_standardColors.length)];
            }
            _controller.setEventIdColor(event.uniqueId, eventColor);
            if (_controller.getEventColor(event.title) == null) {
              _controller.setEventColor(event.title, eventColor);
            }
          }
        }
        _controller.setDateLoading(normalizedDay, false);
      }
      print('✅ 월별 이벤트 로딩 완료: ${month.year}년 ${month.month}월 - 총 ${allMonthEvents.length}개 이벤트');
    } catch (e) {
      print('❌ 월별 이벤트 로딩 실패: $e');
    }
  }

  Future<void> addEvent(Event event, {bool syncWithGoogle = true}) async {
    try {
      final existingEvents = await EventStorageService.getEvents(event.date);
      if (existingEvents.any((e) => e.title.trim().toLowerCase() == event.title.trim().toLowerCase() && e.time == event.time && e.date.isAtSameMomentAs(event.date))) {
        throw Exception('이미 동일한 일정이 존재합니다');
      }
      final cachedEvents = _controller.getEventsForDay(event.date);
      if (cachedEvents.any((e) => e.title.trim().toLowerCase() == event.title.trim().toLowerCase() && e.time == event.time && e.date.isAtSameMomentAs(event.date))) {
        throw Exception('이미 동일한 일정이 존재합니다');
      }
      Event eventToSave = event;
      if (event.colorId == null) {
        eventToSave = event.copyWith(colorId: (1 + _random.nextInt(11)).toString());
      }
      await EventStorageService.addEvent(eventToSave.date, eventToSave);
      _controller.addEvent(eventToSave);
      if (_controller.getEventColor(eventToSave.title) == null) {
        _controller.setEventColor(eventToSave.title, eventToSave.getDisplayColor());
      }
      if (eventToSave.colorId != null) {
        final colorId = int.tryParse(eventToSave.colorId!);
        if (colorId != null && colorId >= 1 && colorId <= 11) {
          _controller.setEventIdColor(eventToSave.uniqueId, _standardColors[colorId - 1]);
        }
      }
      if (syncWithGoogle && eventToSave.source == 'local') {
        await _syncManager.syncEventAddition(eventToSave);
      }
      print('✅ 이벤트 추가됨: ${event.title}');
    } catch (e) {
      print('❌ 이벤트 추가 중 오류: $e');
      rethrow;
    }
  }

  Future<void> updateEvent(Event originalEvent, Event updatedEvent, {bool syncWithGoogle = true}) async {
    try {
      print('🔄 EventManager: 이벤트 수정 시작 - ${originalEvent.title} -> ${updatedEvent.title}');
      await EventStorageService.removeEvent(originalEvent.date, originalEvent);
      _controller.removeEvent(originalEvent);
      final eventToSave = updatedEvent.copyWith(uniqueId: originalEvent.uniqueId);
      await EventStorageService.addEvent(eventToSave.date, eventToSave);
      _controller.addEvent(eventToSave);
      final originalColor = _controller.getEventIdColor(originalEvent.uniqueId);
      if (originalColor != null) {
        _controller.setEventIdColor(eventToSave.uniqueId, originalColor);
      }
      if (syncWithGoogle) {
        await _syncManager.syncEventUpdate(originalEvent, eventToSave);
      }
      print('✅ EventManager: 이벤트 수정 완료 - ${eventToSave.title}');
    } catch (e) {
      print('❌ EventManager: 이벤트 수정 실패 - ${originalEvent.title}: $e');
      rethrow;
    }
  }

  Future<void> addEventWithColorId(Event event, int colorId, {bool syncWithGoogle = true}) async {
    try {
      final coloredEvent = event.withColorId(colorId);
      final existingEvents = await EventStorageService.getEvents(coloredEvent.date);
      if (existingEvents.any((e) => e.title.trim().toLowerCase() == coloredEvent.title.trim().toLowerCase() && e.time == coloredEvent.time && e.date.isAtSameMomentAs(coloredEvent.date))) {
        throw Exception('이미 동일한 일정이 존재합니다');
      }
      final cachedEvents = _controller.getEventsForDay(coloredEvent.date);
      if (cachedEvents.any((e) => e.title.trim().toLowerCase() == coloredEvent.title.trim().toLowerCase() && e.time == coloredEvent.time && e.date.isAtSameMomentAs(coloredEvent.date))) {
        throw Exception('이미 동일한 일정이 존재합니다');
      }
      await EventStorageService.addEvent(coloredEvent.date, coloredEvent);
      _controller.addEvent(coloredEvent);
      _controller.setEventIdColor(coloredEvent.uniqueId, coloredEvent.getDisplayColor());
      if (syncWithGoogle && coloredEvent.source == 'local') {
        await _syncManager.syncEventAddition(coloredEvent);
      }
      print('✅ 색상 지정 이벤트 추가됨: ${coloredEvent.title} (색상 ID: $colorId)');
    } catch (e) {
      print('❌ 색상 지정 이벤트 추가 중 오류: $e');
      rethrow;
    }
  }

  Future<void> removeEvent(Event event, {bool syncWithGoogle = true}) async {
    try {
      await EventStorageService.removeEvent(event.date, event);
      _controller.removeEvent(event);
      if (syncWithGoogle) {
        await _syncManager.syncEventDeletion(event);
      }
      print('✅ 이벤트 삭제됨: ${event.title}');
    } catch (e) {
      print('❌ 이벤트 삭제 중 오류: $e');
      rethrow;
    }
  }

  Future<void> removeEventAndRefresh(DateTime date, Event event, {bool syncWithGoogle = true}) async {
    try {
      print('🗑️ EventManager: 이벤트 삭제 및 새로고침 시작...');
      print('   삭제할 이벤트: ${event.title} (${date.toString().substring(0, 10)})');
      await EventStorageService.removeEvent(date, event);
      _controller.removeEvent(event);
      if (syncWithGoogle) {
        await _syncManager.syncEventDeletion(event);
      }
      await loadEventsForDay(date, forceRefresh: true);
      print('✅ EventManager: 이벤트 삭제 및 새로고침 완료');
    } catch (e) {
      print('❌ EventManager: 이벤트 삭제 중 오류: $e');
      rethrow;
    }
  }

  Future<void> refreshCurrentMonthEvents({bool forceRefresh = true}) async {
    print('🔄 EventManager: 현재 월 이벤트 새로고침 시작 (강제 갱신: $forceRefresh)');
    final currentMonth = _controller.focusedDay;
    final startOfMonth = DateTime(currentMonth.year, currentMonth.month, 1);
    final endOfMonth = DateTime(currentMonth.year, currentMonth.month + 1, 0);
    final selectedDay = _controller.selectedDay;
    if (selectedDay.month == currentMonth.month && selectedDay.year == currentMonth.year) {
      print('🎯 EventManager: 선택된 날짜 ($selectedDay) 강제 갱신');
      await loadEventsForDay(selectedDay, forceRefresh: true);
    }
    for (int day = startOfMonth.day; day <= endOfMonth.day; day++) {
      final date = DateTime(currentMonth.year, currentMonth.month, day);
      if (date.isAtSameMomentAs(DateTime(selectedDay.year, selectedDay.month, selectedDay.day))) {
        continue;
      }
      await loadEventsForDay(date, forceRefresh: forceRefresh);
    }
    print('✅ EventManager: 현재 월 이벤트 새로고침 완료');
  }

  Future<void> syncWithGoogleCalendar() async {
    try {
      print('🔄 EventManager: Google Calendar 동기화 시작...');
      if (!await _googleCalendarService.initialize()) {
        throw Exception('Google Calendar 초기화 실패');
      }
      await _googleCalendarService.syncColorMappingsToController(_controller);
      final DateTime startOfYear = DateTime(_controller.focusedDay.year, 1, 1);
      final DateTime endOfYear = DateTime(_controller.focusedDay.year, 12, 31);
      Map<String, List<Event>> oldGoogleEventsMap = {};
      DateTime currentDate = startOfYear;
      while (currentDate.isBefore(endOfYear.add(const Duration(days: 1)))) {
        final dateEvents = await EventStorageService.getEvents(currentDate);
        final googleEvents = dateEvents.where((e) => e.source == 'google' || e.source == 'holiday').toList();
        if (googleEvents.isNotEmpty) {
          oldGoogleEventsMap[_formatDateKey(currentDate)] = googleEvents;
        }
        currentDate = currentDate.add(const Duration(days: 1));
      }
      print('📊 기존 구글 이벤트 맵 구축 완료: ${oldGoogleEventsMap.length}일치 데이터');
      _controller.removeEventsBySource('google');
      _controller.removeEventsBySource('holiday');
      final List<Event> googleEvents = await _googleCalendarService.syncWithGoogleCalendarIncludingHolidays(startDate: startOfYear, endDate: endOfYear);
      Map<String, List<Event>> newGoogleEventsMap = {};
      for (var event in googleEvents) {
        newGoogleEventsMap.putIfAbsent(_formatDateKey(event.date), () => []).add(event);
      }
      int addedCount = 0, skippedCount = 0, removedCount = 0;
      await _clearGoogleEventsFromStorage(startOfYear, endOfYear);
      for (var dateKey in newGoogleEventsMap.keys) {
        final events = newGoogleEventsMap[dateKey]!;
        final date = _parseDateKey(dateKey);
        for (var event in events) {
          final existingEvents = await EventStorageService.getEvents(date);
          if (existingEvents.any((e) => e.title.trim().toLowerCase() == event.title.trim().toLowerCase() && e.time == event.time && e.source != 'google' && e.source != 'holiday')) {
            skippedCount++;
            continue;
          }
          final googleEvent = Event(title: event.title, time: event.time, date: event.date, source: event.source == 'holiday' ? 'holiday' : 'google', description: event.description, colorId: event.colorId, color: event.color);
          await EventStorageService.addEvent(date, googleEvent);
          _controller.addEvent(googleEvent);
          addedCount++;
          if (_controller.getEventIdColor(googleEvent.uniqueId) == null) {
            Color eventColor = googleEvent.source == 'holiday' ? Colors.deepOrange : (googleEvent.colorId != null && _controller.getColorIdColor(googleEvent.colorId!) != null ? _controller.getColorIdColor(googleEvent.colorId!)! : Colors.lightBlue);
            _controller.setEventIdColor(googleEvent.uniqueId, eventColor);
            if (_controller.getEventColor(googleEvent.title) == null) {
              _controller.setEventColor(googleEvent.title, eventColor);
            }
          }
        }
      }
      removedCount = oldGoogleEventsMap.keys.toSet().difference(newGoogleEventsMap.keys.toSet()).length;
      final currentMonth = _controller.focusedDay;
      await loadEventsForMonth(currentMonth);
      print('✅ EventManager: Google Calendar 동기화 완료\n- 추가: $addedCount개\n- 중복 제외: $skippedCount개\n- 삭제된 이벤트 포함 날짜: $removedCount일\n- 총 ${newGoogleEventsMap.length}일치 데이터 동기화됨');
    } catch (e) {
      print('❌ EventManager: Google Calendar 동기화 중 오류: $e');
      rethrow;
    }
  }

  String _formatDateKey(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  DateTime _parseDateKey(String key) {
    final parts = key.split('-');
    return DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
  }

  Future<void> _clearGoogleEventsFromStorage(DateTime startDate, DateTime endDate) async {
    try {
      for (DateTime currentDate = startDate; currentDate.isBefore(endDate.add(const Duration(days: 1))); currentDate = currentDate.add(const Duration(days: 1))) {
        final events = await EventStorageService.getEventsForDate(currentDate);
        final localEvents = events.where((event) => event.source != 'google' && event.source != 'holiday').toList();
        if (localEvents.length != events.length) {
          await EventStorageService.clearEventsForDate(currentDate);
          for (var localEvent in localEvents) {
            await EventStorageService.addEvent(currentDate, localEvent);
          }
        }
      }
    } catch (e) {
      print('❌ 기존 Google 이벤트 정리 실패: $e');
    }
  }

  Future<void> uploadToGoogleCalendar({bool cleanupExisting = false}) async {
    try {
      print('🔄 EventManager: Google Calendar 업로드 시작...');
      if (!await _googleCalendarService.initialize()) {
        throw Exception('Google Calendar 초기화 실패');
      }
      await _googleCalendarService.syncColorMappingsToController(_controller);
      final currentMonth = _controller.focusedDay;
      final startOfMonth = DateTime(currentMonth.year, currentMonth.month, 1);
      final endOfMonth = DateTime(currentMonth.year, currentMonth.month + 1, 0);
      if (cleanupExisting) {
        try {
          final googleEvents = await _googleCalendarService.getEventsFromGoogleCalendar(startDate: startOfMonth, endDate: endOfMonth);
          if (googleEvents.isNotEmpty) {
            final results = await _googleCalendarService.deleteMultipleEventsFromGoogle(googleEvents);
            final successCount = results.values.where((v) => v).length;
            print('✅ $successCount개 삭제 완료, ${results.length - successCount}개 삭제 실패');
          }
        } catch (e) {
          print('⚠️ 구글 캘린더 초기화 중 오류: $e');
        }
      }
      List<Event> localEvents = [];
      for (int day = startOfMonth.day; day <= endOfMonth.day; day++) {
        localEvents.addAll(_controller.getEventsForDay(DateTime(currentMonth.year, currentMonth.month, day)).where((e) => e.source == 'local'));
      }
      final List<Event> googleEvents = await _googleCalendarService.getEventsFromGoogleCalendar(startDate: startOfMonth, endDate: endOfMonth);
      int uploadedCount = 0, skippedCount = 0;
      for (var localEvent in localEvents) {
        if (googleEvents.any((g) => g.title == localEvent.title && g.date.isAtSameMomentAs(localEvent.date) && g.time == localEvent.time)) {
          skippedCount++;
          continue;
        }
        try {
          final googleEventId = await _googleCalendarService.addEventToGoogleCalendar(localEvent);
          if (googleEventId != null) {
            uploadedCount++;
            try {
              final updatedEvent = localEvent.copyWith(googleEventId: googleEventId);
              await EventStorageService.removeEvent(localEvent.date, localEvent);
              await EventStorageService.addEvent(localEvent.date, updatedEvent);
              _controller.removeEvent(localEvent);
              _controller.addEvent(updatedEvent);
            } catch (e) {
              print('⚠️ Google Event ID 저장 실패: $e');
            }
          }
        } catch (e) {
          print('❌ 업로드 중 오류: ${localEvent.title} - $e');
        }
      }
      print('📊 Google Calendar 업로드 완료:\n   • 신규 업로드: $uploadedCount개\n   • 중복으로 건너뜀: $skippedCount개\n   • 총 로컬 이벤트: ${localEvents.length}개');
      await _googleCalendarService.syncColorMappingsToController(_controller);
    } catch (e) {
      print('❌ Google Calendar 업로드 중 오류: $e');
      rethrow;
    }
  }

  Future<void> loadInitialData() async {
    try {
      print('📥 초기 데이터 로드 시작...');
      await EventStorageService.cleanupAllDuplicateEvents();
      final today = DateTime.now();
      await loadEventsForMonth(today);
      final localEvents = _controller.getEventsForDay(today).where((e) => e.source == 'local').toList();
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

  Future<void> cleanupDuplicateEvents() async {
    try {
      print('🧹 수동 중복 정리 시작...');
      await EventStorageService.cleanupAllDuplicateEvents();
      await refreshCurrentMonthEvents();
      print('✅ 수동 중복 정리 완료');
    } catch (e) {
      print('❌ 중복 정리 중 오류: $e');
      rethrow;
    }
  }

  Future<void> migrateEventsToStandardColors() async {
    try {
      print('🎨 기존 이벤트 색상 마이그레이션 시작...');
      final now = DateTime.now();
      final startOfYear = DateTime(now.year, 1, 1);
      final endOfYear = DateTime(now.year, 12, 31);
      int migratedCount = 0;
      for (DateTime currentDate = startOfYear; currentDate.isBefore(endOfYear.add(const Duration(days: 1))); currentDate = currentDate.add(const Duration(days: 1))) {
        final events = await EventStorageService.getEvents(currentDate);
        bool hasChanges = false;
        for (var event in events) {
          if (event.source == 'local' && !event.hasCustomColor()) {
            final randomColorId = (_random.nextInt(11) + 1);
            final migratedEvent = event.withColorId(randomColorId);
            await EventStorageService.removeEvent(currentDate, event);
            await EventStorageService.addEvent(currentDate, migratedEvent);
            migratedCount++;
            hasChanges = true;
          }
        }
        if (hasChanges) {
          await loadEventsForDay(currentDate);
        }
      }
      print('✅ 색상 마이그레이션 완료: $migratedCount개 이벤트 처리됨');
    } catch (e) {
      print('❌ 색상 마이그레이션 중 오류: $e');
      rethrow;
    }
  }
}
