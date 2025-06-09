from typing import Optional, List, Dict, Any, TypedDict, Annotated
from openai import OpenAI
from langgraph.graph import StateGraph, END
from app.core.config import get_settings
# from app.services.google_calendar_service import GoogleCalendarService
from app.services.vector_store import VectorStoreService
import json
import re
from datetime import datetime, timedelta
from dateutil import parser
import pytz
import logging

settings = get_settings()

# =============================================================================
# 유틸리티 함수들 (글로벌 함수)
# =============================================================================

def get_relative_date_rules(current_date: datetime) -> dict:
    """상대적 날짜 표현을 절대 날짜로 변환하는 규칙을 생성합니다."""
    # 현재 요일 (0=월요일, 6=일요일) -> 일요일 기준으로 변환
    current_weekday = current_date.weekday()
    # 일요일을 0으로 만들기 위해 조정: (일=0, 월=1, 화=2, ..., 토=6)
    current_weekday_sunday_base = (current_weekday + 1) % 7
    
    # 다음 주 일요일까지의 일수
    days_to_next_sunday = 7 - current_weekday_sunday_base
    if days_to_next_sunday == 7:  # 오늘이 일요일인 경우
        days_to_next_sunday = 7
    
    next_sunday = current_date + timedelta(days=days_to_next_sunday)
    
    # 이번 주 남은 요일들 (일요일 기준)
    days_to_this_weekend = 6 - current_weekday_sunday_base  # 이번 주 토요일까지
    
    rules = {
        # 기본 상대적 표현
        "오늘": current_date.strftime('%Y-%m-%d'),
        "내일": (current_date + timedelta(days=1)).strftime('%Y-%m-%d'),
        "모레": (current_date + timedelta(days=2)).strftime('%Y-%m-%d'),
        "글피": (current_date + timedelta(days=3)).strftime('%Y-%m-%d'),
        
        # 주 단위 표현 - 일요일 기준
        "다음주": next_sunday.strftime('%Y-%m-%d'),
        "다음주 일요일": next_sunday.strftime('%Y-%m-%d'),
        "다음주 월요일": (next_sunday + timedelta(days=1)).strftime('%Y-%m-%d'),
        "다음주 화요일": (next_sunday + timedelta(days=2)).strftime('%Y-%m-%d'),
        "다음주 수요일": (next_sunday + timedelta(days=3)).strftime('%Y-%m-%d'),
        "다음주 목요일": (next_sunday + timedelta(days=4)).strftime('%Y-%m-%d'),
        "다음주 금요일": (next_sunday + timedelta(days=5)).strftime('%Y-%m-%d'),
        "다음주 토요일": (next_sunday + timedelta(days=6)).strftime('%Y-%m-%d'),
        
        # 이번 주 표현
        "이번 주말": (current_date + timedelta(days=days_to_this_weekend)).strftime('%Y-%m-%d'),
        "이번주 토요일": (current_date + timedelta(days=days_to_this_weekend)).strftime('%Y-%m-%d'),
        "이번주 일요일": (current_date + timedelta(days=days_to_this_weekend + 1)).strftime('%Y-%m-%d'),
        
        # 월 단위 표현
        "다음달": (current_date.replace(day=1) + timedelta(days=32)).replace(day=1).strftime('%Y-%m-%d'),
        "내년": current_date.replace(year=current_date.year + 1, month=1, day=1).strftime('%Y-%m-%d'),
        
        # 시간 표현
        "오전 9시": "09:00",
        "오전 10시": "10:00",
        "오전 11시": "11:00",
        "오후 1시": "13:00",
        "오후 2시": "14:00",
        "오후 3시": "15:00",
        "오후 4시": "16:00",
        "오후 5시": "17:00",
        "오후 6시": "18:00",
        "저녁 7시": "19:00",
        "저녁 8시": "20:00",
        "저녁 9시": "21:00",
        "밤 10시": "22:00",
        "밤 11시": "23:00",
    }
    
    return rules

def safe_json_parse(response_text: str, fallback_data: dict) -> dict:
    """JSON 파싱을 안전하게 수행"""
    try:
        # JSON 블록 추출 시도
        json_match = re.search(r'\{.*\}', response_text, re.DOTALL)
        if json_match:
            return json.loads(json_match.group())
        return json.loads(response_text)
    except json.JSONDecodeError:
        return fallback_data

