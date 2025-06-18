import 'package:http/http.dart';

import '../models/event.dart';
import '../controllers/calendar_controller.dart';
import '../managers/event_manager.dart';
import '../widgets/color_picker_dialog.dart';
import '../enums/recurrence_type.dart';
import 'package:flutter/material.dart';
import '../utils/font_utils.dart';

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

  /// 이벤트 추가 다이얼로그 표시
  Future<void> showAddEventDialog(BuildContext context) async {
    final TextEditingController titleController = TextEditingController();
    TimeOfDay selectedStartTime = TimeOfDay.now();
    TimeOfDay selectedEndTime = TimeOfDay(
      hour: (selectedStartTime.hour + 1) % 24,
      minute: selectedStartTime.minute,
    );
    int selectedColorId = 1; // 기본 색상: 라벤더
    RecurrenceType selectedRecurrence = RecurrenceType.none; // 기본 반복: 없음
    int recurrenceCount = 1; // 기본 반복 횟수

    return showDialog<void>(
      context: context,
      builder:
          (context) => StatefulBuilder(
            builder:
                (context, setState) => Dialog(
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
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.of(context).size.height * 0.8,
                      maxWidth: MediaQuery.of(context).size.width * 0.9,
                    ),
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '새 일정 추가',
                                style: getTextStyle(fontSize: 20),
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
                              // 에러 메시지 표시를 위한 헬퍼 텍스트 추가
                              helperText: ' ', // 공간 확보
                            ),
                            // 자동 포커스 추가
                            autofocus: true,
                            // 엔터키 입력 시 다음 단계로 이동
                            textInputAction: TextInputAction.next,
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
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12.0,
                                  horizontal: 16.0,
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.color_lens),
                                    const SizedBox(width: 12),
                                    Text(
                                      '색상 선택',
                                      style: getTextStyle(fontSize: 12),
                                    ),
                                    const Spacer(),
                                    Container(
                                      width: 24,
                                      height: 24,
                                      decoration: BoxDecoration(
                                        color: _getColorByColorId(
                                          selectedColorId,
                                        ),
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: Colors.grey,
                                          width: 1,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    const Icon(
                                      Icons.arrow_forward_ios,
                                      size: 16,
                                    ),
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
                                      final TimeOfDay?
                                      picked = await showTimePicker(
                                        context: context,
                                        initialTime: selectedStartTime,
                                        builder: (context, child) {
                                          return Theme(
                                            data: Theme.of(context).copyWith(
                                              timePickerTheme: TimePickerThemeData(
                                                backgroundColor: Colors.white,
                                                hourMinuteTextColor:
                                                    Colors.black,
                                                dayPeriodTextColor:
                                                    Colors.black,
                                                dayPeriodColor:
                                                    Colors.grey[200],
                                                dayPeriodShape:
                                                    RoundedRectangleBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
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
                                            hour:
                                                (selectedStartTime.hour + 1) %
                                                24,
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
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            '시작',
                                            style: getTextStyle(
                                              color: Colors.grey,
                                              fontSize: 12,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Row(
                                            children: [
                                              const Icon(
                                                Icons.access_time,
                                                size: 18,
                                              ),
                                              const SizedBox(width: 8),
                                              Text(
                                                '${selectedStartTime.hour.toString().padLeft(2, '0')}:${selectedStartTime.minute.toString().padLeft(2, '0')}',
                                                style: getTextStyle(
                                                  fontSize: 16,
                                                  color: Colors.black87,
                                                ),
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
                                      final TimeOfDay?
                                      picked = await showTimePicker(
                                        context: context,
                                        initialTime: selectedEndTime,
                                        builder: (context, child) {
                                          return Theme(
                                            data: Theme.of(context).copyWith(
                                              timePickerTheme: TimePickerThemeData(
                                                backgroundColor: Colors.white,
                                                hourMinuteTextColor:
                                                    Colors.black,
                                                dayPeriodTextColor:
                                                    Colors.black,
                                                dayPeriodColor:
                                                    Colors.grey[200],
                                                dayPeriodShape:
                                                    RoundedRectangleBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
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
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 12.0,
                                        horizontal: 16.0,
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            '종료',
                                            style: getTextStyle(
                                              color: Colors.grey,
                                              fontSize: 12,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Row(
                                            children: [
                                              const Icon(
                                                Icons.access_time,
                                                size: 18,
                                              ),
                                              const SizedBox(width: 8),
                                              Text(
                                                '${selectedEndTime.hour.toString().padLeft(2, '0')}:${selectedEndTime.minute.toString().padLeft(2, '0')}',
                                                style: getTextStyle(
                                                  fontSize: 16,
                                                  color: Colors.black87,
                                                ),
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
                          const SizedBox(height: 20),
                          // 반복 옵션 섹션: 새 일정 추가
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('반복 설정', style: getTextStyle(fontSize: 16)),
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 8.0,
                                runSpacing: 8.0,
                                children:
                                    RecurrenceType.values.map((recurrence) {
                                      final isSelected =
                                          selectedRecurrence == recurrence;
                                      return FilterChip(
                                        label: Text(
                                          recurrence.label,
                                          style: getTextStyle(
                                            fontSize:
                                                12, // 매일, 매주 등 설정 버튼의 텍스트 크기
                                            color: Colors.black87,
                                          ),
                                        ),
                                        selected: isSelected,
                                        onSelected: (bool selected) {
                                          setState(() {
                                            selectedRecurrence =
                                                selected
                                                    ? recurrence
                                                    : RecurrenceType.none;
                                            // 반복 타입이 변경되면 해당 타입의 기본 반복 횟수로 설정
                                            if (selected &&
                                                recurrence !=
                                                    RecurrenceType.none) {
                                              recurrenceCount =
                                                  recurrence.defaultCount;
                                            } else if (!selected) {
                                              recurrenceCount = 1;
                                            }
                                          });
                                        },
                                        backgroundColor: Colors.grey[100],
                                        selectedColor: _getColorByColorId(
                                          selectedColorId,
                                        ),
                                        checkmarkColor: Colors.white,
                                        elevation: isSelected ? 2 : 0,
                                        shadowColor: _getColorByColorId(
                                          selectedColorId,
                                        ).withOpacity(0.3),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            20,
                                          ),
                                          side: BorderSide(
                                            color:
                                                isSelected
                                                    ? _getColorByColorId(
                                                      selectedColorId,
                                                    )
                                                    : Colors.grey[300]!,
                                            width: 1,
                                          ),
                                        ),
                                      );
                                    }).toList(),
                              ),
                              // 반복 횟수 선택 (반복이 선택된 경우에만 표시)
                              if (selectedRecurrence !=
                                  RecurrenceType.none) ...[
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Text(
                                      '반복 횟수:',
                                      style: getTextStyle(fontSize: 14),
                                    ),
                                    const SizedBox(width: 12),
                                    Container(
                                      width: 150, // 80에서 100으로 증가
                                      height: 40,
                                      decoration: BoxDecoration(
                                        border: Border.all(
                                          color: Colors.grey[300]!,
                                        ),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Row(
                                        children: [
                                          IconButton(
                                            icon: const Icon(
                                              Icons.remove,
                                              size: 14,
                                            ), // 16에서 14로 감소
                                            onPressed: () {
                                              setState(() {
                                                if (recurrenceCount > 1) {
                                                  recurrenceCount--;
                                                }
                                              });
                                            },
                                            padding: EdgeInsets.zero,
                                            constraints: const BoxConstraints(
                                              minWidth: 20, // 24에서 20으로 감소
                                              minHeight: 20, // 24에서 20으로 감소
                                            ),
                                          ),
                                          Expanded(
                                            child: Text(
                                              '$recurrenceCount',
                                              textAlign: TextAlign.center,
                                              style: getTextStyle(
                                                fontSize: 14,
                                                color: Colors.black87,
                                              ),
                                            ),
                                          ),
                                          IconButton(
                                            icon: const Icon(
                                              Icons.add,
                                              size: 14,
                                            ), // 16에서 14로 감소
                                            onPressed: () {
                                              setState(() {
                                                if (recurrenceCount < 50) {
                                                  // 최대 50회로 제한
                                                  recurrenceCount++;
                                                }
                                              });
                                            },
                                            padding: EdgeInsets.zero,
                                            constraints: const BoxConstraints(
                                              minWidth: 20, // 24에서 20으로 감소
                                              minHeight: 20, // 24에서 20으로 감소
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      _getRecurrenceDescription(
                                        selectedRecurrence,
                                      ),
                                      style: getTextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
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
                                child: Text(
                                  '취소',
                                  style: getTextStyle(fontSize: 12),
                                ),
                              ),
                              const SizedBox(width: 16),
                              ElevatedButton(
                                onPressed: () async {
                                  // 개선: 입력 검증 추가
                                  if (titleController.text.trim().isEmpty) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('일정 제목을 입력해주세요.'),
                                        backgroundColor: Colors.orange,
                                      ),
                                    );
                                    return;
                                  } // 개선: 시간 유효성 검사
                                  // 24시간 기준으로 비교하여 다음날로 넘어가는 경우도 허용
                                  final startTotalMinutes =
                                      selectedStartTime.hour * 60 +
                                      selectedStartTime.minute;
                                  final endTotalMinutes =
                                      selectedEndTime.hour * 60 +
                                      selectedEndTime.minute;

                                  // 시작 시간과 종료 시간이 같은 경우에만 오류
                                  if (startTotalMinutes == endTotalMinutes) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          '종료 시간은 시작 시간보다 늦어야 합니다.',
                                        ),
                                        backgroundColor: Colors.orange,
                                      ),
                                    );
                                    return;
                                  }

                                  // 시간 변환
                                  final startTimeStr =
                                      '${selectedStartTime.hour.toString().padLeft(2, '0')}:${selectedStartTime.minute.toString().padLeft(2, '0')}';
                                  final endTimeStr =
                                      '${selectedEndTime.hour.toString().padLeft(2, '0')}:${selectedEndTime.minute.toString().padLeft(2, '0')}';

                                  // 시작 시간이 종료 시간보다 큰 경우 (예: 23:00 시작, 01:00 종료)
                                  // 다음 날을 가리키는 이벤트로 처리
                                  final Event event;

                                  if (startTotalMinutes > endTotalMinutes) {
                                    // 날짜가 넘어가는 경우 - 멀티데이 이벤트로 처리
                                    final today = _controller.selectedDay;
                                    final tomorrow = today.add(
                                      const Duration(days: 1),
                                    );

                                    event = Event(
                                      title: titleController.text.trim(),
                                      time: startTimeStr,
                                      endTime: endTimeStr,
                                      date: today,
                                      isMultiDay: true,
                                      startDate: today,
                                      endDate: tomorrow,
                                      source: 'local',
                                      recurrence: selectedRecurrence,
                                      recurrenceCount: recurrenceCount,
                                    );
                                  } else {
                                    // 일반적인 경우 - 기존과 동일한 방식
                                    event = Event(
                                      title: titleController.text.trim(),
                                      time: startTimeStr,
                                      endTime: endTimeStr,
                                      date: _controller.selectedDay,
                                      source: 'local',
                                      recurrence: selectedRecurrence,
                                      recurrenceCount: recurrenceCount,
                                    );
                                  }

                                  try {
                                    // 반복 옵션이 있는 경우 반복 이벤트들을 생성
                                    if (selectedRecurrence !=
                                        RecurrenceType.none) {
                                      await _createRecurringEvents(
                                        event,
                                        selectedColorId,
                                        selectedRecurrence,
                                        recurrenceCount,
                                      );
                                      Navigator.pop(context);

                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            '${selectedRecurrence.label} 반복 일정이 추가되었습니다: ${titleController.text.trim()}',
                                          ),
                                          backgroundColor: Colors.green,
                                        ),
                                      );
                                    } else {
                                      // 단일 이벤트 추가
                                      await _eventManager.addEventWithColorId(
                                        event,
                                        selectedColorId,
                                        syncWithGoogle: true,
                                      );
                                      Navigator.pop(context);

                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            '새 일정이 추가되었습니다: ${titleController.text.trim()}',
                                          ),
                                          backgroundColor: Colors.green,
                                        ),
                                      );
                                    }
                                  } catch (e) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('일정 추가 실패: $e'),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                  }
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _getColorByColorId(
                                    selectedColorId,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 12,
                                  ),
                                ),
                                child: Text(
                                  '추가',
                                  style: getTextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
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
    RecurrenceType selectedRecurrence = event.recurrence; // 현재 반복 타입
    int recurrenceCount = event.recurrenceCount; // 현재 반복 횟수

    return showDialog<void>(
      context: context,
      builder:
          (context) => StatefulBuilder(
            builder:
                (context, setState) => Dialog(
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
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.of(context).size.height * 0.8,
                      maxWidth: MediaQuery.of(context).size.width * 0.9,
                    ),
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('일정 수정', style: getTextStyle(fontSize: 20)),
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
                              helperText: ' ',
                            ),
                            autofocus: true,
                            textInputAction: TextInputAction.next,
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
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12.0,
                                  horizontal: 16.0,
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.color_lens),
                                    const SizedBox(width: 12),
                                    Text(
                                      '색상 선택',
                                      style: getTextStyle(fontSize: 12),
                                    ),
                                    const Spacer(),
                                    Container(
                                      width: 24,
                                      height: 24,
                                      decoration: BoxDecoration(
                                        color: _getColorByColorId(
                                          selectedColorId,
                                        ),
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: Colors.grey,
                                          width: 1,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    const Icon(
                                      Icons.arrow_forward_ios,
                                      size: 16,
                                    ),
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
                                      final TimeOfDay?
                                      picked = await showTimePicker(
                                        context: context,
                                        initialTime: selectedStartTime,
                                        builder: (context, child) {
                                          return Theme(
                                            data: Theme.of(context).copyWith(
                                              timePickerTheme: TimePickerThemeData(
                                                backgroundColor: Colors.white,
                                                hourMinuteTextColor:
                                                    Colors.black,
                                                dayPeriodTextColor:
                                                    Colors.black,
                                                dayPeriodColor:
                                                    Colors.grey[200],
                                                dayPeriodShape:
                                                    RoundedRectangleBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
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
                                            hour:
                                                (selectedStartTime.hour + 1) %
                                                24,
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
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            '시작',
                                            style: getTextStyle(
                                              color: Colors.grey,
                                              fontSize: 10,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Row(
                                            children: [
                                              const Icon(
                                                Icons.access_time,
                                                size: 18,
                                              ),
                                              const SizedBox(width: 8),
                                              Text(
                                                '${selectedStartTime.hour.toString().padLeft(2, '0')}:${selectedStartTime.minute.toString().padLeft(2, '0')}',
                                                style: getTextStyle(
                                                  fontSize: 16,
                                                  color: Colors.black87,
                                                ),
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
                                      final TimeOfDay?
                                      picked = await showTimePicker(
                                        context: context,
                                        initialTime: selectedEndTime,
                                        builder: (context, child) {
                                          return Theme(
                                            data: Theme.of(context).copyWith(
                                              timePickerTheme: TimePickerThemeData(
                                                backgroundColor: Colors.white,
                                                hourMinuteTextColor:
                                                    Colors.black,
                                                dayPeriodTextColor:
                                                    Colors.black,
                                                dayPeriodColor:
                                                    Colors.grey[200],
                                                dayPeriodShape:
                                                    RoundedRectangleBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
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
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 12.0,
                                        horizontal: 16.0,
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            '종료',
                                            style: getTextStyle(
                                              color: Colors.grey,
                                              fontSize: 12,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Row(
                                            children: [
                                              const Icon(
                                                Icons.access_time,
                                                size: 18,
                                              ),
                                              const SizedBox(width: 8),
                                              Text(
                                                '${selectedEndTime.hour.toString().padLeft(2, '0')}:${selectedEndTime.minute.toString().padLeft(2, '0')}',
                                                style: getTextStyle(
                                                  fontSize: 16,
                                                  color: Colors.black87,
                                                ),
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
                          const SizedBox(height: 20),
                          // 반복 옵션 섹션: 일정 수정
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('반복 설정', style: getTextStyle(fontSize: 16)),
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 8.0,
                                runSpacing: 8.0,
                                children:
                                    RecurrenceType.values.map((recurrence) {
                                      final isSelected =
                                          selectedRecurrence == recurrence;
                                      return FilterChip(
                                        label: Text(
                                          recurrence.label,
                                          style: getTextStyle(
                                            fontSize: 12,
                                            color: Colors.black87,
                                          ),
                                        ),
                                        selected: isSelected,
                                        onSelected: (bool selected) {
                                          setState(() {
                                            selectedRecurrence =
                                                selected
                                                    ? recurrence
                                                    : RecurrenceType.none;
                                            // 반복 타입이 변경되면 해당 타입의 기본 반복 횟수로 설정
                                            if (selected &&
                                                recurrence !=
                                                    RecurrenceType.none) {
                                              recurrenceCount =
                                                  recurrence.defaultCount;
                                            } else if (!selected) {
                                              recurrenceCount = 1;
                                            }
                                          });
                                        },
                                        backgroundColor: Colors.grey[100],
                                        selectedColor: _getColorByColorId(
                                          selectedColorId,
                                        ),
                                        checkmarkColor: Colors.white,
                                        elevation: isSelected ? 2 : 0,
                                        shadowColor: _getColorByColorId(
                                          selectedColorId,
                                        ).withOpacity(0.3),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            20,
                                          ),
                                          side: BorderSide(
                                            color:
                                                isSelected
                                                    ? _getColorByColorId(
                                                      selectedColorId,
                                                    )
                                                    : Colors.grey[300]!,
                                            width: 1,
                                          ),
                                        ),
                                      );
                                    }).toList(),
                              ),
                              // 반복 횟수 선택 (반복이 선택된 경우에만 표시)
                              if (selectedRecurrence !=
                                  RecurrenceType.none) ...[
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Text(
                                      '반복 횟수:',
                                      style: getTextStyle(fontSize: 14),
                                    ),
                                    const SizedBox(width: 12),
                                    Container(
                                      width: 150,
                                      height: 40,
                                      decoration: BoxDecoration(
                                        border: Border.all(
                                          color: Colors.grey[300]!,
                                        ),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Row(
                                        children: [
                                          IconButton(
                                            icon: const Icon(
                                              Icons.remove,
                                              size: 14,
                                            ),
                                            onPressed: () {
                                              setState(() {
                                                if (recurrenceCount > 1) {
                                                  recurrenceCount--;
                                                }
                                              });
                                            },
                                            padding: EdgeInsets.zero,
                                            constraints: const BoxConstraints(
                                              minWidth: 20,
                                              minHeight: 20,
                                            ),
                                          ),
                                          Expanded(
                                            child: Text(
                                              '$recurrenceCount',
                                              textAlign: TextAlign.center,
                                              style: getTextStyle(
                                                fontSize: 14,
                                                color: Colors.black87,
                                              ),
                                            ),
                                          ),
                                          IconButton(
                                            icon: const Icon(
                                              Icons.add,
                                              size: 14,
                                            ),
                                            onPressed: () {
                                              setState(() {
                                                if (recurrenceCount < 50) {
                                                  recurrenceCount++;
                                                }
                                              });
                                            },
                                            padding: EdgeInsets.zero,
                                            constraints: const BoxConstraints(
                                              minWidth: 20,
                                              minHeight: 20,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      _getRecurrenceDescription(
                                        selectedRecurrence,
                                      ),
                                      style: getTextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
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
                                child: Text(
                                  '취소',
                                  style: getTextStyle(fontSize: 12),
                                ),
                              ),
                              const SizedBox(width: 16),
                              ElevatedButton(
                                onPressed: () async {
                                  // 입력 검증 추가
                                  if (titleController.text.trim().isEmpty) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('일정 제목을 입력해주세요.'),
                                        backgroundColor: Colors.orange,
                                      ),
                                    );
                                    return;
                                  }

                                  // 시간 유효성 검사
                                  final startTotalMinutes =
                                      selectedStartTime.hour * 60 +
                                      selectedStartTime.minute;
                                  final endTotalMinutes =
                                      selectedEndTime.hour * 60 +
                                      selectedEndTime.minute;

                                  // 시작 시간과 종료 시간이 같은 경우에만 오류
                                  if (startTotalMinutes == endTotalMinutes) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          '종료 시간은 시작 시간보다 늦어야 합니다.',
                                        ),
                                        backgroundColor: Colors.orange,
                                      ),
                                    );
                                    return;
                                  }

                                  // 시간 변환
                                  final startTimeStr =
                                      '${selectedStartTime.hour.toString().padLeft(2, '0')}:${selectedStartTime.minute.toString().padLeft(2, '0')}';
                                  final endTimeStr =
                                      '${selectedEndTime.hour.toString().padLeft(2, '0')}:${selectedEndTime.minute.toString().padLeft(2, '0')}';

                                  // 다음 날을 넘어가는 경우 처리
                                  final Event updatedEvent;

                                  if (startTotalMinutes > endTotalMinutes) {
                                    // 날짜가 넘어가는 경우 - 멀티데이 이벤트로 처리
                                    final today = event.date;
                                    final tomorrow = today.add(
                                      const Duration(days: 1),
                                    );

                                    updatedEvent = event.copyWith(
                                      title: titleController.text.trim(),
                                      time: startTimeStr,
                                      endTime: endTimeStr,
                                      isMultiDay: true,
                                      startDate: today,
                                      endDate: tomorrow,
                                      colorId: selectedColorId.toString(),
                                      recurrence: selectedRecurrence,
                                      recurrenceCount: recurrenceCount,
                                    );
                                  } else {
                                    // 일반적인 경우
                                    updatedEvent = event.copyWith(
                                      title: titleController.text.trim(),
                                      time: startTimeStr,
                                      endTime: endTimeStr,
                                      isMultiDay: false, // 명시적으로 설정
                                      startDate: null, // 멀티데이 속성 제거
                                      endDate: null, // 멀티데이 속성 제거
                                      colorId: selectedColorId.toString(),
                                      recurrence: selectedRecurrence,
                                      recurrenceCount: recurrenceCount,
                                    );
                                  }

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
                                          '일정이 수정되었습니다: ${titleController.text.trim()}',
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
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _getColorByColorId(
                                    selectedColorId,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 12,
                                  ),
                                ),
                                child: Text(
                                  '수정',
                                  style: getTextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
          ),
    );
  }

  /// 이벤트 삭제 확인 다이얼로그 표시
  Future<bool?> showDeleteEventDialog(BuildContext context, Event event) async {
    return showDialog<bool>(
      context: context,
      builder:
          (context) => Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16.0),
            ),
            elevation: 0,
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16.0),
              ),
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.85,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.delete_outline,
                          color: Colors.red,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        '일정 삭제',
                        style: getTextStyle(
                          fontSize: 20,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey[200]!, width: 1),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                color: _getColorByColorId(
                                  event.getColorId() ?? 1,
                                ),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                event.title,
                                style: getTextStyle(
                                  fontSize: 16,
                                  color: Colors.black87,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(
                              Icons.access_time,
                              size: 16,
                              color: Colors.grey,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${event.time}${event.endTime != null ? ' - ${event.endTime}' : ''}',
                              style: getTextStyle(
                                fontSize: 14,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(
                              Icons.calendar_today,
                              size: 16,
                              color: Colors.grey,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${event.date.year}년 ${event.date.month}월 ${event.date.day}일',
                              style: getTextStyle(
                                fontSize: 14,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    '이 일정을 삭제하시겠습니까?',
                    style: getTextStyle(fontSize: 16, color: Colors.black87),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '삭제된 일정은 복구할 수 없습니다.',
                    style: getTextStyle(fontSize: 14, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      OutlinedButton(
                        onPressed: () => Navigator.pop(context, false),
                        style: OutlinedButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                        ),
                        child: Text('취소', style: getTextStyle(fontSize: 12)),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(context, true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.delete, size: 16),
                            const SizedBox(width: 4),
                            Text('삭제', style: getTextStyle(fontSize: 12)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
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

  /// 반복 이벤트들을 생성하는 헬퍼 메서드
  Future<void> _createRecurringEvents(
    Event baseEvent,
    int colorId,
    RecurrenceType recurrence,
    int recurrenceCount,
  ) async {
    List<Event> eventsToAdd = [];
    DateTime currentDate = baseEvent.date;

    // 사용자가 지정한 반복 횟수 사용
    for (int i = 0; i < recurrenceCount; i++) {
      if (i > 0) {
        currentDate = _getNextOccurrence(currentDate, recurrence);
      }

      final recurringEvent = baseEvent.copyWith(
        date: currentDate,
        recurrence:
            i == 0 ? recurrence : RecurrenceType.none, // 첫 번째 이벤트만 원본 반복 타입 유지
        recurrenceCount: recurrenceCount, // 반복 횟수 정보 저장
      );

      eventsToAdd.add(recurringEvent);
    }

    // 모든 반복 이벤트를 추가
    for (final event in eventsToAdd) {
      try {
        await _eventManager.addEventWithColorId(
          event,
          colorId,
          syncWithGoogle: true,
        );
      } catch (e) {
        print('반복 이벤트 추가 실패: ${event.date} - $e');
        // 하나가 실패해도 계속 진행
      }
    }
  }

  /// 다음 반복 일자 계산
  DateTime _getNextOccurrence(DateTime current, RecurrenceType recurrence) {
    switch (recurrence) {
      case RecurrenceType.daily:
        return current.add(const Duration(days: 1));
      case RecurrenceType.weekly:
        return current.add(const Duration(days: 7));
      case RecurrenceType.monthly:
        return DateTime(
          current.month == 12 ? current.year + 1 : current.year,
          current.month == 12 ? 1 : current.month + 1,
          current.day,
          current.hour,
          current.minute,
          current.second,
          current.millisecond,
          current.microsecond,
        );
      case RecurrenceType.yearly:
        return DateTime(
          current.year + 1,
          current.month,
          current.day,
          current.hour,
          current.minute,
          current.second,
          current.millisecond,
          current.microsecond,
        );
      case RecurrenceType.none:
        return current;
    }
  }

  /// 반복 유형에 대한 설명 반환
  String _getRecurrenceDescription(RecurrenceType recurrence) {
    switch (recurrence) {
      case RecurrenceType.daily:
        return '매일';
      case RecurrenceType.weekly:
        return '매주';
      case RecurrenceType.monthly:
        return '매월';
      case RecurrenceType.yearly:
        return '매년';
      case RecurrenceType.none:
        return '반복 없음';
    }
  }
}
