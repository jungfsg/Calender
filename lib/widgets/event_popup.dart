import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/event.dart';
import '../utils/font_utils.dart';

class EventPopup extends StatelessWidget {
  final DateTime selectedDay;
  final List<Event> events;
  final Map<String, Color> eventColors;
  final Function() onClose;
  final Function() onAddEvent;
  final Function(Event) onDeleteEvent;

  const EventPopup({
    Key? key,
    required this.selectedDay,
    required this.events,
    required this.eventColors,
    required this.onClose,
    required this.onAddEvent,
    required this.onDeleteEvent,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // 시간순으로 정렬된 이벤트 목록
    final sortedEvents = List<Event>.from(events)
      ..sort((a, b) => a.compareTo(b));

    return Container(
      color: Colors.black.withOpacity(0.5),
      child: Center(
        child: Container(
          width: MediaQuery.of(context).size.width * 0.8,
          height: MediaQuery.of(context).size.height * 0.7,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.black, width: 2),
          ),
          child: Column(
            children: [
              // 헤더
              Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(8),
                    topRight: Radius.circular(8),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      DateFormat('yyyy년 MM월 dd일').format(selectedDay),
                      style: getTextStyle(fontSize: 14, color: Colors.white),
                    ),
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
              ),
              // 이벤트 목록
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(8),
                  itemCount: sortedEvents.length,
                  itemBuilder: (context, index) {
                    final event = sortedEvents[index];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color:
                            eventColors[event.title]?.withOpacity(0.1) ??
                            Colors.grey.withOpacity(0.1),
                        border: Border.all(
                          color: eventColors[event.title] ?? Colors.grey,
                          width: 1,
                        ),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: ListTile(
                        leading: Container(
                          width: 90,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Text(
                            event.time,
                            style: getTextStyle(
                              fontSize: 12,
                              color: Colors.black,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        title: Text(
                          event.title,
                          style: getTextStyle(
                            fontSize: 12,
                            color: Colors.black,
                          ),
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete, size: 20),
                          onPressed: () async {
                            // 삭제 확인 다이얼로그
                            final shouldDelete = await showDialog<bool>(
                              context: context,
                              builder:
                                  (context) => AlertDialog(
                                    title: Text(
                                      '일정 삭제',
                                      style: getTextStyle(fontSize: 14),
                                    ),
                                    content: Text(
                                      '${event.time} ${event.title} 일정을 삭제하시겠습니까?',
                                      style: getTextStyle(fontSize: 12),
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed:
                                            () => Navigator.pop(context, false),
                                        child: Text(
                                          '취소',
                                          style: getTextStyle(fontSize: 12),
                                        ),
                                      ),
                                      TextButton(
                                        onPressed:
                                            () => Navigator.pop(context, true),
                                        child: Text(
                                          '삭제',
                                          style: getTextStyle(fontSize: 12),
                                        ),
                                      ),
                                    ],
                                  ),
                            );

                            if (shouldDelete == true) {
                              onDeleteEvent(event);
                            }
                          },
                        ),
                      ),
                    );
                  },
                ),
              ),
              // 하단 버튼
              Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  border: Border(
                    top: BorderSide(color: Colors.black, width: 1),
                  ),
                ),
                child: Container(
                  height: 50,
                  decoration: BoxDecoration(
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.5),
                        spreadRadius: 1,
                        blurRadius: 3,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Material(
                    color: const Color.fromARGB(255, 162, 222, 141),
                    child: InkWell(
                      onTap: onAddEvent,
                      child: Container(
                        alignment: Alignment.center,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.add_box_outlined,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '새 일정 추가',
                              style: getTextStyle(
                                fontSize: 12,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
