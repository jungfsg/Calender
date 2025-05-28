import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/weather_info.dart';
import 'weather_icon.dart';
import '../utils/font_utils.dart';

class WeatherCalendarCell extends StatelessWidget {
  final DateTime day;
  final bool isSelected;
  final bool isToday;
  final Function() onTap;
  final Function() onLongPress;
  final List<String> events;
  final Map<String, Color> eventColors;
  final WeatherInfo? weatherInfo;

  const WeatherCalendarCell({
    Key? key,
    required this.day,
    required this.isSelected,
    required this.isToday,
    required this.onTap,
    required this.onLongPress,
    required this.events,
    required this.eventColors,
    this.weatherInfo,
  }) : super(key: key);

  // 셀 배경 색상 결정
  Color _getBackgroundColor() {
    // 공휴일 체크
    final isHoliday = _isHoliday();
    
    if (isSelected) {
      return const Color.fromARGB(255, 68, 138, 218)!;
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

  // 공휴일 여부 확인
  bool _isHoliday() {
    return events.any((event) => event.startsWith('🎌'));
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
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
                // 날씨 아이콘 (있는 경우에만 표시) - 우상단 유지
                if (weatherInfo != null)
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

                // 이벤트 리스트 - 하단 유지
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
                            final bgColor = eventColors[event] ?? Colors.blue;
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
                                event,
                                style: getCustomTextStyle(
                                  fontSize: 10,
                                  color: Colors.white,
                                ),
                                overflow: TextOverflow.ellipsis,
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
