import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import 'dart:math';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'pages/empty_page.dart';

void main() {
  runApp(const MyApp());
}

// 일정 저장/로드를 위한 서비스 클래스
class EventStorageService {
  static const String ALL_EVENTS_KEY = 'all_events';
  static const String ALL_TIMESLOTS_KEY = 'all_timeslots';

  // 모든 이벤트 저장
  static Future<void> saveAllEvents(Map<String, List<String>> allEvents) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonData = jsonEncode(allEvents);
    await prefs.setString(ALL_EVENTS_KEY, jsonData);
  }

  // 모든 이벤트 로드
  static Future<Map<String, List<String>>> getAllEvents() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonData = prefs.getString(ALL_EVENTS_KEY);

    if (jsonData == null || jsonData.isEmpty) {
      return {};
    }

    try {
      final Map<String, dynamic> decoded = jsonDecode(jsonData);
      final Map<String, List<String>> result = {};

      decoded.forEach((key, value) {
        if (value is List) {
          result[key] = List<String>.from(value);
        }
      });

      return result;
    } catch (e) {
      print('이벤트 데이터 파싱 오류: $e');
      return {};
    }
  }

  // 특정 날짜의 이벤트 저장
  static Future<void> saveEvents(DateTime date, List<String> events) async {
    final dateKey = _getKey(date);
    final allEvents = await getAllEvents();
    allEvents[dateKey] = events;
    await saveAllEvents(allEvents);
  }

  // 특정 날짜의 이벤트 로드
  static Future<List<String>> getEvents(DateTime date) async {
    final dateKey = _getKey(date);
    final allEvents = await getAllEvents();
    return allEvents[dateKey] ?? [];
  }

  // 이벤트 추가
  static Future<void> addEvent(DateTime date, String event) async {
    print('이벤트 저장 시작: $date, 내용: $event');
    final events = await getEvents(date);
    // print('기존 이벤트: $events');
    events.add(event);
    await saveEvents(date, events);
  }

  // 이벤트 삭제
  static Future<void> removeEvent(DateTime date, String event) async {
    final events = await getEvents(date);
    events.remove(event);
    await saveEvents(date, events);
  }

  // 타임슬롯 관련 메서드는 이전과 유사하게 유지하되 저장 방식 수정
  // 모든 타임슬롯 저장
  static Future<void> saveAllTimeSlots(
    Map<String, List<Map<String, dynamic>>> allTimeSlots,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonData = jsonEncode(allTimeSlots);
    await prefs.setString(ALL_TIMESLOTS_KEY, jsonData);
  }

  // 모든 타임슬롯 로드
  static Future<Map<String, List<Map<String, dynamic>>>>
  getAllTimeSlots() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonData = prefs.getString(ALL_TIMESLOTS_KEY);

    if (jsonData == null || jsonData.isEmpty) {
      return {};
    }

    try {
      final Map<String, dynamic> decoded = jsonDecode(jsonData);
      final Map<String, List<Map<String, dynamic>>> result = {};

      decoded.forEach((key, value) {
        if (value is List) {
          result[key] = List<Map<String, dynamic>>.from(
            value.map((item) => Map<String, dynamic>.from(item)),
          );
        }
      });

      return result;
    } catch (e) {
      print('타임슬롯 데이터 파싱 오류: $e');
      return {};
    }
  }

  // 특정 날짜의 타임슬롯 저장
  static Future<void> saveTimeSlots(
    DateTime date,
    List<TimeSlot> timeSlots,
  ) async {
    final dateKey = _getKey(date);
    final allTimeSlots = await getAllTimeSlots();

    // TimeSlot 객체를 JSON으로 변환
    final List<Map<String, dynamic>> timeSlotMaps =
        timeSlots
            .map(
              (slot) => {
                'title': slot.title,
                'startTime': slot.startTime,
                'endTime': slot.endTime,
                'colorValue': slot.color.value,
              },
            )
            .toList();

    allTimeSlots[dateKey] = timeSlotMaps;
    await saveAllTimeSlots(allTimeSlots);
  }

  // 특정 날짜의 타임슬롯 로드
  static Future<List<TimeSlot>> getTimeSlots(DateTime date) async {
    final dateKey = _getKey(date);
    final allTimeSlots = await getAllTimeSlots();
    final timeSlotMaps = allTimeSlots[dateKey] ?? [];

    // JSON을 TimeSlot 객체로 변환
    return timeSlotMaps
        .map(
          (map) => TimeSlot(
            map['title'],
            map['startTime'],
            map['endTime'],
            Color(map['colorValue']),
          ),
        )
        .toList();
  }

  // 타임슬롯 추가
  static Future<void> addTimeSlot(DateTime date, TimeSlot timeSlot) async {
    final timeSlots = await getTimeSlots(date);
    timeSlots.add(timeSlot);
    await saveTimeSlots(date, timeSlots);
  }

  // 날짜 키 생성 (YYYY-MM-DD 형식)
  static String _getKey(DateTime date) {
    return "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
  }

  // 저장된 모든 키 목록 출력 (디버그용)
  static Future<void> printAllKeys() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys();
    print('저장된 키 목록: $keys');

    if (keys.contains(ALL_EVENTS_KEY)) {
      print('이벤트 저장 확인: ALL_EVENTS_KEY 존재');
    }
  }
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Calender 250512',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const PixelArtCalendarScreen(),
    );
  }
}

