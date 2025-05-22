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
    if (isSelected) {
      return const Color.fromARGB(255, 68, 138, 218)!;
    } else if (isToday) {
      return Colors.amber[300]!;
    } else if (day.weekday == DateTime.saturday ||
        day.weekday == DateTime.sunday) {
      return const Color.fromARGB(255, 255, 255, 255);
    }
    return Colors.white;
  }

  // 날짜 색상 결정
  Color _getDateColor() {
    if (isSelected) {
      return Colors.white;
    } else if (day.weekday == DateTime.saturday) {
      return const Color.fromARGB(255, 54, 184, 244);
    } else if (day.weekday == DateTime.sunday) {
      return Colors.red;
    }
    return Colors.black;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        // 여백만 남기고 테두리 제거
        padding: const EdgeInsets.all(2),
        color: _getBackgroundColor(),
        child: Stack(
          children: [
            // 달력에 표시되는 날짜 텍스트를 중앙 상단에 배치
            Positioned(
              top: 8, // 상단에서 약간 여백
              left: 0,
              right: 0,
              child: Center(
                child: Text(
                  '${day.day}',
                  style: getTextStyle(fontSize: 16, color: _getDateColor()),
                ),
              ),
            ),

            // 날씨 아이콘 (있는 경우에만 표시) - 우상단 유지
            if (weatherInfo != null)
              Positioned(
                top: 3,
                right: 3,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: Colors.black, width: 1),
                  ),
                  padding: EdgeInsets.all(2),
                  child: WeatherIcon(weatherInfo: weatherInfo!, size: 16),
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
                            border: Border.all(color: Colors.black, width: 1),
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
      ),
    );
  }
}
