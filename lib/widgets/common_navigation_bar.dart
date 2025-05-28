import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:water_drop_nav_bar/water_drop_nav_bar.dart';

class CommonNavigationBar extends StatelessWidget {
  final int selectedIndex;
  final Function(int) onItemTapped;

  const CommonNavigationBar({
    Key? key,
    required this.selectedIndex,
    required this.onItemTapped,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // 시스템 네비게이션 바 설정
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        systemNavigationBarColor: Color.fromARGB(255, 162, 222, 141),
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
    );

    return SafeArea(
      bottom: true,
      child: WaterDropNavBar(
        backgroundColor: const Color.fromARGB(255, 162, 222, 141),
        onItemSelected: onItemTapped,
        selectedIndex: selectedIndex,
        waterDropColor: Colors.white,
        inactiveIconColor: Colors.white.withOpacity(0.5),
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
