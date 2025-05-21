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

  // 배경 색상 결정
  Color _getBackgroundColor() {
    if (isSelected) {
      return Colors.blue[800]!;
    } else if (isToday) {
      return Colors.amber[300]!;
    } else if (day.weekday == DateTime.saturday ||
        day.weekday == DateTime.sunday) {
      return const Color(0xFFEEEEEE);
    }
    return Colors.white;
  }

  // 날짜 색상 결정
  Color _getDateColor() {
    if (isSelected) {
      return Colors.white;
    } else if (day.weekday == DateTime.saturday ||
        day.weekday == DateTime.sunday) {
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
        margin: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: _getBackgroundColor(),
          border: Border.all(color: Colors.black, width: 1),
        ),
        child: Stack(
          children: [
            // 달력에 표시되는 날자 텍스트
            Positioned(
              top: 5,
              left: 5,
              child: Text(
                '${day.day}',
                style: getTextStyle(fontSize: 10, color: _getDateColor()),
              ),
            ),

            // 날씨 아이콘 (있는 경우에만 표시)
            if (weatherInfo != null)
              Positioned(
                top: 5,
                right: 5,
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

            // 이벤트 리스트
            if (events.isNotEmpty)
              Positioned(
                bottom: 4,
                left: 4,
                right: 4,
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
