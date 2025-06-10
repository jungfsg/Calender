/// 이벤트 반복 타입을 정의하는 열거형
enum RecurrenceType {
  /// 반복 없음
  none('없음'),

  /// 매일 반복
  daily('매일'),

  /// 매주 반복
  weekly('매주'),

  /// 매월 반복
  monthly('매월'),

  /// 매년 반복
  yearly('매년');

  const RecurrenceType(this.label);

  /// 사용자에게 표시될 라벨
  final String label;

  /// 기본 반복 횟수를 반환
  int get defaultCount {
    switch (this) {
      case RecurrenceType.daily:
        return 1;
      case RecurrenceType.weekly:
        return 1;
      case RecurrenceType.monthly:
        return 1;
      case RecurrenceType.yearly:
        return 1;
      case RecurrenceType.none:
        return 1;
    }
  }

  /// 문자열에서 RecurrenceType으로 변환
  static RecurrenceType fromString(String value) {
    switch (value.toLowerCase()) {
      case 'daily':
      case '매일':
        return RecurrenceType.daily;
      case 'weekly':
      case '매주':
        return RecurrenceType.weekly;
      case 'monthly':
      case '매월':
        return RecurrenceType.monthly;
      case 'yearly':
      case '매년':
        return RecurrenceType.yearly;
      case 'none':
      case '없음':
      default:
        return RecurrenceType.none;
    }
  }

  /// RecurrenceType을 문자열로 변환
  @override
  String toString() {
    return name;
  }
}
