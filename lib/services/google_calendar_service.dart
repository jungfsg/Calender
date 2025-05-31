import 'package:googleapis/calendar/v3.dart' as calendar;
import 'package:googleapis_auth/auth_io.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import '../models/event.dart';
import 'package:intl/intl.dart';
import 'package:flutter/material.dart';

class GoogleCalendarService {
  static final GoogleCalendarService _instance = GoogleCalendarService._internal();
  factory GoogleCalendarService() => _instance;
  GoogleCalendarService._internal();

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: [
      calendar.CalendarApi.calendarScope,
      calendar.CalendarApi.calendarEventsScope,
    ],
  );

  calendar.CalendarApi? _calendarApi;
  bool _isInitialized = false;

  // 🎨 동적 색상 매핑 (Google Calendar Colors API에서 가져옴)
  static Map<String, Color> _eventColors = {}; // event 색상 팔레트
  static Map<String, Color> _calendarColors = {}; // calendar 색상 팔레트
  static Map<String, String> _eventColorHex = {}; // event hex 코드 저장
  static Map<String, String> _calendarColorHex = {}; // calendar hex 코드 저장
  static Map<String, Color> _userCalendarColors = {}; // 사용자 캘린더별 실제 색상
  static bool _colorsLoaded = false;

  // 기본 색상 (colorId가 없을 때 사용)
  static const Color _defaultEventColor = Color(0xFF1976D2);

  // 🎨 캘린더별 색상 정보 저장
  static String? _primaryCalendarColor;

  // Google Calendar 인증 및 초기화
  Future<bool> initialize() async {
    try {
      final GoogleSignInAccount? account = await _googleSignIn.signIn();
      if (account == null) {
        print('Google 로그인이 취소되었습니다.');
        return false;
      }

      final httpClient = await _googleSignIn.authenticatedClient();
      if (httpClient == null) {
        print('인증된 클라이언트를 가져올 수 없습니다.');
        return false;
      }

      _calendarApi = calendar.CalendarApi(httpClient);
      _isInitialized = true;
      
      // 🎨 초기화 시 색상 정보 로드
      await fetchColorsFromAPI();
      
      print('Google Calendar 서비스가 초기화되었습니다.');
      return true;
    } catch (e) {
      print('Google Calendar 초기화 오류: $e');
      return false;
    }
  }

  // 🎨 Google Calendar Colors API - 공식 문서 기준 완전 구현
  Future<bool> fetchColorsFromAPI() async {
    if (!_isInitialized || _calendarApi == null) {
      print('❌ Google Calendar 서비스가 초기화되지 않았습니다.');
      _initializeDefaultColors();
      return false;
    }

    try {
      print('🎨 Google Calendar Colors API 호출 시작');
      
      // Colors API 호출 - 공식 문서: service.colors().get().execute()
      final colors = await _calendarApi!.colors.get();
      
      // 🎨 공식 문서: Print available calendarListEntry colors
      if (colors.calendar != null) {
        print('📋 가져온 캘린더 색상 수: ${colors.calendar!.length}');
        
        _calendarColors.clear();
        _calendarColorHex.clear();
        
        // 공식 문서: for id, color in colors['calendar'].iteritem()
        colors.calendar!.forEach((colorId, colorDef) {
          print('🎨 Calendar ColorId: $colorId');
          print('  Background: ${colorDef.background}');
          print('  Foreground: ${colorDef.foreground}');
          
          if (colorDef.background != null) {
            final hexColor = colorDef.background!;
            _calendarColorHex[colorId] = hexColor;
            
            try {
              final colorValue = int.parse(hexColor.substring(1), radix: 16);
              final flutterColor = Color(0xFF000000 | colorValue);
              _calendarColors[colorId] = flutterColor;
            } catch (e) {
              print('⚠️ 캘린더 색상 변환 오류 (colorId: $colorId): $e');
            }
          }
        });
      }

      // 🎨 공식 문서: Print available event colors
      if (colors.event != null) {
        print('📋 가져온 이벤트 색상 수: ${colors.event!.length}');
        
        _eventColors.clear();
        _eventColorHex.clear();
        
        // 공식 문서: for id, color in colors['event'].iteritem()
        colors.event!.forEach((colorId, colorDef) {
          print('🎨 Event ColorId: $colorId');
          print('  Background: ${colorDef.background}');
          print('  Foreground: ${colorDef.foreground}');
          
          if (colorDef.background != null) {
            final hexColor = colorDef.background!;
            _eventColorHex[colorId] = hexColor;
            
            try {
              final colorValue = int.parse(hexColor.substring(1), radix: 16);
              final flutterColor = Color(0xFF000000 | colorValue);
              _eventColors[colorId] = flutterColor;
            } catch (e) {
              print('⚠️ 이벤트 색상 변환 오류 (colorId: $colorId): $e');
            }
          }
        });
      }

      _colorsLoaded = true;
      print('✅ Colors API 완료 - 캘린더: ${_calendarColors.length}개, 이벤트: ${_eventColors.length}개');
      return true;
      
    } catch (e) {
      print('❌ Colors API 호출 오류: $e');
      _initializeDefaultColors();
      return false;
    }
  }

  // 기본 색상 매핑 초기화 (API 호출 실패 시 폴백)
  void _initializeDefaultColors() {
    _eventColors = {
      '1': const Color(0xFF7986CB), // 라벤더
      '2': const Color(0xFF33B679), // 세이지
      '3': const Color(0xFF8E24AA), // 포도
      '4': const Color(0xFFE67C73), // 플라밍고
      '5': const Color(0xFFF6BF26), // 바나나
      '6': const Color(0xFFFF8A65), // 귤
      '7': const Color(0xFF4FC3F7), // 공작새
      '8': const Color(0xFF9E9E9E), // 그래파이트
      '9': const Color(0xFF3F51B5), // 블루베리
      '10': const Color(0xFF0B8043), // 바질
      '11': const Color(0xFFD50000), // 토마토
    };
    _colorsLoaded = true;
    print('🔄 기본 색상 매핑으로 폴백됨');
  }

  // 🎨 캘린더별 실제 색상 정보 - 공식 문서 기준 우선순위 적용
  Future<void> _fetchUserCalendarColors() async {
    try {
      print('🎨 사용자 캘린더 색상 정보 가져오기 시작');
      
      final calendarList = await _calendarApi!.calendarList.list();
      
      if (calendarList.items != null) {
        for (var calendar in calendarList.items!) {
          if (calendar.id != null) {
            Color calendarColor;
            
            // 🎯 공식 문서 기준 우선순위:
            // 1. backgroundColor (직접 hex 색상)
            if (calendar.backgroundColor != null) {
              try {
                final hexColor = calendar.backgroundColor!;
                final colorValue = int.parse(hexColor.substring(1), radix: 16);
                calendarColor = Color(0xFF000000 | colorValue);
                print('🎨 캘린더 "${calendar.summary}" backgroundColor: $hexColor');
              } catch (e) {
                calendarColor = _getCalendarColorFromId(calendar.colorId);
                print('⚠️ backgroundColor 파싱 실패: ${calendar.backgroundColor}');
              }
            }
            // 2. colorId (공식 문서의 calendar 색상 팔레트 참조)
            else if (calendar.colorId != null) {
              calendarColor = _getCalendarColorFromId(calendar.colorId);
              print('🎨 캘린더 "${calendar.summary}" colorId: ${calendar.colorId}');
            }
            // 3. 기본 색상
            else {
              calendarColor = const Color(0xFF1976D2);
              print('🎨 캘린더 "${calendar.summary}" 기본 색상 사용');
            }
            
            _userCalendarColors[calendar.id!] = calendarColor;
          }
        }
      }
      
      print('✅ ${_userCalendarColors.length}개 캘린더의 색상 정보 로드 완료');
    } catch (e) {
      print('❌ 사용자 캘린더 색상 가져오기 오류: $e');
    }
  }

  // 🎨 CalendarList API 기반 - 모든 캘린더의 이벤트와 색상 완전 처리
  Future<List<Event>> getEventsFromGoogleCalendar({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    if (!_isInitialized || _calendarApi == null) {
      throw Exception('Google Calendar 서비스가 초기화되지 않았습니다.');
    }

    try {
      final DateTime start = startDate ?? DateTime.now().subtract(const Duration(days: 30));
      final DateTime end = endDate ?? DateTime.now().add(const Duration(days: 30));

      print('🔍 구글 캘린더 이벤트 조회 시작');

      // 1. 🎨 CalendarList API로 모든 캘린더와 색상 정보 가져오기
      final calendarList = await _calendarApi!.calendarList.list();
      Map<String, Color> calendarColors = {};
      Map<String, String> calendarNames = {};
      
      // 🔥 한국 공휴일 캘린더 ID (중복 방지용)
      const String koreanHolidayCalendarId = 'ko.south_korea#holiday@group.v.calendar.google.com';
      
      if (calendarList.items != null) {
        print('📋 발견된 캘린더 수: ${calendarList.items!.length}');
        
        for (var calendar in calendarList.items!) {
          if (calendar.id != null) {
            // 🔥 한국 공휴일 캘린더는 getKoreanHolidays에서 별도 처리하므로 제외
            if (calendar.id == koreanHolidayCalendarId) {
              print('⚠️ 한국 공휴일 캘린더는 별도 처리를 위해 제외: ${calendar.summary}');
              continue;
            }
            
            Color calendarColor;
            
            // 🎯 CalendarList API 문서 기준 우선순위:
            // 1. backgroundColor (16진수 "#0088aa" 형식 - colorId를 대체함)
            if (calendar.backgroundColor != null) {
              try {
                final hexColor = calendar.backgroundColor!;
                final colorValue = int.parse(hexColor.substring(1), radix: 16);
                calendarColor = Color(0xFF000000 | colorValue);
                print('🎨 캘린더 "${calendar.summary}" backgroundColor: $hexColor');
              } catch (e) {
                calendarColor = _getCalendarColorFromId(calendar.colorId);
                print('⚠️ backgroundColor 파싱 실패: ${calendar.backgroundColor}');
              }
            }
            // 2. colorId (Colors API의 calendar 팔레트 참조)
            else if (calendar.colorId != null) {
              calendarColor = _getCalendarColorFromId(calendar.colorId);
              print('🎨 캘린더 "${calendar.summary}" colorId: ${calendar.colorId}');
            }
            // 3. 기본 색상
            else {
              calendarColor = const Color(0xFF1976D2);
              print('🎨 캘린더 "${calendar.summary}" 기본 색상 사용');
            }
            
            calendarColors[calendar.id!] = calendarColor;
            calendarNames[calendar.id!] = calendar.summary ?? 'Unknown Calendar';
          }
        }
      }

      // 2. 🎨 일반 캘린더에서만 이벤트 가져오기 (공휴일 캘린더 제외)
      List<Event> appEvents = [];
      
      for (var calendarId in calendarColors.keys) {
        try {
          print('📅 캘린더 "${calendarNames[calendarId]}" ($calendarId)에서 이벤트 조회 중...');

      final events = await _calendarApi!.events.list(
            calendarId,
        timeMin: start.toUtc(),
        timeMax: end.toUtc(),
        singleEvents: true,
        orderBy: 'startTime',
            maxResults: 2500,
      );

          if (events.items != null) {
            print('   📋 ${events.items!.length}개 이벤트 발견');
      
        for (var googleEvent in events.items!) {
          if (googleEvent.summary != null) {
            DateTime eventDate;
            String eventTime = '';

            // 날짜/시간 처리
            if (googleEvent.start?.dateTime != null) {
              eventDate = googleEvent.start!.dateTime!.toLocal();
              eventTime = DateFormat('HH:mm').format(eventDate);
            } else if (googleEvent.start?.date != null) {
              eventDate = googleEvent.start!.date!;
              eventTime = '종일';
            } else {
                  continue;
                }

                // 🎯 CalendarList API 문서 기준 색상 결정:
                Color eventColor;
                String? finalColorId = googleEvent.colorId;
                
                if (finalColorId != null) {
                  // 1️⃣ 개별 이벤트에 색상이 지정된 경우 (드물음)
                  eventColor = _getEventColorFromId(finalColorId);
                  print('🎨 개별 이벤트 색상: "${googleEvent.summary}" -> event colorId: $finalColorId');
                } else {
                  // 2️⃣ 캘린더의 backgroundColor/colorId 사용 (일반적인 경우)
                  eventColor = calendarColors[calendarId] ?? const Color(0xFF1976D2);
                  print('🎨 캘린더 색상: "${googleEvent.summary}" -> ${calendarNames[calendarId]} -> $eventColor');
            }

            final appEvent = Event(
              title: googleEvent.summary!,
              time: eventTime,
              date: eventDate,
              description: googleEvent.description ?? '',
                  colorId: finalColorId,
                  color: eventColor,
            );

            appEvents.add(appEvent);
          }
        }
      }
        } catch (e) {
          print('⚠️ 캘린더 "$calendarId" 이벤트 조회 오류: $e');
          // 개별 캘린더 오류는 계속 진행
        }
      }

      // 날짜순 정렬
      appEvents.sort((a, b) => a.date.compareTo(b.date));
      
      print('✅ 총 ${calendarColors.length}개 일반 캘린더에서 ${appEvents.length}개의 이벤트를 가져왔습니다');
      return appEvents;
      
    } catch (e) {
      print('Google Calendar 이벤트 가져오기 오류: $e');
      throw Exception('Google Calendar 이벤트를 가져오는데 실패했습니다: $e');
    }
  }

  // 🎨 이벤트 색상 ID → Color 변환 (공식 문서의 event 팔레트 사용)
  static Color _getEventColorFromId(String? colorId) {
    if (colorId == null) return const Color(0xFF1976D2);
    
    final color = _eventColors[colorId];
    if (color != null) {
      final hexColor = _eventColorHex[colorId];
      print('🎨 이벤트 색상 매핑: colorId "$colorId" -> $hexColor -> $color');
      return color;
    } else {
      print('⚠️ 알 수 없는 이벤트 colorId "$colorId"');
      return const Color(0xFF1976D2);
    }
  }

  // 🎨 캘린더 색상 ID → Color 변환 (공식 문서의 calendar 팔레트 사용)
  static Color _getCalendarColorFromId(String? colorId) {
    if (colorId == null) return const Color(0xFF1976D2);
    
    final color = _calendarColors[colorId];
    if (color != null) {
      final hexColor = _calendarColorHex[colorId];
      print('🎨 캘린더 색상 매핑: colorId "$colorId" -> $hexColor -> $color');
      return color;
    } else {
      print('⚠️ 알 수 없는 캘린더 colorId "$colorId"');
      return const Color(0xFF1976D2);
    }
  }

  // 🎨 CalendarList 디버깅 - 모든 캘린더 색상 정보 표시
  Future<void> debugCalendarListColors() async {
    if (!_isInitialized || _calendarApi == null) {
      print('❌ Google Calendar 서비스가 초기화되지 않았습니다.');
      return;
    }

    try {
      print('🔍 CalendarList API 색상 정보 분석 시작');
      
      final calendarList = await _calendarApi!.calendarList.list();
      
      if (calendarList.items != null) {
        print('\n📋 사용자의 모든 캘린더 색상 정보:');
        
        for (var calendar in calendarList.items!) {
          print('\n🎨 캘린더: "${calendar.summary}"');
          print('   ID: ${calendar.id}');
          print('   backgroundColor: ${calendar.backgroundColor ?? "null"}');
          print('   colorId: ${calendar.colorId ?? "null"}');
          print('   foregroundColor: ${calendar.foregroundColor ?? "null"}');
          print('   primary: ${calendar.primary ?? false}');
          print('   selected: ${calendar.selected ?? false}');
          
          // 실제 적용될 색상 계산
          Color finalColor;
          if (calendar.backgroundColor != null) {
            try {
              final colorValue = int.parse(calendar.backgroundColor!.substring(1), radix: 16);
              finalColor = Color(0xFF000000 | colorValue);
              print('   → 최종 색상: backgroundColor 사용 -> $finalColor');
            } catch (e) {
              finalColor = _getCalendarColorFromId(calendar.colorId);
              print('   → 최종 색상: colorId 폴백 -> $finalColor');
            }
          } else if (calendar.colorId != null) {
            finalColor = _getCalendarColorFromId(calendar.colorId);
            print('   → 최종 색상: colorId 사용 -> $finalColor');
          } else {
            finalColor = const Color(0xFF1976D2);
            print('   → 최종 색상: 기본값 사용 -> $finalColor');
          }
        }
      }
    } catch (e) {
      print('❌ CalendarList 디버깅 오류: $e');
    }
  }

  // 사용 가능한 모든 색상 정보 가져오기
  static Map<String, Color> getAllGoogleColors() {
    return Map.from(_eventColors);
  }

  // 색상 ID별 이름 가져오기
  static String getColorName(String colorId) {
    const colorNames = {
      '1': '라벤더',
      '2': '세이지', 
      '3': '포도',
      '4': '플라밍고',
      '5': '바나나',
      '6': '귤',
      '7': '공작새',
      '8': '그래파이트',
      '9': '블루베리',
      '10': '바질',
      '11': '토마토',
    };
    return colorNames[colorId] ?? '알 수 없음';
  }

  // 앱의 이벤트를 Google Calendar에 추가 (색상 정보 포함)
  Future<bool> addEventToGoogleCalendar(Event event) async {
    if (!_isInitialized || _calendarApi == null) {
      throw Exception('Google Calendar 서비스가 초기화되지 않았습니다.');
    }

    try {
      DateTime startDateTime;
      DateTime endDateTime;

      if (event.time == '종일') {
        // 종일 이벤트
        startDateTime = DateTime(event.date.year, event.date.month, event.date.day);
        endDateTime = startDateTime.add(const Duration(days: 1));
      } else {
        // 시간이 지정된 이벤트
        final timeParts = event.time.split(':');
        if (timeParts.length == 2) {
          final hour = int.tryParse(timeParts[0]) ?? 0;
          final minute = int.tryParse(timeParts[1]) ?? 0;
          startDateTime = DateTime(
            event.date.year,
            event.date.month,
            event.date.day,
            hour,
            minute,
          );
          endDateTime = startDateTime.add(const Duration(hours: 1)); // 기본 1시간 이벤트
        } else {
          startDateTime = event.date;
          endDateTime = startDateTime.add(const Duration(hours: 1));
        }
      }

      final googleEvent = calendar.Event()
        ..summary = event.title
        ..description = event.description
        ..start = (event.time == '종일')
            ? calendar.EventDateTime(date: startDateTime)
            : calendar.EventDateTime(dateTime: startDateTime.toUtc())
        ..end = (event.time == '종일')
            ? calendar.EventDateTime(date: endDateTime)
            : calendar.EventDateTime(dateTime: endDateTime.toUtc());

      // 색상 정보가 있으면 추가
      if (event.colorId != null) {
        googleEvent.colorId = event.colorId;
      }

      await _calendarApi!.events.insert(googleEvent, 'primary');
      print('이벤트가 Google Calendar에 추가되었습니다: ${event.title}');
      return true;
    } catch (e) {
      print('Google Calendar 이벤트 추가 오류: $e');
      return false;
    }
  }

  // Google Calendar에서 이벤트 삭제
  Future<bool> deleteEventFromGoogleCalendar(Event event) async {
    if (!_isInitialized || _calendarApi == null) {
      throw Exception('Google Calendar 서비스가 초기화되지 않았습니다.');
    }

    try {
      // 먼저 해당 이벤트를 Google Calendar에서 찾기
      final DateTime startDate = DateTime(event.date.year, event.date.month, event.date.day);
      final DateTime endDate = startDate.add(const Duration(days: 1));

      final events = await _calendarApi!.events.list(
        'primary',
        timeMin: startDate.toUtc(),
        timeMax: endDate.toUtc(),
        singleEvents: true,
        orderBy: 'startTime',
      );

      if (events.items != null) {
        for (var googleEvent in events.items!) {
          if (googleEvent.summary == event.title) {
            // 시간도 비교하여 정확한 이벤트인지 확인
            bool timeMatches = false;
            
            if (event.time == '종일') {
              timeMatches = googleEvent.start?.date != null;
            } else {
              if (googleEvent.start?.dateTime != null) {
                final eventDateTime = googleEvent.start!.dateTime!.toLocal();
                final eventTimeString = DateFormat('HH:mm').format(eventDateTime);
                timeMatches = eventTimeString == event.time;
              }
            }

            if (timeMatches && googleEvent.id != null) {
              await _calendarApi!.events.delete('primary', googleEvent.id!);
              print('이벤트가 Google Calendar에서 삭제되었습니다: ${event.title}');
              return true;
            }
          }
        }
      }

      print('Google Calendar에서 해당 이벤트를 찾을 수 없습니다: ${event.title}');
      return false;
    } catch (e) {
      print('Google Calendar 이벤트 삭제 오류: $e');
      return false;
    }
  }

  // Google Calendar에서 한국 공휴일 가져오기
  Future<List<Event>> getKoreanHolidays({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    if (!_isInitialized || _calendarApi == null) {
      // 초기화되지 않은 경우 초기화 시도
      final initialized = await initialize();
      if (!initialized) {
        print('Google Calendar 서비스 초기화 실패 - 공휴일을 가져올 수 없습니다.');
        return [];
      }
    }

    try {
      final DateTime start = startDate ?? DateTime.now().subtract(const Duration(days: 30));
      final DateTime end = endDate ?? DateTime.now().add(const Duration(days: 365));

      // 한국 공휴일 캘린더 ID
      const String koreanHolidayCalendarId = 'ko.south_korea#holiday@group.v.calendar.google.com';

      final events = await _calendarApi!.events.list(
        koreanHolidayCalendarId,
        timeMin: start.toUtc(),
        timeMax: end.toUtc(),
        singleEvents: true,
        orderBy: 'startTime',
      );

      List<Event> holidays = [];
      
      if (events.items != null) {
        for (var googleEvent in events.items!) {
          if (googleEvent.summary != null) {
            DateTime eventDate;

            // 공휴일은 보통 종일 이벤트
            if (googleEvent.start?.date != null) {
              eventDate = googleEvent.start!.date!;
            } else if (googleEvent.start?.dateTime != null) {
              eventDate = googleEvent.start!.dateTime!.toLocal();
            } else {
              continue; // 시작 날짜가 없는 이벤트는 건너뛰기
            }

            final holiday = Event(
              title: '🇰🇷 ${googleEvent.summary!}', // 한국 태극기로 변경
              time: '종일',
              date: eventDate,
              description: '한국 공휴일',
              colorId: 'holiday_red', // 공휴일 전용 colorId
              color: Colors.red,       // 🔥 빨간색 직접 설정
            );

            holidays.add(holiday);
          }
        }
      }

      print('한국 공휴일 ${holidays.length}개를 가져왔습니다.');
      return holidays;
    } catch (e) {
      print('한국 공휴일 가져오기 오류: $e');
      // 오류가 발생해도 빈 리스트 반환 (앱 사용에 지장 없도록)
      return [];
    }
  }

  // Google Calendar와 동기화
  Future<List<Event>> syncWithGoogleCalendar({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    if (!_isInitialized) {
      final initialized = await initialize();
      if (!initialized) {
        throw Exception('Google Calendar 인증에 실패했습니다.');
      }
    }

    return await getEventsFromGoogleCalendar(
      startDate: startDate,
      endDate: endDate,
    );
  }

  // Google Calendar와 동기화 (공휴일 포함)
  Future<List<Event>> syncWithGoogleCalendarIncludingHolidays({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      // 일반 이벤트 가져오기
      final regularEvents = await syncWithGoogleCalendar(
        startDate: startDate,
        endDate: endDate,
      );

      // 공휴일 가져오기
      final holidays = await getKoreanHolidays(
        startDate: startDate,
        endDate: endDate,
      );

      // 두 리스트 합치기
      final allEvents = [...regularEvents, ...holidays];
      
      print('총 ${allEvents.length}개의 이벤트를 가져왔습니다. (일반: ${regularEvents.length}, 공휴일: ${holidays.length})');
      return allEvents;
    } catch (e) {
      print('공휴일 포함 동기화 오류: $e');
      // 오류 발생 시 일반 이벤트만 반환
      return await syncWithGoogleCalendar(
        startDate: startDate,
        endDate: endDate,
      );
    }
  }

  // 로그아웃
  Future<void> signOut() async {
    await _googleSignIn.signOut();
    _calendarApi = null;
    _isInitialized = false;
    print('Google Calendar에서 로그아웃되었습니다.');
  }

  // 현재 로그인 상태 확인
  bool get isSignedIn => _googleSignIn.currentUser != null && _isInitialized;

  // 현재 사용자 정보
  GoogleSignInAccount? get currentUser => _googleSignIn.currentUser;

  // 이미 로그인된 사용자가 있는지 확인
  bool get hasSignedInUser => _googleSignIn.currentUser != null;

  // 🔥 자동 초기화 및 동기화를 위한 새로운 메서드
  Future<bool> initializeIfSignedIn() async {
    try {
      // 이미 로그인된 사용자가 있는지 확인
      final currentUser = _googleSignIn.currentUser;
      if (currentUser != null) {
        print('🔄 이미 로그인된 사용자 발견: ${currentUser.email}');
        
        // 이미 초기화되어 있으면 바로 성공 반환
        if (_isInitialized && _calendarApi != null) {
          print('✅ Google Calendar 서비스 이미 초기화됨');
          return true;
        }
        
        // 초기화되지 않았으면 다시 초기화
        try {
          final httpClient = await _googleSignIn.authenticatedClient();
          if (httpClient != null) {
            _calendarApi = calendar.CalendarApi(httpClient);
            _isInitialized = true;
            
            // 색상 정보 로드
            await fetchColorsFromAPI();
            
            print('✅ 기존 로그인으로 Google Calendar 서비스 초기화 완료');
            return true;
          }
        } catch (e) {
          print('⚠️ 기존 로그인으로 초기화 실패: $e');
        }
      }
      
      print('ℹ️ 로그인된 사용자 없음 - Google Calendar 초기화 건너뜀');
      return false;
    } catch (e) {
      print('❌ Google Calendar 자동 초기화 오류: $e');
      return false;
    }
  }

  // 🔥 조용한 재연결 (오류가 발생해도 계속 진행)
  Future<bool> silentReconnect() async {
    try {
      // 현재 사용자가 있고 인증된 클라이언트를 가져올 수 있는지 확인
      if (_googleSignIn.currentUser != null) {
        final httpClient = await _googleSignIn.authenticatedClient();
        if (httpClient != null) {
          _calendarApi = calendar.CalendarApi(httpClient);
          _isInitialized = true;
          print('🔄 Google Calendar 조용한 재연결 성공');
          return true;
        }
      }
      return false;
    } catch (e) {
      print('⚠️ Google Calendar 조용한 재연결 실패: $e');
      return false;
    }
  }
} 