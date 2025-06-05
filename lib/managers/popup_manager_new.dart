import '../models/event.dart';
import '../models/time_slot.dart';
import '../controllers/calendar_controller.dart';
import '../managers/event_manager.dart';
import '../widgets/color_picker_dialog.dart';
import 'package:flutter/material.dart';

/// 팝업 관련 로직을 처리하는 매니저 클래스
class PopupManager {
  final CalendarController _controller;
  final EventManager _eventManager;

  PopupManager(this._controller, this._eventManager);

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

  /// 이벤트 추가 다이얼로그 표시 (색상 선택 기능 포함)
  Future<void> showAddEventDialog(BuildContext context) async {
    final TextEditingController titleController = TextEditingController();
    TimeOfDay selectedTime = TimeOfDay.now();
    int selectedColorId = 1; // 기본 색상: 라벤더

    return showDialog<void>(
      context: context,
      builder:
          (context) => StatefulBuilder(
            builder:
                (context, setState) => AlertDialog(
                  title: const Text('새 일정 추가'),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: titleController,
                        decoration: const InputDecoration(hintText: '일정 제목'),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('색상 선택:'),
                          Row(
                            children: [
                              Container(
                                width: 24,
                                height: 24,
                                decoration: BoxDecoration(
                                  color: _getColorByColorId(selectedColorId),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.grey,
                                    width: 1,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              TextButton(
                                onPressed: () {
                                  showDialog(
                                    context: context,
                                    builder:
                                        (context) => ColorPickerDialog(
                                          initialColorId: selectedColorId,
                                          onColorSelected: (colorId) {
                                            setState(() {
                                              selectedColorId = colorId;
                                            });
                                          },
                                        ),
                                  );
                                },
                                child: const Text('변경'),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('시간 선택:'),
                          TextButton(
                            onPressed: () async {
                              final TimeOfDay? picked = await showTimePicker(
                                context: context,
                                initialTime: selectedTime,
                                builder: (context, child) {
                                  return Theme(
                                    data: Theme.of(context).copyWith(
                                      timePickerTheme: TimePickerThemeData(
                                        backgroundColor: Colors.white,
                                        hourMinuteTextColor: Colors.black,
                                        dayPeriodTextColor: Colors.black,
                                        dayPeriodColor: Colors.grey[200],
                                        dayPeriodShape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                      ),
                                    ),
                                    child: child!,
                                  );
                                },
                              );
                              if (picked != null) {
                                setState(() {
                                  selectedTime = picked;
                                });
                              }
                            },
                            child: Text(
                              '${selectedTime.hour.toString().padLeft(2, '0')}:${selectedTime.minute.toString().padLeft(2, '0')}',
                              style: const TextStyle(color: Colors.blue),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('취소'),
                    ),
                    TextButton(
                      onPressed: () async {
                        if (titleController.text.isNotEmpty) {
                          final event = Event(
                            title: titleController.text,
                            time:
                                '${selectedTime.hour.toString().padLeft(2, '0')}:${selectedTime.minute.toString().padLeft(2, '0')}',
                            date: _controller.selectedDay,
                            source: 'local',
                          );

                          try {
                            // 색상 ID를 지정하여 이벤트 추가
                            await _eventManager.addEventWithColorId(
                              event,
                              selectedColorId,
                            );
                            Navigator.pop(context);

                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  '새 일정이 추가되었습니다: ${titleController.text}',
                                ),
                                backgroundColor: Colors.green,
                              ),
                            );
                          } catch (e) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('일정 추가 실패: $e'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        }
                      },
                      child: const Text('추가'),
                    ),
                  ],
                ),
          ),
    );
  }

  // colorId로 색상 가져오기 (Google Calendar 표준 색상)
  Color _getColorByColorId(int colorId) {
    const Map<int, Color> googleColors = {
      1: Color(0xFF9AA0F5), // 라벤더
      2: Color(0xFF33B679), // 세이지
      3: Color(0xFF8E24AA), // 포도
      4: Color(0xFFE67C73), // 플라밍고
      5: Color(0xFFF6BF26), // 바나나
      6: Color(0xFFFF8A65), // 귤
      7: Color(0xFF039BE5), // 공작새
      8: Color(0xFF616161), // 그래파이트
      9: Color(0xFF3F51B5), // 블루베리
      10: Color(0xFF0B8043), // 바질
      11: Color(0xFFD50000), // 토마토
    };
    return googleColors[colorId] ?? googleColors[1]!;
  }

  /// 타임슬롯 추가 다이얼로그 표시 (간단한 스타일)
  Future<void> showAddTimeSlotDialog(BuildContext context) async {
    final TextEditingController titleController = TextEditingController();
    final TextEditingController startTimeController = TextEditingController();
    final TextEditingController endTimeController = TextEditingController();

    return showDialog<void>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('새 일정 추가'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(hintText: '일정 제목'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: startTimeController,
                  decoration: const InputDecoration(hintText: '시작 시간 (HH:MM)'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: endTimeController,
                  decoration: const InputDecoration(hintText: '종료 시간 (HH:MM)'),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('취소'),
              ),
              TextButton(
                onPressed: () async {
                  if (titleController.text.isNotEmpty &&
                      startTimeController.text.isNotEmpty &&
                      endTimeController.text.isNotEmpty) {
                    final timeSlot = TimeSlot(
                      titleController.text,
                      startTimeController.text,
                      endTimeController.text,
                      Colors.blue,
                      date: _controller.selectedDay,
                    );

                    try {
                      _controller.addTimeSlot(timeSlot);
                      Navigator.pop(context);

                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            '새 일정이 추가되었습니다: ${titleController.text}',
                          ),
                          backgroundColor: Colors.green,
                        ),
                      );
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('일정 추가 실패: $e'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                },
                child: const Text('추가'),
              ),
            ],
          ),
    );
  }
}
