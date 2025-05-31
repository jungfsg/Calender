# from typing import Optional, List, Dict, Any
# from googleapiclient.discovery import build
# from google.oauth2.credentials import Credentials
# from google.oauth2 import service_account
# from google.auth.transport.requests import Request
# from google_auth_oauthlib.flow import InstalledAppFlow
# from datetime import datetime, timedelta, timezone
# import json
# import os
# from app.core.config import get_settings

# settings = get_settings()

# class GoogleCalendarService:
#     SCOPES = ['https://www.googleapis.com/auth/calendar']
    
#     def __init__(self):
#         self.service = None
#         self.credentials = None
#         self._initialize_service()
    
#     def _initialize_service(self):
#         """Google Calendar API 서비스를 초기화합니다."""
#         try:
#             # 1. 서비스 계정 방식 시도 (권장)
#             if self._try_service_account():
#                 return
            
#             # 2. OAuth 방식 시도 (기존 방식)
#             if self._try_oauth():
#                 returns
            
#             print("❌ Google Calendar 서비스 초기화에 실패했습니다. (google_calendar_service.py)")
#             print("서비스 계정 또는 OAuth 자격 증명을 확인해주세요.")
                
#         except Exception as e:
#             print(f"Google Calendar 서비스 초기화 중 예상치 못한 오류: {str(e)}")
#             self.service = None
    
#     def _try_service_account(self):
#         """서비스 계정 방식으로 인증을 시도합니다."""
#         try:
#             # 환경 변수에서 서비스 계정 JSON 로드
#             if hasattr(settings, 'GOOGLE_SERVICE_ACCOUNT_JSON') and settings.GOOGLE_SERVICE_ACCOUNT_JSON:
#                 try:
#                     service_account_info = json.loads(settings.GOOGLE_SERVICE_ACCOUNT_JSON)
#                     credentials = service_account.Credentials.from_service_account_info(
#                         service_account_info, scopes=self.SCOPES
#                     )
#                     self.credentials = credentials
#                     self.service = build('calendar', 'v3', credentials=credentials)
#                     print("✅ 서비스 계정(환경변수)으로 Google Calendar 서비스가 초기화되었습니다.")
#                     return True
#                 except json.JSONDecodeError as e:
#                     print(f"서비스 계정 JSON 파싱 오류: {str(e)}")
#                 except Exception as e:
#                     print(f"서비스 계정(환경변수) 인증 실패: {str(e)}")
            
#             # 서비스 계정 파일에서 로드
#             if hasattr(settings, 'GOOGLE_SERVICE_ACCOUNT_FILE') and settings.GOOGLE_SERVICE_ACCOUNT_FILE:
#                 if os.path.exists(settings.GOOGLE_SERVICE_ACCOUNT_FILE):
#                     try:
#                         credentials = service_account.Credentials.from_service_account_file(
#                             settings.GOOGLE_SERVICE_ACCOUNT_FILE, scopes=self.SCOPES
#                         )
#                         self.credentials = credentials
#                         self.service = build('calendar', 'v3', credentials=credentials)
#                         print("✅ 서비스 계정(파일)으로 Google Calendar 서비스가 초기화되었습니다.")
#                         return True
#                     except Exception as e:
#                         print(f"서비스 계정(파일) 인증 실패: {str(e)}")
#                 else:
#                     print(f"서비스 계정 파일을 찾을 수 없습니다: {settings.GOOGLE_SERVICE_ACCOUNT_FILE}")
            
#             return False
            
#         except Exception as e:
#             print(f"서비스 계정 인증 시도 중 오류: {str(e)}")
#             return False
    
#     def _try_oauth(self):
#         """OAuth 방식으로 인증을 시도합니다."""
#         try:
#             creds = None
#             # 토큰 파일이 있으면 로드
#             if os.path.exists('token.json'):
#                 try:
#                     creds = Credentials.from_authorized_user_file('token.json', self.SCOPES)
#                     print("기존 토큰 파일을 로드했습니다.")
#                 except Exception as e:
#                     print(f"토큰 파일 로드 실패: {str(e)}")
#                     # 토큰 파일이 손상된 경우 삭제
#                     os.remove('token.json')
            
