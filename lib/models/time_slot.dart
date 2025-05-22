import 'package:flutter/material.dart';

class TimeSlot {
  final String title;
  final String startTime;
  final String endTime;
  final Color color;

  TimeSlot(this.title, this.startTime, this.endTime, this.color);

  // JSON 직렬화를 위한 메서드
  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'startTime': startTime,
      'endTime': endTime,
      'colorValue': color.value,
    };
  }

  // JSON 역직렬화를 위한 팩토리 생성자
  factory TimeSlot.fromJson(Map<String, dynamic> json) {
    return TimeSlot(
      json['title'],
      json['startTime'],
      json['endTime'],
      Color(json['colorValue']),
    );
  }
}
