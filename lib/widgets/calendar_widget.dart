// lib/widgets/calendar_widget.dart (최종 수정본 - TTS 의존성 전달)
import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import '../controllers/calendar_controller.dart';
import '../managers/event_manager.dart';
import '../managers/popup_manager.dart';
import '../widgets/weather_calendar_cell.dart';
import '../models/weather_info.dart';
import '../widgets/event_popup.dart';
import '../widgets/weather_summary_popup.dart';
import '../widgets/side_menu.dart';
import '../widgets/common_navigation_bar.dart';
import '../widgets/multi_day_event_popup.dart'; // 🆕 멀티데이 이벤트 팝업 추가
import '../utils/font_utils.dart';
import '../services/google_calendar_service.dart';
import '../services/weather_service.dart';
import '../services/stt_command_service.dart';
import '../screens/chat_screen.dart';
import '../services/tts_service.dart'; // --- ★★★ 추가: TtsService 임포트 ★★★ ---
import '../managers/theme_manager.dart'; //☑️ 테마 관련 추가

class CalendarWidget extends StatefulWidget {
  final CalendarController controller;
  final EventManager eventManager;
  final PopupManager popupManager;
  final VoidCallback? onLogout;

  // --- ★★★ 추가: TtsService 인스턴스를 전달받기 위한 변수 ★★★ ---
  final TtsService ttsService;

  const CalendarWidget({
    super.key,
    required this.controller,
    required this.eventManager,
    required this.popupManager,
    this.onLogout,
    required this.ttsService, // --- ★★★ 수정: 생성자에서 ttsService 필수로 받도록 변경 ★★★ ---
  });

  @override
  State<CalendarWidget> createState() => _CalendarWidgetState();
}

class _CalendarWidgetState extends State<CalendarWidget> {
  int _selectedIndex = 0;
  final CalendarFormat _calendarFormat = CalendarFormat.month;
  final GoogleCalendarService _googleCalendarService = GoogleCalendarService();
  bool _showMultiDayEventPopup = false; // 🆕 멀티데이 이벤트 팝업 상태 변수 추가

  @override
  void initState() {
    super.initState();
    //☑️ 테마 변경 리스너 등록
    ThemeManager.addListener(_onThemeChanged);
  }

  @override
  void dispose() {
    //☑️ 리스너 제거
    ThemeManager.removeListener(_onThemeChanged);
    super.dispose();
  }

  //☑️ 테마 변경 시 호출되는 콜백
  void _onThemeChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final DateTime firstDay = DateTime(
      widget.controller.focusedDay.year,
      widget.controller.focusedDay.month,
      1,
    );
    final DateTime lastDay = DateTime(
      widget.controller.focusedDay.year,
      widget.controller.focusedDay.month + 1,
      0,
    );
    final int firstWeekday = (firstDay.weekday % 7);
    final int lastDate = lastDay.day;
    final int totalWeeks = ((firstWeekday + lastDate) / 7).ceil();

