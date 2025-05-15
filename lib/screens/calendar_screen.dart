import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import 'dart:math';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'empty_page.dart';
import '../utils/font_utils.dart';

import '../models/time_slot.dart';
import '../services/event_storage_service.dart';
import '../widgets/event_popup.dart';
import '../widgets/time_table_popup.dart';
import '../widgets/moving_button.dart';

class PixelArtCalendarScreen extends StatefulWidget {
  const PixelArtCalendarScreen({Key? key}) : super(key: key);

  @override
  _PixelArtCalendarScreenState createState() => _PixelArtCalendarScreenState();
}

class _PixelArtCalendarScreenState extends State<PixelArtCalendarScreen>
    with TickerProviderStateMixin {
  late DateTime _focusedDay;
  late DateTime _selectedDay;
  late CalendarFormat _calendarFormat;
  bool _showEventPopup = false; // 이벤트 팝업 표시 여부
  bool _showTimeTablePopup = false; // 타임테이블 팝업 표시 여부

  // 움직이는 버튼 관련 변수
  double _buttonLeft = 0;
  double _buttonTop = 0;
  double _buttonRight = 0;
  double _buttonBottom = 0;
  int _currentEdge = 0; // 0: 상단, 1: 오른쪽, 2: 하단, 3: 왼쪽
  Timer? _timer;
  final double _buttonSize = 80;
  bool _isMovingHorizontally = true;
  final Random _random = Random();

  // 현재 날짜별 로드된 이벤트 캐시 - 키를 String으로 변경
  final Map<String, List<String>> _events = {};
  // 현재 날짜별 로드된 타임 테이블 캐시 - 키를 String으로 변경
  final Map<String, List<TimeSlot>> _timeSlots = {};
  // 이벤트 색상 매핑
  final Map<String, Color> _eventColors = {};
  // 색상 목록
  final List<Color> _colors = [
    Colors.red,
    Colors.blue,
    Colors.green,
    Colors.orange,
    Colors.purple,
    Colors.indigo,
    Colors.teal,
  ];

  // 현재 로드 중인 날짜를 추적하기 위한 세트
  final Set<String> _loadingDates = {};
  // 현재 타임슬롯 로드 중인 날짜를 추적하기 위한 세트
  final Set<String> _loadingTimeSlots = {};

  @override
  void initState() {
    super.initState();
    _focusedDay = DateTime.now();
    _selectedDay = DateTime.now();
    _calendarFormat = CalendarFormat.month; // 항상 월 형식으로 고정
    // 저장된 모든 키 확인
    EventStorageService.printAllKeys();
    // 초기 데이터 로드
    _loadInitialData();
    // 움직이는 버튼 초기 위치 설정
    _startButtonMovement();
  }

  // 애플리케이션 시작 시 초기 데이터 로드
  Future _loadInitialData() async {
    // 현재 날짜의 이벤트 로드
    await _loadEventsForDay(_selectedDay);
    await _loadTimeSlotsForDay(_selectedDay);
    // 화면 갱신
    setState(() {});
  }

  // 날짜별 이벤트 로드 및 캐시
  Future _loadEventsForDay(DateTime day) async {
    final normalizedDay = DateTime(day.year, day.month, day.day);
    final dateKey = _getKey(normalizedDay);
    // 캐시에 없으면 로드
    if (!_events.containsKey(dateKey)) {
      final events = await EventStorageService.getEvents(normalizedDay);
      _events[dateKey] = events;
      // 이벤트 색상 할당
      _assignColorsToEvents(events);
    }
  }

  // 날짜별 타임슬롯 로드 및 캐시
  Future _loadTimeSlotsForDay(DateTime day) async {
    final normalizedDay = DateTime(day.year, day.month, day.day);
    final dateKey = _getKey(normalizedDay);
    // 캐시에 없으면 로드
    if (!_timeSlots.containsKey(dateKey)) {
      final timeSlots = await EventStorageService.getTimeSlots(normalizedDay);
      _timeSlots[dateKey] = timeSlots;
    }
  }

  // 이벤트에 색상 할당
  void _assignColorsToEvents(List<String> events) {
    int colorIndex = 0;
    for (var event in events) {
      if (!_eventColors.containsKey(event)) {
        _eventColors[event] = _colors[colorIndex % _colors.length];
        colorIndex++;
      }
    }
  }

  // 이벤트 추가
  Future _addEvent(String title) async {
    print('이벤트 추가: $title, 날짜: $_selectedDay');
    final normalizedDay = DateTime(
      _selectedDay.year,
      _selectedDay.month,
      _selectedDay.day,
    );
    final dateKey = _getKey(normalizedDay);
    // 이벤트 저장
    await EventStorageService.addEvent(normalizedDay, title);
    // 캐시 업데이트
    await _loadEventsForDay(normalizedDay);
    // UI 갱신 - 상태 업데이트를 통해 전체 캘린더 새로고침
    setState(() {
      print('이벤트 추가 완료: $title');
      // 현재 선택된 날짜를 다시 설정하여 날짜 이벤트 정보 새로고침
      _focusedDay = normalizedDay;
      _selectedDay = normalizedDay;
    });
  }

  // 이벤트 삭제
  Future _removeEvent(String event) async {
    final normalizedDay = DateTime(
      _selectedDay.year,
      _selectedDay.month,
      _selectedDay.day,
    );
    final dateKey = _getKey(normalizedDay);
    // 이벤트 삭제
    await EventStorageService.removeEvent(normalizedDay, event);
    // 캐시 업데이트
    await _loadEventsForDay(normalizedDay);
    // UI 갱신
    setState(() {});
  }

  // 타임슬롯 추가
  Future _addTimeSlot(
    String title,
    String startTime,
    String endTime,
    Color color,
  ) async {
    final normalizedDay = DateTime(
      _selectedDay.year,
      _selectedDay.month,
      _selectedDay.day,
    );
    final dateKey = _getKey(normalizedDay);
    final timeSlot = TimeSlot(title, startTime, endTime, color);
    // 타임슬롯 저장
    await EventStorageService.addTimeSlot(normalizedDay, timeSlot);
    // 캐시 업데이트
    await _loadTimeSlotsForDay(normalizedDay);
    // UI 갱신
    setState(() {});
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  // 버튼 움직임 시작
  void _startButtonMovement() {
    // 타이머 간격을 변경하여 업데이트 빈도 조정 (밀리초 단위)
    _timer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
      setState(() {
        _moveButton();
      });
    });
  }

  // 버튼 움직임 로직
  void _moveButton() {
    final size = MediaQuery.of(context).size;
    final speed = 4.0 + _random.nextDouble() * 4.0; // 지정값 사이의 랜덤 속도
    // 앱바와 화면 패딩을 고려한 실제 가용 영역 계산
    final appBarHeight = AppBar().preferredSize.height;
    final safeAreaTop = MediaQuery.of(context).padding.top;
    final safeAreaBottom = MediaQuery.of(context).padding.bottom;
    // 화면 패딩 고려 (main.dart에서 사용하는 패딩 값)
    final screenPadding = 22.0;
    // 실제 가용 화면 영역
    final effectiveHeight = size.height - appBarHeight - safeAreaTop;
    final effectiveWidth = size.width;

    switch (_currentEdge) {
      case 0: // 상단
        _buttonLeft += speed;
        _buttonTop = screenPadding;
        if (_buttonLeft + _buttonSize >= effectiveWidth - screenPadding) {
          _buttonLeft = effectiveWidth - _buttonSize - screenPadding;
          _currentEdge = 1; // 오른쪽으로 전환
        }
        break;
      case 1: // 오른쪽
        _buttonTop += speed;
        _buttonLeft = effectiveWidth - _buttonSize - screenPadding;
        if (_buttonTop + _buttonSize >=
            effectiveHeight - screenPadding - safeAreaBottom) {
          _buttonTop =
              effectiveHeight - _buttonSize - screenPadding - safeAreaBottom;
          _currentEdge = 2; // 하단으로 전환
        }
        break;
      case 2: // 하단
        _buttonLeft -= speed;
        _buttonTop =
            effectiveHeight - _buttonSize - screenPadding - safeAreaBottom;
        if (_buttonLeft <= screenPadding) {
          _buttonLeft = screenPadding;
          _currentEdge = 3; // 왼쪽으로 전환
        }
        break;
      case 3: // 왼쪽
        _buttonTop -= speed;
        _buttonLeft = screenPadding;
        if (_buttonTop <= screenPadding) {
          _buttonTop = screenPadding;
          _currentEdge = 0; // 상단으로 전환
        }
        break;
    }
  }

  // 빈 페이지로 이동
  void _navigateToEmptyPage() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const EmptyPage()),
    );
  }

  // 날짜별 이벤트 가져오기
  List<String> _getEventsForDay(DateTime day) {
    final normalizedDay = DateTime(day.year, day.month, day.day);
    final dateKey = _getKey(normalizedDay);
    // 캐시에 없는 경우에만 로드하고 로그 출력 (이미 로드 요청 중인지 확인)
    if (!_events.containsKey(dateKey) && !_loadingDates.contains(dateKey)) {
      _loadingDates.add(dateKey); // 로드 중인 날짜 추가
      _loadEventsForDay(normalizedDay).then((_) {
        setState(() {
          _loadingDates.remove(dateKey); // 로드 완료 후 제거
        });
      });
      return [];
    }

    return _events[dateKey] ?? [];
  }

  // 날짜별 타임 테이블 가져오기
  List<TimeSlot> _getTimeSlotsForDay(DateTime day) {
    final normalizedDay = DateTime(day.year, day.month, day.day);
    final dateKey = _getKey(normalizedDay);
    // 캐시에 없고 아직 로드 중이지 않은 경우에만 로드 요청
    if (!_timeSlots.containsKey(dateKey) &&
        !_loadingTimeSlots.contains(dateKey)) {
      _loadingTimeSlots.add(dateKey);
      _loadTimeSlotsForDay(normalizedDay).then((_) {
        setState(() {
          _loadingTimeSlots.remove(dateKey);
        });
      });
      return [];
    }

    return _timeSlots[dateKey] ?? [];
  }

  // 이벤트 팝업 표시/숨김
  void _showEventDialog() {
    setState(() {
      _showEventPopup = true;
      _showTimeTablePopup = false;
    });
  }

  void _hideEventDialog() {
    setState(() {
      _showEventPopup = false;
    });
  }

  // 타임테이블 팝업 표시/숨김
  void _showTimeTableDialog() {
    setState(() {
      _showTimeTablePopup = true;
      _showEventPopup = false;
    });
  }

  void _hideTimeTableDialog() {
    setState(() {
      _showTimeTablePopup = false;
    });
  }

  // 이벤트 추가 다이얼로그 표시
  void _showAddEventDialog() {
    final TextEditingController _textController = TextEditingController();

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(
              '새 일정 추가',
              style: TextStyle(
                fontFamily: 'CustomFont',
                fontSize: 14,
                color: Colors.black,
              ),
            ),
            content: TextField(
              controller: _textController,
              decoration: InputDecoration(hintText: '일정을 입력하세요'),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  '취소',
                  style: TextStyle(
                    fontFamily: 'CustomFont',
                    fontSize: 10,
                    color: Colors.black,
                  ),
                ),
              ),
              TextButton(
                onPressed: () async {
                  if (_textController.text.isNotEmpty) {
                    await _addEvent(_textController.text);
                    Navigator.pop(context);

                    // 저장 후 상태 확인만 출력
                    EventStorageService.printAllKeys();
                  }
                },
                child: Text(
                  '추가',
                  style: TextStyle(
                    fontFamily: 'CustomFont',
                    fontSize: 10,
                    color: Colors.black,
                  ),
                ),
              ),
            ],
          ),
    );
  }

  // 타임슬롯 추가 다이얼로그 표시
  void _showAddTimeSlotDialog() {
    final titleController = TextEditingController();
    final startTimeController = TextEditingController();
    final endTimeController = TextEditingController();
    Color selectedColor = _colors[_random.nextInt(_colors.length)];

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(
              '새 일정 추가',
              style: TextStyle(
                fontFamily: 'CustomFont',
                fontSize: 14,
                color: Colors.black,
              ),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: titleController,
                    decoration: InputDecoration(hintText: '일정 제목'),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: startTimeController,
                    decoration: InputDecoration(hintText: '시작 시간 (HH:MM)'),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: endTimeController,
                    decoration: InputDecoration(hintText: '종료 시간 (HH:MM)'),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children:
                        _colors
                            .map(
                              (color) => GestureDetector(
                                onTap: () {
                                  selectedColor = color;
                                  Navigator.pop(context);
                                  _showAddTimeSlotDialog(); // 색상 선택 후 다이얼로그 다시 표시
                                },
                                child: Container(
                                  width: 24,
                                  height: 24,
                                  decoration: BoxDecoration(
                                    color: color,
                                    border: Border.all(
                                      color:
                                          selectedColor == color
                                              ? Colors.black
                                              : Colors.transparent,
                                      width: 2,
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  '취소',
                  style: TextStyle(
                    fontFamily: 'CustomFont',
                    fontSize: 10,
                    color: Colors.black,
                  ),
                ),
              ),
              TextButton(
                onPressed: () {
                  if (titleController.text.isNotEmpty &&
                      startTimeController.text.isNotEmpty &&
                      endTimeController.text.isNotEmpty) {
                    _addTimeSlot(
                      titleController.text,
                      startTimeController.text,
                      endTimeController.text,
                      selectedColor,
                    );
                    Navigator.pop(context);
                  }
                },
                child: Text(
                  '추가',
                  style: TextStyle(
                    fontFamily: 'CustomFont',
                    fontSize: 10,
                    color: Colors.black,
                  ),
                ),
              ),
            ],
          ),
    );
  }

  // 캐시 키를 생성하기 위한 헬퍼 메서드
  String _getKey(DateTime date) {
    return "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 162, 222, 141),
      appBar: AppBar(
        title: Text(
          'Calender v250514',
          style: TextStyle(
            fontFamily: 'CustomFont',
            fontSize: 14,
            color: Colors.white,
          ),
        ),
        backgroundColor: Colors.black,
      ),
      body: Stack(
        children: [
          // 메인 콘텐츠
          Padding(
            padding: const EdgeInsets.all(22.0),
            child: Container(
              height: double.infinity,
              decoration: BoxDecoration(color: const Color(0xFFFFFFFF)),
              child: TableCalendar(
                firstDay: DateTime.utc(2020, 1, 1),
                lastDay: DateTime.utc(2030, 12, 31),
                focusedDay: _focusedDay,
                calendarFormat: _calendarFormat,
                daysOfWeekHeight: 50.0,
                rowHeight: 109.5,
                selectedDayPredicate: (day) {
                  return isSameDay(_selectedDay, day);
                },
                onDaySelected: (selectedDay, focusedDay) {
                  setState(() {
                    _selectedDay = selectedDay;
                    _focusedDay = focusedDay;
                    _showEventDialog();
                  });
                },
                onPageChanged: (focusedDay) {
                  setState(() {
                    _focusedDay = focusedDay;
                    _showEventPopup = false;
                    _showTimeTablePopup = false;
                  });
                },
                eventLoader: _getEventsForDay,
                startingDayOfWeek: StartingDayOfWeek.sunday,
                headerStyle: HeaderStyle(
                  titleTextStyle: TextStyle(
                    fontFamily: 'CustomFont',
                    fontSize: 12,
                    color: Colors.black,
                  ),
                  formatButtonVisible: false,
                  leftChevronIcon: const Icon(
                    Icons.arrow_left,
                    color: Colors.black,
                    size: 24,
                  ),
                  rightChevronIcon: const Icon(
                    Icons.arrow_right,
                    color: Colors.black,
                    size: 24,
                  ),
                  headerMargin: const EdgeInsets.only(bottom: 8),
                  headerPadding: const EdgeInsets.symmetric(vertical: 10),
                  titleCentered: true,
                ),
                daysOfWeekStyle: DaysOfWeekStyle(
                  weekdayStyle: TextStyle(
                    fontFamily: 'CustomFont',
                    fontSize: 8,
                    color: Colors.black,
                  ),
                  weekendStyle: TextStyle(
                    fontFamily: 'CustomFont',
                    fontSize: 8,
                    color: Colors.red,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEEEEEE),
                    border: Border.all(color: Colors.black, width: 1),
                  ),
                ),
                calendarStyle: CalendarStyle(
                  defaultTextStyle: TextStyle(
                    fontFamily: 'CustomFont',
                    fontSize: 8,
                    color: Colors.black,
                  ),
                  weekendTextStyle: TextStyle(
                    fontFamily: 'CustomFont',
                    fontSize: 8,
                    color: Colors.red,
                  ),
                  selectedTextStyle: TextStyle(
                    fontFamily: 'CustomFont',
                    fontSize: 8,
                    color: Colors.white,
                  ),
                  todayTextStyle: TextStyle(
                    fontFamily: 'CustomFont',
                    fontSize: 8,
                    color: Colors.black,
                  ),
                  outsideTextStyle: TextStyle(
                    fontFamily: 'CustomFont',
                    fontSize: 8,
                    color: const Color(0xFF888888),
                  ),
                  selectedDecoration: BoxDecoration(
                    color: Colors.blue[800],
                    border: Border.all(color: Colors.black, width: 1),
                  ),
                  todayDecoration: BoxDecoration(
                    color: Colors.amber[300],
                    border: Border.all(color: Colors.black, width: 1),
                  ),
                  defaultDecoration: BoxDecoration(
                    border: Border.all(color: Colors.black, width: 1),
                  ),
                  weekendDecoration: BoxDecoration(
                    color: const Color(0xFFEEEEEE),
                    border: Border.all(color: Colors.black, width: 1),
                  ),
                  outsideDecoration: BoxDecoration(
                    color: const Color(0xFFDDDDDD),
                    border: Border.all(color: Colors.black, width: 1),
                  ),
                  tableBorder: TableBorder.all(color: Colors.black, width: 2),
                  markersMaxCount: 6,
                  markersAlignment: Alignment.bottomCenter,
                  markerMargin: const EdgeInsets.only(top: 2),
                  markerDecoration: BoxDecoration(color: Colors.transparent),
                  markerSize: 0,
                ),
                calendarBuilders: CalendarBuilders(
                  // 기본 셀 빌더
                  defaultBuilder: (context, day, focusedDay) {
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedDay = day;
                          _focusedDay = focusedDay;
                          _showEventDialog();
                        });
                      },
                      onLongPress: () {
                        setState(() {
                          _selectedDay = day;
                          _focusedDay = focusedDay;
                          _showTimeTableDialog();
                        });
                      },
                      child: Container(
                        margin: const EdgeInsets.all(2),
                        alignment: Alignment.topCenter,
                        child: Padding(
                          padding: const EdgeInsets.only(top: 5.0),
                          child: Text(
                            '${day.day}',
                            style: getTextStyle(
                              fontSize: 8,
                              color: Colors.black,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                  // 선택된 날짜 셀 빌더
                  selectedBuilder: (context, day, focusedDay) {
                    return GestureDetector(
                      onTap: () {
                        _showEventDialog();
                      },
                      onLongPress: () {
                        _showTimeTableDialog();
                      },
                      child: Container(
                        margin: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: Colors.blue[800],
                          border: Border.all(color: Colors.black, width: 1),
                        ),
                        alignment: Alignment.topCenter,
                        child: Padding(
                          padding: const EdgeInsets.only(top: 5.0),
                          child: Text(
                            '${day.day}',
                            style: getTextStyle(
                              fontSize: 8,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                  // 오늘 날짜 셀 빌더
                  todayBuilder: (context, day, focusedDay) {
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedDay = day;
                          _focusedDay = focusedDay;
                          _showEventDialog();
                        });
                      },
                      onLongPress: () {
                        setState(() {
                          _selectedDay = day;
                          _focusedDay = focusedDay;
                          _showTimeTableDialog();
                        });
                      },
                      child: Container(
                        margin: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: Colors.amber[300],
                          border: Border.all(color: Colors.black, width: 1),
                        ),
                        alignment: Alignment.topCenter,
                        child: Padding(
                          padding: const EdgeInsets.only(top: 5.0),
                          child: Text(
                            '${day.day}',
                            style: getTextStyle(
                              fontSize: 8,
                              color: Colors.black,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                  // 요일 헤더 빌더
                  dowBuilder: (context, day) {
                    final weekdayNames = [
                      'Mon',
                      'Tue',
                      'Wed',
                      'Tur',
                      'Fri',
                      'Sat',
                      'Sun',
                    ];
                    final weekdayIndex = day.weekday - 1;
                    final isWeekend =
                        day.weekday == DateTime.saturday ||
                        day.weekday == DateTime.sunday;
                    return Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFEEEEEE),
                        border: Border.all(color: Colors.black, width: 1),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        weekdayNames[weekdayIndex],
                        style: getTextStyle(
                          fontSize: 8,
                          color: isWeekend ? Colors.red : Colors.black,
                        ),
                      ),
                    );
                  },
                  // 헤더 타이틀 빌더
                  headerTitleBuilder: (context, month) {
                    final monthNames = [
                      '1월',
                      '2월',
                      '3월',
                      '4월',
                      '5월',
                      '6월',
                      '7월',
                      '8월',
                      '9월',
                      '10월',
                      '11월',
                      '12월',
                    ];
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        vertical: 4,
                        horizontal: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black,
                        border: Border.all(
                          color: const Color(0xFF888888),
                          width: 2,
                        ),
                      ),
                      child: Text(
                        '${month.year}년 ${monthNames[month.month - 1]}',
                        style: getTextStyle(fontSize: 10, color: Colors.white),
                      ),
                    );
                  },
                  // 이벤트 마커 빌더
                  markerBuilder: (context, date, events) {
                    if (events.isEmpty) return const SizedBox.shrink();

                    final displayedEvents =
                        events.length > 6 ? events.sublist(0, 6) : events;

                    return Positioned(
                      bottom: 4,
                      left: 4,
                      right: 4,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        mainAxisSize: MainAxisSize.min,
                        children:
                            displayedEvents.map((event) {
                              final eventString = event.toString();
                              final bgColor =
                                  _eventColors[eventString] ?? _colors[0];

                              return Container(
                                margin: const EdgeInsets.only(bottom: 1),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 2,
                                  vertical: 1,
                                ),
                                decoration: BoxDecoration(
                                  color: bgColor.withOpacity(0.7),
                                  border: Border.all(
                                    color: Colors.black,
                                    width: 1,
                                  ),
                                ),
                                child: Text(
                                  eventString,
                                  style: getCustomTextStyle(
                                    fontSize: 10,
                                    color: Colors.white,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                              );
                            }).toList(),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),

          // 이벤트 팝업 오버레이
          if (_showEventPopup)
            EventPopup(
              selectedDay: _selectedDay,
              events: _getEventsForDay(_selectedDay),
              eventColors: _eventColors,
              onClose: _hideEventDialog,
              onAddEvent: _showAddEventDialog,
            ),

          // 타임테이블 팝업 오버레이
          if (_showTimeTablePopup)
            TimeTablePopup(
              selectedDay: _selectedDay,
              timeSlots: _getTimeSlotsForDay(_selectedDay),
              onClose: _hideTimeTableDialog,
              onAddTimeSlot: _showAddTimeSlotDialog,
            ),

          // 움직이는 GIF 버튼
          Positioned(
            left: _buttonLeft,
            top: _buttonTop,
            child: MovingButton(size: _buttonSize, onTap: _navigateToEmptyPage),
          ),
        ],
      ),
    );
  }
}
