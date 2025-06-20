import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/event.dart';
import '../utils/font_utils.dart';
import 'color_picker_dialog.dart';
import '../utils/theme_manager.dart'; // ☑️ 다크모드 적용

class MultiDayEventPopup extends StatefulWidget {
  final Event? editingEvent; // 수정 중인 이벤트 (null이면 새로 생성)
  final Function(Event) onSave;
  final Function() onClose;
  final DateTime? initialDate; // 초기 시작 날짜

  const MultiDayEventPopup({
    super.key,
    this.editingEvent,
    required this.onSave,
    required this.onClose,
    this.initialDate,
  });

  @override
  State<MultiDayEventPopup> createState() => _MultiDayEventPopupState();
}

class _MultiDayEventPopupState extends State<MultiDayEventPopup> {
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  DateTime? _startDate;
  DateTime? _endDate;
  Color _selectedColor = Colors.blue;
  int _selectedColorId = 1;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController();
    _descriptionController = TextEditingController();

    if (widget.editingEvent != null) {
      // 수정 모드
      final event = widget.editingEvent!;
      _titleController.text = event.title;
      _descriptionController.text = event.description;
      _startDate = event.startDate ?? event.date;
      _endDate = event.endDate ?? event.date;
      _selectedColor = event.getDisplayColor();
      _selectedColorId = event.getColorId() ?? 1;
    } else {
      // 새로 생성 모드
      _startDate = widget.initialDate ?? DateTime.now();
      _endDate = (widget.initialDate ?? DateTime.now()).add(
        const Duration(days: 1),
      );
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }
// ☑️ 날짜 선택 팝업_테마 적용_250619
  Future<void> _selectStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030), 

      // ☑️ 테마 적용 추가_250619
      builder: (context, child) {
        return Theme(
          data: ThemeManager.isDarkMode 
              ? ThemeData.dark().copyWith(
                  colorScheme: const ColorScheme.dark(
                    primary: Colors.blue,
                    surface: Color(0xFF2D2D2D),
                  ),
                  dialogBackgroundColor: const Color(0xFF2D2D2D),
                )
              : ThemeData.light().copyWith(
                  colorScheme: const ColorScheme.light(
                    primary: Colors.blue,
                  ),
                ),
          child: child!,
        );
      }, // ☑️ 테마 적용 추가(여기까지)
    );
    if (picked != null) {
      setState(() {
        _startDate = picked;
        // 시작 날짜가 종료 날짜보다 늦으면 종료 날짜를 시작 날짜 + 1일로 설정
        if (_endDate != null && picked.isAfter(_endDate!)) {
          _endDate = picked.add(const Duration(days: 1));
        }
      });
    }
  }
  
