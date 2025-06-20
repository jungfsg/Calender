import '../models/event.dart';
import '../controllers/calendar_controller.dart';
import '../managers/event_manager.dart';
import '../widgets/color_picker_dialog.dart';
import '../enums/recurrence_type.dart';
import 'package:flutter/material.dart';
import '../utils/font_utils.dart';
import '../utils/theme_manager.dart'; // ☑️ 다크모드 적용
// Todo: 동일 디자인의 팝업창의 중복된 코드 제거 및 통일 -> 하나의 팝업창 수정으로 해당하는 팝업에 동일 적용_HE_250620

/// 팝업 관련 로직을 처리하는 매니저 클래스
class PopupManager {
  final CalendarController _controller;
  final EventManager _eventManager;

  PopupManager(this._controller, this._eventManager);

  /// 이벤트 다이얼로그 표시
  void showEventDialog() {
    _controller.hideAllPopups();
    _controller.showEventDialog();
  }

  /// 이벤트 다이얼로그 숨기기
  void hideEventDialog() {
    _controller.hideEventDialog();
  }

  /// 날씨 예보 다이얼로그 표시
  void showWeatherForecastDialog() {
    _controller.hideAllPopups();
    _controller.showWeatherDialog();
  }

  /// 날씨 예보 다이얼로그 숨기기
  void hideWeatherForecastDialog() {
    _controller.hideWeatherDialog();
  }

