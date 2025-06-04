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

  // 앱 전용 색상 목록
  final List<Color> _appColors = [
    Colors.red,
    Colors.blue,
    Colors.green,
    Colors.orange,
    Colors.purple,
    Colors.indigo,
    Colors.teal,
  ];

  EventManager(this._controller);

  /// 특정 날짜의 이벤트 로드
  Future<void> loadEventsForDay(DateTime day) async {
    if (_controller.isDateLoading(day)) return;

    _controller.setDateLoading(day, true);

    try {
      final events = await EventStorageService.getEvents(day);

      // 캐시에 이벤트 저장
      for (var event in events) {
        _controller.addEvent(event);

        // 색상이 없는 이벤트에 색상 할당
        if (_controller.getEventColor(event.title) == null) {
          final color = _appColors[_random.nextInt(_appColors.length)];
          _controller.setEventColor(event.title, color);
        }
      }
    } catch (e) {
      print('이벤트 로드 중 오류: $e');
    } finally {
      _controller.setDateLoading(day, false);
    }
  }

  /// 이벤트 추가
  Future<void> addEvent(Event event) async {
    try {
      // 로컬 스토리지에 저장
      await EventStorageService.addEvent(event.date, event);

      // 컨트롤러에 추가
      _controller.addEvent(event);

      // 색상 할당
      if (_controller.getEventColor(event.title) == null) {
        final color = _appColors[_random.nextInt(_appColors.length)];
        _controller.setEventColor(event.title, color);
      }

      print('이벤트 추가됨: ${event.title}');
    } catch (e) {
      print('이벤트 추가 중 오류: $e');
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

      print('이벤트 삭제됨: ${event.title}');
    } catch (e) {
      print('이벤트 삭제 중 오류: $e');
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
      if (!await _googleCalendarService.initialize()) {
        throw Exception('Google Calendar 초기화 실패');
      }

      // 현재 연도의 시작과 끝 날짜 계산
      final DateTime startOfYear = DateTime(_controller.focusedDay.year, 1, 1);
      final DateTime endOfYear = DateTime(_controller.focusedDay.year, 12, 31);

      // Google Calendar에서 이벤트 가져오기
      final List<Event> googleEvents = await _googleCalendarService
          .syncWithGoogleCalendarIncludingHolidays(
            startDate: startOfYear,
            endDate: endOfYear,
          );

      // 날짜별로 Google 이벤트 그룹화
      final Map<DateTime, List<Event>> googleEventsByDate = {};
      for (var event in googleEvents) {
        final dateKey = DateTime(event.date.year, event.date.month, event.date.day);
        googleEventsByDate.putIfAbsent(dateKey, () => []).add(event);
      }

      // EventStorageService를 통해 중복 방지하며 동기화
      await EventStorageService.syncGoogleEventsForRange(
        startOfYear, 
        endOfYear, 
        googleEventsByDate
      );

      // 컨트롤러에서 기존 Google 이벤트 제거 후 새 이벤트 추가
      _controller.removeEventsBySource('google');
      
      for (var event in googleEvents) {
        _controller.addEvent(event);

        // Google 이벤트는 특별한 색상 처리
        if (_controller.getEventColor(event.title) == null) {
          Color eventColor;
          if (event.source == 'holiday') {
            eventColor = Colors.deepOrange; // 공휴일은 주황색
          } else {
            eventColor = Colors.lightBlue; // Google 이벤트는 연한 파란색
          }
          _controller.setEventColor(event.title, eventColor);
        }
      }

      print('Google Calendar 동기화 완료: ${googleEvents.length}개 이벤트');
    } catch (e) {
      print('Google Calendar 동기화 중 오류: $e');
      rethrow;
    }
  }

  /// 로컬 이벤트를 Google Calendar에 업로드
  Future<void> uploadToGoogleCalendar() async {
    try {
      if (!await _googleCalendarService.initialize()) {
        throw Exception('Google Calendar 초기화 실패');
      }

      // 현재 월의 모든 로컬 이벤트 가져오기
      final currentMonth = _controller.focusedDay;
      final startOfMonth = DateTime(currentMonth.year, currentMonth.month, 1);
      final endOfMonth = DateTime(currentMonth.year, currentMonth.month + 1, 0);

      List<Event> allEvents = [];
      for (int day = startOfMonth.day; day <= endOfMonth.day; day++) {
        final date = DateTime(currentMonth.year, currentMonth.month, day);
        allEvents.addAll(_controller.getEventsForDay(date));
      }

      // Google Calendar에 업로드
      for (var event in allEvents) {
        await _googleCalendarService.addEventToGoogleCalendar(event);
      }

      print('Google Calendar 업로드 완료: ${allEvents.length}개 이벤트');
    } catch (e) {
      print('Google Calendar 업로드 중 오류: $e');
      rethrow;
    }
  }

  /// 초기 데이터 로드
  Future<void> loadInitialData() async {
    final today = DateTime.now();
    final currentMonth = DateTime(today.year, today.month, 1);

    // 현재 월과 다음 월의 이벤트 로드
    for (int month = 0; month < 2; month++) {
      final targetMonth = DateTime(
        currentMonth.year,
        currentMonth.month + month,
        1,
      );
      final daysInMonth =
          DateTime(targetMonth.year, targetMonth.month + 1, 0).day;

      for (int day = 1; day <= daysInMonth; day++) {
        final date = DateTime(targetMonth.year, targetMonth.month, day);
        await loadEventsForDay(date);
      }
    }
  }
}
