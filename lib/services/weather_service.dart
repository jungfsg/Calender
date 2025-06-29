import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geocoding/geocoding.dart';
import '../models/weather_info.dart';
import '../controllers/calendar_controller.dart';

class WeatherService {
  // OpenWeatherMap API 키 (실제 키로 변경하세요)
  static const String apiKey =
      'b17dadb6340528a9d0764c6c2643de4f'; // 예시 키입니다. 실제 작동하는 키로 변경하세요
  static const String baseUrl = 'https://api.openweathermap.org/data/2.5';

  // 캐시 키
  static const String _cacheKey = 'weather_cache';
  static const Duration _cacheDuration = Duration(hours: 2); // 캐시 유효 시간

  // 위치 권한 체크
  static Future<bool> checkLocationPermission() async {
    bool serviceEnabled;
    LocationPermission permission;

    // 위치 서비스 활성화 확인
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return false;
    }

    // 권한 확인
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return false;
    }

    return true;
  }

  // 현재 위치 가져오기
  static Future<Position?> getCurrentLocation() async {
    if (!await checkLocationPermission()) {
      return null;
    }

    return await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.low,
    );
  }

  // 5일간 날씨 예보 가져오기
  static Future<List<WeatherInfo>> get5DayForecast({
    int targetHour = 12,
  }) async {
    print('날씨 정보 로드 시작...');
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();

    // 캐시 확인
    final cacheData = prefs.getString(_cacheKey);
    if (cacheData != null) {
      final cache = jsonDecode(cacheData);
      final cacheTime = DateTime.parse(cache['timestamp']);

      // 캐시가 유효한지 확인
      if (now.difference(cacheTime) < _cacheDuration) {
        print('캐시에서 날씨 정보 로드');
        final List<dynamic> weatherList = cache['data'];
        return weatherList.map((item) {
          return WeatherInfo(
            date: item['date'],
            condition: item['condition'],
            temperature: item['temperature'],
            lat: item['lat'],
            lon: item['lon'],
          );
        }).toList();
      }
    } // 현재 위치 가져오기
    print('위치 정보 요청 중...');
    final position = await getCurrentLocation();
    if (position == null) {
      print('위치 정보를 가져올 수 없습니다.');
      return _generateDummyForecast(null, null); // 위치 정보가 없을 경우 더미 데이터 반환
    }

    print('위치: ${position.latitude}, ${position.longitude}');

    // OpenWeatherMap API로 날씨 정보 가져오기
    final url =
        '$baseUrl/forecast?lat=${position.latitude}&lon=${position.longitude}&units=metric&appid=$apiKey';

    try {
      print('날씨 API 요청: $url');
      final response = await http.get(Uri.parse(url));
      print('API 응답 상태 코드: ${response.statusCode}');
      print('API 응답 내용: ${response.body}');

      if (response.statusCode == 200) {
        print('날씨 API 응답 성공!');
        final data = jsonDecode(response.body); // 날씨 데이터 파싱
        final List<dynamic> list = data['list'];

        // 5일간의 날씨 정보 추출 (정오 12시 기준)
        final List<WeatherInfo> weatherList = [];
        final dateFormat = DateFormat('yyyy-MM-dd');
        final Map<String, Map<String, dynamic>> dailyBestForecast =
            {}; // 날짜별 최적 예보 데이터

        // 각 예보 시간별 데이터에서 정오에 가장 가까운 시간대 찾기
        for (var forecast in list) {
          // 날짜 추출 (yyyy-MM-dd 형식)
          final timestamp = forecast['dt'] * 1000; // 초 단위를 밀리초로 변환
          final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
          final dateStr = dateFormat.format(date);
          final hour = date.hour;

          // 정오(12시)에 가장 가까운 시간대를 선택
          // OpenWeatherMap은 3시간 간격: 00, 03, 06, 09, 12, 15, 18, 21
          // 우선순위: 12시 > 09시 또는 15시 > 기타
          if (!dailyBestForecast.containsKey(dateStr) ||
              _isCloserToNoon(hour, dailyBestForecast[dateStr]!['hour'])) {
            dailyBestForecast[dateStr] = {'forecast': forecast, 'hour': hour};
          }
        }

        // 날짜순으로 정렬하여 최대 5일치 weatherList에 추가
        final sortedDates = dailyBestForecast.keys.toList()..sort();
        for (final dateStr in sortedDates) {
          if (weatherList.length < 5) {
            final bestForecast = dailyBestForecast[dateStr]!['forecast'];
            final hour = dailyBestForecast[dateStr]!['hour'];

            weatherList.add(
              WeatherInfo(
                date: dateStr,
                condition: _mapWeatherCondition(
                  bestForecast['weather'][0]['main'],
                ),
                temperature: bestForecast['main']['temp'].toDouble(),
                lat: position.latitude,
                lon: position.longitude,
              ),
            );

            print(
              '날씨 정보 추가: $dateStr ($hour시), ${bestForecast['weather'][0]['main']}',
            );
          }
        }

        // API에서 충분한 날짜 데이터를 가져오지 못한 경우 더미 데이터로 보충
        if (weatherList.length < 5) {
          print('API에서 충분한 날짜를 가져오지 못했습니다. 더미 데이터로 보충합니다.');
          _fillWithDummyData(
            weatherList,
            5, // 5일로 변경
            position.latitude,
            position.longitude,
          );
        }

        // 캐시 업데이트
        final cacheValue = {
          'timestamp': now.toIso8601String(),
          'data':
              weatherList
                  .map(
                    (w) => {
                      'date': w.date,
                      'condition': w.condition,
                      'temperature': w.temperature,
                      'lat': w.lat,
                      'lon': w.lon,
                    },
                  )
                  .toList(),
        };

        await prefs.setString(_cacheKey, jsonEncode(cacheValue));
        print('날씨 정보 캐시 저장 완료: ${weatherList.length}개');
        return weatherList;
      } else {
        print('❌ API 호출 실패 - 상태코드: ${response.statusCode}');
        print('❌ 오류 메시지: ${response.body}');
        return _generateDummyForecast(position.latitude, position.longitude);
      }
    } catch (e) {
      print('❌ API 호출 예외 발생: $e');
      return _generateDummyForecast(position.latitude, position.longitude);
    }
  }

  // 5일 더미 날씨 데이터 생성
  static List<WeatherInfo> _generateDummyForecast([double? lat, double? lon]) {
    print('더미 날씨 데이터 생성');
    final List<WeatherInfo> dummyList = [];
    final dateFormat = DateFormat('yyyy-MM-dd');
    final now = DateTime.now();

    // 실제 위치가 있으면 사용, 없으면 서울 기본값
    final double useLat = lat ?? 37.5665;
    final double useLon = lon ?? 126.9780;

    print('더미 데이터 위치: 위도=$useLat, 경도=$useLon');

    // 날씨 상태를 snowy로 고정, 온도를 99도로 설정(디버깅 용 더미)
    const String weatherCondition = 'snowy';
    const double weatherTemperature = 99.0;

    // 5일치 더미 데이터 생성
    for (int i = 0; i < 5; i++) {
      final date = now.add(Duration(days: i));
      final dateStr = dateFormat.format(date);

      dummyList.add(
        WeatherInfo(
          date: dateStr,
          condition: weatherCondition,
          temperature: weatherTemperature,
          lat: useLat, // 실제 위치 사용
          lon: useLon,
        ),
      );
    }

    return dummyList;
  }

  // 기존 리스트에 더미 데이터 채우기
  static void _fillWithDummyData(
    List<WeatherInfo> list,
    int targetCount,
    double lat,
    double lon,
  ) {
    final dateFormat = DateFormat('yyyy-MM-dd');
    final now = DateTime.now();

    // 날씨 상태를 snowy로 고정, 온도를 99도로 설정
    const String weatherCondition = 'snowy';
    const double weatherTemperature = 99.0;

    // 마지막 날짜 찾기
    DateTime lastDate = now;
    if (list.isNotEmpty) {
      lastDate = DateFormat('yyyy-MM-dd').parse(list.last.date);
    }

    // 더미 데이터 추가
    int dayOffset = list.isEmpty ? 0 : 1; // 빈 리스트면 오늘부터, 아니면 마지막 날짜 다음날부터

    while (list.length < targetCount) {
      final date = lastDate.add(Duration(days: dayOffset));
      final dateStr = dateFormat.format(date);

      list.add(
        WeatherInfo(
          date: dateStr,
          condition: weatherCondition,
          temperature: weatherTemperature,
          lat: lat,
          lon: lon,
        ),
      );

      dayOffset++;
    }
  }

  // 날씨 상태 매핑
  static String _mapWeatherCondition(String condition) {
    final lowerCondition = condition.toLowerCase();

    if (lowerCondition.contains('clear')) {
      return 'sunny';
    } else if (lowerCondition.contains('cloud') ||
        lowerCondition.contains('overcast')) {
      return 'cloudy';
    } else if (lowerCondition.contains('rain') ||
        lowerCondition.contains('drizzle')) {
      return 'rainy';
    } else if (lowerCondition.contains('snow')) {
      return 'snowy';
    } else {
      return 'cloudy';
    }
  }

  // 네이버 지도 URL 생성
  static String getNaverMapUrl(double lat, double lon) {
    return 'https://m.map.naver.com/map.naver?lat=$lat&lng=$lon&level=12';
  }

  static Future<String> getNaverWeatherUrl() async {
    try {
      final position = await getCurrentLocation();
      if (position != null) {
        final placemarks = await placemarkFromCoordinates(
          position.latitude,
          position.longitude,
          localeIdentifier: 'ko_KR',
        );

        if (placemarks.isNotEmpty) {
          final placemark = placemarks.first;
          String location =
              placemark.locality ?? placemark.administrativeArea ?? '서울';

          print('날씨 검색 지역: $location');
          print(
            '위치 -> 주소 변환: ${placemark.administrativeArea} ${placemark.locality} (위도=${position.latitude}, 경도=${position.longitude})',
          );

          // 네이버 날씨 홈페이지로 직접 이동
          return 'https://weather.naver.com/';
        }
      }
    } catch (e) {
      print('위치 정보 오류: $e');
    }
    // 위치 정보를 가져올 수 없는 경우 네이버 날씨 메인 페이지
    return 'https://weather.naver.com/';
  }

  // 정오(12시)에 더 가까운 시간인지 확인하는 헬퍼 함수
  static bool _isCloserToNoon(int newHour, int currentHour) {
    // 정오(12시)를 기준으로 거리 계산
    final newDistance = (newHour - 12).abs();
    final currentDistance = (currentHour - 12).abs();

    // 새로운 시간이 정오에 더 가까우면 true
    return newDistance < currentDistance;
  }

  /// 캘린더 표시용 날씨 로드 (오늘부터 정확히 5일)
  static Future<List<WeatherInfo>> loadCalendarWeather(
    CalendarController controller,
  ) async {
    final weatherList = await get5DayForecast();
    final today = DateTime.now();
    final todayStr = DateFormat('yyyy-MM-dd').format(today);

    // 오늘 날짜부터 시작하는 데이터만 필터링
    final filteredList =
        weatherList.where((weather) {
          // 날짜 문자열을 DateTime으로 변환하여 비교
          final weatherDate = DateTime.parse(weather.date);
          final todayDate = DateTime(today.year, today.month, today.day);
          return weatherDate.compareTo(todayDate) >= 0; // 오늘 또는 이후 날짜만
        }).toList();

    // 앞에서부터 최대 5일치만 사용
    final limitedWeatherList = filteredList.take(5).toList();

    if (limitedWeatherList.isNotEmpty) {
      // 날씨 정보를 컨트롤러 캐시에 저장
      for (var weather in limitedWeatherList) {
        final date = DateTime.parse(weather.date);
        controller.cacheWeatherInfo(date, weather);
      }
    }

    print('캘린더 날씨 로드 완료: ${limitedWeatherList.length}일간 예보 ($todayStr 부터)');
    return limitedWeatherList;
  }

  /// 특정 날짜가 5일 예보 범위 내인지 확인 (오늘부터 정확히 5일)
  static bool isWithinForecastRange(DateTime day) {
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day); // 시간 제거
    final checkDate = DateTime(day.year, day.month, day.day); // 시간 제거

    final daysDifference = checkDate.difference(todayDate).inDays;

    return daysDifference >= 0 && daysDifference < 5;
  }
}
