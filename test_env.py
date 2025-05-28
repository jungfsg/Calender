#!/usr/bin/env python3
"""
환경 설정 테스트 및 OAuth 문제 진단 스크립트
"""

import os
import json
from app.core.config import get_settings
from app.services.google_calendar_service import GoogleCalendarService

def test_environment():
    """환경 설정을 테스트합니다."""
    print("=== 환경 설정 테스트 ===")
    print()
    
    settings = get_settings()
    
    # 1. OpenAI API 키 확인
    print("1. OpenAI API 키:")
    if settings.OPENAI_API_KEY:
        print(f"   ✅ 설정됨 (길이: {len(settings.OPENAI_API_KEY)})")
    else:
        print("   ❌ 설정되지 않음")
    print()
    
    # 2. Google Calendar 자격 증명 확인
    print("2. Google Calendar 자격 증명:")
    if settings.GOOGLE_CALENDAR_CREDENTIALS:
        try:
            creds = json.loads(settings.GOOGLE_CALENDAR_CREDENTIALS)
            print(f"   ✅ JSON 형식 유효")
            
            # OAuth 설정 타입 확인
            if 'installed' in creds:
                print("   📱 타입: 데스크톱 애플리케이션 (installed)")
                client_info = creds['installed']
                
                # 필수 필드 확인
                required_fields = ['client_id', 'client_secret', 'auth_uri', 'token_uri']
                for field in required_fields:
                    if field in client_info:
                        print(f"   ✅ {field}: 설정됨")
                    else:
                        print(f"   ❌ {field}: 누락")
                
                # redirect_uris 확인
                redirect_uris = client_info.get('redirect_uris', [])
                print(f"   📍 redirect_uris: {redirect_uris}")
                
                if not redirect_uris:
                    print("   ❌ redirect_uris가 비어있습니다!")
                elif 'http://localhost' not in str(redirect_uris):
                    print("   ⚠️  redirect_uris에 http://localhost가 없습니다.")
                    print("      Google Cloud Console에서 승인된 리디렉션 URI에 다음을 추가하세요:")
                    print("      - http://localhost")
                    print("      - http://localhost:8080")
                    print("      - http://localhost:8000")
                
            elif 'web' in creds:
                print("   🌐 타입: 웹 애플리케이션 (web)")
                print("   ⚠️  데스크톱 앱에서는 'installed' 타입을 사용해야 합니다.")
                
            elif 'type' in creds and creds['type'] == 'service_account':
                print("   🔧 타입: 서비스 계정")
                print("   ✅ 서비스 계정은 OAuth 인증이 필요하지 않습니다.")
                
            else:
                print("   ❌ 알 수 없는 자격 증명 타입")
                
        except json.JSONDecodeError as e:
            print(f"   ❌ JSON 파싱 오류: {str(e)}")
            print("   자격 증명 JSON 형식을 확인해주세요.")
    else:
        print("   ❌ 설정되지 않음")
    print()
    
    # 3. 서비스 계정 설정 확인
    print("3. 서비스 계정 설정:")
    if hasattr(settings, 'GOOGLE_SERVICE_ACCOUNT_JSON') and settings.GOOGLE_SERVICE_ACCOUNT_JSON:
        try:
            service_account = json.loads(settings.GOOGLE_SERVICE_ACCOUNT_JSON)
            print("   ✅ 서비스 계정 JSON 설정됨")
            print(f"   📧 이메일: {service_account.get('client_email', 'N/A')}")
            print(f"   🆔 프로젝트: {service_account.get('project_id', 'N/A')}")
        except:
            print("   ❌ 서비스 계정 JSON 파싱 오류")
    elif hasattr(settings, 'GOOGLE_SERVICE_ACCOUNT_FILE') and settings.GOOGLE_SERVICE_ACCOUNT_FILE:
        if os.path.exists(settings.GOOGLE_SERVICE_ACCOUNT_FILE):
            print(f"   ✅ 서비스 계정 파일 존재: {settings.GOOGLE_SERVICE_ACCOUNT_FILE}")
        else:
            print(f"   ❌ 서비스 계정 파일 없음: {settings.GOOGLE_SERVICE_ACCOUNT_FILE}")
    else:
        print("   ❌ 서비스 계정 설정 없음")
    print()

