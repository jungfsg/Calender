import 'package:flutter/material.dart';
import '../models/weather_info.dart';
import '../services/weather_service.dart';
import 'package:url_launcher/url_launcher.dart';
import '../utils/font_utils.dart';

class WeatherSummaryPopup extends StatelessWidget {
  final List<WeatherInfo> weatherList;
  final Function onClose;

  const WeatherSummaryPopup({
    super.key,
    required this.weatherList,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.black, width: 2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 10,
                  offset: Offset(0, 5),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '5일간 날씨 예보',
                          style: getCustomTextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            text: '5일간 날씨 예보',
                          ),
                        ),
                        Text(
                          '(정오 12:00 기준)',
                          style: getCustomTextStyle(
                            fontSize: 11,
                            color: Colors.grey[600]!,
                            text: '(정오 12:00 기준)',
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: Icon(Icons.close),
                      onPressed: () => onClose(),
                    ),
                  ],
                ),
                SizedBox(height: 10),
                Divider(thickness: 2, color: Colors.grey.shade300),
                SizedBox(height: 10),
                // 날씨 목록
                Container(
                  constraints: BoxConstraints(maxHeight: 300),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: weatherList.length,
                    itemBuilder: (context, index) {
                      final weather = weatherList[index];
                      return _buildWeatherItem(context, weather, index);
                    },
                  ),
                ),
                SizedBox(height: 10),
                Divider(thickness: 2, color: Colors.grey.shade300),
                SizedBox(height: 10),
                ElevatedButton(
                  onPressed: _openNaverWeather,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  ),
                  child: Text(
                    '네이버 날씨에서 자세히 보기',
                    style: getCustomTextStyle(
                      fontSize: 12,
                      color: Colors.white,
                      text: '네이버 날씨에서 자세히 보기',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWeatherItem(
    BuildContext context,
    WeatherInfo weather,
    int index,
  ) {
    final date = DateTime.parse(weather.date);
    final isToday = _isToday(date);
    final isTomorrow = _isTomorrow(date);

    String dateText;
    if (isToday) {
      dateText = '오늘';
    } else if (isTomorrow) {
      dateText = '내일';
    } else {
      dateText = '${date.month}월 ${date.day}일';
    }

    return Container(
      margin: EdgeInsets.symmetric(vertical: 4),
      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color:
            isToday
                ? Colors.amber.withOpacity(0.2)
                : isTomorrow
                ? Colors.blue.withOpacity(0.1)
                : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color:
              isToday
                  ? Colors.amber
                  : isTomorrow
                  ? Colors.blue
                  : Colors.grey.shade300,
        ),
      ),
      child: Row(
        children: [
          // 날짜 표시
          SizedBox(
            width: 80,
            child: Text(
              dateText,
              style: getCustomTextStyle(
                fontSize: 12,
                fontWeight:
                    isToday || isTomorrow ? FontWeight.bold : FontWeight.normal,
                text: dateText,
              ),
            ),
          ),
          // 날씨 아이콘
          SizedBox(
            width: 40,
            child: Icon(
              _getWeatherIcon(weather.condition),
              color: _getWeatherColor(weather.condition),
              size: 24,
            ),
          ),
          // 날씨 설명 및 온도
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _getWeatherText(weather.condition),
                  style: getCustomTextStyle(
                    fontSize: 12,
                    text: _getWeatherText(weather.condition),
                  ),
                ),
                Text(
                  '${weather.temperature.toStringAsFixed(1)}°C',
                  style: getCustomTextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    text: '${weather.temperature.toStringAsFixed(1)}°C',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 오늘 날짜인지 확인
  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }

  // 내일 날짜인지 확인
  bool _isTomorrow(DateTime date) {
    final tomorrow = DateTime.now().add(Duration(days: 1));
    return date.year == tomorrow.year &&
        date.month == tomorrow.month &&
        date.day == tomorrow.day;
  }

  // 날씨 아이콘 가져오기
  IconData _getWeatherIcon(String condition) {
    switch (condition) {
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

  // 날씨 아이콘 색상 가져오기
  Color _getWeatherColor(String condition) {
    switch (condition) {
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

  // 날씨 상태 텍스트 변환
  String _getWeatherText(String condition) {
    switch (condition) {
      case 'sunny':
        return '맑음';
      case 'cloudy':
        return '흐림';
      case 'rainy':
        return '비';
      case 'snowy':
        return '눈';
      default:
        return '흐림';
    }
  }

  // 네이버 날씨 열기
  Future<void> _openNaverWeather() async {
    try {
      final url = await WeatherService.getNaverWeatherUrl();
      final uri = Uri.parse(url);

      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        throw '열 수 없는 URL: $url';
      }
    } catch (e) {
      print('네이버 날씨 열기 오류: $e');
    }
  }
}
