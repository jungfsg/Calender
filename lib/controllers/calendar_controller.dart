import '../models/event.dart';
import '../models/weather_info.dart';
import 'package:flutter/material.dart';

/// 캘린더 상태를 관리하는 컨트롤러 클래스
class CalendarController {
  // 날짜 상태
  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();

  // 팝업 상태
  bool _showEventPopup = false;
  bool _showWeatherPopup = false; // 데이터 캐시
  final Map<String, List<Event>> _events = {};
  final Map<String, WeatherInfo> _weatherCache = {};

  // 색상 매핑 시스템 - 제목 기반에서 고유 ID 기반으로 변경
  final Map<String, Color> _eventColors = {}; // 이벤트 제목 기준 (이전 방식, 호환성 유지)
  final Map<String, Color> _eventIdColors = {}; // 고유 ID 기준 (새로운 방식)
  final Map<String, Color> _colorIdColors = {}; // Google colorId 기준

  // Public getter for event colors
  Map<String, Color> get eventColors => _eventColors;
  Map<String, Color> get eventIdColors =>
      _eventIdColors; // 고유 ID 색상 매핑 getter 추가
  Map<String, Color> get colorIdColors =>
      _colorIdColors; // Google colorId 색상 매핑 getter 추가

  // 로딩 상태
  final Set<String> _loadingDates = {};
  bool _loadingWeather = false;

  // Getters
  DateTime get focusedDay => _focusedDay;
  DateTime get selectedDay => _selectedDay;
  bool get showEventPopup => _showEventPopup;
  bool get showWeatherPopup => _showWeatherPopup;
  bool get loadingWeather => _loadingWeather;

  // 날짜 키 생성 유틸리티
  String _getKey(DateTime day) {
    return '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
  }

  /// 선택된 날짜 변경
  void setSelectedDay(DateTime day) {
    _selectedDay = day;
    _focusedDay = day;
  }

  /// 포커스된 날짜 변경
  void setFocusedDay(DateTime day) {
    _focusedDay = day;
  }

  /// 이벤트 팝업 표시
  void showEventDialog() {
    _showEventPopup = true;
  }

  /// 이벤트 팝업 숨기기
  void hideEventDialog() {
    _showEventPopup = false;
  }

  /// 날씨 팝업 표시
  void showWeatherDialog() {
    _showWeatherPopup = true;
  }

  /// 날씨 팝업 숨기기
  void hideWeatherDialog() {
    _showWeatherPopup = false;
  }

  /// 특정 날짜의 이벤트 가져오기
  List<Event> getEventsForDay(DateTime day) {
    final key = _getKey(day);
    // 방어적 복사본 반환 (참조 문제 방지)
    return List<Event>.from(_events[key] ?? []);
  }

  /// 특정 날짜의 날씨 정보 가져오기
  WeatherInfo? getWeatherForDay(DateTime day) {
    final key = _getKey(day);
    return _weatherCache[key];
  }

  /// 이벤트 추가 (참조 깨기 로직 추가)
  void addEvent(Event event) {
    final key = _getKey(event.date);
    // 키가 없으면 새 리스트 생성
    if (_events[key] == null) {
      _events[key] = [];
    }

    // 중복 방지 (정확한 비교)
    bool isDuplicate = _events[key]!.any(
      (e) =>
          e.uniqueId == event.uniqueId ||
          (e.title == event.title &&
              e.time == event.time &&
              e.date.year == event.date.year &&
              e.date.month == event.date.month &&
              e.date.day == event.date.day),
    );

    if (!isDuplicate) {
      _events[key]!.add(event);
    }
  }

  /// 이벤트 제거
  void removeEvent(Event event) {
    final key = _getKey(event.date);
    if (_events[key] != null) {
      _events[key]!.removeWhere(
        (e) =>
            e.title == event.title &&
            e.time == event.time &&
            e.date.year == event.date.year &&
            e.date.month == event.date.month &&
            e.date.day == event.date.day,
      );
      print('🗑️ Controller: 이벤트 삭제됨: ${event.title} (${event.time})');
    }
  }

  /// 날씨 정보 캐시
  void cacheWeatherInfo(DateTime day, WeatherInfo weatherInfo) {
    final key = _getKey(day);
    _weatherCache[key] = weatherInfo;
  }

