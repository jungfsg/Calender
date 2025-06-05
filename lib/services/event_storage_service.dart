import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/event.dart';
import '../models/time_slot.dart';

class EventStorageService {
  static const String _eventPrefix = 'event_';
  static const String _timeSlotPrefix = 'timeslot_';
  // 이벤트 저장 (강화된 중복 체크)
  static Future<void> addEvent(DateTime date, Event event) async {
    final prefs = await SharedPreferences.getInstance();
    final dateKey = _getEventKey(date);
    final events = await getEvents(date);

    // 🔥 강화된 중복 이벤트 확인 로직
    final isDuplicate = events.any((e) => _isEventDuplicate(e, event));

    if (!isDuplicate) {
      events.add(event);

      // 시간순으로 정렬
      events.sort((a, b) => a.compareTo(b));

      final eventStrings = events.map((e) => jsonEncode(e.toJson())).toList();
      await prefs.setStringList(dateKey, eventStrings);

      print('✅ 이벤트 저장됨: ${event.title} (${event.time})');
    } else {
      print('🚫 중복 이벤트로 저장하지 않음: ${event.title} (${event.time})');
    }
  }

  // 중복 이벤트 체크 헬퍼 메서드
  static bool _isEventDuplicate(Event existing, Event newEvent) {
    // 제목 정규화 (공백, 대소문자 무시)
    final normalizedExistingTitle = existing.title.trim().toLowerCase();
    final normalizedNewTitle = newEvent.title.trim().toLowerCase();

    return normalizedExistingTitle == normalizedNewTitle &&
        existing.time == newEvent.time &&
        existing.date.year == newEvent.date.year &&
        existing.date.month == newEvent.date.month &&
        existing.date.day == newEvent.date.day;
  }

  // 이벤트 가져오기
  static Future<List<Event>> getEvents(DateTime date) async {
    final prefs = await SharedPreferences.getInstance();
    final dateKey = _getEventKey(date);
    final eventStrings = prefs.getStringList(dateKey) ?? [];

    return eventStrings.map((str) => Event.fromJson(jsonDecode(str))).toList();
  }

  // 특정 날짜의 이벤트 가져오기 (별칭 메서드)
  static Future<List<Event>> getEventsForDate(DateTime date) async {
    return await getEvents(date);
  }

  // 이벤트 삭제
  static Future<void> removeEvent(DateTime date, Event event) async {
    final prefs = await SharedPreferences.getInstance();
    final dateKey = _getEventKey(date);
    final events = await getEvents(date);

    print(
      '🔍 삭제 시도: ${event.title} (${event.time}) - ${date.toString().substring(0, 10)}',
    );
    print('📋 삭제 전 이벤트 수: ${events.length}개');

    // 더 정확한 이벤트 비교 로직으로 변경
    events.removeWhere(
      (e) =>
          e.title == event.title &&
          e.time == event.time &&
          e.date.year == event.date.year &&
          e.date.month == event.date.month &&
          e.date.day == event.date.day,
    );

    print('📋 삭제 후 이벤트 수: ${events.length}개');

    final eventStrings = events.map((e) => jsonEncode(e.toJson())).toList();
    await prefs.setStringList(dateKey, eventStrings);
  }

  // 타임슬롯 관련 메서드들은 그대로 유지
  static Future<void> addTimeSlot(DateTime date, TimeSlot timeSlot) async {
    final prefs = await SharedPreferences.getInstance();
    final dateKey = _getTimeSlotKey(date);
    final timeSlots = await getTimeSlots(date);
    timeSlots.add(timeSlot);
    final timeSlotStrings =
        timeSlots.map((ts) => jsonEncode(ts.toJson())).toList();
    await prefs.setStringList(dateKey, timeSlotStrings);
  }

  static Future<List<TimeSlot>> getTimeSlots(DateTime date) async {
    final prefs = await SharedPreferences.getInstance();
    final dateKey = _getTimeSlotKey(date);
    final timeSlotStrings = prefs.getStringList(dateKey) ?? [];
    return timeSlotStrings
        .map((str) => TimeSlot.fromJson(jsonDecode(str)))
        .toList();
  }

  // Google Calendar 동기화 전용 메서드 (중복 체크 강화)
  static Future<void> syncGoogleEvents(
    DateTime date,
    List<Event> googleEvents,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final dateKey = _getEventKey(date);
    final existingEvents = await getEvents(date);

    // 기존 Google 이벤트 제거 (중복 방지)
    final localEvents =
        existingEvents
            .where((e) => e.source != 'google' && e.source != 'holiday')
            .toList();

    // Google 이벤트 중복 제거 후 추가
    final uniqueGoogleEvents = _removeDuplicateEvents(googleEvents);

    // 로컬 이벤트와 Google 이벤트 중복 체크
    final filteredGoogleEvents = <Event>[];
    for (var googleEvent in uniqueGoogleEvents) {
      final isDuplicateWithLocal = localEvents.any(
        (localEvent) => _isEventDuplicate(localEvent, googleEvent),
      );

      if (!isDuplicateWithLocal) {
        filteredGoogleEvents.add(googleEvent);
      } else {
        print('🚫 로컬 이벤트와 중복된 Google 이벤트 제외: ${googleEvent.title}');
      }
    }

    // 모든 이벤트 병합
    final allEvents = [...localEvents, ...filteredGoogleEvents];

    // 시간순으로 정렬
    allEvents.sort((a, b) => a.compareTo(b));

    final eventStrings = allEvents.map((e) => jsonEncode(e.toJson())).toList();
    await prefs.setStringList(dateKey, eventStrings);

    print(
      '✅ Google 이벤트 동기화 완료: ${date.toString().split(' ')[0]} - ${filteredGoogleEvents.length}개 이벤트',
    );
  }