class PixelArtCalendarScreen extends StatefulWidget {
  const PixelArtCalendarScreen({Key? key}) : super(key: key);

  @override
  _PixelArtCalendarScreenState createState() => _PixelArtCalendarScreenState();
}

// 타임 테이블 항목을 위한 클래스
class TimeSlot {
  final String title;
  final String startTime;
  final String endTime;
  final Color color;

  TimeSlot(this.title, this.startTime, this.endTime, this.color);
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
  Future<void> _loadInitialData() async {
    // 현재 날짜의 이벤트 로드
    await _loadEventsForDay(_selectedDay);
    await _loadTimeSlotsForDay(_selectedDay);

    // 화면 갱신
    setState(() {});
  }

  // 날짜별 이벤트 로드 및 캐시
  Future<void> _loadEventsForDay(DateTime day) async {
    final normalizedDay = DateTime(day.year, day.month, day.day);
    final dateKey = _getKey(normalizedDay);
    // print('날짜별 이벤트 로드 요청: $normalizedDay, 키: $dateKey');

    // 캐시에 없으면 로드
    if (!_events.containsKey(dateKey)) {
      final events = await EventStorageService.getEvents(normalizedDay);
      _events[dateKey] = events;
      // print('이벤트 로드 완료: $events, 키: $dateKey');

      // 이벤트 색상 할당
      _assignColorsToEvents(events);
    } else {
      // print('캐시에서 이벤트 반환: ${_events[dateKey]}, 키: $dateKey');
    }
  }

