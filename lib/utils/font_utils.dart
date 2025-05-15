import 'package:flutter/material.dart';

// 한글 텍스트인지 확인하는 함수
bool isKorean(String text) {
  return RegExp(r'[\u1100-\u11FF\u3130-\u318F\uAC00-\uD7AF]').hasMatch(text);
}

// 텍스트 스타일 헬퍼 함수
TextStyle getCustomTextStyle({
  required double fontSize,
  Color? color,
  String? text,
}) {
  return TextStyle(
    fontFamily: text != null && isKorean(text) ? 'Stardust' : 'PressStart2P',
    fontSize: fontSize,
    color: color ?? Colors.black,
  );
}
