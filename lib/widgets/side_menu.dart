import 'package:flutter/material.dart';
import '../utils/font_utils.dart';

class CalendarSideMenu extends StatelessWidget {
  final VoidCallback onWeatherForecastTap;
  final VoidCallback onGoogleCalendarSyncTap;
  final VoidCallback onLogoutTap; // 로그아웃 콜백 추가
  final bool isGoogleCalendarConnected; // Google Calendar 연결 상태

  const CalendarSideMenu({
    Key? key, 
    required this.onWeatherForecastTap,
    required this.onGoogleCalendarSyncTap,
    required this.onLogoutTap, // 필수 매개변수로 추가
    this.isGoogleCalendarConnected = false, // 기본값은 연결되지 않음
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Theme(
      // Drawer의 모서리를 직각으로 변경
      data: Theme.of(context).copyWith(
        drawerTheme: DrawerThemeData(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.zero, // 모서리 각도 0으로 설정
          ),
        ),
      ),
      child: Drawer(
        width: MediaQuery.of(context).size.width * 0.6, // 화면 너비의 60%로 설정
        backgroundColor: Colors.white,
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
            // 5일간 날씨 예보 버튼
            ListTile(
              leading: const Icon(Icons.wb_sunny, color: Colors.orange),
              title: Text(
                '5일간 날씨 예보',
                style: getTextStyle(fontSize: 12, color: Colors.black),
              ),
              onTap: () {
                // 드로어 닫기
                Navigator.pop(context);
                // 날씨 예보 다이얼로그 표시
                onWeatherForecastTap();
              },
            ),
            // Google Calendar 동기화 버튼
            ListTile(
              leading: Icon(
                Icons.sync, 
                color: isGoogleCalendarConnected ? Colors.green : Colors.blue,
              ),
              title: Text(
                isGoogleCalendarConnected 
                  ? 'Google Calendar 동기화 (연결됨)'
                  : 'Google Calendar 동기화',
                style: getTextStyle(fontSize: 12, color: Colors.black),
              ),
              subtitle: isGoogleCalendarConnected 
                ? Text(
                    '양방향 동기화 활성화됨',
                    style: getTextStyle(fontSize: 10, color: Colors.green),
                  )
                : Text(
                    '터치하여 연결하기',
                    style: getTextStyle(fontSize: 10, color: Colors.grey),
                  ),
              onTap: () {
                // 드로어 닫기
                Navigator.pop(context);
                // Google Calendar 동기화 실행
                onGoogleCalendarSyncTap();
              },
            ),
            // 하단에 로그아웃 버튼을 배치하기 위한 Spacer
            const Spacer(),
            // 구분선
            const Divider(
              color: Color.fromARGB(255, 230, 103, 94),
              thickness: 1,
              indent: 16,
              endIndent: 16,
            ),
            // 로그아웃 버튼
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
                // 드로어 닫기
                Navigator.pop(context);
                // 로그아웃 확인 다이얼로그 표시
                _showLogoutConfirmDialog(context);
              },
            ),
            const SizedBox(height: 20), // 하단 여백
          ],
        ),
      ),
    );
  }

  // 로그아웃 확인 다이얼로그
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
              onPressed: () {
                Navigator.of(context).pop(); // 다이얼로그 닫기
              },
              child: Text(
                '취소',
                style: getTextStyle(fontSize: 12, color: Colors.grey),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // 다이얼로그 닫기
                onLogoutTap(); // 로그아웃 실행
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
