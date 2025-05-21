import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import 'dart:math';
import 'package:permission_handler/permission_handler.dart';
import 'package:geolocator/geolocator.dart';
import 'empty_page.dart';
import '../utils/font_utils.dart';

import '../models/time_slot.dart';
import '../models/event.dart';
import '../models/weather_info.dart';
import '../services/event_storage_service.dart';
import '../services/weather_service.dart';
import '../widgets/event_popup.dart';
import '../widgets/time_table_popup.dart';
import '../widgets/moving_button.dart';
import '../widgets/weather_calendar_cell.dart';
import '../widgets/weather_icon.dart';
import '../widgets/weather_summary_popup.dart';

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
  bool _showWeatherPopup = false; // 날씨 예보 팝업 표시 여부

  // 날씨 정보 캐시
  final Map<String, WeatherInfo> _weatherCache = {};
  List<WeatherInfo> _weatherForecast = []; // 10일간 예보 데이터
  bool _loadingWeather = false;

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
  final Map<String, List<Event>> _events = {};
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

  // 클래스 변수로 추가
  OverlayEntry? _buttonOverlay;

  @override
  void initState() {
    super.initState();
    _focusedDay = DateTime.now();
    _selectedDay = DateTime.now();
    _calendarFormat = CalendarFormat.month; // 기본 월 형식으로 고정
    // 저장된 모든 키 확인
    EventStorageService.printAllKeys();
    // 초기 데이터 로드
    _loadInitialData();
    // 움직이는 버튼 초기 위치 설정
    _startButtonMovement();

    // 위치 권한 요청
    _requestLocationPermission();

    // 날씨 정보 로드 (딱 한 번만 실행)
    _loadWeatherData();

    // 1분마다 날씨 정보 업데이트하는 코드 제거

    // 포스트 프레임 콜백을 사용하여 화면이 그려진 후 Overlay 추가
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _createButtonOverlay();
    });
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
  void _assignColorsToEvents(List<Event> events) {
    int colorIndex = 0;
    for (var event in events) {
      if (!_eventColors.containsKey(event.title)) {
        _eventColors[event.title] = _colors[colorIndex % _colors.length];
        colorIndex++;
      }
    }
  }

  // 이벤트 추가
  Future _addEvent(Event event) async {
    print('이벤트 추가: ${event.title}, 시간: ${event.time}, 날짜: ${event.date}');
    final normalizedDay = DateTime(
      event.date.year,
      event.date.month,
      event.date.day,
    );
    final dateKey = _getKey(normalizedDay);

    // 이벤트 저장
    await EventStorageService.addEvent(normalizedDay, event);

    // 캐시에 직접 이벤트 추가
    if (!_events.containsKey(dateKey)) {
      _events[dateKey] = [];
    }
    _events[dateKey]!.add(event);

    // 이벤트 색상 할당
    if (!_eventColors.containsKey(event.title)) {
      _eventColors[event.title] = _colors[_eventColors.length % _colors.length];
    }

    // UI 즉시 갱신
    if (mounted) {
      setState(() {
        _focusedDay = normalizedDay;
        _selectedDay = normalizedDay;
      });
    }

    print('이벤트 추가 완료: ${event.title}');
  }

  // 이벤트 삭제
  Future _removeEvent(Event event) async {
    final normalizedDay = DateTime(
      event.date.year,
      event.date.month,
      event.date.day,
    );
    final dateKey = _getKey(normalizedDay);

    // 이벤트 삭제
    await EventStorageService.removeEvent(normalizedDay, event);

    // 캐시에서 직접 이벤트 제거
    if (_events.containsKey(dateKey)) {
      _events[dateKey]!.removeWhere(
        (e) =>
            e.title == event.title &&
            e.time == event.time &&
            e.date.year == event.date.year &&
            e.date.month == event.date.month &&
            e.date.day == event.date.day,
      );

      // 해당 날짜의 이벤트가 모두 삭제된 경우 빈 배열로 설정
      if (_events[dateKey]!.isEmpty) {
        _events[dateKey] = [];
      }
    }

    // UI 즉시 갱신
    if (mounted) {
      setState(() {});
    }
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
    // Overlay 제거
    _buttonOverlay?.remove();
    _buttonOverlay = null;
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

    // 고양이 버튼이 움직일 때 계산되는 패딩값
    final screenPadding = 3.0;

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

    // Overlay 업데이트
    _buttonOverlay?.markNeedsBuild();
  }

  // 빈 페이지로 이동
  void _navigateToEmptyPage() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const EmptyPage()),
    );
  }

  // 날짜별 이벤트 가져오기
  List<Event> _getEventsForDay(DateTime day) {
    final normalizedDay = DateTime(day.year, day.month, day.day);
    final dateKey = _getKey(normalizedDay);

    if (!_events.containsKey(dateKey) && !_loadingDates.contains(dateKey)) {
      _loadingDates.add(dateKey);
      _loadEventsForDay(normalizedDay).then((_) {
        setState(() {
          _loadingDates.remove(dateKey);
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
    final TextEditingController _titleController = TextEditingController();
    TimeOfDay selectedTime = TimeOfDay.now();

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(
              '새 일정 추가',
              style: getTextStyle(
                fontSize: 14,
                color: Colors.black,
                text: '새 일정 추가',
              ),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: _titleController,
                  decoration: InputDecoration(
                    hintText: '일정 제목',
                    hintStyle: getTextStyle(fontSize: 12, text: '일정 제목'),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '시간 선택:',
                      style: getTextStyle(
                        fontSize: 12,
                        color: Colors.black,
                        text: '시간 선택:',
                      ),
                    ),
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
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              ),
                              child: child!,
                            );
                          },
                        );
                        if (picked != null) {
                          selectedTime = picked;
                          Navigator.pop(context);
                          _showAddEventDialog(); // 시간 선택 후 다이얼로그 다시 표시
                        }
                      },
                      child: Text(
                        '${selectedTime.hour.toString().padLeft(2, '0')}:${selectedTime.minute.toString().padLeft(2, '0')}',
                        style: getTextStyle(
                          fontSize: 12,
                          color: Colors.blue,
                          text:
                              '${selectedTime.hour.toString().padLeft(2, '0')}:${selectedTime.minute.toString().padLeft(2, '0')}',
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  '취소',
                  style: getTextStyle(
                    fontSize: 12,
                    color: Colors.black,
                    text: '취소',
                  ),
                ),
              ),
              TextButton(
                onPressed: () async {
                  if (_titleController.text.isNotEmpty) {
                    final event = Event(
                      title: _titleController.text,
                      time:
                          '${selectedTime.hour.toString().padLeft(2, '0')}:${selectedTime.minute.toString().padLeft(2, '0')}',
                      date: _selectedDay,
                    );

                    await _addEvent(event);
                    Navigator.pop(context);
                  }
                },
                child: Text(
                  '추가',
                  style: getTextStyle(
                    fontSize: 12,
                    color: Colors.black,
                    text: '추가',
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
              style: getTextStyle(
                fontSize: 14,
                color: Colors.black,
                text: '새 일정 추가',
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
                  style: getTextStyle(
                    fontSize: 10,
                    color: Colors.black,
                    text: '취소',
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
                  style: getTextStyle(
                    fontSize: 10,
                    color: Colors.black,
                    text: '추가',
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

  // uc704uce58 uad8cud55c uc694uccad
  Future<void> _requestLocationPermission() async {
    print('위치 권한 요청 시작');
    final permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      print('위치 권한 요청하는 중...');
      final result = await Geolocator.requestPermission();
      print('위치 권한 요청 결과: $result');

      if (result == LocationPermission.denied ||
          result == LocationPermission.deniedForever) {
        // 사용자에게 권한이 필요하다고 알림
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('날씨 정보를 받으려면 위치 권한이 필요합니다')));
      } else {
        // 권한을 얻었으니 날씨 로드 재시도
        _loadWeatherData();
      }
    } else if (permission == LocationPermission.deniedForever) {
      print('위치 권한이 영구 거부됨');
      // 설정으로 이동하도록 안내
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('위치 권한이 영구적으로 거부되었습니다. 설정에서 변경해주세요.'),
          action: SnackBarAction(
            label: '설정',
            onPressed: () async {
              await Geolocator.openAppSettings();
            },
          ),
        ),
      );
    } else {
      print('위치 권한 이미 있음: $permission');
    }
  }

  // 날씨 정보 로드
  Future<void> _loadWeatherData({bool forceRefresh = false}) async {
    print('날씨 정보 로드 시작');
    if (_loadingWeather) {
      print('이미 로드 중');
      return;
    }

    setState(() {
      _loadingWeather = true;
    });

    try {
      // 이미 날씨 데이터가 있고 강제 새로고침이 아니면 다시 로드하지 않음
      if (_weatherForecast.isNotEmpty && !forceRefresh) {
        print('날씨 데이터가 이미 로드되어 있습니다.');
        setState(() {
          _loadingWeather = false;
        });
        return;
      }

      final weatherList = await WeatherService.get5DayForecast();
      print('가져온 날씨 수: ${weatherList.length}');

      if (mounted) {
        setState(() {
          // 사이클 날씨 처리를 위해 캐시 새로 초기화
          _weatherCache.clear();
          _weatherForecast = weatherList; // 5일 예보 데이터 저장

          for (var weather in weatherList) {
            _weatherCache[weather.date] = weather;
            print('날씨 캐시 추가: ${weather.date}, ${weather.condition}');
          }
          _loadingWeather = false;
        });

        // 업데이트 후 캘린더 화면 새로 그리기
        setState(() {});
      }
    } catch (e) {
      print('날씨 데이터 로드 오류: $e');
      if (mounted) {
        setState(() {
          _loadingWeather = false;
        });
      }
    }
  }

  // 특정 날짜의 날씨 정보 가져오기
  WeatherInfo? _getWeatherForDay(DateTime day) {
    final dateKey = DateFormat('yyyy-MM-dd').format(day);
    final weatherInfo = _weatherCache[dateKey];

    // 테스트 데이터 (날씨 정보가 없는 경우 더미 데이터 제공)
    if (weatherInfo == null &&
        dateKey == DateFormat('yyyy-MM-dd').format(DateTime.now())) {
      return WeatherInfo(
        date: dateKey,
        condition: 'sunny',
        temperature: 25.0,
        lat: 37.5665,
        lon: 126.9780,
      );
    }

    return weatherInfo;
  }

  // 날씨 예보 팝업 표시/숨김
  void _showWeatherForecastDialog() {
    setState(() {
      _showWeatherPopup = true;
      _showEventPopup = false;
      _showTimeTablePopup = false;
    });
  }

  void _hideWeatherForecastDialog() {
    setState(() {
      _showWeatherPopup = false;
    });
  }

  // Overlay 생성 및 삽입 메서드
  void _createButtonOverlay() {
    _buttonOverlay?.remove();
    _buttonOverlay = OverlayEntry(
      builder: (context) {
        return Positioned(
          left: _buttonLeft,
          // AppBar와 상태바 높이를 고려하여 top 위치 조정
          top:
              _buttonTop +
              AppBar().preferredSize.height +
              MediaQuery.of(context).padding.top,
          child: MovingButton(size: _buttonSize, onTap: _navigateToEmptyPage),
        );
      },
    );

    Overlay.of(context)?.insert(_buttonOverlay!);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 162, 222, 141),
      appBar: AppBar(
        title: Text(
          'Calender v250521',
          style: getTextStyle(
            fontSize: 14,
            color: Colors.white,
            text: 'Calender v250521',
          ),
        ),
        backgroundColor: Colors.black,
        actions: [
          // 날씨 예보 보기 버튼
          IconButton(
            icon: Icon(Icons.wb_sunny, color: Colors.white),
            onPressed: () {
              _showWeatherForecastDialog();
            },
            tooltip: '5일간 날씨 예보 보기',
          ),
          // 날씨 새로고침 버튼
          IconButton(
            icon: Icon(Icons.refresh, color: Colors.white),
            onPressed: () {
              _loadWeatherData(forceRefresh: true);
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text('날씨 정보를 업데이트하고 있습니다...')));
            },
            tooltip: '날씨 정보 새로 가져오기',
          ),
        ],
      ),
      body: Stack(
        children: [
          // 메인 콘텐츠
          Padding(
            padding: const EdgeInsets.all(3.0),
            // SingleChildScrollView를 제거하고 Expanded와 함께 사용
            child: Column(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(color: const Color(0xFFFFFFFF)),
                    child: TableCalendar(
                      firstDay: DateTime.utc(2020, 1, 1),
                      lastDay: DateTime.utc(2030, 12, 31),
                      focusedDay: _focusedDay,
                      calendarFormat: _calendarFormat,
                      daysOfWeekHeight: 35.0,
                      // TableCalendar는 null을 허용하지 않으므로 계산식 사용
                      rowHeight:
                          (MediaQuery.of(context).size.height -
                              AppBar().preferredSize.height -
                              MediaQuery.of(context).padding.top -
                              MediaQuery.of(context).padding.bottom -
                              35.0 -
                              20.0) /
                          6, // 최대 6주 기준으로 계산
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
                      eventLoader:
                          (day) =>
                              _getEventsForDay(
                                day,
                              ).map((e) => e.title).toList(),
                      startingDayOfWeek: StartingDayOfWeek.sunday,
                      headerStyle: HeaderStyle(
                        titleTextStyle: getTextStyle(
                          fontSize: 12,
                          color: Colors.black,
                          text: '달력 제목',
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
                        weekdayStyle: getTextStyle(
                          fontSize: 8,
                          color: Colors.black,
                          text: 'Mon',
                        ),
                        weekendStyle: getTextStyle(
                          fontSize: 8,
                          color: const Color.fromARGB(255, 54, 184, 244),
                          text: 'Sat',
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEEEEEE),
                          border: Border.all(color: Colors.black, width: 1),
                        ),
                      ),
                      calendarStyle: CalendarStyle(
                        defaultTextStyle: getTextStyle(
                          fontSize: 8,
                          color: Colors.black,
                          text: '1',
                        ),
                        weekendTextStyle: getTextStyle(
                          fontSize: 8,
                          color: Colors.red,
                          text: '1',
                        ),
                        selectedTextStyle: getTextStyle(
                          fontSize: 8,
                          color: Colors.white,
                          text: '1',
                        ),
                        todayTextStyle: getTextStyle(
                          fontSize: 8,
                          color: Colors.black,
                          text: '1',
                        ),
                        outsideTextStyle: getTextStyle(
                          fontSize: 8,
                          color: const Color(0xFF888888),
                          text: '1',
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
                        tableBorder: TableBorder.all(
                          color: Colors.black,
                          width: 2,
                        ),
                        markersMaxCount: 6,
                        markersAlignment: Alignment.bottomCenter,
                        markerMargin: const EdgeInsets.only(top: 2),
                        markerDecoration: BoxDecoration(
                          color: Colors.transparent,
                        ),
                        markerSize: 0,
                      ),
                      calendarBuilders: CalendarBuilders(
                        // 기본 셀 빌더
                        defaultBuilder: (context, day, focusedDay) {
                          return WeatherCalendarCell(
                            day: day,
                            isSelected: false,
                            isToday: false,
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
                            events:
                                _getEventsForDay(
                                  day,
                                ).map((e) => e.title).toList(),
                            eventColors: _eventColors,
                            weatherInfo: _getWeatherForDay(day),
                          );
                        },
                        // 선택된 날짜 셀 빌더
                        selectedBuilder: (context, day, focusedDay) {
                          return WeatherCalendarCell(
                            day: day,
                            isSelected: true,
                            isToday: false,
                            onTap: () {
                              _showEventDialog();
                            },
                            onLongPress: () {
                              _showTimeTableDialog();
                            },
                            events:
                                _getEventsForDay(
                                  day,
                                ).map((e) => e.title).toList(),
                            eventColors: _eventColors,
                            weatherInfo: _getWeatherForDay(day),
                          );
                        },
                        // 오늘 날짜 셀 빌더
                        todayBuilder: (context, day, focusedDay) {
                          return WeatherCalendarCell(
                            day: day,
                            isSelected: false,
                            isToday: true,
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
                            events:
                                _getEventsForDay(
                                  day,
                                ).map((e) => e.title).toList(),
                            eventColors: _eventColors,
                            weatherInfo: _getWeatherForDay(day),
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
                          Color textColor;
                          if (day.weekday == DateTime.saturday) {
                            textColor = const Color.fromARGB(255, 54, 184, 244);
                          } else if (day.weekday == DateTime.sunday) {
                            textColor = Colors.red;
                          } else {
                            textColor = Colors.black;
                          }
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
                                color: textColor,
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
                              style: getTextStyle(
                                fontSize: 10,
                                color: Colors.white,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ],
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
              onDeleteEvent: (Event event) async {
                await _removeEvent(event);
                setState(() {});
              },
            ),

          // 타임테이블 팝업 오버레이
          if (_showTimeTablePopup)
            TimeTablePopup(
              selectedDay: _selectedDay,
              timeSlots: _getTimeSlotsForDay(_selectedDay),
              onClose: _hideTimeTableDialog,
              onAddTimeSlot: _showAddTimeSlotDialog,
            ),

          // 날씨 예보 팝업 오버레이
          if (_showWeatherPopup)
            WeatherSummaryPopup(
              weatherList: _weatherForecast,
              onClose: _hideWeatherForecastDialog,
            ),
        ],
      ),
    );
  }
}
