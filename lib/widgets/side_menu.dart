// lib/widgets/side_menu.dart (최종 수정본 - TTS 관련 UI 제거)
import 'package:flutter/material.dart';
import '../utils/font_utils.dart';
import '../models/event.dart';

class CalendarSideMenu extends StatelessWidget {
  final VoidCallback onWeatherForecastTap;
  final VoidCallback onGoogleCalendarDownload;
  final VoidCallback onGoogleCalendarUpload;
  final VoidCallback onLogoutTap;
  final VoidCallback onBriefingSettingsTap; // 🆕 브리핑 설정 콜백 추가
  final bool isGoogleCalendarConnected;
  final List<Event> events; // 🆕 이벤트 목록 추가
  final DateTime currentMonth; // 🆕 현재 월 정보 추가

  // --- ★★★ 수정: TTS 관련 속성 모두 제거 ★★★ ---
  const CalendarSideMenu({
    super.key,
    required this.onWeatherForecastTap,
    required this.onGoogleCalendarDownload,
    required this.onGoogleCalendarUpload,
    required this.onLogoutTap,
    required this.onBriefingSettingsTap, // 🆕 브리핑 설정 콜백 추가
    this.isGoogleCalendarConnected = false,
    required this.events, // 🆕 이벤트 목록 필수로 받기
    required this.currentMonth, // 🆕 현재 월 정보 필수로 받기
  });

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(
        drawerTheme: const DrawerThemeData(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        ),
      ),
      child: Drawer(
        width: MediaQuery.of(context).size.width * 0.75,
        backgroundColor: const Color.fromARGB(255, 255, 255, 255),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(16, 40, 16, 16),
              color: Colors.black,
              width: double.infinity,
              child: Text(
                '캘린더 메뉴',
                style: getTextStyle(fontSize: 14, color: Colors.white),
              ),
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: const Icon(Icons.wb_sunny, color: Colors.orange),
              title: Text(
                '5일간 날씨 예보',
                style: getTextStyle(fontSize: 12, color: Colors.black),
              ),
              onTap: () {
                Navigator.pop(context);
                onWeatherForecastTap();
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.notifications_active,
                color: Colors.blue,
              ),
              title: Text(
                '브리핑 설정',
                style: getTextStyle(fontSize: 12, color: Colors.black),
              ),
              subtitle: Text(
                '일일 일정 브리핑 알림 설정',
                style: getTextStyle(fontSize: 10, color: Colors.grey),
              ),
              onTap: () {
                Navigator.pop(context);
                onBriefingSettingsTap();
              },
            ),

