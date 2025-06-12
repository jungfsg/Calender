import '../models/event.dart';
import '../controllers/calendar_controller.dart';
import '../services/event_storage_service.dart';
import '../services/google_calendar_service.dart';
import 'event_manager.dart';
import 'package:flutter/material.dart';

/// 로컬 저장소와 Google 캘린더 간의 동기화를 전담하는 매니저
class SyncManager {
  final EventManager _eventManager;
  final CalendarController _controller;
  final GoogleCalendarService _googleCalendarService = GoogleCalendarService();

  SyncManager(this._eventManager, this._controller);

  /// 이벤트 추가 시 동기화 (로컬 → 구글)
  Future<void> syncEventAddition(Event event) async {
    try {
      print('🔄 SyncManager: 이벤트 추가 동기화 시작...');
      print('🔄 이벤트 정보: ${event.title}, 멀티데이: ${event.isMultiDay}');

      // 구글 캘린더가 연결되어 있는지 확인
      if (!await _googleCalendarService.silentReconnect()) {
        print('⚠️ Google Calendar 연결되지 않음, 로컬에만 저장');
        return;
      }

      // 이미 구글 캘린더에 있는 이벤트인지 확인 (중복 방지)
      if (event.source == 'google' || event.source == 'holiday') {
        print('🔍 구글 소스 이벤트는 동기화 불필요');
        return;
      }

      // 멀티데이 이벤트인 경우 특별 처리
      if (event.isMultiDay && event.startDate != null && event.endDate != null) {
        await _syncMultiDayEventToGoogle(event);
        return;
      }

      // 구글 캘린더에 추가
      final googleEventId = await _googleCalendarService.addEventToGoogleCalendar(
        event,
      );
      if (googleEventId != null) {
        print('✅ 구글 캘린더에 이벤트 동기화 성공: ${event.title}');

        // 로컬 이벤트에 Google Event ID 저장
        try {
          // 1. 기존 이벤트 삭제
          await EventStorageService.removeEvent(event.date, event);

          // 2. Google Event ID가 추가된 이벤트 생성
          final updatedEventWithId = Event(
            title: event.title,
            time: event.time,
            date: event.date,
            description: event.description,
            source: event.source,
            colorId: event.colorId,
            color: event.color,
            uniqueId: event.uniqueId,
            endTime: event.endTime,
            googleEventId: googleEventId, // Google Event ID 저장
          );

          // 3. 업데이트된 이벤트 저장
          await EventStorageService.addEvent(event.date, updatedEventWithId);

          // 4. 컨트롤러에도 업데이트
          _controller.removeEvent(event);
          _controller.addEvent(updatedEventWithId);

          print('🔗 Google Event ID 저장 완료: ${event.title} -> $googleEventId');
        } catch (e) {
          print('⚠️ Google Event ID 저장 중 오류: $e');
        }

        // 🔥 Google Calendar API에서 설정한 색상 정보가 로컬에도 반영되도록 이벤트 업데이트
        try {
          // 이벤트에 colorId가 없을 경우, 동일한 날짜에 동일한 제목의 Google 이벤트를 찾아서 색상 정보를 가져옴
          final googleEvents = await _googleCalendarService
              .getEventsFromGoogleCalendar(
                startDate: event.date,
                endDate: event.date.add(const Duration(days: 1)),
              );

          final matchingEvent = googleEvents.firstWhere(
            (e) =>
                e.title == event.title &&
                e.date.year == event.date.year &&
                e.date.month == event.date.month &&
                e.date.day == event.date.day &&
                e.time == event.time,
            orElse: () => event,
          );

          // Google에서 할당한 colorId가 있으면 이를 로컬 이벤트에 반영
          if (matchingEvent.colorId != null &&
              (event.colorId == null ||
                  matchingEvent.colorId != event.colorId)) {
            print(
              '🎨 Google Calendar에서 색상 정보 동기화: colorId=${matchingEvent.colorId}',
            );

            // 1. 기존 이벤트 삭제
            await EventStorageService.removeEvent(event.date, event);

            // 2. 색상 정보가 업데이트된 이벤트 생성
            final updatedEvent = Event(
              title: event.title,
              time: event.time,
              date: event.date,
              description: event.description,
              source: event.source,
              colorId: matchingEvent.colorId,
              color: matchingEvent.color,
              uniqueId: event.uniqueId,
              endTime: event.endTime,
            );

            // 3. 업데이트된 이벤트 저장
            await EventStorageService.addEvent(event.date, updatedEvent);

            // 4. 컨트롤러에도 업데이트
            _controller.removeEvent(event);
            _controller.addEvent(updatedEvent);

            // 5. 색상 ID에 해당하는 색상 매핑 설정
            if (updatedEvent.colorId != null) {
              final colorId = int.tryParse(updatedEvent.colorId!);
              if (colorId != null && colorId >= 1 && colorId <= 11) {
                final color = updatedEvent.getDisplayColor();
                _controller.setEventIdColor(updatedEvent.uniqueId, color);
                print(
                  '🎨 이벤트 색상 매핑 완료: ${updatedEvent.title} -> ${updatedEvent.colorId} -> $color',
                );
              }
            }
          }
        } catch (e) {
          print('⚠️ 색상 동기화 중 오류: $e');
        }
      } else {
        print('❌ 구글 캘린더 동기화 실패: ${event.title}');
      }
    } catch (e) {
      print('❌ 이벤트 추가 동기화 오류: $e');
    }
  }

