import 'package:googleapis/calendar/v3.dart' as calendar;
import 'package:googleapis_auth/auth_io.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import '../models/event.dart';
import 'package:intl/intl.dart';

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
      print('Google Calendar 서비스가 초기화되었습니다.');
      return true;
    } catch (e) {
      print('Google Calendar 초기화 오류: $e');
      return false;
    }
  }

  // Google Calendar에서 이벤트 가져오기
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

      final events = await _calendarApi!.events.list(
        'primary',
        timeMin: start.toUtc(),
        timeMax: end.toUtc(),
        singleEvents: true,
        orderBy: 'startTime',
      );

      List<Event> appEvents = [];
      
      if (events.items != null) {
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
              continue; // 시작 시간이 없는 이벤트는 건너뛰기
            }

            final appEvent = Event(
              title: googleEvent.summary!,
              time: eventTime,
              date: eventDate,
              description: googleEvent.description ?? '',
            );

            appEvents.add(appEvent);
          }
        }
      }

      print('Google Calendar에서 ${appEvents.length}개의 이벤트를 가져왔습니다.');
      return appEvents;
    } catch (e) {
      print('Google Calendar 이벤트 가져오기 오류: $e');
      throw Exception('Google Calendar 이벤트를 가져오는데 실패했습니다: $e');
    }
  }

  // 앱의 이벤트를 Google Calendar에 추가
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
} 