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
import '../utils/font_utils.dart';
import '../services/google_calendar_service.dart';
import '../services/weather_service.dart';
import '../services/stt_command_service.dart';
import '../screens/chat_screen.dart';
import '../services/tts_service.dart'; // --- ★★★ 추가: TtsService 임포트 ★★★ ---

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

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final DateTime firstDay = DateTime(widget.controller.focusedDay.year, widget.controller.focusedDay.month, 1);
    final DateTime lastDay = DateTime(widget.controller.focusedDay.year, widget.controller.focusedDay.month + 1, 0);
    final int firstWeekday = (firstDay.weekday % 7);
    final int lastDate = lastDay.day;
    final int totalWeeks = ((firstWeekday + lastDate) / 7).ceil();

    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: const Color.fromARGB(255, 162, 222, 141),
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
        isGoogleCalendarConnected: _googleCalendarService.isSignedIn,
        // --- ★★★ 삭제: isTtsEnabled, onTtsToggle 전달 코드 제거 ★★★ ---
      ),
      body: SafeArea(
        bottom: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final availableHeight = constraints.maxHeight;
            const monthHeaderHeight = 65.0;
            const dayOfWeekHeaderHeight = 33.0;
            final weekHeight = (availableHeight - monthHeaderHeight - dayOfWeekHeaderHeight - 16.0) / totalWeeks;

            return Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(3.0, 0.0, 3.0, 0),
                  child: Container(
                    color: Colors.white,
                    child: TableCalendar(
                      firstDay: DateTime.utc(2020, 1, 1),
                      lastDay: DateTime.utc(2030, 12, 31),
                      focusedDay: widget.controller.focusedDay,
                      calendarFormat: _calendarFormat,
                      daysOfWeekHeight: dayOfWeekHeaderHeight,
                      rowHeight: weekHeight,
                      selectedDayPredicate: (day) => isSameDay(widget.controller.selectedDay, day),
                      onDaySelected: (selectedDay, focusedDay) async {
                        widget.controller.setSelectedDay(selectedDay);
                        widget.controller.setFocusedDay(focusedDay);
                        if (widget.controller.shouldLoadEventsForDay(selectedDay)) {
                          try {
                            await widget.eventManager.loadEventsForDay(selectedDay);
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
                          await widget.eventManager.loadEventsForMonth(focusedDay);
                        } catch (e) {
                          print('❌ 월 변경 시 이벤트 로드 실패: $e');
                        }
                        setState(() {});
                      },
                      eventLoader: (day) => widget.controller.getEventsForDay(day).map((e) => e.title).toList(),
                      startingDayOfWeek: StartingDayOfWeek.sunday,
                      headerStyle: HeaderStyle(titleTextStyle: getTextStyle(fontSize: 12, color: Colors.black, text: '달력 제목'), formatButtonVisible: false, leftChevronVisible: false, rightChevronVisible: false, headerMargin: const EdgeInsets.only(bottom: 8), headerPadding: const EdgeInsets.symmetric(vertical: 10), titleCentered: true),
                      daysOfWeekStyle: DaysOfWeekStyle(weekdayStyle: getTextStyle(fontSize: 8, color: Colors.black, text: 'Mon'), weekendStyle: getTextStyle(fontSize: 8, color: const Color.fromARGB(255, 54, 184, 244), text: 'Sat'), decoration: BoxDecoration(color: const Color(0xFFEEEEEE), border: Border.all(color: Colors.black, width: 1))),
                      calendarStyle: CalendarStyle(defaultTextStyle: getTextStyle(fontSize: 8, color: Colors.black, text: '1'), weekendTextStyle: getTextStyle(fontSize: 8, color: Colors.red, text: '1'), selectedTextStyle: getTextStyle(fontSize: 8, color: Colors.white, text: '1'), todayTextStyle: getTextStyle(fontSize: 8, color: Colors.black, text: '1'), outsideTextStyle: getTextStyle(fontSize: 8, color: const Color(0xFF888888), text: '1'), selectedDecoration: BoxDecoration(color: Colors.blue[800]), todayDecoration: BoxDecoration(color: Colors.amber[300]), defaultDecoration: const BoxDecoration(), weekendDecoration: const BoxDecoration(color: Color(0xFFEEEEEE)), outsideDecoration: const BoxDecoration(color: Color(0xFFDDDDDD)), tableBorder: TableBorder.all(color: const Color.fromARGB(24, 0, 0, 0), width: 1), markersMaxCount: 6, markersAlignment: Alignment.bottomCenter, markerMargin: const EdgeInsets.only(top: 2), markerDecoration: const BoxDecoration(color: Colors.transparent), markerSize: 0),
                      calendarBuilders: CalendarBuilders(
                        defaultBuilder: (context, day, focusedDay) => WeatherCalendarCell(day: day, isSelected: false, isToday: false, onTap: () async {
                          widget.controller.setSelectedDay(day);
                          widget.controller.setFocusedDay(focusedDay);
                          if (widget.controller.shouldLoadEventsForDay(day)) {
                            try {
                              await widget.eventManager.loadEventsForDay(day);
                            } catch (e) { print('❌ 날짜 선택 시 이벤트 로드 실패: $e'); }
                          }
                          widget.popupManager.showEventDialog();
                          setState(() {});
                        }, events: widget.controller.getEventsForDay(day), eventColors: widget.controller.eventColors, eventIdColors: widget.controller.eventIdColors, colorIdColors: widget.controller.colorIdColors, weatherInfo: widget.controller.getWeatherForDay(day)),
                        selectedBuilder: (context, day, focusedDay) => WeatherCalendarCell(day: day, isSelected: true, isToday: false, onTap: () {
                          widget.popupManager.showEventDialog();
                          setState(() {});
                        }, events: widget.controller.getEventsForDay(day), eventColors: widget.controller.eventColors, eventIdColors: widget.controller.eventIdColors, colorIdColors: widget.controller.colorIdColors, weatherInfo: widget.controller.getWeatherForDay(day)),
                        todayBuilder: (context, day, focusedDay) => WeatherCalendarCell(day: day, isSelected: false, isToday: true, onTap: () async {
                          widget.controller.setSelectedDay(day);
                          widget.controller.setFocusedDay(focusedDay);
                          if (widget.controller.shouldLoadEventsForDay(day)) {
                            try {
                              await widget.eventManager.loadEventsForDay(day);
                            } catch (e) { print('❌ 오늘 날짜 선택 시 이벤트 로드 실패: $e'); }
                          }
                          widget.popupManager.showEventDialog();
                          setState(() {});
                        }, events: widget.controller.getEventsForDay(day), eventColors: widget.controller.eventColors, eventIdColors: widget.controller.eventIdColors, colorIdColors: widget.controller.colorIdColors, weatherInfo: widget.controller.getWeatherForDay(day)),
                        dowBuilder: (context, day) {
                          final weekdayNames = ['월', '화', '수', '목', '금', '토', '일'];
                          final weekdayIndex = day.weekday - 1;
                          Color textColor;
                          if (day.weekday == DateTime.saturday) {
                            textColor = const Color.fromARGB(255, 54, 184, 244);
                          } else if (day.weekday == DateTime.sunday) {
                            textColor = Colors.red;
                          } else {
                            textColor = Colors.black;
                          }
                          return Container(decoration: const BoxDecoration(color: Color(0xFFEEEEEE)), alignment: Alignment.center, padding: const EdgeInsets.symmetric(vertical: 8.0), child: Text(weekdayNames[weekdayIndex], style: getTextStyle(fontSize: 12, color: textColor, text: weekdayNames[weekdayIndex])));
                        },
                        headerTitleBuilder: (context, month) {
                          final monthNames = ['1월', '2월', '3월', '4월', '5월', '6월', '7월', '8월', '9월', '10월', '11월', '12월'];
                          return Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [IconButton(icon: const Icon(Icons.menu, color: Colors.black), onPressed: () => Scaffold.of(context).openDrawer()), Expanded(child: Center(child: Text('${month.year}년 ${monthNames[month.month - 1]}', style: getTextStyle(fontSize: 16, color: Colors.black)))), const IconButton(icon: Icon(Icons.calendar_today, color: Colors.transparent), onPressed: null)]);
                        },
                      ),
                    ),
                  ),
                ),
                if (widget.controller.showEventPopup)
                  EventPopup(selectedDay: widget.controller.selectedDay, events: widget.controller.getEventsForDay(widget.controller.selectedDay), eventColors: widget.controller.eventColors, eventIdColors: widget.controller.eventIdColors, colorIdColors: widget.controller.colorIdColors, getEventDisplayColor: (event) => widget.controller.getEventDisplayColor(event), popupManager: widget.popupManager, onClose: () {
                    widget.popupManager.hideEventDialog();
                    setState(() {});
                  }, onAddEvent: () {
                    widget.popupManager.showAddEventDialog(context).then((_) => setState(() {}));
                  }, onEditEvent: (event) {
                    widget.popupManager.showEditEventDialog(context, event).then((_) => setState(() {}));
                  }, onDeleteEvent: (event) async {
                    await widget.eventManager.removeEvent(event);
                    setState(() {});
                  }),
                if (widget.controller.showWeatherPopup)
                  FutureBuilder<List<WeatherInfo>>(
                    future: WeatherService.get5DayForecast(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: SizedBox(width: 200, height: 200, child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [CircularProgressIndicator(), SizedBox(height: 16), Text('날씨 정보를 불러오는 중...', style: TextStyle(fontSize: 16))])));
                      }
                      List<WeatherInfo> weatherList = snapshot.data ?? [];
                      if (weatherList.length > 5) {
                        weatherList = weatherList.take(5).toList();
                      }
                      return WeatherSummaryPopup(weatherList: weatherList, onClose: () {
                        widget.popupManager.hideWeatherForecastDialog();
                        setState(() {});
                      });
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
        _navigateToChatScreen();
        break;
    }
  }

  void _navigateToChatScreen() async {
    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ChatScreen(
          onCalendarUpdate: () {
            widget.eventManager.refreshCurrentMonthEvents();
            setState(() {});
          },
          eventManager: widget.eventManager,
        ),
      ),
    );
    if (result != null && result['refreshNavigation'] == true) {
      setState(() {
        _selectedIndex = 0;
      });
      if (result['showVoiceInput'] == true) {
        Future.delayed(const Duration(milliseconds: 100), () {
          _showVoiceInput();
        });
      }
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  void _showVoiceInput() {
    VoiceCommandService.instance.showVoiceInput(
      context: context,
      eventManager: widget.eventManager,
      // --- ★★★ 추가: ttsService 인스턴스 전달 ★★★ ---
      ttsService: widget.ttsService,
      onCommandProcessed: _handleVoiceCommandResponse,
      onCalendarUpdate: () async {
        print('🔄 CalendarWidget: 캘린더 업데이트 콜백 받음');
        await widget.eventManager.loadEventsForDay(widget.controller.selectedDay, forceRefresh: true);
        widget.eventManager.refreshCurrentMonthEvents().then((_) {
          print('🔄 월 전체 이벤트 새로고침 완료');
        });
        setState(() {});
      },
    );
  }

  void _handleVoiceCommandResponse(String response, String command) {
    print('🎤 CalendarWidget: STT 명령 처리 - 명령: "$command", 응답: "$response"');
    _showSnackBar(response);
    VoiceCommandService.instance.processCalendarCommand(command, widget.controller, widget.popupManager, widget.eventManager, () => setState(() {}));
    print('🔄 음성 명령 후 이벤트 강제 새로고침');
    widget.eventManager.refreshCurrentMonthEvents().then((_) {
      widget.eventManager.loadEventsForDay(widget.controller.selectedDay, forceRefresh: true).then((_) {
        setState(() {});
      });
    });
  }
}
