import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeManager {
  static bool _isDarkMode = false;
  static bool get isDarkMode => _isDarkMode;

// ☑️ 테마 관련 추가
  // 상태 변경 알림을 위한 리스너 리스트
  static final List<VoidCallback> _listeners = [];
  
  // 초기화
  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _isDarkMode = prefs.getBool('dark_mode') ?? false;
  }
  
  // 리스너 등록
  static void addListener(VoidCallback listener) {
    _listeners.add(listener);
  }
  
  // 리스너 제거
  static void removeListener(VoidCallback listener) {
    _listeners.remove(listener);
  }
  
  // 모든 리스너에게 변경 알림
  static void _notifyListeners() {
    for (var listener in _listeners) {
      listener();
    }
  }
  
  // 테마 토글 (리스너 알림 추가)
  static Future<void> toggleTheme() async {
    _isDarkMode = !_isDarkMode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('dark_mode', _isDarkMode);
    
    // 모든 리스너에게 변경 알림
    _notifyListeners();
  }
  
  // 기본 색상 가져오기
  static Color getTextColor({Color? lightColor, Color? darkColor}) {
    return _isDarkMode ? (darkColor ?? Colors.white) : (lightColor ?? Colors.black);
  }
  
  static Color getBackgroundColor({Color? lightColor, Color? darkColor}) {
    // return _isDarkMode ? (darkColor ?? const Color(0xFF121212)) : (lightColor ?? Colors.white);
    // ☑️ 캘린더와 채팅 화면의 메인 배경을 헤더와 동일한 초록색으로 변경
    return getNavigationBarColor(); // 헤더와 동일한 초록색 배경 적용
  }
  
  static Color getCardColor({Color? lightColor, Color? darkColor}) {
    return _isDarkMode ? (darkColor ?? const Color(0xFF1F1F1F)) : (lightColor ?? Colors.white);
  }
  
  // 캘린더 전용 색상들
  static Color getCalendarBackgroundColor() {
    return _isDarkMode ? const Color(0xFF2C2C2C) : Colors.white;
  }
  
  static Color getCalendarSelectedColor() {
    return _isDarkMode ? Colors.blue[600]! : const Color.fromARGB(200, 68, 138, 218);
  }
  
  static Color getCalendarTodayColor() {
    return _isDarkMode ? Colors.amber[700]! : Colors.amber[300]!;
  }
  
  static Color getCalendarHolidayColor() {
    return _isDarkMode ? const Color.fromARGB(255, 80, 40, 40) : const Color.fromARGB(255, 255, 240, 240);
  }
  
  static Color getCalendarWeekendColor() {
    return _isDarkMode ? const Color(0xFF333333) : const Color(0xFFEEEEEE);
  }
  
  static Color getCalendarOutsideColor() {
    // return _isDarkMode ? const Color(0xFF1F1F1F) : const Color(0xFFDDDDDD); //_HE_250623_1428_기존 색상 변경
    return _isDarkMode ? const Color(0xFF2A2A2A) : const Color(0xFFBBBBBB);
  }
  
  static Color getNavigationBarColor() {
    return _isDarkMode ? const Color.fromARGB(255, 100, 150, 100) : const Color.fromARGB(255, 162, 222, 141);
  }
  
  // 요일별 텍스트 색상
  static Color getSaturdayColor() {
    return _isDarkMode ? const Color.fromARGB(255, 100, 200, 255) : const Color.fromARGB(255, 54, 184, 244);
  }
  
  static Color getSundayColor() {
    return _isDarkMode ? Colors.red[300]! : Colors.red;
  }

// 캘린더 헤더 전용 색상들
static Color getCalendarHeaderBackgroundColor() {
  // return _isDarkMode ? const Color.fromARGB(255, 63, 63, 63) : const Color.fromARGB(255, 204, 204, 204); // 어두운 회색
  return getNavigationBarColor(); // ☑️ 네비게이션바와 동일한 색상 적용
  // return _isDarkMode ? const Color.fromARGB(255, 100, 150, 100) : const Color.fromARGB(255, 162, 222, 141); // ☑️ 네비게이션바와 동일한 색상 직접 적용
}

static Color getCalendarHeaderIconColor() {
  return _isDarkMode ? Color(0xFF1F1F1F) : Colors.black; // 아이콘은 화이트
}

static Color getCalendarHeaderTextColor() {
  // return _isDarkMode ? const Color(0xFFB0B0B0) : Colors.black; // 밝은 회색
  return _isDarkMode ? const Color(0xFF1F1F1F) : Colors.black; // 연두 배경에 어두운 글씨가 보기 좋겠지...?
}

static Color getCalendarDayOfWeekBackgroundColor() {
  return _isDarkMode ? const Color(0xFF2A2A2A) : const Color(0xFFEEEEEE); // 요일 헤더 배경
}

