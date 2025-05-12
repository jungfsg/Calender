import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

void main() {
  runApp(const MyApp());
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

class _PixelArtCalendarScreenState extends State<PixelArtCalendarScreen> {
  late DateTime _focusedDay;
  late DateTime _selectedDay;
  late CalendarFormat _calendarFormat;

  // 샘플 이벤트 데이터
  final Map<DateTime, List<String>> _events = {};

  @override
  void initState() {
    super.initState();
    _focusedDay = DateTime.now();
    _selectedDay = DateTime.now();
    _calendarFormat = CalendarFormat.month;

    // 샘플 이벤트 추가
    final today = DateTime.now();
    _events[DateTime(today.year, today.month, today.day + 2)] = [
      '이벤트 1',
      '이벤트 2',
    ];
    _events[DateTime(today.year, today.month, today.day + 5)] = ['이벤트 3'];
  }

  // 날짜별 이벤트 가져오기
  List<String> _getEventsForDay(DateTime day) {
    final normalizedDay = DateTime(day.year, day.month, day.day);
    return _events[normalizedDay] ?? [];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFCCCCCC), // 픽셀아트 스타일의 배경색
      appBar: AppBar(
        title: Text(
          'Calender v250512',
          style: GoogleFonts.pressStart2p(fontSize: 14, color: Colors.white),
        ),
        backgroundColor: Colors.black,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // 캘린더 Container
            Container(
              height: 1000,
              decoration: BoxDecoration(
                color: const Color(0xFFFFFFFF),
                border: Border.all(color: Colors.black, width: 4),
              ),
              child: TableCalendar(
                // 구현할 시간 범위 산정
                firstDay: DateTime.utc(2020, 1, 1),
                lastDay: DateTime.utc(2030, 12, 31),
                focusedDay: _focusedDay,
                calendarFormat: _calendarFormat,

                // 날짜 선택 처리
                selectedDayPredicate: (day) {
                  return isSameDay(_selectedDay, day);
                },
                onDaySelected: (selectedDay, focusedDay) {
                  setState(() {
                    _selectedDay = selectedDay;
                    _focusedDay = focusedDay;
                  });
                },

                // 형식 변경 처리
                onFormatChanged: (format) {
                  setState(() {
                    _calendarFormat = format;
                  });
                },

                // 페이지 변경 처리
                onPageChanged: (focusedDay) {
                  _focusedDay = focusedDay;
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
                  formatButtonVisible: true,
                  formatButtonDecoration: BoxDecoration(
                    color: Colors.black,
                    border: Border.all(
                      color: const Color(0xFF888888),
                      width: 2,
                    ),
                  ),
                  formatButtonTextStyle: GoogleFonts.pressStart2p(
                    fontSize: 8,
                    color: Colors.white,
                  ),
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
                  markersMaxCount: 3,
                  markersAlignment: Alignment.bottomCenter,
                  markerMargin: const EdgeInsets.only(top: 4),
                  markerDecoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.rectangle,
                  ),
                  markerSize: 6,
                ),

                // 캘린더 빌더
                calendarBuilders: CalendarBuilders(
                  // 기본 셀 빌더
                  defaultBuilder: (context, day, focusedDay) {
                    return Container(
                      margin: const EdgeInsets.all(2),
                      alignment: Alignment.center,
                      child: Text(
                        '${day.day}',
                        style: GoogleFonts.pressStart2p(
                          fontSize: 8,
                          color: Colors.black,
                        ),
                      ),
                    );
                  },

                  // 선택된 날짜 셀 빌더
                  selectedBuilder: (context, day, focusedDay) {
                    return Container(
                      margin: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: Colors.blue[800],
                        border: Border.all(color: Colors.black, width: 1),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '${day.day}',
                        style: GoogleFonts.pressStart2p(
                          fontSize: 8,
                          color: Colors.white,
                        ),
                      ),
                    );
                  },

                  // 오늘 날짜 셀 빌더
                  todayBuilder: (context, day, focusedDay) {
                    return Container(
                      margin: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: Colors.amber[300],
                        border: Border.all(color: Colors.black, width: 1),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '${day.day}',
                        style: GoogleFonts.pressStart2p(
                          fontSize: 8,
                          color: Colors.black,
                        ),
                      ),
                    );
                  },

                  // 요일 헤더 빌더
                  dowBuilder: (context, day) {
                    final weekdayNames = ['월', '화', '수', '목', '금', '토', '일'];
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

                  // 이벤트 마커 빌더
                  markerBuilder: (context, date, events) {
                    if (events.isEmpty) return const SizedBox.shrink();

                    return Positioned(
                      bottom: 4,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: List.generate(
                          events.length > 3 ? 3 : events.length,
                          (index) => Container(
                            margin: const EdgeInsets.symmetric(horizontal: 1),
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: Colors.red,
                              border: Border.all(color: Colors.black, width: 1),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),

            const SizedBox(height: 16), // 달력과 이벤트 표시 사이 간격
            // 선택된 날짜의 이벤트 표시
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: Colors.black, width: 4),
                ),
                padding: const EdgeInsets.all(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.black,
                        border: Border.all(
                          color: const Color(0xFF888888),
                          width: 2,
                        ),
                      ),
                      child: Text(
                        '${DateFormat('yyyy.MM.dd').format(_selectedDay)}의 이벤트',
                        style: GoogleFonts.pressStart2p(
                          fontSize: 10,
                          color: Colors.white,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: ListView.builder(
                        itemCount: _getEventsForDay(_selectedDay).length,
                        itemBuilder: (context, index) {
                          final event = _getEventsForDay(_selectedDay)[index];
                          return Container(
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEEEEEE),
                              border: Border.all(color: Colors.black, width: 2),
                            ),
                            child: Text(
                              event,
                              style: GoogleFonts.pressStart2p(
                                fontSize: 10,
                                color: Colors.black,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    if (_getEventsForDay(_selectedDay).isEmpty)
                      Expanded(
                        child: Center(
                          child: Text(
                            '이벤트가 없습니다',
                            style: GoogleFonts.pressStart2p(
                              fontSize: 10,
                              color: Colors.grey,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