def keyword_based_classification(user_input: str) -> dict:
    """키워드 기반 의도 분류 폴백"""
    user_input_lower = user_input.lower()
    
    # 커스터마이징 포인트: 키워드 추가/수정 가능
    # 예: '예약'을 추가하거나 특정 도메인 용어 추가
    intent_keywords = {
        'calendar_add': ['추가', '만들', '생성', '등록', '잡아', '스케줄', '예약', '설정'],
        'calendar_update': ['수정', '변경', '바꿔', '업데이트', '이동', '옮겨'],
        'calendar_delete': ['삭제', '지워', '취소', '없애', '빼'],
        'calendar_search': ['검색', '찾아', '조회', '확인', '뭐 있', '언제', '일정 보', '스케줄 확인'],
        'calendar_copy': ['복사', '복제', '같은 일정', '동일한']
    }
    
    for intent, keywords in intent_keywords.items():
        if any(keyword in user_input_lower for keyword in keywords):
            return {
                "intent": intent,
                "confidence": 0.7,
                "reason": f"키워드 기반 분류: {[k for k in keywords if k in user_input_lower]}"
            }
    
    return {
        "intent": "general_chat",
        "confidence": 0.8,
        "reason": "일정 관련 키워드 없음"
    }

def extract_title_from_input(user_input: str) -> str:
    """사용자 입력에서 제목 추출"""
    # 커스터마이징 포인트: 패턴 추가/수정 가능
    # 예: 특정 업무 용어나 패턴 추가
    patterns = [
        r'(.+?)\s*일정',
        r'(.+?)\s*미팅',
        r'(.+?)\s*회의',
        r'(.+?)\s*만남',
        r'(.+?)\s*약속',
        r'(.+?)\s*수업',  # 교육/학습 관련
        r'(.+?)\s*세미나'  # 비즈니스 관련
    ]
    
    for pattern in patterns:
        match = re.search(pattern, user_input)
        if match:
            title = match.group(1).strip()
            if len(title) > 2:  # 너무 짧은 제목 제외
                return title + ' 일정'
    
    # 패턴이 없으면 전체 입력에서 동사 제거
    cleaned = re.sub(r'(추가|만들|생성|등록|잡아|스케줄)', '', user_input).strip()
    return cleaned[:20] if cleaned else '새 일정'

def validate_and_correct_info(info: dict, current_date: datetime) -> dict:
    """추출된 정보 검증 및 보정"""
    try:
        # 날짜 검증
        start_date = info.get('start_date')
        if start_date:
            try:
                parsed_date = datetime.strptime(start_date, '%Y-%m-%d')
                # 과거 날짜면 내년으로 보정
                if parsed_date.date() < current_date.date():
                    info['start_date'] = (parsed_date + timedelta(days=365)).strftime('%Y-%m-%d')
            except:
                info['start_date'] = (current_date + timedelta(days=1)).strftime('%Y-%m-%d')
        
        # 시간 검증
        start_time = info.get('start_time')
        if start_time and not re.match(r'^\d{2}:\d{2}$', start_time):
            info['start_time'] = '10:00'
        
        # 종료 시간 자동 설정
        if info.get('start_time') and not info.get('end_time'):
            try:
                start_dt = datetime.strptime(info['start_time'], '%H:%M')
                # 커스터마이징 포인트: 기본 일정 길이 변경 가능 (현재 1시간)
                end_dt = start_dt + timedelta(hours=1)  # 기본 1시간, 필요시 변경
                info['end_time'] = end_dt.strftime('%H:%M')
            except:
                info['end_time'] = '11:00'
        
        # 종료 날짜 설정
        if not info.get('end_date'):
            info['end_date'] = info.get('start_date')
        
        return info
        
    except Exception as e:
        logging.error(f"정보 검증 중 오류: {str(e)}")
        return info

