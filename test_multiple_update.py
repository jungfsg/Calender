#!/usr/bin/env python3
"""
다중 수정 기능 테스트 스크립트

이 스크립트는 AI 캘린더 시스템의 다중 수정 기능을 테스트합니다.
"""

import requests
import json
import datetime
from typing import Dict, Any, List

# 서버 URL 설정
BASE_URL = "http://localhost:8000"
CHAT_URL = f"{BASE_URL}/api/v1/calendar/chat"

def test_update_classification(user_input: str) -> Dict[str, Any]:
    """수정 유형 분류 테스트"""
    try:
        response = requests.post(
            CHAT_URL,
            json={"message": user_input},
            headers={"Content-Type": "application/json"}
        )
        
        if response.status_code == 200:
            data = response.json()
            print(f"✅ 서버 응답 성공")
            print(f"📝 입력: {user_input}")
            print(f"🎯 응답: {data.get('response', 'No response')}")
            
            # 분류 결과 확인
            if 'calendar_result' in data:
                result = data['calendar_result']
                print(f"📊 캘린더 결과: {result}")
                
                if 'extracted_info' in data:
                    extracted = data['extracted_info']
                    update_type = extracted.get('update_type', 'unknown')
                    print(f"🔍 수정 타입: {update_type}")
                    
                    if update_type == 'multiple':
                        updates = extracted.get('updates', [])
                        print(f"📝 수정 요청 개수: {len(updates)}")
                        for i, update in enumerate(updates):
                            print(f"   수정 {i+1}:")
                            print(f"     대상: {update.get('target', {})}")
                            print(f"     변경사항: {update.get('changes', {})}")
                    else:
                        print(f"📝 단일 수정:")
                        print(f"     대상: {extracted.get('target', {})}")
                        print(f"     변경사항: {extracted.get('changes', {})}")
            
            return data
        else:
            print(f"❌ 서버 응답 실패: {response.status_code}")
            print(f"오류 내용: {response.text}")
            return {}
            
    except Exception as e:
        print(f"❌ 테스트 중 오류 발생: {e}")
        return {}

def test_multiple_update_examples():
    """다중 수정 예시 테스트"""
    print("🧪 다중 수정 기능 테스트 시작")
    print("=" * 50)
    
    test_cases = [
        # 기본 다중 수정
        "오늘 헬스 일정 오후 3시로 바꾸고 다음주 드라이브 일정을 헬스로 이름 바꿔줘",
        
        # 시간과 제목 수정
        "팀 미팅 시간 4시로 바꾸고 프로젝트 회의도 내일로 옮겨줘",
        
        # 제목과 날짜 수정
        "내일 회의 제목을 중요한 회의로 바꾸고 금요일 점심약속 시간을 1시로 변경해줘",
        
        # 복합 수정
        "오늘 운동 일정을 헬스장 운동으로 바꾸고 내일 미팅 시간을 오후 2시로 변경해줘",
        
        # 날짜와 시간 동시 수정
        "수요일 회의를 목요일 오후 3시로 옮기고 토요일 약속을 일요일 오전 10시로 바꿔줘",
    ]
    
    for i, test_case in enumerate(test_cases, 1):
        print(f"\n🧪 테스트 케이스 {i}")
        print(f"📝 입력: {test_case}")
        print("-" * 40)
        
        result = test_update_classification(test_case)
        
        if result:
            print("✅ 테스트 완료")
        else:
            print("❌ 테스트 실패")
        
        print("-" * 40)

def test_single_update_examples():
    """단일 수정 예시 테스트"""
    print("\n🧪 단일 수정 기능 테스트 시작")
    print("=" * 50)
    
    test_cases = [
        # 시간 수정
        "오늘 회의 시간을 오후 3시로 바꿔줘",
        
        # 제목 수정
        "내일 미팅 제목을 중요한 미팅으로 바꿔줘",
        
        # 날짜 수정
        "수요일 약속을 목요일로 옮겨줘",
        
        # 설명 수정
        "금요일 회의 설명을 중요한 안건 논의로 바꿔줘",
    ]
    
    for i, test_case in enumerate(test_cases, 1):
        print(f"\n🧪 테스트 케이스 {i}")
        print(f"📝 입력: {test_case}")
        print("-" * 40)
        
        result = test_update_classification(test_case)
        
        if result:
            print("✅ 테스트 완료")
        else:
            print("❌ 테스트 실패")
        
        print("-" * 40)

def test_edge_cases():
    """엣지 케이스 테스트"""
    print("\n🧪 엣지 케이스 테스트 시작")
    print("=" * 50)
    
    test_cases = [
        # 애매한 표현
        "회의 시간 바꾸고 약속도 수정해줘",
        
        # 복잡한 연결어
        "오늘 일정을 내일로 옮기고, 그 다음에 수요일 회의도 목요일로 바꾸고, 추가로 금요일 약속 시간도 조정해줘",
        
        # 부분 정보만 있는 경우
        "헬스 일정 수정하고 미팅도 바꿔줘",
        
        # 모호한 시간 표현
        "회의를 늦은 시간으로 바꾸고 약속도 이른 시간으로 수정해줘",
    ]
    
    for i, test_case in enumerate(test_cases, 1):
        print(f"\n🧪 엣지 케이스 {i}")
        print(f"📝 입력: {test_case}")
        print("-" * 40)
        
        result = test_update_classification(test_case)
        
        if result:
            print("✅ 처리 완료 (결과 확인 필요)")
        else:
            print("❌ 처리 실패")
        
        print("-" * 40)

def check_server_status():
    """서버 상태 확인"""
    try:
        response = requests.get(f"{BASE_URL}/health")
        if response.status_code == 200:
            print("✅ 서버가 정상적으로 실행 중입니다.")
            return True
        else:
            print(f"⚠️ 서버 상태 확인 실패: {response.status_code}")
            return False
    except:
        print("❌ 서버에 연결할 수 없습니다. 서버가 실행 중인지 확인해주세요.")
        print("서버 실행 명령: python app/main.py")
        return False

def main():
    """메인 함수"""
    print("🤖 AI 캘린더 다중 수정 기능 테스트")
    print("=" * 60)
    
    # 서버 상태 확인
    if not check_server_status():
        return
    
    print(f"🌐 서버 URL: {BASE_URL}")
    print(f"📅 테스트 시작 시간: {datetime.datetime.now()}")
    print()
    
    try:
        # 다중 수정 테스트
        test_multiple_update_examples()
        
        # 단일 수정 테스트
        test_single_update_examples()
        
        # 엣지 케이스 테스트
        test_edge_cases()
        
        print("\n🎉 모든 테스트가 완료되었습니다!")
        print("📊 결과를 확인하고 필요시 수정해주세요.")
        
    except KeyboardInterrupt:
        print("\n⏹️ 사용자에 의해 테스트가 중단되었습니다.")
    except Exception as e:
        print(f"\n❌ 테스트 중 오류 발생: {e}")

if __name__ == "__main__":
    main() 