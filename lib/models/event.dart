import 'package:flutter/material.dart';

class Event {
  final String title;
  final String time; // HH:mm 형식의 시간
  final DateTime date;
  final String description; // 이벤트 설명 추가
  final String? colorId; // 구글 캘린더 색상 ID 추가
  final Color? color; // Flutter Color 객체 추가
  final String source; // 🆕 이벤트 출처: 'local', 'google', 'holiday'
  final String uniqueId; // 새로 추가: 이벤트 고유 ID

  Event({
    required this.title,
    required this.time,
    required this.date,
    this.description = '', // 기본값으로 빈 문자열 설정
    this.colorId,
    this.color,
    this.source = 'local', // 🆕 기본값은 'local'
    String? uniqueId, // 고유 ID는 선택적 매개변수
  }) : uniqueId =
           uniqueId ??
           '${title}_${date.toIso8601String()}_${time}_${DateTime.now().microsecondsSinceEpoch}';

  // 고유 ID 생성 메소드 (날짜+시간+제목 기반)
  static String generateUniqueId(String title, DateTime date, String time) {
    return '${title}_${date.toIso8601String()}_${time}_${DateTime.now().microsecondsSinceEpoch}';
  }

  // JSON 직렬화를 위한 메서드 - 디버깅 추가
  Map<String, dynamic> toJson() {
    final json = {
      'title': title,
      'time': time,
      'date': date.toIso8601String(),
      'description': description,
      'colorId': colorId,
      'color': color?.value, // Color를 int 값으로 저장
      'source': source, // 🆕 source 필드 추가
      'uniqueId': uniqueId, // 고유 ID 저장
    };
    print(
      '💾 Event toJson: $title -> colorId: $colorId, color: ${color?.value}, source: $source, uniqueId: $uniqueId',
    );
    return json;
  }

  // JSON 역직렬화를 위한 팩토리 생성자 - 디버깅 추가
  factory Event.fromJson(Map<String, dynamic> json) {
    final event = Event(
      title: json['title'],
      time: json['time'],
      date: DateTime.parse(json['date']),
      description: json['description'] ?? '',
      colorId: json['colorId'],
      color: json['color'] != null ? Color(json['color']) : null,
      source: json['source'] ?? 'local', // 🆕 source 필드 추가 (기본값: 'local')
      uniqueId: json['uniqueId'], // 고유 ID 복원
    );
    print(
      '📖 Event fromJson: ${event.title} -> colorId: ${event.colorId}, color: ${event.color?.value}, source: ${event.source}, uniqueId: ${event.uniqueId}',
    );
    return event;
  }

  // 시간 비교를 위한 메서드
  int compareTo(Event other) {
    return time.compareTo(other.time);
  } // 색상이 있는 Event 복사본 생성

  Event copyWith({
    String? title,
    String? time,
    DateTime? date,
    String? description,
    String? colorId,
    Color? color,
    String? source, // 🆕 source 필드 추가
    String? uniqueId, // 고유 ID 복사 옵션 추가
  }) {
    return Event(
      title: title ?? this.title,
      time: time ?? this.time,
      date: date ?? this.date,
      description: description ?? this.description,
      colorId: colorId ?? this.colorId,
      color: color ?? this.color,
      source: source ?? this.source, // 🆕 source 필드 추가
      uniqueId: uniqueId ?? this.uniqueId, // 고유 ID 유지
    );
  }
}
