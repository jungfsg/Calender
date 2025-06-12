// lib/services/stt_command_service.dart (최종 수정본 - TTS 호출 로직 추가)
import 'package:flutter/material.dart';
import '../controllers/calendar_controller.dart';
import '../managers/event_manager.dart';
import '../managers/popup_manager.dart';
import '../services/weather_service.dart';
import '../services/chat_service.dart';
import '../widgets/stt_ui.dart';
import '../services/tts_service.dart'; // --- 추가: TtsService 임포트 ---

class VoiceCommandService {
  static VoiceCommandService? _instance;
  static VoiceCommandService get instance => _instance ??= VoiceCommandService._();

  VoiceCommandService._();

  final ChatService _chatService = ChatService();

  static const List<String> _calendarActionKeywords = [
    '추가', '생성', '만들', '등록', '잡아', '스케줄', '예약', '설정', '수정',
    '변경', '바꿔', '업데이트', '이동', '옮겨', '고쳐', '편집', '조정', '삭제',
    '지워', '취소', '없애', '빼', '제거', '다 삭제', '모두 삭제', '전체 삭제', '검색',
    '찾아', '조회', '확인', '뭐 있', '언제', '일정 보', '스케줄 확인', '복사',
    '복제', '같은 일정', '동일한',
  ];

  Future<void> showVoiceInput({
    required BuildContext context,
    required Function(String, String) onCommandProcessed,
    VoidCallback? onCalendarUpdate,
    EventManager? eventManager,
    required TtsService ttsService, // --- ★★★ 추가: TtsService 인스턴스 수신 ★★★ ---
  }) async {
    showModalBottomSheet(
      context: context,
      isDismissible: true,
      enableDrag: true,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (BuildContext context) {
        return FractionallySizedBox(
          heightFactor: 0.9,
          child: VoiceInputWidget(
            onVoiceCommand: (_) {},
            onProcessCommand: (command, responseCallback) {
              _processCommand(
                command,
                (response, originalCommand) {
                  responseCallback(response);
                  onCommandProcessed(response, originalCommand);
                },
                onCalendarUpdate,
                eventManager,
                ttsService, // --- ★★★ 추가: ttsService를 내부 로직으로 전달 ★★★ ---
              );
            },
            onClose: () {
              Navigator.of(context).pop();
            },
          ),
        );
      },
    );
  }

  Future<void> _processCommand(
    String command,
    Function(String, String) onCommandProcessed,
    VoidCallback? onCalendarUpdate,
    EventManager? eventManager,
    TtsService ttsService, // --- ★★★ 추가: ttsService 인스턴스 수신 ★★★ ---
  ) async {
    print('🎯 VoiceCommandService: 음성 명령 처리 시작 - "$command"');
    onCommandProcessed("명령어 처리 중...", command);

    try {
      if (_isSimpleCommand(command)) {
        final response = _processSimpleCommand(command);
        onCommandProcessed(response, command);
        // --- ★★★ 추가: 간단한 명령어 응답도 TTS로 출력 ★★★ ---
        await ttsService.speak(response); 
        return;
      }

      final userid = 'voice_command_user_${DateTime.now().millisecondsSinceEpoch}';
      final response = await _chatService.sendMessage(
        command,
        userid,
        eventManager: eventManager,
        onCalendarUpdate: () {
          print('🔄 VoiceCommandService: AI가 캘린더를 업데이트했습니다');
          if (eventManager != null) {
            eventManager.refreshCurrentMonthEvents().then((_) {
              if (onCalendarUpdate != null) {
                onCalendarUpdate();
              }
            });
          } else {
            if (onCalendarUpdate != null) {
              onCalendarUpdate();
            }
          }
        },
      );

      String formattedResponse = response.text.trim();
      if (formattedResponse.startsWith('AI:')) {
        formattedResponse = formattedResponse.substring(3).trim();
      }
      onCommandProcessed(formattedResponse, command);
      
      // --- ★★★ 추가: AI 응답을 TTS로 출력 ★★★ ---
      await ttsService.speak(formattedResponse);

    } catch (e) {
      print('AI 처리 오류: $e');
      final response = '명령을 이해하지 못했습니다. 다시 시도해주세요.';
      onCommandProcessed(response, command);
      // --- ★★★ 추가: 에러 메시지도 TTS로 출력 ★★★ ---
      await ttsService.speak(response);
    }
  }

  bool _isSimpleCommand(String command) {
    command = command.toLowerCase();
    if (_calendarActionKeywords.any((keyword) => command.contains(keyword))) {
      return false;
    }
    final simpleCommands = [
      '다음 달', '다음달', '이전 달', '전 달', '저번달', '지난달',
      '날씨', '날씨 보여', '날씨보여', '날씨 정보', '타임테이블', '시간표',
    ];
    if ((command.contains('오늘') || command.contains('투데이')) &&
        !_calendarActionKeywords.any((keyword) => command.contains(keyword))) {
      return true;
    }
    return simpleCommands.any((cmd) => command.contains(cmd)) ||
        RegExp(r'\d{4}년|\d{1,2}월').hasMatch(command);
  }