// ☑️ 종료 날짜 선택 팝업_테마 적용_250619
  Future<void> _selectEndDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _endDate ?? DateTime.now().add(const Duration(days: 1)),
      firstDate: _startDate ?? DateTime.now(),
      lastDate: DateTime(2030),

      // ☑️ 테마 적용 추가_250619
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: ThemeManager.getDatePickerSelectedColor(),
              onPrimary: Colors.white,
              surface: ThemeManager.getDatePickerSurfaceColor(),
              onSurface: ThemeManager.getDatePickerTextColor(),
              background: ThemeManager.getDatePickerBackgroundColor(),
              onBackground: ThemeManager.getDatePickerTextColor(),
            ).copyWith(
              brightness: ThemeManager.isDarkMode ? Brightness.dark : Brightness.light,
            ),
            dialogBackgroundColor: ThemeManager.getDatePickerBackgroundColor(),
          ),
          child: child!,
        ); 
      }, // ☑️ 테마 적용 추가(여기까지)
    );
    if (picked != null) {
      setState(() {
        _endDate = picked;
      });
    }
  }

  Future<void> _selectColor() async {
    await showDialog(
      context: context,
      builder:
          (context) => ColorPickerDialog(
            initialColorId: _selectedColorId,
            onColorSelected: (colorId) {
              setState(() {
                _selectedColorId = colorId;
                _selectedColor = _getColorByColorId(colorId);
              });
            },
          ),
    );
  }

  // Google Calendar 표준 색상 매핑
  Color _getColorByColorId(int colorId) {
    const Map<int, Color> googleColors = {
      1: Color(0xFF9AA0F5), // 라벤더
      2: Color(0xFF33B679), // 세이지
      3: Color(0xFF8E24AA), // 포도
      4: Color(0xFFE67C73), // 플라밍고
      5: Color(0xFFF6BF26), // 바나나
      6: Color(0xFFFF8A65), // 귤
      7: Color(0xFF039BE5), // 공작새
      8: Color(0xFF616161), // 그래파이트
      9: Color(0xFF3F51B5), // 블루베리
      10: Color(0xFF0B8043), // 바질
      11: Color(0xFFD50000), // 토마토
    };
    return googleColors[colorId] ?? googleColors[1]!;
  }

  void _saveEvent() {
    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('제목을 입력해주세요.')));
      return;
    }

    if (_startDate == null || _endDate == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('시작 날짜와 종료 날짜를 선택해주세요.')));
      return;
    }

    final event = Event.multiDay(
      title: _titleController.text.trim(),
      startDate: _startDate!,
      endDate: _endDate!,
      description: _descriptionController.text.trim(),
      colorId: _selectedColorId.toString(),
      color: _selectedColor,
      uniqueId: widget.editingEvent?.uniqueId, // 수정 시 기존 ID 유지
    );

    print('🎯 MultiDayEventPopup: 멀티데이 이벤트 생성됨');
    print('   제목: ${event.title}');
    print('   시작날짜: ${event.startDate}');
    print('   종료날짜: ${event.endDate}');
    print('   isMultiDay: ${event.isMultiDay}');
    print('   uniqueId: ${event.uniqueId}');
    print('   색상: ${event.color}');

    widget.onSave(event);
    widget.onClose();
  }

  @override
  Widget build(BuildContext context) {
    //☑️ 테마 적용_멀티데이 이벤트 팝업_250619
    return Container(
      color: Colors.black.withAlpha(127),
      child: Center(
        child: Container(
          width: MediaQuery.of(context).size.width * 0.85,
          height: MediaQuery.of(context).size.height * 0.7,
          decoration: BoxDecoration(
            // color: Colors.white,
            color: ThemeManager.getEventPopupBackgroundColor(), // ☑️ 변경
            borderRadius: BorderRadius.circular(15),
            // border: Border.all(color: Colors.black, width: 2),
            border: Border.all( 
              color: ThemeManager.getEventPopupBorderColor(), // ☑️ 변경
              width: 2,
            ),
          ),
          child: Column(
            children: [
              // 헤더
              Container(
                padding: const EdgeInsets.all(16),
                // decoration: const BoxDecoration(
                //   color: Colors.black,
                decoration: BoxDecoration( // ☑️ const 제거
                    color: ThemeManager.getEventPopupHeaderColor(), // ☑️ 변경
                    
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(13),
                    topRight: Radius.circular(13),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      widget.editingEvent != null ? '며칠 일정 수정' : '며칠 일정 추가',
                      style: getTextStyle(fontSize: 18, color: Colors.white),
                    ),
                    GestureDetector(
                      onTap: widget.onClose,
                      child: Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: Colors.red,
                          border: Border.all(color: Colors.white, width: 1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          'X',
                          style: getTextStyle(
                            fontSize: 12,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // 내용
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 제목 입력
                      Text(
                        '제목',
                        // style: getTextStyle(fontSize: 16, color: Colors.black),
                        style: getTextStyle(
                          fontSize: 16,
                          color: ThemeManager.getEventPopupTextColor(), // ☑️ 변경
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _titleController,
                        // decoration: const InputDecoration(
                        //   border: OutlineInputBorder(),
                        decoration: InputDecoration(
                          border: OutlineInputBorder(
                            borderSide: BorderSide(
                              color: ThemeManager.getEventPopupBorderColor(), // ☑️ 변경
                            ),
                          ),
                          hintText: '일정 제목을 입력하세요',
                        // ),
                        // style: getTextStyle(fontSize: 14, color: Colors.black),
                          hintStyle: TextStyle( // ☑️ 변경
                            color: ThemeManager.getTextColor(
                              lightColor: Colors.grey[600]!,
                              darkColor: Colors.grey[400]!,
                            ),
                          ),
                          fillColor: ThemeManager.getCardColor(),
                          filled: true,
                        ),
                        style: getTextStyle(
                          fontSize: 14,
                          color: ThemeManager.getEventPopupTextColor(),
                        ), // ☑️ 변경(여기까지)
                      ),

                      Spacer(),

                      // 색상 선택
                      Material(
                        // color: Colors.grey[100],
                        color: ThemeManager.getCardColor(),  // ☑️ 변경
                        
                        borderRadius: BorderRadius.circular(12),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: _selectColor,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: 12.0,
                              horizontal: 16.0,
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.color_lens,
                                  color: ThemeManager.getEventPopupTextColor(), // ☑️ 추가
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  '색상 선택',
                                  style: getTextStyle(
                                    fontSize: 12,
                                    // color: Colors.black,
                                    color: ThemeManager.getEventPopupTextColor(), // ☑️ 변경
                                  ),
                                ),
                                const Spacer(),
                                Container(
                                  width: 24,
                                  height: 24,
                                  decoration: BoxDecoration(
                                    color: _selectedColor,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      // color: Colors.grey,
                                      color: ThemeManager.getEventPopupBorderColor(), // ☑️ 변경
                                      width: 1,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Icon(
                                  Icons.arrow_forward_ios,
                                  size: 16,
                                  // color: Colors.black,
                                  color: ThemeManager.getEventPopupTextColor(), // ☑️ 변경
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      // 날짜 선택
                      Spacer(),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '시작 날짜',
                                  style: getTextStyle(
                                    fontSize: 16,
                                    // color: Colors.black,
                                    color: ThemeManager.getEventPopupTextColor(), // ☑️ 변경
                                  ),
                                ),
                                const SizedBox(height: 8),
                                GestureDetector(
                                  onTap: _selectStartDate,
                                  child: Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      // border: Border.all(color: Colors.grey),
                                      border: Border.all(
                                        color: ThemeManager.getEventPopupBorderColor(), // ☑️ 변경
                                      ),
                                      
                                      borderRadius: BorderRadius.circular(4),
                                      color: ThemeManager.getCardColor(), // ☑️ 추가
                                    ),
                                    child: Text(
                                      _startDate != null
                                          ? DateFormat('yyyy-MM-dd').format(_startDate!)
                                          : '날짜 선택',
                                      style: getTextStyle(
                                        fontSize: 14,
                                        // color: Colors.black,
                                        color: ThemeManager.getEventPopupTextColor(), // ☑️ 변경
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(width: 16),

                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '종료 날짜',
                                  style: getTextStyle(
                                    fontSize: 16,
                                    // color: Colors.black,
                                    color: ThemeManager.getEventPopupTextColor(), // ☑️ 변경
                                  ),
                                ),
                                const SizedBox(height: 8),
                                GestureDetector(
                                  onTap: _selectEndDate,
                                  child: Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      // border: Border.all(color: Colors.grey),
                                      border: Border.all(
                                        color: ThemeManager.getEventPopupBorderColor(), // ☑️ 변경
                                      ),
                                      
                                      borderRadius: BorderRadius.circular(4),
                                      color: ThemeManager.getCardColor(), // ☑️ 추가
                                    ),
                                    child: Text(
                                      _endDate != null
                                          ? DateFormat('yyyy-MM-dd').format(_endDate!)
                                          : '날짜 선택',
                                      style: getTextStyle(
                                        fontSize: 14,
                                        // color: Colors.black,
                                        color: ThemeManager.getEventPopupTextColor(), // ☑️ 변경
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      //
                      Spacer(),
                      Spacer(),

                      // 버튼들
                      Align(
                        alignment: Alignment.bottomRight,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // ☑️ 취소 버튼_테마 적용_250619
                            ElevatedButton(
                              onPressed: widget.onClose,
                              style: ElevatedButton.styleFrom(
                                // backgroundColor: const Color.fromARGB(
                                //   255,
                                //   255,
                                //   255,
                                //   255,
                                // ),
                                backgroundColor: ThemeManager.getCardColor(), // ☑️ 변경
                                foregroundColor: ThemeManager.getEventPopupTextColor(), // ☑️ 추가
                                
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                minimumSize: const Size(0, 0),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  side: BorderSide( // ☑️ 추가
                                    color: ThemeManager.getEventPopupBorderColor(), // ☑️ 추가
                                  ),
                                ),
                              ),
                              child: Text(
                                '취소',
                                style: getTextStyle(
                                  fontSize: 12,
                                  // color: const Color.fromARGB(255, 0, 0, 0), 
                                  color: ThemeManager.getEventPopupTextColor(), // ☑️ 변경
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton(
                              onPressed: _saveEvent,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _getColorByColorId(
                                  _selectedColorId,
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                minimumSize: const Size(0, 0),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: Text(
                                '저장',
                                style: getTextStyle(
                                  fontSize: 12,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
