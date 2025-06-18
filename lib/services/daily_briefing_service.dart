import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import '../models/daily_briefing.dart';
import '../models/event.dart';
import '../models/weather_info.dart';
import 'event_storage_service.dart';
import 'chat_service.dart';
import 'notification_service.dart';

class DailyBriefingService {
  static const String _briefingPrefix = 'briefing_';
  static const String _settingsKey = 'briefing_settings';
  static const String _defaultBriefingTime = '08:00';

  // 브리핑 설정 저장/불러오기
  static Future<Map<String, dynamic>> getBriefingSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final settingsJson = prefs.getString(_settingsKey);

    if (settingsJson != null) {
      return jsonDecode(settingsJson);
    }

    // 기본 설정 (includeTomorrow 제거)
    return {'enabled': false, 'time': _defaultBriefingTime};
  }

  static Future<void> saveBriefingSettings(
    Map<String, dynamic> settings,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_settingsKey, jsonEncode(settings));
  }

  // 날씨 정보 가져오기
  static Future<WeatherInfo?> getWeatherForDate(DateTime date) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheData = prefs.getString('weather_cache');

      if (cacheData != null) {
        final cache = jsonDecode(cacheData);
        final List<dynamic> weatherList = cache['data'];

        final dateStr =
            '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

        for (var weatherData in weatherList) {
          if (weatherData['date'] == dateStr) {
            return WeatherInfo(
              date: weatherData['date'],
              condition: weatherData['condition'],
              temperature: weatherData['temperature'].toDouble(),
              lat: weatherData['lat'],
              lon: weatherData['lon'],
            );
          }
        }
      }
    } catch (e) {
      print('날씨 정보 로드 실패: $e');
    }
    return null;
  }

  // 브리핑 생성
  static Future<String?> generateBriefingSummary(DateTime date) async {
    try {
      print('📝 브리핑 생성 시작: ${date.toString().split(' ')[0]}');

      // 해당 날짜의 이벤트들 가져오기
      final events = await EventStorageService.getEventsForDate(date);

      // 날씨 정보 가져오기
      final weather = await getWeatherForDate(date);

      // 이벤트들을 시간대별로 분류
      final morningEvents = events.where((e) => _isMorning(e.time)).toList();
      final afternoonEvents =
          events.where((e) => _isAfternoon(e.time)).toList();
      final eveningEvents = events.where((e) => _isEvening(e.time)).toList();
      final noTimeEvents = events.where((e) => e.time.isEmpty).toList();

      // 먼저 백업 브리핑을 준비 (항상 사용 가능한 브리핑)
      final backupBriefing = _generateBackupBriefing(
        events,
        morningEvents,
        afternoonEvents,
        eveningEvents,
        noTimeEvents,
        weather,
      );

      print('🛡️ 백업 브리핑 준비 완료: $backupBriefing');

      // 일정이나 날씨 정보가 없으면 백업 브리핑 반환
      if (events.isEmpty && weather == null) {
        print('📋 일정과 날씨 정보 없음 - 백업 브리핑 사용');
        return backupBriefing;
      }

      try {
        // ChatService를 사용해서 자연스러운 브리핑 생성 (타임아웃 적용)
        print('🤖 ChatService로 브리핑 생성 시도...');
        final chatService = ChatService();
        final prompt = _buildBriefingPrompt(
          events,
          morningEvents,
          afternoonEvents,
          eveningEvents,
          noTimeEvents,
          weather,
        );

        print('📝 브리핑 프롬프트: $prompt');

        // 타임아웃을 15초로 연장
        final response = await chatService
            .sendMessage(prompt, 'briefing_user')
            .timeout(Duration(seconds: 15));

        print('🔍 ChatService 원본 응답: "${response.text}"');

        // 응답 검증을 더 엄격하게
        if (response.text.isNotEmpty &&
            !response.text.contains('문제가 발생했어요') &&
            !response.text.contains('오류가 발생했습니다') &&
            !response.text.contains('알 수 없는 오류') &&
            !response.text.contains('다시 시도해주시거나') &&
            response.text.length > 15 &&
            !response.text.startsWith('❌')) {
          print('✅ ChatService 브리핑 생성 성공: "${response.text.trim()}"');
          return response.text.trim();
        } else {
          print('⚠️ ChatService 응답이 유효하지 않음: "${response.text}"');
          print('🛡️ 백업 브리핑 사용');
          return backupBriefing;
        }
      } catch (e) {
        print('❌ ChatService 브리핑 생성 실패: $e');
        print('🛡️ 백업 브리핑 사용');
        return backupBriefing;
      }
    } catch (e) {
      print('❌ 전체 브리핑 생성 실패: $e');

      // 최후의 수단으로 간단한 기본 브리핑 생성
      try {
        final events = await EventStorageService.getEventsForDate(date);
        final weather = await getWeatherForDate(date);

        if (events.isNotEmpty || weather != null) {
          final morningEvents =
              events.where((e) => _isMorning(e.time)).toList();
          final afternoonEvents =
              events.where((e) => _isAfternoon(e.time)).toList();
          final eveningEvents =
              events.where((e) => _isEvening(e.time)).toList();
          final noTimeEvents = events.where((e) => e.time.isEmpty).toList();

          final backup = _generateBackupBriefing(
            events,
            morningEvents,
            afternoonEvents,
            eveningEvents,
            noTimeEvents,
            weather,
          );
          print('🆘 최후 백업 브리핑 생성: $backup');
          return backup;
        }
      } catch (backupError) {
        print('❌ 백업 브리핑도 실패: $backupError');
      }

      // 정말 모든 것이 실패한 경우
      return "브리핑 생성 중 문제가 발생했습니다. 좋은 하루 보내세요! 😊";
    }
  }

  // 브리핑 저장
  static Future<void> saveBriefing(DailyBriefing briefing) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _getBriefingKey(briefing.date);
    await prefs.setString(key, jsonEncode(briefing.toJson()));
    print('💾 브리핑 저장 완료: ${briefing.date.toString().split(' ')[0]}');
  }

  // 브리핑 불러오기
  static Future<DailyBriefing?> getBriefing(DateTime date) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _getBriefingKey(date);
    final briefingJson = prefs.getString(key);

    if (briefingJson != null) {
      return DailyBriefing.fromJson(jsonDecode(briefingJson));
    }
    return null;
  }

  // 브리핑 알림 스케줄링
  static Future<bool> scheduleBriefingNotification(
    DateTime date,
    String time,
  ) async {
    try {
      print('🔔 브리핑 알림 스케줄링 시작');
      print('📅 날짜: ${date.toString().split(' ')[0]}');
      print('⏰ 시간: $time');

      // 기존 브리핑이 있는지 확인
      final existingBriefing = await getBriefing(date);
      String summary;

      if (existingBriefing != null && existingBriefing.isValid()) {
        summary = existingBriefing.summary;
        print('📖 기존 브리핑 사용');
      } else {
        // 새 브리핑 생성
        summary = await generateBriefingSummary(date) ?? "오늘 일정을 확인해보세요.";
        print('📝 새 브리핑 생성');
      }

      print('📄 브리핑 내용: $summary');

      // 알림 시간 계산
      final scheduledDateTime = _parseScheduledTime(date, time);
      print('🔍 파싱된 스케줄 시간: $scheduledDateTime');
      print('🔍 현재 시간: ${DateTime.now()}');

      if (scheduledDateTime == null) {
        print('❌ 알림 시간 파싱 실패');
        return false;
      }

      if (scheduledDateTime.isBefore(DateTime.now())) {
        print('⚠️ 알림 시간이 과거입니다: $scheduledDateTime');
        return false;
      }

      // 알림 권한 확인
      print('🔍 알림 권한 확인 중...');
      final hasPermission = await NotificationService.requestPermissions();
      print('📱 알림 권한: $hasPermission');

      if (!hasPermission) {
        print('❌ 알림 권한이 없습니다');
        return false;
      }

      // 알림 ID 생성
      final notificationId = _generateNotificationId();
      print('🔢 생성된 알림 ID: $notificationId');

      // 알림 스케줄링
      print('🔔 알림 스케줄링 실행 중...');
      await NotificationService.initialize();
      final flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

      final tzDateTime = tz.TZDateTime.from(scheduledDateTime, tz.local);
      print('🌏 TZ DateTime: $tzDateTime');

      await flutterLocalNotificationsPlugin.zonedSchedule(
        notificationId,
        '📅 오늘의 일정 브리핑',
        summary,
        tzDateTime,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'daily_briefing',
            '일일 브리핑',
            channelDescription: '오늘의 일정 요약 브리핑',
            importance: Importance.high,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
            showWhen: true,
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        payload: 'daily_briefing_${date.toIso8601String()}',
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );

      print('✅ 알림 스케줄링 API 호출 완료');

      // 예약된 알림 확인
      final pendingNotifications =
          await flutterLocalNotificationsPlugin.pendingNotificationRequests();
      print('📋 현재 예약된 알림 수: ${pendingNotifications.length}');
      for (var notification in pendingNotifications) {
        if (notification.id == notificationId) {
          print('✅ 방금 설정한 알림이 예약 목록에 있습니다: ${notification.title}');
        }
      }

      // 브리핑 저장
      final briefing = DailyBriefing(
        date: date,
        summary: summary,
        createdAt: DateTime.now(),
        scheduledTime: scheduledDateTime,
        isScheduled: true,
        notificationId: notificationId,
      );

      await saveBriefing(briefing);

      print('✅ 브리핑 알림 스케줄링 완료: $scheduledDateTime (ID: $notificationId)');
      return true;
    } catch (e, stackTrace) {
      print('❌ 브리핑 알림 스케줄링 실패: $e');
      print('📍 스택 트레이스: $stackTrace');
      return false;
    }
  }

  // 브리핑 알림 취소
  static Future<void> cancelBriefingNotification(DateTime date) async {
    final briefing = await getBriefing(date);
    if (briefing?.notificationId != null) {
      await NotificationService.cancelNotification(briefing!.notificationId!);

      // 브리핑 업데이트 (스케줄링 해제)
      final updatedBriefing = briefing.copyWith(
        isScheduled: false,
        notificationId: null,
      );
      await saveBriefing(updatedBriefing);

      print('🗑️ 브리핑 알림 취소 완료');
    }
  }

  // 오늘과 내일 브리핑 자동 생성 및 스케줄링
  static Future<void> updateBriefings() async {
    final settings = await getBriefingSettings();
    if (!settings['enabled']) return;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(Duration(days: 1));

    print('🔄 브리핑 업데이트 시작');

    // 오늘 브리핑 처리
    await _updateBriefingForDate(today, settings['time']);

    // 내일 브리핑 처리 (항상 포함)
    await _updateBriefingForDate(tomorrow, settings['time']);

    print('✅ 브리핑 업데이트 완료');
  }

  // 특정 날짜의 브리핑 업데이트
  static Future<void> _updateBriefingForDate(DateTime date, String time) async {
    final existingBriefing = await getBriefing(date);

    // 기존 브리핑이 유효하다면 스킵
    if (existingBriefing != null &&
        existingBriefing.isValid() &&
        existingBriefing.isScheduled) {
      print('📋 ${date.toString().split(' ')[0]} 브리핑은 이미 최신 상태');
      return;
    }

    // 기존 알림이 있다면 취소
    if (existingBriefing?.notificationId != null) {
      await NotificationService.cancelNotification(
        existingBriefing!.notificationId!,
      );
    }

    // 새 브리핑 생성 및 스케줄링
    await scheduleBriefingNotification(date, time);
  }

  // 헬퍼 메서드들
  static String _getBriefingKey(DateTime date) {
    return '$_briefingPrefix${date.year}_${date.month}_${date.day}';
  }

  static bool _isMorning(String time) {
    if (time.isEmpty) return false;
    final hour = int.tryParse(time.split(':')[0]) ?? 0;
    return hour >= 6 && hour < 12;
  }

  static bool _isAfternoon(String time) {
    if (time.isEmpty) return false;
    final hour = int.tryParse(time.split(':')[0]) ?? 0;
    return hour >= 12 && hour < 18;
  }

  static bool _isEvening(String time) {
    if (time.isEmpty) return false;
    final hour = int.tryParse(time.split(':')[0]) ?? 0;
    return hour >= 18 || hour < 6;
  }

  static DateTime? _parseScheduledTime(DateTime date, String time) {
    try {
      final timeParts = time.split(':');
      final hour = int.parse(timeParts[0]);
      final minute = int.parse(timeParts[1]);

      return DateTime(date.year, date.month, date.day, hour, minute);
    } catch (e) {
      print('❌ 시간 파싱 실패: $time');
      return null;
    }
  }

  static int _generateNotificationId() {
    return DateTime.now().millisecondsSinceEpoch % 2147483647;
  }

  static String _buildBriefingPrompt(
    List<Event> allEvents,
    List<Event> morningEvents,
    List<Event> afternoonEvents,
    List<Event> eveningEvents,
    List<Event> noTimeEvents,
    WeatherInfo? weather,
  ) {
    String weatherInfo = '';
    if (weather != null) {
      String weatherDesc = '';
      switch (weather.condition) {
        case 'sunny':
          weatherDesc = '맑음';
          break;
        case 'cloudy':
          weatherDesc = '흐림';
          break;
        case 'rainy':
          weatherDesc = '비';
          break;
        case 'snowy':
          weatherDesc = '눈';
          break;
        default:
          weatherDesc = weather.condition;
      }
      weatherInfo = '날씨: ${weatherDesc} ${weather.temperature.round()}°C. ';
    }

    // 구체적인 일정 정보 포함
    String scheduleInfo = '';
    if (allEvents.isNotEmpty) {
      final scheduleParts = <String>[];

      if (morningEvents.isNotEmpty) {
        final morningTitles = morningEvents
            .map((e) => e.title)
            .take(2)
            .join(', ');
        final moreText =
            morningEvents.length > 2 ? ' 등 ${morningEvents.length}개' : '';
        scheduleParts.add('오전: $morningTitles$moreText');
      }

      if (afternoonEvents.isNotEmpty) {
        final afternoonTitles = afternoonEvents
            .map((e) => e.title)
            .take(2)
            .join(', ');
        final moreText =
            afternoonEvents.length > 2 ? ' 등 ${afternoonEvents.length}개' : '';
        scheduleParts.add('오후: $afternoonTitles$moreText');
      }

      if (eveningEvents.isNotEmpty) {
        final eveningTitles = eveningEvents
            .map((e) => e.title)
            .take(2)
            .join(', ');
        final moreText =
            eveningEvents.length > 2 ? ' 등 ${eveningEvents.length}개' : '';
        scheduleParts.add('저녁: $eveningTitles$moreText');
      }

      if (noTimeEvents.isNotEmpty) {
        final noTimeTitles = noTimeEvents
            .map((e) => e.title)
            .take(2)
            .join(', ');
        final moreText =
            noTimeEvents.length > 2 ? ' 등 ${noTimeEvents.length}개' : '';
        scheduleParts.add('기타: $noTimeTitles$moreText');
      }

      scheduleInfo = '일정: ${scheduleParts.join(', ')}. ';
    }

    // 간단하고 명확한 프롬프트
    return '${weatherInfo}${scheduleInfo}이 정보를 바탕으로 친근하고 자연스러운 하루 브리핑을 120자 이내로 작성해주세요.';
  }

  static String _generateBackupBriefing(
    List<Event> allEvents,
    List<Event> morningEvents,
    List<Event> afternoonEvents,
    List<Event> eveningEvents,
    List<Event> noTimeEvents,
    WeatherInfo? weather,
  ) {
    final parts = <String>[];

    // 날씨 정보 추가
    if (weather != null) {
      String weatherDesc = '';
      switch (weather.condition) {
        case 'sunny':
          weatherDesc = '맑음';
          break;
        case 'cloudy':
          weatherDesc = '흐림';
          break;
        case 'rainy':
          weatherDesc = '비';
          break;
        case 'snowy':
          weatherDesc = '눈';
          break;
        default:
          weatherDesc = weather.condition;
      }
      parts.add('오늘은 ${weatherDesc} ${weather.temperature.round()}°C');
    }

    // 구체적인 일정 정보 추가
    if (allEvents.isNotEmpty) {
      final scheduleParts = <String>[];

      if (morningEvents.isNotEmpty) {
        if (morningEvents.length == 1) {
          scheduleParts.add('오전에 ${morningEvents.first.title}');
        } else {
          final titles = morningEvents.map((e) => e.title).take(2).join(', ');
          scheduleParts.add(
            '오전에 $titles${morningEvents.length > 2 ? ' 등 ${morningEvents.length}개' : ''}',
          );
        }
      }

      if (afternoonEvents.isNotEmpty) {
        if (afternoonEvents.length == 1) {
          scheduleParts.add('오후에 ${afternoonEvents.first.title}');
        } else {
          final titles = afternoonEvents.map((e) => e.title).take(2).join(', ');
          scheduleParts.add(
            '오후에 $titles${afternoonEvents.length > 2 ? ' 등 ${afternoonEvents.length}개' : ''}',
          );
        }
      }

      if (eveningEvents.isNotEmpty) {
        if (eveningEvents.length == 1) {
          scheduleParts.add('저녁에 ${eveningEvents.first.title}');
        } else {
          final titles = eveningEvents.map((e) => e.title).take(2).join(', ');
          scheduleParts.add(
            '저녁에 $titles${eveningEvents.length > 2 ? ' 등 ${eveningEvents.length}개' : ''}',
          );
        }
      }

      if (noTimeEvents.isNotEmpty) {
        if (noTimeEvents.length == 1) {
          scheduleParts.add('${noTimeEvents.first.title}');
        } else {
          final titles = noTimeEvents.map((e) => e.title).take(2).join(', ');
          scheduleParts.add('$titles${noTimeEvents.length > 2 ? ' 등' : ''}');
        }
      }

      if (scheduleParts.isNotEmpty) {
        parts.add(scheduleParts.join(', '));
      }
    }

    // 브리핑 조합
    String summary;
    if (parts.isEmpty) {
      summary = '오늘은 특별한 일정이 없네요';
    } else if (allEvents.isEmpty && weather != null) {
      // 날씨만 있는 경우
      summary = parts.join('예요');
    } else if (allEvents.isNotEmpty && weather == null) {
      // 일정만 있는 경우
      summary = '오늘 ${parts.join('이 있어요')}';
    } else {
      // 날씨와 일정 모두 있는 경우
      summary = '${parts[0]}예요. ${parts.sublist(1).join('이 있어요')}';
    }

    // 마무리 인사
    final endings = [
      '좋은 하루 보내세요! 😊',
      '알찬 하루 되세요! 🌟',
      '즐거운 하루 되세요! 😄',
      '오늘도 화이팅! 💪',
    ];
    final randomEnding = endings[DateTime.now().millisecond % endings.length];

    return '$summary $randomEnding';
  }
}
