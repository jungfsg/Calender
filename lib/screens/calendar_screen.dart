import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import 'dart:math';
import 'package:permission_handler/permission_handler.dart';
import 'package:geolocator/geolocator.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'empty_page.dart';
import '../utils/font_utils.dart';

import '../models/time_slot.dart';
import '../models/event.dart';
import '../models/weather_info.dart';
import '../services/event_storage_service.dart';
import '../services/weather_service.dart';
import '../services/google_calendar_service.dart';
import '../services/chat_service.dart';
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
  const PixelArtCalendarScreen({super.key});

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
  // STT 관련 변수 추가
  late stt.SpeechToText _speech;
  bool _isListening = false;
  String _recognizedText = '';
  final ChatService _chatService = ChatService();
  bool _isProcessingSTT = false;
  StateSetter? _dialogSetState; // 다이얼로그 실시간 업데이트용

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

    // STT 초기화
    _speech = stt.SpeechToText();
    _initializeSpeech();

    // 이벤트 캐시 새로고침 (다른 화면에서 추가된 이벤트를 위해)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshCurrentMonthEvents();
    });
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
            if (events.any((e) => e.title.startsWith('🇰🇷'))) {
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
        final normalizedDay = DateTime(
          holiday.date.year,
          holiday.date.month,
          holiday.date.day,
        );
        final dateKey = _getKey(normalizedDay);

        // 중복 체크
        final existingEvents = _events[dateKey] ?? [];
        final isDuplicate = existingEvents.any(
          (e) =>
              e.title == holiday.title &&
              e.time == holiday.time &&
              e.date.day == holiday.date.day &&
              e.date.month == holiday.date.month &&
              e.date.year == holiday.date.year,
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
        print('$addedHolidayCount개의 공휴일이 백그라운드에서 로드되었습니다.');
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
        _eventColors[event.title] =
            _colors[_eventColors.length % _colors.length];
      }

      // Google Calendar에도 이벤트 추가 시도
      try {
        if (_googleCalendarService.isSignedIn) {
          final success = await _googleCalendarService.addEventToGoogleCalendar(
            event,
          );
          if (success) {
            _showSnackBar('일정이 Google Calendar에도 추가되었습니다.');
          } else {
            _showSnackBar('Google Calendar 추가에 실패했습니다.');
          }
        } else {
          // Google Calendar에 로그인되어 있지 않은 경우 초기화 시도
          final initialized = await _googleCalendarService.initialize();
          if (initialized) {
            final success = await _googleCalendarService
                .addEventToGoogleCalendar(event);
            if (success) {
              _showSnackBar('일정이 Google Calendar에도 추가되었습니다.');
            } else {
              _showSnackBar(
                'Google Calendar 연동이 필요합니다. 사이드바에서 동기화를 먼저 실행해주세요.',
              );
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
          final success = await _googleCalendarService
              .deleteEventFromGoogleCalendar(event);
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
    _speech.stop();
    super.dispose();
  }

  // STT 초기화
  void _initializeSpeech() async {
    bool available = await _speech.initialize(
      onStatus: (val) => print('STT onStatus: $val'),
      onError: (val) => print('STT onError: $val'),
    );
    if (available) {
      print('STT 초기화 성공');
    } else {
      print('STT를 사용할 수 없습니다');
    }
  }

  // STT 시작
  void _startListening() async {
    // 마이크 권한 확인
    PermissionStatus permission = await Permission.microphone.request();

    if (permission != PermissionStatus.granted) {
      _showSnackBar('마이크 권한이 필요합니다.');
      return;
    }

    if (!_isListening) {
      bool available = await _speech.initialize();
      if (available) {
        setState(() {
          _isListening = true;
          _recognizedText = '';
        });

        _speech.listen(
          onResult: (val) {
            setState(() {
              _recognizedText = val.recognizedWords;
            });
            // 다이얼로그가 열려있다면 실시간 업데이트
            if (_dialogSetState != null) {
              _dialogSetState!(() {});
            }
          },
          listenFor: Duration(seconds: 30),
          pauseFor: Duration(seconds: 5), // 더 긴 일시정지 허용
          partialResults: true, // 부분 결과 활성화
          cancelOnError: true,
          listenMode: stt.ListenMode.confirmation,
          localeId: "ko_KR", // 한국어 설정
        );

        // 음성 인식 중임을 사용자에게 알림
        _showSTTDialog();
      }
    }
  }

  // STT 중지
  void _stopListening() {
    if (_isListening) {
      _speech.stop();
      setState(() {
        _isListening = false;
      });

      // 다이얼로그 상태도 업데이트
      if (_dialogSetState != null) {
        _dialogSetState!(() {});
      }
    }
  }

  // STT 다이얼로그 표시 (하단 슬라이드업 방식)
  void _showSTTDialog() {
    showModalBottomSheet(
      context: context,
      isDismissible: true,
      enableDrag: true,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            _dialogSetState = setDialogState; // 상태 설정 함수 저장

            return Container(
              height: MediaQuery.of(context).size.height * 0.4, // 화면의 40% 높이
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 10,
                    offset: Offset(0, -2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // 핸들 바
                  Container(
                    width: 40,
                    height: 4,
                    margin: EdgeInsets.only(top: 12, bottom: 8),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),

                  // 제목
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    child: Row(
                      children: [
                        AnimatedContainer(
                          duration: Duration(milliseconds: 300),
                          child: Icon(
                            _isListening ? Icons.mic : Icons.mic_off,
                            color: _isListening ? Colors.red : Colors.grey,
                            size: 24,
                          ),
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _isListening ? '음성을 듣고 있습니다...' : '음성 인식 완료',
                            style: getTextStyle(
                              fontSize: 16,
                              color: Colors.black,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  Divider(height: 1, color: Colors.grey.shade200),

                  // 컨텐츠 영역
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.all(20),
                      child: Column(
                        children: [
                          // 음성 인식 텍스트 표시 영역
                          Expanded(
                            child: Container(
                              width: double.infinity,
                              padding: EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade50,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.grey.shade200),
                              ),
                              child: SingleChildScrollView(
                                child: AnimatedSwitcher(
                                  duration: Duration(milliseconds: 200),
                                  child: Text(
                                    _recognizedText.isEmpty
                                        ? '음성을 입력하세요...'
                                        : _recognizedText,
                                    key: ValueKey(_recognizedText),
                                    style: getTextStyle(
                                      fontSize: 14,
                                      color:
                                          _recognizedText.isEmpty
                                              ? Colors.grey.shade500
                                              : Colors.black87,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),

                          SizedBox(height: 16),

                          // 상태 표시
                          if (_isListening) ...[
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: Colors.red,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                SizedBox(width: 8),
                                Text(
                                  '음성 인식 중...',
                                  style: getTextStyle(
                                    fontSize: 14,
                                    color: Colors.red,
                                  ),
                                ),
                              ],
                            ),
                          ],

                          if (_isProcessingSTT) ...[
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.blue,
                                    ),
                                  ),
                                ),
                                SizedBox(width: 12),
                                Text(
                                  'AI가 처리 중입니다...',
                                  style: getTextStyle(
                                    fontSize: 14,
                                    color: Colors.blue,
                                  ),
                                ),
                              ],
                            ),
                          ],

                          SizedBox(height: 16),

                          // 버튼 영역
                          if (!_isProcessingSTT) ...[
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: () {
                                      _stopListening();
                                      Navigator.of(context).pop();
                                      _dialogSetState = null;
                                    },
                                    style: OutlinedButton.styleFrom(
                                      padding: EdgeInsets.symmetric(
                                        vertical: 12,
                                      ),
                                      side: BorderSide(
                                        color: Colors.grey.shade300,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                    child: Text(
                                      '취소',
                                      style: getTextStyle(
                                        fontSize: 14,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                  ),
                                ),

                                if (_isListening) ...[
                                  SizedBox(width: 12),
                                  Expanded(
                                    child: ElevatedButton(
                                      onPressed: () {
                                        _stopListening();
                                        setDialogState(() {});
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.red,
                                        padding: EdgeInsets.symmetric(
                                          vertical: 12,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                      ),
                                      child: Text(
                                        '중지',
                                        style: getTextStyle(
                                          fontSize: 14,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],

                                if (!_isListening &&
                                    _recognizedText.isNotEmpty) ...[
                                  SizedBox(width: 12),
                                  Expanded(
                                    child: ElevatedButton(
                                      onPressed:
                                          () => _sendRecognizedText(
                                            setDialogState,
                                          ),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.blue,
                                        padding: EdgeInsets.symmetric(
                                          vertical: 12,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                      ),
                                      child: Text(
                                        '전송',
                                        style: getTextStyle(
                                          fontSize: 14,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    ).then((_) {
      // 다이얼로그가 닫힐 때 STT 상태 완전 초기화
      _stopListening();
      _dialogSetState = null;
      setState(() {
        _isListening = false;
        _isProcessingSTT = false;
        _recognizedText = '';
      });
    });
  }

  // 인식된 텍스트를 AI 서버로 전송
  void _sendRecognizedText(StateSetter setDialogState) async {
    if (_recognizedText.trim().isEmpty) return;

    setDialogState(() {
      _isProcessingSTT = true;
    });

    try {
      final botResponse = await _chatService.sendMessage(
        _recognizedText,
        'user',
        onCalendarUpdate: () {
          _showSnackBar('일정이 캘린더에 추가되었습니다!');
          _refreshCurrentMonthEvents();
        },
      ); // 처리 완료 후 캘린더 화면 새로 그리기
      _refreshCurrentMonthEvents();

      // 다이얼로그 닫기 전에 상태 초기화
      setState(() {
        _isListening = false;
        _isProcessingSTT = false;
        _recognizedText = '';
      });

      // 다이얼로그 닫기
      Navigator.of(context).pop();
      _dialogSetState = null; // 참조 해제

      // 결과 표시
      _showResultDialog(botResponse.text);
    } catch (e) {
      setDialogState(() {
        _isProcessingSTT = false;
      });
      _showSnackBar('음성 처리 중 오류가 발생했습니다: $e');
    }
  }

  // AI 응답 결과 다이얼로그
  void _showResultDialog(String response) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(
              'AI 응답',
              style: getTextStyle(fontSize: 14, color: Colors.black),
            ),
            content: Text(
              response,
              style: getTextStyle(fontSize: 12, color: Colors.black87),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(
                  '확인',
                  style: getTextStyle(fontSize: 12, color: Colors.blue),
                ),
              ),
            ],
          ),
    );
  }

  // 빈 페이지로 이동
  void _navigateToEmptyPage() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) => EmptyPage(
              onCalendarUpdate: () {
                // 채팅에서 일정 추가/삭제 시 호출될 콜백
                _refreshCurrentMonthEvents();
              },
            ),
      ),
    );

    // 채팅화면에서 돌아왔을 때도 새로고침
    if (result == true || result == null) {
      _refreshCurrentMonthEvents();
    }
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
    final TextEditingController titleController = TextEditingController();
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
                        controller: titleController,
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
                        if (titleController.text.isNotEmpty) {
                          final event = Event(
                            title: titleController.text,
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
      case 1: // 마이크 버튼 - STT 실행
        _startListening();
        break;
      case 2: // 채팅 화면
        _navigateToEmptyPage();
        break;
    }
  }

  // Google Calendar에서 앱으로 다운로드 (완전 동기화)
  Future<void> _downloadFromGoogleCalendar() async {
    if (_isSyncing) {
      _showSnackBar('이미 동기화가 진행 중입니다.');
      return;
    }

    setState(() {
      _isSyncing = true;
    });

    try {
      _showSnackBar('Google Calendar에서 일정을 다운로드 중... (완전 동기화)');

      // 현재 연도의 시작과 끝 날짜 계산
      final DateTime startOfYear = DateTime(_focusedDay.year, 1, 1);
      final DateTime endOfYear = DateTime(_focusedDay.year, 12, 31);

      print('다운로드 범위: ${startOfYear.toString()} ~ ${endOfYear.toString()}');

      // 먼저 전체 년도의 로컬 이벤트를 모두 로드
      _showSnackBar('로컬 이벤트를 로드 중...');
      await _loadAllEventsForYear(_focusedDay.year);

      // Google Calendar에서 이벤트 가져오기 (공휴일 포함)
      final List<Event> googleEvents = await _googleCalendarService
          .syncWithGoogleCalendarIncludingHolidays(
            startDate: startOfYear,
            endDate: endOfYear,
          );

      print('Google에서 가져온 이벤트 수: ${googleEvents.length}');

      // 1. Google Calendar에서 가져온 이벤트를 로컬에 추가
      int addedCount = 0;
      for (var event in googleEvents) {
        final normalizedDay = DateTime(
          event.date.year,
          event.date.month,
          event.date.day,
        );
        final dateKey = _getKey(normalizedDay);

        // 중복 체크 (같은 제목과 시간의 이벤트가 이미 있는지 확인)
        final existingEvents = _events[dateKey] ?? [];
        final isDuplicate = existingEvents.any(
          (e) =>
              e.title == event.title &&
              e.time == event.time &&
              e.date.day == event.date.day &&
              e.date.month == event.date.month &&
              e.date.year == event.date.year,
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
            _eventColors[event.title] =
                _colors[_eventColors.length % _colors.length];
          }

          addedCount++;
          print('Google에서 로컬로 추가: ${event.title}');
        }
      }

      // 2. Google에 없지만 로컬에 있는 이벤트 삭제 (공휴일 제외)
      int deletedCount = 0;
      for (var dateKey in _events.keys.toList()) {
        final localEvents = _events[dateKey]!.toList(); // 복사본 생성

        for (var localEvent in localEvents) {
          // 공휴일은 삭제하지 않음
          if (localEvent.title.startsWith('🇰🇷')) {
            continue;
          }

          // Google에 동일한 이벤트가 있는지 확인
          final existsInGoogle = googleEvents.any(
            (googleEvent) =>
                googleEvent.title == localEvent.title &&
                googleEvent.time == localEvent.time &&
                googleEvent.date.day == localEvent.date.day &&
                googleEvent.date.month == localEvent.date.month &&
                googleEvent.date.year == localEvent.date.year,
          );

          // Google에 없으면 로컬에서 삭제
          if (!existsInGoogle) {
            try {
              final normalizedDay = DateTime(
                localEvent.date.year,
                localEvent.date.month,
                localEvent.date.day,
              );

              // 로컬 저장소에서 삭제
              await EventStorageService.removeEvent(normalizedDay, localEvent);

              // 캐시에서도 삭제
              _events[dateKey]!.removeWhere(
                (e) =>
                    e.title == localEvent.title &&
                    e.time == localEvent.time &&
                    e.date.day == localEvent.date.day &&
                    e.date.month == localEvent.date.month &&
                    e.date.year == localEvent.date.year,
              );

              deletedCount++;
              print('Google에 없어서 로컬에서 삭제: ${localEvent.title}');
            } catch (e) {
              print('로컬 이벤트 삭제 중 오류: ${localEvent.title} - $e');
            }
          }
        }
      }

      // 결과 메시지 표시
      String resultMessage = '${_focusedDay.year}년 Google Calendar 다운로드 완료!';
      if (addedCount > 0 || deletedCount > 0) {
        resultMessage += ' $addedCount개 추가, $deletedCount개 삭제되었습니다.';
      } else {
        resultMessage += ' 변경사항이 없습니다.';
      }

      _showSnackBar(resultMessage);

      // UI 갱신
      setState(() {});
    } catch (e) {
      print('Google Calendar 다운로드 오류: $e');
      _showSnackBar('Google Calendar 다운로드에 실패했습니다: ${e.toString()}');
    } finally {
      setState(() {
        _isSyncing = false;
      });
    }
  }

  // 앱에서 Google Calendar로 업로드 (완전 동기화)
  Future<void> _uploadToGoogleCalendar() async {
    if (_isSyncing) {
      _showSnackBar('이미 동기화가 진행 중입니다.');
      return;
    }

    setState(() {
      _isSyncing = true;
    });

    try {
      _showSnackBar('앱의 일정을 Google Calendar로 업로드 중... (완전 동기화)');

      // 현재 연도의 시작과 끝 날짜 계산
      final DateTime startOfYear = DateTime(_focusedDay.year, 1, 1);
      final DateTime endOfYear = DateTime(_focusedDay.year, 12, 31);

      // 먼저 전체 년도의 로컬 이벤트를 모두 로드
      _showSnackBar('로컬 이벤트를 로드 중...');
      await _loadAllEventsForYear(_focusedDay.year);

      // Google Calendar에서 기존 이벤트 가져오기 (중복 확인용)
      final List<Event> googleEvents = await _googleCalendarService
          .syncWithGoogleCalendarIncludingHolidays(
            startDate: startOfYear,
            endDate: endOfYear,
          );

      print('Google에 있는 이벤트 수: ${googleEvents.length}');

      // 로컬 이벤트 수집
      List<Event> localEvents = [];
      for (var dateKey in _events.keys) {
        localEvents.addAll(_events[dateKey]!);
      }
      print('로컬에 있는 이벤트 수: ${localEvents.length}');

      // 1. 로컬에만 있는 이벤트를 Google Calendar에 추가
      int uploadedCount = 0;
      for (var localEvent in localEvents) {
        // Google Calendar에 동일한 이벤트가 있는지 확인
        final existsInGoogle = googleEvents.any(
          (googleEvent) =>
              googleEvent.title == localEvent.title &&
              googleEvent.time == localEvent.time &&
              googleEvent.date.day == localEvent.date.day &&
              googleEvent.date.month == localEvent.date.month &&
              googleEvent.date.year == localEvent.date.year,
        );

        // Google Calendar에 없으면 추가
        if (!existsInGoogle) {
          try {
            // 공휴일은 Google Calendar에 추가하지 않음
            if (!localEvent.title.startsWith('🇰🇷')) {
              final success = await _googleCalendarService
                  .addEventToGoogleCalendar(localEvent);
              if (success) {
                uploadedCount++;
                print('로컬에서 Google로 추가: ${localEvent.title}');
              } else {
                print('Google Calendar 업로드 실패: ${localEvent.title}');
              }
            }
          } catch (e) {
            print('Google Calendar 업로드 중 오류: ${localEvent.title} - $e');
          }
        }
      }

      // 2. Google에만 있고 로컬에 없는 이벤트를 Google에서 삭제 (공휴일 제외)
      int deletedCount = 0;
      for (var googleEvent in googleEvents) {
        // 공휴일은 삭제하지 않음
        if (googleEvent.title.startsWith('🇰🇷')) {
          continue;
        }

        // 로컬에 동일한 이벤트가 있는지 확인
        final existsInLocal = localEvents.any(
          (localEvent) =>
              localEvent.title == googleEvent.title &&
              localEvent.time == googleEvent.time &&
              localEvent.date.day == googleEvent.date.day &&
              localEvent.date.month == googleEvent.date.month &&
              localEvent.date.year == googleEvent.date.year,
        );

        // 로컬에 없으면 Google에서 삭제
        if (!existsInLocal) {
          try {
            final success = await _googleCalendarService
                .deleteEventFromGoogleCalendar(googleEvent);
            if (success) {
              deletedCount++;
              print('로컬에 없어서 Google에서 삭제: ${googleEvent.title}');
            } else {
              print('Google Calendar 삭제 실패: ${googleEvent.title}');
            }
          } catch (e) {
            print('Google Calendar 삭제 중 오류: ${googleEvent.title} - $e');
          }
        }
      }

      // 결과 메시지 표시
      String resultMessage = '앱 → Google Calendar 업로드 완료!';
      if (uploadedCount > 0 || deletedCount > 0) {
        resultMessage += ' $uploadedCount개 추가, $deletedCount개 삭제되었습니다.';
      } else {
        resultMessage += ' 변경사항이 없습니다.';
      }

      _showSnackBar(resultMessage);
    } catch (e) {
      print('Google Calendar 업로드 오류: $e');
      _showSnackBar('Google Calendar 업로드에 실패했습니다: ${e.toString()}');
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
          MaterialPageRoute(builder: (context) => const LoginScreen()),
          (route) => false, // 모든 이전 라우트 제거
        );
      }
    } catch (e) {
      print('로그아웃 중 오류 발생: $e');
      // 오류가 발생해도 로그인 화면으로 이동
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LoginScreen()),
          (route) => false,
        );
      }
    }
  }

  // 특정 날짜의 이벤트 캐시 새로고침
  Future<void> _refreshEventsForDay(DateTime day) async {
    final normalizedDay = DateTime(day.year, day.month, day.day);
    final dateKey = _getKey(normalizedDay);

    // 캐시에서 해당 날짜 제거
    _events.remove(dateKey);
    _loadingDates.remove(dateKey);

    // 다시 로드
    await _loadEventsForDay(normalizedDay);

    // UI 갱신
    if (mounted) {
      setState(() {});
    }
  }

  // 전체 이벤트 캐시 새로고침
  Future<void> _refreshAllEvents() async {
    _events.clear();

    // 현재 화면에 보이는 모든 날짜 다시 로드
    final firstVisibleDay = DateTime(
      _focusedDay.year,
      _focusedDay.month - 1,
      1,
    );
    final lastVisibleDay = DateTime(_focusedDay.year, _focusedDay.month + 2, 0);

    DateTime currentDay = firstVisibleDay;
    while (currentDay.isBefore(lastVisibleDay) ||
        currentDay.isAtSameMomentAs(lastVisibleDay)) {
      await _loadEventsForDay(currentDay);
      currentDay = currentDay.add(const Duration(days: 1));
    }

    if (mounted) {
      setState(() {});
    }
  }

  // 이벤트 캐시 새로고침 (다른 화면에서 추가된 이벤트를 위해)
  Future<void> _refreshCurrentMonthEvents() async {
    final DateTime firstDayOfMonth = DateTime(
      _focusedDay.year,
      _focusedDay.month,
      1,
    );
    final DateTime lastDayOfMonth = DateTime(
      _focusedDay.year,
      _focusedDay.month + 1,
      0,
    );

    // 해당 월의 모든 날짜에 대해 캐시 새로고침
    for (int day = 1; day <= lastDayOfMonth.day; day++) {
      final date = DateTime(_focusedDay.year, _focusedDay.month, day);
      final dateKey = _getKey(date);

      // 캐시에서 제거
      _events.remove(dateKey);

      // 다시 로드
      await _loadEventsForDay(date);
    }

    if (mounted) {
      setState(() {});
    }
  }

  // 전체 년도의 이벤트를 로드하는 메서드
  Future<void> _loadAllEventsForYear(int year) async {
    print('=== $year년 전체 이벤트 로드 시작 ===');

    // 년도의 모든 날짜를 순회하며 이벤트 로드
    for (int month = 1; month <= 12; month++) {
      final daysInMonth = DateTime(year, month + 1, 0).day;
      for (int day = 1; day <= daysInMonth; day++) {
        final date = DateTime(year, month, day);
        await _loadEventsForDay(date);
      }
    }

    print('=== $year년 전체 이벤트 로드 완료 ===');
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
        onGoogleCalendarDownload: _downloadFromGoogleCalendar,
        onGoogleCalendarUpload: _uploadToGoogleCalendar,
        onLogoutTap: _handleLogout,
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
                            events: _getEventsForDay(day),
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
                            events: _getEventsForDay(day),
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
                            events: _getEventsForDay(day),
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
