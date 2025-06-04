import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/event.dart';
import '../models/time_slot.dart';

class EventStorageService {
  static const String _eventPrefix = 'event_';
  static const String _timeSlotPrefix = 'timeslot_';

  // 이벤트 저장
  static Future<void> addEvent(DateTime date, Event event) async {
    final prefs = await SharedPreferences.getInstance();
    final dateKey = _getEventKey(date);
    final events = await getEvents(date);
    
    // 🔥 중복 이벤트 확인 로직 추가
    final isDuplicate = events.any((e) => 
      e.title == event.title && 
      e.time == event.time &&
      e.date.year == event.date.year &&
      e.date.month == event.date.month &&
      e.date.day == event.date.day
    );
    
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

  // 이벤트 가져오기
  static Future<List<Event>> getEvents(DateTime date) async {
    final prefs = await SharedPreferences.getInstance();
    final dateKey = _getEventKey(date);
    final eventStrings = prefs.getStringList(dateKey) ?? [];
    
    return eventStrings
        .map((str) => Event.fromJson(jsonDecode(str)))
        .toList();
  }

  // 이벤트 삭제
  static Future<void> removeEvent(DateTime date, Event event) async {
    final prefs = await SharedPreferences.getInstance();
    final dateKey = _getEventKey(date);
    final events = await getEvents(date);
    
    events.removeWhere((e) => e.title == event.title && e.time == event.time);
    
    final eventStrings = events.map((e) => jsonEncode(e.toJson())).toList();
    await prefs.setStringList(dateKey, eventStrings);
  }

  // 타임슬롯 관련 메서드들은 그대로 유지
  static Future<void> addTimeSlot(DateTime date, TimeSlot timeSlot) async {
    final prefs = await SharedPreferences.getInstance();
    final dateKey = _getTimeSlotKey(date);
    final timeSlots = await getTimeSlots(date);
    timeSlots.add(timeSlot);
    final timeSlotStrings = timeSlots.map((ts) => jsonEncode(ts.toJson())).toList();
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

  // Google Calendar 동기화 전용 메서드
  static Future<void> syncGoogleEvents(DateTime date, List<Event> googleEvents) async {
    final prefs = await SharedPreferences.getInstance();
    final dateKey = _getEventKey(date);
    final existingEvents = await getEvents(date);
    
    // 기존 Google 이벤트 제거 (중복 방지)
    final localEvents = existingEvents.where((e) => e.source != 'google').toList();
    
    // Google 이벤트 추가
    final allEvents = [...localEvents, ...googleEvents];
    
    // 시간순으로 정렬
    allEvents.sort((a, b) => a.compareTo(b));
    
    final eventStrings = allEvents.map((e) => jsonEncode(e.toJson())).toList();
    await prefs.setStringList(dateKey, eventStrings);
    
    print('✅ Google 이벤트 동기화 완료: ${date.toString().split(' ')[0]} - ${googleEvents.length}개 이벤트');
  }

  // 특정 소스의 이벤트만 제거하는 메서드
  static Future<void> removeEventsBySource(DateTime date, String source) async {
    final prefs = await SharedPreferences.getInstance();
    final dateKey = _getEventKey(date);
    final events = await getEvents(date);
    
    final filteredEvents = events.where((e) => e.source != source).toList();
    
    final eventStrings = filteredEvents.map((e) => jsonEncode(e.toJson())).toList();
    await prefs.setStringList(dateKey, eventStrings);
    
    print('🗑️ ${source} 소스 이벤트 제거 완료: ${date.toString().split(' ')[0]}');
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
    Map<DateTime, List<Event>> googleEventsByDate
  ) async {
    // 날짜 범위 내의 모든 날짜 처리
    DateTime currentDate = startDate;
    while (currentDate.isBefore(endDate) || currentDate.isAtSameMomentAs(endDate)) {
      final googleEvents = googleEventsByDate[currentDate] ?? [];
      await syncGoogleEvents(currentDate, googleEvents);
      currentDate = currentDate.add(const Duration(days: 1));
    }
    
    print('📅 Google Calendar 범위 동기화 완료: ${startDate.toString().split(' ')[0]} ~ ${endDate.toString().split(' ')[0]}');
  }

  // 키 생성 헬퍼 메서드
  static String _getEventKey(DateTime date) {
    return '${_eventPrefix}${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  static String _getTimeSlotKey(DateTime date) {
    return '${_timeSlotPrefix}${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  // 디버깅용: 모든 키 출력
  static Future<void> printAllKeys() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys();
    print('저장된 모든 키: $keys');
  }
}
