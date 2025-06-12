// lib/widgets/side_menu.dart (최종 수정본 - TTS 관련 UI 제거)
import 'package:flutter/material.dart';
import '../utils/font_utils.dart';

class CalendarSideMenu extends StatelessWidget {
  final VoidCallback onWeatherForecastTap;
  final VoidCallback onGoogleCalendarDownload;
  final VoidCallback onGoogleCalendarUpload;
  final VoidCallback onLogoutTap;
  final bool isGoogleCalendarConnected;

  // --- ★★★ 수정: TTS 관련 속성 모두 제거 ★★★ ---
  const CalendarSideMenu({
    super.key,
    required this.onWeatherForecastTap,
    required this.onGoogleCalendarDownload,
    required this.onGoogleCalendarUpload,
    required this.onLogoutTap,
    this.isGoogleCalendarConnected = false,
  });

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(
        drawerTheme: const DrawerThemeData(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.zero,
          ),
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
                    const Color(0xFF9AA0F5), const Color(0xFF33B679),
                    const Color(0xFF8E24AA), const Color(0xFFE67C73),
                    const Color(0xFFF6BF26), const Color(0xFFFF8A65),
                    const Color(0xFF039BE5), const Color(0xFF616161),
                    const Color(0xFF3F51B5), const Color(0xFF0B8043),
                    const Color(0xFFD50000),
                  ];

                  final categories = [
                    '업무', '집안일', '기념일', '학교', '운동', '공부',
                    '여행', '기타', '친구', '가족', '병원',
                  ];

                  return Container(
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
