#!/usr/bin/env python3
"""
안드로이드 앱용 Google Calendar API 설정 가이드
"""

import json
import os
from app.core.config import get_settings

def android_setup_guide():
    """안드로이드 앱용 Google Calendar API 설정 가이드"""
    print("=== 안드로이드 앱용 Google Calendar API 설정 ===")
    print()
    print("🔧 현재 문제: 데스크톱 애플리케이션용 OAuth 설정을 사용 중")
    print("✅ 해결책: 안드로이드 앱용 OAuth 설정으로 변경")
    print()
    
    print("📱 안드로이드 앱용 설정 단계:")
    print()
    print("1. Google Cloud Console 설정:")
    print("   - https://console.cloud.google.com/ 접속")
    print("   - 프로젝트: calendar-service-79804 선택")
    print("   - API 및 서비스 > 사용자 인증 정보")
    print()
    
    print("2. 새 OAuth 2.0 클라이언트 ID 생성:")
    print("   - '+ 사용자 인증 정보 만들기' > 'OAuth 클라이언트 ID'")
    print("   - 애플리케이션 유형: 'Android'")
    print("   - 패키지 이름: com.example.calender (또는 실제 패키지명)")
    print("   - SHA-1 인증서 지문 추가 (개발용)")
    print()
    
    print("3. SHA-1 지문 생성 방법:")
    print("   - Android Studio에서: Gradle > app > Tasks > android > signingReport")
    print("   - 또는 터미널에서:")
    print("     keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android")
    print()
    
    print("4. 서비스 계정 키 생성 (백엔드용):")
    print("   - '+ 사용자 인증 정보 만들기' > '서비스 계정'")
    print("   - 서비스 계정 이름: calendar-backend")
    print("   - 역할: 편집자 또는 소유자")
    print("   - 키 생성: JSON 형식")
    print("   - 다운로드한 JSON 파일을 백엔드에서 사용")
    print()

def create_service_account_setup():
    """서비스 계정 설정 방법"""
    print("=== 서비스 계정 기반 설정 (권장) ===")
    print()
    print("🎯 서비스 계정을 사용하면 사용자 인증 없이 캘린더에 접근 가능")
    print()
    
    print("1. 서비스 계정 생성:")
    print("   - Google Cloud Console > IAM 및 관리 > 서비스 계정")
    print("   - '+ 서비스 계정 만들기'")
    print("   - 이름: calendar-service")
    print("   - 설명: AI 캘린더 백엔드 서비스")
    print()
    
    print("2. 서비스 계정 키 다운로드:")
    print("   - 생성된 서비스 계정 클릭")
    print("   - '키' 탭 > '키 추가' > '새 키 만들기'")
    print("   - 유형: JSON")
    print("   - 다운로드된 JSON 파일을 프로젝트 폴더에 저장")
    print()
    
    print("3. 캘린더 공유 설정:")
    print("   - Google Calendar 웹사이트 접속")
    print("   - 사용할 캘린더 선택 > 설정 및 공유")
    print("   - '특정 사용자와 공유' > 서비스 계정 이메일 추가")
    print("   - 권한: '변경 및 관리 권한' 선택")
    print()

def create_service_account_config():
    """서비스 계정용 설정 파일 생성"""
    print("=== 서비스 계정용 환경 설정 ===")
    print()
    
    service_account_env = '''# OpenAI API 설정
OPENAI_API_KEY=your_openai_api_key_here

# Google Calendar API 설정 (서비스 계정 방식)
GOOGLE_SERVICE_ACCOUNT_FILE=path/to/service-account-key.json
GOOGLE_CALENDAR_ID=primary

# 또는 서비스 계정 JSON을 직접 환경 변수로 설정
GOOGLE_SERVICE_ACCOUNT_JSON={"type":"service_account","project_id":"calendar-service-79804","private_key_id":"...","private_key":"-----BEGIN PRIVATE KEY-----\\n...\\n-----END PRIVATE KEY-----\\n","client_email":"calendar-service@calendar-service-79804.iam.gserviceaccount.com","client_id":"...","auth_uri":"https://accounts.google.com/o/oauth2/auth","token_uri":"https://oauth2.googleapis.com/token","auth_provider_x509_cert_url":"https://www.googleapis.com/oauth2/v1/certs","client_x509_cert_url":"..."}

# ChromaDB 설정
CHROMADB_HOST=localhost
CHROMADB_PORT=9000
CHROMADB_PERSIST_DIR=./chroma_db

# 로깅 설정
LOG_LEVEL=INFO
'''
    
    with open('.env.service_account', 'w', encoding='utf-8') as f:
        f.write(service_account_env)
    
    print("✅ .env.service_account 파일이 생성되었습니다.")
    print("   서비스 계정 키 파일 경로를 수정하고 .env로 이름을 변경하세요.")
    print()

