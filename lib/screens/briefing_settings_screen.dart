import 'package:flutter/material.dart';
import '../services/daily_briefing_service.dart';
import '../utils/font_utils.dart';
import '../services/notification_service.dart';

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
      final settings = await DailyBriefingService.getBriefingSettings();
      setState(() {
        _briefingEnabled = settings['enabled'] ?? false;

        final timeString = settings['time'] ?? '08:00';
        final timeParts = timeString.split(':');
        _briefingTime = TimeOfDay(
          hour: int.parse(timeParts[0]),
          minute: int.parse(timeParts[1]),
        );

        _isLoading = false;
      });
    } catch (e) {
      print('설정 로드 실패: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveSettings() async {
    try {
      final settings = {
        'enabled': _briefingEnabled,
        'time':
            '${_briefingTime.hour.toString().padLeft(2, '0')}:'
            '${_briefingTime.minute.toString().padLeft(2, '0')}',
      };

      await DailyBriefingService.saveBriefingSettings(settings);

      // 설정이 활성화되었다면 브리핑 업데이트
      if (_briefingEnabled) {
        await DailyBriefingService.updateBriefings();
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
    } catch (e) {
      print('설정 저장 실패: $e');
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
    );

    if (picked != null) {
      setState(() {
        _briefingTime = picked;
      });
    }
  }

  // 오늘과 내일의 브리핑 내용 확인
  Future<void> _checkScheduledNotifications() async {
    try {
      setState(() => _isLoading = true);

      final today = DateTime.now();
      final tomorrow = today.add(const Duration(days: 1));

      // 먼저 저장된 브리핑 확인, 없으면 새로 생성
      String? todayBriefing;
      String? tomorrowBriefing;

      // 오늘 브리핑 - 저장된 것 우선 확인
      final savedTodayBriefing = await DailyBriefingService.getBriefing(today);
      if (savedTodayBriefing != null && savedTodayBriefing.summary.isNotEmpty) {
        todayBriefing = savedTodayBriefing.summary;
      } else {
        todayBriefing = await DailyBriefingService.generateBriefingSummary(
          today,
        );
      }

      // 내일 브리핑 - 저장된 것 우선 확인
      final savedTomorrowBriefing = await DailyBriefingService.getBriefing(
        tomorrow,
      );
      if (savedTomorrowBriefing != null &&
          savedTomorrowBriefing.summary.isNotEmpty) {
        tomorrowBriefing = savedTomorrowBriefing.summary;
      } else {
        tomorrowBriefing = await DailyBriefingService.generateBriefingSummary(
          tomorrow,
        );
      }

      setState(() => _isLoading = false);

      String message = '';

      // 오늘 브리핑
      message += '📅 오늘 (${today.month}/${today.day})\n';
      if (todayBriefing != null && todayBriefing.isNotEmpty) {
        message += '$todayBriefing\n\n';
      } else {
        message += '오늘 일정이 없습니다.\n\n';
      }

      // 내일 브리핑
      message += '📅 내일 (${tomorrow.month}/${tomorrow.day})\n';
      if (tomorrowBriefing != null && tomorrowBriefing.isNotEmpty) {
        message += tomorrowBriefing;
      } else {
        message += '내일 일정이 없습니다.';
      }

      showDialog(
        context: context,
        builder:
            (context) => AlertDialog(
              title: Text(
                '브리핑 내용 미리보기',
                style: getTextStyle(fontSize: 16, color: Colors.black),
              ),
              content: SizedBox(
                width: MediaQuery.of(context).size.width * 0.8,
                child: SingleChildScrollView(
                  child: Text(
                    message,
                    style: getTextStyle(fontSize: 12, color: Colors.black),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(
                    '확인',
                    style: getTextStyle(fontSize: 12, color: Colors.blue),
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
        appBar: AppBar(
          title: Text(
            '브리핑 설정',
            style: getTextStyle(fontSize: 16, color: Colors.white),
          ),
          backgroundColor: Colors.black,
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          '브리핑 설정',
          style: getTextStyle(fontSize: 16, color: Colors.white),
        ),
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(icon: const Icon(Icons.save), onPressed: _saveSettings),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '📅 일일 브리핑',
                    style: getTextStyle(
                      fontSize: 18,
                      color: Colors.black,
                    ).copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '매일 정해진 시간에 오늘의 일정을 요약해서 알림으로 보내드립니다.',
                    style: getTextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 16),
                  SwitchListTile(
                    title: Text(
                      '브리핑 알림 활성화',
                      style: getTextStyle(fontSize: 14, color: Colors.black),
                    ),
                    subtitle: Text(
                      _briefingEnabled
                          ? '브리핑 알림이 활성화되어 있습니다'
                          : '브리핑 알림이 비활성화되어 있습니다',
                      style: getTextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    value: _briefingEnabled,
                    onChanged: (value) {
                      setState(() {
                        _briefingEnabled = value;
                      });
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (_briefingEnabled) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '⏰ 알림 시간',
                      style: getTextStyle(
                        fontSize: 16,
                        color: Colors.black,
                      ).copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    ListTile(
                      leading: const Icon(
                        Icons.access_time,
                        color: Colors.blue,
                      ),
                      title: Text(
                        '브리핑 시간',
                        style: getTextStyle(fontSize: 14, color: Colors.black),
                      ),
                      subtitle: Text(
                        '${_briefingTime.hour.toString().padLeft(2, '0')}:${_briefingTime.minute.toString().padLeft(2, '0')}',
                        style: getTextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      trailing: const Icon(Icons.edit),
                      onTap: _selectTime,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '📋 브리핑 포함 내용',
                      style: getTextStyle(
                        fontSize: 16,
                        color: Colors.black,
                      ).copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      '• 오늘의 일정 및 날씨 정보\n'
                      '• 내일의 일정 정보\n'
                      '• 시간대별 일정 요약',
                      style: getTextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '🧪 미리보기',
                      style: getTextStyle(
                        fontSize: 16,
                        color: Colors.black,
                      ).copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),

                    ListTile(
                      // leading: const Icon(Icons.preview, color: Colors.purple),
                      title: Text(
                        '예약된 브리핑 목록',
                        style: getTextStyle(fontSize: 14, color: Colors.black),
                      ),
                      subtitle: Text(
                        '오늘과 내일의 브리핑 내용을 미리 확인',
                        style: getTextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      onTap: _checkScheduledNotifications,
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
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue[200]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.info, color: Colors.blue),
                      const SizedBox(width: 8),
                      Text(
                        '브리핑 안내',
                        style: getTextStyle(
                          fontSize: 14,
                          color: Colors.blue[800],
                        ).copyWith(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '• 앱을 열 때마다 오늘/내일 브리핑이 자동으로 생성됩니다\n'
                    '• 설정한 시간에 미리 준비된 브리핑을 알림으로 받습니다\n'
                    '• 일정이 변경되면 다음에 앱을 열 때 브리핑이 업데이트됩니다',
                    style: getTextStyle(fontSize: 12, color: Colors.blue[700]),
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