  // 날짜별 타임슬롯 로드 및 캐시
  Future<void> _loadTimeSlotsForDay(DateTime day) async {
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
  Future<void> _addEvent(String title) async {
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
  Future<void> _removeEvent(String event) async {
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
  Future<void> _addTimeSlot(
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
    // 값이 작을수록 더 부드럽게 움직이고, 클수록 덜 부드럽게 움직입니다
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
              style: GoogleFonts.pressStart2p(fontSize: 14),
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
                  style: GoogleFonts.pressStart2p(fontSize: 10),
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
                  style: GoogleFonts.pressStart2p(fontSize: 10),
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
              style: GoogleFonts.pressStart2p(fontSize: 14),
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
                  style: GoogleFonts.pressStart2p(fontSize: 10),
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
                  style: GoogleFonts.pressStart2p(fontSize: 10),
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
      backgroundColor: const Color.fromARGB(255, 162, 222, 141), // 패딩 뒤쪽 배경색
      // backgroundColor: const Color(0xFFCCCCCC),
      appBar: AppBar(
        title: Text(
          'Calender v250514',
          style: GoogleFonts.pressStart2p(fontSize: 14, color: Colors.white),
        ),
        backgroundColor: Colors.black,
      ),
      body: Stack(
        children: [
          // 메인 콘텐츠
          Padding(
            padding: const EdgeInsets.all(22.0),
            child: Container(
              height: double.infinity, // 무한으로 설정
              decoration: BoxDecoration(
                color: const Color(0xFFFFFFFF),
                // border: Border.all(color: Colors.black, width: 4),
              ),
              child: TableCalendar(
                // 구현할 시간 범위 산정
                firstDay: DateTime.utc(2020, 1, 1),
                lastDay: DateTime.utc(2030, 12, 31),
                focusedDay: _focusedDay,
                calendarFormat: _calendarFormat,

                daysOfWeekHeight: 50.0, // 요일 행 높이
                rowHeight: 210.0, // 날짜 행 높이
                // 날짜 선택 처리
                selectedDayPredicate: (day) {
                  return isSameDay(_selectedDay, day);
                },
                onDaySelected: (selectedDay, focusedDay) {
                  setState(() {
                    _selectedDay = selectedDay;
                    _focusedDay = focusedDay;
                    _showEventDialog(); // 일반 탭에서는 이벤트 팝업 표시
                  });
                },

                // 페이지 변경 시 팝업 닫기 추가
                onPageChanged: (focusedDay) {
                  setState(() {
                    _focusedDay = focusedDay;
                    _showEventPopup = false;
                    _showTimeTablePopup = false;
                  });
                },

                // 이벤트 로더
                eventLoader: _getEventsForDay,

                // 시작 요일 (월요일) -> 일요일
                startingDayOfWeek: StartingDayOfWeek.sunday,

                // 헤더 스타일
                headerStyle: HeaderStyle(
                  titleTextStyle: GoogleFonts.pressStart2p(
                    fontSize: 12,
                    color: Colors.black,
                  ),
                  formatButtonVisible: false, // 포맷 버튼 숨기기
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

                // 요일 스타일
                daysOfWeekStyle: DaysOfWeekStyle(
                  weekdayStyle: GoogleFonts.pressStart2p(
                    fontSize: 8,
                    color: Colors.black,
                  ),
                  weekendStyle: GoogleFonts.pressStart2p(
                    fontSize: 8,
                    color: Colors.red,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEEEEEE),
                    border: Border.all(color: Colors.black, width: 1),
                  ),
                ),

                // 캘린더 스타일
                calendarStyle: CalendarStyle(
                  defaultTextStyle: GoogleFonts.pressStart2p(
                    fontSize: 8,
                    color: Colors.black,
                  ),
                  weekendTextStyle: GoogleFonts.pressStart2p(
                    fontSize: 8,
                    color: Colors.red,
                  ),
                  selectedTextStyle: GoogleFonts.pressStart2p(
                    fontSize: 8,
                    color: Colors.white,
                  ),
                  todayTextStyle: GoogleFonts.pressStart2p(
                    fontSize: 8,
                    color: Colors.black,
                  ),
                  outsideTextStyle: GoogleFonts.pressStart2p(
                    fontSize: 8,
                    color: const Color(0xFF888888),
                  ),
                  // 선택된 날짜 스타일
                  selectedDecoration: BoxDecoration(
                    color: Colors.blue[800],
                    border: Border.all(color: Colors.black, width: 1),
                  ),
                  // 오늘 날짜 스타일
                  todayDecoration: BoxDecoration(
                    color: Colors.amber[300],
                    border: Border.all(color: Colors.black, width: 1),
                  ),
                  // 기본 셀 스타일 (픽셀아트 느낌의 직각)
                  defaultDecoration: BoxDecoration(
                    border: Border.all(color: Colors.black, width: 1),
                  ),
                  // 주말 셀 스타일
                  weekendDecoration: BoxDecoration(
                    color: const Color(0xFFEEEEEE),
                    border: Border.all(color: Colors.black, width: 1),
                  ),
                  // 다른 달의 날짜 셀 스타일
                  outsideDecoration: BoxDecoration(
                    color: const Color(0xFFDDDDDD),
                    border: Border.all(color: Colors.black, width: 1),
                  ),
                  tableBorder: TableBorder.all(color: Colors.black, width: 2),
                  // 마커 설정 변경
                  markersMaxCount: 6,
                  markersAlignment: Alignment.bottomCenter,
                  markerMargin: const EdgeInsets.only(top: 2),
                  markerDecoration: BoxDecoration(
                    color: Colors.transparent, // 기본 마커 스타일은 사용하지 않음
                  ),
                  markerSize: 0, // 기본 마커 크기 0으로 설정
                ),

                // 캘린더 빌더
                calendarBuilders: CalendarBuilders(
                  // 기본 셀 빌더 - GestureDetector 추가
                  defaultBuilder: (context, day, focusedDay) {
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedDay = day;
                          _focusedDay = focusedDay;
                          _showEventDialog(); // 일반 터치 시 이벤트 팝업 표시
                        });
                      },
                      onLongPress: () {
                        setState(() {
                          _selectedDay = day;
                          _focusedDay = focusedDay;
                          _showTimeTableDialog(); // 길게 터치 시 타임테이블 팝업 표시
                        });
                      },
                      child: Container(
                        margin: const EdgeInsets.all(2),
                        alignment: Alignment.topCenter,
                        child: Padding(
                          padding: const EdgeInsets.only(top: 5.0),
                          child: Text(
                            '${day.day}',
                            style: GoogleFonts.pressStart2p(
                              fontSize: 8,
                              color: Colors.black,
                            ),
                          ),
                        ),
                      ),
                    );
                  },

                  // 선택된 날짜 셀 빌더 - GestureDetector 추가
                  selectedBuilder: (context, day, focusedDay) {
                    return GestureDetector(
                      onTap: () {
                        _showEventDialog(); // 날짜 선택 시 이벤트 팝업 표시
                      },
                      onLongPress: () {
                        _showTimeTableDialog(); // 길게 누를 시 타임테이블 팝업 표시
                      },
                      child: Container(
                        margin: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: Colors.blue[800],
                          border: Border.all(color: Colors.black, width: 1),
                        ),
                        alignment: Alignment.topCenter, // 상단 정렬
                        child: Padding(
                          padding: const EdgeInsets.only(top: 5.0), // 위쪽 여백 추가
                          child: Text(
                            '${day.day}',
                            style: GoogleFonts.pressStart2p(
                              fontSize: 8,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    );
                  },

                  // 오늘 날짜 셀 빌더 - GestureDetector 추가
                  todayBuilder: (context, day, focusedDay) {
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedDay = day;
                          _focusedDay = focusedDay;
                          _showEventDialog(); // 날짜 선택 시 이벤트 팝업 표시
                        });
                      },
                      onLongPress: () {
                        setState(() {
                          _selectedDay = day;
                          _focusedDay = focusedDay;
                          _showTimeTableDialog(); // 길게 누를 시 타임테이블 팝업 표시
                        });
                      },
                      child: Container(
                        margin: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: Colors.amber[300],
                          border: Border.all(color: Colors.black, width: 1),
                        ),
                        alignment: Alignment.topCenter, // 상단 정렬
                        child: Padding(
                          padding: const EdgeInsets.only(top: 5.0), // 위쪽 여백 추가
                          child: Text(
                            '${day.day}',
                            style: GoogleFonts.pressStart2p(
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
                        style: GoogleFonts.pressStart2p(
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
                        style: GoogleFonts.pressStart2p(
                          fontSize: 10,
                          color: Colors.white,
                        ),
                      ),
                    );
                  },

                  // 이벤트 마커 빌더 수정
                  markerBuilder: (context, date, events) {
                    if (events.isEmpty) return const SizedBox.shrink();

                    // 여러 이벤트의 경우 최대 n개만 표시
                    // markersMaxCount를 같이 수정해야 함
                    final displayedEvents =
                        events.length > 6 ? events.sublist(0, 6) : events;

                    // 이벤트 텍스트 리스트 생성
                    return Positioned(
                      bottom: 4, // 셀 하단에 배치
                      left: 4,
                      right: 4,
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.stretch, // 너비 꽉 차게
                        mainAxisSize: MainAxisSize.min,
                        children:
                            displayedEvents.map((event) {
                              // String으로 명시적 타입 변환
                              final eventString = event.toString();

                              // 이벤트별 색상 가져오기
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
                                  eventString, // String으로 변환된 이벤트 텍스트 사용
                                  style: GoogleFonts.pressStart2p(
                                    fontSize: 10, // 작은 폰트 크기
                                    color: Colors.white,
                                  ),
                                  overflow:
                                      TextOverflow.ellipsis, // 길 경우 ... 처리
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
            Container(
              color: Colors.black.withOpacity(0.5), // 반투명 배경
              width: double.infinity,
              height: double.infinity,
              child: Center(
                child: Container(
                  width: 300, // 팝업 리스트의 너비 부분
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: Colors.black, width: 4),
                  ),
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    mainAxisSize: MainAxisSize.min, // 내용에 맞게 크기 조정
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
                              '${DateFormat('yyyy.MM.dd').format(_selectedDay)}의 이벤트',
                              style: GoogleFonts.pressStart2p(
                                fontSize: 8,
                                color: Colors.white,
                              ),
                            ),
                            Row(
                              children: [
                                GestureDetector(
                                  onTap: _showAddEventDialog,
                                  child: Container(
                                    width: 20,
                                    height: 20,
                                    decoration: BoxDecoration(
                                      color: Colors.green,
                                      border: Border.all(
                                        color: Colors.white,
                                        width: 1,
                                      ),
                                    ),
                                    alignment: Alignment.center,
                                    child: Text(
                                      '+',
                                      style: GoogleFonts.pressStart2p(
                                        fontSize: 8,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                GestureDetector(
                                  onTap: _hideEventDialog,
                                  child: Container(
                                    width: 20,
                                    height: 20,
                                    decoration: BoxDecoration(
                                      color: Colors.red,
                                      border: Border.all(
                                        color: Colors.white,
                                        width: 1,
                                      ),
                                    ),
                                    alignment: Alignment.center,
                                    child: Text(
                                      'X',
                                      style: GoogleFonts.pressStart2p(
                                        fontSize: 8,
                                        color: Colors.white,
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
                        width: 700, // 기본 너비 지정 -> _showEventPopup에서도 수정해야 함
                        constraints: const BoxConstraints(
                          maxHeight:
                              300, // 최대 높이 제한 -> 빈 이벤트에 최대치가 그대로 반영되는 문제 있음
                          maxWidth: 700,
                        ),
                        child:
                            _getEventsForDay(_selectedDay)
                                    .isEmpty // 비어있을 경우
                                ? Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Center(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Image.asset(
                                          'assets/images/balloon (1).gif', // 이미지 경로
                                          width: 150, // 원하는 크기로 조정
                                          height: 150, // 원하는 크기로 조정
                                        ),
                                        const SizedBox(
                                          height: 24,
                                        ), // 이미지와 텍스트 사이 간격
                                        Text(
                                          '할 일이 없어. 아직은..',
                                          style: GoogleFonts.pressStart2p(
                                            fontSize: 10,
                                            color: Colors.grey,
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                      ],
                                    ),
                                  ),
                                )
                                : ListView.builder(
                                  shrinkWrap: true,
                                  itemCount:
                                      _getEventsForDay(_selectedDay).length,
                                  itemBuilder: (context, index) {
                                    final event =
                                        _getEventsForDay(_selectedDay)[index];
                                    // String으로 명시적 타입 변환 (필요한 경우)
                                    final eventString = event.toString();

                                    // 이벤트별 색상 가져오기
                                    final bgColor =
                                        _eventColors[eventString] ?? _colors[0];

                                    return Container(
                                      margin: const EdgeInsets.symmetric(
                                        vertical: 4,
                                      ),
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: bgColor.withOpacity(0.2),
                                        border: Border.all(
                                          color: bgColor,
                                          width: 2,
                                        ),
                                      ),
                                      child: Text(
                                        eventString,
                                        style: GoogleFonts.pressStart2p(
                                          fontSize: 10, // 이벤트 리스트의 폰트 크기
                                          color: Colors.black,
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
            ),

          // 타임테이블 팝업 오버레이
          if (_showTimeTablePopup)
            Container(
              color: Colors.black.withOpacity(0.5), // 반투명 배경
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
                    mainAxisSize: MainAxisSize.min, // 내용에 맞게 크기 조정
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
                              '${DateFormat('yyyy.MM.dd').format(_selectedDay)}의 시간표',
                              style: GoogleFonts.pressStart2p(
                                fontSize: 8,
                                color: Colors.white,
                              ),
                            ),
                            Row(
                              children: [
                                GestureDetector(
                                  onTap: _showAddTimeSlotDialog,
                                  child: Container(
                                    width: 20,
                                    height: 20,
                                    decoration: BoxDecoration(
                                      color: Colors.green,
                                      border: Border.all(
                                        color: Colors.white,
                                        width: 1,
                                      ),
                                    ),
                                    alignment: Alignment.center,
                                    child: Text(
                                      '+',
                                      style: GoogleFonts.pressStart2p(
                                        fontSize: 8,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                GestureDetector(
                                  onTap: _hideTimeTableDialog,
                                  child: Container(
                                    width: 20,
                                    height: 20,
                                    decoration: BoxDecoration(
                                      color: Colors.red,
                                      border: Border.all(
                                        color: Colors.white,
                                        width: 1,
                                      ),
                                    ),
                                    alignment: Alignment.center,
                                    child: Text(
                                      'X',
                                      style: GoogleFonts.pressStart2p(
                                        fontSize: 8,
                                        color: Colors.white,
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
                        constraints: const BoxConstraints(
                          maxHeight: 300, // 최대 높이 제한
                        ),
                        child:
                            _getTimeSlotsForDay(_selectedDay).isEmpty
                                ? Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Center(
                                    child: Text(
                                      '일정이 없습니다',
                                      style: GoogleFonts.pressStart2p(
                                        fontSize: 10,
                                        color: Colors.grey,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                )
                                : ListView.builder(
                                  shrinkWrap: true,
                                  itemCount:
                                      _getTimeSlotsForDay(_selectedDay).length,
                                  itemBuilder: (context, index) {
                                    final slot =
                                        _getTimeSlotsForDay(
                                          _selectedDay,
                                        )[index];
                                    return Container(
                                      margin: const EdgeInsets.symmetric(
                                        vertical: 4,
                                      ),
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: slot.color.withOpacity(0.2),
                                        border: Border.all(
                                          color: slot.color,
                                          width: 2,
                                        ),
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
                                                  style:
                                                      GoogleFonts.pressStart2p(
                                                        fontSize: 10,
                                                        color: Colors.black,
                                                      ),
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  '${slot.startTime} - ${slot.endTime}',
                                                  style:
                                                      GoogleFonts.pressStart2p(
                                                        fontSize: 8,
                                                        color: Colors.grey[800],
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
            ),

          // 움직이는 GIF 버튼
          Positioned(
            left: _buttonLeft,
            top: _buttonTop,
            child: GestureDetector(
              onTap: _navigateToEmptyPage,
              child: Container(
                width: _buttonSize,
                height: _buttonSize,
                child: Image.asset(
                  'assets/images/original (2).gif',
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
