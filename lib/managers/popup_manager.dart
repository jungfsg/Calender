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
    TimeOfDay selectedStartTime = TimeOfDay.now();
    TimeOfDay selectedEndTime = TimeOfDay(
      hour: (selectedStartTime.hour + 1) % 24,
      minute: selectedStartTime.minute,
    );
    int selectedColorId = 1; // 기본 색상: 라벤더

    return showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16.0),
          ),
          elevation: 0,
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16.0),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      '새 일정 추가',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: titleController,
                  decoration: InputDecoration(
                    hintText: '일정 제목',
                    filled: true,
                    fillColor: Colors.grey[100],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    prefixIcon: const Icon(Icons.event_note),
                  ),
                ),
                const SizedBox(height: 20),
                Material(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () {
                      showDialog(
                        context: context,
                        builder: (context) => ColorPickerDialog(
                          initialColorId: selectedColorId,
                          onColorSelected: (colorId) {
                            setState(() {
                              selectedColorId = colorId;
                            });
                          },
                        ),
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: 12.0,
                        horizontal: 16.0,
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.color_lens),
                          const SizedBox(width: 12),
                          const Text('색상 선택'),
                          const Spacer(),
                          Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              color: _getColorByColorId(selectedColorId),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.grey, width: 1),
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Icon(Icons.arrow_forward_ios, size: 16),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: Material(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(12),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () async {
                            final TimeOfDay? picked = await showTimePicker(
                              context: context,
                              initialTime: selectedStartTime,
                              builder: (context, child) {
                                return Theme(
                                  data: Theme.of(context).copyWith(
                                    timePickerTheme: TimePickerThemeData(
                                      backgroundColor: Colors.white,
                                      hourMinuteTextColor: Colors.black,
                                      dayPeriodTextColor: Colors.black,
                                      dayPeriodColor: Colors.grey[200],
                                      dayPeriodShape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                  ),
                                  child: child!,
                                );
                              },
                            );
                            if (picked != null) {
                              setState(() {
                                selectedStartTime = picked;
                                // 시작 시간이 변경되면 종료 시간도 자동으로 1시간 후로 업데이트
                                selectedEndTime = TimeOfDay(
                                  hour: (selectedStartTime.hour + 1) % 24,
                                  minute: selectedStartTime.minute,
                                );
                              });
                            }
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: 12.0,
                              horizontal: 16.0,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  '시작',
                                  style: TextStyle(
                                    color: Colors.grey,
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    const Icon(Icons.access_time, size: 18),
                                    const SizedBox(width: 8),
                                    Text(
                                      '${selectedStartTime.hour.toString().padLeft(2, '0')}:${selectedStartTime.minute.toString().padLeft(2, '0')}',
                                      style: const TextStyle(fontSize: 16),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Material(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(12),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () async {
                            final TimeOfDay? picked = await showTimePicker(
                              context: context,
                              initialTime: selectedEndTime,
                              builder: (context, child) {
                                return Theme(
                                  data: Theme.of(context).copyWith(
                                    timePickerTheme: TimePickerThemeData(
                                      backgroundColor: Colors.white,
                                      hourMinuteTextColor: Colors.black,
                                      dayPeriodTextColor: Colors.black,
                                      dayPeriodColor: Colors.grey[200],
                                      dayPeriodShape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                  ),
                                  child: child!,
                                );
                              },
                            );
                            if (picked != null) {
                              setState(() {
                                selectedEndTime = picked;
                              });
                            }
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: 12.0,
                              horizontal: 16.0,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  '종료',
                                  style: TextStyle(
                                    color: Colors.grey,
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    const Icon(Icons.access_time, size: 18),
                                    const SizedBox(width: 8),
                                    Text(
                                      '${selectedEndTime.hour.toString().padLeft(2, '0')}:${selectedEndTime.minute.toString().padLeft(2, '0')}',
                                      style: const TextStyle(fontSize: 16),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                      child: const Text('취소'),
                    ),
                    const SizedBox(width: 16),
                    ElevatedButton(
                      onPressed: () async {
                        if (titleController.text.isNotEmpty) {
                          final event = Event(
                            title: titleController.text,
                            time:
                                '${selectedStartTime.hour.toString().padLeft(2, '0')}:${selectedStartTime.minute.toString().padLeft(2, '0')}',
                            endTime:
                                '${selectedEndTime.hour.toString().padLeft(2, '0')}:${selectedEndTime.minute.toString().padLeft(2, '0')}',
                            date: _controller.selectedDay,
                            source: 'local',
                          );

                          try {
                            // 색상 ID를 지정하여 이벤트 추가 (Google 동기화 활성화)
                            await _eventManager.addEventWithColorId(
                              event,
                              selectedColorId,
                              syncWithGoogle: true,
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
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _getColorByColorId(selectedColorId),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                      child: const Text('추가'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 이벤트 수정 다이얼로그 표시
  Future<void> showEditEventDialog(BuildContext context, Event event) async {
    final TextEditingController titleController = TextEditingController(
      text: event.title,
    );

    // 시작 시간 파싱
    final timeParts = event.time.split(':');
    TimeOfDay selectedStartTime = TimeOfDay(
      hour: int.parse(timeParts[0]),
      minute: int.parse(timeParts[1]),
    );

    // 종료 시간 파싱
    TimeOfDay selectedEndTime;
    if (event.endTime != null && event.endTime!.isNotEmpty) {
      final endTimeParts = event.endTime!.split(':');
      selectedEndTime = TimeOfDay(
        hour: int.parse(endTimeParts[0]),
        minute: int.parse(endTimeParts[1]),
      );
    } else {
      selectedEndTime = TimeOfDay(
        hour: (selectedStartTime.hour + 1) % 24,
        minute: selectedStartTime.minute,
      );
    }

    int selectedColorId = event.getColorId() ?? 1; // 기본 색상: 라벤더

    return showDialog<void>(
      context: context,
      builder:
          (context) => StatefulBuilder(
            builder:
                (context, setState) => AlertDialog(
                  title: const Text('일정 수정'),
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
                          const Text('시작 시간:'),
                          TextButton(
                            onPressed: () async {
                              final TimeOfDay? picked = await showTimePicker(
                                context: context,
                                initialTime: selectedStartTime,
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
                                  selectedStartTime = picked;
                                  // 시작 시간이 변경되면 종료 시간도 자동으로 1시간 후로 업데이트
                                  selectedEndTime = TimeOfDay(
                                    hour: (selectedStartTime.hour + 1) % 24,
                                    minute: selectedStartTime.minute,
                                  );
                                });
                              }
                            },
                            child: Text(
                              '${selectedStartTime.hour.toString().padLeft(2, '0')}:${selectedStartTime.minute.toString().padLeft(2, '0')}',
                              style: const TextStyle(color: Colors.blue),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('종료 시간:'),
                          TextButton(
                            onPressed: () async {
                              final TimeOfDay? picked = await showTimePicker(
                                context: context,
                                initialTime: selectedEndTime,
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
                                  selectedEndTime = picked;
                                });
                              }
                            },
                            child: Text(
                              '${selectedEndTime.hour.toString().padLeft(2, '0')}:${selectedEndTime.minute.toString().padLeft(2, '0')}',
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
                          final updatedEvent = event.copyWith(
                            title: titleController.text,
                            time:
                                '${selectedStartTime.hour.toString().padLeft(2, '0')}:${selectedStartTime.minute.toString().padLeft(2, '0')}',
                            endTime:
                                '${selectedEndTime.hour.toString().padLeft(2, '0')}:${selectedEndTime.minute.toString().padLeft(2, '0')}',
                            colorId: selectedColorId.toString(),
                          );

                          try {
                            await _eventManager.updateEvent(
                              event,
                              updatedEvent,
                              syncWithGoogle: true,
                            );
                            Navigator.pop(context);

                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  '일정이 수정되었습니다: ${titleController.text}',
                                ),
                                backgroundColor: Colors.green,
                              ),
                            );
                          } catch (e) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('일정 수정 실패: $e'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        }
                      },
                      child: const Text('수정'),
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
