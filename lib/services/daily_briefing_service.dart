import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import '../models/daily_briefing.dart';
import '../models/event.dart';
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

    // 기본 설정
    return {
      'enabled': false,
      'time': _defaultBriefingTime,
      'includeWeather': true,
      'includeTomorrow': true,
    };
  }

  static Future<void> saveBriefingSettings(
    Map<String, dynamic> settings,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_settingsKey, jsonEncode(settings));
  }

  // 브리핑 생성
  static Future<String?> generateBriefingSummary(DateTime date) async {
    try {
      print('📝 브리핑 생성 시작: ${date.toString().split(' ')[0]}');

      // 해당 날짜의 이벤트들 가져오기
      final events = await EventStorageService.getEventsForDate(date);

      if (events.isEmpty) {
        return "오늘은 등록된 일정이 없습니다. 여유로운 하루 보내세요! 😊";
      }

      // 이벤트들을 시간대별로 분류
      final morningEvents = events.where((e) => _isMorning(e.time)).toList();
      final afternoonEvents =
          events.where((e) => _isAfternoon(e.time)).toList();
      final eveningEvents = events.where((e) => _isEvening(e.time)).toList();
      final noTimeEvents = events.where((e) => e.time.isEmpty).toList();

      // ChatService를 사용해서 자연스러운 브리핑 생성
      final chatService = ChatService();
      final prompt = _buildBriefingPrompt(
        events,
        morningEvents,
        afternoonEvents,
        eveningEvents,
        noTimeEvents,
      );

      final response = await chatService.sendMessage(prompt, 'briefing_user');

      if (response.text.isNotEmpty) {
        print('✅ 브리핑 생성 완료');
        return response.text;
      } else {
        // 백업 브리핑 생성
        return _generateBackupBriefing(
          events,
          morningEvents,
          afternoonEvents,
          eveningEvents,
          noTimeEvents,
        );
      }
    } catch (e) {
      print('❌ 브리핑 생성 실패: $e');
      // 백업 브리핑 생성
      final events = await EventStorageService.getEventsForDate(date);
      if (events.isNotEmpty) {
        final morningEvents = events.where((e) => _isMorning(e.time)).toList();
        final afternoonEvents =
            events.where((e) => _isAfternoon(e.time)).toList();
        final eveningEvents = events.where((e) => _isEvening(e.time)).toList();
        final noTimeEvents = events.where((e) => e.time.isEmpty).toList();
        return _generateBackupBriefing(
          events,
          morningEvents,
          afternoonEvents,
          eveningEvents,
          noTimeEvents,
        );
      }
      return null;
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

      // 알림 시간 계산
      final scheduledDateTime = _parseScheduledTime(date, time);
      if (scheduledDateTime == null ||
          scheduledDateTime.isBefore(DateTime.now())) {
        print('⚠️ 알림 시간이 과거입니다');
        return false;
      }

      // 알림 ID 생성
      final notificationId = _generateNotificationId();

      // 알림 스케줄링
      await NotificationService.initialize();
      final flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

      await flutterLocalNotificationsPlugin.zonedSchedule(
        notificationId,
        '📅 오늘의 일정 브리핑',
        summary,
        tz.TZDateTime.from(scheduledDateTime, tz.local),
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'daily_briefing',
            '일일 브리핑',
            channelDescription: '오늘의 일정 요약 브리핑',
            importance: Importance.high,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
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

      print('✅ 브리핑 알림 스케줄링 완료: $scheduledDateTime');
      return true;
    } catch (e) {
      print('❌ 브리핑 알림 스케줄링 실패: $e');
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

    // 내일 브리핑 처리 (설정에서 활성화된 경우)
    if (settings['includeTomorrow']) {
      await _updateBriefingForDate(tomorrow, settings['time']);
    }

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
  ) {
    return '''
오늘의 일정을 자연스럽고 친근한 톤으로 요약해주세요. 
전체 일정: ${allEvents.length}개

시간대별 일정:
- 오전: ${morningEvents.map((e) => '${e.time} ${e.title}').join(', ')}
- 오후: ${afternoonEvents.map((e) => '${e.time} ${e.title}').join(', ')}
- 저녁: ${eveningEvents.map((e) => '${e.time} ${e.title}').join(', ')}
- 시간 미정: ${noTimeEvents.map((e) => e.title).join(', ')}

요약 조건:
1. 100자 이내로 간결하게
2. 친근하고 자연스러운 톤
3. 시간대별로 간단히 언급
4. 격려나 응원의 말 포함

예시: "오늘 오전에 회의 2개, 오후에 병원 예약, 저녁에 친구 만남이 있어요. 알찬 하루 보내세요! 😊"
''';
  }

  static String _generateBackupBriefing(
    List<Event> allEvents,
    List<Event> morningEvents,
    List<Event> afternoonEvents,
    List<Event> eveningEvents,
    List<Event> noTimeEvents,
  ) {
    final parts = <String>[];

    if (morningEvents.isNotEmpty) {
      parts.add('오전에 ${morningEvents.length}개 일정');
    }
    if (afternoonEvents.isNotEmpty) {
      parts.add('오후에 ${afternoonEvents.length}개 일정');
    }
    if (eveningEvents.isNotEmpty) {
      parts.add('저녁에 ${eveningEvents.length}개 일정');
    }
    if (noTimeEvents.isNotEmpty) {
      parts.add('${noTimeEvents.length}개 추가 일정');
    }

    final summary =
        parts.isNotEmpty ? '오늘 ${parts.join(', ')}이 있어요.' : '오늘은 일정이 없어요.';

    return '$summary 좋은 하루 보내세요! 😊';
  }
}