def diagnose_oauth_error():
    """OAuth 400 오류를 진단합니다."""
    print("=== OAuth 400 오류 진단 ===")
    print()
    
    print("🔍 400 오류: invalid_request의 일반적인 원인:")
    print()
    
    print("1. 잘못된 애플리케이션 타입:")
    print("   - 현재 '데스크톱 애플리케이션' 타입을 사용 중")
    print("   - 안드로이드 앱의 경우 '안드로이드' 타입이 필요")
    print("   - 또는 서비스 계정 방식 사용 권장")
    print()
    
    print("2. 승인된 리디렉션 URI 문제:")
    print("   - Google Cloud Console > API 및 서비스 > 사용자 인증 정보")
    print("   - OAuth 2.0 클라이언트 ID 편집")
    print("   - 승인된 리디렉션 URI에 다음 추가:")
    print("     * http://localhost")
    print("     * http://localhost:8080")
    print("     * http://localhost:8000")
    print()
    
    print("3. 클라이언트 시크릿 누락:")
    print("   - 데스크톱 애플리케이션에는 client_secret이 필요")
    print("   - JSON 파일에 client_secret 필드 확인")
    print()
    
    print("4. 프로젝트 설정 문제:")
    print("   - Google Calendar API가 활성화되어 있는지 확인")
    print("   - OAuth 동의 화면이 올바르게 설정되어 있는지 확인")
    print()

def create_fixed_oauth_config():
    """수정된 OAuth 설정 예시를 생성합니다."""
    print("=== 수정된 OAuth 설정 예시 ===")
    print()
    
    oauth_config = {
        "installed": {
            "client_id": "your-client-id.apps.googleusercontent.com",
            "project_id": "calendar-service-79804",
            "auth_uri": "https://accounts.google.com/o/oauth2/auth",
            "token_uri": "https://oauth2.googleapis.com/token",
            "auth_provider_x509_cert_url": "https://www.googleapis.com/oauth2/v1/certs",
            "client_secret": "your-client-secret",
            "redirect_uris": [
                "http://localhost",
                "http://localhost:8080",
                "http://localhost:8000"
            ]
        }
    }
    
    print("올바른 OAuth 설정 형식:")
    print(json.dumps(oauth_config, indent=2, ensure_ascii=False))
    print()
    
    print("⚠️  주의사항:")
    print("1. client_id와 client_secret을 실제 값으로 교체하세요")
    print("2. redirect_uris에 localhost 주소들이 포함되어야 합니다")
    print("3. Google Cloud Console에서 동일한 redirect_uris를 설정하세요")
    print()

def recommend_service_account():
    """서비스 계정 방식을 권장합니다."""
    print("=== 권장 해결책: 서비스 계정 사용 ===")
    print()
    
    print("🎯 안드로이드 앱의 경우 서비스 계정 방식이 더 적합합니다:")
    print()
    
    print("장점:")
    print("✅ 사용자 인증 없이 캘린더 접근")
    print("✅ OAuth 플로우 불필요")
    print("✅ 백엔드에서 안전하게 관리")
    print("✅ 안드로이드 앱은 HTTP API로만 통신")
    print()
    
    print("설정 방법:")
    print("1. Google Cloud Console > IAM 및 관리 > 서비스 계정")
    print("2. 새 서비스 계정 생성")
    print("3. JSON 키 다운로드")
    print("4. 환경 변수에 설정:")
    print("   GOOGLE_SERVICE_ACCOUNT_FILE=path/to/service-account.json")
    print("   또는")
    print("   GOOGLE_SERVICE_ACCOUNT_JSON='{...json content...}'")
    print()
    
    print("5. Google Calendar에서 서비스 계정 이메일에 권한 부여")
    print("   - 캘린더 설정 > 특정 사용자와 공유")
    print("   - 서비스 계정 이메일 추가")
    print("   - '변경 및 관리 권한' 선택")
    print()