  // 이벤트 목록에서 중복 제거
  static List<Event> _removeDuplicateEvents(List<Event> events) {
    final uniqueEvents = <Event>[];
    final seenEvents = <String>{};

    for (var event in events) {
      final key =
          '${event.title.trim().toLowerCase()}_${event.time}_${event.date.year}_${event.date.month}_${event.date.day}';

      if (!seenEvents.contains(key)) {
        seenEvents.add(key);
        uniqueEvents.add(event);
      } else {
        print('🚫 중복 이벤트 제외: ${event.title} (${event.time})');
      }
    }

    return uniqueEvents;
  }

  // 특정 소스의 이벤트만 제거하는 메서드
  static Future<void> removeEventsBySource(DateTime date, String source) async {
    final prefs = await SharedPreferences.getInstance();
    final dateKey = _getEventKey(date);
    final events = await getEvents(date);

    final filteredEvents = events.where((e) => e.source != source).toList();

    final eventStrings =
        filteredEvents.map((e) => jsonEncode(e.toJson())).toList();
    await prefs.setStringList(dateKey, eventStrings);

    print('🗑️ $source 소스 이벤트 제거 완료: ${date.toString().split(' ')[0]}');
  }

  // 특정 소스의 이벤트 개수 확인
  static Future<int> getEventCountBySource(DateTime date, String source) async {
    final events = await getEvents(date);
    return events.where((e) => e.source == source).length;
  }

  // 날짜 범위에 대한 Google 이벤트 일괄 동기화
  static Future<void> syncGoogleEventsForRange(
    DateTime startDate,
    DateTime endDate,
    Map<DateTime, List<Event>> googleEventsByDate,
  ) async {
    // 날짜 범위 내의 모든 날짜 처리
    DateTime currentDate = startDate;
    while (currentDate.isBefore(endDate) ||
        currentDate.isAtSameMomentAs(endDate)) {
      final googleEvents = googleEventsByDate[currentDate] ?? [];
      await syncGoogleEvents(currentDate, googleEvents);
      currentDate = currentDate.add(const Duration(days: 1));
    }

    print(
      '📅 Google Calendar 범위 동기화 완료: ${startDate.toString().split(' ')[0]} ~ ${endDate.toString().split(' ')[0]}',
    );
  }

  // 키 생성 헬퍼 메서드
  static String _getEventKey(DateTime date) {
    return '$_eventPrefix${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  static String _getTimeSlotKey(DateTime date) {
    return '$_timeSlotPrefix${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  // 디버깅용: 모든 키 출력
  static Future<void> printAllKeys() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys();
    print('저장된 모든 키: $keys');
  }

  // 🧹 전체 중복 이벤트 정리 메서드
  static Future<void> cleanupAllDuplicateEvents() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where((key) => key.startsWith(_eventPrefix));

    int totalCleaned = 0;

    for (final key in keys) {
      try {
        final eventStrings = prefs.getStringList(key) ?? [];
        if (eventStrings.isEmpty) continue;

        final events =
            eventStrings.map((str) => Event.fromJson(jsonDecode(str))).toList();

        final originalCount = events.length;
        final uniqueEvents = _removeDuplicateEvents(events);
        final cleanedCount = originalCount - uniqueEvents.length;

        if (cleanedCount > 0) {
          final cleanedEventStrings =
              uniqueEvents.map((e) => jsonEncode(e.toJson())).toList();
          await prefs.setStringList(key, cleanedEventStrings);
          totalCleaned += cleanedCount;
          print(
            '🧹 $key: $originalCount개 -> ${uniqueEvents.length}개 ($cleanedCount개 정리)',
          );
        }
      } catch (e) {
        print('❌ $key 정리 중 오류: $e');
      }
    }

    print('✅ 전체 중복 정리 완료: $totalCleaned개 이벤트 정리됨');
  }

  // 특정 날짜의 모든 이벤트 삭제
  static Future<void> clearEventsForDate(DateTime date) async {
    final prefs = await SharedPreferences.getInstance();
    final dateKey = _getEventKey(date);
    await prefs.remove(dateKey);
    print('🗑️ ${date.toString().split(' ')[0]} 모든 이벤트 삭제 완료');
  }

  // 특정 날짜의 중복 이벤트만 정리
  static Future<int> cleanupDuplicatesForDate(DateTime date) async {
    final prefs = await SharedPreferences.getInstance();
    final dateKey = _getEventKey(date);
    final events = await getEvents(date);

    if (events.isEmpty) return 0;

    final originalCount = events.length;
    final uniqueEvents = _removeDuplicateEvents(events);
    final cleanedCount = originalCount - uniqueEvents.length;

    if (cleanedCount > 0) {
      final eventStrings =
          uniqueEvents.map((e) => jsonEncode(e.toJson())).toList();
      await prefs.setStringList(dateKey, eventStrings);
      print(
        '🧹 ${date.toString().split(' ')[0]}: $originalCount개 -> ${uniqueEvents.length}개 ($cleanedCount개 정리)',
      );
    }
    return cleanedCount;
  }
}