#             # 유효한 자격 증명이 없으면 사용자 인증 플로우 실행
#             if not creds or not creds.valid:
#                 if creds and creds.expired and creds.refresh_token:
#                     try:
#                         creds.refresh(Request())
#                         print("토큰을 갱신했습니다.")
#                     except Exception as e:
#                         print(f"토큰 갱신 실패: {str(e)}")
#                         creds = None
                
#                 if not creds:
#                     if settings.GOOGLE_CALENDAR_CREDENTIALS:
#                         try:
#                             # 환경 변수에서 자격 증명 로드
#                             credentials_info = json.loads(settings.GOOGLE_CALENDAR_CREDENTIALS)
#                             print("환경 변수에서 Google Calendar 자격 증명을 로드했습니다.")
                            
#                             # redirect_uri 확인 및 수정
#                             if 'installed' in credentials_info:
#                                 redirect_uris = credentials_info['installed'].get('redirect_uris', [])
#                                 if 'http://localhost' not in redirect_uris:
#                                     credentials_info['installed']['redirect_uris'] = ['http://localhost']
#                                     print("redirect_uri를 http://localhost로 설정했습니다.")
                            
#                             flow = InstalledAppFlow.from_client_config(
#                                 credentials_info, self.SCOPES)
                            
#                             # 로컬 서버를 사용한 인증 (포트 자동 할당)
#                             try:
#                                 creds = flow.run_local_server(
#                                     port=0,  # 자동 포트 할당
#                                     access_type='offline',
#                                     include_granted_scopes='true'
#                                 )
#                                 print("OAuth 인증이 완료되었습니다.")
#                             except Exception as oauth_error:
#                                 print(f"로컬 서버 인증 실패: {str(oauth_error)}")
#                                 print("콘솔 인증을 시도합니다...")
                                
#                                 # 콘솔 기반 인증으로 대체
#                                 creds = flow.run_console()
#                                 print("콘솔 인증이 완료되었습니다.")
                            
#                         except json.JSONDecodeError as e:
#                             print(f"Google Calendar 자격 증명 JSON 파싱 오류: {str(e)}")
#                             print("GOOGLE_CALENDAR_CREDENTIALS 환경 변수의 JSON 형식을 확인해주세요.")
#                             return False
#                         except Exception as e:
#                             print(f"Google Calendar 인증 오류: {str(e)}")
#                             print("Google Cloud Console에서 OAuth 설정을 확인해주세요:")
#                             print("1. 승인된 리디렉션 URI에 http://localhost가 포함되어 있는지 확인")
#                             print("2. 애플리케이션 유형이 '데스크톱 애플리케이션'으로 설정되어 있는지 확인")
#                             print("3. Google Calendar API가 활성화되어 있는지 확인")
#                             return False
#                     else:
#                         print("GOOGLE_CALENDAR_CREDENTIALS 환경 변수가 설정되지 않았습니다.")
#                         print("Google Calendar API를 사용하려면 환경 변수를 설정해주세요.")
#                         return False
                
#                 # 토큰을 파일에 저장
#                 if creds:
#                     try:
#                         with open('token.json', 'w') as token:
#                             token.write(creds.to_json())
#                         print("토큰이 저장되었습니다.")
#                     except Exception as e:
#                         print(f"토큰 저장 실패: {str(e)}")
            
#             if creds:
#                 self.credentials = creds
#                 self.service = build('calendar', 'v3', credentials=creds)
#                 print("✅ OAuth로 Google Calendar 서비스가 성공적으로 초기화되었습니다.")
#                 return True
#             else:
#                 return False
                
#         except Exception as e:
#             print(f"OAuth 인증 시도 중 오류: {str(e)}")
#             return False
    
#     def create_event(self, event_data: Dict[str, Any]) -> Dict[str, Any]:
#         """새로운 일정을 생성합니다."""
#         try:
#             if not self.service:
#                 return {"error": "Google Calendar 서비스가 초기화되지 않았습니다."}
            