            // --- ★★★ 수정: TTS 설정 스위치와 구분선(Divider) 완전 제거 ★★★ ---
            // const Divider(),
            // SwitchListTile(...) -> 이 부분이 완전히 삭제되었습니다.
            const Spacer(),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.category, color: Colors.blue),
              title: Text(
                '카테고리',
                style: getTextStyle(fontSize: 12, color: Colors.black),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                  childAspectRatio: 1,
                ),
                itemCount: 11,
                itemBuilder: (context, index) {
                  final colors = [
                    const Color(0xFF9AA0F5),
                    const Color(0xFF33B679),
                    const Color(0xFF8E24AA),
                    const Color(0xFFE67C73),
                    const Color(0xFFF6BF26),
                    const Color(0xFFFF8A65),
                    const Color(0xFF039BE5),
                    const Color(0xFF616161),
                    const Color(0xFF3F51B5),
                    const Color(0xFF0B8043),
                    const Color(0xFFD50000),
                  ];

                  final categories = [
                    '업무',
                    '집안일',
                    '기념일',
                    '학교',
                    '운동',
                    '공부',
                    '여행',
                    '기타',
                    '친구',
                    '가족',
                    '병원',
                  ];

                  return GestureDetector(
                    onTap: () {
                      Navigator.pop(context);
                      _showCategoryEvents(context, categories[index], colors[index]);
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: colors[index],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Colors.grey.shade300,
                          width: 0.5,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          categories[index],
                          style: getTextStyle(fontSize: 10, color: Colors.white),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const Divider(
              color: Color.fromARGB(255, 230, 103, 94),
              thickness: 1,
              indent: 16,
              endIndent: 16,
            ),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: Text(
                '로그아웃',
                style: getTextStyle(fontSize: 12, color: Colors.red),
              ),
              subtitle: Text(
                'Google 계정에서 로그아웃',
                style: getTextStyle(fontSize: 10, color: Colors.grey),
              ),
              onTap: () {
                Navigator.pop(context);
                _showLogoutConfirmDialog(context);
              },
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  // 🆕 카테고리별 일정 목록을 보여주는 팝업
  void _showCategoryEvents(BuildContext context, String category, Color categoryColor) {
    // 현재 월의 시작일과 마지막일 계산
    final firstDayOfMonth = DateTime(currentMonth.year, currentMonth.month, 1);
    final lastDayOfMonth = DateTime(currentMonth.year, currentMonth.month + 1, 0);

    // 해당 카테고리의 당월 일정 필터링
    final filteredEvents = events.where((event) {
      // 카테고리 매칭 (직접 카테고리 필드가 있는 경우 우선, 없으면 colorId 기반으로 추정)
      bool isMatchingCategory = false;
      
      if (event.category != null && event.category == category) {
        isMatchingCategory = true;
      } else {
        // colorId 기반으로 카테고리 추정
        final colorIdToCategory = {
          '1': '업무',     // 라벤더
          '2': '집안일',   // 세이지
          '3': '기념일',   // 포도
          '4': '학교',     // 플라밍고
          '5': '운동',     // 바나나
          '6': '공부',     // 귤
          '7': '여행',     // 공작새
          '8': '기타',     // 그래파이트
          '9': '친구',     // 블루베리
          '10': '가족',    // 바질
          '11': '병원',    // 토마토
        };
        
        if (event.colorId != null && colorIdToCategory[event.colorId] == category) {
          isMatchingCategory = true;
        }
      }

      // 당월 이벤트 여부 확인
      bool isCurrentMonth = false;
      if (event.isMultiDay) {
        // 멀티데이 이벤트의 경우 시작일 또는 종료일이 현재 월에 포함되거나, 현재 월이 이벤트 기간에 포함되는지 확인
        final startDate = event.startDate ?? event.date;
        final endDate = event.endDate ?? event.date;
        
        isCurrentMonth = (startDate.year == currentMonth.year && startDate.month == currentMonth.month) ||
                        (endDate.year == currentMonth.year && endDate.month == currentMonth.month) ||
                        (startDate.isBefore(firstDayOfMonth) && endDate.isAfter(lastDayOfMonth));
      } else {
        // 단일날짜 이벤트의 경우
        isCurrentMonth = event.date.year == currentMonth.year && event.date.month == currentMonth.month;
      }

      return isMatchingCategory && isCurrentMonth;
    }).toList();

    // 날짜순으로 정렬
    filteredEvents.sort((a, b) => a.date.compareTo(b.date));

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  color: categoryColor,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '$category 일정',
                style: getTextStyle(fontSize: 16, color: Colors.black),
              ),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            height: filteredEvents.isEmpty ? 100 : 400,
            child: filteredEvents.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.event_busy,
                          size: 48,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${currentMonth.month}월에 $category 일정이 없습니다.',
                          style: getTextStyle(fontSize: 12, color: Colors.grey),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount: filteredEvents.length,
                    itemBuilder: (context, index) {
                      final event = filteredEvents[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: Container(
                            width: 4,
                            height: double.infinity,
                            color: event.getDisplayColor(),
                          ),
                          title: Text(
                            event.title,
                            style: getTextStyle(fontSize: 12, color: Colors.black),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (event.isMultiDay)
                                Text(
                                  '${_formatDate(event.startDate ?? event.date)} ~ ${_formatDate(event.endDate ?? event.date)}',
                                  style: getTextStyle(fontSize: 10, color: Colors.grey),
                                )
                              else
                                Text(
                                  '${_formatDate(event.date)}${event.time.isNotEmpty ? ' ${event.time}' : ''}',
                                  style: getTextStyle(fontSize: 10, color: Colors.grey),
                                ),
                              if (event.description.isNotEmpty)
                                Text(
                                  event.description,
                                  style: getTextStyle(fontSize: 10, color: Colors.grey[600]),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                            ],
                          ),
                          isThreeLine: event.description.isNotEmpty,
                        ),
                      );
                    },
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                '닫기',
                style: getTextStyle(fontSize: 12, color: Colors.blue),
              ),
            ),
          ],
        );
      },
    );
  }

  // 날짜 포맷팅 헬퍼 메서드
  String _formatDate(DateTime date) {
    return '${date.month}/${date.day}';
  }

  void _showLogoutConfirmDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            '로그아웃',
            style: getTextStyle(fontSize: 16, color: Colors.black),
          ),
          content: Text(
            'Google 계정에서 로그아웃하시겠습니까?\n로그인 화면으로 돌아갑니다.',
            style: getTextStyle(fontSize: 12, color: Colors.black),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                '취소',
                style: getTextStyle(fontSize: 12, color: Colors.grey),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                onLogoutTap();
              },
              child: Text(
                '로그아웃',
                style: getTextStyle(fontSize: 12, color: Colors.red),
              ),
            ),
          ],
        );
      },
    );
  }
}
