#!/usr/bin/env python3
"""
Google Calendar API 설정을 도와주는 스크립트
"""

import json
import os
from app.core.config import get_settings

def check_credentials_format():
    """자격 증명 형식을 확인합니다."""
    print("=== Google Calendar 자격 증명 형식 확인 ===")
    
    settings = get_settings()
    
    if not settings.GOOGLE_CALENDAR_CREDENTIALS:
        print("❌ GOOGLE_CALENDAR_CREDENTIALS 환경 변수가 설정되지 않았습니다.")
        print("\n다음 단계를 따라 설정해주세요:")
        print("1. Google Cloud Console (https://console.cloud.google.com/) 접속")
        print("2. 새 프로젝트 생성 또는 기존 프로젝트 선택")
        print("3. Google Calendar API 활성화")
        print("4. 사용자 인증 정보 > OAuth 2.0 클라이언트 ID 생성")
        print("5. 애플리케이션 유형: 데스크톱 애플리케이션")
        print("6. 승인된 리디렉션 URI에 다음 추가:")
        print("   - http://localhost")
        print("   - http://localhost:8080")
        print("   - http://localhost:8000")
        print("7. JSON 파일 다운로드 후 내용을 GOOGLE_CALENDAR_CREDENTIALS에 설정")
        return False
    
    try:
        credentials_data = json.loads(settings.GOOGLE_CALENDAR_CREDENTIALS)
        print("✅ JSON 형식이 올바릅니다.")
        
        # 필수 필드 확인
        if 'installed' not in credentials_data:
            print("❌ 'installed' 키가 없습니다. 데스크톱 애플리케이션용 자격 증명인지 확인해주세요.")
            return False
        
        installed = credentials_data['installed']
        required_fields = ['client_id', 'client_secret', 'auth_uri', 'token_uri']
        
        for field in required_fields:
            if field not in installed:
                print(f"❌ 필수 필드 '{field}'가 없습니다.")
                return False
        
        print(f"✅ 프로젝트 ID: {installed.get('project_id', 'N/A')}")
        print(f"✅ 클라이언트 ID: {installed['client_id'][:20]}...")
        
        # redirect_uris 확인
        redirect_uris = installed.get('redirect_uris', [])
        print(f"✅ 리디렉션 URI: {redirect_uris}")
        
        if 'http://localhost' not in redirect_uris:
            print("⚠️  경고: 'http://localhost'가 리디렉션 URI에 없습니다.")
            print("   Google Cloud Console에서 승인된 리디렉션 URI에 추가해주세요.")
        
        return True
        
    except json.JSONDecodeError as e:
        print(f"❌ JSON 파싱 오류: {str(e)}")
        print("GOOGLE_CALENDAR_CREDENTIALS의 JSON 형식을 확인해주세요.")
        return False

def create_sample_env():
    """샘플 .env 파일을 생성합니다."""
    print("\n=== 샘플 .env 파일 생성 ===")
    
    sample_env_content = '''# OpenAI API 설정
OPENAI_API_KEY=your_openai_api_key_here

# Google Calendar API 설정
# Google Cloud Console에서 다운로드한 credentials.json 파일의 내용을 한 줄로 입력
GOOGLE_CALENDAR_CREDENTIALS={"installed":{"client_id":"your_client_id","project_id":"your_project_id","auth_uri":"https://accounts.google.com/o/oauth2/auth","token_uri":"https://oauth2.googleapis.com/token","auth_provider_x509_cert_url":"https://www.googleapis.com/oauth2/v1/certs","client_secret":"your_client_secret","redirect_uris":["http://localhost","http://localhost:8080","http://localhost:8000"]}}

# ChromaDB 설정
CHROMADB_HOST=localhost
CHROMADB_PORT=9000
CHROMADB_PERSIST_DIR=./chroma_db

# 로깅 설정
LOG_LEVEL=INFO
'''
    
    if not os.path.exists('.env'):
        with open('.env', 'w', encoding='utf-8') as f:
            f.write(sample_env_content)
        print("✅ 샘플 .env 파일이 생성되었습니다.")
        print("   파일을 편집하여 실제 API 키와 자격 증명을 입력해주세요.")
    else:
        print("⚠️  .env 파일이 이미 존재합니다.")
        print("   기존 파일을 확인하여 필요한 설정을 추가해주세요.")

def validate_oauth_setup():
    """OAuth 설정을 검증합니다."""
    print("\n=== OAuth 설정 검증 ===")
    
    print("Google Cloud Console에서 다음 설정을 확인해주세요:")
    print()
    print("1. 프로젝트 설정:")
    print("   - Google Calendar API가 활성화되어 있는지 확인")
    print("   - API 및 서비스 > 라이브러리에서 'Google Calendar API' 검색 후 사용 설정")
    print()
    print("2. OAuth 동의 화면:")
    print("   - 사용자 유형: 외부 (개인 사용) 또는 내부 (조직 내)")
    print("   - 앱 이름, 사용자 지원 이메일, 개발자 연락처 정보 입력")
    print("   - 범위: ../auth/calendar 추가")
    print()
    print("3. 사용자 인증 정보:")
    print("   - OAuth 2.0 클라이언트 ID 생성")
    print("   - 애플리케이션 유형: 데스크톱 애플리케이션")
    print("   - 승인된 리디렉션 URI:")
    print("     * http://localhost")
    print("     * http://localhost:8080") 
    print("     * http://localhost:8000")
    print()
    print("4. 테스트 사용자 (외부 앱인 경우):")
    print("   - OAuth 동의 화면 > 테스트 사용자에 본인 Gmail 주소 추가")
    print()

def troubleshoot_common_issues():
    """일반적인 문제 해결 방법을 제공합니다."""
    print("\n=== 일반적인 문제 해결 ===")
    print()
    print("🔧 400 오류: invalid_request")
    print("   - redirect_uri가 Google Cloud Console에 등록되지 않음")
    print("   - 해결: 승인된 리디렉션 URI에 http://localhost 추가")
    print()
    print("🔧 403 오류: access_denied")
    print("   - 앱이 확인되지 않음 또는 테스트 사용자가 아님")
    print("   - 해결: OAuth 동의 화면에서 테스트 사용자에 본인 이메일 추가")
    print()
    print("🔧 인증 창이 열리지 않음")
    print("   - 방화벽 또는 브라우저 설정 문제")
    print("   - 해결: 다른 브라우저 시도 또는 콘솔 인증 사용")
    print()
    print("🔧 토큰 만료 오류")
    print("   - token.json 파일 삭제 후 재인증")
    print("   - 해결: rm token.json && python test_env.py")
    print()

if __name__ == "__main__":
    print("Google Calendar API 설정 도우미")
    print("=" * 50)
    
    # 자격 증명 형식 확인
    credentials_ok = check_credentials_format()
    
    # 샘플 .env 파일 생성
    create_sample_env()
    
    # OAuth 설정 가이드
    validate_oauth_setup()
    
    # 문제 해결 가이드
    troubleshoot_common_issues()
    
    print("\n" + "=" * 50)
    if credentials_ok:
        print("✅ 설정이 완료되었습니다. 'python test_env.py'로 테스트해보세요.")
    else:
        print("❌ 설정을 완료한 후 다시 시도해주세요.") 