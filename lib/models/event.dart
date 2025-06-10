import 'package:flutter/material.dart';
import '../enums/recurrence_type.dart';

class Event {
  final String title;
  final String time; // HH:mm 형식의 시작 시간
  final String? endTime; // HH:mm 형식의 종료 시간, null일 경우 시작시간+1시간으로 자동 계산
  final DateTime date;
  final String description; // 이벤트 설명 추가
  final String? colorId; // 구글 캘린더 색상 ID 추가
  final Color? color; // Flutter Color 객체 추가
  final String source; // 🆕 이벤트 출처: 'local', 'google', 'holiday'
  final String uniqueId; // 새로 추가: 이벤트 고유 ID
  final String? googleEventId; // Google Calendar 이벤트 ID 저장
  final RecurrenceType recurrence; // 🆕 반복 타입 추가
  final int recurrenceCount; // 🆕 반복 횟수 추가

  Event({
    required this.title,
    required this.time,
    this.endTime,
    required this.date,
    this.description = '', // 기본값으로 빈 문자열 설정
    this.colorId,
    this.color,
    this.source = 'local', // 🆕 기본값은 'local'
    String? uniqueId, // 고유 ID는 선택적 매개변수
    this.googleEventId, // Google Calendar 이벤트 ID
    this.recurrence = RecurrenceType.none, // 🆕 기본값은 반복 없음
    int? recurrenceCount, // 🆕 반복 횟수는 선택적 매개변수
  }) : uniqueId =
           uniqueId ??
           '${title}_${date.toIso8601String()}_${time}_${DateTime.now().microsecondsSinceEpoch}',
       recurrenceCount = recurrenceCount ?? recurrence.defaultCount;

  // 고유 ID 생성 메소드 (날짜+시간+제목 기반)
  static String generateUniqueId(String title, DateTime date, String time) {
    return '${title}_${date.toIso8601String()}_${time}_${DateTime.now().microsecondsSinceEpoch}';
  }

  // JSON 직렬화를 위한 메서드 - 디버깅 추가
  Map<String, dynamic> toJson() {
    final json = {
      'title': title,
      'time': time,
      'endTime': endTime, // 종료 시간 추가
      'date': date.toIso8601String(),
      'description': description,
      'colorId': colorId,
      'color': color?.value, // Color를 int 값으로 저장
      'source': source, // 🆕 source 필드 추가
      'uniqueId': uniqueId, // 고유 ID 저장
      'googleEventId': googleEventId, // Google Calendar 이벤트 ID 저장
      'recurrence': recurrence.toString(), // 🆕 반복 타입 저장
      'recurrenceCount': recurrenceCount, // 🆕 반복 횟수 저장
    };
    print(
      '💾 Event toJson: $title -> colorId: $colorId, color: ${color?.value}, source: $source, uniqueId: $uniqueId, googleEventId: $googleEventId, recurrence: $recurrence, count: $recurrenceCount',
    );
    return json;
  }

  // JSON 역직렬화를 위한 팩토리 생성자 - 디버깅 추가
  factory Event.fromJson(Map<String, dynamic> json) {
    final event = Event(
      title: json['title'],
      time: json['time'],
      endTime: json['endTime'], // 종료 시간 복원
      date: DateTime.parse(json['date']),
      description: json['description'] ?? '',
      colorId: json['colorId'],
      color: json['color'] != null ? Color(json['color']) : null,
      source: json['source'] ?? 'local', // 🆕 source 필드 추가 (기본값: 'local')
      uniqueId: json['uniqueId'], // 고유 ID 복원
      googleEventId: json['googleEventId'], // Google Calendar 이벤트 ID 복원
      recurrence:
          json['recurrence'] != null
              ? RecurrenceType.fromString(json['recurrence'])
              : RecurrenceType.none, // 🆕 반복 타입 복원
      recurrenceCount: json['recurrenceCount'] ?? 1, // 🆕 반복 횟수 복원
    );
    print(
      '📖 Event fromJson: ${event.title} -> colorId: ${event.colorId}, color: ${event.color?.value}, source: ${event.source}, uniqueId: ${event.uniqueId}, googleEventId: ${event.googleEventId}, recurrence: ${event.recurrence}, count: ${event.recurrenceCount}',
    );
    return event;
  }

  // 시간 비교를 위한 메서드
  int compareTo(Event other) {
    return time.compareTo(other.time);
  }

  // 종료 시간이 있는지 확인하는 메서드
  bool hasEndTime() {
    return endTime != null && endTime!.isNotEmpty;
  }

  // 색상이 있는 Event 복사본 생성
  Event copyWith({
    String? title,
    String? time,
    String? endTime,
    DateTime? date,
    String? description,
    String? colorId,
    Color? color,
    String? source, // 🆕 source 필드 추가
    String? uniqueId, // 고유 ID 복사 옵션 추가
    String? googleEventId, // Google Calendar 이벤트 ID 복사 옵션 추가
    RecurrenceType? recurrence, // 🆕 반복 타입 추가
    int? recurrenceCount, // 🆕 반복 횟수 추가
  }) {
    return Event(
      title: title ?? this.title,
      time: time ?? this.time,
      endTime: endTime ?? this.endTime,
      date: date ?? this.date,
      description: description ?? this.description,
      colorId: colorId ?? this.colorId,
      color: color ?? this.color,
      source: source ?? this.source, // 🆕 source 필드 추가
      uniqueId: uniqueId ?? this.uniqueId, // 고유 ID 유지
      googleEventId:
          googleEventId ?? this.googleEventId, // Google Calendar 이벤트 ID 유지
      recurrence: recurrence ?? this.recurrence, // 🆕 반복 타입 유지
      recurrenceCount: recurrenceCount ?? this.recurrenceCount, // 🆕 반복 횟수 유지
    );
  }

  // 색상 ID 설정 (Google Calendar 표준 색상)
  Event withColorId(int colorId) {
    // ColorPickerDialog에서 색상 가져오기
    final colorValue = _getColorByColorId(colorId);
    return copyWith(colorId: colorId.toString(), color: colorValue);
  }

  // colorId로 색상 가져오기 (Google Calendar 표준 색상)
  static Color _getColorByColorId(int colorId) {
    const Map<int, Color> googleColors = {
      1: Color(0xFF9AA0F5), // 라벤더
      2: Color(0xFF33B679), // 세이지
      3: Color(0xFF8E24AA), // 포도
      4: Color(0xFFE67C73), // 플라밍고
      5: Color(0xFFF6BF26), // 바나나
      6: Color(0xFFFF8A65), // 귤
      7: Color(0xFF039BE5), // 공작새
      8: Color(0xFF616161), // 그래파이트
      9: Color(0xFF3F51B5), // 블루베리
      10: Color(0xFF0B8043), // 바질
      11: Color(0xFFD50000), // 토마토
    };
    return googleColors[colorId] ?? googleColors[1]!;
  }

  // 색상 ID를 가져오는 메서드
  int? getColorId() {
    if (colorId != null) {
      final id = int.tryParse(colorId!);
      if (id != null && id >= 1 && id <= 11) {
        return id;
      }
    }
    return null;
  }

  // 표시할 색상 가져오기 (colorId 우선, color 폴백)
  Color getDisplayColor() {
    if (colorId != null) {
      final id = int.tryParse(colorId!);
      if (id != null && id >= 1 && id <= 11) {
        return _getColorByColorId(id);
      }
    }
    return color ?? Colors.blue;
  }

  // 커스텀 색상을 가지고 있는지 확인
  bool hasCustomColor() {
    return colorId != null && colorId!.isNotEmpty;
  }
}
