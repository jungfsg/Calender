import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:water_drop_nav_bar/water_drop_nav_bar.dart';

class CommonNavigationBar extends StatelessWidget {
  final int selectedIndex;
  final Function(int) onItemTapped;

  const CommonNavigationBar({
    super.key,
    required this.selectedIndex,
    required this.onItemTapped,
  });

  // 인덱스별 색상 정의 (다양한 옵션들)
  Color _getBackgroundColor(int index) {
    switch (index) {
      default:
        return const Color.fromARGB(255, 162, 222, 141);
    }
  }

  // 물방울 색상 (배경색과 대비되는 색상)
  Color _getWaterDropColor(int index) {
    switch (index) {
      case 0: // Calendar
        return Colors.white;
      case 1: // Mic
        return Colors.white;
      case 2: // Chat
        return Colors.white;
      default:
        return Colors.white;
    }
  }

  // 비활성 아이콘 색상
  Color _getInactiveIconColor(int index) {
    switch (index) {
      case 0: // Calendar
        return Colors.white.withOpacity(0.6);
      case 1: // Mic
        return Colors.white.withOpacity(0.6);
      case 2: // Chat
        return Colors.white.withOpacity(0.6);
      default:
        return Colors.white.withOpacity(0.6);
    }
  }

  @override
  Widget build(BuildContext context) {
    final backgroundColor = _getBackgroundColor(selectedIndex);

    // 시스템 네비게이션 바 색상도 동적으로 변경
    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        systemNavigationBarColor: backgroundColor,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
    );

    return SafeArea(
      bottom: true,
      child: WaterDropNavBar(
        backgroundColor: backgroundColor,
        onItemSelected: onItemTapped,
        selectedIndex: selectedIndex,
        waterDropColor: _getWaterDropColor(selectedIndex),
        inactiveIconColor: _getInactiveIconColor(selectedIndex),
        iconSize: 25,
        bottomPadding: 10.0,
        barItems: [
          BarItem(
            filledIcon: Icons.calendar_today,
            outlinedIcon: Icons.calendar_today_outlined,
          ),
          BarItem(filledIcon: Icons.mic, outlinedIcon: Icons.mic_outlined),
          BarItem(filledIcon: Icons.chat, outlinedIcon: Icons.chat_outlined),
        ],
      ),
    );
  }
}
