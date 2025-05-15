import 'package:flutter/material.dart';
import '../utils/font_utils.dart';

class EmptyPage extends StatelessWidget {
  const EmptyPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          '빈 페이지',
          style: getCustomTextStyle(
            fontSize: 14,
            color: Colors.white,
            text: '빈 페이지',
          ),
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
              style: getCustomTextStyle(fontSize: 12, text: '아직 준비 중인 페이지입니다'),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                '돌아가기',
                style: getCustomTextStyle(fontSize: 10, text: '돌아가기'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
