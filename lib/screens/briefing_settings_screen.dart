import 'package:flutter/material.dart';
import '../services/daily_briefing_service.dart';
import '../utils/font_utils.dart';

class BriefingSettingsScreen extends StatefulWidget {
  const BriefingSettingsScreen({super.key});

  @override
  State<BriefingSettingsScreen> createState() => _BriefingSettingsScreenState();
}

class _BriefingSettingsScreenState extends State<BriefingSettingsScreen> {
  bool _isEnabled = false;
  String _briefingTime = '08:00';
  bool _includeWeather = true;
  bool _includeTomorrow = true;
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
        _isEnabled = settings['enabled'] ?? false;
        _briefingTime = settings['time'] ?? '08:00';
        _includeWeather = settings['includeWeather'] ?? true;
        _includeTomorrow = settings['includeTomorrow'] ?? true;
        _isLoading = false;
      });
    } catch (e) {
      print('설정 로드 실패: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _saveSettings() async {
    try {
      final settings = {
        'enabled': _isEnabled,
        'time': _briefingTime,
        'includeWeather': _includeWeather,
        'includeTomorrow': _includeTomorrow,
      };

      await DailyBriefingService.saveBriefingSettings(settings);

      // 설정이 활성화되었다면 브리핑 업데이트
      if (_isEnabled) {
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
      initialTime: TimeOfDay(
        hour: int.parse(_briefingTime.split(':')[0]),
        minute: int.parse(_briefingTime.split(':')[1]),
      ),
    );

    if (picked != null) {
      setState(() {
        _briefingTime =
            '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
      });
    }
  }

  Future<void> _testBriefing() async {
    try {
      setState(() {
        _isLoading = true;
      });

      final today = DateTime.now();
      final briefing = await DailyBriefingService.generateBriefingSummary(
        today,
      );

      setState(() {
        _isLoading = false;
      });

      if (briefing != null) {
        showDialog(
          context: context,
          builder:
              (context) => AlertDialog(
                title: Text(
                  '오늘의 브리핑 미리보기',
                  style: getTextStyle(fontSize: 16, color: Colors.black),
                ),
                content: Text(
                  briefing,
                  style: getTextStyle(fontSize: 12, color: Colors.black),
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
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '브리핑 생성에 실패했습니다.',
              style: getTextStyle(fontSize: 12, color: Colors.white),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '브리핑 테스트에 실패했습니다: $e',
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
                      _isEnabled ? '브리핑 알림이 활성화되어 있습니다' : '브리핑 알림이 비활성화되어 있습니다',
                      style: getTextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    value: _isEnabled,
                    onChanged: (value) {
                      setState(() {
                        _isEnabled = value;
                      });
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (_isEnabled) ...[
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
                        _briefingTime,
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
                      '🛠️ 추가 옵션',
                      style: getTextStyle(
                        fontSize: 16,
                        color: Colors.black,
                      ).copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    SwitchListTile(
                      title: Text(
                        '내일 일정 포함',
                        style: getTextStyle(fontSize: 14, color: Colors.black),
                      ),
                      subtitle: Text(
                        '내일 일정도 미리 브리핑에 포함합니다',
                        style: getTextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      value: _includeTomorrow,
                      onChanged: (value) {
                        setState(() {
                          _includeTomorrow = value;
                        });
                      },
                    ),
                    SwitchListTile(
                      title: Text(
                        '날씨 정보 포함',
                        style: getTextStyle(fontSize: 14, color: Colors.black),
                      ),
                      subtitle: Text(
                        '브리핑에 날씨 정보를 포함합니다 (향후 추가 예정)',
                        style: getTextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      value: _includeWeather,
                      onChanged: (value) {
                        setState(() {
                          _includeWeather = value;
                        });
                      },
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
                      '🧪 테스트',
                      style: getTextStyle(
                        fontSize: 16,
                        color: Colors.black,
                      ).copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    ListTile(
                      leading: const Icon(
                        Icons.play_arrow,
                        color: Colors.green,
                      ),
                      title: Text(
                        '브리핑 미리보기',
                        style: getTextStyle(fontSize: 14, color: Colors.black),
                      ),
                      subtitle: Text(
                        '오늘 일정으로 브리핑을 미리 확인해보세요',
                        style: getTextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      onTap: _testBriefing,
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 24),
          if (_isEnabled)
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
      ),
    );
  }
}
