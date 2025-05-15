import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import '../models/time_slot.dart';

class EventStorageService {
  static const String ALL_EVENTS_KEY = 'all_events';
  static const String ALL_TIMESLOTS_KEY = 'all_timeslots';

  // 모든 이벤트 저장
  static Future saveAllEvents(Map<String, List<String>> allEvents) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonData = jsonEncode(allEvents);
    await prefs.setString(ALL_EVENTS_KEY, jsonData);
  }

  // 모든 이벤트 로드
  static Future<Map<String, List<String>>> getAllEvents() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonData = prefs.getString(ALL_EVENTS_KEY);
    if (jsonData == null || jsonData.isEmpty) {
      return {};
    }

    try {
      final Map decoded = jsonDecode(jsonData);
      final Map<String, List<String>> result = {};
      decoded.forEach((key, value) {
        if (value is List) {
          result[key] = List<String>.from(value);
        }
      });
      return result;
    } catch (e) {
      print('이벤트 데이터 파싱 오류: $e');
      return {};
    }
  }

  // 특정 날짜의 이벤트 저장
  static Future saveEvents(DateTime date, List<String> events) async {
    final dateKey = _getKey(date);
    final allEvents = await getAllEvents();
    allEvents[dateKey] = events;
    await saveAllEvents(allEvents);
  }

  // 특정 날짜의 이벤트 로드
  static Future<List<String>> getEvents(DateTime date) async {
    final dateKey = _getKey(date);
    final allEvents = await getAllEvents();
    return allEvents[dateKey] ?? [];
  }

  // 이벤트 추가
  static Future addEvent(DateTime date, String event) async {
    print('이벤트 저장 시작: $date, 내용: $event');
    final events = await getEvents(date);
    events.add(event);
    await saveEvents(date, events);
  }

  // 이벤트 삭제
  static Future removeEvent(DateTime date, String event) async {
    final events = await getEvents(date);
    events.remove(event);
    await saveEvents(date, events);
  }

  // 모든 타임슬롯 저장
  static Future saveAllTimeSlots(
    Map<String, List<Map<String, dynamic>>> allTimeSlots,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonData = jsonEncode(allTimeSlots);
    await prefs.setString(ALL_TIMESLOTS_KEY, jsonData);
  }

  // 모든 타임슬롯 로드
  static Future<Map<String, List<Map<String, dynamic>>>>
  getAllTimeSlots() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonData = prefs.getString(ALL_TIMESLOTS_KEY);
    if (jsonData == null || jsonData.isEmpty) {
      return {};
    }

    try {
      final Map decoded = jsonDecode(jsonData);
      final Map<String, List<Map<String, dynamic>>> result = {};
      decoded.forEach((key, value) {
        if (value is List) {
          result[key] = List<Map<String, dynamic>>.from(
            value.map((item) => Map<String, dynamic>.from(item)),
          );
        }
      });
      return result;
    } catch (e) {
      print('타임슬롯 데이터 파싱 오류: $e');
      return {};
    }
  }

  // 특정 날짜의 타임슬롯 저장
  static Future saveTimeSlots(DateTime date, List<TimeSlot> timeSlots) async {
    final dateKey = _getKey(date);
    final allTimeSlots = await getAllTimeSlots();

    // TimeSlot 객체를 JSON으로 변환
    final List<Map<String, dynamic>> timeSlotMaps =
        timeSlots
            .map(
              (slot) => {
                'title': slot.title,
                'startTime': slot.startTime,
                'endTime': slot.endTime,
                'colorValue': slot.color.value,
              },
            )
            .toList();

    allTimeSlots[dateKey] = timeSlotMaps;
    await saveAllTimeSlots(allTimeSlots);
  }

  // 특정 날짜의 타임슬롯 로드
  static Future<List<TimeSlot>> getTimeSlots(DateTime date) async {
    final dateKey = _getKey(date);
    final allTimeSlots = await getAllTimeSlots();
    final timeSlotMaps = allTimeSlots[dateKey] ?? [];

    // JSON을 TimeSlot 객체로 변환
    return timeSlotMaps
        .map(
          (map) => TimeSlot(
            map['title'],
            map['startTime'],
            map['endTime'],
            Color(map['colorValue']),
          ),
        )
        .toList();
  }

  // 타임슬롯 추가
  static Future addTimeSlot(DateTime date, TimeSlot timeSlot) async {
    final timeSlots = await getTimeSlots(date);
    timeSlots.add(timeSlot);
    await saveTimeSlots(date, timeSlots);
  }

  // 날짜 키 생성 (YYYY-MM-DD 형식)
  static String _getKey(DateTime date) {
    return "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
  }

  // 저장된 모든 키 목록 출력 (디버그용)
  static Future printAllKeys() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys();
    print('저장된 키 목록: $keys');
    if (keys.contains(ALL_EVENTS_KEY)) {
      print('이벤트 저장 확인: ALL_EVENTS_KEY 존재');
    }
  }
}
