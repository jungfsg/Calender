import 'package:flutter/material.dart';
import '../managers/theme_manager.dart'; // ☑️ _HE_테마 관리자 추가

// 단일 폰트를 사용하는 간단한 스타일 함수
TextStyle getTextStyle({required double fontSize, Color? color, String? text, bool? useThemeColor, //☑️새로운 옵션
}) {

//☑️ 테마 색상 사용 옵션 추가
 Color textColor = color ?? 
    (useThemeColor == true ? ThemeManager.getTextColor() : Colors.black);

  // 폰트 크기를 약 1.3배 크게 조정하여 작게 보이는 문제 해결
  return TextStyle(
    fontFamily: 'KoreanFont', // 한글과 영어를 모두 지원하는 폰트로 통일
    fontSize: fontSize * 1.3, // 폰트 크기를 1.3배 증가
  //  color: color ?? Colors.black,
  color: textColor, //☑️ 테마 색상 사용 옵션 추가
  );
}

// // 이전 함수와 호환성을 위한 함수
// TextStyle getCustomTextStyle({
//   required double fontSize,
//   Color? color,
//   String? text,
//   FontWeight? fontWeight,
// }) {
//   return TextStyle(
//     fontFamily: 'KoreanFont', // 한글과 영어를 모두 지원하는 폰트로 통일
//     fontSize: fontSize * 1.3, // 일괄적으로 폰트 크기를 지정한대로 증가
//     color: color ?? Colors.black,
//     fontWeight: fontWeight,
//   );
// }

// ☑️ 기존 코드와 100% 호환되는 새로운 함수 추가
TextStyle getThemeTextStyle({
  required double fontSize, 
  String? text,
  Color? lightColor,
  Color? darkColor,
}) {
  return TextStyle(
    fontFamily: 'KoreanFont',
    fontSize: fontSize * 1.3,
    color: ThemeManager.getTextColor(
      lightColor: lightColor, 
      darkColor: darkColor
    ),
  );
}