import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import '../models/event.dart';
import 'dart:math';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  static final FlutterLocalNotificationsPlugin
  _flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

  static bool _isInitialized = false;

  /// 알림 서비스 초기화
  static Future<void> initialize() async {
    if (_isInitialized) return;

    // 타임존 데이터 초기화
    tz.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Seoul'));

    // Android 초기화 설정
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    // iOS 초기화 설정
    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
          requestAlertPermission: true,
          requestBadgePermission: true,
          requestSoundPermission: true,
        );

    const InitializationSettings initializationSettings =
        InitializationSettings(
          android: initializationSettingsAndroid,
          iOS: initializationSettingsIOS,
        );

    await _flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) async {
        print('🔔 알림 탭됨: ${response.payload}');
        // 여기서 알림을 탭했을 때의 동작을 구현할 수 있습니다
      },
    );

    _isInitialized = true;
    print('✅ NotificationService 초기화 완료');
  }

  /// 알림 권한 요청
  static Future<bool> requestPermissions() async {
    if (!_isInitialized) await initialize();

    // Android 13+ 알림 권한 요청
    final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
        _flutterLocalNotificationsPlugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();

    if (androidImplementation != null) {
      final bool? granted =
          await androidImplementation.requestNotificationsPermission();
      print('📱 Android 알림 권한: ${granted ?? false}');
      return granted ?? false;
    }

    // iOS 권한 요청 (현재 미사용 - 필요시 주석 해제)
    // final DarwinFlutterLocalNotificationsPlugin? iosImplementation =
    //     _flutterLocalNotificationsPlugin
    //         .resolvePlatformSpecificImplementation<
    //           DarwinFlutterLocalNotificationsPlugin
    //         >();

    // if (iosImplementation != null) {
    //   final bool? granted = await iosImplementation.requestPermissions(
    //     alert: true,
    //     badge: true,
    //     sound: true,
    //   );
    //   print('🍎 iOS 알림 권한: ${granted ?? false}');
    //   return granted ?? false;
    // }

    return true; // 다른 플랫폼의 경우 기본적으로 허용
  }

  /// 이벤트 알림 스케줄링
  static Future<int?> scheduleEventNotification(Event event) async {
    print('🔍 [DEBUG] scheduleEventNotification 시작 - ${event.title}');
    print('🔍 [DEBUG] isNotificationEnabled: ${event.isNotificationEnabled}');
    print('🔍 [DEBUG] time: "${event.time}"');
    print('🔍 [DEBUG] date: ${event.date}');
    print(
      '🔍 [DEBUG] notificationMinutesBefore: ${event.notificationMinutesBefore}',
    );

    if (!event.isNotificationEnabled || event.time.isEmpty) {
      print('⏰ 알림이 비활성화되어 있거나 시간이 없는 이벤트: ${event.title}');
      return null;
    }

    if (!_isInitialized) {
      print('🔍 [DEBUG] NotificationService가 초기화되지 않음, 초기화 중...');
      await initialize();
    }

    try {
      // 이벤트 시간을 DateTime으로 파싱
      print('🔍 [DEBUG] 이벤트 시간 파싱 시도...');
      final eventDateTime = _parseEventDateTime(event);
      if (eventDateTime == null) {
        print('❌ 이벤트 시간 파싱 실패: ${event.title} - ${event.time}');
        return null;
      }
      print('🔍 [DEBUG] 파싱된 이벤트 시간: $eventDateTime');

      // 알림 시간 계산 (이벤트 시간에서 지정된 분 만큼 빼기)
      final notificationDateTime = eventDateTime.subtract(
        Duration(minutes: event.notificationMinutesBefore),
      );
      print('🔍 [DEBUG] 계산된 알림 시간: $notificationDateTime');
      print('🔍 [DEBUG] 현재 시간: ${DateTime.now()}');

      // 과거 시간인지 확인
      if (notificationDateTime.isBefore(DateTime.now())) {
        print('⚠️ 알림 시간이 과거입니다: ${event.title} - $notificationDateTime');
        return null;
      }

      // 고유한 알림 ID 생성
      final notificationId = event.notificationId ?? _generateNotificationId();
      print('🔍 [DEBUG] 생성된 알림 ID: $notificationId');

      // 알림 스케줄링
      print('🔍 [DEBUG] 알림 스케줄링 시도...');
      await _flutterLocalNotificationsPlugin.zonedSchedule(
        notificationId,
        '📅 일정 알림',
        '${event.title} (${event.time}${event.endTime != null ? ' - ${event.endTime}' : ''})',
        tz.TZDateTime.from(notificationDateTime, tz.local),
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'event_notifications',
            '일정 알림',
            channelDescription: '캘린더 일정에 대한 알림',
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
        payload: event.uniqueId,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );

      print(
        '✅ 알림 스케줄링 완료: ${event.title} - $notificationDateTime (ID: $notificationId)',
      );
      return notificationId;
    } catch (e) {
      print('❌ 알림 스케줄링 실패: ${event.title} - $e');
      print('🔍 [DEBUG] 스택 트레이스: ${e.toString()}');
      return null;
    }
  }

  /// 알림 취소
  static Future<void> cancelNotification(int notificationId) async {
    if (!_isInitialized) await initialize();

    try {
      await _flutterLocalNotificationsPlugin.cancel(notificationId);
      print('🗑️ 알림 취소 완료: ID $notificationId');
    } catch (e) {
      print('❌ 알림 취소 실패: ID $notificationId - $e');
    }
  }

  /// 이벤트 관련 모든 알림 취소
  static Future<void> cancelEventNotifications(Event event) async {
    if (event.notificationId != null) {
      await cancelNotification(event.notificationId!);
    }
  }

  /// 모든 알림 취소
  static Future<void> cancelAllNotifications() async {
    if (!_isInitialized) await initialize();

    try {
      await _flutterLocalNotificationsPlugin.cancelAll();
      print('🗑️ 모든 알림 취소 완료');
    } catch (e) {
      print('❌ 모든 알림 취소 실패: $e');
    }
  }

  /// 예약된 알림 목록 조회
  static Future<List<PendingNotificationRequest>>
  getPendingNotifications() async {
    if (!_isInitialized) await initialize();

    try {
      final pendingNotifications =
          await _flutterLocalNotificationsPlugin.pendingNotificationRequests();
      print('📋 예약된 알림 개수: ${pendingNotifications.length}');
      return pendingNotifications;
    } catch (e) {
      print('❌ 예약된 알림 조회 실패: $e');
      return [];
    }
  }

  /// 이벤트 시간을 DateTime으로 파싱
  static DateTime? _parseEventDateTime(Event event) {
    try {
      // "종일" 이벤트 처리
      if (event.time.trim() == '종일' ||
          event.time.trim().toLowerCase() == 'all day') {
        print('🔍 [DEBUG] 종일 이벤트 감지, 오전 9시로 설정');
        return DateTime(
          event.date.year,
          event.date.month,
          event.date.day,
          9, // 오전 9시
          0, // 0분
        );
      }

      final timeParts = event.time.split(':');
      if (timeParts.length != 2) return null;

      final hour = int.parse(timeParts[0]);
      final minute = int.parse(timeParts[1]);

      return DateTime(
        event.date.year,
        event.date.month,
        event.date.day,
        hour,
        minute,
      );
    } catch (e) {
      print('❌ 시간 파싱 오류: ${event.time} - $e');
      return null;
    }
  }

  /// 고유한 알림 ID 생성
  static int _generateNotificationId() {
    final random = Random();
    return random.nextInt(2147483647); // int의 최대값
  }

  /// 즉시 테스트 알림 보내기 (개발/테스트용)
  static Future<void> showTestNotification() async {
    if (!_isInitialized) await initialize();

    await _flutterLocalNotificationsPlugin.show(
      999999,
      '🧪 테스트 알림',
      '알림이 정상적으로 작동합니다!',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'test_notifications',
          '테스트 알림',
          channelDescription: '알림 기능 테스트',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
    );
  }
}
