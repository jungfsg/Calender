import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/weather_info.dart';
import '../services/weather_service.dart';

class WeatherIcon extends StatelessWidget {
  final WeatherInfo weatherInfo;
  final double size;

  const WeatherIcon({Key? key, required this.weatherInfo, this.size = 24.0})
    : super(key: key);

  // 아이콘 가져오기
  IconData _getWeatherIcon() {
    switch (weatherInfo.condition) {
      case 'sunny':
        return Icons.wb_sunny;
      case 'cloudy':
        return Icons.cloud;
      case 'rainy':
        return Icons.grain;
      case 'snowy':
        return Icons.ac_unit;
      default:
        return Icons.cloud;
    }
  }

  // 아이콘 색상 결정
  Color _getWeatherColor() {
    switch (weatherInfo.condition) {
      case 'sunny':
        return Colors.orange;
      case 'cloudy':
        return Colors.grey;
      case 'rainy':
        return Colors.blue;
      case 'snowy':
        return Colors.lightBlue;
      default:
        return Colors.grey;
    }
  }

  // 네이버 날씨 열기
  Future<void> _openNaverWeather() async {
    try {
      // 비동기 메서드로 URL 가져오기
      final url = await WeatherService.getNaverWeatherUrl();
      final uri = Uri.parse(url);

      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        throw '열 수 없는 URL: $url';
      }
    } catch (e) {
      print('네이버 날씨 열기 오류: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: _openNaverWeather,
      child: Tooltip(
        message:
            '${weatherInfo.condition} ${weatherInfo.temperature.toStringAsFixed(1)}°C\n${_getDateText()}\n네이버 날씨 열기',
        child: Container(
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            color: _getWeatherColor().withOpacity(0.2),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Icon(_getWeatherIcon(), color: _getWeatherColor(), size: size),
        ),
      ),
    );
  }

  // 날짜 텍스트 생성 (오늘, 내일, 또는 날짜)
  String _getDateText() {
    final today = DateTime.now();
    final tomorrow = DateTime.now().add(Duration(days: 1));

    final weatherDate = DateTime.parse(weatherInfo.date);

    if (weatherDate.year == today.year &&
        weatherDate.month == today.month &&
        weatherDate.day == today.day) {
      return '오늘';
    } else if (weatherDate.year == tomorrow.year &&
        weatherDate.month == tomorrow.month &&
        weatherDate.day == tomorrow.day) {
      return '내일';
    } else {
      return '${weatherDate.month}/${weatherDate.day}';
    }
  }
}
