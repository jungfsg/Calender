import 'package:flutter/material.dart';
import '../controllers/calendar_controller.dart';
import '../managers/event_manager.dart';
import '../managers/popup_manager.dart';
import '../services/weather_service.dart';
import '../services/chat_service.dart';
import '../widgets/stt_ui.dart';

/// 음성 명령 처리 서비스 - 로컬 명령어 + AI 처리
class VoiceCommandService {
  static VoiceCommandService? _instance;
  static VoiceCommandService get instance =>
      _instance ??= VoiceCommandService._();

  VoiceCommandService._();

  final ChatService _chatService = ChatService();

  /// 음성 입력 다이얼로그 표시
  Future<void> showVoiceInput({
    required BuildContext context,
    required Function(String, String) onCommandProcessed,
  }) async {
    showModalBottomSheet(
      context: context,
      isDismissible: true,
      enableDrag: true,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return VoiceInputWidget(
          onVoiceCommand: (command) {
            _processCommand(command, onCommandProcessed);
          },
          onClose: () => Navigator.of(context).pop(),
        );
      },
    );
  }

  /// 음성 명령 처리
  Future<void> _processCommand(
    String command,
    Function(String, String) onCommandProcessed,
  ) async {
    // 즉시 처리 중 메시지 표시
    onCommandProcessed("명령어 처리 중...", command);

    try {
      // 간단한 명령어는 로컬에서 처리
      if (_isSimpleCommand(command)) {
        final response = _processSimpleCommand(command);
        onCommandProcessed(response, command);
        return;
      }

      // 복잡한 명령어는 AI로 전달
      final userid =
          'voice_command_user_${DateTime.now().millisecondsSinceEpoch}';
      final response = await _chatService.sendMessage(
        command,
        userid,
        onCalendarUpdate: () {
          // AI가 일정을 추가/수정/삭제한 경우 콜백으로 알림
        },
      );

      onCommandProcessed('AI: ${response.text}', command);
    } catch (e) {
      print('AI 처리 오류: $e');
      // 오류 발생 시 기본 메시지로 처리
      final response = _processSimpleCommand(command);
      onCommandProcessed(
        response.isNotEmpty ? response : '명령을 이해하지 못했습니다.',
        command,
      );
    }
  }

  /// 간단한 명령어인지 확인
  bool _isSimpleCommand(String command) {
    command = command.toLowerCase();
    final simpleCommands = [
      '오늘',
      '투데이',
      '다음 달',
      '다음달',
      '이전 달',
      '전 달',
      '저번달',
      '지난달',
      '날씨',
      '날씨 보여',
      '날씨보여',
      '날씨 정보',
      '일정 보기',
      '일정보기',
      '타임테이블',
      '시간표',
    ];

    return simpleCommands.any((cmd) => command.contains(cmd)) ||
        RegExp(r'\d{4}년|\d{1,2}월').hasMatch(command); // 연도/월 패턴도 간단한 명령어로 처리
  }

  /// 간단한 명령어 처리
  String _processSimpleCommand(String command) {
    command = command.toLowerCase();

    if (command.contains('오늘') || command.contains('투데이')) {
      return '오늘 날짜로 이동했습니다.';
    } else if (command.contains('다음 달') || command.contains('다음달')) {
      return '다음 달로 이동했습니다.';
    } else if (command.contains('이전 달') ||
        command.contains('전 달') ||
        command.contains('저번달') ||
        command.contains('지난달')) {
      return '이전 달로 이동했습니다.';
    } else if (command.contains('날씨')) {
      return '날씨 정보를 불러오는 중...';
    } else if (command.contains('일정 보기') || command.contains('일정보기')) {
      return '일정을 표시합니다.';
    } else if (command.contains('타임테이블') || command.contains('시간표')) {
      return '타임테이블을 표시합니다.';
    } else if (RegExp(r'\d{4}년|\d{1,2}월').hasMatch(command)) {
      return '날짜로 이동했습니다.';
    }

    return ''; // 빈 문자열 반환으로 AI 처리로 넘어가도록
  }

  /// 캘린더 관련 음성 명령 처리
  void processCalendarCommand(
    String command,
    CalendarController controller,
    PopupManager popupManager,
    EventManager eventManager,
    VoidCallback onStateUpdate,
  ) {
    final lowerCommand = command.toLowerCase();

    // 달력 이동 명령어 처리
    if (lowerCommand.contains('다음 달') || lowerCommand.contains('다음달')) {
      _moveToNextMonth(controller, onStateUpdate);
    } else if (lowerCommand.contains('이전 달') ||
        lowerCommand.contains('전 달') ||
        lowerCommand.contains('저번달') ||
        lowerCommand.contains('지난달')) {
      _moveToPreviousMonth(controller, onStateUpdate);
    } else if (lowerCommand.contains('오늘') || lowerCommand.contains('투데이')) {
      _moveToToday(controller, popupManager, onStateUpdate);
    } else if (_checkForDateMovement(lowerCommand, controller)) {
      // 연도/월 이동 처리됨
      onStateUpdate();
    }
    // 일정 관리 명령어
    else if (lowerCommand.contains('일정 추가') ||
        lowerCommand.contains('일정추가') ||
        lowerCommand.contains('새 일정') ||
        lowerCommand.contains('새일정')) {
      // 컨텍스트가 필요한 작업은 콜백으로 처리
    } else if (lowerCommand.contains('일정 보기') ||
        lowerCommand.contains('일정보기')) {
      popupManager.showEventDialog();
      onStateUpdate();
    }
    // 타임테이블 관련 명령어
    else if (lowerCommand.contains('타임테이블') || lowerCommand.contains('시간표')) {
      popupManager.showTimeTableDialog();
      onStateUpdate();
    }
    // 날씨 정보 명령어 처리
    else if (lowerCommand.contains('날씨')) {
      _showWeatherForecast(controller, popupManager, onStateUpdate);
    }
  }

  void _moveToNextMonth(
    CalendarController controller,
    VoidCallback onStateUpdate,
  ) {
    final nextMonth = DateTime(
      controller.focusedDay.year,
      controller.focusedDay.month + 1,
      1,
    );
    controller.setFocusedDay(nextMonth);
    controller.setSelectedDay(nextMonth);
    onStateUpdate();
  }

  void _moveToPreviousMonth(
    CalendarController controller,
    VoidCallback onStateUpdate,
  ) {
    final prevMonth = DateTime(
      controller.focusedDay.year,
      controller.focusedDay.month - 1,
      1,
    );
    controller.setFocusedDay(prevMonth);
    controller.setSelectedDay(prevMonth);
    onStateUpdate();
  }

  void _moveToToday(
    CalendarController controller,
    PopupManager popupManager,
    VoidCallback onStateUpdate,
  ) {
    final today = DateTime.now();
    controller.setFocusedDay(today);
    controller.setSelectedDay(today);
    popupManager.showEventDialog();
    onStateUpdate();
  }

  void _showWeatherForecast(
    CalendarController controller,
    PopupManager popupManager,
    VoidCallback onStateUpdate,
  ) {
    WeatherService.loadCalendarWeather(controller).then((_) {
      popupManager.showWeatherForecastDialog();
      onStateUpdate();
    });
  }

  /// 연도와 월 이동 명령어 처리 (ex: "2024년 5월로 이동")
  bool _checkForDateMovement(String command, CalendarController controller) {
    // 연도 및 월 추출을 위한 패턴 확인
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

    // 연도와 월이 모두 유효하면 해당 날짜로 이동
    if (year != null && month != null && month >= 1 && month <= 12) {
      final targetDate = DateTime(year, month, 1);
      controller.setFocusedDay(targetDate);
      controller.setSelectedDay(targetDate);
      return true;
    }
    // 월만 있는 경우 (현재 연도에서 해당 월로 이동)
    else if (month != null && month >= 1 && month <= 12) {
      final targetDate = DateTime(controller.focusedDay.year, month, 1);
      controller.setFocusedDay(targetDate);
      controller.setSelectedDay(targetDate);
      return true;
    }

    return false;
  }
}