def get_default_event_info() -> dict:
    """기본 이벤트 정보 반환"""
    current_date = datetime.now(pytz.timezone('Asia/Seoul'))
    tomorrow = current_date + timedelta(days=1)
    
    # 커스터마이징 포인트: 기본값들 변경 가능
    return {
        "title": "새 일정",
        "start_date": tomorrow.strftime('%Y-%m-%d'),
        "start_time": "10:00",  # 기본 시작 시간
        "end_date": tomorrow.strftime('%Y-%m-%d'),
        "end_time": "11:00",   # 기본 종료 시간
        "description": "",
        "location": "",
        "attendees": [],
        "repeat_type": "none",
        "repeat_interval": 1,
        "repeat_count": None,
        "repeat_until": None,
        "reminders": [15],     # 기본 알림: 15분 전
        "all_day": False,
        "timezone": "Asia/Seoul",
        "priority": "normal",
        "category": "other"
    }

# =============================================================================
# 상태 정의
# =============================================================================

class CalendarState(TypedDict):
    messages: List[Dict[str, str]]
    current_input: str
    current_output: Optional[str]
    intent: Optional[str]
    extracted_info: Optional[Dict[str, Any]]
    action_type: Optional[str]
    calendar_result: Optional[Dict[str, Any]]
    context: Optional[List[str]]

# =============================================================================
# 메인 서비스 클래스
# =============================================================================

