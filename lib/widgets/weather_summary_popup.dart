import 'package:flutter/material.dart';
import '../models/weather_info.dart';
import '../services/weather_service.dart';
import 'package:url_launcher/url_launcher.dart';
import '../utils/font_utils.dart';
import '../utils/theme_manager.dart'; // ☑️ _HE_250620_추가

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
              // color: Colors.white,
              color: ThemeManager.getEventPopupBackgroundColor(), // ☑️ _HE_250620_변경
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                // color: Colors.black, 
                color: ThemeManager.getEventPopupBorderColor(), // ☑️ _HE_250620_변경
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  // color: Colors.black.withOpacity(0.3),
                  color: ThemeManager.isDarkMode // ☑️ _HE_250620_변경
                      ? Colors.black.withOpacity(0.5) // ☑️ 다크 모드용 그림자
                      : Colors.black.withOpacity(0.3), // ☑️ 라이트 모드용 그림자
                  blurRadius: 10,
                  offset: const Offset(0, 5), // ☑️ _HE_250620_const → 추가
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
                          style: getTextStyle(
                            fontSize: 16, 
                            text: '5일간 날씨 예보',
                            color: ThemeManager.getTextColor(), // ☑️ 텍스트 색상 추가
                          ),
                        ),
                        Text(
                          '(정오 12:00 기준)',
                          style: getTextStyle(
                            fontSize: 11,
                            // color: Colors.grey[600]!,
                            color: ThemeManager.getPopupSecondaryTextColor(), // ☑️ _HE_250620_변경
                            text: '(정오 12:00 기준)',
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.close,
                        color: ThemeManager.getEventPopupCloseButtonColor(), // ☑️ _HE_250620_추가
                      ),
                      onPressed: () => onClose(),
                    ),
                  ],
                ),
                const SizedBox(height: 10), // ☑️ _HE_250620_const → 추가
                Divider(
                  thickness: 2, 
                  // color: Colors.grey.shade300
                  color: ThemeManager.getPopupBorderColor(), // ☑️ _HE_250620_변경
                  ),
                const SizedBox(height: 10), // ☑️ _HE_250620_const → 추가
                // 날씨 목록
                Container(
                  constraints: const BoxConstraints(maxHeight: 300), // ☑️ _HE_250620_const → 추가
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: weatherList.length,
                    itemBuilder: (context, index) {
                      final weather = weatherList[index];
                      return _buildWeatherItem(context, weather, index);
                    },
                  ),
                ),
                const SizedBox(height: 10), // ☑️ _HE_250620_const → 추가
                Divider(
                  thickness: 2, 
                  // color: Colors.grey.shade300
                  color: ThemeManager.getPopupBorderColor(), // ☑️ _HE_250620_변경
                  ),
                const SizedBox(height: 10), // ☑️ _HE_250620_const → 추가
                ElevatedButton(
                  onPressed: _openNaverWeather,
                  style: ElevatedButton.styleFrom(
                    // backgroundColor: Colors.blue,
                    backgroundColor: ThemeManager.isDarkMode  
                        ? Colors.blue[400] // ☑️ 다크 모드용 버튼 색상
                        : Colors.blue, // ☑️ 라이트 모드용 버튼 색상 
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10), // ☑️ _HE_250620_const → 추가
                  ),
                  child: Text(
                    '네이버 날씨에서 자세히 보기',
                    style: getTextStyle(
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
      margin: const EdgeInsets.symmetric(vertical: 4), // ☑️ _HE_250620_const → 추가
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8), // ☑️ _HE_250620_const → 추가
      decoration: BoxDecoration(
        // color:
        //     isToday
        //         ? Colors.amber.withOpacity(0.2)
        //         : isTomorrow
        //         ? Colors.blue.withOpacity(0.1)
        //         : Colors.white,
        color: _getWeatherItemBackgroundColor(isToday, isTomorrow), // ☑️ 배경색 함수로 분리
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          // color:
          //     isToday
          //         ? Colors.amber
          //         : isTomorrow
          //         ? Colors.blue
          //         : Colors.grey.shade300,
          color: _getWeatherItemBorderColor(isToday, isTomorrow), // ☑️ 테두리 색상 함수로 분리
        ),
      ),
      child: Row(
        children: [
          // 날짜 표시
          SizedBox(
            width: 80,
            child: Text(
              dateText,
              style: getTextStyle(
                fontSize: 12, 
                text: dateText,
                color: ThemeManager.getTextColor(), // ☑️ _HE_250620_추가
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
                  style: getTextStyle(
                    fontSize: 12,
                    text: _getWeatherText(weather.condition),
                    color: ThemeManager.getTextColor(), // ☑️ _HE_250620_추가
                  ),
                ),
                Text(
                  '${weather.temperature.toStringAsFixed(1)}°C',
                  style: getTextStyle(
                    fontSize: 12,
                    text: '${weather.temperature.toStringAsFixed(1)}°C',
                    color: ThemeManager.getTextColor(), // ☑️ _HE_250620_추가
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ☑️ 날씨 아이템 배경색 결정 (다크 모드 대응)
  Color _getWeatherItemBackgroundColor(bool isToday, bool isTomorrow) {
    if (isToday) {
      return ThemeManager.isDarkMode 
          ? Colors.amber.withOpacity(0.3) // ☑️ 다크 모드용 오늘 배경
          : Colors.amber.withOpacity(0.2); // ☑️ 라이트 모드용 오늘 배경
    } else if (isTomorrow) {
      return ThemeManager.isDarkMode 
          ? Colors.blue.withOpacity(0.2) // ☑️ 다크 모드용 내일 배경
          : Colors.blue.withOpacity(0.1); // ☑️ 라이트 모드용 내일 배경
    } else {
      return ThemeManager.getPopupSecondaryBackgroundColor(); // ☑️ 기본 배경색
    }
  }

  // ☑️ 날씨 아이템 테두리 색상 결정 (다크 모드 대응)
  Color _getWeatherItemBorderColor(bool isToday, bool isTomorrow) {
    if (isToday) {
      return ThemeManager.isDarkMode 
          ? Colors.amber[300]! // ☑️ 다크 모드용 오늘 테두리
          : Colors.amber; // ☑️ 라이트 모드용 오늘 테두리
    } else if (isTomorrow) {
      return ThemeManager.isDarkMode 
          ? Colors.blue[300]! // ☑️ 다크 모드용 내일 테두리
          : Colors.blue; // ☑️ 라이트 모드용 내일 테두리
    } else {
      return ThemeManager.getPopupBorderColor(); // ☑️ 기본 테두리 색상
    }
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
    final tomorrow = DateTime.now().add(const Duration(days: 1)); // ☑️ _HE_250620_const → 추가
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