  String _processSimpleCommand(String command) {
    command = command.toLowerCase();
    if ((command.contains('오늘') || command.contains('투데이')) &&
        !_calendarActionKeywords.any((keyword) => command.contains(keyword))) {
      return '오늘 날짜로 이동했습니다.';
    } else if (command.contains('다음 달') || command.contains('다음달')) {
      return '다음 달로 이동했습니다.';
    } else if (command.contains('이전 달') || command.contains('전 달') || command.contains('저번달') || command.contains('지난달')) {
      return '이전 달로 이동했습니다.';
    } else if (command.contains('날씨')) {
      return '날씨 정보를 불러오는 중입니다.';
    } else if (command.contains('일정 보기') || command.contains('일정보기')) {
      return '일정을 표시합니다.';
    } else if (command.contains('타임테이블') || command.contains('시간표')) {
      return '타임테이블을 표시합니다.';
    } else if (RegExp(r'\d{4}년|\d{1,2}월').hasMatch(command)) {
      return '해당 날짜로 이동했습니다.';
    }
    return '';
  }

  void processCalendarCommand(String command, CalendarController controller, PopupManager popupManager, EventManager eventManager, VoidCallback onStateUpdate) {
    final lowerCommand = command.toLowerCase();
    if (lowerCommand.contains('다음 달') || lowerCommand.contains('다음달')) {
      _moveToNextMonth(controller, onStateUpdate);
    } else if (lowerCommand.contains('이전 달') || lowerCommand.contains('전 달') || lowerCommand.contains('저번달') || lowerCommand.contains('지난달')) {
      _moveToPreviousMonth(controller, onStateUpdate);
    } else if (lowerCommand.contains('오늘') || lowerCommand.contains('투데이')) {
      if (!_calendarActionKeywords.any((keyword) => lowerCommand.contains(keyword))) {
        _moveToToday(controller, popupManager, onStateUpdate);
      }
    } else if (_checkForDateMovement(lowerCommand, controller)) {
      onStateUpdate();
    } else if (lowerCommand.contains('날씨')) {
      _showWeatherForecast(controller, popupManager, onStateUpdate);
    }
  }

  void _moveToNextMonth(CalendarController controller, VoidCallback onStateUpdate) {
    final nextMonth = DateTime(controller.focusedDay.year, controller.focusedDay.month + 1, 1);
    controller.setFocusedDay(nextMonth);
    controller.setSelectedDay(nextMonth);
    onStateUpdate();
  }

  void _moveToPreviousMonth(CalendarController controller, VoidCallback onStateUpdate) {
    final prevMonth = DateTime(controller.focusedDay.year, controller.focusedDay.month - 1, 1);
    controller.setFocusedDay(prevMonth);
    controller.setSelectedDay(prevMonth);
    onStateUpdate();
  }

  void _moveToToday(CalendarController controller, PopupManager popupManager, VoidCallback onStateUpdate) {
    final today = DateTime.now();
    controller.setFocusedDay(today);
    controller.setSelectedDay(today);
    popupManager.showEventDialog();
    onStateUpdate();
  }

  void _showWeatherForecast(CalendarController controller, PopupManager popupManager, VoidCallback onStateUpdate) {
    WeatherService.loadCalendarWeather(controller).then((_) {
      popupManager.showWeatherForecastDialog();
      onStateUpdate();
    });
  }

  bool _checkForDateMovement(String command, CalendarController controller) {
    RegExp yearPattern = RegExp(r'(\d{4})년');
    RegExp monthPattern = RegExp(r'(\d{1,2})월');
    final yearMatches = yearPattern.allMatches(command);
    final monthMatches = monthPattern.allMatches(command);
    int? year;
    int? month;
    if (yearMatches.isNotEmpty) {
      year = int.tryParse(yearMatches.first.group(1) ?? '');
    }
    if (monthMatches.isNotEmpty) {
      month = int.tryParse(monthMatches.first.group(1) ?? '');
    }
    if (year != null && month != null && month >= 1 && month <= 12) {
      final targetDate = DateTime(year, month, 1);
      controller.setFocusedDay(targetDate);
      controller.setSelectedDay(targetDate);
      return true;
    } else if (month != null && month >= 1 && month <= 12) {
      final targetDate = DateTime(controller.focusedDay.year, month, 1);
      controller.setFocusedDay(targetDate);
      controller.setSelectedDay(targetDate);
      return true;
    }
    return false;
  }
}