class LLMService:
    def __init__(self):
        self.client = OpenAI(api_key=settings.OPENAI_API_KEY)
        # self.calendar_service = GoogleCalendarService()
        self.vector_store = VectorStoreService()
        self.workflow = self._create_calendar_workflow()
        
    def _create_calendar_workflow(self):
        """AI 캘린더를 위한 LangGraph 워크플로우를 생성합니다."""
        
        def classify_intent(state: CalendarState) -> CalendarState:
            """1단계: 의도 분류"""
            try:
                # 커스터마이징 포인트: 프롬프트 수정하여 도메인 특화 가능
                # 예: 의료진을 위한 '진료', '수술' 등의 분류 추가
                prompt = f"""
사용자의 입력을 분석하여 의도를 분류해주세요.

예시:
"내일 오후 3시에 회의 일정 잡아줘" → {{"intent": "calendar_add", "confidence": 0.95, "reason": "새로운 일정 추가 요청"}}
"오늘 일정 뭐 있어?" → {{"intent": "calendar_search", "confidence": 0.93, "reason": "일정 조회 요청"}}
"회의 시간을 4시로 바꿔줘" → {{"intent": "calendar_update", "confidence": 0.90, "reason": "기존 일정 수정 요청"}}
"내일 미팅 취소해줘" → {{"intent": "calendar_delete", "confidence": 0.88, "reason": "일정 삭제 요청"}}
"안녕하세요" → {{"intent": "general_chat", "confidence": 0.99, "reason": "일반 인사말"}}

사용자 입력: {state['current_input']}

다음 중 하나로 분류해주세요:
1. calendar_add - 새로운 일정 추가 (키워드: 추가, 만들기, 생성, 등록, 잡아줘, 스케줄)
2. calendar_update - 기존 일정 수정 (키워드: 수정, 변경, 바꿔, 업데이트, 이동)
3. calendar_delete - 일정 삭제 (키워드: 삭제, 지워, 취소, 없애)
4. calendar_search - 일정 조회/검색 (키워드: 검색, 찾아, 조회, 확인, 뭐 있어, 언제)
5. calendar_copy - 일정 복사 (키워드: 복사, 복제, 같은 일정)
6. general_chat - 일반 대화 (일정과 무관한 대화)

반드시 다음 JSON 형식으로만 응답해주세요:
{{"intent": "분류결과", "confidence": 0.95, "reason": "분류 이유"}}

Confidence 기준:
- 0.9-1.0: 매우 명확한 의도 (명확한 키워드 포함)
- 0.7-0.9: 명확하지만 약간의 모호함 (문맥상 추론 가능)
- 0.5-0.7: 모호하지만 추론 가능 (여러 해석 가능)
- 0.3-0.5: 매우 모호함 (추측에 의존)
- 0.0-0.3: 분류 불가능 (일반 대화로 처리)
"""
                
                response = self.client.chat.completions.create(
                    model="gpt-4o-mini",
                    messages=[{"role": "user", "content": prompt}],
                    temperature=0.1,  # 일관된 분류를 위해 낮은 temperature
                    # response_format={"type": "json_object"}  # gpt-4-turbo 이상에서만 지원
                )
                
                response_text = response.choices[0].message.content.strip()
                print(f"의도 분류 응답: {response_text}")
                
                # 안전한 JSON 파싱
                fallback_data = {"intent": "general_chat", "confidence": 0.1, "reason": "파싱 실패"}
                result = safe_json_parse(response_text, fallback_data)
                
                # 커스터마이징 포인트: 신뢰도 임계값 조정 가능
                # 신뢰도가 낮으면 키워드 기반 보완
                if result.get('confidence', 0) < 0.5:  # 임계값: 0.5
                    result = keyword_based_classification(state['current_input'])
                
                state['intent'] = result.get('intent', 'general_chat')
                return state
                
            except Exception as e:
                print(f"의도 분류 중 오류: {str(e)}")
                state['intent'] = 'general_chat'
                return state
        
        def extract_information(state: CalendarState) -> CalendarState:
            """2단계: 정보 추출"""
            try:
                if state['intent'] == 'general_chat':
                    return state
                
                current_date = datetime.now(pytz.timezone('Asia/Seoul'))
                
                # 상대적 날짜 규칙 생성 (일요일 기준)
                date_rules = get_relative_date_rules(current_date)
                
                # 규칙을 텍스트로 변환
                rule_text = "\n".join([f'- "{key}" → {value}' for key, value in date_rules.items()])
                
                # 커스터마이징 포인트: 프롬프트에 도메인별 시간 규칙 추가 가능
                # 예: 병원이면 "진료 시간은 보통 30분", 회사면 "회의는 보통 1시간"
                prompt = f"""
현재 날짜: {current_date.strftime('%Y년 %m월 %d일 %A')}
현재 시간: {current_date.strftime('%H:%M')}

사용자 입력에서 일정 정보를 추출해주세요:
"{state['current_input']}"

상대적 표현 해석 규칙 (주의 시작: 일요일):
{rule_text}

반드시 다음 JSON 형식으로만 응답해주세요:
{{
    "title": "일정 제목 (필수)",
    "start_date": "YYYY-MM-DD (필수)",
    "start_time": "HH:MM",
    "end_date": "YYYY-MM-DD",
    "end_time": "HH:MM",
    "description": "상세 설명",
    "location": "장소",
    "attendees": ["email1@example.com"],
    "repeat_type": "none|daily|weekly|monthly|yearly",
    "repeat_interval": 1,
    "repeat_count": null,
    "repeat_until": null,
    "reminders": [15, 60],
    "all_day": false,
    "timezone": "Asia/Seoul",
    "priority": "normal|high|low",
    "category": "work|personal|meeting|appointment|other"
}}

추출 가이드라인:
1. 제목이 명시되지 않으면 사용자 입력에서 핵심 내용을 추출
2. 시간이 없으면 null로 설정
3. 종료 시간이 없으면 시작 시간 + 1시간
4. 반복은 명시적으로 언급된 경우만 설정
5. 우선순위는 "긴급", "중요" 등의 키워드로 판단
6. "다음주"는 다음 주 일요일(주의 시작)을 의미함
"""
                
                response = self.client.chat.completions.create(
                    model="gpt-4o-mini",
                    messages=[{"role": "user", "content": prompt}],
                    temperature=0.1
                )
                
                response_text = response.choices[0].message.content.strip()
                print(f"정보 추출 응답: {response_text}")
                
                # 기본값 설정
                default_info = get_default_event_info()
                default_info["title"] = extract_title_from_input(state['current_input'])
                
                # 안전한 JSON 파싱
                extracted_info = safe_json_parse(response_text, default_info)
                
                # 데이터 검증 및 보정
                extracted_info = validate_and_correct_info(extracted_info, current_date)
                
                state['extracted_info'] = extracted_info
                return state
                
            except Exception as e:
                print(f"정보 추출 중 오류: {str(e)}")
                state['extracted_info'] = get_default_event_info()
                return state
        
        def determine_action(state: CalendarState) -> CalendarState:
            """3단계: 작업 유형 결정"""
            try:
                intent = state.get('intent', 'general_chat')
                
                if intent == 'general_chat':
                    state['action_type'] = 'chat'
                elif intent in ['calendar_add', 'calendar_update', 'calendar_delete', 
                               'calendar_search', 'calendar_copy', 'calendar_move']:
                    state['action_type'] = intent
                else:
                    state['action_type'] = 'chat'
                
                return state
                
            except Exception as e:
                print(f"작업 유형 결정 중 오류: {str(e)}")
                state['action_type'] = 'chat'
                return state
        
        def execute_calendar_action(state: CalendarState) -> CalendarState:
            """4단계: 캘린더 작업 실행"""
            try:
                action_type = state.get('action_type')
                extracted_info = state.get('extracted_info', {})
                
                print("execute_calendar_action 실행")
                
                if action_type == 'calendar_add':
                    state['calendar_result'] = {
                        "success": True,
                        "event_id": "mock_event_id",
                        "message": "일정이 성공적으로 생성되었습니다.",
                        "event_data": extracted_info  # Flutter로 전달할 데이터
                    }
                    print("calendar_add 실행됨")
                    
                elif action_type == 'calendar_search':
                    # 커스터마이징 포인트: 실제 검색 로직 구현 필요
                    state['calendar_result'] = {"events": [], "search_query": state['current_input']}
                    
                elif action_type == 'calendar_update':
                    state['calendar_result'] = {
                        "success": True,
                        "event_id": "mock_event_id",
                        "message": "일정이 성공적으로 수정되었습니다.",
                        "updated_data": extracted_info
                    }
                        
                elif action_type == 'calendar_delete':
                    state['calendar_result'] = {
                        "success": True,
                        "message": "일정이 성공적으로 삭제되었습니다."
                    }
                
                return state
                
            except Exception as e:
                print(f"캘린더 작업 실행 중 오류: {str(e)}")
                state['calendar_result'] = {"error": f"작업 실행 중 오류 발생: {str(e)}"}
                return state
        
        def generate_response(state: CalendarState) -> CalendarState:
            """5단계: 응답 생성"""
            try:
                action_type = state.get('action_type', 'chat')
                calendar_result = state.get('calendar_result', {})
                extracted_info = state.get('extracted_info', {})
                
                if action_type == 'chat':
                    # 일반 대화
                    messages = state['messages'].copy()
                    
                    # 커스터마이징 포인트: 시스템 메시지로 AI 성격 조정 가능
                    if not any(msg.get("role") == "system" for msg in messages):
                        system_msg = {
                            "role": "system", 
                            "content": "당신은 친근하고 도움이 되는 AI 캘린더 어시스턴트입니다. 사용자의 일정을 관리하고 자연어로 대화하며 도움을 줍니다."
                        }
                        messages.insert(0, system_msg)
                    
                    messages.append({"role": "user", "content": state['current_input']})
                    
                    response = self.client.chat.completions.create(
                        model="gpt-4o-mini",
                        messages=messages,
                        temperature=0.7  # 자연스러운 대화를 위해 약간 높은 temperature
                    )
                    
                    state['current_output'] = response.choices[0].message.content
                    
                else:
                    # 캘린더 작업 결과 기반 응답
                    if calendar_result.get('success'):
                        if action_type == 'calendar_add':
                            title = extracted_info.get('title', '새 일정')
                            start_date = extracted_info.get('start_date', '')
                            start_time = extracted_info.get('start_time', '')
                            location = extracted_info.get('location', '')
                            
                            # 커스터마이징 포인트: 응답 형식 변경 가능
                            state['current_output'] = f"네! '{title}' 일정을 성공적으로 추가했습니다. 📅\n\n"
                            if start_date and start_time:
                                state['current_output'] += f"📅 날짜: {start_date}\n⏰ 시간: {start_time}\n"
                            elif start_date:
                                state['current_output'] += f"📅 날짜: {start_date}\n"
                            
                            if location:
                                state['current_output'] += f"📍 장소: {location}\n"
                            
                            state['current_output'] += "\n일정이 캘린더에 잘 저장되었어요! 😊"
                            
                        elif action_type == 'calendar_update':
                            title = extracted_info.get('title', '일정')
                            state['current_output'] = f"✅ '{title}' 일정을 성공적으로 수정했습니다!\n\n변경사항이 캘린더에 반영되었어요. 📝"
                            
                        elif action_type == 'calendar_delete':
                            state['current_output'] = "✅ 일정을 성공적으로 삭제했습니다!\n\n캘린더에서 해당 일정이 제거되었어요. 🗑️"
                            
                        elif action_type == 'calendar_search':
                            events = calendar_result.get('events', [])
                            if events:
                                event_list = "\n".join([f"📅 {event['summary']} - {event['start'].get('dateTime', event['start'].get('date', ''))}" for event in events[:5]])
                                state['current_output'] = f"🔍 찾은 일정들을 보여드릴게요:\n\n{event_list}"
                            else:
                                state['current_output'] = "🔍 검색하신 조건에 맞는 일정을 찾지 못했어요.\n\n다른 키워드로 다시 검색해보시겠어요?"
                    else:
                        error_msg = calendar_result.get('error', '알 수 없는 오류가 발생했습니다.')
                        state['current_output'] = f"❌ 앗, 문제가 발생했어요.\n\n{error_msg}\n\n다시 시도해주시거나 다른 방법으로 말씀해주세요."
                
                # 메시지 히스토리에 추가
                state['messages'].append({"role": "user", "content": state['current_input']})
                state['messages'].append({"role": "assistant", "content": state['current_output']})
                
                return state
                
            except Exception as e:
                print(f"응답 생성 중 오류: {str(e)}")
                state['current_output'] = "죄송해요, 응답을 생성하는 중에 문제가 발생했어요. 다시 시도해주세요. 😅"
                return state
        
        # 그래프 정의
        builder = StateGraph(CalendarState)
        
        # 노드 추가
        builder.add_node("classify_intent", classify_intent)
        builder.add_node("extract_information", extract_information)
        builder.add_node("determine_action", determine_action)
        builder.add_node("execute_calendar_action", execute_calendar_action)
        builder.add_node("generate_response", generate_response)
        
        # 엣지 정의
        builder.set_entry_point("classify_intent")
        builder.add_edge("classify_intent", "extract_information")
        builder.add_edge("extract_information", "determine_action")
        
        # 조건부 엣지: 일정 관련 작업인지 일반 대화인지에 따라 분기
        def should_execute_calendar_action(state: CalendarState) -> str:
            action_type = state.get('action_type', 'chat')
            if action_type == 'chat':
                return "generate_response"
            else:
                return "execute_calendar_action"
        
        builder.add_conditional_edges(
            "determine_action",
            should_execute_calendar_action,
            {
                "execute_calendar_action": "execute_calendar_action",
                "generate_response": "generate_response"
            }
        )
        
        builder.add_edge("execute_calendar_action", "generate_response")
        builder.add_edge("generate_response", END)
        
        # 그래프 컴파일
        return builder.compile()
    
    def _create_event_data(self, extracted_info: Dict[str, Any]) -> Dict[str, Any]:
        """추출된 정보를 Google Calendar API 형식으로 변환"""
        try:
            event_data = {
                'summary': extracted_info.get('title', '새 일정'),
                'description': extracted_info.get('description', ''),
                'location': extracted_info.get('location', ''),
            }
            
            # 시간 설정
            start_date = extracted_info.get('start_date')
            start_time = extracted_info.get('start_time')
            end_date = extracted_info.get('end_date', start_date)
            end_time = extracted_info.get('end_time')
            timezone = extracted_info.get('timezone', 'Asia/Seoul')
            
            if extracted_info.get('all_day', False):
                event_data['start'] = {'date': start_date}
                event_data['end'] = {'date': end_date}
            else:
                if start_time:
                    start_datetime = f"{start_date}T{start_time}:00"
                    event_data['start'] = {
                        'dateTime': start_datetime,
                        'timeZone': timezone
                    }
                
                if end_time:
                    end_datetime = f"{end_date}T{end_time}:00"
                    event_data['end'] = {
                        'dateTime': end_datetime,
                        'timeZone': timezone
                    }
                elif start_time:
                    # 종료 시간이 없으면 1시간 후로 설정
                    start_dt = datetime.strptime(f"{start_date} {start_time}", "%Y-%m-%d %H:%M")
                    end_dt = start_dt + timedelta(hours=1)
                    event_data['end'] = {
                        'dateTime': end_dt.strftime("%Y-%m-%dT%H:%M:00"),
                        'timeZone': timezone
                    }
            
            # 참석자 설정
            attendees = extracted_info.get('attendees', [])
            if attendees:
                event_data['attendees'] = [{'email': email} for email in attendees]
            
            # 알림 설정
            reminders = extracted_info.get('reminders', [15])
            if reminders:
                event_data['reminders'] = {
                    'useDefault': False,
                    'overrides': [
                        {'method': 'popup', 'minutes': minutes} for minutes in reminders
                    ]
                }
            
            return event_data
            
        except Exception as e:
            print(f"이벤트 데이터 생성 중 오류: {str(e)}")
            return {
                'summary': extracted_info.get('title', '새 일정'),
                'start': {'dateTime': datetime.now().isoformat(), 'timeZone': 'Asia/Seoul'},
                'end': {'dateTime': (datetime.now() + timedelta(hours=1)).isoformat(), 'timeZone': 'Asia/Seoul'}
            }
    
    async def process_calendar_input_with_workflow(
        self,
        user_input: str,
        chat_history: Optional[List[Dict[str, str]]] = None
    ) -> Dict[str, Any]:
        """워크플로우를 사용하여 캘린더 입력을 처리합니다."""
        try:
            if chat_history is None:
                chat_history = []
            
            # 시스템 메시지 추가
            if not any(msg.get("role") == "system" for msg in chat_history):
                chat_history.insert(0, {
                    "role": "system", 
                    "content": "당신은 AI 캘린더 어시스턴트입니다. 사용자의 일정을 관리하고 자연어로 대화하며 도움을 줍니다."
                })
            
            # 초기 상태 설정
            initial_state = {
                "messages": chat_history,
                "current_input": user_input,
                "current_output": None,
                "intent": None,
                "extracted_info": None,
                "action_type": None,
                "calendar_result": None,
                "context": None
            }
            
            # 워크플로우 실행
            result = await self._run_workflow_async(initial_state)
            
            return {
                "response": result["current_output"],
                "intent": result.get("intent"),
                "extracted_info": result.get("extracted_info"),
                "calendar_result": result.get("calendar_result"),
                "updated_history": result["messages"]
            }
            
        except Exception as e:
            print(f"워크플로우 처리 중 오류: {str(e)}")
            return {
                "response": "죄송합니다. 요청을 처리하는 중 오류가 발생했습니다.",
                "error": str(e)
            }
    
    async def _run_workflow_async(self, initial_state: CalendarState) -> CalendarState:
        """비동기적으로 워크플로우를 실행합니다."""
        # LangGraph는 동기 실행이므로 비동기 래퍼 사용
        import asyncio
        loop = asyncio.get_event_loop()
        return await loop.run_in_executor(None, self.workflow.invoke, initial_state)
    
    # =============================================================================
    # 기존 메서드들 (호환성 유지)
    # =============================================================================
    
    async def generate_response(
        self,
        messages: List[Dict[str, str]],
        temperature: float = 0.7,
        max_tokens: int = 1000
    ) -> str:
        """사용자 메시지에 대한 응답을 생성합니다."""
        try:
            response = self.client.chat.completions.create(
                model="gpt-4o-mini",
                messages=messages,
                temperature=temperature,
                max_tokens=max_tokens
            )
            return response.choices[0].message.content
        except Exception as e:
            print(f"LLM 요청 중 오류 발생: {str(e)}")
            return "죄송합니다, 응답을 생성하는 중 오류가 발생했습니다."

    async def process_calendar_input(
        self,
        user_input: str,
        context: Optional[List[str]] = None
    ) -> Dict[str, Any]:
        """사용자 입력을 처리하여 일정 정보를 추출합니다."""
        # 새로운 워크플로우 사용
        return await self.process_calendar_input_with_workflow(user_input)
    
    async def chat_with_graph(
        self,
        message: str,
        session_id: str = "default",
        chat_history: Optional[List[Dict[str, str]]] = None
    ) -> Dict[str, Any]:
        """LangGraph를 사용하여 대화형 응답을 생성합니다."""
        # 새로운 워크플로우 사용
        return await self.process_calendar_input_with_workflow(message, chat_history)

