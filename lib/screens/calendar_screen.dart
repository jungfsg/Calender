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
import '../services/google_calendar_service.dart';
import '../widgets/event_popup.dart';
import '../widgets/time_table_popup.dart';
import '../widgets/moving_button.dart';
import '../widgets/weather_calendar_cell.dart';
import '../widgets/weather_icon.dart';
import '../widgets/weather_summary_popup.dart';
import '../widgets/side_menu.dart';
import '../widgets/common_navigation_bar.dart';
import '../services/auth_service.dart';
import 'login_screen.dart';

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
  int _selectedIndex = 0; // 현재 선택된 네비게이션 바 인덱스
  final Random _random = Random(); // Random 객체 추가

  // Google Calendar 서비스
  final GoogleCalendarService _googleCalendarService = GoogleCalendarService();
  bool _isSyncing = false; // 동기화 진행 상태

  // 날씨 정보 캐시
  final Map<String, WeatherInfo> _weatherCache = {};
  List<WeatherInfo> _weatherForecast = []; // 10일간 예보 데이터
  bool _loadingWeather = false;

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

  // AuthService 인스턴스 추가
  final AuthService _authService = AuthService();

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

    // 위치 권한 요청
    _requestLocationPermission();

    // 날씨 정보 로드 (딱 한 번만 실행)
    _loadWeatherData();

    // Google Calendar 서비스 초기화 시도 (백그라운드에서)
    _initializeGoogleCalendarService();
  }

  // Google Calendar 서비스 초기화 (백그라운드)
  Future<void> _initializeGoogleCalendarService() async {
    try {
      // 이미 로그인된 사용자가 있는지 확인
      if (_googleCalendarService.hasSignedInUser) {
        await _googleCalendarService.initialize();
        print('Google Calendar 서비스가 자동으로 초기화되었습니다.');
        
        // 초기화 성공 시 공휴일 자동 로드
        _loadHolidaysInBackground();
      }
    } catch (e) {
      print('Google Calendar 자동 초기화 실패: $e');
      // 실패해도 앱 사용에는 문제없으므로 에러 메시지는 표시하지 않음
    }
  }

  // 백그라운드에서 공휴일 로드
  Future<void> _loadHolidaysInBackground() async {
    try {
      print('백그라운드에서 공휴일을 로드합니다...');
      
      // 현재 년도의 공휴일 로드
      final DateTime startOfYear = DateTime(_focusedDay.year, 1, 1);
      final DateTime endOfYear = DateTime(_focusedDay.year, 12, 31);
      
      // 이미 로드된 공휴일이 있는지 확인 (성능 최적화)
      bool hasExistingHolidays = false;
      for (int month = 1; month <= 12; month++) {
        final daysInMonth = DateTime(_focusedDay.year, month + 1, 0).day;
        for (int day = 1; day <= daysInMonth; day++) {
          final date = DateTime(_focusedDay.year, month, day);
          final dateKey = _getKey(date);
          await _loadEventsForDay(date);
          if (_events.containsKey(dateKey)) {
            final events = _events[dateKey]!;
            if (events.any((e) => e.title.startsWith('🎌'))) {
              hasExistingHolidays = true;
              break;
            }
          }
        }
        if (hasExistingHolidays) break;
      }

      // 이미 공휴일이 로드되어 있으면 스킵
      if (hasExistingHolidays) {
        print('공휴일이 이미 로드되어 있습니다. 백그라운드 로드를 스킵합니다.');
        return;
      }
      
      final holidays = await _googleCalendarService.getKoreanHolidays(
        startDate: startOfYear,
        endDate: endOfYear,
      );

      // 공휴일을 로컬 캐시에 추가
      int addedHolidayCount = 0;
      for (var holiday in holidays) {
        final normalizedDay = DateTime(holiday.date.year, holiday.date.month, holiday.date.day);
        final dateKey = _getKey(normalizedDay);

        // 중복 체크
        final existingEvents = _events[dateKey] ?? [];
        final isDuplicate = existingEvents.any((e) => 
          e.title == holiday.title && 
          e.time == holiday.time &&
          e.date.day == holiday.date.day &&
          e.date.month == holiday.date.month &&
          e.date.year == holiday.date.year
        );

        if (!isDuplicate) {
          // 로컬 저장소에 저장
          await EventStorageService.addEvent(normalizedDay, holiday);
          
          // 캐시에 직접 추가
          if (!_events.containsKey(dateKey)) {
            _events[dateKey] = [];
          }
          _events[dateKey]!.add(holiday);

          // 공휴일 색상 할당 (빨간색 계열)
          if (!_eventColors.containsKey(holiday.title)) {
            _eventColors[holiday.title] = Colors.red;
          }
          
          addedHolidayCount++;
        }
      }

      if (addedHolidayCount > 0) {
        print('${addedHolidayCount}개의 공휴일이 백그라운드에서 로드되었습니다.');
        // UI 갱신
        if (mounted) {
          setState(() {});
        }
      } else {
        print('새로 추가된 공휴일이 없습니다.');
      }
    } catch (e) {
      print('백그라운드 공휴일 로드 실패: $e');
      // 실패해도 앱 사용에는 문제없음
    }
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

    try {
      // 로컬에 이벤트 저장
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

      // Google Calendar에도 이벤트 추가 시도
      try {
        if (_googleCalendarService.isSignedIn) {
          final success = await _googleCalendarService.addEventToGoogleCalendar(event);
          if (success) {
            _showSnackBar('일정이 Google Calendar에도 추가되었습니다.');
          } else {
            _showSnackBar('Google Calendar 추가에 실패했습니다.');
          }
        } else {
          // Google Calendar에 로그인되어 있지 않은 경우 초기화 시도
          final initialized = await _googleCalendarService.initialize();
          if (initialized) {
            final success = await _googleCalendarService.addEventToGoogleCalendar(event);
            if (success) {
              _showSnackBar('일정이 Google Calendar에도 추가되었습니다.');
            } else {
              _showSnackBar('Google Calendar 추가에 실패했습니다.');
            }
          } else {
            _showSnackBar('Google Calendar 연동이 필요합니다. 사이드바에서 동기화를 먼저 실행해주세요.');
          }
        }
      } catch (e) {
        print('Google Calendar 추가 오류: $e');
        _showSnackBar('Google Calendar 추가 중 오류가 발생했습니다.');
      }

      // UI 즉시 갱신
      if (mounted) {
        setState(() {
          _focusedDay = normalizedDay;
          _selectedDay = normalizedDay;
        });
      }

      print('이벤트 추가 완료: ${event.title}');
    } catch (e) {
      print('이벤트 추가 오류: $e');
      _showSnackBar('일정 추가에 실패했습니다.');
    }
  }

  // 이벤트 삭제
  Future _removeEvent(Event event) async {
    final normalizedDay = DateTime(
      event.date.year,
      event.date.month,
      event.date.day,
    );
    final dateKey = _getKey(normalizedDay);

    try {
      // 로컬에서 이벤트 삭제
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

      // Google Calendar에서도 이벤트 삭제 시도
      try {
        if (_googleCalendarService.isSignedIn) {
          final success = await _googleCalendarService.deleteEventFromGoogleCalendar(event);
          if (success) {
            _showSnackBar('일정이 Google Calendar에서도 삭제되었습니다.');
          } else {
            _showSnackBar('Google Calendar에서 해당 일정을 찾을 수 없습니다.');
          }
        } else {
          _showSnackBar('Google Calendar 연동이 필요합니다.');
        }
      } catch (e) {
        print('Google Calendar 삭제 오류: $e');
        _showSnackBar('Google Calendar 삭제 중 오류가 발생했습니다.');
      }

      // UI 즉시 갱신
      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      print('이벤트 삭제 오류: $e');
      _showSnackBar('일정 삭제에 실패했습니다.');
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
    super.dispose();
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
    // 지역 변수가 아닌 StatefulWidget의 상태로 만들기 위한 변수 선언
    TimeOfDay selectedTime = TimeOfDay.now();

    showDialog(
      context: context,
      builder:
          (context) => StatefulBuilder(
            builder:
                (context, setState) => AlertDialog(
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
                                // StatefulBuilder의 setState 호출로 UI 업데이트
                                setState(() {
                                  selectedTime = picked;
                                });
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

  // 네비게이션 바 아이템 탭 처리
  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });

    switch (index) {
      case 0: // 캘린더 - 현재 화면이므로 아무 작업 없음
        break;
      case 1: // 가운데 버튼 - 아직 기능 미정
        break;
      case 2: // 채팅 화면
        _navigateToEmptyPage();
        break;
    }
  }

  // Google Calendar 동기화
  Future<void> _syncWithGoogleCalendar() async {
    if (_isSyncing) {
      _showSnackBar('이미 동기화가 진행 중입니다.');
      return;
    }

    setState(() {
      _isSyncing = true;
    });

    try {
      _showSnackBar('Google Calendar와 동기화 중... (1년치 데이터)');

      // 현재 연도의 시작과 끝 날짜 계산
      final DateTime startOfYear = DateTime(_focusedDay.year, 1, 1);
      final DateTime endOfYear = DateTime(_focusedDay.year, 12, 31);

      print('동기화 범위: ${startOfYear.toString()} ~ ${endOfYear.toString()}');

      // Google Calendar에서 이벤트 가져오기 (공휴일 포함)
      final List<Event> googleEvents = await _googleCalendarService.syncWithGoogleCalendarIncludingHolidays(
        startDate: startOfYear,
        endDate: endOfYear,
      );

      // 현재 연도의 모든 로컬 이벤트 수집
      Map<String, List<Event>> currentYearEvents = {};
      
      // 1월부터 12월까지 모든 월의 이벤트 수집
      for (int month = 1; month <= 12; month++) {
        final daysInMonth = DateTime(_focusedDay.year, month + 1, 0).day;
        for (int day = 1; day <= daysInMonth; day++) {
          final date = DateTime(_focusedDay.year, month, day);
          final dateKey = _getKey(date);
          await _loadEventsForDay(date); // 해당 날짜의 이벤트 로드
          if (_events.containsKey(dateKey) && _events[dateKey]!.isNotEmpty) {
            currentYearEvents[dateKey] = List.from(_events[dateKey]!);
          }
        }
      }

      // 1. Google Calendar에서 가져온 이벤트를 로컬에 추가 (기존 로직)
      int addedCount = 0;
      for (var event in googleEvents) {
        final normalizedDay = DateTime(event.date.year, event.date.month, event.date.day);
        final dateKey = _getKey(normalizedDay);

        // 중복 체크 (같은 제목과 시간의 이벤트가 이미 있는지 확인)
        final existingEvents = _events[dateKey] ?? [];
        final isDuplicate = existingEvents.any((e) => 
          e.title == event.title && 
          e.time == event.time &&
          e.date.day == event.date.day &&
          e.date.month == event.date.month &&
          e.date.year == event.date.year
        );

        if (!isDuplicate) {
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

          addedCount++;
        }
      }

      // 2. Google Calendar에서 삭제된 이벤트를 로컬에서도 삭제 (새로운 로직)
      int deletedCount = 0;
      for (var dateKey in currentYearEvents.keys) {
        final localEvents = currentYearEvents[dateKey]!;
        final eventsToDelete = <Event>[];

        for (var localEvent in localEvents) {
          // Google Calendar에 동일한 이벤트가 있는지 확인
          final existsInGoogle = googleEvents.any((googleEvent) =>
            googleEvent.title == localEvent.title &&
            googleEvent.time == localEvent.time &&
            googleEvent.date.day == localEvent.date.day &&
            googleEvent.date.month == localEvent.date.month &&
            googleEvent.date.year == localEvent.date.year
          );

          // Google Calendar에 없으면 로컬에서 삭제 대상으로 표시
          if (!existsInGoogle) {
            eventsToDelete.add(localEvent);
          }
        }

        // 삭제 대상 이벤트들을 실제로 삭제
        for (var eventToDelete in eventsToDelete) {
          final normalizedDay = DateTime(
            eventToDelete.date.year,
            eventToDelete.date.month,
            eventToDelete.date.day,
          );
          
          // 로컬 저장소에서 삭제
          await EventStorageService.removeEvent(normalizedDay, eventToDelete);
          
          // 캐시에서도 삭제
          if (_events.containsKey(dateKey)) {
            _events[dateKey]!.removeWhere((e) =>
              e.title == eventToDelete.title &&
              e.time == eventToDelete.time &&
              e.date.year == eventToDelete.date.year &&
              e.date.month == eventToDelete.date.month &&
              e.date.day == eventToDelete.date.day
            );
          }
          
          deletedCount++;
          print('Google Calendar에서 삭제된 이벤트를 로컬에서도 삭제: ${eventToDelete.title}');
        }
      }

      // 결과 메시지 표시
      String resultMessage = '${_focusedDay.year}년 전체 동기화 완료!';
      if (addedCount > 0 && deletedCount > 0) {
        resultMessage += ' ${addedCount}개 추가, ${deletedCount}개 삭제되었습니다.';
      } else if (addedCount > 0) {
        resultMessage += ' ${addedCount}개의 새 이벤트가 추가되었습니다.';
      } else if (deletedCount > 0) {
        resultMessage += ' ${deletedCount}개의 이벤트가 삭제되었습니다.';
      } else {
        resultMessage += ' 변경사항이 없습니다.';
      }
      
      _showSnackBar(resultMessage);
      
      // UI 갱신
      setState(() {});

    } catch (e) {
      print('Google Calendar 동기화 오류: $e');
      _showSnackBar('Google Calendar 동기화에 실패했습니다: ${e.toString()}');
    } finally {
      setState(() {
        _isSyncing = false;
      });
    }
  }

  // 스낵바 표시 헬퍼 메서드
  void _showSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            message,
            style: getTextStyle(fontSize: 12, color: Colors.white),
          ),
          backgroundColor: Colors.black87,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  // 로그아웃 처리 메서드 추가
  Future<void> _handleLogout() async {
    try {
      // AuthService를 통해 로그아웃 실행
      await _authService.logout();
      
      // 로그인 화면으로 이동 (모든 이전 화면 제거)
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (context) => const LoginScreen(),
          ),
          (route) => false, // 모든 이전 라우트 제거
        );
      }
    } catch (e) {
      print('로그아웃 중 오류 발생: $e');
      // 오류가 발생해도 로그인 화면으로 이동
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (context) => const LoginScreen(),
          ),
          (route) => false,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // 현재 월의 주 수 계산
    final DateTime firstDay = DateTime(_focusedDay.year, _focusedDay.month, 1);
    final DateTime lastDay = DateTime(
      _focusedDay.year,
      _focusedDay.month + 1,
      0,
    );

    // 주 시작일에 맞는 요일 오프셋 계산
    final int firstWeekday = (firstDay.weekday % 7); // 0: 일, 1: 월, ... 6: 토
    // 마지막 날의 날짜
    final int lastDate = lastDay.day;

    // 정확한 주 수 계산
    final int totalWeeks = ((firstWeekday + lastDate) / 7).ceil();

    return Scaffold(
      resizeToAvoidBottomInset: false, // 키보드가 올라올 때 화면 리사이즈 방지
      backgroundColor: const Color.fromARGB(255, 162, 222, 141),
      drawer: CalendarSideMenu(
        onWeatherForecastTap: _showWeatherForecastDialog,
        onGoogleCalendarSyncTap: _syncWithGoogleCalendar,
        onLogoutTap: _handleLogout, // 로그아웃 콜백 추가
        isGoogleCalendarConnected: _googleCalendarService.isSignedIn,
      ),
      body: SafeArea(
        bottom: false, // 하단 SafeArea는 적용하지 않음 (네비게이션 바가 차지)
        child: LayoutBuilder(
          builder: (context, constraints) {
            // 사용 가능한 화면 높이 (네비게이션 바 제외)
            final availableHeight = constraints.maxHeight;

            // 연/월 표시 헤더 높이 (타이틀 텍스트 + 패딩 + 마진)
            const monthHeaderHeight = 65.0; // 대략적인 연/월 헤더 높이

            // 요일 헤더 높이
            const dayOfWeekHeaderHeight = 35.0;

            // 각 주의 높이 계산 (가용 높이에서 두 헤더 높이와 패딩 제외)
            final weekHeight =
                (availableHeight -
                    monthHeaderHeight -
                    dayOfWeekHeaderHeight -
                    16.0) /
                totalWeeks;

            return Stack(
              children: [
                // 캘린더 부분
                Padding(
                  padding: const EdgeInsets.fromLTRB(3.0, 3.0, 3.0, 0),
                  child: Container(
                    color: Colors.white,
                    child: TableCalendar(
                      firstDay: DateTime.utc(2020, 1, 1),
                      lastDay: DateTime.utc(2030, 12, 31),
                      focusedDay: _focusedDay,
                      calendarFormat: _calendarFormat,
                      daysOfWeekHeight: dayOfWeekHeaderHeight,
                      rowHeight: weekHeight,
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
                        leftChevronVisible: false,
                        rightChevronVisible: false,
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
                        ),
                        todayDecoration: BoxDecoration(
                          color: Colors.amber[300],
                        ),
                        defaultDecoration: const BoxDecoration(),
                        weekendDecoration: const BoxDecoration(
                          color: Color(0xFFEEEEEE),
                        ),
                        outsideDecoration: const BoxDecoration(
                          color: Color(0xFFDDDDDD),
                        ),
                        tableBorder: TableBorder.all(
                          color: const Color.fromARGB(24, 0, 0, 0),
                          width: 1,
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
                            '월',
                            '화',
                            '수',
                            '목',
                            '금',
                            '토',
                            '일',
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
                            decoration: const BoxDecoration(
                              color: Color(0xFFEEEEEE),
                              // 테두리 제거
                            ),
                            alignment: Alignment.center,
                            padding: const EdgeInsets.symmetric(vertical: 8.0),
                            child: Text(
                              weekdayNames[weekdayIndex],
                              style: getTextStyle(
                                fontSize: 14, // 글씨 크기 키움
                                color: textColor,
                                text: weekdayNames[weekdayIndex],
                              ),
                            ),
                          );
                        },
                        // 헤더 타이틀 빌더 - 날씨 버튼 제거
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
                          return Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              // 햄버거 메뉴 아이콘 추가
                              IconButton(
                                icon: const Icon(
                                  Icons.menu,
                                  color: Colors.black,
                                ),
                                onPressed: () {
                                  Scaffold.of(context).openDrawer();
                                },
                              ),
                              // 연/월 표시 박스 제거하고 텍스트만 표시
                              Expanded(
                                child: Center(
                                  child: Text(
                                    '${month.year}년 ${monthNames[month.month - 1]}',
                                    style: getTextStyle(
                                      fontSize: 20,
                                      color: Colors.black,
                                    ),
                                  ),
                                ),
                              ),
                              // 여백을 위한 빈 아이콘 버튼
                              const IconButton(
                                icon: Icon(
                                  Icons.menu,
                                  color: Colors.transparent,
                                ),
                                onPressed: null,
                              ),
                            ],
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
            );
          },
        ),
      ),

      // 네비게이션 바
      bottomNavigationBar: CommonNavigationBar(
        selectedIndex: _selectedIndex,
        onItemTapped: _onItemTapped,
      ),
    );
  }
}
