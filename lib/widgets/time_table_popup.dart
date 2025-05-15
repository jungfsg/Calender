import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/time_slot.dart';
import '../utils/font_utils.dart';

class TimeTablePopup extends StatelessWidget {
  final DateTime selectedDay;
  final List<TimeSlot> timeSlots;
  final VoidCallback onClose;
  final VoidCallback onAddTimeSlot;

  const TimeTablePopup({
    Key? key,
    required this.selectedDay,
    required this.timeSlots,
    required this.onClose,
    required this.onAddTimeSlot,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withOpacity(0.5),
      width: double.infinity,
      height: double.infinity,
      child: Center(
        child: Container(
          width: 300,
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: Colors.black, width: 4),
          ),
          padding: const EdgeInsets.all(8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 팝업 헤더와 닫기 버튼
              Container(
                width: double.infinity,
                color: Colors.black,
                padding: const EdgeInsets.symmetric(
                  vertical: 8,
                  horizontal: 12,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${DateFormat('yyyy.MM.dd').format(selectedDay)}의 시간표',
                      style: getTextStyle(
                        fontSize: 8,
                        color: Colors.white,
                        text:
                            '${DateFormat('yyyy.MM.dd').format(selectedDay)}의 시간표',
                      ),
                    ),
                    Row(
                      children: [
                        GestureDetector(
                          onTap: onAddTimeSlot,
                          child: Container(
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(
                              color: Colors.green,
                              border: Border.all(color: Colors.white, width: 1),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              '+',
                              style: getTextStyle(
                                fontSize: 8,
                                color: Colors.white,
                                text: '+',
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: onClose,
                          child: Container(
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(
                              color: Colors.red,
                              border: Border.all(color: Colors.white, width: 1),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              'X',
                              style: getTextStyle(
                                fontSize: 8,
                                color: Colors.white,
                                text: 'X',
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              // 타임테이블 목록
              Container(
                constraints: const BoxConstraints(maxHeight: 300),
                child:
                    timeSlots.isEmpty
                        ? Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Center(
                            child: Text(
                              '일정이 없습니다',
                              style: getTextStyle(
                                fontSize: 10,
                                color: Colors.grey,
                                text: '일정이 없습니다',
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        )
                        : ListView.builder(
                          shrinkWrap: true,
                          itemCount: timeSlots.length,
                          itemBuilder: (context, index) {
                            final slot = timeSlots[index];
                            return Container(
                              margin: const EdgeInsets.symmetric(vertical: 4),
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: slot.color.withOpacity(0.2),
                                border: Border.all(color: slot.color, width: 2),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 5,
                                    height: 30,
                                    color: slot.color,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          slot.title,
                                          style: getTextStyle(
                                            fontSize: 10,
                                            color: Colors.black,
                                            text: slot.title,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '${slot.startTime} - ${slot.endTime}',
                                          style: getTextStyle(
                                            fontSize: 8,
                                            color: Colors.grey[800]!,
                                            text:
                                                '${slot.startTime} - ${slot.endTime}',
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
