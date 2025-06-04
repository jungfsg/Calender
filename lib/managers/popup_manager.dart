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

  /// 이벤트 추가 다이얼로그 표시 (개선된 버전)
  Future<void> showAddEventDialog(BuildContext context) async {
    String title = '';
    String time = '';
    String description = '';
    Color selectedColor = Colors.blue; // 기본 색상
    bool isAllDay = false; // 종일 일정 여부

    // 시간 선택을 위한 TimeOfDay
    TimeOfDay? startTime;
    TimeOfDay? endTime;

    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            // 시간을 포맷팅하는 헬퍼 함수
            String formatTimeDisplay() {
              if (isAllDay) {
                return '종일';
              } else if (startTime != null && endTime != null) {
                return '${startTime!.format(context)} - ${endTime!.format(context)}';
              } else if (startTime != null) {
                return startTime!.format(context);
              } else if (time.isNotEmpty) {
                return time;
              } else {
                return '시간 선택';
              }
            }

            return Material(
              type: MaterialType.transparency,
              child: Container(
                color: Colors.black.withOpacity(0.5),
                child: Center(
                  child: Material(
                    type: MaterialType.card,
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    clipBehavior: Clip.antiAlias,
                    elevation: 5.0,
                    child: Container(
                      width: MediaQuery.of(context).size.width * 0.85,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.black, width: 2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // 픽셀아트 스타일 헤더
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            decoration: const BoxDecoration(
                              color: Color.fromARGB(255, 162, 222, 141),
                              borderRadius: BorderRadius.only(
                                topLeft: Radius.circular(8),
                                topRight: Radius.circular(8),
                              ),
                              border: Border(
                                bottom: BorderSide(
                                  color: Colors.black,
                                  width: 2,
                                ),
                              ),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    '${_controller.selectedDay.year}년 ${_controller.selectedDay.month}월 ${_controller.selectedDay.day}일',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () => Navigator.of(context).pop(),
                                  child: Container(
                                    width: 24,
                                    height: 24,
                                    decoration: BoxDecoration(
                                      color: Colors.red,
                                      border: Border.all(
                                        color: Colors.white,
                                        width: 1,
                                      ),
                                    ),
                                    alignment: Alignment.center,
                                    child: const Text(
                                      'X',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // 내용 부분
                          Container(
                            padding: const EdgeInsets.all(16),
                            child: SingleChildScrollView(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // 제목 입력
                                  Container(
                                    decoration: BoxDecoration(
                                      border: Border.all(
                                        color: Colors.black,
                                        width: 2,
                                      ),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: TextField(
                                      decoration: const InputDecoration(
                                        labelText: '일정 제목',
                                        hintText: '예: 회의, 약속, 생일 등',
                                        border: InputBorder.none,
                                        contentPadding: EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: 12,
                                        ),
                                        prefixIcon: Icon(Icons.event_note),
                                      ),
                                      onChanged: (value) => title = value,
                                    ),
                                  ),
                                  const SizedBox(height: 16),

                                  // 종일 일정 체크박스
                                  Container(
                                    decoration: BoxDecoration(
                                      border: Border.all(
                                        color: Colors.black,
                                        width: 2,
                                      ),
                                      borderRadius: BorderRadius.circular(8),
                                      color:
                                          isAllDay
                                              ? const Color.fromARGB(
                                                255,
                                                162,
                                                222,
                                                141,
                                              ).withOpacity(0.3)
                                              : Colors.white,
                                    ),
                                    child: CheckboxListTile(
                                      title: const Text(
                                        '종일 일정',
                                        style: TextStyle(fontSize: 16),
                                      ),
                                      value: isAllDay,
                                      controlAffinity:
                                          ListTileControlAffinity.leading,
                                      onChanged: (value) {
                                        setState(() {
                                          isAllDay = value ?? false;
                                        });
                                      },
                                    ),
                                  ),
                                  const SizedBox(height: 16),

                                  // 시간 설정 (종일이 아닌 경우만)
                                  if (!isAllDay)
                                    Container(
                                      decoration: BoxDecoration(
                                        border: Border.all(
                                          color: Colors.black,
                                          width: 2,
                                        ),
                                        borderRadius: BorderRadius.circular(8),
                                        color: const Color.fromARGB(
                                          255,
                                          235,
                                          245,
                                          228,
                                        ),
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 8,
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            '일정 시간',
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          Row(
                                            children: [
                                              Expanded(
                                                child: ElevatedButton.icon(
                                                  icon: const Icon(
                                                    Icons.access_time,
                                                  ),
                                                  label: Text(
                                                    startTime != null
                                                        ? '시작: ${startTime!.format(context)}'
                                                        : '시작 시간',
                                                  ),
                                                  onPressed: () async {
                                                    final picked = await showTimePicker(
                                                      context: context,
                                                      initialTime:
                                                          startTime ??
                                                          TimeOfDay.now(),
                                                      builder: (
                                                        BuildContext context,
                                                        Widget? child,
                                                      ) {
                                                        return Theme(
                                                          data: ThemeData.light().copyWith(
                                                            colorScheme:
                                                                const ColorScheme.light(
                                                                  primary:
                                                                      Color.fromARGB(
                                                                        255,
                                                                        162,
                                                                        222,
                                                                        141,
                                                                      ),
                                                                ),
                                                            buttonTheme:
                                                                const ButtonThemeData(
                                                                  textTheme:
                                                                      ButtonTextTheme
                                                                          .primary,
                                                                ),
                                                          ),
                                                          child: child!,
                                                        );
                                                      },
                                                    );

                                                    if (picked != null) {
                                                      setState(() {
                                                        startTime = picked;
                                                        time =
                                                            formatTimeDisplay();
                                                      });
                                                    }
                                                  },
                                                  style: ElevatedButton.styleFrom(
                                                    backgroundColor:
                                                        const Color.fromARGB(
                                                          255,
                                                          162,
                                                          222,
                                                          141,
                                                        ),
                                                    foregroundColor:
                                                        Colors.black,
                                                    shape: RoundedRectangleBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            8,
                                                          ),
                                                      side: const BorderSide(
                                                        color: Colors.black,
                                                        width: 2,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: ElevatedButton.icon(
                                                  icon: const Icon(
                                                    Icons.access_time,
                                                  ),
                                                  label: Text(
                                                    endTime != null
                                                        ? '종료: ${endTime!.format(context)}'
                                                        : '종료 시간',
                                                  ),
                                                  onPressed: () async {
                                                    final picked = await showTimePicker(
                                                      context: context,
                                                      initialTime:
                                                          endTime ??
                                                          TimeOfDay.now(),
                                                      builder: (
                                                        BuildContext context,
                                                        Widget? child,
                                                      ) {
                                                        return Theme(
                                                          data: ThemeData.light()
                                                              .copyWith(
                                                                colorScheme:
                                                                    const ColorScheme.light(
                                                                      primary:
                                                                          Color.fromARGB(
                                                                            255,
                                                                            162,
                                                                            222,
                                                                            141,
                                                                          ),
                                                                    ),
                                                              ),
                                                          child: child!,
                                                        );
                                                      },
                                                    );

                                                    if (picked != null) {
                                                      setState(() {
                                                        endTime = picked;
                                                        time =
                                                            formatTimeDisplay();
                                                      });
                                                    }
                                                  },
                                                  style: ElevatedButton.styleFrom(
                                                    backgroundColor:
                                                        const Color.fromARGB(
                                                          255,
                                                          162,
                                                          222,
                                                          141,
                                                        ),
                                                    foregroundColor:
                                                        Colors.black,
                                                    shape: RoundedRectangleBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            8,
                                                          ),
                                                      side: const BorderSide(
                                                        color: Colors.black,
                                                        width: 2,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),

                                  const SizedBox(height: 16),

                                  // 색상 선택
                                  Container(
                                    decoration: BoxDecoration(
                                      border: Border.all(
                                        color: Colors.black,
                                        width: 2,
                                      ),
                                      borderRadius: BorderRadius.circular(8),
                                      color: const Color.fromARGB(
                                        255,
                                        235,
                                        245,
                                        228,
                                      ),
                                    ),
                                    padding: const EdgeInsets.all(12),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          '일정 색상',
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Wrap(
                                          spacing: 10.0,
                                          runSpacing: 10.0,
                                          children:
                                              [
                                                Colors.red,
                                                Colors.pink,
                                                Colors.purple,
                                                Colors.deepPurple,
                                                Colors.indigo,
                                                Colors.blue,
                                                Colors.lightBlue,
                                                Colors.cyan,
                                                Colors.teal,
                                                Colors.green,
                                                Colors.lightGreen,
                                                Colors.lime,
                                                Colors.yellow,
                                                Colors.amber,
                                                Colors.orange,
                                                Colors.deepOrange,
                                                Colors.brown,
                                                Colors.grey,
                                              ].map((color) {
                                                return GestureDetector(
                                                  onTap: () {
                                                    setState(() {
                                                      selectedColor = color;
                                                    });
                                                  },
                                                  child: Container(
                                                    width: 36,
                                                    height: 36,
                                                    decoration: BoxDecoration(
                                                      color: color,
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            8,
                                                          ),
                                                      border: Border.all(
                                                        width: 3,
                                                        color:
                                                            selectedColor ==
                                                                    color
                                                                ? Colors.black
                                                                : Colors.grey
                                                                    .withOpacity(
                                                                      0.5,
                                                                    ),
                                                      ),
                                                      boxShadow: [
                                                        BoxShadow(
                                                          color: Colors.black
                                                              .withOpacity(0.2),
                                                          spreadRadius: 1,
                                                          blurRadius: 3,
                                                          offset: const Offset(
                                                            0,
                                                            2,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                );
                                              }).toList(),
                                        ),
                                      ],
                                    ),
                                  ),

                                  const SizedBox(height: 16),

                                  // 설명 입력
                                  Container(
                                    decoration: BoxDecoration(
                                      border: Border.all(
                                        color: Colors.black,
                                        width: 2,
                                      ),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: TextField(
                                      decoration: const InputDecoration(
                                        labelText: '메모 (선택사항)',
                                        hintText: '상세 정보를 입력하세요',
                                        border: InputBorder.none,
                                        contentPadding: EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: 12,
                                        ),
                                      ),
                                      maxLines: 3,
                                      onChanged: (value) => description = value,
                                    ),
                                  ),

                                  const SizedBox(height: 16),

                                  // 하단 버튼
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      // 음성 입력 버튼
                                      Expanded(
                                        child: ElevatedButton.icon(
                                          onPressed:
                                              () => _handleVoiceInput(context),
                                          icon: const Icon(Icons.mic),
                                          label: const Text(
                                            '음성으로 추가',
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.green,
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 12,
                                            ),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              side: const BorderSide(
                                                color: Colors.black,
                                                width: 2,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),

                                      const SizedBox(width: 8),

                                      // 일정 추가 버튼
                                      Expanded(
                                        child: ElevatedButton.icon(
                                          onPressed:
                                              title.isNotEmpty
                                                  ? () async {
                                                    // 시간 문자열 구성
                                                    String timeString;
                                                    if (isAllDay) {
                                                      timeString = '종일';
                                                    } else if (startTime !=
                                                            null &&
                                                        endTime != null) {
                                                      timeString =
                                                          '${startTime!.format(context)} - ${endTime!.format(context)}';
                                                    } else if (startTime !=
                                                        null) {
                                                      timeString = startTime!
                                                          .format(context);
                                                    } else if (time
                                                        .isNotEmpty) {
                                                      timeString = time;
                                                    } else {
                                                      timeString = '시간 미정';
                                                    }

                                                    final event = Event(
                                                      title: title,
                                                      time: timeString,
                                                      date:
                                                          _controller
                                                              .selectedDay,
                                                      description: description,
                                                      source:
                                                          'local', // 로컬에서 생성된 이벤트
                                                      color:
                                                          selectedColor, // 사용자가 선택한 색상 적용
                                                    );

                                                    try {
                                                      await _eventManager
                                                          .addEvent(event);
                                                      Navigator.of(
                                                        context,
                                                      ).pop();

                                                      // 성공 메시지 표시
                                                      ScaffoldMessenger.of(
                                                        context,
                                                      ).showSnackBar(
                                                        SnackBar(
                                                          content: Text(
                                                            '새 일정이 추가되었습니다: $title',
                                                          ),
                                                          backgroundColor:
                                                              Colors.green,
                                                        ),
                                                      );
                                                    } catch (e) {
                                                      ScaffoldMessenger.of(
                                                        context,
                                                      ).showSnackBar(
                                                        SnackBar(
                                                          content: Text(
                                                            '일정 추가 실패: $e',
                                                          ),
                                                          backgroundColor:
                                                              Colors.red,
                                                        ),
                                                      );
                                                    }
                                                  }
                                                  : null,
                                          icon: const Icon(Icons.add),
                                          label: const Text(
                                            '일정 추가',
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor:
                                                const Color.fromARGB(
                                                  255,
                                                  162,
                                                  222,
                                                  141,
                                                ),
                                            foregroundColor: Colors.black,
                                            disabledBackgroundColor:
                                                Colors.grey[300],
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 16,
                                              vertical: 12,
                                            ),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              side: const BorderSide(
                                                color: Colors.black,
                                                width: 2,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  /// 음성 입력 처리
  void _handleVoiceInput(BuildContext context) {
    // VoiceCommandService를 사용하여 음성 입력 처리
    VoiceCommandService.instance.showVoiceInput(
      context: context,
      eventManager: _eventManager, // EventManager 전달
      onCommandProcessed: (response, originalCommand) async {
        // 음성으로 인식된 결과를 바탕으로 이벤트 생성
        if (originalCommand.isNotEmpty) {
          final eventInfo = _parseEventFromText(originalCommand);

          if (eventInfo['title'] != null && eventInfo['title']!.isNotEmpty) {
            final event = Event(
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
    Color selectedColor = Colors.blue; // 기본 색상

    // TimeOfDay 객체로 시간 관리
    TimeOfDay? startTimeOfDay;
    TimeOfDay? endTimeOfDay;

    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Material(
              type: MaterialType.transparency,
              child: Container(
                color: Colors.black.withOpacity(0.5),
                child: Center(
                  child: Material(
                    type: MaterialType.card,
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    clipBehavior: Clip.antiAlias,
                    elevation: 5.0,
                    child: Container(
                      width: MediaQuery.of(context).size.width * 0.85,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.black, width: 2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // 픽셀아트 스타일 헤더
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            decoration: const BoxDecoration(
                              color: Color.fromARGB(255, 162, 222, 141),
                              borderRadius: BorderRadius.only(
                                topLeft: Radius.circular(8),
                                topRight: Radius.circular(8),
                              ),
                              border: Border(
                                bottom: BorderSide(
                                  color: Colors.black,
                                  width: 2,
                                ),
                              ),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    '${_controller.selectedDay.year}년 ${_controller.selectedDay.month}월 ${_controller.selectedDay.day}일 타임슬롯',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () => Navigator.of(context).pop(),
                                  child: Container(
                                    width: 24,
                                    height: 24,
                                    decoration: BoxDecoration(
                                      color: Colors.red,
                                      border: Border.all(
                                        color: Colors.white,
                                        width: 1,
                                      ),
                                    ),
                                    alignment: Alignment.center,
                                    child: const Text(
                                      'X',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // 내용 부분
                          Container(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // 활동 입력
                                Container(
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                      color: Colors.black,
                                      width: 2,
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: TextField(
                                    decoration: const InputDecoration(
                                      labelText: '활동 내용',
                                      hintText: '예: 운동, 공부, 미팅 등',
                                      border: InputBorder.none,
                                      contentPadding: EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 12,
                                      ),
                                      prefixIcon: Icon(Icons.event_available),
                                    ),
                                    onChanged: (value) => activity = value,
                                  ),
                                ),
                                const SizedBox(height: 16),

                                // 시간 설정
                                Container(
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                      color: Colors.black,
                                      width: 2,
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                    color: const Color.fromARGB(
                                      255,
                                      235,
                                      245,
                                      228,
                                    ),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 12,
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        '시간 설정',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: ElevatedButton.icon(
                                              icon: const Icon(
                                                Icons.access_time,
                                              ),
                                              label: Text(
                                                startTimeOfDay != null
                                                    ? '시작: ${startTimeOfDay!.format(context)}'
                                                    : '시작 시간',
                                              ),
                                              onPressed: () async {
                                                final picked = await showTimePicker(
                                                  context: context,
                                                  initialTime:
                                                      startTimeOfDay ??
                                                      TimeOfDay.now(),
                                                  builder: (
                                                    BuildContext context,
                                                    Widget? child,
                                                  ) {
                                                    return Theme(
                                                      data: ThemeData.light().copyWith(
                                                        colorScheme:
                                                            const ColorScheme.light(
                                                              primary:
                                                                  Color.fromARGB(
                                                                    255,
                                                                    162,
                                                                    222,
                                                                    141,
                                                                  ),
                                                            ),
                                                      ),
                                                      child: child!,
                                                    );
                                                  },
                                                );

                                                if (picked != null) {
                                                  setState(() {
                                                    startTimeOfDay = picked;
                                                    // HH:MM 형식으로 변환
                                                    startTime =
                                                        '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
                                                  });
                                                }
                                              },
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor:
                                                    const Color.fromARGB(
                                                      255,
                                                      162,
                                                      222,
                                                      141,
                                                    ),
                                                foregroundColor: Colors.black,
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                  side: const BorderSide(
                                                    color: Colors.black,
                                                    width: 2,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: ElevatedButton.icon(
                                              icon: const Icon(
                                                Icons.access_time,
                                              ),
                                              label: Text(
                                                endTimeOfDay != null
                                                    ? '종료: ${endTimeOfDay!.format(context)}'
                                                    : '종료 시간',
                                              ),
                                              onPressed: () async {
                                                final picked = await showTimePicker(
                                                  context: context,
                                                  initialTime:
                                                      endTimeOfDay ??
                                                      TimeOfDay.now(),
                                                  builder: (
                                                    BuildContext context,
                                                    Widget? child,
                                                  ) {
                                                    return Theme(
                                                      data: ThemeData.light().copyWith(
                                                        colorScheme:
                                                            const ColorScheme.light(
                                                              primary:
                                                                  Color.fromARGB(
                                                                    255,
                                                                    162,
                                                                    222,
                                                                    141,
                                                                  ),
                                                            ),
                                                      ),
                                                      child: child!,
                                                    );
                                                  },
                                                );

                                                if (picked != null) {
                                                  setState(() {
                                                    endTimeOfDay = picked;
                                                    // HH:MM 형식으로 변환
                                                    endTime =
                                                        '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
                                                  });
                                                }
                                              },
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor:
                                                    const Color.fromARGB(
                                                      255,
                                                      162,
                                                      222,
                                                      141,
                                                    ),
                                                foregroundColor: Colors.black,
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                  side: const BorderSide(
                                                    color: Colors.black,
                                                    width: 2,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 16),

                                // 색상 선택
                                Container(
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                      color: Colors.black,
                                      width: 2,
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                    color: const Color.fromARGB(
                                      255,
                                      235,
                                      245,
                                      228,
                                    ),
                                  ),
                                  padding: const EdgeInsets.all(12),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        '색상 선택',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Wrap(
                                        spacing: 10.0,
                                        runSpacing: 10.0,
                                        children:
                                            [
                                              Colors.red,
                                              Colors.pink,
                                              Colors.purple,
                                              Colors.deepPurple,
                                              Colors.indigo,
                                              Colors.blue,
                                              Colors.lightBlue,
                                              Colors.cyan,
                                              Colors.teal,
                                              Colors.green,
                                              Colors.lightGreen,
                                              Colors.lime,
                                              Colors.yellow,
                                              Colors.amber,
                                              Colors.orange,
                                              Colors.deepOrange,
                                              Colors.brown,
                                              Colors.grey,
                                            ].map((color) {
                                              return GestureDetector(
                                                onTap: () {
                                                  setState(() {
                                                    selectedColor = color;
                                                  });
                                                },
                                                child: Container(
                                                  width: 36,
                                                  height: 36,
                                                  decoration: BoxDecoration(
                                                    color: color,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          8,
                                                        ),
                                                    border: Border.all(
                                                      width: 3,
                                                      color:
                                                          selectedColor == color
                                                              ? Colors.black
                                                              : Colors.grey
                                                                  .withOpacity(
                                                                    0.5,
                                                                  ),
                                                    ),
                                                    boxShadow: [
                                                      BoxShadow(
                                                        color: Colors.black
                                                            .withOpacity(0.2),
                                                        spreadRadius: 1,
                                                        blurRadius: 3,
                                                        offset: const Offset(
                                                          0,
                                                          2,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              );
                                            }).toList(),
                                      ),
                                    ],
                                  ),
                                ),

                                const SizedBox(height: 16),

                                // 하단 버튼
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    // 음성 입력 버튼
                                    Expanded(
                                      child: ElevatedButton.icon(
                                        onPressed:
                                            () => _handleTimeSlotVoiceInput(
                                              context,
                                            ),
                                        icon: const Icon(Icons.mic),
                                        label: const Text(
                                          '음성으로 추가',
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.green,
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 12,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                            side: const BorderSide(
                                              color: Colors.black,
                                              width: 2,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),

                                    const SizedBox(width: 8),

                                    // 타임슬롯 추가 버튼
                                    Expanded(
                                      child: ElevatedButton.icon(
                                        onPressed:
                                            activity.isNotEmpty &&
                                                    startTime.isNotEmpty &&
                                                    endTime.isNotEmpty
                                                ? () {
                                                  final timeSlot = TimeSlot(
                                                    activity,
                                                    startTime,
                                                    endTime,
                                                    selectedColor,
                                                    date:
                                                        _controller.selectedDay,
                                                  );

                                                  _controller.addTimeSlot(
                                                    timeSlot,
                                                  );
                                                  Navigator.of(context).pop();

                                                  // 성공 메시지 표시
                                                  ScaffoldMessenger.of(
                                                    context,
                                                  ).showSnackBar(
                                                    SnackBar(
                                                      content: Text(
                                                        '타임슬롯이 추가되었습니다: $activity',
                                                      ),
                                                      backgroundColor:
                                                          Colors.green,
                                                    ),
                                                  );
                                                }
                                                : null,
                                        icon: const Icon(Icons.add),
                                        label: const Text(
                                          '타임슬롯 추가',
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color.fromARGB(
                                            255,
                                            162,
                                            222,
                                            141,
                                          ),
                                          foregroundColor: Colors.black,
                                          disabledBackgroundColor:
                                              Colors.grey[300],
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 16,
                                            vertical: 12,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                            side: const BorderSide(
                                              color: Colors.black,
                                              width: 2,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  /// 음성 입력 처리
  void _handleTimeSlotVoiceInput(BuildContext context) {
    VoiceCommandService.instance.showVoiceInput(
      context: context,
      eventManager: _eventManager, // EventManager 전달
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
