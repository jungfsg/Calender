import 'package:flutter/material.dart';

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
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenHeight = MediaQuery.of(context).size.height;
        final navBarHeight = (screenHeight * 0.1).clamp(60.0, 100.0);

        return Container(
          height: navBarHeight,
          decoration: BoxDecoration(
            color:
                selectedIndex == 0
                    ? const Color.fromARGB(255, 162, 222, 141) // 캘린더 화면의 색상
                    : Colors.white, // 채팅 화면의 색상
            boxShadow: [
              BoxShadow(color: Colors.black12, blurRadius: 4, spreadRadius: 0),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              IconButton(
                iconSize: navBarHeight * 0.2,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: Icon(
                  Icons.calendar_today,
                  color: selectedIndex == 0 ? Colors.blue[800] : Colors.grey,
                ),
                onPressed: () => onItemTapped(0),
              ),
              IconButton(
                iconSize: navBarHeight * 0.2,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: Icon(
                  Icons.chat,
                  color: selectedIndex == 1 ? Colors.blue[800] : Colors.grey,
                ),
                onPressed: () => onItemTapped(1),
              ),
            ],
          ),
        );
      },
    );
  }
}
