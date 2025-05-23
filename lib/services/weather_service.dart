import 'dart:convert';
import 'dart:math' as math;
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geocoding/geocoding.dart';
import '../models/weather_info.dart';

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
  static Future<List<WeatherInfo>> get5DayForecast() async {
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
    }

    // 현재 위치 가져오기
    print('위치 정보 요청 중...');
    final position = await getCurrentLocation();
    if (position == null) {
      print('위치 정보를 가져올 수 없습니다.');
      return _generateDummyForecast(); // 위치 정보가 없을 경우 더미 데이터 반환
    }

    print('위치: ${position.latitude}, ${position.longitude}');

    // OpenWeatherMap API로 날씨 정보 가져오기
    final url =
        '$baseUrl/forecast?lat=${position.latitude}&lon=${position.longitude}&units=metric&appid=$apiKey';

    try {
      print('날씨 API 요청: $url');
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        print('날씨 API 응답 성공!');
        final data = jsonDecode(response.body);

        // 날씨 데이터 파싱
        final List<dynamic> list = data['list'];

        // 5일간의 날씨 정보 추출
        final List<WeatherInfo> weatherList = [];
        final dateFormat = DateFormat('yyyy-MM-dd');
        final Map<String, bool> dateProcessed = {}; // 날짜별 처리 여부 체크

        // 각 예보 시간별 데이터에서 5일치 날씨 정보 추출
        for (var forecast in list) {
          // 날짜 추출 (yyyy-MM-dd 형식)
          final timestamp = forecast['dt'] * 1000; // 초 단위를 밀리초로 변환
          final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
          final dateStr = dateFormat.format(date);

          // 이미 해당 날짜가 처리되었으면 스킵
          if (dateProcessed[dateStr] == true) continue;

          // 아직 5일치가 차지 않았으면 추가
          if (weatherList.length < 5) {
            dateProcessed[dateStr] = true;

            weatherList.add(
              WeatherInfo(
                date: dateStr,
                condition: _mapWeatherCondition(forecast['weather'][0]['main']),
                temperature: forecast['main']['temp'].toDouble(),
                lat: position.latitude,
                lon: position.longitude,
              ),
            );

            print('날씨 정보 추가: $dateStr, ${forecast['weather'][0]['main']}');
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
        print('날씨 API 응답 오류: ${response.statusCode}, ${response.body}');
        return _generateDummyForecast();
      }
    } catch (e) {
      print('날씨 API 오류: $e');
      return _generateDummyForecast();
    }
  }

  // 5일 더미 날씨 데이터 생성
  static List<WeatherInfo> _generateDummyForecast() {
    print('더미 날씨 데이터 생성');
    final List<WeatherInfo> dummyList = [];
    final dateFormat = DateFormat('yyyy-MM-dd');
    final now = DateTime.now();

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
          lat: 37.5665, // 서울 기준 위치
          lon: 126.9780,
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

  // ub0a0uc528 uc0c1ud0dc ub9e4ud551
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

  // ub124uc774ubc84 uc9c0ub3c4 URL uc0dduc131
  static String getNaverMapUrl(double lat, double lon) {
    return 'https://m.map.naver.com/map.naver?lat=$lat&lng=$lon&level=12';
  }

  // 네이버 날씨 URL 생성
  static Future<String> getNaverWeatherUrl() async {
    try {
      // 현재 위치 가져오기
      final position = await getCurrentLocation();
      if (position != null) {
        try {
          // 위도/경도로 주소 얻기 (지오코딩)
          final placemarks = await placemarkFromCoordinates(
            position.latitude,
            position.longitude,
            localeIdentifier: 'ko_KR', // 한글 주소 요청
          );

          if (placemarks.isNotEmpty) {
            final placemark = placemarks.first;

            // 시/도 정보만 사용
            String? administrativeArea = placemark.administrativeArea;

            // 시/도 정보가 있는 경우에만 사용
            if (administrativeArea != null && administrativeArea.isNotEmpty) {
              print(
                '위치 -> 주소 변환: $administrativeArea (위도=${position.latitude}, 경도=${position.longitude})',
              );

              // 네이버 날씨 검색 URL 생성
              final encodedQuery = Uri.encodeComponent(administrativeArea);
              return 'https://weather.naver.com/today/$encodedQuery';
            } else {
              print('시/도 정보를 찾을 수 없습니다. 기본 URL 사용');
            }
          } else {
            print('placemarks가 비어 있습니다.');
          }
        } catch (geocodingError) {
          print('위치 -> 주소 변환 오류: $geocodingError');
        }

        // 주소를 찾을 수 없는 경우 기본 URL 반환
        return 'https://weather.naver.com/';
      } else {
        print('위치 정보를 가져올 수 없습니다.');
      }
    } catch (e) {
      print('위치 정보 변환 오류: $e');
    }

    // 위치 정보를 가져올 수 없는 경우 기본 URL 반환
    return 'https://weather.naver.com/';
  }
}
