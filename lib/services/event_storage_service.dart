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
