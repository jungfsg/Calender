class Event {
  final String title;
  final String time; // HH:mm 형식의 시간
  final DateTime date;
  final String description; // 이벤트 설명 추가

  Event({
    required this.title,
    required this.time,
    required this.date,
    this.description = '', // 기본값으로 빈 문자열 설정
  });

  // JSON 직렬화를 위한 메서드
  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'time': time,
      'date': date.toIso8601String(),
      'description': description,
    };
  }

  // JSON 역직렬화를 위한 팩토리 생성자
  factory Event.fromJson(Map<String, dynamic> json) {
    return Event(
      title: json['title'],
      time: json['time'],
      date: DateTime.parse(json['date']),
      description: json['description'] ?? '',
    );
  }

  // 시간 비교를 위한 메서드
  int compareTo(Event other) {
    return time.compareTo(other.time);
  }
} 