    return Scaffold(
      resizeToAvoidBottomInset: false,
      // backgroundColor: const Color.fromARGB(255, 162, 222, 141),
      //☑️테마에 따른 배경색 변경
      backgroundColor:
          ThemeManager.getCalendarMainBackgroundColor(), // 검정에 가까운 회색

      drawer: CalendarSideMenu(
        onWeatherForecastTap: () async {
          await WeatherService.loadCalendarWeather(widget.controller);
          widget.popupManager.showWeatherForecastDialog();
          setState(() {});
        },
        onGoogleCalendarDownload: () async {
          try {
            _showSnackBar('Google Calendar 동기화 시작...');
            await widget.eventManager.syncWithGoogleCalendar();
            setState(() {});
            _showSnackBar('Google Calendar 동기화 완료!');
          } catch (e) {
            _showSnackBar('동기화 실패: $e');
          }
        },
        onGoogleCalendarUpload: () async {
          try {
            await widget.eventManager.uploadToGoogleCalendar();
            _showSnackBar('앱 → Google Calendar 업로드 완료! (중복 방지 적용)');
          } catch (e) {
            _showSnackBar('업로드 실패: $e');
          }
        },
        onLogoutTap: widget.onLogout ?? () {},
        onBriefingSettingsTap: () {
          Navigator.pushNamed(context, '/briefing_settings');
        },
        isGoogleCalendarConnected: _googleCalendarService.isSignedIn,
        events: widget.controller.getAllEvents(), // 🆕 전체 이벤트 목록 전달
        currentMonth: widget.controller.focusedDay, // 🆕 현재 포커스된 월 전달
        // --- ★★★ 삭제: isTtsEnabled, onTtsToggle 전달 코드 제거 ★★★ ---
      ),
      body: SafeArea(
        bottom: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final availableHeight = constraints.maxHeight;
            const monthHeaderHeight = 40.0; // ☑️ 헤더 높이 줄임 (65 → 40)
            const dayOfWeekHeaderHeight = 28.0; // ☑️ 요일 헤더 높이 10% 증가 (25 → 28)
            final weekHeight =
                (availableHeight -
                    monthHeaderHeight -
                    dayOfWeekHeaderHeight -
                    16.0) /
                totalWeeks;

            return Stack(
              alignment: Alignment.topCenter, // ☑️ 달력을 상단 중앙에 정렬
              children: [
                Positioned(
                  top: 10, // ☑️ 약간의 여백 추가 (0 → 10)
                  left: 3.0,
                  right: 3.0,
                  child: Container(
                    // color: Colors.white,
                    //☑️테마에 따른 배경색 변경
                    color:
                        ThemeManager.getCalendarMainBackgroundColor(), // 검정에 가까운 어두운 회색
                    // color: ThemeManager.getCalendarHeaderBackgroundColor(), // 네비게이션바와 동일한 색상 적용
                    child: TableCalendar(
                      firstDay: DateTime.utc(2020, 1, 1),
                      lastDay: DateTime.utc(2030, 12, 31),
                      focusedDay: widget.controller.focusedDay,
                      calendarFormat: _calendarFormat,
                      daysOfWeekHeight: dayOfWeekHeaderHeight,
                      rowHeight: weekHeight,
                      selectedDayPredicate:
                          (day) =>
                              isSameDay(widget.controller.selectedDay, day),
                      onDaySelected: (selectedDay, focusedDay) async {
                        widget.controller.setSelectedDay(selectedDay);
                        widget.controller.setFocusedDay(focusedDay);
                        if (widget.controller.shouldLoadEventsForDay(
                          selectedDay,
                        )) {
                          try {
                            await widget.eventManager.loadEventsForDay(
                              selectedDay,
                            );
                          } catch (e) {
                            print('❌ 날짜 선택 시 이벤트 로드 실패: $e');
                          }
                        }
                        widget.popupManager.showEventDialog();
                        setState(() {});
                      },
                      onPageChanged: (focusedDay) async {
                        widget.controller.setFocusedDay(focusedDay);
                        widget.controller.hideAllPopups();
                        try {
                          await widget.eventManager.loadEventsForMonth(
                            focusedDay,
                          );
                        } catch (e) {
                          print('❌ 월 변경 시 이벤트 로드 실패: $e');
                        }
                        setState(() {});
                      },
                      eventLoader:
                          (day) =>
                              widget.controller
                                  .getEventsForDay(day)
                                  .map((e) => e.title)
                                  .toList(),
                      startingDayOfWeek: StartingDayOfWeek.sunday,
                      headerStyle: HeaderStyle(
                        titleTextStyle: getTextStyle(
                          fontSize: 12,
                          // color: Colors.black,
                          color:
                              ThemeManager.getCalendarHeaderTextColor(), //☑️ 테마에 따른 요일 텍스트 색상 변경
                          text: '달력 제목',
                        ),
                        formatButtonVisible: false,
                        leftChevronVisible: false,
                        rightChevronVisible: false,
                        headerMargin: const EdgeInsets.only(
                          bottom: 0,
                        ), // ☑️ 마진 완전히 제거 (2 → 0)
                        headerPadding: const EdgeInsets.symmetric(
                          vertical: 0,
                        ), // ☑️ 패딩 완전히 제거 (4 → 0)
                        titleCentered: true,
                      ),
                      daysOfWeekStyle: DaysOfWeekStyle(
                        weekdayStyle: getTextStyle(
                          fontSize: 8,
                          // color: Colors.black,
                          color:
                              ThemeManager.getTextColor(), //☑️ 테마에 따른 요일 텍스트 색상 변경
                          text: 'Mon',
                        ),
                        weekendStyle: getTextStyle(
                          fontSize: 8,
                          // color: const Color.fromARGB(255, 54, 184, 244),
                          color:
                              ThemeManager.getSaturdayColor(), //☑️ 테마에 따른 요일 텍스트 색상 변경
                          text: 'Sat',
                        ),
                        decoration: BoxDecoration(
                          // color: const Color(0xFFEEEEEE),
                          color:
                              ThemeManager.getCalendarDayOfWeekBackgroundColor(), //☑️ 테마에 따른 요일 텍스트 색상 변경
                          border: Border.all(
                            // color: Colors.black, width: 1),
                            // color: ThemeManager.getEventPopupBorderColor(), //☑️ 테마에 따른 요일 텍스트 색상 변경
                            color:
                                ThemeManager.getCalendarBorderColor(), //☑️ 캘린더 전용 테두리 색상 적용
                            width: 1,
                          ),
                        ),
                      ),
                      calendarStyle: CalendarStyle(
                        defaultTextStyle: getTextStyle(
                          fontSize: 8,
                          // color: Colors.black,
                          color:
                              ThemeManager.getTextColor(), //☑️ 테마에 따른 요일 텍스트 색상 변경
                          text: '1',
                        ),
                        weekendTextStyle: getTextStyle(
                          fontSize: 8,
                          // color: Colors.red,
                          color:
                              ThemeManager.getSundayColor(), //☑️ 테마에 따른 요일 텍스트 색상 변경
                          text: '1',
                        ),
                        selectedTextStyle: getTextStyle(
                          fontSize: 8,
                          color: Colors.white,
                          text: '1',
                        ),
                        todayTextStyle: getTextStyle(
                          fontSize: 8,
                          // color: Colors.black,
                          color:
                              ThemeManager.getTextColor(), //☑️ 테마에 따른 요일 텍스트 색상 변경
                          text: '1',
                        ),
                        outsideTextStyle: getTextStyle(
                          fontSize: 8,
                          // color: const Color(0xFF888888),
                          color: ThemeManager.getTextColor(
                            lightColor: const Color(0xFF888888),
                            darkColor: const Color(0xFF666666),
                          ), //☑️ 테마 적용용
                          text: '1',
                        ),
                        selectedDecoration: BoxDecoration(
                          // color: Colors.blue[800],
                          color:
                              ThemeManager.getCalendarSelectedColor(), //☑️ 테마 적용용
                        ),
                        todayDecoration: BoxDecoration(
                          // color: Colors.amber[300],
                          color:
                              ThemeManager.getCalendarTodayColor(), //☑️ 테마 적용용
                        ),
                        defaultDecoration: const BoxDecoration(),
                        weekendDecoration: BoxDecoration(
                          // const 제거
                          // color: Color(0xFFEEEEEE),
                          color:
                              ThemeManager.getCalendarWeekendColor(), //☑️ 테마 적용용
                        ),
                        outsideDecoration: BoxDecoration(
                          // const 제거
                          // color: Color(0xFFDDDDDD),
                          color:
                              ThemeManager.getCalendarOutsideColor(), //☑️ 테마 적용용
                        ),
                        tableBorder: TableBorder.all(
                          // color: const Color.fromARGB(24, 0, 0, 0),
                          // color: ThemeManager.getEventPopupBorderColor(), //☑️ 테마 적용용
                          color:
                              ThemeManager.getCalendarBorderColor(), // ☑️ 캘린더 전용 테두리 색상 적용
                          width: 1,
                        ),
                        markersMaxCount: 6,
                        markersAlignment: Alignment.bottomCenter,
                        markerMargin: const EdgeInsets.only(top: 2),
                        markerDecoration: const BoxDecoration(
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
                            onTap: () async {
                              widget.controller.setSelectedDay(day);
                              widget.controller.setFocusedDay(focusedDay);

                              // 🔥 날짜 선택 시에도 중복 로드 방지
                              if (widget.controller.shouldLoadEventsForDay(
                                day,
                              )) {
                                try {
                                  await widget.eventManager.loadEventsForDay(
                                    day,
                                  );
                                } catch (e) {
                                  print('❌ 날짜 선택 시 이벤트 로드 실패: $e');
                                }
                              }
                              widget.popupManager.showEventDialog();
                              setState(() {});
                            },
                            events: widget.controller.getEventsForDay(day),
                            eventColors: widget.controller.eventColors,
                            eventIdColors: widget.controller.eventIdColors,
                            colorIdColors: widget.controller.colorIdColors,
                            weatherInfo: widget.controller.getWeatherForDay(
                              day,
                            ),
                            allEvents:
                                widget.controller
                                    .getAllEvents(), // 🆕 전체 이벤트 목록 전달
                          );
                        },
                        // 선택된 날짜 셀 빌더
                        selectedBuilder: (context, day, focusedDay) {
                          return WeatherCalendarCell(
                            day: day,
                            isSelected: true,
                            isToday: false,
                            onTap: () {
                              widget.popupManager.showEventDialog();
                              setState(() {});
                            },
                            events: widget.controller.getEventsForDay(day),
                            eventColors: widget.controller.eventColors,
                            eventIdColors: widget.controller.eventIdColors,
                            colorIdColors: widget.controller.colorIdColors,
                            weatherInfo: widget.controller.getWeatherForDay(
                              day,
                            ),
                            allEvents:
                                widget.controller
                                    .getAllEvents(), // 🆕 전체 이벤트 목록 전달
                          );
                        }, // 오늘 날짜 셀 빌더
                        todayBuilder: (context, day, focusedDay) {
                          return WeatherCalendarCell(
                            day: day,
                            isSelected: false,
                            isToday: true,
                            onTap: () async {
                              widget.controller.setSelectedDay(day);
                              widget.controller.setFocusedDay(focusedDay);

                              // 🔥 날짜 선택 시에도 중복 로드 방지
                              if (widget.controller.shouldLoadEventsForDay(
                                day,
                              )) {
                                try {
                                  await widget.eventManager.loadEventsForDay(
                                    day,
                                  );
                                } catch (e) {
                                  print('❌ 오늘 날짜 선택 시 이벤트 로드 실패: $e');
                                }
                              }

                              widget.popupManager.showEventDialog();
                              setState(() {});
                            },
                            events: widget.controller.getEventsForDay(day),
                            eventColors: widget.controller.eventColors,
                            eventIdColors: widget.controller.eventIdColors,
                            colorIdColors: widget.controller.colorIdColors,
                            weatherInfo: widget.controller.getWeatherForDay(
                              day,
                            ),
                            allEvents:
                                widget.controller
                                    .getAllEvents(), // 🆕 전체 이벤트 목록 전달
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
                          //☑️ 테마에 따른 요일 텍스트 색상 변경
                          // Color textColor;
                          // if (day.weekday == DateTime.saturday) {
                          //   textColor = const Color.fromARGB(255, 54, 184, 244);
                          // } else if (day.weekday == DateTime.sunday) {
                          //   textColor = Colors.red;
                          // } else {
                          //   textColor = Colors.black;
                          // }
                          final isSaturday = day.weekday == DateTime.saturday;
                          final isSunday = day.weekday == DateTime.sunday;
                          final isWeekend =
                              isSaturday ||
                              isSunday; // ☑️ 테마에 따른 요일 텍스트 색상 변경(여기까지)

                          return Container(
                            //☑️ 테마에 따른 요일 텍스트 색상 변경
                            // decoration: const BoxDecoration(
                            //   color: Color(0xFFEEEEEE),
                            decoration: BoxDecoration(
                              color:
                                  ThemeManager.getCalendarDayOfWeekBackgroundColor(), // 테마 적용
                              border: Border.all(
                                // color: ThemeManager.getEventPopupBorderColor(),
                                color:
                                    ThemeManager.getCalendarBorderColor(), //_HE_250623_캘린더 전용 테두리 색상 적용
                                width: 1,
                              ),
                            ),
                            alignment: Alignment.center,
                            padding: const EdgeInsets.symmetric(
                              vertical: 4.0,
                            ), // ☑️ 요일 헤더 패딩 줄임 (8 → 4)
                            child: Text(
                              weekdayNames[weekdayIndex],
                              style: getTextStyle(
                                fontSize: 12,
                                // color: textColor,
                                color:
                                    ThemeManager.getCalendarDayOfWeekTextColor(
                                      isWeekend,
                                      isSaturday,
                                    ), //☑️ 테마에 따른 요일 텍스트 색상 변경

                                text: weekdayNames[weekdayIndex],
                              ),
                            ),
                          );
                        },
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
                            // ☑️ _HE_250623_헤더만 초록색 배경 적용
                            decoration: BoxDecoration(
                              color:
                                  ThemeManager.getCalendarHeaderBackgroundColor(),
                              border: Border(
                                bottom: BorderSide(
                                  // color: ThemeManager.getEventPopupBorderColor(),
                                  // ☑️ 헤더 아래 선을 헤더 배경색과 동일하게 변경
                                  color:
                                      ThemeManager.getCalendarHeaderBackgroundColor(),
                                  width: 0.5,
                                ),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                //  메뉴 아이콘 (테마 적용)
                                IconButton(
                                  icon: Icon(
                                    Icons.menu,
                                    color:
                                        ThemeManager.getCalendarHeaderIconColor(), // 🔧 테마 적용
                                  ),
                                  onPressed:
                                      () => Scaffold.of(context).openDrawer(),
                                ),
                                //  년도/월 텍스트 (테마 적용)
                                Expanded(
                                  child: Center(
                                    child: Text(
                                      '${month.year} ${monthNames[month.month - 1]}',
                                      style: getTextStyle(
                                        fontSize: 18,
                                        color:
                                            ThemeManager.getCalendarHeaderTextColor(), // 🔧 테마 적용
                                      ),
                                    ),
                                  ),
                                ),
                                const IconButton(
                                  icon: Icon(
                                    Icons.calendar_today,
                                    color: Colors.transparent,
                                  ),
                                  onPressed: null,
                                ),
                              ],
                            ), // ☑️ 테마에 따른 달력 제목 색상 변경(여기까지)
                          );
                        },
                      ),
                    ),
                  ),
                ),
                if (widget.controller.showEventPopup)
                  EventPopup(
                    selectedDay: widget.controller.selectedDay,
                    events: widget.controller.getEventsForDay(
                      widget.controller.selectedDay,
                    ),
                    eventColors: widget.controller.eventColors,
                    eventIdColors: widget.controller.eventIdColors,
                    colorIdColors: widget.controller.colorIdColors,
                    getEventDisplayColor:
                        (event) =>
                            widget.controller.getEventDisplayColor(event),
                    popupManager: widget.popupManager, // PopupManager 전달
                    onClose: () {
                      widget.popupManager.hideEventDialog();
                      setState(() {});
                    },
                    onAddEvent: () {
                      widget.popupManager.showAddEventDialog(context).then((_) {
                        setState(() {});
                      });
                    },
                    onEditEvent: (event) {
                      widget.popupManager
                          .showEditEventDialog(context, event)
                          .then((_) {
                            setState(() {});
                          });
                    },
                    onDeleteEvent: (event) async {
                      await widget.eventManager.removeEvent(event);
                      setState(() {});
                    },
                    // 🆕 멀티데이 이벤트 추가 콜백
                    onAddMultiDayEvent: () {
                      _showMultiDayEventDialog();
                    },
                  ),

                // 🆕 멀티데이 이벤트 팝업 오버레이
                if (_showMultiDayEventPopup)
                  MultiDayEventPopup(
                    initialDate:
                        widget.controller.selectedDay, // 클릭한 날짜를 초기 날짜로 설정
                    onSave: (event) async {
                      // EventManager를 통해 멀티데이 이벤트 추가 (영구 저장 포함)
                      await widget.eventManager.addEvent(event);
                      setState(() {
                        _showMultiDayEventPopup = false;
                      });
                    },
                    onClose: () {
                      setState(() {
                        _showMultiDayEventPopup = false;
                      });
                    },
                  ),

                // 날씨 예보 팝업 오버레이
                if (widget.controller.showWeatherPopup)
                  FutureBuilder<List<WeatherInfo>>(
                    future: WeatherService.get5DayForecast(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return Center(
                          child: SizedBox(
                            width: 200,
                            height: 200,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                CircularProgressIndicator(),
                                SizedBox(height: 16),
                                Text(
                                  '날씨 정보를 불러오는 중...',
                                  style: getTextStyle(fontSize: 16),
                                ),
                              ],
                            ),
                          ),
                        );
                      }
                      List<WeatherInfo> weatherList = snapshot.data ?? [];
                      if (weatherList.length > 5) {
                        weatherList = weatherList.take(5).toList();
                      }
                      return WeatherSummaryPopup(
                        weatherList: weatherList,
                        onClose: () {
                          widget.popupManager.hideWeatherForecastDialog();
                          setState(() {});
                        },
                      );
                    },
                  ),
              ],
            );
          },
        ),
      ),
      bottomNavigationBar: CommonNavigationBar(
        selectedIndex: _selectedIndex,
        onItemTapped: _onItemTapped,
      ),
    );
  }

  void _onItemTapped(int index) {
    // 마이크 버튼(index 1)이고 팝업이 열려있을 때는 아무것도 하지 않음
    if (index == 1 &&
        (widget.controller.showEventPopup ||
            widget.controller.showWeatherPopup)) {
      print('🚫 팝업이 열려있어서 마이크 버튼이 비활성화됨');
      return;
    }

    setState(() {
      _selectedIndex = index;
    });

    switch (index) {
      case 0:
        break;
      case 1:
        _showVoiceInput();
        break;
      case 2:
        // 채팅 화면으로 이동하기 전에 애니메이션 시간을 줌
        Future.delayed(const Duration(milliseconds: 500), () {
          _navigateToChatScreen();
        });
        break;
    }
  }

  void _navigateToChatScreen() async {
    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder:
            (context) => ChatScreen(
              ttsService: widget.ttsService, // ttsService 매개변수 추가
              onCalendarUpdate: () {
                // 🚀 성능 최적화: 필요한 경우에만 새로고침
                print('📱 ChatScreen: 캘린더 업데이트 요청 (최적화됨)');
                widget.eventManager.loadEventsForDay(
                  widget.controller.selectedDay,
                  forceRefresh: true,
                );
                setState(() {});
              },
              eventManager: widget.eventManager,
            ),
      ),
    );

    // 채팅 화면에서 돌아왔을 때 네비게이션 바 상태 리셋
    if (result != null && result['refreshNavigation'] == true) {
      // 음성 인식 UI 표시가 요청된 경우
      if (result['showVoiceInput'] == true) {
        // 먼저 가운데 버튼(마이크)으로 상태 설정
        setState(() {
          _selectedIndex = 1;
        });

        // 애니메이션 시간을 늘려서 자연스럽게 음성 인식 UI 표시
        Future.delayed(const Duration(milliseconds: 500), () {
          _showVoiceInput();
        });
      } else {
        // 음성 입력이 요청되지 않은 경우에만 달력 버튼으로 리셋
        setState(() {
          _selectedIndex = 0;
        });
      }
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  /// 🆕 멀티데이 이벤트 생성 다이얼로그 표시
  void _showMultiDayEventDialog() {
    widget.controller.hideEventDialog(); // 기존 팝업 닫기
    setState(() {
      // 멀티데이 이벤트 팝업 표시 상태 추가 (showMultiDayEventPopup)
      _showMultiDayEventPopup = true;
    });
  }

  void _showVoiceInput() {
    VoiceCommandService.instance
        .showVoiceInput(
          context: context,
          eventManager: widget.eventManager,
          // --- ★★★ 추가: ttsService 인스턴스 전달 ★★★ ---
          ttsService: widget.ttsService,
          onCommandProcessed: _handleVoiceCommandResponse,
          onCalendarUpdate: () async {
            print('🔄 CalendarWidget: 캘린더 업데이트 콜백 받음 (최적화됨)');
            // 🚀 성능 최적화: 불필요한 중복 새로고침 제거
            await widget.eventManager.loadEventsForDay(
              widget.controller.selectedDay,
              forceRefresh: true,
            );
            setState(() {});
          },
        )
        .then((_) {
          // STT 팝업이 닫힌 후 네비게이션 바 상태를 달력 버튼(0)으로 리셋
          setState(() {
            _selectedIndex = 0;
          });
        });
  }

  void _handleVoiceCommandResponse(String response, String command) {
    print('🎤 CalendarWidget: STT 명령 처리 - 명령: "$command", 응답: "$response"');
    _showSnackBar(response);
    VoiceCommandService.instance.processCalendarCommand(
      command,
      widget.controller,
      widget.popupManager,
      widget.eventManager,
      () => setState(() {}),
    );
    // 🚀 성능 최적화: 중복 새로고침 제거 - onCalendarUpdate에서 이미 처리됨
    print('🔄 음성 명령 완료 - onCalendarUpdate에서 새로고침 처리됨');
  }
}
