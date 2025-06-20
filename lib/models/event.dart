import 'package:flutter/material.dart';
import '../enums/recurrence_type.dart';

class Event {
  final String title;
  final String time; // HH:mm 형식의 시작 시간
  final String? endTime; // HH:mm 형식의 종료 시간, null일 경우 시작시간+1시간으로 자동 계산
  final DateTime date;
  final DateTime? startDate; // 🆕 멀티데이 이벤트의 시작 날짜
  final DateTime? endDate; // 🆕 멀티데이 이벤트의 종료 날짜
  final bool isMultiDay; // 🆕 멀티데이 이벤트 여부
  final String description; // 이벤트 설명 추가
  final String? colorId; // 구글 캘린더 색상 ID 추가
  final Color? color; // Flutter Color 객체 추가
  final String source; // 🆕 이벤트 출처: 'local', 'google', 'holiday'
  final String uniqueId; // 새로 추가: 이벤트 고유 ID
  final String? googleEventId; // Google Calendar 이벤트 ID 저장
  final RecurrenceType recurrence; // 🆕 반복 타입 추가
  final int recurrenceCount; // 🆕 반복 횟수 추가
  final bool isNotificationEnabled; // 🆕 알림 활성화 여부
  final int notificationMinutesBefore; // 🆕 이벤트 몇 분 전에 알림 (기본값: 10분)
  final int? notificationId; // 🆕 시스템 알림 ID (스케줄링된 알림의 식별자)
  final String? category; // 🆕 카테고리 필드 추가

  Event({
    required this.title,
    this.time = '', // 🆕 멀티데이 이벤트는 시간이 없을 수도 있음
    this.endTime,
    DateTime? date, // 🆕 nullable로 변경
    this.startDate, // 🆕 멀티데이 이벤트의 시작 날짜
    this.endDate, // 🆕 멀티데이 이벤트의 종료 날짜
    this.isMultiDay = false, // 🆕 기본값은 단일날짜 이벤트
    this.description = '', // 기본값으로 빈 문자열 설정
    this.colorId,
    this.color,
    this.source = 'local', // 🆕 기본값은 'local'
    String? uniqueId, // 고유 ID는 선택적 매개변수
    this.googleEventId, // Google Calendar 이벤트 ID
    this.recurrence = RecurrenceType.none, // 🆕 기본값은 반복 없음
    int? recurrenceCount, // 🆕 반복 횟수는 선택적 매개변수
    this.isNotificationEnabled = true, // 🆕 기본값은 알림 활성화
    this.notificationMinutesBefore = 10, // 🆕 기본값은 10분 전 알림
    this.notificationId, // 🆕 시스템 알림 ID
    this.category, // 🆕 카테고리 필드 추가
  }) : date =
           date ??
           startDate ??
           DateTime.now(), // 🆕 date는 startDate 또는 현재 날짜로 fallback
       uniqueId =
           uniqueId ??
           '${title}_${(date ?? startDate ?? DateTime.now()).toIso8601String()}_${time}_${DateTime.now().microsecondsSinceEpoch}',
       recurrenceCount = recurrenceCount ?? recurrence.defaultCount;