  /// 이벤트 추가 다이얼로그 표시
  Future<void> showAddEventDialog(BuildContext context) async {
    final TextEditingController titleController = TextEditingController();
    TimeOfDay? selectedStartTime; // null로 시작하여 사용자가 반드시 설정하도록 함
    TimeOfDay? selectedEndTime; // null로 시작하여 사용자가 반드시 설정하도록 함
    int selectedColorId = 1; // 기본 색상: 라벤더
    RecurrenceType selectedRecurrence = RecurrenceType.none; // 기본 반복: 없음
    int recurrenceCount = 1; // 기본 반복 횟수

    return showDialog<void>(
      context: context,
      builder:
          (context) => StatefulBuilder(
            builder:
                (context, setState) => Dialog(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16.0),
                  ),
                  elevation: 0,
                  backgroundColor: ThemeManager.getEventPopupBackgroundColor(), // ☑️ 추가
                  child: Container(
                    padding: const EdgeInsets.all(16), // ☑️ _HE_250619_20 → 16으로 감소
                    decoration: BoxDecoration(
                      // color: Colors.white,
                      color: ThemeManager.getEventPopupBackgroundColor(), // ☑️ 변경
                      
                      borderRadius: BorderRadius.circular(16.0),
                      border: Border.all( // ☑️ border 추가
                        color: ThemeManager.getEventPopupBorderColor(),
                        width: 1,
                      ),
                    ),
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.of(context).size.height * 0.85, // ☑️ _HE_250619_0.8 → 0.85로 증가
                      maxWidth: MediaQuery.of(context).size.width * 0.92, // ☑️ _HE_250619_0.9 → 0.92로 증가
                      minWidth: 320, // ☑️ _HE_250619_최소 너비 설정정
                    ),
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '새 일정 추가',
                                style: getTextStyle(
                                  fontSize: 20,
                                  color: ThemeManager.getTextColor(), // ☑️ 팝업창 테마 통일_250619_추가
                                ),
                              ),
                              IconButton(
                                icon: Icon(
                                  Icons.close,
                                  color: ThemeManager.getEventPopupCloseButtonColor(),
                                ),
                                onPressed: () => Navigator.pop(context),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          // 
                          TextField(
                            controller: titleController,
                            decoration: InputDecoration(
                              hintText: '일정 제목',
                              hintStyle: TextStyle( // ☑️ 팝업창 테마 통일_250619_추가가
                                color: ThemeManager.getPopupSecondaryTextColor(),
                              ), 
                              filled: true,
                              fillColor: ThemeManager.getPopupSecondaryBackgroundColor(), // ☑️ 팝업창 테마 통일_250619_변경
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                              prefixIcon: Icon( // ☑️ 팝업창 테마 통일_250619_추가
                                Icons.event_note,
                                color: ThemeManager.getPopupSecondaryTextColor(), // ☑️ 팝업창 테마 통일_250619_추가
                              ),
                            ),
                            style: getTextStyle( // ☑️ 팝업창 테마 통일_250619_추가
                              fontSize: 14,
                              color: ThemeManager.getTextColor(),
                            ),
                            autofocus: true,
                            // 엔터키 입력 시 다음 단계로 이동
                            textInputAction: TextInputAction.next,
                          ),
                          const SizedBox(height: 16), // ☑️ 간격 추가 - 일정 제목과 색상 선택 사이
                          Material(
                            color: ThemeManager.getPopupSecondaryBackgroundColor(),
                            borderRadius: BorderRadius.circular(12),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: () {
                                showDialog(
                                  context: context,
                                  builder: (context) => ColorPickerDialog(
                                    initialColorId: selectedColorId,
                                    onColorSelected: (colorId) {
                                      setState(() {
                                        selectedColorId = colorId;
                                      });
                                    },
                                  ),
                                );
                              },
                              
                              child: Container( // ☑️ _HE_250619_Padding → Container로 변경
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12.0,
                                  horizontal: 14.0, // ☑️ _HE_250619_16.0 → 14.0으로 감소
                                ),
                                child: Row(
                                  children: [
                                    Icon( 
                                      Icons.color_lens,
                                      color: ThemeManager.getPopupSecondaryTextColor(), // ☑️ 팝업창 테마 통일_250619_추가
                                      size: 20, // ☑️ 크기 명시
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        '색상 선택',
                                        style: getTextStyle(
                                          fontSize: 12,
                                          color: ThemeManager.getTextColor(), // ☑️ 팝업창 테마 통일_250619_추가
                                        ),
                                      ),
                                    ),
                                    Container(
                                      width: 22, // ☑️ _HE_250619_24 → 22로 감소
                                      height: 22, // ☑️ _HE_250619_24 → 22로 감소
                                      decoration: BoxDecoration(
                                        color: _getColorByColorId(selectedColorId),
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          // color: Colors.grey,
                                          color: ThemeManager.getPopupBorderColor(), // ☑️ 팝업창 테마 통일_250619_변경
                                          width: 1,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 6), // ☑️ _HE_250619_8에서 6으로 감소 
                                    Icon(
                                      Icons.arrow_forward_ios,
                                      size: 14, // ☑️ _HE_250619_16 → 14로 감소
                                      color: ThemeManager.getPopupSecondaryTextColor(), // ☑️ 팝업창 테마 통일_250619_추가
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 14), // ☑️ 간격 줄임 - 20 → 14
                          Container(
                            // padding: const EdgeInsets.all(12),
                            padding: const EdgeInsets.all(8), // ☑️ 패딩 줄임 - 12 → 8
                            decoration: BoxDecoration(
                              // color: Colors.blue[50],
                              color: ThemeManager.getInfoBoxBackgroundColor(), // ☑️ 다크모드 적용
                              borderRadius: BorderRadius.circular(8),
                              // border: Border.all(color: Colors.blue[200]!),
                              border: Border.all(color: ThemeManager.getInfoBoxBorderColor()), // ☑️ 다크모드 적용
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.info_outline,
                                  // color: Colors.blue[600],
                                  color: ThemeManager.getInfoBoxIconColor(), // ☑️ 다크모드 적용
                                  size: 20, 
                                ),
                                const SizedBox(width: 6), // ☑️ 간격 줄임 - 8 → 6
                                Expanded(
                                  child: Text(
                                    '시간을 선택하지 않으면 종일 일정으로 추가됩니다.',
                                    style: getTextStyle(
                                      // fontSize: 12,
                                      fontSize: 10, // ☑️ 폰트 크기 줄임 - 12 → 10
                                      // color: Colors.blue[700],
                                      color: ThemeManager.getInfoBoxTextColor(), // ☑️ 다크모드 적용
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14), // ☑️ 간격 줄임 - 16 → 14              
                          Row(
                            children: [
                              Expanded(
                                child: Material(
                                  // color: Colors.grey[100],
                                  color: ThemeManager.getPopupSecondaryBackgroundColor(), // ☑️ 팝업창 테마 통일_250619_변경
                                  borderRadius: BorderRadius.circular(12),
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(12),
                                    onTap: () async {
                                      final TimeOfDay?
                                      picked = await showTimePicker(
                                        context: context,
                                        initialTime:
                                            selectedStartTime ??
                                            TimeOfDay.now(),
                                        builder: (context, child) {
                                          return Theme(
                                            data: Theme.of(context).copyWith(
                                              timePickerTheme: TimePickerThemeData(
                                                // backgroundColor: Colors.white,
                                                // hourMinuteTextColor:
                                                //     Colors.black,
                                                // dayPeriodTextColor:
                                                //     Colors.black,
                                                // dayPeriodColor:
                                                //     Colors.grey[200],
                                                // dayPeriodShape:
                                                //     RoundedRectangleBorder(
                                                //       borderRadius:
                                                //           BorderRadius.circular(
                                                //             8,
                                                //           ),
                                                //     ),
                                                // ☑️ 팝업창 테마 통일_250619_변경
                                                backgroundColor: ThemeManager.getPopupBackgroundColor(),
                                                hourMinuteTextColor: ThemeManager.getTextColor(),
                                                dayPeriodTextColor: ThemeManager.getTextColor(),
                                                dayPeriodColor: ThemeManager.getPopupSecondaryBackgroundColor(),
                                              ),
                                            ),
                                            child: child!,
                                          );
                                        },
                                      );
                                      if (picked != null) {
                                        setState(() {
                                          selectedStartTime = picked;
                                          // 시작 시간이 변경되면 종료 시간을 1시간 후로 자동 설정
                                          selectedEndTime = TimeOfDay(
                                            hour: (picked.hour + 1) % 24,
                                            minute: picked.minute,
                                          );
                                        });
                                      }
                                    },
                                    // child: Padding(
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 12.0,
                                        horizontal: 12.0, // ☑️ _HE_250619_16.0 → 12.0으로 감소
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            '시작',
                                            style: getTextStyle(
                                              // color: Colors.grey,
                                              color: ThemeManager.getPopupSecondaryTextColor(), // ☑️ 팝업창 테마 통일_250619_변경
                                              fontSize: 10,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Row(
                                            children: [
                                              Icon( // ☑️ 팝업창 테마 통일_250619_const 제거
                                                Icons.access_time,
                                                size: 16, // ☑️ _HE_250619_18 → 16으로 감소
                                                color: ThemeManager.getPopupSecondaryTextColor(), // ☑️ 팝업창 테마 통일_250619_추가  
                                              ),
                                              const SizedBox(width: 6), // ☑️ _HE_250619_8에서 6으로 감소
                                              // Text(
                                              //   '${selectedStartTime.hour.toString().padLeft(2, '0')}:${selectedStartTime.minute.toString().padLeft(2, '0')}',
                                              //   style: getTextStyle(
                                              //     fontSize: 16,
                                              //     // color: Colors.black87,
                                              //     color: ThemeManager.getTextColor(), // ☑️ 팝업창 테마 통일_250619_변경
                                              Flexible( // ☑️ Text를 Flexible로 감싸기
                                                child: Text(
                                                  selectedStartTime != null
                                                      ? '${selectedStartTime!.hour.toString().padLeft(2, '0')}:${selectedStartTime!.minute.toString().padLeft(2, '0')}'
                                                      : '--:--',
                                                  style: getTextStyle(
                                                    fontSize: 16,
                                                    color: ThemeManager.getTextColor(),
                                                  ),
                                                  overflow: TextOverflow.ellipsis, // ☑️ 오버플로우 처리
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12), // ☑️ _HE_250619_16에서 12로 감소
                              Expanded(
                                child: Material(
                                  // color: Colors.grey[100],
                                  color: ThemeManager.getPopupSecondaryBackgroundColor(), // ☑️ 팝업창 테마 통일_250619_변경
                                  borderRadius: BorderRadius.circular(12),
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(12),
                                    onTap: () async {
                                      final TimeOfDay?
                                      picked = await showTimePicker(
                                        context: context,
                                        initialTime:
                                            selectedEndTime ?? TimeOfDay.now(),
                                        builder: (context, child) {
                                          return Theme(
                                            data: Theme.of(context).copyWith(
                                              timePickerTheme: TimePickerThemeData(
                                                // backgroundColor: Colors.white,
                                                // hourMinuteTextColor:
                                                //     Colors.black,
                                                // dayPeriodTextColor:
                                                //     Colors.black,
                                                // dayPeriodColor:
                                                //     Colors.grey[200],
                                                // dayPeriodShape:
                                                //     RoundedRectangleBorder(
                                                //       borderRadius:
                                                //           BorderRadius.circular(
                                                //             8,
                                                //           ),
                                                //     ),
                                                // ☑️ 팝업창 테마 통일_250619_변경
                                                backgroundColor: ThemeManager.getPopupBackgroundColor(),
                                                hourMinuteTextColor: ThemeManager.getTextColor(),
                                                dayPeriodTextColor: ThemeManager.getTextColor(),
                                                dayPeriodColor: ThemeManager.getPopupSecondaryBackgroundColor(),
                                              ),
                                            ),
                                            child: child!,
                                          );
                                        },
                                      );
                                      if (picked != null) {
                                        setState(() {
                                          selectedEndTime = picked;
                                        });
                                      }
                                    },
                                    // child: Padding(
                                    child: Container( // ☑️ _HE_250619_Padding → Container로 변경
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 12.0,
                                        horizontal: 12.0, // ☑️ _HE_250619_16.0 → 12.0으로 감소
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            '종료',
                                            style: getTextStyle(
                                              // color: Colors.grey,
                                              color: ThemeManager.getPopupSecondaryTextColor(), // ☑️ 팝업창 테마 통일_250619_변경
                                              fontSize: 10,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Row(
                                            children: [
                                              Icon( // ☑️ 팝업창 테마 통일_250619_const 제거
                                                Icons.access_time,
                                                size: 16, // ☑️ _HE_250619_18 → 16으로 감소
                                                color: ThemeManager.getPopupSecondaryTextColor(), // ☑️ 팝업창 테마 통일_250619_추가
                                              ),
                                              const SizedBox(width: 6), // ☑️ _HE_250619_8에서 6으로 감소
                                              // Text(
                                              //   '${selectedEndTime.hour.toString().padLeft(2, '0')}:${selectedEndTime.minute.toString().padLeft(2, '0')}',
                                              //   style: getTextStyle(
                                              //     fontSize: 16,
                                              //     // color: Colors.black87,
                                              //     color: ThemeManager.getTextColor(), // ☑️ 팝업창 테마 통일_250619_변경
                                              Flexible( // ☑️ Text를 Flexible로 감싸기
                                                child: Text(
                                                  selectedEndTime != null
                                                      ? '${selectedEndTime!.hour.toString().padLeft(2, '0')}:${selectedEndTime!.minute.toString().padLeft(2, '0')}'
                                                      : '--:--',
                                                  style: getTextStyle(
                                                    fontSize: 16,
                                                    color: ThemeManager.getTextColor(),
                                                  ),
                                                  overflow: TextOverflow.ellipsis, // ☑️ 오버플로우 처리
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          // 반복 옵션 섹션: 새 일정 추가
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Text('반복 설정', style: getTextStyle(fontSize: 16)),
                              Text('반복 설정', style: getTextStyle(fontSize: 16, color: ThemeManager.getTextColor())), // ☑️ 팝업창 테마 통일_250619_추가
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 8.0,
                                runSpacing: 8.0,
                                children:
                                    RecurrenceType.values.map((recurrence) {
                                      final isSelected =
                                          selectedRecurrence == recurrence;
                                      return FilterChip(
                                        label: Text(
                                          recurrence.label,
                                          style: getTextStyle(
                                            fontSize:
                                                12, // 매일, 매주 등 설정 버튼의 텍스트 크기
                                            // color: Colors.black87,
                                            color: isSelected // ☑️ 팝업창 테마 통일_250619_변경
                                              ? Colors.white 
                                              : ThemeManager.getTextColor(), 
                                          ),
                                        ),
                                        selected: isSelected,
                                        onSelected: (bool selected) {
                                          setState(() {
                                            selectedRecurrence =
                                                selected
                                                    ? recurrence
                                                    : RecurrenceType.none;
                                            // 반복 타입이 변경되면 해당 타입의 기본 반복 횟수로 설정
                                            if (selected &&
                                                recurrence !=
                                                    RecurrenceType.none) {
                                              recurrenceCount =
                                                  recurrence.defaultCount;
                                            } else if (!selected) {
                                              recurrenceCount = 1;
                                            }
                                          });
                                        },
                                        // backgroundColor: Colors.grey[100],
                                        backgroundColor: ThemeManager.getPopupSecondaryBackgroundColor(), // ☑️ 팝업창 테마 통일_250619_변경
                                        selectedColor: _getColorByColorId(
                                          selectedColorId,
                                        ),
                                        checkmarkColor: Colors.white,
                                        elevation: isSelected ? 2 : 0,
                                        shadowColor: _getColorByColorId(
                                          selectedColorId,
                                        ).withOpacity(0.3),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            20,
                                          ),
                                          side: BorderSide(
                                            color:
                                                isSelected
                                                    ? _getColorByColorId(
                                                      selectedColorId,
                                                    )
                                                    // : Colors.grey[300]!,
                                                    : ThemeManager.getPopupBorderColor(), // ☑️ 팝업창 테마 통일_250619_변경
                                            width: 1,
                                          ),
                                        ),
                                      );
                                    }).toList(),
                              ),
                              // 반복 횟수 선택 (반복이 선택된 경우에만 표시)
                              if (selectedRecurrence !=
                                  RecurrenceType.none) ...[
                                const SizedBox(height: 12),
                                Row( 
                                  children: [
                                   
                                    // ☑️ 1. '반복 횟수' 텍스트 - 왼쪽 정렬
                                    Text(
                                        '반복 횟수',
                                        style: getTextStyle(
                                          fontSize: 14,
                                          color: ThemeManager.getTextColor(), // ☑️ 팝업창 테마 통일_250619_추가
                                        ),
                                      ),
                                   
                                    // ☑️ 2. 유연한 공간 확보
                                    const Spacer(), // ☑️ _HE_250620_Spacer 추가

                                    // ☑️ 3. 카운터 컨테이너 - 오른쪽 배치
                                    Container(
                                      width: 90, // ☑️ 140에서 90으로 감소
                                      height: 34, // ☑️ 40에서 34으로 감소
                                      decoration: BoxDecoration(
                                        color: ThemeManager.getPopupSecondaryBackgroundColor(),
                                        border: Border.all(
                                          color: ThemeManager.getPopupBorderColor(),
                                        ),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            flex: 1,
                                            child: InkWell(
                                              onTap: () {
                                                setState(() {
                                                  if (recurrenceCount > 1) {
                                                    recurrenceCount--;
                                                  }
                                                });
                                              },
                                              child: Container(
                                                height: double.infinity,
                                                alignment: Alignment.center, // ☑️ _HE_250620_alignment 추가
                                                child: Icon(
                                                  Icons.remove,
                                                  size: 14,
                                                  color: ThemeManager.getPopupSecondaryTextColor(),
                                                ),
                                              ),
                                            ),
                                          ),
                                          
                                          Expanded(
                                            flex: 2,
                                            child: Container(
                                              alignment: Alignment.center,
                                              child: Text(
                                                '$recurrenceCount',
                                                style: getTextStyle(
                                                  fontSize: 14,
                                                  color: ThemeManager.getTextColor(),
                                                ),
                                              ),
                                            ),
                                          ),
                                          Expanded(
                                            flex: 1,
                                            child: InkWell(
                                              onTap: () {
                                                setState(() {
                                                  if (recurrenceCount < 50) {
                                                    recurrenceCount++;
                                                  }
                                                });
                                              },
                                              child: Container(
                                                height: double.infinity,
                                                alignment: Alignment.center, // ☑️ _HE_250620_alignment 추가
                                                child: Icon(
                                                  Icons.add,
                                                  size: 14,
                                                  color: ThemeManager.getPopupSecondaryTextColor(),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),

                                    // ☑️ 4. 설명 텍스트 - 오른쪽 정렬
                                    const SizedBox(width: 8), // ☑️ _HE_250620_12에서 8로 감소
                                    // Flexible( // ☑️ 설명 텍스트를 Flexible로 감싸기
                                      // child: Text(
                                      // Text(
                                    Expanded( // ☑️ 일정 수정과 동일하게 Expanded 추가
                                      child: Text(
                                        _getRecurrenceDescription(selectedRecurrence),
                                        style: getTextStyle(
                                          fontSize: 12,
                                          color: ThemeManager.getPopupSecondaryTextColor(),
                                        ),
                                        overflow: TextOverflow.ellipsis, // ☑️ 오버플로우 처리
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                      
                            
      
                          const SizedBox(height: 24),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              OutlinedButton(
                                onPressed: () => Navigator.pop(context),
                                style: OutlinedButton.styleFrom(
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 12,
                                  ),
                                  foregroundColor: ThemeManager.getTextColor(), // ☑️ 팝업창 테마 통일_250619_추가
                                  side: BorderSide( // ☑️ 팝업창 테마 통일_250619_추가  
                                    color: ThemeManager.getPopupBorderColor(),
                                  ),
                                ),
                                child: Text(
                                  '취소',
                                  // style: getTextStyle(fontSize: 12),
                                  style: getTextStyle(
                                    color: ThemeManager.getTextColor(), // ☑️ 팝업창 테마 통일_250619_추가
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              ElevatedButton(
                                onPressed: () async {
                                  // 개선: 입력 검증 추가
                                  if (titleController.text.trim().isEmpty) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('일정 제목을 입력해주세요.'),
                                        backgroundColor: Colors.orange,
                                      ),
                                    );
                                    return;
                                  }

                                  // 시간이 선택되지 않은 경우 종일 일정으로 처리
                                  bool isAllDayEvent =
                                      selectedStartTime == null ||
                                      selectedEndTime == null;
                                  String startTimeStr;
                                  String? endTimeStr;

                                  if (isAllDayEvent) {
                                    // 종일 일정의 경우
                                    startTimeStr = '종일';
                                    endTimeStr = null;
                                  } else {
                                    // 시간이 선택된 경우 유효성 검사
                                    final startTotalMinutes =
                                        selectedStartTime!.hour * 60 +
                                        selectedStartTime!.minute;
                                    final endTotalMinutes =
                                        selectedEndTime!.hour * 60 +
                                        selectedEndTime!.minute;

                                    // 시작 시간과 종료 시간이 같은 경우에만 오류
                                    if (startTotalMinutes == endTotalMinutes) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            '종료 시간은 시작 시간보다 늦어야 합니다.',
                                          ),
                                          backgroundColor: Colors.orange,
                                        ),
                                      );
                                      return;
                                    }

                                    // 시간 변환
                                    startTimeStr =
                                        '${selectedStartTime!.hour.toString().padLeft(2, '0')}:${selectedStartTime!.minute.toString().padLeft(2, '0')}';
                                    endTimeStr =
                                        '${selectedEndTime!.hour.toString().padLeft(2, '0')}:${selectedEndTime!.minute.toString().padLeft(2, '0')}';
                                  } // 이벤트 생성
                                  final Event event;

                                  if (isAllDayEvent) {
                                    // 종일 일정 생성
                                    event = Event(
                                      title: titleController.text.trim(),
                                      // _HE_250620_병합전 기존 코드 
                                      // time:
                                      //   '${selectedStartTime.hour.toString().padLeft(2, '0')}:${selectedStartTime.minute.toString().padLeft(2, '0')}',
                                      // endTime:
                                      //   '${selectedEndTime.hour.toString().padLeft(2, '0')}:${selectedEndTime.minute.toString().padLeft(2, '0')}',
                                      time: startTimeStr, // _HE_250620_병합 후 코드
                                      endTime: endTimeStr,
                                      date: _controller.selectedDay,
                                      source: 'local',
                                      recurrence: selectedRecurrence,
                                      recurrenceCount: recurrenceCount,
                                      colorId: selectedColorId.toString(),
                                    );
                                  } else {
                                    // 시간 기반 일정의 경우 - 날짜 넘어가는지 확인
                                    final startTotalMinutes =
                                        selectedStartTime!.hour * 60 +
                                        selectedStartTime!.minute;
                                    final endTotalMinutes =
                                        selectedEndTime!.hour * 60 +
                                        selectedEndTime!.minute;

                                    if (startTotalMinutes > endTotalMinutes) {
                                      // 날짜가 넘어가는 경우 - 멀티데이 이벤트로 처리
                                      final today = _controller.selectedDay;
                                      final tomorrow = today.add(
                                        const Duration(days: 1),
                                      );

                                      event = Event(
                                        title: titleController.text.trim(),
                                        time: startTimeStr,
                                        endTime: endTimeStr,
                                        date: today,
                                        isMultiDay: true,
                                        startDate: today,
                                        endDate: tomorrow,
                                        source: 'local',
                                        recurrence: selectedRecurrence,
                                        recurrenceCount: recurrenceCount,
                                        colorId: selectedColorId.toString(),
                                      );
                                    } else {
                                      // 일반적인 경우 - 기존과 동일한 방식
                                      event = Event(
                                        title: titleController.text.trim(),
                                        time: startTimeStr,
                                        endTime: endTimeStr,
                                        date: _controller.selectedDay,
                                        source: 'local',
                                        recurrence: selectedRecurrence,
                                        recurrenceCount: recurrenceCount,
                                        colorId: selectedColorId.toString(),
                                      );
                                    }
                                  }

                                  try {
                                    // 반복 옵션이 있는 경우 반복 이벤트들을 생성
                                    if (selectedRecurrence !=
                                        RecurrenceType.none) {
                                      await _createRecurringEvents(
                                        event,
                                        selectedColorId,
                                        selectedRecurrence,
                                        recurrenceCount,
                                      );
                                      Navigator.pop(context);

                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            '${selectedRecurrence.label} 반복 일정이 추가되었습니다: ${titleController.text.trim()}',
                                          ),
                                          backgroundColor: Colors.green,
                                        ),
                                      );
                                    } else {
                                      // 단일 이벤트 추가
                                      await _eventManager.addEventWithColorId(
                                        event,
                                        selectedColorId,
                                        syncWithGoogle: true,
                                      );
                                      Navigator.pop(context);

                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              '새 일정이 추가되었습니다: ${titleController.text.trim()}',
                                            ),
                                            backgroundColor: Colors.green,
                                          ),
                                        );
                                      }
                                    } catch (e) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('일정 추가 실패: $e'),
                                          backgroundColor: Colors.red,
                                        ),
                                      );
                                    }
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: _getColorByColorId(
                                      selectedColorId,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 12,
                                    ),
                                  ),
                                  child: Text(
                                    '추가',
                                    style: getTextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                    ),
                                  ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
          ),
    );
  }
        
  


  /// 이벤트 수정 다이얼로그 표시
  Future<void> showEditEventDialog(BuildContext context, Event event) async {
    final TextEditingController titleController = TextEditingController(
      text: event.title,
    ); // 시작 시간 파싱 - 종일 일정 처리
    TimeOfDay? selectedStartTime;
    if (event.time != '종일' && event.time.contains(':')) {
      try {
        final timeParts = event.time.split(':');
        selectedStartTime = TimeOfDay(
          hour: int.parse(timeParts[0]),
          minute: int.parse(timeParts[1]),
        );
      } catch (e) {
        // 파싱 실패 시 null로 설정 (종일 일정으로 처리)
        selectedStartTime = null;
      }
    } // 종료 시간 파싱 - 종일 일정 처리
    TimeOfDay? selectedEndTime;
    if (event.time == '종일') {
      // 종일 일정인 경우 종료 시간을 null로 설정
      selectedEndTime = null;
    } else if (event.endTime != null &&
        event.endTime!.isNotEmpty &&
        event.endTime != '종일' &&
        event.endTime!.contains(':')) {
      try {
        final endTimeParts = event.endTime!.split(':');
        selectedEndTime = TimeOfDay(
          hour: int.parse(endTimeParts[0]),
          minute: int.parse(endTimeParts[1]),
        );
      } catch (e) {
        // 파싱 실패 시 null로 설정
        selectedEndTime = null;
      }
    } else if (selectedStartTime != null) {
      // 시간 기반 일정이고 종료 시간이 없으면 1시간 후로 설정
      selectedEndTime = TimeOfDay(
        hour: (selectedStartTime.hour + 1) % 24,
        minute: selectedStartTime.minute,
      );
    }
    int selectedColorId = event.getColorId() ?? 1; // 기본 색상: 라벤더
    RecurrenceType selectedRecurrence = event.recurrence; // 현재 반복 타입
    int recurrenceCount = event.recurrenceCount; // 현재 반복 횟수

    //☑️ 테마 적용_이벤트 팝업_250619
    return showDialog<void>(
      context: context,
      builder:
          (context) => StatefulBuilder(
            builder:
                (context, setState) => Dialog(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16.0),
                  ),
                  elevation: 0,
                  backgroundColor: ThemeManager.getEventPopupBackgroundColor(), // ☑️ 추가
                  child: Container(
                    padding: const EdgeInsets.all(16), // ☑️ _HE_250620_20 → 16으로 감소
                    decoration: BoxDecoration(
                      // color: Colors.white,
                      color: ThemeManager.getEventPopupBackgroundColor(), // ☑️ 추가
                      borderRadius: BorderRadius.circular(16.0),
                      border: Border.all( // ☑️ border 추가
                        color: ThemeManager.getEventPopupBorderColor(),
                        width: 1,
                      ),
                    ),
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.of(context).size.height * 0.85, // ☑️ _HE_250620_0.8 → 0.85로 증가
                      maxWidth: MediaQuery.of(context).size.width * 0.92, // ☑️ _HE_250620_0.9 → 0.92로 증가
                      minWidth: 320, // ☑️ _HE_250620_최소 너비 설정정
                    ),
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '일정 수정',
                                style: getTextStyle(
                                  fontSize: 20,
                                  // color: ThemeManager.getEventPopupTextColor())), // ☑️ 변경
                                  color: ThemeManager.getTextColor(), // ☑️ 팝업창 테마 통일_250619_변경
                                ),
                              ),
                              IconButton(
                                icon: Icon(
                                  Icons.close,
                                  color: ThemeManager.getEventPopupCloseButtonColor(), // ☑️ 변경
                                ),
                                onPressed: () => Navigator.pop(context),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // ☑️ TextField에 style 추가
                          TextField(
                            controller: titleController,
                            decoration: InputDecoration(
                              hintText: '일정 제목',
                              hintStyle: TextStyle( // ☑️ 팝업창 테마 통일_250619_추가
                                color: ThemeManager.getPopupSecondaryTextColor(),
                              ),
                              filled: true,
                              // fillColor: Colors.grey[100],
                              // fillColor: ThemeManager.getCardColor(), // ☑️ 변경
                              fillColor: ThemeManager.getPopupSecondaryBackgroundColor(), // ☑️ 팝업창 테마 통일_250619_추가
                              
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                              prefixIcon: Icon( 
                                Icons.event_note,
                                color: ThemeManager.getPopupSecondaryTextColor(), // ☑️ 팝업창 테마 통일_250619_추가
                              ),
                              // helperText: ' ',
                            ),
                            style: getTextStyle( // ☑️ 팝업창 테마 통일_250619_추가
                              fontSize: 14,
                              color: ThemeManager.getTextColor(),
                            ),

                            autofocus: true,
                            textInputAction: TextInputAction.next,
                          ),
                          const SizedBox(height: 16), // ☑️ 간격 추가 - 일정 제목과 색상 선택 사이
                          Material(
                            color: ThemeManager.getPopupSecondaryBackgroundColor(),
                            borderRadius: BorderRadius.circular(12),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: () {
                                showDialog(
                                  context: context,
                                  builder:
                                      (context) => ColorPickerDialog(
                                        initialColorId: selectedColorId,
                                        onColorSelected: (colorId) {
                                          setState(() {
                                            selectedColorId = colorId;
                                          });
                                        },
                                      ),
                                );
                              },
                              child: Container( // ☑️ _HE_250620_Padding → Container로 변경
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12.0,
                                  horizontal: 14.0, // ☑️ _HE_250620_16.0 → 14.0으로 감소
                                ),
                                child: Row(
                                  children: [
                                    Icon( 
                                      Icons.color_lens,
                                      color: ThemeManager.getPopupSecondaryTextColor(), // ☑️ 팝업창 테마 통일_250619_추가
                                      size: 20, // ☑️ _HE_250620_크기 명시
                                    ),
                                    const SizedBox(width: 10), // ☑️ _HE_250619_const SizedBox 추가, Expanded 추가
                                    Expanded(
                                      child: Text(
                                        '색상 선택',
                                        style: getTextStyle(
                                          fontSize: 12,
                                          color: ThemeManager.getTextColor(), // ☑️ 팝업창 테마 통일_250619_추가
                                        ),
                                      ),
                                    ),
                                    // const Spacer(),
                                    Container(
                                      width: 22,
                                      height: 22,
                                      decoration: BoxDecoration(
                                        color: _getColorByColorId(selectedColorId),
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: ThemeManager.getPopupBorderColor(),
                                          width: 1,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 6), // ☑️ _HE_250620_8에서 6으로 감소
                                    Icon( // ☑️ 팝업창 테마 통일_250619_const 제거
                                      Icons.arrow_forward_ios,
                                      size: 14, // ☑️ _HE_250620_16 → 14로 감소
                                      color: ThemeManager.getPopupSecondaryTextColor(), // ☑️ 팝업창 테마 통일_250619_추가
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16), // ☑️ 간격 줄임 - 20 → 16
                          // 종일 옵션 선택
                          Material(
                            // color: Colors.grey[100],
                            color: ThemeManager.getPopupSecondaryBackgroundColor(), // ☑️ 다크모드 적용
                            borderRadius: BorderRadius.circular(12),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: () {
                                setState(() {
                                  bool currentValue =
                                      selectedStartTime == null &&
                                      selectedEndTime == null;
                                  if (!currentValue) {
                                    // 종일 일정으로 설정
                                    selectedStartTime = null;
                                    selectedEndTime = null;
                                  } else {
                                    // 시간 기반 일정으로 설정 (기본값 설정)
                                    selectedStartTime = TimeOfDay.now();
                                    selectedEndTime = TimeOfDay(
                                      hour: (TimeOfDay.now().hour + 1) % 24,
                                      minute: TimeOfDay.now().minute,
                                    );
                                  }
                                });
                              },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12.0,
                                  horizontal: 16.0,
                                ),
                                child: Row(
                                  children: [
                                    // const Icon(Icons.event_available),
                                    Icon( // ☑️ 다크모드 적용 - const 제거하고 색상 추가
                                      Icons.event_available,
                                      color: ThemeManager.getPopupSecondaryTextColor(),
                                    ),
                                    const SizedBox(width: 12),
                                    Text(
                                      '종일 선택',
                                      // style: getTextStyle(fontSize: 12),
                                      style: getTextStyle( // ☑️ 다크모드 적용 - 색상 추가
                                        fontSize: 12,
                                        color: ThemeManager.getTextColor(),
                                      ),
                                    ),
                                    const Spacer(),
                                    Switch(
                                      value: selectedStartTime == null && selectedEndTime == null,
                                      onChanged: (bool value) {
                                        setState(() {
                                          if (value) {
                                            // 종일 일정으로 설정
                                            selectedStartTime = null;
                                            selectedEndTime = null;
                                          } else {
                                            // 시간 기반 일정으로 설정 (기본값 설정)
                                            selectedStartTime = TimeOfDay.now();
                                            selectedEndTime = TimeOfDay(
                                              hour: (TimeOfDay.now().hour + 1) % 24,
                                              minute: TimeOfDay.now().minute,
                                            );
                                          }
                                        });
                                      },
                                      activeColor: _getColorByColorId(selectedColorId),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12), // ☑️ 간격 줄임 - 16 → 12
                          // 시간 선택 UI (종일이 아닌 경우에만 표시)
                          if (selectedStartTime != null ||
                              selectedEndTime != null) ...[
                            Row(
                              children: [
                                Expanded(
                                  child: Material(
                                    // color: Colors.grey[100],
                                    color: ThemeManager.getPopupSecondaryBackgroundColor(), // ☑️ 팝업창 테마 통일_250619_변경
                                    borderRadius: BorderRadius.circular(12),
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(12),
                                      onTap: () async {
                                        final TimeOfDay?
                                        picked = await showTimePicker(
                                          context: context,
                                          initialTime: selectedStartTime ?? TimeOfDay.now(),
                                          builder: (context, child) {
                                            return Theme(
                                              data: Theme.of(context).copyWith(
                                                timePickerTheme: TimePickerThemeData(
                                                  // backgroundColor: Colors.white,
                                                  // hourMinuteTextColor:
                                                  //     Colors.black,
                                                  // dayPeriodTextColor:
                                                  //     Colors.black,
                                                  // dayPeriodColor:
                                                  //     Colors.grey[200],
                                                  // dayPeriodShape:
                                                  //     RoundedRectangleBorder(
                                                  //       borderRadius:
                                                  //           BorderRadius.circular(
                                                  //             8,
                                                  //           ),
                                                  //     ),
                                                  backgroundColor: ThemeManager.getPopupBackgroundColor(),
                                                  hourMinuteTextColor: ThemeManager.getTextColor(),
                                                  dayPeriodTextColor: ThemeManager.getTextColor(),
                                                  dayPeriodColor: ThemeManager.getPopupSecondaryBackgroundColor(),
                                                ),
                                              ),
                                              child: child!,
                                            );
                                          },
                                        );
                                        if (picked != null) {
                                          setState(() {
                                            selectedStartTime = picked;
                                            // 시작 시간이 변경되면 종료 시간도 자동으로 1시간 후로 업데이트
                                            selectedEndTime = TimeOfDay(
                                              // hour: _HE_250620_병합 전 코드
                                              //     (selectedStartTime.hour + 1) %
                                              //     24,
                                              // minute: selectedStartTime.minute, // 
                                              
                                              hour: (picked.hour + 1) % 24, // 병합
                                              minute: picked.minute,
                                            );
                                          });
                                        }
                                      },
                                      child: Container( // ☑️ _HE_250620_Padding → Container로 변경
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 12.0,
                                          horizontal: 12.0, // ☑️ _HE_250620_16.0 → 12.0으로 감소
                                        ),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              '시작',
                                              style: getTextStyle(
                                                // color: Colors.grey,
                                                color: ThemeManager.getPopupSecondaryTextColor(), // ☑️ 팝업창 테마 통일_250619_변경
                                                fontSize: 12, // ☑️ _HE_250620_10 → 12로 통일일
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Row(
                                              children: [
                                                Icon( // ☑️ 팝업창 테마 통일_250619_const 제거
                                                  Icons.access_time,
                                                  size: 16, // ☑️ _HE_250620_18 → 16으로 감소
                                                  color: ThemeManager.getPopupSecondaryTextColor(), // ☑️ 팝업창 테마 통일_250619_추가  
                                                ),
                                                const SizedBox(width: 6), // ☑️ _HE_250620_8에서 6으로 감소
                                                Text(
                                                  // '${selectedStartTime.hour.toString().padLeft(2, '0')}:${selectedStartTime.minute.toString().padLeft(2, '0')}',
                                                  selectedStartTime != null
                                                      ? '${selectedStartTime!.hour.toString().padLeft(2, '0')}:${selectedStartTime!.minute.toString().padLeft(2, '0')}'
                                                      : '종일', // _HE_250620_병합 부분...!!

                                                  style: getTextStyle(
                                                    fontSize: 16,
                                                    // color: Colors.black87,
                                                    color: ThemeManager.getTextColor(), // ☑️ 팝업창 테마 통일_250619_변경
                                                  ),
                                                  overflow: TextOverflow.ellipsis, // ☑️ 오버플로우 처리
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12), // ☑️ _HE_250620_16에서 12로 감소
                                Expanded(
                                  child: Material(
                                    // color: Colors.grey[100],
                                    color: ThemeManager.getPopupSecondaryBackgroundColor(), // ☑️ 팝업창 테마 통일_250619_변경
                                    borderRadius: BorderRadius.circular(12),
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(12),
                                      onTap: () async {
                                        final TimeOfDay?
                                        picked = await showTimePicker(
                                          context: context,
                                          initialTime: selectedEndTime ?? TimeOfDay.now(),
                                          builder: (context, child) {
                                            return Theme(
                                              data: Theme.of(context).copyWith(
                                                timePickerTheme: TimePickerThemeData(
                                                  // backgroundColor: Colors.white,
                                                  // hourMinuteTextColor:
                                                  //     Colors.black,
                                                  // dayPeriodTextColor:
                                                  //     Colors.black,
                                                  // dayPeriodColor:
                                                  //     Colors.grey[200],
                                                  // dayPeriodShape:
                                                  //     RoundedRectangleBorder(
                                                  //       borderRadius:
                                                  //           BorderRadius.circular(
                                                  //             8,
                                                  //           ),
                                                  //     ),
                                                  // ☑️ 팝업창 테마 통일_250619_변경
                                                  backgroundColor: ThemeManager.getPopupBackgroundColor(),
                                                  hourMinuteTextColor: ThemeManager.getTextColor(),
                                                  dayPeriodTextColor: ThemeManager.getTextColor(),
                                                  dayPeriodColor: ThemeManager.getPopupSecondaryBackgroundColor(),
                                                ),
                                              ),
                                              child: child!,
                                            );
                                          },
                                        );
                                        if (picked != null) {
                                          setState(() {
                                            selectedEndTime = picked;
                                        });
                                      }
                                    },
                                    child: Container( // ☑️ _HE_250620_Padding → Container로 변경
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 12.0,
                                        horizontal: 12.0, // ☑️ _HE_250620_16.0 → 12.0으로 감소
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            '종료',
                                            style: getTextStyle(
                                              // color: Colors.grey,
                                              color: ThemeManager.getPopupSecondaryTextColor(), // ☑️ 팝업창 테마 통일_250619_변경
                                              fontSize: 12,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Row(
                                            children: [
                                              Icon( // ☑️ 팝업창 테마 통일_250619_const 제거
                                                Icons.access_time,
                                                size: 16, // ☑️ _HE_250620_18 → 16으로 감소
                                                color: ThemeManager.getPopupSecondaryTextColor(), // ☑️ 팝업창 테마 통일_250619_추가
                                              ),
                                              const SizedBox(width: 6), // ☑️ _HE_250620_8에서 6으로 감소
                                              Text(
                                                // '${selectedEndTime.hour.toString().padLeft(2, '0')}:${selectedEndTime.minute.toString().padLeft(2, '0')}',
                                                selectedEndTime != null
                                                    ? '${selectedEndTime!.hour.toString().padLeft(2, '0')}:${selectedEndTime!.minute.toString().padLeft(2, '0')}'
                                                    : '종일', // _HE_250620_병합 부분...!!

                                                style: getTextStyle(
                                                  fontSize: 16,
                                                  // color: Colors.black87,
                                                  color: ThemeManager.getTextColor(), // ☑️ 팝업창 테마 통일_250619_변경
                                                ),
                                                overflow: TextOverflow.ellipsis, // ☑️ 오버플로우 처리
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          
                          const SizedBox(height: 20),
                          // 반복 옵션 섹션: 일정 수정
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Text('반복 설정', style: getTextStyle(fontSize: 16)),
                              Text('반복 설정', style: getTextStyle(fontSize: 16, color: ThemeManager.getTextColor())), // ☑️ 팝업창 테마 통일_250619_추가
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 8.0,
                                runSpacing: 8.0,
                                children:
                                    RecurrenceType.values.map((recurrence) {
                                      final isSelected =
                                          selectedRecurrence == recurrence;
                                      return FilterChip(
                                        label: Text(
                                          recurrence.label,
                                          style: getTextStyle(
                                            fontSize: 12,
                                            // color: Colors.black87,
                                            color: isSelected 
                                              ? Colors.white 
                                              : ThemeManager.getTextColor(), // ☑️ 팝업창 테마 통일_250619_변경
                                          ),
                                        ),
                                        selected: isSelected,
                                        onSelected: (bool selected) {
                                          setState(() {
                                            selectedRecurrence =
                                                selected
                                                    ? recurrence
                                                    : RecurrenceType.none;
                                            // 반복 타입이 변경되면 해당 타입의 기본 반복 횟수로 설정
                                            if (selected &&
                                                recurrence !=
                                                    RecurrenceType.none) {
                                              recurrenceCount =
                                                  recurrence.defaultCount;
                                            } else if (!selected) {
                                              recurrenceCount = 1;
                                            }
                                          });
                                        },
                                        // backgroundColor: Colors.grey[100],
                                        backgroundColor: ThemeManager.getPopupSecondaryBackgroundColor(), // ☑️ 팝업창 테마 통일_250619_변경
                                        
                                        selectedColor: _getColorByColorId(
                                          selectedColorId,
                                        ),
                                        checkmarkColor: Colors.white,
                                        elevation: isSelected ? 2 : 0,
                                        shadowColor: _getColorByColorId(
                                          selectedColorId,
                                        ).withOpacity(0.3),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            20,
                                          ),
                                          side: BorderSide(
                                            color:
                                                isSelected
                                                    ? _getColorByColorId(
                                                      selectedColorId,
                                                    )
                                                    // : Colors.grey[300]!,
                                                    : ThemeManager.getPopupBorderColor(), // ☑️ 팝업창 테마 통일_250619_변경
                                            width: 1,
                                          ),
                                        ),
                                      );
                                    }).toList(),
                              ),
                              // 반복 횟수 선택 (반복이 선택된 경우에만 표시)
                              if (selectedRecurrence !=
                                  RecurrenceType.none) ...[
                                const SizedBox(height: 12),
                                Row( 
                                  children: [
                                    Text(
                                        '반복 횟수',
                                        style: getTextStyle(
                                          fontSize: 14,
                                          color: ThemeManager.getTextColor(), // ☑️ 팝업창 테마 통일_250619_추가
                                        ),
                                      ),
                                    const Spacer(), // ☑️ _HE_250620_Spacer 추가
                                      
                                    Container(
                                      width: 90, // ☑️ 140에서 90으로 감소
                                      height: 34, // ☑️ 40에서 34으로 감소
                                      decoration: BoxDecoration(
                                        color: ThemeManager.getPopupSecondaryBackgroundColor(),
                                        border: Border.all(
                                          color: ThemeManager.getPopupBorderColor(),
                                        ),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            flex: 1,
                                            child: InkWell(
                                              onTap: () {
                                                setState(() {
                                                  if (recurrenceCount > 1) {
                                                    recurrenceCount--;
                                                  }
                                                });
                                              },
                                              child: Container(
                                                height: double.infinity,
                                                alignment: Alignment.center, // ☑️ _HE_250620_alignment 추가
                                                child: Icon(
                                                  Icons.remove,
                                                  size: 14,
                                                  color: ThemeManager.getPopupSecondaryTextColor(),
                                                ),
                                              ),
                                            ),
                                          ),
                                          Expanded(
                                            flex: 2,
                                            child: Container(
                                              alignment: Alignment.center,
                                              child: Text(
                                                '$recurrenceCount',
                                                style: getTextStyle(
                                                  fontSize: 14,
                                                  color: ThemeManager.getTextColor(),
                                                ),
                                              ),
                                            ),
                                          ),
                                          Expanded(
                                            flex: 1,
                                            child: InkWell(
                                              onTap: () {
                                                setState(() {
                                                  if (recurrenceCount < 50) {
                                                    recurrenceCount++;
                                                  }
                                                });
                                              },
                                              child: Container(
                                                height: double.infinity,
                                                alignment: Alignment.center, // ☑️ _HE_250620_alignment 추가
                                                child: Icon(
                                                  Icons.add,
                                                  size: 14,
                                                  color: ThemeManager.getPopupSecondaryTextColor(),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8), // ☑️ _HE_250620_12에서 8로 감소  

                                    // Flexible( // ☑️ 설명 텍스트를 Flexible로 감싸기
                                      // child: Text(
                                      // Text(
                                    Expanded(
                                      child: Text(
                                        _getRecurrenceDescription(selectedRecurrence),
                                        style: getTextStyle(
                                          fontSize: 12,
                                          color: ThemeManager.getPopupSecondaryTextColor(),
                                        ),
                                        overflow: TextOverflow.ellipsis, // ☑️ 오버플로우 처리
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 24),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              OutlinedButton(
                                onPressed: () => Navigator.pop(context),
                                style: OutlinedButton.styleFrom(
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 12,
                                  ),
                                  foregroundColor: ThemeManager.getTextColor(), // ☑️ 팝업창 테마 통일_250619_추가
                                  side: BorderSide(  // ☑️ 팝업창 테마 통일_250619_추가
                                    color: ThemeManager.getPopupBorderColor(),
                                  ),
                                ),
                                child: Text(
                                  '취소',
                                  // style: getTextStyle(fontSize: 12),
                                  style: getTextStyle(
                                    color: ThemeManager.getTextColor(), // ☑️ 팝업창 테마 통일_250619_추가
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              ElevatedButton(
                                onPressed: () async {
                                  // 입력 검증 추가
                                  if (titleController.text.trim().isEmpty) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('일정 제목을 입력해주세요.'),
                                        backgroundColor: Colors.orange,
                                      ),
                                    );
                                    return;
                                  }

                                  // 종일 일정 여부 확인
                                  bool isAllDayEvent =
                                      selectedStartTime == null ||
                                      selectedEndTime == null;

                                  // 시간 기반 일정의 경우에만 시간 유효성 검사
                                  if (!isAllDayEvent) {
                                    final startTotalMinutes =
                                        selectedStartTime!.hour * 60 +
                                        selectedStartTime!.minute;
                                    final endTotalMinutes =
                                        selectedEndTime!.hour * 60 +
                                        selectedEndTime!.minute;

                                    // 시작 시간과 종료 시간이 같은 경우에만 오류
                                    if (startTotalMinutes == endTotalMinutes) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            '종료 시간은 시작 시간보다 늦어야 합니다.',
                                          ),
                                          backgroundColor: Colors.orange,
                                        ),
                                      );
                                      return;
                                    }
                                  }

                                  // 시간 변환
                                  String startTimeStr;
                                  String? endTimeStr;

                                  if (isAllDayEvent) {
                                    startTimeStr = '종일';
                                    endTimeStr = null;
                                  } else {
                                    startTimeStr =
                                        '${selectedStartTime!.hour.toString().padLeft(2, '0')}:${selectedStartTime!.minute.toString().padLeft(2, '0')}';
                                    endTimeStr =
                                        '${selectedEndTime!.hour.toString().padLeft(2, '0')}:${selectedEndTime!.minute.toString().padLeft(2, '0')}';
                                  } // 이벤트 업데이트
                                  final Event updatedEvent;

                                  if (!isAllDayEvent) {
                                    // 시간 기반 일정의 경우 다음 날로 넘어가는지 확인
                                    final startTotalMinutes =
                                        selectedStartTime!.hour * 60 +
                                        selectedStartTime!.minute;
                                    final endTotalMinutes =
                                        selectedEndTime!.hour * 60 +
                                        selectedEndTime!.minute;

                                    if (startTotalMinutes > endTotalMinutes) {
                                      // 날짜가 넘어가는 경우 - 멀티데이 이벤트로 처리
                                      final today = event.date;
                                      final tomorrow = today.add(
                                        const Duration(days: 1),
                                      );

                                      updatedEvent = event.copyWith(
                                        title: titleController.text.trim(),
                                    //     time: // _HE_250620_병합 전 코드
                                    //     '${selectedStartTime.hour.toString().padLeft(2, '0')}:${selectedStartTime.minute.toString().padLeft(2, '0')}',
                                    // endTime:
                                    //     '${selectedEndTime.hour.toString().padLeft(2, '0')}:${selectedEndTime.minute.toString().padLeft(2, '0')}',
                                        time: startTimeStr,
                                        endTime: endTimeStr,
                                        isMultiDay: true,
                                        startDate: today,
                                        endDate: tomorrow,
                                        colorId: selectedColorId.toString(),
                                        recurrence: selectedRecurrence,
                                        recurrenceCount: recurrenceCount,
                                      );
                                    } else {
                                      // 일반적인 시간 기반 이벤트
                                      updatedEvent = event.copyWith(
                                        title: titleController.text.trim(),
                                        time: startTimeStr,
                                        endTime: endTimeStr,
                                        colorId: selectedColorId.toString(),
                                        recurrence: selectedRecurrence,
                                        recurrenceCount: recurrenceCount,
                                      );
                                    }
                                  } else {
                                    // 종일 이벤트
                                    updatedEvent = event.copyWith(
                                      title: titleController.text.trim(),
                                      time: startTimeStr,
                                      endTime: endTimeStr,
                                      isMultiDay: false,
                                      startDate: null,
                                      endDate: null,
                                      colorId: selectedColorId.toString(),
                                      recurrence: selectedRecurrence,
                                      recurrenceCount: recurrenceCount,
                                    );
                                  }

                                  try {
                                    await _eventManager.updateEvent(
                                      event,
                                      updatedEvent,
                                      syncWithGoogle: true,
                                    );
                                    Navigator.pop(context);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          '일정이 수정되었습니다: ${titleController.text.trim()}',
                                        ),
                                        backgroundColor: Colors.green,
                                      ),
                                    );
                                  } catch (e) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('일정 수정 실패: $e'),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                  }
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _getColorByColorId(
                                    selectedColorId,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 12,
                                  ),
                                ),
                                child: Text(
                                  '수정',
                                  style: getTextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
          ),
    );
  }

  // 이벤트 삭제 확인 다이얼로그 표시_HE_250620_다크모드 적용용
  Future<bool?> showDeleteEventDialog(BuildContext context, Event event) async {
    return showDialog<bool>(
      context: context,
      builder:
          (context) => Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16.0),
            ),
            elevation: 0,
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                // color: Colors.white,
                color: ThemeManager.getEventPopupBackgroundColor(), // ☑️ _HE_250620_변경
                borderRadius: BorderRadius.circular(16.0),
                border: Border.all( // ☑️ _HE_250620_테두리 추가
                  color: ThemeManager.getEventPopupBorderColor(),
                  width: 1,
                ),
              ),
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.85,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          // color: Colors.red.withOpacity(0.1),
                          color: ThemeManager.isDarkMode // ☑️ _HE_250620_변경
                              ? Colors.red.withOpacity(0.2) // ☑️ 다크 모드용
                              : Colors.red.withOpacity(0.1), // ☑️ 라이트 모드용
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(  // ☑️ _HE_250620_const → 제거
                          Icons.delete_outline,
                          // color: Colors.red,
                          color: ThemeManager.isDarkMode 
                              ? Colors.red[300] // ☑️ 다크 모드용
                              : Colors.red, // ☑️ 라이트 모드용
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        '일정 삭제',
                        style: getTextStyle(
                          fontSize: 20,
                          // color: Colors.black87,
                          color: ThemeManager.getTextColor(), // ☑️ _HE_250620_변경
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      // color: Colors.grey[50],
                      color: ThemeManager.getPopupSecondaryBackgroundColor(), // ☑️ _HE_250620_변경
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        // color: Colors.grey[200]!, width: 1),
                        color: ThemeManager.getPopupBorderColor(), // ☑️ _HE_250620_변경
                        width: 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                color: _getColorByColorId(
                                  event.getColorId() ?? 1,
                                ),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                event.title,
                                style: getTextStyle(
                                  fontSize: 16,
                                  // color: Colors.black87,
                                  color: ThemeManager.getTextColor(), // ☑️ _HE_250620_변경
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon( // ☑️ _HE_250620_const → 제거
                              Icons.access_time,
                              size: 16,
                              // color: Colors.grey,
                              color: ThemeManager.getPopupSecondaryTextColor(), // ☑️ _HE_250620_변경
                            ),
                            const SizedBox(width: 4),
                            Text(
                              event.time == '종일'
                                  ? '종일'
                                  : '${event.time}${event.endTime != null ? ' - ${event.endTime}' : ''}',
                              style: getTextStyle(
                                fontSize: 14,
                                // color: Colors.grey,
                                color: ThemeManager.getPopupSecondaryTextColor(), // ☑️ _HE_250620_변경
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon( // ☑️ _HE_250620_const → 제거
                              Icons.calendar_today,
                              size: 16,
                              // color: Colors.grey,
                              color: ThemeManager.getPopupSecondaryTextColor(), // ☑️ _HE_250620_변경
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${event.date.year}년 ${event.date.month}월 ${event.date.day}일',
                              style: getTextStyle(
                                fontSize: 14,
                                // color: Colors.grey,
                                color: ThemeManager.getPopupSecondaryTextColor(), // ☑️ _HE_250620_변경
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    '이 일정을 삭제하시겠습니까?',
                    style: getTextStyle(
                      fontSize: 16, 
                      // color: Colors.black87,
                      color: ThemeManager.getTextColor(), // ☑️ _HE_250620_변경
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '삭제된 일정은 복구할 수 없습니다.',
                    style: getTextStyle(
                      fontSize: 14, 
                      // color: Colors.grey[600],
                      color: ThemeManager.getPopupSecondaryTextColor(), // ☑️ _HE_250620_변경
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      OutlinedButton(
                        onPressed: () => Navigator.pop(context, false),
                        style: OutlinedButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                          foregroundColor: ThemeManager.getTextColor(), // ☑️ _HE_250620_추가
                          side: BorderSide(  // ☑️ _HE_250620_추가
                            color: ThemeManager.getPopupBorderColor(),
                          ),
                        ),
                        child: Text(
                          '취소', 
                          style: getTextStyle(
                            fontSize: 12,
                            color: ThemeManager.getTextColor(), // ☑️ _HE_250620_추가
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(context, true),
                        style: ElevatedButton.styleFrom(
                          // backgroundColor: Colors.red,
                          backgroundColor: ThemeManager.isDarkMode // ☑️ _HE_250620_변경
                              ? Colors.red[400] // ☑️ 다크 모드용
                              : Colors.red, // ☑️ 라이트 모드용
                          foregroundColor: Colors.white, 
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.delete, size: 16),
                            const SizedBox(width: 4),
                            Text('삭제', style: getTextStyle(fontSize: 12)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
    );
  }

  // colorId로 색상 가져오기 (Google Calendar 표준 색상)
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

  /// 반복 이벤트들을 생성하는 헬퍼 메서드
  Future<void> _createRecurringEvents(
    Event baseEvent,
    int colorId,
    RecurrenceType recurrence,
    int recurrenceCount,
  ) async {
    List<Event> eventsToAdd = [];
    DateTime currentDate = baseEvent.date;

    // 사용자가 지정한 반복 횟수 사용
    for (int i = 0; i < recurrenceCount; i++) {
      if (i > 0) {
        currentDate = _getNextOccurrence(currentDate, recurrence);
      }

      final recurringEvent = baseEvent.copyWith(
        date: currentDate,
        recurrence:
            i == 0 ? recurrence : RecurrenceType.none, // 첫 번째 이벤트만 원본 반복 타입 유지
        recurrenceCount: recurrenceCount, // 반복 횟수 정보 저장
      );

      eventsToAdd.add(recurringEvent);
    }

    // 모든 반복 이벤트를 추가
    for (final event in eventsToAdd) {
      try {
        await _eventManager.addEventWithColorId(
          event,
          colorId,
          syncWithGoogle: true,
        );
      } catch (e) {
        print('반복 이벤트 추가 실패: ${event.date} - $e');
        // 하나가 실패해도 계속 진행
      }
    }
  }

  /// 다음 반복 일자 계산
  DateTime _getNextOccurrence(DateTime current, RecurrenceType recurrence) {
    switch (recurrence) {
      case RecurrenceType.daily:
        return current.add(const Duration(days: 1));
      case RecurrenceType.weekly:
        return current.add(const Duration(days: 7));
      case RecurrenceType.monthly:
        return DateTime(
          current.month == 12 ? current.year + 1 : current.year,
          current.month == 12 ? 1 : current.month + 1,
          current.day,
          current.hour,
          current.minute,
          current.second,
          current.millisecond,
          current.microsecond,
        );
      case RecurrenceType.yearly:
        return DateTime(
          current.year + 1,
          current.month,
          current.day,
          current.hour,
          current.minute,
          current.second,
          current.millisecond,
          current.microsecond,
        );
      case RecurrenceType.none:
        return current;
    }
  }

  /// 반복 유형에 대한 설명 반환
  String _getRecurrenceDescription(RecurrenceType recurrence) {
    switch (recurrence) {
      case RecurrenceType.daily:
        return '매일';
      case RecurrenceType.weekly:
        return '매주';
      case RecurrenceType.monthly:
        return '매월';
      case RecurrenceType.yearly:
        return '매년';
      case RecurrenceType.none:
        return '반복 없음';
    }
  }
}
