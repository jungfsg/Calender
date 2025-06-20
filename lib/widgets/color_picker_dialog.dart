import 'package:flutter/material.dart';
import '../utils/font_utils.dart';
import '../managers/theme_manager.dart'; // ☑️ 다크모드 적용

/// Google Calendar 표준 색상 선택 다이얼로그
class ColorPickerDialog extends StatefulWidget {
  final int? initialColorId;
  final Function(int colorId) onColorSelected;

  const ColorPickerDialog({
    super.key,
    this.initialColorId,
    required this.onColorSelected,
  });

  @override
  State<ColorPickerDialog> createState() => _ColorPickerDialogState();
}

class _ColorPickerDialogState extends State<ColorPickerDialog> {
  int? selectedColorId;

  // Google Calendar 표준 11가지 색상 (colorId 1-11)
  static const Map<int, Map<String, dynamic>> googleColors = {
    1: {'name': '라벤더', 'color': Color(0xFF9AA0F5), 'text': '업무'},
    2: {'name': '세이지', 'color': Color(0xFF33B679), 'text': '집안일'},
    3: {'name': '포도', 'color': Color(0xFF8E24AA), 'text': '기념일'},
    4: {'name': '플라밍고', 'color': Color(0xFFE67C73), 'text': '학교'},
    5: {'name': '바나나', 'color': Color(0xFFF6BF26), 'text': '운동'},
    6: {'name': '귤', 'color': Color(0xFFFF8A65), 'text': '공부'},
    7: {'name': '공작새', 'color': Color(0xFF039BE5), 'text': '여행'},
    8: {'name': '그래파이트', 'color': Color(0xFF616161), 'text': '기타'},
    9: {'name': '블루베리', 'color': Color(0xFF3F51B5), 'text': '친구'},
    10: {'name': '바질', 'color': Color(0xFF0B8043), 'text': '가족'},
    11: {'name': '토마토', 'color': Color(0xFFD50000), 'text': '병원'},
  };

  @override
  void initState() {
    super.initState();
    selectedColorId = widget.initialColorId ?? 1;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      // ☑️ 테마 적용_색상 선택 다이얼로그_250619
      backgroundColor: ThemeManager.getColorPickerBackgroundColor(),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: ThemeManager.getEventPopupBorderColor(),
          width: 1,
        ),
      ), // ☑️ 테마 적용(여기까지)

      title: Text(
        '색상 선택',
        style: getTextStyle(
          fontSize: 18,
          color: ThemeManager.getColorPickerTextColor(), // ☑️ 변경
          text: '색상 선택',
        ),
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: GridView.builder(
          shrinkWrap: true,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            childAspectRatio: 1,
          ),
          itemCount: googleColors.length,
          itemBuilder: (context, index) {
            final colorId = googleColors.keys.elementAt(index);
            final colorData = googleColors[colorId]!;
            final isSelected = selectedColorId == colorId;

            return GestureDetector(
              onTap: () {
                setState(() {
                  selectedColorId = colorId;
                });
              },
              child: Container(
                decoration: BoxDecoration(
                  color: colorData['color'],
                  shape: BoxShape.circle,
                  // border: // ☑️ _HE_색상 선택 팝업 수정_250620
                  //     isSelected
                  //         ? Border.all(
                  //           color: ThemeManager.getColorPickerTextColor(), // ☑️ 변경
                  //           width: 3,
                  //         )
                  //         : Border.all(
                  //           color: ThemeManager.getEventPopupBorderColor(), // ☑️ 변경
                  //           width: 1,
                  //         ),
                  // boxShadow:
                  //     isSelected
                  //         ? [
                  //           BoxShadow(
                  //             // color: Colors.black.withOpacity(0.3), 
                  //             color: ThemeManager.getColorPickerTextColor(), // ☑️ 변경
                  //             blurRadius: 6,
                  //             offset: const Offset(0, 2),
                  //           ),
                  //         ]
                  //         : null,
                  border: isSelected
                      ? Border.all(
                          color: ThemeManager.getColorPickerTextColor(),
                          width: 4, // ☑️ 3 → 4로 증가 (더 명확한 선택 표시)
                        )
                      : Border.all(
                          color: ThemeManager.getEventPopupBorderColor(),
                          width: 1,
                        ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: ThemeManager.getColorPickerTextColor().withOpacity(0.4), // ☑️ 투명도 추가
                            blurRadius: 8, // ☑️ 6 → 8로 증가 (더 명확한 그림자)
                            offset: const Offset(0, 3), // ☑️ (0,2) → (0,3)으로 증가
                            spreadRadius: 1, // ☑️ 그림자 확산 추가
                          ),
                        ]
                      : null,
                ),
                child: Center(
                  // ☑️ 체크 아이콘 완전 제거! 텍스트만 표시_HE_250620
                  // child: Column(
                  //   mainAxisAlignment: MainAxisAlignment.center,
                  //   children: [
                  //     if (isSelected)
                  //       Icon(Icons.check, color: Colors.white, size: 20),
                  //     Text(
                  //       colorData['text'],
                  //       style: getTextStyle(
                  //         fontSize: 12,
                  //         color: Colors.white,
                  //         text: colorData['text'],
                  //       ),
                  //     ),
                  //   ],
                  // ),
                  child: 
                    // ☑️ 체크 아이콘 완전 제거! 텍스트만 표시
                    Text(
                      colorData['text'],
                      style: getTextStyle(
                        fontSize: 11, // ☑️ 12 → 11로 감소 (더 안전한 크기)
                        color: Colors.white,
                        text: colorData['text'],
                      ),
                      textAlign: TextAlign.center, // ☑️ 중앙 정렬 명시
                      overflow: TextOverflow.ellipsis, // ☑️ 오버플로우 방지
                      maxLines: 1, // ☑️ 한 줄로 제한
                    ),
                ),
              ),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(
            '취소',
            style: getTextStyle(
              fontSize: 14,
              // color: Colors.grey[700],
               color: ThemeManager.getTextColor( // ☑️ 변경
                lightColor: Colors.grey[700]!,
                darkColor: Colors.grey[400]!,
              ), 
              text: '취소',
            ),
          ),
        ),
        ElevatedButton(
          style: ButtonStyle(
            backgroundColor: MaterialStateProperty.all(
              googleColors[selectedColorId]!['color'],
            ),
          ),
          onPressed: () {
            if (selectedColorId != null) {
              widget.onColorSelected(selectedColorId!);
              Navigator.of(context).pop();
            }
          },
          child: Text(
            '확인',
            style: getTextStyle(fontSize: 14, color: Colors.white, text: '확인'),
          ),
        ),
      ],
    );
  }

  /// 색상 ID로 색상 가져오기 (외부 사용)
  static Color getColorById(int colorId) {
    return googleColors[colorId]?['color'] ?? googleColors[1]!['color'];
  }

  /// 색상 ID로 색상 이름 가져오기 (외부 사용)
  static String getColorNameById(int colorId) {
    return googleColors[colorId]?['name'] ?? '라벤더';
  }

  /// 모든 색상 정보 가져오기 (외부 사용)
  static Map<int, Map<String, dynamic>> getAllColors() {
    return googleColors;
  }
}
