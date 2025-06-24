import 'package:flutter/material.dart';
import '../services/daily_briefing_service.dart';
import '../utils/font_utils.dart';
import '../services/notification_service.dart';
import '../managers/theme_manager.dart'; // ☑️ _HE_250621_테마 관리자 추가
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class BriefingSettingsScreen extends StatefulWidget {
  const BriefingSettingsScreen({super.key});

  @override
  State<BriefingSettingsScreen> createState() => _BriefingSettingsScreenState();
}

class _BriefingSettingsScreenState extends State<BriefingSettingsScreen> {
  bool _briefingEnabled = false;
  TimeOfDay _briefingTime = TimeOfDay(hour: 8, minute: 0);
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      print('🔍 [화면] 설정 로드 시작');
      final settings = await DailyBriefingService.getBriefingSettings();
      print('🔍 [화면] 로드된 설정: $settings');

      setState(() {
        _briefingEnabled = settings['enabled'] ?? false;
        print('🔍 [화면] 설정된 _briefingEnabled: $_briefingEnabled');

        final timeString = settings['time'] ?? '08:00';
        print('🔍 [화면] 설정된 timeString: $timeString');

        final timeParts = timeString.split(':');
        _briefingTime = TimeOfDay(
          hour: int.parse(timeParts[0]),
          minute: int.parse(timeParts[1]),
        );
        print(
          '🔍 [화면] 설정된 _briefingTime: ${_briefingTime.hour}:${_briefingTime.minute}',
        );

        _isLoading = false;
      });
      print('✅ [화면] 설정 로드 완료');
    } catch (e) {
      print('❌ [화면] 설정 로드 실패: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveSettings() async {
    try {
      print('🔍 [화면] 설정 저장 시작');
      print('🔍 [화면] 현재 _briefingEnabled: $_briefingEnabled');
      print(
        '🔍 [화면] 현재 _briefingTime: ${_briefingTime.hour}:${_briefingTime.minute}',
      );

      final settings = {
        'enabled': _briefingEnabled,
        'time':
            '${_briefingTime.hour.toString().padLeft(2, '0')}:'
            '${_briefingTime.minute.toString().padLeft(2, '0')}',
      };
      print('🔍 [화면] 저장할 설정: $settings');

      await DailyBriefingService.saveBriefingSettings(settings);
      print('✅ [화면] DailyBriefingService.saveBriefingSettings 완료');

      // 설정이 활성화되었다면 브리핑 업데이트
      if (_briefingEnabled) {
        print('🔄 [화면] 브리핑 설정 활성화 - 브리핑 강제 업데이트 시작');
        await DailyBriefingService.updateBriefings();
        print('✅ [화면] 브리핑 설정 활성화 - 브리핑 강제 업데이트 완료');
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '브리핑 설정이 저장되었습니다.',
            style: getTextStyle(fontSize: 12, color: Colors.white),
          ),
          backgroundColor: Colors.green,
        ),
      );
      print('✅ [화면] 설정 저장 완료');
    } catch (e) {
      print('❌ [화면] 설정 저장 실패: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '설정 저장에 실패했습니다.',
            style: getTextStyle(fontSize: 12, color: Colors.white),
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _selectTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _briefingTime,
      builder: (BuildContext context, Widget? child) {
        // ☑️ 기존 ThemeManager 색상들을 활용한 다크 모드 테마 적용
        return Theme(
          data: Theme.of(context).copyWith(
            // TimePicker 전용 색상 테마 적용 (기존 색상 활용)
            timePickerTheme: TimePickerThemeData(
              backgroundColor:
                  ThemeManager.getDatePickerBackgroundColor(), // DatePicker 배경 활용
              hourMinuteTextColor:
                  ThemeManager.getDatePickerTextColor(), // DatePicker 텍스트 활용
              hourMinuteColor:
                  ThemeManager.getEventPopupTimePickerDayPeriodColor(), // 기존 TimePicker 색상 활용
              dayPeriodTextColor:
                  ThemeManager.getDatePickerTextColor(), // AM/PM 텍스트
              dayPeriodColor:
                  ThemeManager.getEventPopupTimePickerDayPeriodColor(), // AM/PM 배경
              dialHandColor:
                  ThemeManager.getDatePickerSelectedColor(), // 시계 바늘 (선택 색상)
              dialBackgroundColor:
                  ThemeManager.getDatePickerSurfaceColor(), // 시계 다이얼 배경
              dialTextColor: ThemeManager.getDatePickerTextColor(), // 시계 숫자
              entryModeIconColor:
                  ThemeManager.getDatePickerTextColor(), // 입력 모드 아이콘
              helpTextStyle: TextStyle(
                color: ThemeManager.getDatePickerTextColor(),
                fontSize: 16,
              ),
            ),
            // 추가 색상 보정 (기존 색상 활용)
            colorScheme: Theme.of(context).colorScheme.copyWith(
              surface:
                  ThemeManager.getDatePickerSurfaceColor(), // DatePicker 표면색 활용
              onSurface: ThemeManager.getDatePickerTextColor(), // 표면 위 텍스트
              primary: ThemeManager.getDatePickerSelectedColor(), // 주요 색상
              onPrimary: Colors.white, // 주요 색상 위 텍스트
              secondary: ThemeManager.getDatePickerSelectedColor(), // 보조 색상
            ),
          ),
          child: child!,
        );
      }, // ☑️ _HE_250621_다크 모드 적용
    );

    if (picked != null) {
      setState(() {
        _briefingTime = picked;
      });
    }
  }

  // 테스트 브리핑 알림 보내기
  Future<void> _sendTestBriefingNotification() async {
    try {
      setState(() => _isLoading = true);

      // 오늘 브리핑 가져오기 또는 생성
      final today = DateTime.now();
      String briefingMessage;

      final savedBriefing = await DailyBriefingService.getBriefing(today);
      if (savedBriefing != null && savedBriefing.summary.isNotEmpty) {
        briefingMessage = savedBriefing.summary;
      } else {
        // 저장된 브리핑이 없으면 새로 생성
        briefingMessage =
            await DailyBriefingService.generateBriefingSummary(today) ??
            '오늘 일정을 확인해보세요! 좋은 하루 보내세요! 😊';
      }

      setState(() => _isLoading = false);

      // 즉시 알림 보내기
      await NotificationService.initialize();
      final flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

      await flutterLocalNotificationsPlugin.show(
        DateTime.now().millisecond, // 고유 ID
        '📅 브리핑 테스트 알림',
        briefingMessage,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'test_briefing',
            '브리핑 테스트',
            channelDescription: '브리핑 알림 테스트',
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
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '테스트 알림을 보냈습니다! 상단 알림을 확인해보세요.',
            style: getTextStyle(fontSize: 12, color: Colors.white),
          ),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '테스트 알림 실패: $e',
            style: getTextStyle(fontSize: 12, color: Colors.white),
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // 오늘과 내일의 브리핑 내용 확인
  Future<void> _checkScheduledNotifications() async {
    try {
      setState(() => _isLoading = true);

      final today = DateTime.now();
      final tomorrow = today.add(const Duration(days: 1));

      // 저장된 브리핑만 확인 (없으면 생성하지 않음)
      final savedTodayBriefing = await DailyBriefingService.getBriefing(today);
      final savedTomorrowBriefing = await DailyBriefingService.getBriefing(
        tomorrow,
      );

      setState(() => _isLoading = false);

      String message = '';
      bool hasBriefings = false;

      // 오늘 브리핑 확인
      message += '📅 오늘 (${today.month}/${today.day})\n';
      if (savedTodayBriefing != null && savedTodayBriefing.summary.isNotEmpty) {
        message += '${savedTodayBriefing.summary}\n\n';
        hasBriefings = true;
      } else {
        message += '생성된 브리핑이 없습니다.\n\n';
      }

      // 내일 브리핑 확인
      message += '📅 내일 (${tomorrow.month}/${tomorrow.day})\n';
      if (savedTomorrowBriefing != null &&
          savedTomorrowBriefing.summary.isNotEmpty) {
        message += savedTomorrowBriefing.summary;
        hasBriefings = true;
      } else {
        message += '생성된 브리핑이 없습니다.';
      }

      // 브리핑이 없는 경우 안내 메시지 추가
      if (!hasBriefings) {
        message += '\n\n💡 브리핑을 생성하려면:\n1. 브리핑 알림을 활성화하고\n2. 저장 버튼을 눌러주세요!';
      }

      showDialog(
        context: context,
        builder:
            (context) => AlertDialog(
              // ☑️ _HE_250621_다크 모드 적용
              backgroundColor: ThemeManager.getPopupBackgroundColor(),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                  color: ThemeManager.getPopupBorderColor(),
                  width: 1,
                ),
              ),
              title: Text(
                hasBriefings ? '브리핑 내용 미리보기' : '브리핑 생성 안내',
                style: getTextStyle(
                  fontSize: 16,
                  color: ThemeManager.getTextColor(), // ☑️ _HE_250621_변경
                ),
              ),
              content: SizedBox(
                width: MediaQuery.of(context).size.width * 0.8,
                child: SingleChildScrollView(
                  child: Text(
                    message,
                    style: getTextStyle(
                      fontSize: 12,
                      color: ThemeManager.getTextColor(), // ☑️ _HE_250621_변경
                    ),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(
                    '확인',
                    style: getTextStyle(
                      fontSize: 12,
                      color:
                          ThemeManager
                                  .isDarkMode // ☑️ _HE_250621_변경
                              ? Colors.blue[300]!
                              : Colors.blue,
                    ),
                  ),
                ),
              ],
            ),
      );
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '브리핑 내용 확인 실패: $e',
            style: getTextStyle(fontSize: 12, color: Colors.white),
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor:
            ThemeManager.getBriefingSettingsBackgroundColor(), // ☑️ _HE_250623_브리핑 설정 전용 배경색 사용
        appBar: AppBar(
          title: Text(
            '브리핑 설정',
            style: getTextStyle(fontSize: 16, color: Colors.white),
          ),
          backgroundColor:
              ThemeManager.getCalendarHeaderBackgroundColor(), // ☑️ _HE_250621_변경
          iconTheme: IconThemeData(
            color:
                ThemeManager.getCalendarHeaderIconColor(), // ☑️ _HE_250621_변경
          ),
        ),
        body: Center(
          child: CircularProgressIndicator(
            color:
                ThemeManager.isDarkMode
                    ? Colors.white
                    : Colors.black, // ☑️ _HE_250621_추가
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor:
          ThemeManager.getBriefingSettingsBackgroundColor(), // ☑️ 브리핑 설정 전용 배경색 사용
      appBar: AppBar(
        title: Text(
          '브리핑 설정',
          style: getTextStyle(fontSize: 16, color: Colors.white),
        ),
        backgroundColor:
            ThemeManager.getCalendarHeaderBackgroundColor(), // ☑️ _HE_250621_변경
        iconTheme: IconThemeData(
          color: ThemeManager.getCalendarHeaderIconColor(), // ☑️ _HE_250621_변경
        ),
        actions: [
          IconButton(
            icon: Icon(
              Icons.save,
              color:
                  ThemeManager.getCalendarHeaderIconColor(), // ☑️ _HE_250621_추가
            ),
            onPressed: _saveSettings,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            // ☑️ _HE_250621_카드 색상 변경
            color: ThemeManager.getCardColor(),
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: BorderSide(
                color: ThemeManager.getPopupBorderColor(),
                width: 0.5,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '📅 일일 브리핑',
                    style: getTextStyle(
                      fontSize: 18,
                      color: ThemeManager.getTextColor(), // ☑️ _HE_250621_변경
                    ).copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '매일 정해진 시간에 오늘의 일정을 요약해서 알림으로 보내드립니다.',
                    style: getTextStyle(
                      fontSize: 12,
                      color:
                          ThemeManager.getPopupSecondaryTextColor(), // ☑️ _HE_250621_변경
                    ),
                  ),
                  const SizedBox(height: 16),
                  SwitchListTile(
                    title: Text(
                      '브리핑 알림 활성화',
                      style: getTextStyle(
                        fontSize: 14,
                        color: ThemeManager.getTextColor(), // ☑️ _HE_250621_변경
                      ),
                    ),
                    subtitle: Text(
                      _briefingEnabled
                          ? '브리핑 알림이 활성화되어 있습니다'
                          : '브리핑 알림이 비활성화되어 있습니다',
                      style: getTextStyle(
                        fontSize: 12,
                        color:
                            ThemeManager.getPopupSecondaryTextColor(), // ☑️ _HE_250621_변경
                      ),
                    ),
                    value: _briefingEnabled,
                    onChanged: (value) {
                      setState(() {
                        _briefingEnabled = value;
                      });
                    },
                    activeColor:
                        ThemeManager.isDarkMode
                            ? Colors.blue[300]
                            : Colors.blue, // ☑️ _HE_250621_추가
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (_briefingEnabled) ...[
            Card(
              // ☑️ _HE_250621_카드 색상 변경
              color: ThemeManager.getCardColor(),
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: BorderSide(
                  color: ThemeManager.getPopupBorderColor(),
                  width: 0.5,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '⏰ 알림 시간',
                      style: getTextStyle(
                        fontSize: 16,
                        color: ThemeManager.getTextColor(), // ☑️ _HE_250621_변경
                      ).copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    ListTile(
                      leading: Icon(
                        // ☑️ _HE_250621_const 제거
                        Icons.access_time,
                        color:
                            ThemeManager
                                    .isDarkMode // ☑️ _HE_250621_변경
                                ? Colors.blue[300]
                                : Colors.blue,
                      ),
                      title: Text(
                        '브리핑 시간',
                        style: getTextStyle(
                          fontSize: 14,
                          color:
                              ThemeManager.getTextColor(), // ☑️ _HE_250621_변경
                        ),
                      ),
                      subtitle: Text(
                        '${_briefingTime.hour.toString().padLeft(2, '0')}:${_briefingTime.minute.toString().padLeft(2, '0')}',
                        style: getTextStyle(
                          fontSize: 12,
                          color:
                              ThemeManager.getPopupSecondaryTextColor(), // ☑️ _HE_250621_변경
                        ),
                      ),
                      trailing: Icon(
                        Icons.edit,
                        color:
                            ThemeManager.getPopupSecondaryTextColor(), // ☑️ _HE_250621_추가
                      ),
                      onTap: _selectTime,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              // ☑️ _HE_250621_카드 색상 변경
              color: ThemeManager.getCardColor(),
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: BorderSide(
                  color: ThemeManager.getPopupBorderColor(),
                  width: 0.5,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '📋 브리핑 포함 내용',
                      style: getTextStyle(
                        fontSize: 16,
                        color: ThemeManager.getTextColor(), // ☑️ _HE_250621_변경
                      ).copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      '• 오늘의 일정 및 날씨 정보\n'
                      '• 내일의 일정 정보\n'
                      '• 시간대별 일정 요약',
                      style: getTextStyle(
                        fontSize: 12,
                        color:
                            ThemeManager.getPopupSecondaryTextColor(), // ☑️ _HE_250621_변경
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              // ☑️ _HE_250621_카드 색상 변경
              color: ThemeManager.getCardColor(),
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: BorderSide(
                  color: ThemeManager.getPopupBorderColor(),
                  width: 0.5,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '🧪 미리보기',
                      style: getTextStyle(
                        fontSize: 16,
                        color: ThemeManager.getTextColor(), // ☑️ _HE_250621_변경
                      ).copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),

                    ListTile(
                      title: Text(
                        '예약된 브리핑 목록',
                        style: getTextStyle(
                          fontSize: 14,
                          color:
                              ThemeManager.getTextColor(), // ☑️ _HE_250621_변경
                        ),
                      ),
                      subtitle: Text(
                        '오늘과 내일의 브리핑 내용을 미리 확인',
                        style: getTextStyle(
                          fontSize: 12,
                          color:
                              ThemeManager.getPopupSecondaryTextColor(), // ☑️ _HE_250621_변경
                        ),
                      ),
                      onTap: _checkScheduledNotifications,
                    ),
                    ListTile(
                      title: Text(
                        '테스트 알림 보내기',
                        style: getTextStyle(
                          fontSize: 14,
                          color: ThemeManager.getTextColor(),
                        ),
                      ),
                      subtitle: Text(
                        '즉시 브리핑 알림을 테스트해보세요',
                        style: getTextStyle(
                          fontSize: 12,
                          color: ThemeManager.getPopupSecondaryTextColor(),
                        ),
                      ),
                      onTap: _sendTestBriefingNotification,
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 24),
          if (_briefingEnabled) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color:
                    ThemeManager.getInfoBoxBackgroundColor(), // ☑️ _HE_250621_변경
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: ThemeManager.getInfoBoxBorderColor(),
                ), // ☑️ _HE_250621_변경
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.info,
                        color:
                            ThemeManager.getInfoBoxIconColor(), // ☑️ _HE_250621_변경
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '브리핑 안내',
                        style: getTextStyle(
                          fontSize: 14,
                          color:
                              ThemeManager.getInfoBoxTextColor(), // ☑️ _HE_250621_변경
                        ).copyWith(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '• 앱을 열 때마다 오늘/내일 브리핑이 자동으로 생성됩니다\n'
                    '• 설정한 시간에 미리 준비된 브리핑을 알림으로 받습니다\n'
                    '• 일정이 변경되면 다음에 앱을 열 때 브리핑이 업데이트됩니다',
                    style: getTextStyle(
                      fontSize: 12,
                      color:
                          ThemeManager.getInfoBoxTextColor(), // ☑️ _HE_250621_변경
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
