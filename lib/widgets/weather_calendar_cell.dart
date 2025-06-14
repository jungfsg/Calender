import 'package:flutter/material.dart';
import '../models/weather_info.dart';
import '../models/event.dart';
import 'weather_icon.dart';
import '../utils/font_utils.dart';
import '../services/weather_service.dart';

class WeatherCalendarCell extends StatelessWidget {
  final DateTime day;
  final bool isSelected;
  final bool isToday;
  final Function() onTap;
  final List<Event> events;
  final Map<String, Color> eventColors;
  final Map<String, Color>? eventIdColors; // ID 기반 색상 매핑 추가
  final Map<String, Color>? colorIdColors; // Google colorId 색상 매핑 추가
  final WeatherInfo? weatherInfo;
  final List<Event>? allEvents; // 🆕 전체 이벤트 목록 (멀티데이 이벤트 처리용)
  const WeatherCalendarCell({
    super.key,
    required this.day,
    required this.isSelected,
    required this.isToday,
    required this.onTap,
    required this.events,
    required this.eventColors,
    this.eventIdColors,
    this.colorIdColors,
    this.weatherInfo,
    this.allEvents, // 🆕 전체 이벤트 목록
  });

  // 셀 배경 색상 결정
  Color _getBackgroundColor() {
    // 공휴일 체크
    final isHoliday = _isHoliday();

    if (isSelected) {
      return const Color.fromARGB(200, 68, 138, 218);
    } else if (isToday) {
      return Colors.amber[300]!;
    } else if (isHoliday) {
      return const Color.fromARGB(255, 255, 240, 240); // 연한 빨간색 배경
    } else if (day.weekday == DateTime.saturday ||
        day.weekday == DateTime.sunday) {
      return const Color.fromARGB(255, 255, 255, 255);
    }
    return Colors.white;
  }

  // 날짜 색상 결정
  Color _getDateColor() {
    // 공휴일 체크
    final isHoliday = _isHoliday();

    if (isSelected) {
      return Colors.white;
    } else if (isHoliday) {
      return Colors.red; // 공휴일은 빨간색
    } else if (day.weekday == DateTime.saturday) {
      return const Color.fromARGB(255, 54, 184, 244);
    } else if (day.weekday == DateTime.sunday) {
      return Colors.red;
    }
    return Colors.black;
  }

  // 공휴일 여부 확인 - 실제 휴무인 공휴일만
  bool _isHoliday() {
    // 실제로 쉬는 공휴일만 포함
    final actualHolidays = {
      '신정',
      '설날',
      '삼일절',
      '석가탄신일',
      '부처님오신날',
      '어린이날',
      '현충일',
      '광복절',
      '추석',
      '개천절',
      '한글날',
      '크리스마스',
      '대체공휴일',
      '임시공휴일',
    };

    return events.any(
      (event) => actualHolidays.any((holiday) => event.title.contains(holiday)),
    );
  }

  // 이벤트 색상 가져오기 - 고유 ID 기반 시스템 우선
  Color _getEventColor(Event event) {
    // 1. Google colorId 기반 매핑
    if (event.colorId != null &&
        colorIdColors != null &&
        colorIdColors!.containsKey(event.colorId)) {
      return colorIdColors![event.colorId]!;
    }

    // 2. Event 객체의 color 속성 우선
    if (event.color != null) {
      return event.color!;
    }

    // 3. 고유 ID 기반 색상 매핑 (새로운 방식)
    if (eventIdColors != null && eventIdColors!.containsKey(event.uniqueId)) {
      return eventIdColors![event.uniqueId]!;
    }

    // 4. 제목 기반 색상 매핑 (이전 방식, 호환성 유지)
    if (eventColors.containsKey(event.title)) {
      return eventColors[event.title]!;
    }

    // 5. 기본 색상
    return Colors.blue;
  }

