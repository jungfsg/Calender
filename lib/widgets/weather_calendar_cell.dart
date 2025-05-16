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

  // ubc30uacbd uc0c9uc0c1 uacb0uc815
  Color _getBackgroundColor() {
    if (isSelected) {
      return Colors.blue[800]!;
    } else if (isToday) {
      return Colors.amber[300]!;
    } else if (day.weekday == DateTime.saturday || day.weekday == DateTime.sunday) {
      return const Color(0xFFEEEEEE);
    }
    return Colors.white;
  }

  // ub0a0uc9dc uc0c9uc0c1 uacb0uc815
  Color _getDateColor() {
    if (isSelected) {
      return Colors.white;
    } else if (day.weekday == DateTime.saturday || day.weekday == DateTime.sunday) {
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
            // ub0a0uc9dc ubc88ud638
            Positioned(
              top: 5,
              left: 5,
              child: Text(
                '${day.day}',
                style: getTextStyle(
                  fontSize: 8,
                  color: _getDateColor(),
                ),
              ),
            ),
            
            // ub0a0uc528 uc544uc774ucf58 (uc788ub294 uacbduc6b0uc5d0ub9cc ud45c uc2dc)
            if (weatherInfo != null)
              Positioned(
                top: 5,
                right: 5,
                child: Builder(builder: (context) {
                  print('날씨 아이콘 위치 표시: ${day.day}일 - ${weatherInfo!.condition}');
                  return Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.black, width: 1),
                    ),
                    padding: EdgeInsets.all(2),
                    child: WeatherIcon(
                      weatherInfo: weatherInfo!,
                      size: 16,
                    ),
                  );
                }),
              ),
            
            // uc774ubca4ud2b8 ub9acuc2a4ud2b8
            if (events.isNotEmpty)
              Positioned(
                bottom: 4,
                left: 4,
                right: 4,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: events.take(6).map((event) {
                    final bgColor = eventColors[event] ?? Colors.blue;
                    
                    return Container(
                      margin: const EdgeInsets.only(bottom: 1),
                      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
                      decoration: BoxDecoration(
                        color: bgColor.withOpacity(0.7),
                        border: Border.all(color: Colors.black, width: 1),
                      ),
                      child: Text(
                        event,
                        style: getCustomTextStyle(fontSize: 10, color: Colors.white),
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