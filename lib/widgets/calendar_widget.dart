import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import '../controllers/calendar_controller.dart';
import '../managers/event_manager.dart';
import '../managers/popup_manager.dart';
import '../widgets/weather_calendar_cell.dart';
import '../models/weather_info.dart';
import '../widgets/event_popup.dart';
import '../widgets/time_table_popup.dart';
import '../widgets/weather_summary_popup.dart';
import '../widgets/side_menu.dart';
import '../widgets/common_navigation_bar.dart';
import '../utils/font_utils.dart';
import '../services/google_calendar_service.dart';
import '../services/weather_service.dart';
import '../services/stt_command_service.dart'; // 음성 명령 서비스 임포트
import '../screens/chat_screen.dart'; // EmptyPage 추가

/// 캘린더 위젯 - 순수 UI 컴포넌트
class CalendarWidget extends StatefulWidget {
  final CalendarController controller;
  final EventManager eventManager;
  final PopupManager popupManager;
  final VoidCallback? onLogout;

  const CalendarWidget({
    super.key,
    required this.controller,
    required this.eventManager,
    required this.popupManager,
    this.onLogout,
  });

  @override
  State<CalendarWidget> createState() => _CalendarWidgetState();
}

class _CalendarWidgetState extends State<CalendarWidget> {
  int _selectedIndex = 0;
  final CalendarFormat _calendarFormat = CalendarFormat.month;
  final GoogleCalendarService _googleCalendarService = GoogleCalendarService();
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    // 현재 월의 주 수 계산
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

    // 주 시작일에 맞는 요일 오프셋 계산
    final int firstWeekday = (firstDay.weekday % 7); // 0: 일, 1: 월, ... 6: 토
    // 마지막 날의 날짜
    final int lastDate = lastDay.day;

    // 정확한 주 수 계산
    final int totalWeeks = ((firstWeekday + lastDate) / 7).ceil();

    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: const Color.fromARGB(255, 162, 222, 141),
      drawer: CalendarSideMenu(
        onWeatherForecastTap: () async {
          // WeatherService 직접 호출
          await WeatherService.loadCalendarWeather(widget.controller);
          widget.popupManager.showWeatherForecastDialog();
          setState(() {});
        },
        onGoogleCalendarDownload: () async {
          try {
            await widget.eventManager.syncWithGoogleCalendar();
            setState(() {});
            _showSnackBar('Google Calendar 동기화 완료');
          } catch (e) {
            _showSnackBar('동기화 실패: $e');
          }
        },
        onGoogleCalendarUpload: () async {
          try {
            await widget.eventManager.uploadToGoogleCalendar();
            _showSnackBar('Google Calendar 업로드 완료');
          } catch (e) {
            _showSnackBar('업로드 실패: $e');
          }
        },
        onLogoutTap: widget.onLogout ?? () {},
        isGoogleCalendarConnected: _googleCalendarService.isSignedIn,
      ),
      body: SafeArea(
        bottom: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final availableHeight = constraints.maxHeight;
            const monthHeaderHeight = 65.0;
            const dayOfWeekHeaderHeight = 35.0;
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
                      focusedDay: widget.controller.focusedDay,
                      calendarFormat: _calendarFormat,
                      daysOfWeekHeight: dayOfWeekHeaderHeight,
                      rowHeight: weekHeight,
                      selectedDayPredicate: (day) {
                        return isSameDay(widget.controller.selectedDay, day);
                      },
                      onDaySelected: (selectedDay, focusedDay) {
                        widget.controller.setSelectedDay(selectedDay);
                        widget.controller.setFocusedDay(focusedDay);
                        widget.popupManager.showEventDialog();
                        setState(() {});
                      },
                      onPageChanged: (focusedDay) {
                        widget.controller.setFocusedDay(focusedDay);
                        widget.controller.hideAllPopups();
                        widget.eventManager.refreshCurrentMonthEvents();
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
                            onTap: () {
                              widget.controller.setSelectedDay(day);
                              widget.controller.setFocusedDay(focusedDay);
                              widget.popupManager.showEventDialog();
                              setState(() {});
                            },
                            onLongPress: () {
                              widget.controller.setSelectedDay(day);
                              widget.controller.setFocusedDay(focusedDay);
                              widget.popupManager.showTimeTableDialog();
                              setState(() {});
                            },
                            events: widget.controller.getEventsForDay(day),
                            eventColors: widget.controller.eventColors,
                            weatherInfo: widget.controller.getWeatherForDay(
                              day,
                            ),
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
                            onLongPress: () {
                              widget.popupManager.showTimeTableDialog();
                              setState(() {});
                            },
                            events: widget.controller.getEventsForDay(day),
                            eventColors: widget.controller.eventColors,
                            weatherInfo: widget.controller.getWeatherForDay(
                              day,
                            ),
                          );
                        },
                        // 오늘 날짜 셀 빌더
                        todayBuilder: (context, day, focusedDay) {
                          return WeatherCalendarCell(
                            day: day,
                            isSelected: false,
                            isToday: true,
                            onTap: () {
                              widget.controller.setSelectedDay(day);
                              widget.controller.setFocusedDay(focusedDay);
                              widget.popupManager.showEventDialog();
                              setState(() {});
                            },
                            onLongPress: () {
                              widget.controller.setSelectedDay(day);
                              widget.controller.setFocusedDay(focusedDay);
                              widget.popupManager.showTimeTableDialog();
                              setState(() {});
                            },
                            events: widget.controller.getEventsForDay(day),
                            eventColors: widget.controller.eventColors,
                            weatherInfo: widget.controller.getWeatherForDay(
                              day,
                            ),
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
                            ),
                            alignment: Alignment.center,
                            padding: const EdgeInsets.symmetric(vertical: 8.0),
                            child: Text(
                              weekdayNames[weekdayIndex],
                              style: getTextStyle(
                                fontSize: 14,
                                color: textColor,
                                text: weekdayNames[weekdayIndex],
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
                              ), // 연/월 표시
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
                              // 여백을 위한 투명한 아이콘
                              IconButton(
                                icon: Icon(
                                  Icons.calendar_today,
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
                if (widget.controller.showEventPopup)
                  EventPopup(
                    selectedDay: widget.controller.selectedDay,
                    events: widget.controller.getEventsForDay(
                      widget.controller.selectedDay,
                    ),
                    eventColors: widget.controller.eventColors,
                    onClose: () {
                      widget.popupManager.hideEventDialog();
                      setState(() {});
                    },
                    onAddEvent: () {
                      widget.popupManager.showAddEventDialog(context).then((_) {
                        setState(() {});
                      });
                    },
                    onDeleteEvent: (event) async {
                      await widget.eventManager.removeEvent(event);
                      setState(() {});
                    },
                  ),

                // 타임테이블 팝업 오버레이
                if (widget.controller.showTimeTablePopup)
                  TimeTablePopup(
                    selectedDay: widget.controller.selectedDay,
                    timeSlots: widget.controller.getTimeSlotsForDay(
                      widget.controller.selectedDay,
                    ),
                    onClose: () {
                      widget.popupManager.hideTimeTableDialog();
                      setState(() {});
                    },
                    onAddTimeSlot: () {
                      widget.popupManager.showAddTimeSlotDialog(context).then((
                        _,
                      ) {
                        setState(() {});
                      });
                    },
                  ), // 날씨 예보 팝업 오버레이
                if (widget.controller.showWeatherPopup)
                  FutureBuilder<List<WeatherInfo>>(
                    future: WeatherService.get5DayForecast(),
                    builder: (context, snapshot) {
                      // 로딩 중일 때 로딩 인디케이터 표시
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return Center(
                          child: Container(
                            width: MediaQuery.of(context).size.width * 0.7,
                            height: MediaQuery.of(context).size.height * 0.3,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.3),
                                  blurRadius: 10,
                                ),
                              ],
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                CircularProgressIndicator(),
                                SizedBox(height: 16),
                                Text(
                                  '날씨 정보를 불러오는 중...',
                                  style: TextStyle(fontSize: 16),
                                ),
                              ],
                            ),
                          ),
                        );
                      }