  /// 특정 소스의 이벤트 제거
  void removeEventsBySource(String source) {
    // 새로운 이벤트 맵 생성 (방어적 복사)
    Map<String, List<Event>> newEvents = {};

    for (final key in _events.keys) {
      if (_events[key] != null) {
        // 해당 소스가 아닌 이벤트만 새 맵에 추가
        newEvents[key] =
            _events[key]!.where((e) => e.source != source).toList();
      }
    }

    // 기존 맵을 새 맵으로 교체 (참조 깨기)
    _events.clear();
    _events.addAll(newEvents);

    print('🗑️ Controller: $source 소스의 이벤트 모두 삭제됨');
  }

  /// 특정 날짜의 모든 이벤트 삭제
  void clearEventsForDay(DateTime day) {
    final key = _getKey(day);

    // 기존 참조를 끊고 새 리스트 할당
    if (_events.containsKey(key)) {
      _events[key] = List<Event>.empty(growable: true);
    } else {
      _events[key] = [];
    }

    print('🧹 Controller: ${day.toString().substring(0, 10)} 날짜의 이벤트 모두 삭제됨');
  }

  /// 이벤트 색상 설정
  void setEventColor(String eventTitle, Color color) {
    _eventColors[eventTitle] = color;
  }

  /// 이벤트 색상 가져오기
  Color? getEventColor(String eventTitle) {
    return _eventColors[eventTitle];
  }

  /// 이벤트 ID 기반 색상 설정
  void setEventIdColor(String uniqueId, Color color) {
    _eventIdColors[uniqueId] = color;
  }

  /// 이벤트 ID 기반 색상 가져오기
  Color? getEventIdColor(String uniqueId) {
    return _eventIdColors[uniqueId];
  }

  /// Google colorId 기반 색상 설정
  void setColorIdColor(String colorId, Color color) {
    _colorIdColors[colorId] = color;
  }

  /// Google colorId 기반 색상 가져오기
  Color? getColorIdColor(String colorId) {
    return _colorIdColors[colorId];
  }

  /// 이벤트의 색상 가져오기 (모든 색상 매핑 방식 지원)
  Color getEventDisplayColor(Event event) {
    // 1. 이벤트 자체에 색상이 있는 경우
    if (event.color != null) {
      return event.color!;
    }

    // 2. Google colorId가 있고, 매핑된 색상이 있는 경우
    if (event.colorId != null && getColorIdColor(event.colorId!) != null) {
      return getColorIdColor(event.colorId!)!;
    }

    // 3. 고유 ID 기반 색상이 있는 경우
    if (getEventIdColor(event.uniqueId) != null) {
      return getEventIdColor(event.uniqueId)!;
    }

    // 4. 기존 제목 기반 색상 (호환성 유지)
    if (getEventColor(event.title) != null) {
      // 기존 색상을 고유 ID 기반 매핑으로 마이그레이션
      setEventIdColor(event.uniqueId, getEventColor(event.title)!);
      return getEventColor(event.title)!;
    }

    // 5. 기본 색상 (새로운 이벤트인 경우)
    final defaultColor = Colors.blue;
    setEventIdColor(event.uniqueId, defaultColor); // 기본 색상 저장
    return defaultColor;
  }

  /// 모든 팝업 숨기기
  void hideAllPopups() {
    _showEventPopup = false;
    _showWeatherPopup = false;
  }

  /// 특정 날짜가 로딩 중인지 확인
  bool isDateLoading(DateTime day) {
    final key = _getKey(day);
    return _loadingDates.contains(key);
  }

  /// 로딩 상태 설정
  void setDateLoading(DateTime day, bool loading) {
    final key = _getKey(day);
    if (loading) {
      _loadingDates.add(key);
    } else {
      _loadingDates.remove(key);
    }
  }

  /// 날씨 로딩 상태 설정
  void setWeatherLoading(bool loading) {
    _loadingWeather = loading;
  }

  /// 특정 날짜에 이벤트가 이미 로드되었는지 확인
  bool hasEventsLoadedForDay(DateTime date) {
    final key = _getKey(date);
    return _events[key] != null && _events[key]!.isNotEmpty;
  }