static Color getCalendarDayOfWeekTextColor(bool isWeekend, bool isSaturday) {
  if (_isDarkMode) {
    if (isSaturday) {
      return const Color(0xFF87CEEB); // 밝은 파란색
    } else if (isWeekend) {
      return const Color(0xFFFF6B6B); // 밝은 빨간색
    } else {
      return const Color(0xFFE0E0E0); // 밝은 회색
    }
  } else {
    if (isSaturday) {
      return const Color.fromARGB(255, 54, 184, 244);
    } else if (isWeekend) {
      return Colors.red;
    } else {
      return Colors.black;
    }
  }
}

// ☑️ 캘린더 테두리 전용 색상 (다음달 날짜 배경과 동일하게)
  static Color getCalendarBorderColor() {
    return getCalendarOutsideColor(); // 다음달 날짜 배경과 동일한 색상 사용
  }

// 캘린더 메인 배경색 (검정에 가까운 어두운 회색)
static Color getCalendarMainBackgroundColor() {
  // return _isDarkMode ? const Color(0xFF1A1A1A) : Colors.white; // 검정에 가까운 어두운 회색
  return getNavigationBarColor();
}  

// ☑️ 사이드바 전용 배경색 (라이트: 밝은색, 다크: 검정색)
static Color getSidebarBackgroundColor() {
  return _isDarkMode ? const Color(0xFF121212) : Colors.white;
}

// ☑️ 브리핑 설정 페이지 전용 배경색 (라이트: 흰색, 다크: 어두운 회색)
static Color getBriefingSettingsBackgroundColor() {
  return _isDarkMode ? const Color(0xFF121212) : Colors.white;
}

// _weather_calendar_cell_날짜 셀 전용 색상들
static Color getCalendarCellBackgroundColor({bool isSelected = false, bool isToday = false, bool isHoliday = false, bool isWeekend = false}) {
  if (isSelected) {
    return _isDarkMode ? Colors.blue[700]! : const Color.fromARGB(200, 68, 138, 218);
  } else if (isToday) {
    return _isDarkMode ? Colors.amber[700]! : Colors.amber[300]!;
  } else if (isHoliday) {
    return _isDarkMode ? const Color.fromARGB(255, 80, 40, 40) : const Color.fromARGB(255, 255, 240, 240);
  } else if (isWeekend) {
    return _isDarkMode ? const Color(0xFF1E1E1E) : const Color.fromARGB(255, 255, 255, 255); //_HE_평일과 같은 컬러로 설정. 필요시 별도 설정 가능.
  }
  return _isDarkMode ? const Color(0xFF1E1E1E) : Colors.white; // 기본 날짜 셀 배경 
}

static Color getCalendarCellDateColor({bool isSelected = false, bool isHoliday = false, bool isSaturday = false, bool isSunday = false}) {
  if (isSelected) {
    return Colors.white;
  } else if (isHoliday) {
    return _isDarkMode ? Colors.red[300]! : Colors.red;
  } else if (isSaturday) {
    return _isDarkMode ? const Color(0xFF87CEEB) : const Color.fromARGB(255, 54, 184, 244);
  } else if (isSunday) {
    return _isDarkMode ? const Color(0xFFFF6B6B) : Colors.red;
  }
  return _isDarkMode ? const Color(0xFFE0E0E0) : Colors.black; // 기본 날짜 텍스트
}

// 날짜 셀 보더 색상
static Color getCalendarCellBorderColor() {
  return _isDarkMode ? const Color(0xFF404040) : const Color(0xFFE0E0E0);
}


// 팝업창 핵심 컬러 간결화 -일괄 스타일 
// === 팝업창 핵심 색상 (5개만 유지) ===
static Color getPopupBackgroundColor() {
  return _isDarkMode ? const Color(0xFF3A3A3A) : Colors.white;
}

static Color getPopupHeaderColor() {
  return _isDarkMode ? const Color(0xFF1F1F1F) : Colors.black;
}

static Color getPopupBorderColor() {
  return _isDarkMode ? const Color(0xFF555555) : Colors.grey[300]!;
}

static Color getPopupSecondaryBackgroundColor() {
  return _isDarkMode ? const Color(0xFF2A2A2A) : Colors.grey[100]!;
}

static Color getPopupSecondaryTextColor() {
  return _isDarkMode ? const Color(0xFFBDBDBD)! : Colors.grey[600]!;
}

// === 기존 메서드들을 통합된 색상으로 리다이렉트 ===
static Color getEventPopupBackgroundColor() => getPopupBackgroundColor();
static Color getEventPopupHeaderColor() => getPopupHeaderColor();
static Color getEventPopupBorderColor() => getPopupBorderColor();
static Color getEventPopupTextColor() => getTextColor();

// Material, FilterChip, Counter 등 모든 보조 배경
static Color getEventPopupMaterialBackgroundColor() => getPopupSecondaryBackgroundColor();
static Color getEventPopupFilterChipBackgroundColor() => getPopupSecondaryBackgroundColor();
static Color getEventPopupCounterBackgroundColor() => getPopupSecondaryBackgroundColor();

