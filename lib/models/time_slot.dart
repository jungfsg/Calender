import 'package:flutter/material.dart';

class TimeSlot {
  final String title;
  final String startTime;
  final String endTime;
  final Color color;
  final DateTime date; // 날짜 필드 추가

  TimeSlot(
    this.title,
    this.startTime,
    this.endTime,
    this.color, {
    required this.date,
  });

  // JSON 직렬화를 위한 메서드
  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'startTime': startTime,
      'endTime': endTime,
      'colorValue': color.value,
      'date': date.toIso8601String(),
    };
  }

  // JSON 역직렬화를 위한 팩토리 생성자
  factory TimeSlot.fromJson(Map<String, dynamic> json) {
    return TimeSlot(
      json['title'],
      json['startTime'],
      json['endTime'],
      Color(json['colorValue']),
      date: DateTime.parse(json['date']),
    );
  }
}
