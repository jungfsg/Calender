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

      // 구글 캘린더에 추가
      final success = await _googleCalendarService.addEventToGoogleCalendar(
        event,
      );
      if (success) {
        print('✅ 구글 캘린더에 이벤트 동기화 성공: ${event.title}');
      } else {
        print('❌ 구글 캘린더 동기화 실패: ${event.title}');
      }
    } catch (e) {
      print('❌ 이벤트 추가 동기화 오류: $e');
    }
  }

  /// 이벤트 삭제 시 동기화 (로컬 → 구글)
  Future<void> syncEventDeletion(Event event) async {
    try {
      print('🔄 SyncManager: 이벤트 삭제 동기화 시작...');

      if (event.source == 'google' || event.source == 'holiday') {
        // 구글/공휴일 소스 이벤트인 경우에만 구글에서도 삭제
        if (await _googleCalendarService.silentReconnect()) {
          final deleted = await _googleCalendarService
              .deleteEventFromGoogleCalendar(event);
          print('🗑️ 구글 소스 이벤트 삭제 ${deleted ? '성공' : '실패'}: ${event.title}');
        }
      } else {
        // 로컬 이벤트도 구글 캘린더에서 삭제해야 함
        if (await _googleCalendarService.silentReconnect()) {
          final deleted = await _googleCalendarService
              .deleteEventFromGoogleCalendar(event);
          if (deleted) {
            print('✅ 구글 캘린더에서 로컬 이벤트 삭제 성공: ${event.title}');
          } else {
            print('⚠️ 구글 캘린더에서 로컬 이벤트 찾지 못함: ${event.title}');
          }
        } else {
          print('⚠️ Google Calendar 연결되지 않음, 구글 삭제 건너뜀');
        }
      }
    } catch (e) {
      print('❌ 이벤트 삭제 동기화 오류: $e');
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
