import 'package:flutter/material.dart';

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
    1: {'name': '라벤더', 'color': Color(0xFF9AA0F5)},
    2: {'name': '세이지', 'color': Color(0xFF33B679)},
    3: {'name': '포도', 'color': Color(0xFF8E24AA)},
    4: {'name': '플라밍고', 'color': Color(0xFFE67C73)},
    5: {'name': '바나나', 'color': Color(0xFFF6BF26)},
    6: {'name': '귤', 'color': Color(0xFFFF8A65)},
    7: {'name': '공작새', 'color': Color(0xFF039BE5)},
    8: {'name': '그래파이트', 'color': Color(0xFF616161)},
    9: {'name': '블루베리', 'color': Color(0xFF3F51B5)},
    10: {'name': '바질', 'color': Color(0xFF0B8043)},
    11: {'name': '토마토', 'color': Color(0xFFD50000)},
  };

  @override
  void initState() {
    super.initState();
    selectedColorId = widget.initialColorId ?? 1;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text(
        '색상 선택',
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: GridView.builder(
          shrinkWrap: true,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
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
                  border:
                      isSelected
                          ? Border.all(color: Colors.black, width: 3)
                          : Border.all(color: Colors.grey.shade300, width: 1),
                  boxShadow:
                      isSelected
                          ? [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.3),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ]
                          : null,
                ),
                child:
                    isSelected
                        ? const Icon(Icons.check, color: Colors.white, size: 20)
                        : null,
              ),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('취소'),
        ),
        ElevatedButton(
          onPressed: () {
            if (selectedColorId != null) {
              widget.onColorSelected(selectedColorId!);
              Navigator.of(context).pop();
            }
          },
          child: const Text('확인'),
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
