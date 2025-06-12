import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/event.dart';
import '../utils/font_utils.dart';
import '../managers/popup_manager.dart';

class EventPopup extends StatelessWidget {
  final DateTime selectedDay;
  final List<Event> events;
  final Map<String, Color> eventColors;
  final Map<String, Color>? eventIdColors; // ID 기반 색상 매핑 추가
  final Map<String, Color>? colorIdColors; // Google colorId 색상 매핑 추가
  final Function() onClose;
  final Function() onAddEvent;
  final Function(Event) onDeleteEvent;
  final Function(Event)? onEditEvent; // 이벤트 수정 콜백 함수 추가
  final Function(Event)? getEventDisplayColor; // 이벤트 색상 가져오는 콜백 함수
  final PopupManager? popupManager; // PopupManager 추가
  final Function()? onAddMultiDayEvent; // 🆕 멀티데이 이벤트 추가 콜백

  const EventPopup({
    super.key,
    required this.selectedDay,
    required this.events,
    required this.eventColors,
    this.eventIdColors,
    this.colorIdColors,
    required this.onClose,
    required this.onAddEvent,
    required this.onDeleteEvent,
    this.onEditEvent, // 이벤트 수정 콜백 추가
    this.getEventDisplayColor,
    this.popupManager, // PopupManager 추가
    this.onAddMultiDayEvent, // 🆕 멀티데이 이벤트 추가 콜백
  });

  // 이벤트 색상 가져오기 - 색상 출력의 우선순위가 설정됨
  Color _getEventColor(Event event) {
    // 1. Google colorId 기반 매핑 (최우선)
    if (event.colorId != null &&
        colorIdColors != null &&
        colorIdColors!.containsKey(event.colorId)) {
      return colorIdColors![event.colorId]!;
    }

    // 2. 콜백 함수 사용 (CalendarController의 getEventDisplayColor)
    if (getEventDisplayColor != null) {
      return getEventDisplayColor!(event);
    }

    // 3. Event 객체의 color 속성
    if (event.color != null) {
      return event.color!;
    }

    // 4. 기본 색상
    return Colors.blue;
  }

  // 카테고리 이름 매핑 함수
  String _getCategoryName(dynamic colorId) {
    if (colorId == null) return '기타';

    // 문자열 colorId 처리
    if (colorId is String) {
      switch (colorId) {
        case 'holiday_red':
          return '공휴일';
        default:
          // 숫자 문자열인 경우 정수로 변환 시도
          int? numericId = int.tryParse(colorId);
          if (numericId != null) {
            return _getCategoryFromNumber(numericId);
          }
          return '기타';
      }
    }

    // 숫자 colorId 처리
    if (colorId is int) {
      return _getCategoryFromNumber(colorId);
    }

    return '기타';
  }

  String _getCategoryFromNumber(int colorId) {
    const categories = [
      '업무', // colorId 1
      '집안일', // colorId 2
      '기념일', // colorId 3
      '학교', // colorId 4
      '운동', // colorId 5
      '공부', // colorId 6
      '여행', // colorId 7
      '기타', // colorId 8
      '친구', // colorId 9
      '가족', // colorId 10
      '병원', // colorId 11
    ];

    if (colorId > 0 && colorId <= categories.length) {
      return categories[colorId - 1];
    }
    return '기타';
  }