# =============================================================================
# 테스트 및 디버깅용 함수들
# =============================================================================

def test_relative_date_rules():
    """상대적 날짜 규칙 테스트 함수"""
    # 테스트 날짜들
    test_dates = [
        datetime(2025, 6, 9),   # 월요일
        datetime(2025, 6, 11),  # 수요일  
        datetime(2025, 6, 13),  # 금요일
        datetime(2025, 6, 15),  # 일요일
    ]
    
    for test_date in test_dates:
        print(f"\n{'='*50}")
        print(f"기준 날짜: {test_date.strftime('%Y년 %m월 %d일 %A')}")
        print(f"{'='*50}")
        
        rules = get_relative_date_rules(test_date)
        
        # 주요 규칙들만 출력
        key_rules = ['오늘', '내일', '모레', '다음주', '다음주 월요일', '다음주 일요일']
        for key in key_rules:
            if key in rules:
                print(f"{key}: {rules[key]}")

def test_llm_service():
    """
    LLM 서비스 테스트 함수
    
    커스터마이징 포인트: 테스트 케이스 추가/수정 가능
    """
    import asyncio
    
    async def run_tests():
        service = LLMService()
        
        # 테스트 케이스들 - 일요일 기준 주 계산 테스트 포함
        test_cases = [
            "내일 오후 3시에 팀 회의 일정 잡아줘",
            "다음주 월요일 오전 10시에 프레젠테이션",
            "다음주 일요일에 가족 모임",
            "오늘 일정 뭐 있어?",
            "회의 시간을 4시로 바꿔줘",
            "내일 미팅 취소해줘",
            "안녕하세요",
        ]
        
        for test_input in test_cases:
            print(f"\n{'='*50}")
            print(f"테스트 입력: {test_input}")
            print(f"{'='*50}")
            
            result = await service.process_calendar_input_with_workflow(test_input)
            
            print(f"의도: {result.get('intent')}")
            print(f"추출된 정보: {result.get('extracted_info')}")
            print(f"응답: {result.get('response')}")
    
    # 비동기 테스트 실행
    # asyncio.run(run_tests())