                      // 데이터가 로드되었으면 팝업 표시 (5일치만 제한)
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

      // 네비게이션 바
      bottomNavigationBar: CommonNavigationBar(
        selectedIndex: _selectedIndex,
        onItemTapped: _onItemTapped,
      ),
    );
  }

  /// 네비게이션 바 아이템 탭 처리
  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });

    switch (index) {
      case 0: // 캘린더 - 현재 화면이므로 아무 작업 없음
        break;
      case 1: // 마이크 버튼 - STT 실행
        _showVoiceInput();
        break;
      case 2: // 채팅 화면 - EmptyPage로 이동
        _navigateToEmptyPage();
        break;
    }
  }

  /// EmptyPage로 이동
  void _navigateToEmptyPage() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder:
            (context) => EmptyPage(
              onCalendarUpdate: () {
                // 채팅에서 캘린더가 업데이트되면 화면 갱신
                widget.eventManager.refreshCurrentMonthEvents();
                setState(() {});
              },
            ),
      ),
    );
  }

  /// 스낵바 표시
  void _showSnackBar(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  /// 음성 입력 다이얼로그 표시
  void _showVoiceInput() {
    VoiceCommandService.instance.showVoiceInput(
      context: context,
      onCommandProcessed: _handleVoiceCommandResponse,
    );
  }

  /// 음성 명령 처리 결과에 따른 액션
  void _handleVoiceCommandResponse(String response, String command) {
    // 스낵바로 응답 표시
    _showSnackBar(response);

    // 캘린더 관련 명령어 처리
    VoiceCommandService.instance.processCalendarCommand(
      command,
      widget.controller,
      widget.popupManager,
      widget.eventManager,
      () => setState(() {}),
    );

    // 일정 추가 명령어는 컨텍스트가 필요하므로 여기서 처리
    final lowerCommand = command.toLowerCase();
    if (lowerCommand.contains('일정 추가') ||
        lowerCommand.contains('일정추가') ||
        lowerCommand.contains('새 일정') ||
        lowerCommand.contains('새일정')) {
      widget.popupManager.showAddEventDialog(context).then((_) {
        setState(() {});
      });
    }

    // AI 응답이 있는 경우
    if (response.startsWith('AI:')) {
      // 캘린더 이벤트 새로고침 (AI가 수정했을 수 있음)
      widget.eventManager.refreshCurrentMonthEvents();
      setState(() {});
    }
  }
}