  /// 특정 날짜의 로딩 상태를 확인하고 중복 로드 방지
  bool shouldLoadEventsForDay(DateTime date) {
    return !isDateLoading(date) && !hasEventsLoadedForDay(date);
  }

  /// 월별 이벤트 초기화 (월 변경 시 사용)
  void clearEventsForMonth(DateTime month) {
    final keysToRemove = <String>[];
    for (var key in _events.keys) {
      final parts = key.split('-');
      if (parts.length == 3) {
        final year = int.tryParse(parts[0]);
        final monthPart = int.tryParse(parts[1]);
        if (year == month.year && monthPart == month.month) {
          keysToRemove.add(key);
        }
      }
    }
    for (var key in keysToRemove) {
      _events.remove(key);
    }
  }

  /// 🆕 모든 이벤트 가져오기 (멀티데이 이벤트 처리용)
  List<Event> getAllEvents() {
    final allEvents = <Event>[];
    for (final eventList in _events.values) {
      allEvents.addAll(eventList);
    }
    return allEvents;
  }

  /// 🆕 멀티데이 이벤트 추가 (여러 날짜에 추가)
  void addMultiDayEvent(Event event) {
    if (!event.isMultiDay || event.startDate == null || event.endDate == null) {
      // 일반 이벤트로 처리
      addEvent(event);
      return;
    }

    // 멀티데이 이벤트를 각 날짜에 추가
    final startDate = event.startDate!;
    final endDate = event.endDate!;

    for (int i = 0; i <= endDate.difference(startDate).inDays; i++) {
      final currentDate = startDate.add(Duration(days: i));
      final dailyEvent = event.copyWith(date: currentDate);
      addEvent(dailyEvent);
    }
  }

  /// 🆕 멀티데이 이벤트 제거 (모든 날짜에서 제거)
  void removeMultiDayEvent(Event event) {
    if (!event.isMultiDay || event.startDate == null || event.endDate == null) {
      // 일반 이벤트로 처리
      removeEvent(event);
      return;
    }

    // 멀티데이 이벤트를 모든 관련 날짜에서 제거
    final startDate = event.startDate!;
    final endDate = event.endDate!;

    print('🗑️ CalendarController: 멀티데이 이벤트 제거 시작');
    print('   이벤트: ${event.title}');
    print(
      '   기간: ${startDate.toString().split(' ')[0]} ~ ${endDate.toString().split(' ')[0]}',
    );
    print('   uniqueId: ${event.uniqueId}');

    // 기본 uniqueId 패턴 추출
    final baseUniqueId = event.uniqueId.split('_multiday_')[0];

    for (int i = 0; i <= endDate.difference(startDate).inDays; i++) {
      final currentDate = startDate.add(Duration(days: i));
      final key = _getKey(currentDate);

      if (_events[key] != null) {
        final initialCount = _events[key]!.length;

        // 더 강력한 매칭으로 관련 이벤트들 제거
        _events[key]!.removeWhere(
          (e) =>
              // 1. uniqueId 패턴 매칭
              (e.uniqueId.contains(baseUniqueId) &&
                  e.uniqueId.contains('_multiday_')) ||
              // 2. 정확한 uniqueId 매칭
              e.uniqueId == event.uniqueId ||
              // 3. 멀티데이 속성과 제목, 범위 매칭
              (e.isMultiDay &&
                  e.title == event.title &&
                  e.startDate != null &&
                  e.endDate != null &&
                  e.startDate!.isAtSameMomentAs(startDate) &&
                  e.endDate!.isAtSameMomentAs(endDate)) ||
              // 4. 제목과 날짜 범위가 일치하는 모든 이벤트
              (e.title == event.title &&
                  e.startDate != null &&
                  e.endDate != null &&
                  e.startDate!.isAtSameMomentAs(startDate) &&
                  e.endDate!.isAtSameMomentAs(endDate)),
        );

        final removedCount = initialCount - _events[key]!.length;
        if (removedCount > 0) {
          print(
            '   ${currentDate.toString().split(' ')[0]}: ${removedCount}개 이벤트 제거됨',
          );
        }
      }
    }

    print('✅ CalendarController: 멀티데이 이벤트 제거 완료');
  }
}