  /// 이벤트 수정 시 동기화 (로컬 → 구글)
  Future<void> syncEventUpdate(Event originalEvent, Event updatedEvent) async {
    try {
      print('🔄 SyncManager: 이벤트 수정 동기화 시작...');
      print('   원본: ${originalEvent.title} (${originalEvent.time})');
      print('   수정: ${updatedEvent.title} (${updatedEvent.time})');

      // 구글 캘린더가 연결되어 있는지 확인
      if (!await _googleCalendarService.silentReconnect()) {
        print('⚠️ Google Calendar 연결되지 않음, 로컬에만 수정됨');
        return;
      }

      // 공휴일 이벤트는 수정하지 않음
      if (originalEvent.source == 'holiday') {
        print('🔍 공휴일 이벤트는 Google Calendar 수정 불가');
        return;
      }

      // Google Calendar에서 이벤트 업데이트
      final success = await _googleCalendarService.updateEventOnGoogleCalendar(
        originalEvent,
        updatedEvent,
      );

      if (success) {
        print('✅ Google Calendar 이벤트 수정 동기화 성공: ${updatedEvent.title}');
      } else {
        print('❌ Google Calendar 이벤트 수정 동기화 실패: ${originalEvent.title}');
        // 실패한 경우 로컬에서만 수정된 상태 유지
      }
    } catch (e) {
      print('❌ 이벤트 수정 동기화 오류: $e');
    }
  }

  /// 🆕 멀티데이 이벤트를 Google Calendar에 동기화
  Future<void> _syncMultiDayEventToGoogle(Event event) async {
    try {
      print('📅 SyncManager: 멀티데이 이벤트 Google 동기화 시작...');
      print('📅 기간: ${event.startDate} ~ ${event.endDate}');

      // Google Calendar에 멀티데이 이벤트로 추가
      final googleEventId = await _googleCalendarService.addEventToGoogleCalendar(event);
      
      if (googleEventId != null) {
        print('✅ Google Calendar에 멀티데이 이벤트 동기화 성공: ${event.title}');
        
        // 모든 관련 날짜의 로컬 이벤트에 Google Event ID 저장
        final startDate = event.startDate!;
        final endDate = event.endDate!;
        
        for (int i = 0; i <= endDate.difference(startDate).inDays; i++) {
          final currentDate = startDate.add(Duration(days: i));
          
          try {
            // 해당 날짜의 멀티데이 이벤트들 찾기
            final existingEvents = await EventStorageService.getEvents(currentDate);
            final multiDayEvents = existingEvents.where((e) => 
              e.isMultiDay && 
              e.title == event.title &&
              e.startDate != null && e.endDate != null &&
              e.startDate!.isAtSameMomentAs(startDate) &&
              e.endDate!.isAtSameMomentAs(endDate)
            ).toList();
            
            for (final multiDayEvent in multiDayEvents) {
              // 기존 이벤트 삭제
              await EventStorageService.removeEvent(currentDate, multiDayEvent);
              
              // Google Event ID가 추가된 이벤트 생성
              final updatedEvent = multiDayEvent.copyWith(
                googleEventId: googleEventId,
              );
              
              // 업데이트된 이벤트 저장
              await EventStorageService.addEvent(currentDate, updatedEvent);
              
              // 컨트롤러에도 업데이트
              _controller.removeEvent(multiDayEvent);
              _controller.addEvent(updatedEvent);
            }
            
            print('🔗 ${currentDate.toString().substring(0, 10)} 날짜의 Google Event ID 저장 완료');
          } catch (e) {
            print('⚠️ ${currentDate.toString().substring(0, 10)} 날짜의 Google Event ID 저장 중 오류: $e');
          }
        }
      } else {
        print('❌ Google Calendar 멀티데이 이벤트 동기화 실패: ${event.title}');
      }
    } catch (e) {
      print('❌ 멀티데이 이벤트 Google 동기화 오류: $e');
    }
  }

