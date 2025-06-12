import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/event.dart';
import '../utils/font_utils.dart';
import 'color_picker_dialog.dart';

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
      _endDate = (widget.initialDate ?? DateTime.now()).add(const Duration(days: 1));
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _selectStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
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

  Future<void> _selectEndDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _endDate ?? DateTime.now().add(const Duration(days: 1)),
      firstDate: _startDate ?? DateTime.now(),
      lastDate: DateTime(2030),
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
      builder: (context) => ColorPickerDialog(
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('제목을 입력해주세요.')),
      );
      return;
    }

    if (_startDate == null || _endDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('시작 날짜와 종료 날짜를 선택해주세요.')),
      );
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

    widget.onSave(event);
    widget.onClose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withAlpha(127),
      child: Center(
        child: Container(
          width: MediaQuery.of(context).size.width * 0.85,
          height: MediaQuery.of(context).size.height * 0.7,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: Colors.black, width: 2),
          ),
          child: Column(
            children: [
              // 헤더
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  color: Colors.black,
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
                      style: getTextStyle(
                        fontSize: 18,
                        color: Colors.white,
                      ),
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
                        style: getTextStyle(fontSize: 16, color: Colors.black),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _titleController,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          hintText: '일정 제목을 입력하세요',
                        ),
                        style: getTextStyle(fontSize: 14, color: Colors.black),
                      ),
                      
                      const SizedBox(height: 20),
                      
                      // 날짜 선택
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '시작 날짜',
                                  style: getTextStyle(fontSize: 16, color: Colors.black),
                                ),
                                const SizedBox(height: 8),
                                GestureDetector(
                                  onTap: _selectStartDate,
                                  child: Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      border: Border.all(color: Colors.grey),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      _startDate != null
                                          ? DateFormat('yyyy-MM-dd').format(_startDate!)
                                          : '날짜 선택',
                                      style: getTextStyle(fontSize: 14, color: Colors.black),
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
                                  style: getTextStyle(fontSize: 16, color: Colors.black),
                                ),
                                const SizedBox(height: 8),
                                GestureDetector(
                                  onTap: _selectEndDate,
                                  child: Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      border: Border.all(color: Colors.grey),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      _endDate != null
                                          ? DateFormat('yyyy-MM-dd').format(_endDate!)
                                          : '날짜 선택',
                                      style: getTextStyle(fontSize: 14, color: Colors.black),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 20),
                      
                      // 색상 선택
                      Row(
                        children: [
                          Text(
                            '색상',
                            style: getTextStyle(fontSize: 16, color: Colors.black),
                          ),
                          const SizedBox(width: 12),
                          GestureDetector(
                            onTap: _selectColor,
                            child: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: _selectedColor,
                                border: Border.all(color: Colors.black, width: 1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 40),
                      
                      // 버튼들
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              onPressed: widget.onClose,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.grey,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                              child: Text(
                                '취소',
                                style: getTextStyle(fontSize: 16, color: Colors.white),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: _saveEvent,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                              child: Text(
                                '저장',
                                style: getTextStyle(fontSize: 16, color: Colors.white),
                              ),
                            ),
                          ),
                        ],
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