def flutter_integration_guide():
    """Flutter 앱 통합 가이드"""
    print("=== Flutter 앱 통합 방법 ===")
    print()
    
    print("📱 Flutter 앱에서 백엔드 API 호출:")
    print()
    print("1. HTTP 요청으로 백엔드와 통신:")
    print("   - 사용자가 앱에서 '일정 추가' 요청")
    print("   - Flutter → FastAPI 백엔드 → Google Calendar")
    print("   - 백엔드에서 서비스 계정으로 캘린더 조작")
    print()
    
    print("2. Flutter 코드 예시:")
    print("""
import 'package:http/http.dart' as http;
import 'dart:convert';

class CalendarService {
  static const String baseUrl = 'http://localhost:8000/api/v1/calendar';
  
  static Future<Map<String, dynamic>> addEvent(String message) async {
    final response = await http.post(
      Uri.parse('$baseUrl/ai-chat'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'message': message,
        'session_id': 'user123'
      }),
    );
    
    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('일정 추가 실패');
    }
  }
}
""")
    print()
    
    print("3. 사용 예시:")
    print("""
// 사용자가 "내일 오후 2시에 회의 일정 추가해줘"라고 입력
final result = await CalendarService.addEvent("내일 오후 2시에 회의 일정 추가해줘");
print(result['response']); // "✅ 일정이 성공적으로 추가되었습니다!"
""")
    print()

def check_current_setup():
    """현재 설정 상태 확인"""
    print("=== 현재 설정 상태 확인 ===")
    
    settings = get_settings()
    
    if settings.GOOGLE_CALENDAR_CREDENTIALS:
        try:
            creds = json.loads(settings.GOOGLE_CALENDAR_CREDENTIALS)
            if 'installed' in creds:
                print("❌ 현재 데스크톱 애플리케이션용 OAuth 설정을 사용 중")
                print("   안드로이드 앱에서는 서비스 계정 방식을 권장합니다.")
            elif 'web' in creds:
                print("❌ 현재 웹 애플리케이션용 OAuth 설정을 사용 중")
                print("   안드로이드 앱에서는 서비스 계정 방식을 권장합니다.")
            else:
                print("✅ 서비스 계정 설정으로 보입니다.")
        except:
            print("❌ 자격 증명 형식에 문제가 있습니다.")
    else:
        print("❌ Google Calendar 자격 증명이 설정되지 않았습니다.")
    
    print()

if __name__ == "__main__":
    print("🤖 AI 캘린더 - 안드로이드 앱용 Google Calendar API 설정")
    print("=" * 60)
    print()
    
    # 현재 설정 확인
    check_current_setup()
    
    # 안드로이드 설정 가이드
    android_setup_guide()
    
    # 서비스 계정 설정 (권장)
    create_service_account_setup()
    
    # 설정 파일 생성
    create_service_account_config()
    
    # Flutter 통합 가이드
    flutter_integration_guide()
    
    print("=" * 60)
    print("🎯 권장 방법: 서비스 계정을 사용하여 백엔드에서 캘린더 관리")
    print("📱 Flutter 앱은 HTTP API로 백엔드와 통신")
    print("🔐 사용자 인증 없이 안전하게 캘린더 조작 가능") 