  /// 이벤트 삭제 시 동기화 (로컬 → 구글)
  Future<void> syncEventDeletion(Event event) async {
    try {
      print('🔄 SyncManager: 이벤트 삭제 동기화 시작...');
      print('🔄 삭제 대상: ${event.title}, 멀티데이: ${event.isMultiDay}');

      // 구글 캘린더 연결 확인
      if (!await _googleCalendarService.silentReconnect()) {
        print('⚠️ Google Calendar 연결되지 않음, 로컬에서만 삭제됨');
        return;
      }

      // 멀티데이 이벤트인 경우 특별 처리
      if (event.isMultiDay && event.startDate != null && event.endDate != null) {
        await _syncMultiDayEventDeletionToGoogle(event);
        return;
      }

      if (event.source == 'google' || event.source == 'holiday') {
        // 구글/공휴일 소스 이벤트인 경우에만 구글에서도 삭제
        final deleted = await _googleCalendarService
            .deleteEventFromGoogleCalendar(event);
        print('🗑️ 구글 소스 이벤트 삭제 ${deleted ? '성공' : '실패'}: ${event.title}');
      } else {
        // 로컬 이벤트도 구글 캘린더에서 삭제해야 함
        final deleted = await _googleCalendarService
            .deleteEventFromGoogleCalendar(event);
        if (deleted) {
          print('✅ 구글 캘린더에서 로컬 이벤트 삭제 성공: ${event.title}');
        } else {
          print('⚠️ 구글 캘린더에서 로컬 이벤트 찾지 못함: ${event.title}');
        }
      }
    } catch (e) {
      print('❌ 이벤트 삭제 동기화 오류: $e');
    }
  }

  /// 🆕 멀티데이 이벤트 삭제를 Google Calendar에 동기화
  Future<void> _syncMultiDayEventDeletionToGoogle(Event event) async {
    try {
      print('🗑️ SyncManager: 멀티데이 이벤트 Google 삭제 동기화 시작...');
      print('🗑️ 삭제 대상: ${event.title} (${event.startDate} ~ ${event.endDate})');

      // Google Calendar에서 멀티데이 이벤트 삭제
      final deleted = await _googleCalendarService.deleteEventFromGoogleCalendar(event);
      
      if (deleted) {
        print('✅ Google Calendar에서 멀티데이 이벤트 삭제 성공: ${event.title}');
      } else {
        print('⚠️ Google Calendar에서 멀티데이 이벤트 찾지 못함: ${event.title}');
      }
    } catch (e) {
      print('❌ 멀티데이 이벤트 Google 삭제 동기화 오류: $e');
    }
  }

  /// 구글 캘린더와 로컬 상태 완전 동기화 (양방향)
  Future<void> performFullSync() async {
    try {
      print('🔄 전체 동기화 시작...');

      // 1. 먼저 로컬 이벤트를 구글로 업로드
      await _eventManager.uploadToGoogleCalendar();

      // 2. 구글 이벤트 가져와서 로컬과 병합
      await _eventManager.syncWithGoogleCalendar();

      // 3. 색상 정보 동기화
      await _googleCalendarService.syncColorMappingsToController(_controller);

      // 4. 현재 월 데이터 강제 새로고침
      await _eventManager.refreshCurrentMonthEvents(forceRefresh: true);

      print('✅ 전체 동기화 완료');
    } catch (e) {
      print('❌ 전체 동기화 오류: $e');
    }
  }
}
