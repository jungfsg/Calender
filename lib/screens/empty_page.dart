import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class EmptyPage extends StatelessWidget {
  const EmptyPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          '빈 페이지',
          style: GoogleFonts.pressStart2p(fontSize: 14, color: Colors.white),
        ),
        backgroundColor: Colors.black,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              'assets/images/balloon (1).gif',
              width: 200,
              height: 200,
            ),
            const SizedBox(height: 20),
            Text(
              '아직 준비 중인 페이지입니다',
              style: GoogleFonts.pressStart2p(fontSize: 12),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                '돌아가기',
                style: GoogleFonts.pressStart2p(fontSize: 10),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