#             # 충돌 검사
#             conflicts = self.check_conflicts(
#                 event_data.get('start', {}),
#                 event_data.get('end', {})
#             )
            
#             if conflicts:
#                 return {
#                     "error": "일정 충돌이 발견되었습니다.",
#                     "conflicts": conflicts
#                 }
            
#             # 일정 생성
#             event = self.service.events().insert(
#                 calendarId='primary',
#                 body=event_data
#             ).execute()
            
#             return {
#                 "success": True,
#                 "event_id": event.get('id'),
#                 "event_link": event.get('htmlLink'),
#                 "message": "일정이 성공적으로 생성되었습니다."
#             }
            
#         except Exception as e:
#             return {"error": f"일정 생성 중 오류 발생: {str(e)}"}
    
#     def update_event(self, event_id: str, event_data: Dict[str, Any]) -> Dict[str, Any]:
#         """기존 일정을 수정합니다."""
#         try:
#             if not self.service:
#                 return {"error": "Google Calendar 서비스가 초기화되지 않았습니다."}
            
#             # 기존 일정 가져오기
#             existing_event = self.service.events().get(
#                 calendarId='primary',
#                 eventId=event_id
#             ).execute()
            
#             # 기존 데이터와 새 데이터 병합
#             existing_event.update(event_data)
            
#             # 일정 업데이트
#             updated_event = self.service.events().update(
#                 calendarId='primary',
#                 eventId=event_id,
#                 body=existing_event
#             ).execute()
            
#             return {
#                 "success": True,
#                 "event_id": updated_event.get('id'),
#                 "event_link": updated_event.get('htmlLink'),
#                 "message": "일정이 성공적으로 수정되었습니다."
#             }
            
#         except Exception as e:
#             return {"error": f"일정 수정 중 오류 발생: {str(e)}"}
    
#     def delete_event(self, event_id: str) -> Dict[str, Any]:
#         """일정을 삭제합니다."""
#         try:
#             if not self.service:
#                 return {"error": "Google Calendar 서비스가 초기화되지 않았습니다."}
            
#             self.service.events().delete(
#                 calendarId='primary',
#                 eventId=event_id
#             ).execute()
            
#             return {
#                 "success": True,
#                 "message": "일정이 성공적으로 삭제되었습니다."
#             }
            
#         except Exception as e:
#             return {"error": f"일정 삭제 중 오류 발생: {str(e)}"}
    
#     def search_events(self, query: str = None, time_min: str = None, time_max: str = None, max_results: int = 10) -> List[Dict[str, Any]]:
#         """일정을 검색합니다."""
#         try:
#             if not self.service:
#                 return []
            
#             # 기본 시간 범위 설정 (하루 전체)
#             if not time_min:
#                 # 오늘 자정부터
#                 time_min = datetime.now().replace(hour=0, minute=0, second=0, microsecond=0)
#             else:
#                 # 입력된 시간을 UTC로 변환
#                 try:
#                     dt = datetime.fromisoformat(time_min.replace('Z', '+00:00'))
#                     time_min = dt.astimezone(timezone.utc)
#                 except ValueError:
#                     print(f"잘못된 시간 형식: {time_min}")
#                     time_min = datetime.now().replace(hour=0, minute=0, second=0, microsecond=0)
            
#             if not time_max:
#                 # 다음날 자정까지
#                 time_max = time_min + timedelta(days=1)
#             else:
#                 # 입력된 시간을 UTC로 변환
#                 try:
#                     dt = datetime.fromisoformat(time_max.replace('Z', '+00:00'))
#                     time_max = dt.astimezone(timezone.utc)
#                 except ValueError:
#                     print(f"잘못된 시간 형식: {time_max}")
#                     time_max = time_min + timedelta(days=1)
            
#             print(f"검색 시간 범위: {time_min.strftime('%Y-%m-%dT%H:%M:%SZ')} ~ {time_max.strftime('%Y-%m-%dT%H:%M:%SZ')}")  # 디버깅용
            
