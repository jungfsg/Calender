import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../utils/font_utils.dart';

class EventPopup extends StatelessWidget {
  final DateTime selectedDay;
  final List<String> events;
  final Map<String, Color> eventColors;
  final VoidCallback onClose;
  final VoidCallback onAddEvent;

  const EventPopup({
    Key? key,
    required this.selectedDay,
    required this.events,
    required this.eventColors,
    required this.onClose,
    required this.onAddEvent,
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
                      '${DateFormat('yyyy.MM.dd').format(selectedDay)}의 이벤트',
                      style: getCustomTextStyle(
                        fontSize: 8,
                        color: Colors.white,
                        text:
                            '${DateFormat('yyyy.MM.dd').format(selectedDay)}의 이벤트',
                      ),
                    ),
                    Row(
                      children: [
                        GestureDetector(
                          onTap: onAddEvent,
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
                              style: getCustomTextStyle(
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
                              style: getCustomTextStyle(
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
              // 이벤트 목록
              Container(
                width: 700,
                constraints: const BoxConstraints(
                  maxHeight: 300,
                  maxWidth: 700,
                ),
                child:
                    events.isEmpty
                        ? Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Image.asset(
                                  'assets/images/balloon (1).gif',
                                  width: 150,
                                  height: 150,
                                ),
                                const SizedBox(height: 24),
                                Text(
                                  '할 일이 없어. 아직은..',
                                  style: getCustomTextStyle(
                                    fontSize: 10,
                                    color: Colors.grey,
                                    text: '할 일이 없어. 아직은..',
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        )
                        : ListView.builder(
                          shrinkWrap: true,
                          itemCount: events.length,
                          itemBuilder: (context, index) {
                            final event = events[index];
                            final eventString = event.toString();
                            final bgColor =
                                eventColors[eventString] ?? Colors.blue;

                            return Container(
                              margin: const EdgeInsets.symmetric(vertical: 4),
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: bgColor.withOpacity(0.2),
                                border: Border.all(color: bgColor, width: 2),
                              ),
                              child: Text(
                                eventString,
                                style: getCustomTextStyle(
                                  fontSize: 10,
                                  color: Colors.black,
                                  text: eventString,
                                ),
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
