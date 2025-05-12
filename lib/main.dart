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

// 타임 테이블 항목을 위한 클래스
class TimeSlot {
  final String title;
  final String startTime;
  final String endTime;
  final Color color;

  TimeSlot(this.title, this.startTime, this.endTime, this.color);
}

class _PixelArtCalendarScreenState extends State<PixelArtCalendarScreen> {
  late DateTime _focusedDay;
  late DateTime _selectedDay;
  late CalendarFormat _calendarFormat;

  bool _showEventPopup = false; // 이벤트 팝업 표시 여부
  bool _showTimeTablePopup = false; // 타임테이블 팝업 표시 여부

  // 샘플 이벤트 데이터
  final Map<DateTime, List<String>> _events = {};

  // 샘플 타임 테이블 데이터
  final Map<DateTime, List<TimeSlot>> _timeSlots = {};

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

  @override
  void initState() {
    super.initState();
    _focusedDay = DateTime.now();
    _selectedDay = DateTime.now();
    _calendarFormat = CalendarFormat.month; // 항상 월 형식으로 고정

    // 샘플 이벤트 추가
    final today = DateTime.now();
    _events[DateTime(today.year, today.month, today.day + 2)] = [
      '이벤트 1',
      '이벤트 2',
    ];
    _events[DateTime(today.year, today.month, today.day + 5)] = ['이벤트 3'];
    _events[DateTime(today.year, today.month, today.day)] = [
      '오늘의 이벤트',
      '중요한 미팅',
      '저녁 약속',
    ];

    // 샘플 타임 테이블 추가
    _timeSlots[DateTime(today.year, today.month, today.day)] = [
      TimeSlot('아침 운동', '06:00', '07:00', Colors.green),
      TimeSlot('미팅', '09:00', '10:30', Colors.blue),
      TimeSlot('점심', '12:00', '13:00', Colors.orange),
      TimeSlot('프로젝트 작업', '14:00', '17:00', Colors.purple),
    ];
    _timeSlots[DateTime(today.year, today.month, today.day + 2)] = [
      TimeSlot('병원 예약', '10:00', '11:00', Colors.red),
      TimeSlot('영화 관람', '19:00', '21:30', Colors.indigo),
    ];

    // 이벤트별 색상 할당 - 일관된 색상을 위해
    int colorIndex = 0;
    for (var dayEvents in _events.values) {
      for (var event in dayEvents) {
        if (!_eventColors.containsKey(event)) {
          _eventColors[event] = _colors[colorIndex % _colors.length];
          colorIndex++;
        }
      }
    }
  }

  // 날짜별 이벤트 가져오기
  List<String> _getEventsForDay(DateTime day) {
    final normalizedDay = DateTime(day.year, day.month, day.day);
    return _events[normalizedDay] ?? [];
  }

  // 날짜별 타임 테이블 가져오기
  List<TimeSlot> _getTimeSlotsForDay(DateTime day) {
    final normalizedDay = DateTime(day.year, day.month, day.day);
    return _timeSlots[normalizedDay] ?? [];
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
      body: Stack(
        children: [
          // 메인 콘텐츠
          Padding(
            padding: const EdgeInsets.all(0.0),
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
                                          'assets/images/cat1.png', // 이미지 경로
                                          width: 100, // 원하는 크기로 조정
                                          height: 100, // 원하는 크기로 조정
                                        ),
                                        const SizedBox(
                                          height: 12,
                                        ), // 이미지와 텍스트 사이 간격
                                        Text(
                                          '이벤트가 없습니다',
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
        ],
      ),
    );
  }
}