  // HH:mm 형식의 시간을 분으로 변환하는 헬퍼 메서드
  int _parseTimeToMinutes(String timeStr) {
    try {
      if (timeStr.isEmpty) return 9999; // 시간이 없는 이벤트는 맨 뒤로

      final parts = timeStr.split(':');
      if (parts.length != 2) return 9999;

      final hour = int.parse(parts[0]);
      final minute = int.parse(parts[1]);

      return hour * 60 + minute;
    } catch (e) {
      return 9999; // 파싱 실패시 맨 뒤로
    }
  }

  // 🆕 해당 날짜의 멀티데이 이벤트들을 찾는 메서드
  List<Event> _getMultiDayEventsForDate() {
    if (allEvents == null) {
      return [];
    }

    final multiDayEvents =
        allEvents!.where((event) {
          return event.isMultiDay && event.containsDate(day);
        }).toList();

    if (multiDayEvents.isNotEmpty) {
      print(
        '📅 ${day.toString().substring(0, 10)}에 멀티데이 이벤트 ${multiDayEvents.length}개 발견: ${multiDayEvents.map((e) => e.title).join(', ')}',
      );
    }

    return multiDayEvents;
  }

  // 🆕 멀티데이 이벤트가 이 날짜에서 어떤 상태인지 확인
  String _getMultiDayEventStatus(Event event) {
    if (!event.isMultiDay) return 'none';
    if (event.isStartDate(day)) return 'start';
    if (event.isEndDate(day)) return 'end';
    if (event.isMiddleDate(day)) return 'middle';
    return 'none';
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: LayoutBuilder(
        builder: (context, constraints) {
          // 셀의 너비를 기준으로 날짜 폰트 크기 계산
          // 달력의 셀 크기는 calendar_screen.dart 파일의 TableCalendar 위젯에서 설정됨
          final cellWidth = constraints.maxWidth;
          final fontSize = cellWidth * 0.15; // 셀 너비 대비 비율

          return Container(
            padding: const EdgeInsets.all(2),
            color: _getBackgroundColor(),
            child: Stack(
              children: [
                // 날씨 아이콘 (있는 경우에만 표시 + 5일 범위 내인 경우만) - 우상단
                if (weatherInfo != null &&
                    WeatherService.isWithinForecastRange(day))
                  Positioned(
                    top: 2,
                    right: 0,
                    child: Container(
                      padding: EdgeInsets.all(1),
                      child: WeatherIcon(weatherInfo: weatherInfo!, size: 18),
                    ),
                  ),

                // 날짜 표시 - 상단 중앙
                Positioned(
                  top: 8,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Text(
                      '${day.day}',
                      style: getTextStyle(
                        fontSize: fontSize,
                        color: _getDateColor(),
                      ),
                    ),
                  ),
                ),

                // 🆕 멀티데이 이벤트들을 날짜 바로 아래에 표시 (중복 제거)
                ...() {
                  final multiDayEvents = _getMultiDayEventsForDate();
                  final uniqueEvents = <String, Event>{};

                  // 중복 제거: 같은 uniqueId를 가진 이벤트는 하나만 표시
                  for (final event in multiDayEvents) {
                    if (!uniqueEvents.containsKey(event.uniqueId)) {
                      uniqueEvents[event.uniqueId] = event;
                    }
                  }

                  return uniqueEvents.values.toList().asMap().entries.map((
                    entry,
                  ) {
                    final index = entry.key;
                    final event = entry.value;
                    final status = _getMultiDayEventStatus(event);
                    final bgColor = _getEventColor(event);

                    return Positioned(
                      top:
                          28.0 +
                          (index * 12.0), // 날짜(top: 8 + fontSize) 바로 아래에 배치
                      left: 1,
                      right: 1,
                      child: Container(
                        height: 15,
                        decoration: BoxDecoration(
                          color: bgColor.withOpacity(0.8),
                          borderRadius:
                              status == 'start'
                                  ? const BorderRadius.only(
                                    topLeft: Radius.circular(3),
                                    bottomLeft: Radius.circular(3),
                                  )
                                  : status == 'end'
                                  ? const BorderRadius.only(
                                    topRight: Radius.circular(3),
                                    bottomRight: Radius.circular(3),
                                  )
                                  : BorderRadius.zero,
                          border: Border.all(
                            color: bgColor.withOpacity(0.9),
                            width: 1,
                          ),
                        ),
                        child:
                            status == 'start'
                                ? Padding(
                                  padding: const EdgeInsets.only(left: 2),
                                  child: Text(
                                    event.title,
                                    style: getTextStyle(
                                      fontSize: 6, // 4는 너무 작아서 6으로 조정
                                      color: Colors.white,
                                    ),
                                    overflow: TextOverflow.clip,
                                    maxLines: 1,
                                  ),
                                )
                                : Container(), // 중간이나 끝에서는 제목 표시 안함
                      ),
                    );
                  }).toList();
                }(), // 이벤트 리스트 - 하단 유지, Event 객체 기반으로 변경 + 시간순 정렬 (멀티데이 이벤트 제외)
                if (events.isNotEmpty)
                  Positioned(
                    bottom: 2,
                    left: 0,
                    right: 0,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: () {
                        // 멀티데이 이벤트는 제외하고 일반 이벤트만 표시 (isMultiDay 플래그와 uniqueId 패턴 모두 체크)
                        final regularEvents =
                            events
                                .where(
                                  (event) =>
                                      !event.isMultiDay &&
                                      !event.uniqueId.contains('_multiday_'),
                                )
                                .toList();

                        // 이벤트를 시간순으로 정렬
                        final sortedEvents = List<Event>.from(regularEvents);
                        sortedEvents.sort((a, b) {
                          if (a.time.isEmpty && b.time.isEmpty) return 0;
                          if (a.time.isEmpty) return 1;
                          if (b.time.isEmpty) return -1;

                          // HH:mm 형식의 시간을 분으로 변환하여 비교
                          final aTime = _parseTimeToMinutes(a.time);
                          final bTime = _parseTimeToMinutes(b.time);
                          return aTime.compareTo(bTime);
                        });

                        // 정렬된 이벤트에서 표시할 개수만 선택
                        final hasMultiDayEvents =
                            _getMultiDayEventsForDate().isNotEmpty;
                        final maxEvents = hasMultiDayEvents ? 3 : 4;
                        final displayEvents = hasMultiDayEvents ? 2 : 3;
                        final eventsToShow =
                            sortedEvents.length > maxEvents
                                ? sortedEvents.take(displayEvents).toList()
                                : sortedEvents.take(maxEvents).toList();

                        List<Widget> widgets =
                            eventsToShow.map((event) {
                              final bgColor = _getEventColor(event);
                              return Container(
                                margin: const EdgeInsets.only(bottom: 1),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 2,
                                  vertical: 1,
                                ),
                                decoration: BoxDecoration(
                                  color: bgColor.withOpacity(0.9),
                                  border: Border.all(
                                    color: const Color.fromARGB(
                                      255,
                                      141,
                                      141,
                                      141,
                                    ),
                                    width: 1,
                                  ),
                                ),
                                child: Text(
                                  event.title,
                                  style: getTextStyle(
                                    fontSize: 10,
                                    color: const Color.fromARGB(255, 0, 0, 0),
                                  ),
                                  overflow: TextOverflow.clip,
                                  maxLines: 1,
                                ),
                              );
                            }).toList();

                        // "+N개 더" 표시 추가
                        if (sortedEvents.length > maxEvents) {
                          widgets.add(
                            Container(
                              margin: const EdgeInsets.only(bottom: 1),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 2,
                                vertical: 1,
                              ),
                              decoration: BoxDecoration(
                                color: const Color.fromARGB(255, 185, 185, 185),
                                border: Border.all(
                                  color: const Color.fromARGB(
                                    255,
                                    168,
                                    168,
                                    168,
                                  ),
                                  width: 1,
                                ),
                              ),
                              child: Text(
                                '+${sortedEvents.length - displayEvents}',
                                style: getTextStyle(
                                  fontSize: 10,
                                  color: const Color.fromARGB(135, 0, 0, 0),
                                ),
                                overflow: TextOverflow.clip,
                                maxLines: 1,
                              ),
                            ),
                          );
                        }

                        return widgets;
                      }(),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
