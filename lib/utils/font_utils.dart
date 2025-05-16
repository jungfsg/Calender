import 'package:flutter/material.dart';

// 텍스트 내용에 따라 적절한 폰트를 선택하는 함수
TextStyle getTextStyle({required double fontSize, Color? color, String? text}) {
  // 텍스트가 null이거나 비어있으면 영어 폰트를 기본값으로 사용
  bool hasKorean =
      text != null ? RegExp(r'[ㄱ-ㅎ|ㅏ-ㅣ|가-힣]').hasMatch(text) : false;

  return TextStyle(
    fontFamily: hasKorean ? 'KoreanFont' : 'EnglishFont',
    fontSize: fontSize,
    color: color ?? Colors.black,
  );
}

// 이전 함수와 호환성을 위한 함수 - 텍스트를 분석하여 적절한 폰트 선택
TextStyle getCustomTextStyle({
  required double fontSize,
  Color? color,
  String? text,
  FontWeight? fontWeight,
}) {
  bool hasKorean =
      text != null ? RegExp(r'[ㄱ-ㅎ|ㅏ-ㅣ|가-힣]').hasMatch(text) : false;

  return TextStyle(
    fontFamily: hasKorean ? 'KoreanFont' : 'EnglishFont',
    fontSize: fontSize,
    color: color ?? Colors.black,
    fontWeight: fontWeight,
  );
}