// 모든 보조 텍스트 (힌트, 아이콘 등)
static Color getEventPopupHintTextColor() => getPopupSecondaryTextColor();
static Color getEventPopupSecondaryTextColor() => getPopupSecondaryTextColor();
static Color getEventPopupIconColor() => getPopupSecondaryTextColor();

// 모든 보조 테두리
static Color getEventPopupCounterBorderColor() => getPopupBorderColor();
static Color getEventPopupOutlinedButtonBorderColor() => getPopupBorderColor();

// TimePicker는 기본 테마 색상 사용
static Color getEventPopupTimePickerBackgroundColor() => getPopupBackgroundColor();
static Color getEventPopupTimePickerTextColor() => getTextColor();
static Color getEventPopupTimePickerDayPeriodColor() => getPopupSecondaryBackgroundColor();

// 닫기 버튼은 특별 색상 유지
static Color getEventPopupCloseButtonColor() {
  return _isDarkMode ? Colors.red[400]! : Colors.red;
}



// 현재 Flutter의 기본 DatePicker와 ColorPickerDialog가 시스템 테마를 따르지 않고 있습니다. 이를 해결하기 위해 테마를 명시적으로 적용_250619
// DatePicker 전용 색상들
static Color getDatePickerBackgroundColor() {
  return _isDarkMode ? const Color(0xFF2D2D2D) : Colors.white;
}

static Color getDatePickerSurfaceColor() {
  return _isDarkMode ? const Color(0xFF3A3A3A) : Colors.white;
}

static Color getDatePickerTextColor() {
  return _isDarkMode ? Colors.white : Colors.black87;
}

static Color getDatePickerHeaderColor() {
  return _isDarkMode ? const Color(0xFF1F1F1F) : Colors.blue;
}

static Color getDatePickerSelectedColor() {
  return _isDarkMode ? Colors.blue[400]! : Colors.blue;
}

// ColorPicker 전용 색상들
static Color getColorPickerBackgroundColor() {
  return _isDarkMode ? const Color(0xFF2D2D2D) : Colors.white;
}

static Color getColorPickerHeaderColor() {
  return _isDarkMode ? const Color(0xFF1F1F1F) : Colors.blue;
}

static Color getColorPickerTextColor() {
  return _isDarkMode ? Colors.white : Colors.black87;
}

static Color getColorPickerButtonColor() {
  return _isDarkMode ? const Color(0xFF404040) : Colors.grey[200]!;
}

// 일정 추가 버튼 색상들
static Color getAddEventButtonColor() {
  return _isDarkMode ? const Color.fromARGB(255, 120, 180, 120) : const Color.fromARGB(255, 162, 222, 141);
}

static Color getAddMultiDayEventButtonColor() {
  return _isDarkMode ? const Color.fromARGB(255, 80, 120, 150) : const Color.fromARGB(255, 101, 157, 189);
}

  // 채팅 전용 색상들
  static Color getChatInputBackgroundColor() {
    return _isDarkMode ? const Color.fromARGB(122, 58, 58, 58) : const Color.fromARGB(31, 58, 58, 58); // 어두운 회색
  }

  static Color getChatMessageBackgroundColor() {
    return _isDarkMode ? const Color.fromARGB(255, 41, 41, 41) : Colors.grey[100]!; // 어두운 회색
  }

  static Color getChatReceivedMessageBackgroundColor() {
    return _isDarkMode ? const Color(0xFF404040) : Colors.grey[200]!; // 받은 메시지용
  }

  static Color getChatSentMessageBackgroundColor() {
    return _isDarkMode ? const Color.fromARGB(255, 52, 112, 67) : const Color.fromARGB(255, 33, 150, 243); // 보낸 메시지
  }

  static Color getChatMainBackgroundColor() {
    return _isDarkMode ? const Color(0xFF121212) : Colors.white; // 전체 배경
  }

  // ☑️ Info Box 전용 색상들 추가_250620
  static Color getInfoBoxBackgroundColor() {
    return _isDarkMode ? const Color(0xFF2A4A5A) : Colors.blue[50]!; // 다크모드: 어두운 청색, 라이트모드: 밝은 청색
  }

  static Color getInfoBoxBorderColor() {
    return _isDarkMode ? const Color(0xFF4A6A7A) : Colors.blue[200]!; // 다크모드: 중간 청색, 라이트모드: 중간 청색
  }

  static Color getInfoBoxIconColor() {
    return _isDarkMode ? Colors.blue[300]! : Colors.blue[600]!; // 다크모드: 밝은 청색, 라이트모드: 어두운 청색
  }

  static Color getInfoBoxTextColor() {
    return _isDarkMode ? Colors.blue[200]! : Colors.blue[700]!; // 다크모드: 밝은 청색, 라이트모드: 어두운 청색
  }

// ☑️ 로그인 화면 전용 배경색 (라이트: 흰색, 다크: 블랙)
static Color getLoginScreenBackgroundColor() {
  return _isDarkMode ? Colors.black : Colors.white;
}
}


