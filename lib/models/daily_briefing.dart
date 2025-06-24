class DailyBriefing {
  final DateTime date;
  final String summary;
  final DateTime createdAt;
  final DateTime scheduledTime;
  final bool isScheduled;
  final int? notificationId;

  DailyBriefing({
    required this.date,
    required this.summary,
    required this.createdAt,
    required this.scheduledTime,
    this.isScheduled = false,
    this.notificationId,
  });

  // JSON 직렬화
  Map<String, dynamic> toJson() {
    return {
      'date': date.toIso8601String(),
      'summary': summary,
      'createdAt': createdAt.toIso8601String(),
      'scheduledTime': scheduledTime.toIso8601String(),
      'isScheduled': isScheduled,
      'notificationId': notificationId,
    };
  }

  // JSON 역직렬화
  factory DailyBriefing.fromJson(Map<String, dynamic> json) {
    return DailyBriefing(
      date: DateTime.parse(json['date']),
      summary: json['summary'],
      createdAt: DateTime.parse(json['createdAt']),
      scheduledTime: DateTime.parse(json['scheduledTime']),
      isScheduled: json['isScheduled'] ?? false,
      notificationId: json['notificationId'],
    );
  }

  // 복사본 생성
  DailyBriefing copyWith({
    DateTime? date,
    String? summary,
    DateTime? createdAt,
    DateTime? scheduledTime,
    bool? isScheduled,
    int? notificationId,
  }) {
    return DailyBriefing(
      date: date ?? this.date,
      summary: summary ?? this.summary,
      createdAt: createdAt ?? this.createdAt,
      scheduledTime: scheduledTime ?? this.scheduledTime,
      isScheduled: isScheduled ?? this.isScheduled,
      notificationId: notificationId ?? this.notificationId,
    );
  }

  // 날짜가 같은지 확인
  bool isSameDate(DateTime other) {
    return date.year == other.year &&
        date.month == other.month &&
        date.day == other.day;
  }

  // 브리핑이 유효한지 확인 (브리핑 날짜와 현재 날짜 기준으로 판단)
  bool isValid() {
    final now = DateTime.now();
    final timeDifference = now.difference(createdAt).inHours;

    // 브리핑 날짜가 오늘이거나 내일이고, 24시간 이내에 생성된 경우 유효
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(Duration(days: 1));
    final briefingDate = DateTime(date.year, date.month, date.day);

    final isDateValid =
        briefingDate.isAtSameMomentAs(today) ||
        briefingDate.isAtSameMomentAs(tomorrow);

    return isDateValid && timeDifference <= 24; // 24시간 이내로 확장
  }
}