def test_google_calendar():
    """Google Calendar 서비스 연결을 테스트합니다."""
    print("=== Google Calendar API 테스트 ===")
    
    try:
        calendar_service = GoogleCalendarService()
        
        if calendar_service.service:
            print("✅ Google Calendar 서비스가 성공적으로 초기화되었습니다.")
            
            # 간단한 캘린더 목록 조회 테스트
            try:
                calendar_list = calendar_service.service.calendarList().list().execute()
                calendars = calendar_list.get('items', [])
                print(f"   사용 가능한 캘린더 수: {len(calendars)}")
                
                for calendar in calendars[:3]:  # 처음 3개만 표시
                    print(f"   - {calendar.get('summary', 'N/A')}")
                    
            except Exception as e:
                print(f"❌ 캘린더 목록 조회 실패: {str(e)}")
                
        else:
            print("❌ Google Calendar 서비스 초기화에 실패했습니다.")
            
    except Exception as e:
        print(f"❌ Google Calendar 테스트 중 오류: {str(e)}")
    
    print()

def test_sample_event():
    """샘플 일정 생성을 테스트합니다."""
    print("=== 샘플 일정 생성 테스트 ===")
    
    try:
        calendar_service = GoogleCalendarService()
        
        if not calendar_service.service:
            print("❌ Google Calendar 서비스가 초기화되지 않았습니다.")
            return
        
        from datetime import datetime, timedelta
        
        # 내일 오후 2시에 1시간 테스트 일정
        tomorrow = datetime.now() + timedelta(days=1)
        start_time = tomorrow.replace(hour=14, minute=0, second=0, microsecond=0)
        end_time = start_time + timedelta(hours=1)
        
        test_event = {
            'summary': '[테스트] AI 캘린더 연동 테스트',
            'description': 'AI 캘린더 시스템 연동 테스트용 일정입니다.',
            'start': {
                'dateTime': start_time.isoformat(),
                'timeZone': 'Asia/Seoul'
            },
            'end': {
                'dateTime': end_time.isoformat(),
                'timeZone': 'Asia/Seoul'
            }
        }
        
        print(f"테스트 일정 생성 시도: {start_time.strftime('%Y-%m-%d %H:%M')}")
        result = calendar_service.create_event(test_event)
        
        if result.get('success'):
            print("✅ 테스트 일정이 성공적으로 생성되었습니다!")
            print(f"   일정 ID: {result.get('event_id')}")
            print(f"   링크: {result.get('event_link')}")
            
            # 생성된 테스트 일정 삭제
            event_id = result.get('event_id')
            if event_id:
                delete_result = calendar_service.delete_event(event_id)
                if delete_result.get('success'):
                    print("✅ 테스트 일정이 성공적으로 삭제되었습니다.")
                else:
                    print(f"❌ 테스트 일정 삭제 실패: {delete_result.get('error')}")
        else:
            print(f"❌ 테스트 일정 생성 실패: {result.get('error')}")
            
    except Exception as e:
        print(f"❌ 샘플 일정 테스트 중 오류: {str(e)}")
    
    print()

if __name__ == "__main__":
    print("🔧 Google Calendar API 설정 진단 도구")
    print("=" * 50)
    print()
    
    # 환경 설정 테스트
    test_environment()
    
    # OAuth 오류 진단
    diagnose_oauth_error()
    
    # 수정된 설정 예시
    create_fixed_oauth_config()
    
    # 서비스 계정 권장
    recommend_service_account()
    
    print("=" * 50)
    print("🚀 다음 단계:")
    print("1. 서비스 계정 방식으로 전환 (권장)")
    print("2. 또는 OAuth 설정 수정")
    print("3. python test_env.py 다시 실행하여 확인")
    
    # Google Calendar가 정상적으로 초기화된 경우에만 샘플 이벤트 테스트
    settings = get_settings()
    if settings.GOOGLE_CALENDAR_CREDENTIALS:
        try:
            json.loads(settings.GOOGLE_CALENDAR_CREDENTIALS)
            test_sample_event()
        except:
            print("Google Calendar 자격 증명 문제로 샘플 이벤트 테스트를 건너뜁니다.")
    
    print("테스트 완료!") 