  // 🆕 멀티데이 이벤트 생성자
  Event.multiDay({
    required this.title,
    required DateTime startDate,
    required DateTime endDate,
    this.description = '',
    this.colorId,
    this.color,
    this.source = 'local',
    String? uniqueId,
    this.googleEventId,
    this.isNotificationEnabled = true, // 🆕 기본값은 알림 활성화
    this.notificationMinutesBefore = 10, // 🆕 기본값은 10분 전 알림
    this.notificationId, // 🆕 시스템 알림 ID
    this.category, // 🆕 카테고리 필드 추가
  }) : time = '',
       endTime = null,
       date = startDate,
       startDate = startDate,
       endDate = endDate,
       isMultiDay = true,
       recurrence = RecurrenceType.none,
       recurrenceCount = 1,
       uniqueId =
           uniqueId ??
           '${title}_${startDate.toIso8601String()}_multiday_${DateTime.now().microsecondsSinceEpoch}';

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
      'startDate': startDate?.toIso8601String(), // 🆕 멀티데이 시작 날짜
      'endDate': endDate?.toIso8601String(), // 🆕 멀티데이 종료 날짜
      'isMultiDay': isMultiDay, // 🆕 멀티데이 여부
      'description': description,
      'colorId': colorId,
      'color': color?.value, // Color를 int 값으로 저장
      'source': source, // 🆕 source 필드 추가
      'uniqueId': uniqueId, // 고유 ID 저장
      'googleEventId': googleEventId, // Google Calendar 이벤트 ID 저장
      'recurrence': recurrence.toString(), // 🆕 반복 타입 저장
      'recurrenceCount': recurrenceCount, // 🆕 반복 횟수 저장
      'isNotificationEnabled': isNotificationEnabled, // 🆕 알림 활성화 여부 저장
      'notificationMinutesBefore': notificationMinutesBefore, // 🆕 알림 시간 저장
      'notificationId': notificationId, // 🆕 시스템 알림 ID 저장
      'category': category, // 🆕 카테고리 필드 추가
    };
    print(
      '💾 Event toJson: $title -> colorId: $colorId, color: ${color?.value}, source: $source, uniqueId: $uniqueId, googleEventId: $googleEventId, recurrence: $recurrence, count: $recurrenceCount, multiDay: $isMultiDay',
    );
    return json;
  }

  // JSON 역직렬화를 위한 팩토리 생성자 - 디버깅 추가
  factory Event.fromJson(Map<String, dynamic> json) {
    final event = Event(
      title: json['title'],
      time: json['time'] ?? '', // 🆕 time이 null일 수도 있음
      endTime: json['endTime'], // 종료 시간 복원
      date:
          json['date'] != null
              ? DateTime.parse(json['date'])
              : null, // 🆕 date가 null일 수도 있음
      startDate:
          json['startDate'] != null
              ? DateTime.parse(json['startDate'])
              : null, // 🆕 멀티데이 시작 날짜 복원
      endDate:
          json['endDate'] != null
              ? DateTime.parse(json['endDate'])
              : null, // 🆕 멀티데이 종료 날짜 복원
      isMultiDay: json['isMultiDay'] ?? false, // 🆕 멀티데이 여부 복원
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
      isNotificationEnabled:
          json['isNotificationEnabled'] ?? true, // 🆕 알림 활성화 여부 복원
      notificationMinutesBefore:
          json['notificationMinutesBefore'] ?? 10, // 🆕 알림 시간 복원
      notificationId: json['notificationId'], // 🆕 시스템 알림 ID 복원
      category: json['category'], // 🆕 카테고리 필드 복원
    );
    print(
      '📖 Event fromJson: ${event.title} -> colorId: ${event.colorId}, color: ${event.color?.value}, source: ${event.source}, uniqueId: ${event.uniqueId}, googleEventId: ${event.googleEventId}, recurrence: ${event.recurrence}, count: ${event.recurrenceCount}, multiDay: ${event.isMultiDay}',
    );
    return event;
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
    DateTime? startDate, // 🆕 멀티데이 시작 날짜
    DateTime? endDate, // 🆕 멀티데이 종료 날짜
    bool? isMultiDay, // 🆕 멀티데이 여부
    String? description,
    String? colorId,
    Color? color,
    String? source, // 🆕 source 필드 추가
    String? uniqueId, // 고유 ID 복사 옵션 추가
    String? googleEventId, // Google Calendar 이벤트 ID 복사 옵션 추가
    RecurrenceType? recurrence, // 🆕 반복 타입 추가
    int? recurrenceCount, // 🆕 반복 횟수 추가
    bool? isNotificationEnabled, // 🆕 알림 활성화 여부 복사 옵션
    int? notificationMinutesBefore, // 🆕 알림 시간 복사 옵션
    int? notificationId, // 🆕 시스템 알림 ID 복사 옵션
    String? category, // �� 카테고리 필드 복사 옵션
  }) {
    return Event(
      title: title ?? this.title,
      time: time ?? this.time,
      endTime: endTime ?? this.endTime,
      date: date ?? this.date,
      startDate: startDate ?? this.startDate, // 🆕 멀티데이 시작 날짜 유지
      endDate: endDate ?? this.endDate, // 🆕 멀티데이 종료 날짜 유지
      isMultiDay: isMultiDay ?? this.isMultiDay, // 🆕 멀티데이 여부 유지
      description: description ?? this.description,
      colorId: colorId ?? this.colorId,
      color: color ?? this.color,
      source: source ?? this.source, // 🆕 source 필드 추가
      uniqueId: uniqueId ?? this.uniqueId, // 고유 ID 유지
      googleEventId:
          googleEventId ?? this.googleEventId, // Google Calendar 이벤트 ID 유지
      recurrence: recurrence ?? this.recurrence, // 🆕 반복 타입 유지
      recurrenceCount: recurrenceCount ?? this.recurrenceCount, // 🆕 반복 횟수 유지
      isNotificationEnabled:
          isNotificationEnabled ??
          this.isNotificationEnabled, // 🆕 알림 활성화 여부 유지
      notificationMinutesBefore:
          notificationMinutesBefore ??
          this.notificationMinutesBefore, // 🆕 알림 시간 유지
      notificationId: notificationId ?? this.notificationId, // 🆕 시스템 알림 ID 유지
      category: category ?? this.category, // 🆕 카테고리 필드 유지
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

  // 🆕 멀티데이 이벤트 관련 메서드들

  // 멀티데이 이벤트의 기간(일수) 반환
  int getMultiDayDuration() {
    if (!isMultiDay || startDate == null || endDate == null) return 1;
    return endDate!.difference(startDate!).inDays + 1;
  }

  // 특정 날짜가 멀티데이 이벤트 기간에 포함되는지 확인
  bool containsDate(DateTime date) {
    if (!isMultiDay || startDate == null || endDate == null) {
      return isSameDay(this.date, date);
    }
    final targetDate = DateTime(date.year, date.month, date.day);
    final start = DateTime(startDate!.year, startDate!.month, startDate!.day);
    final end = DateTime(endDate!.year, endDate!.month, endDate!.day);
    return (targetDate.isAtSameMomentAs(start) || targetDate.isAfter(start)) &&
        (targetDate.isAtSameMomentAs(end) || targetDate.isBefore(end));
  }

  // 멀티데이 이벤트에서 특정 날짜가 시작일인지 확인
  bool isStartDate(DateTime date) {
    if (!isMultiDay || startDate == null) return true;
    return isSameDay(startDate!, date);
  }

  // 멀티데이 이벤트에서 특정 날짜가 종료일인지 확인
  bool isEndDate(DateTime date) {
    if (!isMultiDay || endDate == null) return true;
    return isSameDay(endDate!, date);
  }

  // 멀티데이 이벤트에서 특정 날짜가 중간일인지 확인
  bool isMiddleDate(DateTime date) {
    if (!isMultiDay) return false;
    return containsDate(date) && !isStartDate(date) && !isEndDate(date);
  }

  // 날짜 비교 유틸리티 메서드
  static bool isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  // 이벤트 정렬을 위한 compareTo 메서드
  int compareTo(Event other) {
    // 먼저 날짜로 비교
    final dateComparison = date.compareTo(other.date);
    if (dateComparison != 0) {
      return dateComparison;
    }

    // 같은 날짜라면 시간으로 비교
    // 종일 이벤트는 시간 기반 이벤트보다 앞에 표시
    if (time == '종일' && other.time != '종일') {
      return -1; // 종일 이벤트가 먼저
    }
    if (time != '종일' && other.time == '종일') {
      return 1; // 시간 이벤트가 나중
    }
    if (time == '종일' && other.time == '종일') {
      return 0; // 둘 다 종일 이벤트면 같음
    }

    // 둘 다 시간 기반 이벤트인 경우 시간으로 비교
    try {
      final thisParts = time.split(':');
      final otherParts = other.time.split(':');

      final thisHour = int.parse(thisParts[0]);
      final thisMinute = int.parse(thisParts[1]);
      final otherHour = int.parse(otherParts[0]);
      final otherMinute = int.parse(otherParts[1]);

      final thisTotalMinutes = thisHour * 60 + thisMinute;
      final otherTotalMinutes = otherHour * 60 + otherMinute;
      return thisTotalMinutes.compareTo(otherTotalMinutes);
    } catch (e) {
      // 시간 파싱 실패 시 제목으로 비교
      return title.compareTo(other.title);
    }
  }
}
