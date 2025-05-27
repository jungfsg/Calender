import 'package:flutter/material.dart';
import '../utils/font_utils.dart';

class CalendarSideMenu extends StatelessWidget {
  final VoidCallback onWeatherForecastTap;

  const CalendarSideMenu({Key? key, required this.onWeatherForecastTap})
    : super(key: key);

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
          ],
        ),
      ),
    );
  }
}
