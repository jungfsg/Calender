import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
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
  });

  // 셀 배경 색상 결정
  Color _getBackgroundColor() {
    // 공휴일 체크
    final isHoliday = _isHoliday();

    if (isSelected) {
      return const Color.fromARGB(255, 68, 138, 218);
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
    // 1. Event 객체의 color 속성 우선
    if (event.color != null) {
      return event.color!;
    }

    // 2. Google colorId 기반 매핑
    if (event.colorId != null &&
        colorIdColors != null &&
        colorIdColors!.containsKey(event.colorId)) {
      return colorIdColors![event.colorId]!;
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
                // 날씨 아이콘 (있는 경우에만 표시 + 5일 범위 내인 경우만) - 우상단 유지
                if (weatherInfo != null &&
                    WeatherService.isWithinForecastRange(day))
                  Positioned(
                    top: 0,
                    right: 0,
                    child: Container(
                      padding: EdgeInsets.all(1),
                      child: WeatherIcon(weatherInfo: weatherInfo!, size: 18),
                    ),
                  ),

                // 날짜를 날씨 아이콘 위에 표시
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

                // 이벤트 리스트 - 하단 유지, Event 객체 기반으로 변경
                if (events.isNotEmpty)
                  Positioned(
                    bottom: 2,
                    left: 2,
                    right: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children:
                          events.take(6).map((event) {
                            final bgColor = _getEventColor(event);
                            return Container(
                              margin: const EdgeInsets.only(bottom: 1),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 2,
                                vertical: 1,
                              ),
                              decoration: BoxDecoration(
                                color: bgColor.withOpacity(0.7),
                                border: Border.all(
                                  color: Colors.black,
                                  width: 1,
                                ),
                              ),
                              child: Text(
                                event.title,
                                style: getCustomTextStyle(
                                  fontSize: 10,
                                  color: Colors.white,
                                ),
                                overflow: TextOverflow.clip,
                                // 글자수 초과 처리 코드
                                // ellipsis: 초과 시 생략 기호 표시
                                // clip: 초과 시 자르기
                                maxLines: 1,
                              ),
                            );
                          }).toList(),
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
