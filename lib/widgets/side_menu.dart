// lib/widgets/side_menu.dart (최종 수정본 - TTS 관련 UI 제거)
import 'package:flutter/material.dart';
import '../utils/font_utils.dart';
import '../models/event.dart';
import '../managers/theme_manager.dart'; //☑️ 테마 관련 추가

// class CalendarSideMenu extends StatelessWidget {
//☑️ 테마 관련 수정(위젯 클래스 수정)
class CalendarSideMenu extends StatefulWidget {
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

//☑️ 테마 관련 추가
  @override
  State<CalendarSideMenu> createState() => _CalendarSideMenuState();
}

class _CalendarSideMenuState extends State<CalendarSideMenu> {
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
    return Theme(
      data: Theme.of(context).copyWith(
        drawerTheme: const DrawerThemeData(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        ),
      ),
      child: Drawer(
        width: MediaQuery.of(context).size.width * 0.75,
        // backgroundColor: const Color.fromARGB(255, 255, 255, 255),
         //☑️테마에 따른 배경색 변경
        backgroundColor: ThemeManager.getSidebarBackgroundColor(), // ☑️ 사이드바 전용 배경색 사용
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(16, 40, 16, 16),
              // color: Colors.black,
              //☑️테마에 따른 텍스트색 변경
              color: ThemeManager.getTextColor(
                lightColor: Colors.black,
                darkColor: const Color(0xFF2C2C2C),
              ),
              width: double.infinity,
              child: Text(
                '캘린더 메뉴',
                style: getTextStyle(fontSize: 14,
                 color: Colors.white),
              ),
            ),
            const SizedBox(height: 20),
            // ☑️ _HE_250620_5일간 날씨 예보 ListTile 수정
            ListTile(
              // leading: const Icon(Icons.wb_sunny, color: Colors.orange),
              leading: Icon( // ☑️ _HE_250620_const → 제거
                Icons.wb_sunny, 
                color: ThemeManager.isDarkMode 
                    ? Colors.orange[300] // ☑️ 다크 모드용 밝은 오렌지
                    : Colors.orange,    // ☑️ 라이트 모드용 기본 오렌지
              ),
              title: Text(
                '5일간 날씨 예보',
                style: getTextStyle(
                  fontSize: 12, 
                  // color: Colors.black
                  color: ThemeManager.getTextColor(), // ☑️ _HE_250620_추가
                ),
              ),
              subtitle: Text(
                '일일 일정 브리핑 알림 설정',
                style: getTextStyle(fontSize: 10, color: Colors.grey),
              ),
              onTap: () {
                Navigator.pop(context);
                // onWeatherForecastTap();
                //☑️ 테마 관련 수정
                 widget.onWeatherForecastTap();
              },
            ),
            ListTile( // ☑️ 다크 모드 색상 적용 완료
              leading: Icon( // ☑️ const 제거하고 다크 모드 색상 적용
                Icons.notifications_active,
                color: ThemeManager.isDarkMode 
                    ? Colors.blue[300] // ☑️ 다크 모드용 밝은 파란색
                    : Colors.blue,     // ☑️ 라이트 모드용 기본 파란색
              ),
              title: Text(
                '브리핑 설정',
                // style: getTextStyle(fontSize: 12, color: Colors.black),
                style: getTextStyle(
                  fontSize: 12, 
                  color: ThemeManager.getTextColor(), // ☑️ 다크 모드 색상 적용
                ),
              ),
              subtitle: Text(
                '일일 일정 브리핑 알림 설정',
                // style: getTextStyle(fontSize: 10, color: Colors.grey), 
                style: getTextStyle(
                  fontSize: 10, 
                  color: ThemeManager.getPopupSecondaryTextColor(), // ☑️ 다크 모드 색상 적용
                ),
              ),
              onTap: () {
                Navigator.pop(context);
                widget.onBriefingSettingsTap();
              },
            ),

// --- ★★★ 수정: TTS 설정 스위치와 구분선(Divider) 완전 제거 ★★★ ---
            // const Divider(),
            // SwitchListTile(...) -> 이 부분이 완전히 삭제되었습니다.
            const Spacer(),
            const Divider(),
            ListTile(
              // leading: const Icon(Icons.category, color: Colors.blue),
              leading: Icon( // ☑️ _HE_250620_const → 제거
                Icons.category, 
                color: ThemeManager.isDarkMode 
                    ? Colors.blue[300] // ☑️ 다크 모드용 밝은 파란색
                    : Colors.blue,     // ☑️ 라이트 모드용 기본 파란색
              ),
              title: Text(
                '카테고리',
                style: getTextStyle(
                  fontSize: 12, 
                  // color: Colors.black
                  color: ThemeManager.getTextColor(), // ☑️ _HE_250620_변경
                ),
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
                          // color: Colors.grey.shade300,
                          color: ThemeManager.getPopupBorderColor(), // ☑️ _HE_250620_변경  
                          width: 0.5,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          categories[index],
                          style: getTextStyle(fontSize: 10, color: Colors.white), //☑️ 흰색 텍스트 유지
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
             //☑️ 테마 관련 추가
            ListTile(
              leading: Icon(
                // ThemeManager.isDarkMode ? Icons.dark_mode : Icons.light_mode,
                ThemeManager.isDarkMode ? Icons.light_mode : Icons.dark_mode,
                color: ThemeManager.getTextColor(),
              ),
              title: Text(
                '다크 모드',
                style: getThemeTextStyle(fontSize: 12),
              ),
              trailing: Switch(
                value: ThemeManager.isDarkMode,
                onChanged: (value) async {
                  await ThemeManager.toggleTheme();
                  // // 앱 새로고침
                  // if (mounted) {
                  //   Navigator.pushAndRemoveUntil(
                  //     context,
                  //     MaterialPageRoute(builder: (context) => 
                  //       // 현재 홈 화면으로 돌아가기
                  //       LoginScreen(ttsService: TtsService())
                  //     ),
                  //     (route) => false,
                  //   );
                  // }
                },
              ),
            ), //☑️ 테마 관련 추가(여기까지)


            ListTile(
              // leading: const Icon(Icons.logout, color: Colors.red),
              leading: Icon( // ☑️ _HE_250620_const → 제거
                Icons.logout, 
                color: ThemeManager.isDarkMode 
                    ? Colors.red[300] // ☑️ 다크 모드용 밝은 빨간색
                    : Colors.red,     // ☑️ 라이트 모드용 기본 빨간색
              ),
              title: Text(
                '로그아웃',
                // style: getTextStyle(fontSize: 12, color: Colors.red),
                style: getTextStyle(
                  fontSize: 12, 
                  color: ThemeManager.isDarkMode  
                      ? Colors.red[300] // ☑️ 다크 모드용 밝은 빨간색
                      : Colors.red,     // ☑️ 라이트 모드용 기본 빨간색
                ),
              ),
              subtitle: Text(
                'Google 계정에서 로그아웃',
                style: getTextStyle(
                  fontSize: 10, 
                  // color: Colors.grey
                  color: ThemeManager.getPopupSecondaryTextColor(), // ☑️ _HE_250620_변경
                ),
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
  // 🆕 카테고리별 일정 목록을 보여주는 팝업 - ☑️ 다크 모드 색상 적용
  void _showCategoryEvents(BuildContext context, String category, Color categoryColor) {
    // 현재 월의 시작일과 마지막일 계산
    final firstDayOfMonth = DateTime(widget.currentMonth.year, widget.currentMonth.month, 1);
    final lastDayOfMonth = DateTime(widget.currentMonth.year, widget.currentMonth.month + 1, 0);

    // 해당 카테고리의 당월 일정 필터링
    final filteredEvents = widget.events.where((event) {
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
        
        isCurrentMonth = (startDate.year == widget.currentMonth.year && startDate.month == widget.currentMonth.month) ||
                        (endDate.year == widget.currentMonth.year && endDate.month == widget.currentMonth.month) ||
                        (startDate.isBefore(firstDayOfMonth) && endDate.isAfter(lastDayOfMonth));
      } else {
        // 단일날짜 이벤트의 경우
        isCurrentMonth = event.date.year == widget.currentMonth.year && event.date.month == widget.currentMonth.month;
      }

      return isMatchingCategory && isCurrentMonth;
    }).toList();

    // 날짜순으로 정렬
    filteredEvents.sort((a, b) => a.date.compareTo(b.date));

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          // ☑️ 다크 모드 배경색과 테두리 적용
          backgroundColor: ThemeManager.getPopupBackgroundColor(),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: ThemeManager.getPopupBorderColor(),
              width: 1,
            ),
          ),
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
                // style: getTextStyle(fontSize: 16, color: Colors.black),
                style: getTextStyle(
                  fontSize: 16, 
                  color: ThemeManager.getTextColor(), // ☑️ 다크 모드 텍스트 색상 적용
                ),
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
                          // color: Colors.grey[400],
                          color: ThemeManager.getPopupSecondaryTextColor(), // ☑️ 다크 모드 아이콘 색상 적용
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${widget.currentMonth.month}월에 $category 일정이 없습니다.',
                          // style: getTextStyle(fontSize: 12, color: Colors.grey),
                          style: getTextStyle(
                            fontSize: 12, 
                            color: ThemeManager.getPopupSecondaryTextColor(), // ☑️ 다크 모드 텍스트 색상 적용
                          ),
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
                        // ☑️ 다크 모드 카드 색상 적용
                        color: ThemeManager.getPopupSecondaryBackgroundColor(),
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: BorderSide(
                            color: ThemeManager.getPopupBorderColor(),
                            width: 0.5,
                          ),
                        ),
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: Container(
                            width: 4,
                            height: double.infinity,
                            color: event.getDisplayColor(),
                          ),
                          title: Text(
                            event.title,
                            // style: getTextStyle(fontSize: 12, color: Colors.black),
                            style: getTextStyle(
                              fontSize: 12, 
                              color: ThemeManager.getTextColor(), // ☑️ 다크 모드 텍스트 색상 적용
                            ),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (event.isMultiDay)
                                Text(
                                  '${_formatDate(event.startDate ?? event.date)} ~ ${_formatDate(event.endDate ?? event.date)}',
                                  // style: getTextStyle(fontSize: 10, color: Colors.grey),
                                  style: getTextStyle(
                                    fontSize: 10, 
                                    color: ThemeManager.getPopupSecondaryTextColor(), // ☑️ 다크 모드 텍스트 색상 적용
                                  ),
                                )
                              else
                                Text(
                                  '${_formatDate(event.date)}${event.time.isNotEmpty ? ' ${event.time}' : ''}',
                                  // style: getTextStyle(fontSize: 10, color: Colors.grey),
                                  style: getTextStyle(
                                    fontSize: 10, 
                                    color: ThemeManager.getPopupSecondaryTextColor(), // ☑️ 다크 모드 텍스트 색상 적용
                                  ),
                                ),
                              if (event.description.isNotEmpty)
                                Text(
                                  event.description,
                                  // style: getTextStyle(fontSize: 10, color: Colors.grey[600]),
                                  style: getTextStyle(
                                    fontSize: 10, 
                                    color: ThemeManager.getPopupSecondaryTextColor(), // ☑️ 다크 모드 텍스트 색상 적용
                                  ),
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
                // style: getTextStyle(fontSize: 12, color: Colors.blue),
                style: getTextStyle(
                  fontSize: 12, 
                  color: ThemeManager.isDarkMode 
                      ? Colors.blue[300]! // ☑️ 다크 모드용 밝은 파란색
                      : Colors.blue,      // ☑️ 라이트 모드용 기본 파란색
                ),
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

  
//☑️ 로그아웃 확인 팝업_다크테마 적용_250619
  void _showLogoutConfirmDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          // ☑️ 추가
          backgroundColor: ThemeManager.getEventPopupBackgroundColor(),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: ThemeManager.getEventPopupBorderColor(),
              width: 1,
            ),
          ), // ☑️ 추가(여기까지)
          
          title: Text(
            '로그아웃',
            // style: getTextStyle(fontSize: 16, color: Colors.black),
            style: getTextStyle(
              fontSize: 16,
              color: ThemeManager.getEventPopupTextColor(), // ☑️ 변경
            ),
          ),
          content: Text(
            'Google 계정에서 로그아웃하시겠습니까?\n로그인 화면으로 돌아갑니다.',
            // style: getTextStyle(fontSize: 12, color: Colors.black),
            style: getTextStyle(
              fontSize: 12,
              color: ThemeManager.getEventPopupTextColor(), // ☑️ 변경
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                '취소',
                //style: getTextStyle(fontSize: 12, color: Colors.grey),
                style: getTextStyle( // ☑️ 변경
                  fontSize: 12,
                  color: ThemeManager.getTextColor(
                    lightColor: Colors.grey,
                    darkColor: Colors.grey[400]!,
                  ),
                ),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                // onLogoutTap();
                //☑️ 테마 관련 수정
                 widget.onLogoutTap();
              },
              child: Text(
                '로그아웃',
                // style: getTextStyle(fontSize: 12, color: Colors.red),
                style: getTextStyle(
                  fontSize: 12,
                  color: ThemeManager.getEventPopupCloseButtonColor(), // ☑️ 변경
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
