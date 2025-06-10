#!/usr/bin/env python3
"""
다중 삭제 기능 테스트 스크립트
"""

import requests
import json
from datetime import datetime, timedelta

# 서버 URL (실제 서버 URL로 변경 필요)
BASE_URL = "http://localhost:8000"  # 또는 실제 ngrok URL

def test_multiple_delete():
    """다중 삭제 테스트"""
    
    # 테스트 케이스들
    test_cases = [
        {
            "name": "기본 다중 개별 삭제",
            "message": "내일 회의 삭제하고 다음주 월요일 점심약속도 삭제해줘"
        },
        {
            "name": "연속 일정 삭제",
            "message": "오늘 팀미팅 지우고 내일 병원 예약도 취소해줘"
        },
        {
            "name": "주간 일정 삭제",
            "message": "다음주 화요일 프레젠테이션 삭제하고 수요일 개인약속도 취소해줘"
        }
    ]
    
    print("🗑️ 다중 개별 삭제 기능 테스트 시작\n")
    
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
                    'session_id': f'test_delete_{i}'
                }
            )
            
            if response.status_code == 200:
                data = response.json()
                
                print(f"✅ 응답 성공")
                print(f"🤖 AI 응답: {data.get('response', 'N/A')}")
                
                # 추출된 정보 확인
                extracted_info = data.get('extracted_info', {})
                delete_type = extracted_info.get('delete_type', 'unknown')
                
                print(f"🔍 삭제 타입: {delete_type}")
                
                if delete_type == 'multiple':
                    targets = extracted_info.get('targets', [])
                    print(f"📊 삭제할 일정 수: {len(targets)}개")
                    
                    for j, target in enumerate(targets, 1):
                        print(f"   삭제 대상 {j}:")
                        print(f"     - 제목: {target.get('title', 'N/A')}")
                        print(f"     - 날짜: {target.get('date', 'N/A')}")
                        print(f"     - 시간: {target.get('time', 'N/A') or '없음'}")
                else:
                    print("📝 단일 삭제로 처리됨")
                    print(f"   - 제목: {extracted_info.get('title', 'N/A')}")
                    print(f"   - 날짜: {extracted_info.get('date', 'N/A')}")
                
                # 캘린더 결과 확인
                calendar_result = data.get('calendar_result', {})
                result_delete_type = calendar_result.get('delete_type', 'unknown')
                
                if result_delete_type == 'multiple':
                    events_count = calendar_result.get('events_count', 0)
                    print(f"🗑️ 캘린더에서 삭제된 일정: {events_count}개")
                
            else:
                print(f"❌ API 호출 실패: {response.status_code}")
                print(f"   오류 내용: {response.text}")
                
        except Exception as e:
            print(f"❌ 테스트 실행 중 오류: {str(e)}")
        
        print("-" * 80)
        print()

def test_bulk_delete():
    """전체 삭제 테스트"""
    
    test_cases = [
        {
            "name": "내일 전체 삭제",
            "message": "내일 일정을 모두 다 삭제해줘"
        },
        {
            "name": "오늘 전체 삭제",
            "message": "오늘 모든 일정 지워줘"
        },
        {
            "name": "다음주 월요일 전체 삭제",
            "message": "다음주 월요일 전체 일정 삭제해줘"
        },
        {
            "name": "이번주 금요일 전체 삭제",
            "message": "이번주 금요일 일정 다 없애줘"
        }
    ]
    
    print("🗑️ 전체 삭제 기능 테스트 시작\n")
    
    for i, test_case in enumerate(test_cases, 1):
        print(f"📋 테스트 {i}: {test_case['name']}")
        print(f"💬 입력: {test_case['message']}")
        
        try:
            response = requests.post(
                f"{BASE_URL}/api/v1/calendar/ai-chat",
                headers={'Content-Type': 'application/json'},
                json={
                    'message': test_case['message'],
                    'session_id': f'test_bulk_delete_{i}'
                }
            )
            
            if response.status_code == 200:
                data = response.json()
                
                print(f"✅ 응답 성공")
                print(f"🤖 AI 응답: {data.get('response', 'N/A')}")
                
                # 추출된 정보 확인
                extracted_info = data.get('extracted_info', {})
                delete_type = extracted_info.get('delete_type', 'unknown')
                
                print(f"🔍 삭제 타입: {delete_type}")
                
                if delete_type == 'bulk':
                    target_date = extracted_info.get('target_date', 'N/A')
                    date_description = extracted_info.get('date_description', 'N/A')
                    print(f"📅 삭제 대상 날짜: {target_date}")
                    print(f"📝 날짜 설명: {date_description}")
                else:
                    print("⚠️ 전체 삭제로 인식되지 않았습니다")
                
                # 캘린더 결과 확인
                calendar_result = data.get('calendar_result', {})
                result_delete_type = calendar_result.get('delete_type', 'unknown')
                
                if result_delete_type == 'bulk':
                    print(f"🗑️ 전체 삭제 실행 완료")
                    
            else:
                print(f"❌ API 호출 실패: {response.status_code}")
                print(f"   오류 내용: {response.text}")
                
        except Exception as e:
            print(f"❌ 테스트 실행 중 오류: {str(e)}")
        
        print("-" * 80)
        print()

def test_delete_classification():
    """삭제 유형 분류 테스트"""
    
    test_cases = [
        {"message": "내일 회의 삭제해줘", "expected": "single"},
        {"message": "내일 회의 삭제하고 모레 약속도 취소해줘", "expected": "multiple"},
        {"message": "내일 일정 모두 삭제해줘", "expected": "bulk"},
        {"message": "오늘 모든 일정 지워줘", "expected": "bulk"},
        {"message": "팀미팅 취소해줘", "expected": "single"},
        {"message": "다음주 월요일 전체 일정 삭제해줘", "expected": "bulk"},
    ]
    
    print("🔍 삭제 유형 분류 테스트\n")
    
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
                delete_type = extracted_info.get('delete_type', 'unknown')
                
                result = "✅ 정확" if delete_type == test_case['expected'] else "❌ 오류"
                print(f"실제 결과: {delete_type} {result}")
                
                if delete_type == 'multiple':
                    targets = extracted_info.get('targets', [])
                    print(f"추출된 삭제 대상: {len(targets)}개")
                elif delete_type == 'bulk':
                    target_date = extracted_info.get('target_date', 'N/A')
                    print(f"전체 삭제 날짜: {target_date}")
                    
            else:
                print(f"❌ API 호출 실패: {response.status_code}")
                
        except Exception as e:
            print(f"❌ 테스트 실행 중 오류: {str(e)}")
        
        print("-" * 50)

if __name__ == "__main__":
    print("=" * 80)
    print("🗑️ 다중 삭제 기능 테스트")
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
    test_delete_classification()
    print("\n" + "=" * 80 + "\n")
    test_bulk_delete()
    print("\n" + "=" * 80 + "\n")
    test_multiple_delete()
    
    print("🎉 모든 테스트 완료!") 