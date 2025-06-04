import '../models/event.dart';
import '../models/time_slot.dart';
import '../controllers/calendar_controller.dart';
import '../managers/event_manager.dart';
import '../services/stt_command_service.dart';
import 'package:flutter/material.dart';

/// 팝업 관련 로직을 처리하는 매니저 클래스
class PopupManager {
  final CalendarController _controller;
  final EventManager _eventManager;

  PopupManager(this._controller, this._eventManager);

  /// STT 초기화 (VoiceCommandService에서 자동 관리)
  Future<void> initializeSpeech() async {
    // VoiceCommandService가 자동으로 초기화됨
    print('✅ STT는 VoiceCommandService에서 관리됩니다');
  }

  /// 이벤트 다이얼로그 표시
  void showEventDialog() {
    _controller.hideAllPopups();
    _controller.showEventDialog();
  }

  /// 이벤트 다이얼로그 숨기기
  void hideEventDialog() {
    _controller.hideEventDialog();
  }

  /// 타임테이블 다이얼로그 표시
  void showTimeTableDialog() {
    _controller.hideAllPopups();
    _controller.showTimeTableDialog();
  }

  /// 타임테이블 다이얼로그 숨기기
  void hideTimeTableDialog() {
    _controller.hideTimeTableDialog();
  }

  /// 날씨 예보 다이얼로그 표시
  void showWeatherForecastDialog() {
    _controller.hideAllPopups();
    _controller.showWeatherDialog();
  }

  /// 날씨 예보 다이얼로그 숨기기
  void hideWeatherForecastDialog() {
    _controller.hideWeatherDialog();
  }

