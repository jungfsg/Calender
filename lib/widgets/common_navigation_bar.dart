import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:curved_navigation_bar/curved_navigation_bar.dart';

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
      child: CurvedNavigationBar(
        index: selectedIndex,
        height: 70.0,
        backgroundColor:
            selectedIndex == 0
                ? const Color.fromARGB(255, 255, 255, 255)
                : const Color.fromARGB(255, 255, 255, 255),
        color: const Color.fromARGB(255, 162, 222, 141),
        buttonBackgroundColor: const Color.fromARGB(255, 162, 222, 141),
        animationDuration: const Duration(milliseconds: 300),
        onTap: onItemTapped,
        items: [
          Icon(
            Icons.calendar_today,
            size: 30,
            color:
                selectedIndex == 0
                    ? const Color.fromARGB(255, 255, 255, 255)
                    : Colors.grey,
          ),
          Icon(
            Icons.mic,
            size: 35,
            color:
                selectedIndex == 1
                    ? const Color.fromARGB(255, 255, 255, 255)
                    : Colors.grey,
          ),
          Icon(
            Icons.chat,
            size: 30,
            color:
                selectedIndex == 2
                    ? const Color.fromARGB(255, 255, 255, 255)
                    : Colors.grey,
          ),
        ],
      ),
    );
  }
}
