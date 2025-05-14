import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class EmptyPage extends StatelessWidget {
  const EmptyPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 162, 222, 141), // 패딩 뒤쪽 배경색
      appBar: AppBar(
        title: Text(
          '빈 페이지',
          style: GoogleFonts.pressStart2p(fontSize: 14, color: Colors.white),
        ),
        backgroundColor: Colors.black,
      ),
      body: Padding(
        padding: const EdgeInsets.all(22.0),
        child: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: const BoxDecoration(color: Colors.white),
          child: Center(
            child: Text(
              '빈 페이지입니다',
              style: GoogleFonts.pressStart2p(
                fontSize: 12,
                color: Colors.black,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