  /// 이벤트 추가 다이얼로그 표시
  Future<void> showAddEventDialog(BuildContext context) async {
    String title = '';
    String time = '';
    String description = '';

    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('새 이벤트 추가'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  decoration: const InputDecoration(
                    labelText: '이벤트 제목',
                    hintText: '예: 회의, 약속 등',
                  ),
                  onChanged: (value) => title = value,
                ),
                const SizedBox(height: 16),
                TextField(
                  decoration: const InputDecoration(
                    labelText: '시간',
                    hintText: '예: 14:00 또는 오후 2시',
                  ),
                  onChanged: (value) => time = value,
                ),
                const SizedBox(height: 16),
                TextField(
                  decoration: const InputDecoration(
                    labelText: '설명 (선택사항)',
                    hintText: '추가 정보',
                  ),
                  maxLines: 2,
                  onChanged: (value) => description = value,
                ),
                const SizedBox(height: 16),
                // 음성 입력 버튼
                ElevatedButton.icon(
                  onPressed: () => _handleVoiceInput(context),
                  icon: const Icon(Icons.mic),
                  label: const Text('음성으로 추가'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('취소'),
            ),
            ElevatedButton(
              onPressed:
                  title.isNotEmpty
                      ? () async {                        final event = Event(
                          title: title,
                          time: time.isNotEmpty ? time : '시간 미정',
                          date: _controller.selectedDay,
                          description: description,
                          source: 'local', // 로컬에서 생성된 이벤트
                        );

                        try {
                          await _eventManager.addEvent(event);
                          Navigator.of(context).pop();
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('이벤트 추가 실패: $e')),
                          );
                        }
                      }
                      : null,
              child: const Text('추가'),
            ),
          ],
        );
      },
    );
  }

  /// 음성 입력 처리
  void _handleVoiceInput(BuildContext context) {
    // VoiceCommandService를 사용하여 음성 입력 처리
    VoiceCommandService.instance.showVoiceInput(
      context: context,
      onCommandProcessed: (response, originalCommand) async {
        // 음성으로 인식된 결과를 바탕으로 이벤트 생성
        if (originalCommand.isNotEmpty) {
          final eventInfo = _parseEventFromText(originalCommand);

          if (eventInfo['title'] != null && eventInfo['title']!.isNotEmpty) {            final event = Event(
              title: eventInfo['title'] ?? '제목 없음',
              time: eventInfo['time'] ?? '시간 미정',
              date: _controller.selectedDay,
              description: eventInfo['description'] ?? '',
              source: 'local', // 로컬에서 생성된 이벤트
            );

            try {
              await _eventManager.addEvent(event);
              Navigator.of(context).pop(); // 다이얼로그 닫기

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('이벤트가 추가되었습니다: ${event.title}'),
                  backgroundColor: Colors.green,
                ),
              );
            } catch (e) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('이벤트 추가 실패: $e'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('이벤트 정보를 추출할 수 없습니다. 다시 시도해주세요.'),
                backgroundColor: Colors.orange,
              ),
            );
          }
        }
      },
    );
  }

  /// 텍스트에서 이벤트 정보 파싱
  Map<String, String> _parseEventFromText(String text) {
    final result = <String, String>{};

    // 기본 제목 설정
    result['title'] = text.length > 20 ? '${text.substring(0, 20)}...' : text;
    result['description'] = text;

    // 시간 패턴 찾기 (예: "3시", "15:30", "오후 2시" 등)
    final timePatterns = [
      RegExp(r'(\d{1,2})시(\d{0,2}분?)?'),
      RegExp(r'(\d{1,2}):(\d{2})'),
      RegExp(r'(오전|오후)\s*(\d{1,2})시(\d{0,2}분?)?'),
    ];

    for (final pattern in timePatterns) {
      final match = pattern.firstMatch(text);
      if (match != null) {
        result['time'] = match.group(0) ?? '시간 미정';
        break;
      }
    }

    return result;
  }

  /// 타임슬롯 추가 다이얼로그 표시
  Future<void> showAddTimeSlotDialog(BuildContext context) async {
    String startTime = '';
    String endTime = '';
    String activity = '';

    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('새 타임슬롯 추가'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                decoration: const InputDecoration(
                  labelText: '시작 시간',
                  hintText: '예: 09:00',
                ),
                onChanged: (value) => startTime = value,
              ),
              const SizedBox(height: 16),
              TextField(
                decoration: const InputDecoration(
                  labelText: '종료 시간',
                  hintText: '예: 10:00',
                ),
                onChanged: (value) => endTime = value,
              ),
              const SizedBox(height: 16),
              TextField(
                decoration: const InputDecoration(
                  labelText: '활동',
                  hintText: '예: 운동, 공부 등',
                ),
                onChanged: (value) => activity = value,
              ),
              const SizedBox(height: 16),
              // 음성 입력 버튼
              ElevatedButton.icon(
                onPressed: () => _handleTimeSlotVoiceInput(context),
                icon: const Icon(Icons.mic),
                label: const Text('음성으로 추가'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('취소'),
            ),
            ElevatedButton(
              onPressed:
                  startTime.isNotEmpty &&
                          endTime.isNotEmpty &&
                          activity.isNotEmpty
                      ? () {
                        final timeSlot = TimeSlot(
                          activity,
                          startTime,
                          endTime,
                          Colors.blue,
                          date: _controller.selectedDay,
                        );

                        _controller.addTimeSlot(timeSlot);
                        Navigator.of(context).pop();
                      }
                      : null,
              child: const Text('추가'),
            ),
          ],
        );
      },
    );
  }

  /// 타임슬롯 음성 입력 처리
  void _handleTimeSlotVoiceInput(BuildContext context) {
    VoiceCommandService.instance.showVoiceInput(
      context: context,
      onCommandProcessed: (response, originalCommand) async {
        if (originalCommand.isNotEmpty) {
          final timeSlotInfo = _parseTimeSlotFromText(originalCommand);

          if (timeSlotInfo['activity'] != null &&
              timeSlotInfo['startTime'] != null &&
              timeSlotInfo['endTime'] != null) {
            final timeSlot = TimeSlot(
              timeSlotInfo['activity']!,
              timeSlotInfo['startTime']!,
              timeSlotInfo['endTime']!,
              Colors.blue,
              date: _controller.selectedDay,
            );

            _controller.addTimeSlot(timeSlot);
            Navigator.of(context).pop();

            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('타임슬롯이 추가되었습니다: ${timeSlot.title}'),
                backgroundColor: Colors.green,
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('타임슬롯 정보를 추출할 수 없습니다. 다시 시도해주세요.'),
                backgroundColor: Colors.orange,
              ),
            );
          }
        }
      },
    );
  }

  /// 텍스트에서 타임슬롯 정보 파싱
  Map<String, String> _parseTimeSlotFromText(String text) {
    final result = <String, String>{};

    // 기본 활동명 설정
    result['activity'] =
        text.length > 20 ? '${text.substring(0, 20)}...' : text;

    // 시간 패턴 찾기 (예: "9시부터 10시까지", "09:00-10:00" 등)
    final timeRangePatterns = [
      RegExp(r'(\d{1,2})시부터\s*(\d{1,2})시까지'),
      RegExp(r'(\d{1,2}):(\d{2})\s*[-~]\s*(\d{1,2}):(\d{2})'),
      RegExp(r'(\d{1,2})시\s*[-~]\s*(\d{1,2})시'),
    ];

    for (final pattern in timeRangePatterns) {
      final match = pattern.firstMatch(text);
      if (match != null) {
        result['startTime'] = '${match.group(1)}:00';
        result['endTime'] = '${match.group(2)}:00';
        break;
      }
    }

    // 기본값 설정
    result['startTime'] ??= '09:00';
    result['endTime'] ??= '10:00';

    return result;
  }

  /// 리소스 정리 (더 이상 STT 관련 정리 불필요)
  void dispose() {
    // VoiceCommandService가 자체적으로 관리함
  }
}