  @override
  Widget build(BuildContext context) {
    // 시간순으로 정렬된 이벤트 목록
    final sortedEvents = List<Event>.from(events)
      ..sort((a, b) => a.compareTo(b));

    return Container(
      color: Colors.black.withAlpha(127),
      child: Center(
        child: Container(
          width: MediaQuery.of(context).size.width * 0.8,
          height: MediaQuery.of(context).size.height * 0.7,
          decoration: BoxDecoration(
            color: const Color.fromARGB(255, 255, 255, 255),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.black, width: 2),
          ),
          child: Column(
            children: [
              // 헤더
              Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  color: Color.fromARGB(255, 0, 0, 0),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(8),
                    topRight: Radius.circular(8),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      DateFormat('MM dd EEE').format(selectedDay),
                      style: getTextStyle(
                        fontSize: 16,
                        color: const Color.fromARGB(255, 255, 255, 255),
                      ),
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
                    Color eventColor = _getEventColor(event).withAlpha(200);
                    String categoryName = _getCategoryName(event.colorId);
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: eventColor,
                        border: Border.all(color: eventColor, width: 1),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: ListTile(
                        leading: Container(
                          width: 70,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Text(
                            event
                                    .isMultiDay // 🆕 멀티데이 이벤트 처리
                                ? '며칠 일정'
                                : event
                                    .hasEndTime() // 종료시간이 따로 있는 경우를 따지는 조건문
                                ? '${event.time}\n-${event.endTime}'
                                : event.time,
                            style: getTextStyle(
                              fontSize: 12,
                              color: Colors.black,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        title: Text(
                          '$categoryName\n${event.title} ',
                          style: getTextStyle(
                            fontSize: 12,
                            color: Colors.black,
                          ),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            // 수정 버튼
                            if (onEditEvent != null)
                              GestureDetector(
                                onTap: () {
                                  if (event.isMultiDay) {
                                    // 멀티데이 이벤트 수정 알림
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('며칠 일정은 삭제 후 다시 생성해주세요.'),
                                        duration: Duration(seconds: 2),
                                      ),
                                    );
                                  } else {
                                    onEditEvent!(event);
                                  }
                                },
                                child: Container(
                                  width: 24,
                                  height: 24,
                                  margin: const EdgeInsets.only(right: 4),
                                  child: const Icon(
                                    Icons.edit,
                                    size: 20,
                                    color: Color.fromARGB(180, 0, 0, 0),
                                  ),
                                ),
                              ),
                            // 삭제 버튼
                            GestureDetector(
                              onTap: () async {
                                // 새로운 세련된 삭제 확인 다이얼로그
                                bool? shouldDelete;
                                if (popupManager != null) {
                                  shouldDelete = await popupManager!
                                      .showDeleteEventDialog(context, event);
                                } else {
                                  // PopupManager가 없으면 기본 다이얼로그 사용
                                  shouldDelete = await showDialog<bool>(
                                    context: context,
                                    builder:
                                        (context) => AlertDialog(
                                          title: Text(
                                            '일정 삭제',
                                            style: getTextStyle(fontSize: 14),
                                          ),
                                          content: Text(
                                            '${event.hasEndTime() ? '${event.time}-${event.endTime}' : event.time} ${event.title} 일정을 삭제하시겠습니까?',
                                            style: getTextStyle(fontSize: 12),
                                          ),
                                          actions: [
                                            TextButton(
                                              onPressed:
                                                  () => Navigator.pop(
                                                    context,
                                                    false,
                                                  ),
                                              child: Text(
                                                '취소',
                                                style: getTextStyle(
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ),
                                            TextButton(
                                              onPressed:
                                                  () => Navigator.pop(
                                                    context,
                                                    true,
                                                  ),
                                              child: Text(
                                                '삭제',
                                                style: getTextStyle(
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                  );
                                }

                                if (shouldDelete == true) {
                                  onDeleteEvent(event);
                                }
                              },

                              child: Container(
                                width: 24,
                                height: 24,
                                child: const Icon(
                                  Icons.delete,
                                  size: 20,
                                  color: Color.fromARGB(180, 0, 0, 0),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              // 하단 버튼들
              Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  border: Border(
                    top: BorderSide(color: Colors.black, width: 1),
                  ),
                ),
                child: Column(
                  children: [
                    // 일반 일정 추가 버튼
                    Container(
                      height: 50,
                      margin: const EdgeInsets.only(bottom: 8),
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

                    // 🆕 멀티데이 일정 추가 버튼
                    if (onAddMultiDayEvent != null)
                      Container(
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
                          color: const Color.fromARGB(255, 101, 157, 189),
                          child: InkWell(
                            onTap: onAddMultiDayEvent,
                            child: Container(
                              alignment: Alignment.center,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(
                                    Icons.date_range,
                                    color: Colors.white,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '며칠 일정 추가',
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
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