#             events_result = self.service.events().list(
#                 calendarId='primary',
#                 timeMin=time_min.strftime('%Y-%m-%dT%H:%M:%SZ'),
#                 timeMax=time_max.strftime('%Y-%m-%dT%H:%M:%SZ'),
#                 maxResults=max_results,
#                 singleEvents=True,
#                 orderBy='startTime',
#                 q=query
#             ).execute()
            
#             events = events_result.get('items', [])
            
#             return [
#                 {
#                     "id": event.get('id'),
#                     "summary": event.get('summary', '제목 없음'),
#                     "start": event.get('start', {}),
#                     "end": event.get('end', {}),
#                     "description": event.get('description', ''),
#                     "location": event.get('location', ''),
#                     "attendees": event.get('attendees', []),
#                     "htmlLink": event.get('htmlLink', '')
#                 }
#                 for event in events
#             ]
            
#         except Exception as e:
#             print(f"일정 검색 중 오류 발생: {str(e)}")
#             return []
    
#     def check_conflicts(self, start_time: Dict[str, str], end_time: Dict[str, str]) -> List[Dict[str, Any]]:
#         """일정 충돌을 검사합니다."""
#         try:
#             if not self.service or not start_time.get('dateTime') or not end_time.get('dateTime'):
#                 return []
            
#             # 해당 시간대의 일정 검색
#             events = self.search_events(
#                 time_min=start_time['dateTime'],
#                 time_max=end_time['dateTime']
#             )
            
#             conflicts = []
#             for event in events:
#                 event_start = event.get('start', {}).get('dateTime')
#                 event_end = event.get('end', {}).get('dateTime')
                
#                 if event_start and event_end:
#                     # 시간 겹침 검사
#                     if (start_time['dateTime'] < event_end and end_time['dateTime'] > event_start):
#                         conflicts.append({
#                             "id": event.get('id'),
#                             "summary": event.get('summary'),
#                             "start": event_start,
#                             "end": event_end
#                         })
            
#             return conflicts
            
#         except Exception as e:
#             print(f"충돌 검사 중 오류 발생: {str(e)}")
#             return []
    
#     def copy_event(self, event_id: str, destination_calendar_id: str = 'primary') -> Dict[str, Any]:
#         """일정을 복사합니다."""
#         try:
#             if not self.service:
#                 return {"error": "Google Calendar 서비스가 초기화되지 않았습니다."}
            
#             copied_event = self.service.events().copy(
#                 calendarId='primary',
#                 eventId=event_id,
#                 destination=destination_calendar_id
#             ).execute()
            
#             return {
#                 "success": True,
#                 "event_id": copied_event.get('id'),
#                 "message": "일정이 성공적으로 복사되었습니다."
#             }
            
#         except Exception as e:
#             return {"error": f"일정 복사 중 오류 발생: {str(e)}"}
    
#     def move_event(self, event_id: str, destination_calendar_id: str) -> Dict[str, Any]:
#         """일정을 다른 캘린더로 이동합니다."""
#         try:
#             if not self.service:
#                 return {"error": "Google Calendar 서비스가 초기화되지 않았습니다."}
            
#             moved_event = self.service.events().move(
#                 calendarId='primary',
#                 eventId=event_id,
#                 destination=destination_calendar_id
#             ).execute()
            
#             return {
#                 "success": True,
#                 "event_id": moved_event.get('id'),
#                 "message": "일정이 성공적으로 이동되었습니다."
#             }
            
#         except Exception as e:
#             return {"error": f"일정 이동 중 오류 발생: {str(e)}"}
    
#     def create_rrule(self, repeat_type: str, interval: int = 1, count: int = None, until: str = None) -> str:
#         """반복 일정을 위한 RRULE을 생성합니다."""
#         freq_map = {
#             "daily": "DAILY",
#             "weekly": "WEEKLY", 
#             "monthly": "MONTHLY",
#             "yearly": "YEARLY"
#         }
        
#         freq = freq_map.get(repeat_type.lower(), "WEEKLY")
#         rrule = f"FREQ={freq}"
        
#         if interval > 1:
#             rrule += f";INTERVAL={interval}"
        
#         if count:
#             rrule += f";COUNT={count}"
#         elif until:
#             rrule += f";UNTIL={until}"
        
#         return rrule 