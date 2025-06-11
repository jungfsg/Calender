#!/usr/bin/env python3
"""
다중 일정 처리 기능 테스트 스크립트
"""

import requests
import json
from datetime import datetime, timedelta

# 서버 URL (실제 서버 URL로 변경 필요)
BASE_URL = "http://localhost:8000"  # 또는 실제 ngrok URL

def test_multiple_events():
    """다중 일정 추가 테스트"""
    
    # 테스트 케이스들
    test_cases = [
        {
            "name": "기본 다중 일정",
            "message": "내일 저녁 7시에 카페 일정 추가하고 다음주 월요일 오전 11시에 점심 일정 추가해줘"
        },
        {
            "name": "연속 회의 일정",
            "message": "오늘 오후 2시에 회의 잡고 내일 오전 10시에 병원 예약해줘"
        },
        {
            "name": "주간 일정 계획",
            "message": "다음주 화요일 오후 3시에 프레젠테이션 준비하고 수요일 오전 9시에 팀 미팅 추가해줘"
        },
        {
            "name": "개인 일정",
            "message": "이번 주말 토요일 저녁 8시에 친구 만남 일정 추가하고 일요일 오후 2시에 영화 보기 일정도 추가해줘"
        }
    ]
    
    print("🚀 다중 일정 처리 기능 테스트 시작\n")
    
    for i, test_case in enumerate(test_cases, 1):
        print(f"📋 테스트 {i}: {test_case['name']}")
        print(f"💬 입력: {test_case['message']}")
        
        try:
            # API 호출
            response = requests.post(
                f"{BASE_URL}/api/v1/calendar/ai-chat",
                headers={'Content-Type': 'application/json'},
                json={
                    'message': test_case['message'],
                    'session_id': f'test_user_{i}'
                }
            )
            
            if response.status_code == 200:
                data = response.json()
                
                print(f"✅ 응답 성공")
                print(f"🤖 AI 응답: {data.get('response', 'N/A')}")
                
                # 추출된 정보 확인
                extracted_info = data.get('extracted_info', {})
                if extracted_info.get('is_multiple'):
                    events = extracted_info.get('events', [])
                    print(f"📊 추출된 일정 수: {len(events)}개")
                    
                    for j, event in enumerate(events, 1):
                        print(f"   일정 {j}:")
                        print(f"     - 제목: {event.get('title', 'N/A')}")
                        print(f"     - 날짜: {event.get('start_date', 'N/A')}")
                        print(f"     - 시간: {event.get('start_time', 'N/A')}")
                        print(f"     - 장소: {event.get('location', 'N/A') or '없음'}")
                else:
                    print("📝 단일 일정으로 처리됨")
                    print(f"   - 제목: {extracted_info.get('title', 'N/A')}")
                    print(f"   - 날짜: {extracted_info.get('start_date', 'N/A')}")
                    print(f"   - 시간: {extracted_info.get('start_time', 'N/A')}")
                
                # 캘린더 결과 확인
                calendar_result = data.get('calendar_result', {})
                if calendar_result.get('is_multiple'):
                    events_count = calendar_result.get('events_count', 0)
                    print(f"📅 캘린더에 추가된 일정: {events_count}개")
                
            else:
                print(f"❌ API 호출 실패: {response.status_code}")
                print(f"   오류 내용: {response.text}")
                
        except Exception as e:
            print(f"❌ 테스트 실행 중 오류: {str(e)}")
        
        print("-" * 80)
        print()

def test_single_vs_multiple():
    """단일 일정과 다중 일정 구분 테스트"""
    
    test_cases = [
        {"message": "내일 오후 2시에 회의 일정 추가해줘", "expected": "SINGLE"},
        {"message": "내일 오후 2시에 회의하고 저녁 7시에 저녁약속도 추가해줘", "expected": "MULTIPLE"},
        {"message": "다음주 월요일 회의 일정 만들어줘", "expected": "SINGLE"},
        {"message": "다음주 월요일에 회의하고 화요일에 프레젠테이션 준비해줘", "expected": "MULTIPLE"},
    ]
    
    print("🔍 단일/다중 일정 구분 테스트\n")
    
    for i, test_case in enumerate(test_cases, 1):
        print(f"테스트 {i}: {test_case['message']}")
        print(f"예상 결과: {test_case['expected']}")
        
        try:
            response = requests.post(
                f"{BASE_URL}/api/v1/calendar/ai-chat",
                headers={'Content-Type': 'application/json'},
                json={
                    'message': test_case['message'],
                    'session_id': f'test_classification_{i}'
                }
            )
            
            if response.status_code == 200:
                data = response.json()
                extracted_info = data.get('extracted_info', {})
                is_multiple = extracted_info.get('is_multiple', False)
                actual = "MULTIPLE" if is_multiple else "SINGLE"
                
                result = "✅ 정확" if actual == test_case['expected'] else "❌ 오류"
                print(f"실제 결과: {actual} {result}")
                
                if is_multiple:
                    events = extracted_info.get('events', [])
                    print(f"추출된 일정 수: {len(events)}개")
            else:
                print(f"❌ API 호출 실패: {response.status_code}")
                
        except Exception as e:
            print(f"❌ 테스트 실행 중 오류: {str(e)}")
        
        print("-" * 50)

if __name__ == "__main__":
    print("=" * 80)
    print("📅 다중 일정 처리 기능 테스트")
    print("=" * 80)
    print()
    
    # 서버 상태 확인
    try:
        response = requests.get(f"{BASE_URL}/health", timeout=5)
        if response.status_code == 200:
            print("✅ 서버 연결 성공\n")
        else:
            print("⚠️  서버가 실행 중이지만 응답이 이상합니다\n")
    except:
        print(f"❌ 서버에 연결할 수 없습니다. {BASE_URL}에서 서버가 실행 중인지 확인해주세요.")
        print("서버 URL을 수정하거나 서버를 시작한 후 다시 시도해주세요.\n")
        exit(1)
    
    # 테스트 실행
    test_single_vs_multiple()
    print("\n" + "=" * 80 + "\n")
    test_multiple_events()
    
    print("🎉 모든 테스트 완료!") 