def debug_intent_classification(user_input: str):
    """
    의도 분류 디버깅 함수
    
    사용법: debug_intent_classification("내일 회의 일정 잡아줘")
    """
    result = keyword_based_classification(user_input)
    print(f"입력: {user_input}")
    print(f"키워드 분류 결과: {result}")
    
    # 제목 추출 테스트
    title = extract_title_from_input(user_input)
    print(f"추출된 제목: {title}")

def debug_time_parsing():
    """
    시간 파싱 디버깅 함수
    """
    current_date = datetime.now(pytz.timezone('Asia/Seoul'))
    test_info = {
        "start_date": current_date.strftime('%Y-%m-%d'),
        "start_time": "14:30",
        "end_time": None
    }
    
    validated = validate_and_correct_info(test_info, current_date)
    print(f"검증 전: {test_info}")
    print(f"검증 후: {validated}")

def debug_date_calculation():
    """
    날짜 계산 디버깅 함수 - 일요일 기준 주 계산 테스트
    """
    print("=== 일요일 기준 주 계산 테스트 ===")
    test_relative_date_rules()
    
    # 특정 입력에 대한 날짜 해석 테스트
    current_date = datetime.now(pytz.timezone('Asia/Seoul'))
    rules = get_relative_date_rules(current_date)
    
    print(f"\n현재 요일: {current_date.strftime('%A')}")
    print(f"다음주 = 다음 주 일요일: {rules.get('다음주')}")
    print(f"다음주 월요일: {rules.get('다음주 월요일')}")

# 사용 예시:
# if __name__ == "__main__":
#     debug_date_calculation()
#     test_llm_service()
#     debug_intent_classification("다음주 일요일에 가족 모임")
#     debug_time_parsing()