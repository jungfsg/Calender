from typing import Optional, List, Dict, Any, TypedDict, Annotated
from openai import OpenAI
from langgraph.graph import StateGraph, END
from app.core.config import get_settings
from app.services.google_calendar_service import GoogleCalendarService
from app.services.vector_store import VectorStoreService
import json
import re
from datetime import datetime, timedelta
from dateutil import parser
import pytz

settings = get_settings()

# 상태 정의
class CalendarState(TypedDict):
    messages: List[Dict[str, str]]
    current_input: str
    current_output: Optional[str]
    intent: Optional[str]  # 의도 분류 결과
    extracted_info: Optional[Dict[str, Any]]  # 추출된 정보
    action_type: Optional[str]  # 작업 유형
    calendar_result: Optional[Dict[str, Any]]  # 캘린더 API 결과
    context: Optional[List[str]]  # 벡터 검색 컨텍스트

class LLMService:
    def __init__(self):
        self.client = OpenAI(api_key=settings.OPENAI_API_KEY)
        self.calendar_service = GoogleCalendarService()
        self.vector_store = VectorStoreService()
        self.workflow = self._create_calendar_workflow()
        
    def _create_calendar_workflow(self):
        """
        AI 캘린더를 위한 LangGraph 워크플로우를 생성합니다.
        """
        
        def classify_intent(state: CalendarState) -> CalendarState:
            """1단계: 의도 분류 (일정 관련 여부 판단)"""
            try:
                prompt = f"""
사용자의 입력을 분석하여 의도를 분류해주세요.

사용자 입력: {state['current_input']}

다음 중 하나로 분류해주세요:
1. calendar_add - 새로운 일정 추가
2. calendar_update - 기존 일정 수정
3. calendar_delete - 일정 삭제
4. calendar_search - 일정 조회/검색
5. calendar_copy - 일정 복사
6. calendar_move - 일정 이동
7. general_chat - 일반 대화 (일정과 무관)

반드시 다음 JSON 형식으로만 응답해주세요:
{{"intent": "분류결과", "confidence": 0.95, "reason": "분류 이유"}}
"""
                
                response = self.client.chat.completions.create(
                    model="gpt-4o-mini",
                    messages=[{"role": "user", "content": prompt}],
                    temperature=0.1
                )
                
                response_text = response.choices[0].message.content.strip()
                print(f"의도 분류 응답: {response_text}")
                
                # JSON 파싱 시도
                try:
                    result = json.loads(response_text)
                    state['intent'] = result.get('intent', 'general_chat')
                except json.JSONDecodeError as e:
                    print(f"JSON 파싱 오류: {str(e)}")
                    print(f"응답 내용: {response_text}")
                    
                    # JSON이 아닌 경우 키워드 기반으로 의도 분류
                    user_input = state['current_input'].lower()
                    if any(keyword in user_input for keyword in ['추가', '만들', '생성', '등록', '일정']):
                        state['intent'] = 'calendar_add'
                    elif any(keyword in user_input for keyword in ['수정', '변경', '바꿔', '업데이트']):
                        state['intent'] = 'calendar_update'
                    elif any(keyword in user_input for keyword in ['삭제', '지워', '취소']):
                        state['intent'] = 'calendar_delete'
                    elif any(keyword in user_input for keyword in ['검색', '찾아', '조회', '확인']):
                        state['intent'] = 'calendar_search'
                    else:
                        state['intent'] = 'general_chat'
                    
                    print(f"키워드 기반 의도 분류 결과: {state['intent']}")
                
                return state
                
            except Exception as e:
                print(f"의도 분류 중 오류: {str(e)}")
                state['intent'] = 'general_chat'
                return state
        
        def extract_information(state: CalendarState) -> CalendarState:
            """2단계: 정보 추출 (날짜, 시간, 제목, 반복 여부, 참석자 등)"""
            try:
                if state['intent'] == 'general_chat':
                    return state
                
                current_date = datetime.now()
                
                prompt = f"""
현재 날짜: {current_date.strftime('%Y년 %m월 %d일 %A')}
현재 시간: {current_date.strftime('%H:%M')}

사용자 입력에서 일정 정보를 추출해주세요:
"{state['current_input']}"

반드시 다음 JSON 형식으로만 응답해주세요:
{{
    "title": "일정 제목",
    "start_date": "YYYY-MM-DD",
    "start_time": "HH:MM",
    "end_date": "YYYY-MM-DD", 
    "end_time": "HH:MM",
    "description": "상세 설명",
    "location": "장소",
    "attendees": ["참석자1@email.com", "참석자2@email.com"],
    "repeat_type": "none",
    "repeat_interval": 1,
    "repeat_count": null,
    "repeat_until": null,
    "reminders": [15, 60],
    "all_day": false,
    "timezone": "Asia/Seoul"
}}

날짜/시간이 명시되지 않은 경우 적절한 기본값을 설정해주세요.
상대적 표현(내일, 다음주 등)은 현재 날짜 기준으로 계산해주세요.
"""
                
                response = self.client.chat.completions.create(
                    model="gpt-4o-mini",
                    messages=[{"role": "user", "content": prompt}],
                    temperature=0.1
                )
                
                response_text = response.choices[0].message.content.strip()
                print(f"정보 추출 응답: {response_text}")
                
                # JSON 파싱 시도
                try:
                    extracted_info = json.loads(response_text)
                    state['extracted_info'] = extracted_info
                except json.JSONDecodeError as e:
                    print(f"정보 추출 JSON 파싱 오류: {str(e)}")
                    print(f"응답 내용: {response_text}")
                    
                    # JSON 파싱 실패 시 기본값 설정
                    tomorrow = current_date + timedelta(days=1)
                    default_info = {
                        "title": "새 일정",
                        "start_date": tomorrow.strftime('%Y-%m-%d'),
                        "start_time": "10:00",
                        "end_date": tomorrow.strftime('%Y-%m-%d'),
                        "end_time": "11:00",
                        "description": "",
                        "location": "",
                        "attendees": [],
                        "repeat_type": "none",
                        "repeat_interval": 1,
                        "repeat_count": None,
                        "repeat_until": None,
                        "reminders": [15],
                        "all_day": False,
                        "timezone": "Asia/Seoul"
                    }
                    
                    # 사용자 입력에서 제목 추출 시도
                    user_input = state['current_input']
                    if '일정' in user_input:
                        # 간단한 제목 추출
                        parts = user_input.split()
                        for i, part in enumerate(parts):
                            if '일정' in part and i > 0:
                                default_info['title'] = parts[i-1] + ' 일정'
                                break
                    
                    state['extracted_info'] = default_info
                    print(f"기본값으로 정보 설정: {default_info}")
                
                return state
                
            except Exception as e:
                print(f"정보 추출 중 오류: {str(e)}")
                state['extracted_info'] = {}
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
            """캘린더 작업 실행"""
            try:
                action_type = state.get('action_type')
                extracted_info = state.get('extracted_info', {})
                
                if action_type == 'calendar_add':
                    # 일정 추가
                    event_data = self._create_event_data(extracted_info)
                    result = self.calendar_service.create_event(event_data)
                    state['calendar_result'] = result
                    
                elif action_type == 'calendar_search':
                    # 일정 검색
                    query = extracted_info.get('title', '')
                    events = self.calendar_service.search_events(query=query)
                    state['calendar_result'] = {"events": events}
                    
                elif action_type == 'calendar_update':
                    # 일정 수정 (기존 일정 검색 후 수정)
                    query = extracted_info.get('title', '')
                    events = self.calendar_service.search_events(query=query, max_results=1)
                    if events:
                        event_id = events[0]['id']
                        event_data = self._create_event_data(extracted_info)
                        result = self.calendar_service.update_event(event_id, event_data)
                        state['calendar_result'] = result
                    else:
                        state['calendar_result'] = {"error": "수정할 일정을 찾을 수 없습니다."}
                        
                elif action_type == 'calendar_delete':
                    # 일정 삭제
                    query = extracted_info.get('title', '')
                    events = self.calendar_service.search_events(query=query, max_results=1)
                    if events:
                        event_id = events[0]['id']
                        result = self.calendar_service.delete_event(event_id)
                        state['calendar_result'] = result
                    else:
                        state['calendar_result'] = {"error": "삭제할 일정을 찾을 수 없습니다."}
                
                return state
                
            except Exception as e:
                print(f"캘린더 작업 실행 중 오류: {str(e)}")
                state['calendar_result'] = {"error": f"작업 실행 중 오류 발생: {str(e)}"}
                return state
        
        def generate_response(state: CalendarState) -> CalendarState:
            """4단계: 응답 생성"""
            try:
                action_type = state.get('action_type', 'chat')
                calendar_result = state.get('calendar_result', {})
                extracted_info = state.get('extracted_info', {})
                
                if action_type == 'chat':
                    # 일반 대화
                    messages = state['messages'].copy()
                    messages.append({"role": "user", "content": state['current_input']})
                    
                    response = self.client.chat.completions.create(
                        model="gpt-4o-mini",
                        messages=messages,
                        temperature=0.7
                )
                
                state['current_output'] = response.choices[0].message.content
                    
                else:
                    # 캘린더 작업 결과 기반 응답
                    if calendar_result.get('success'):
                        if action_type == 'calendar_add':
                            state['current_output'] = f"✅ 일정이 성공적으로 추가되었습니다!\n\n📅 제목: {extracted_info.get('title', '')}\n🕐 시간: {extracted_info.get('start_date', '')} {extracted_info.get('start_time', '')}\n🔗 링크: {calendar_result.get('event_link', '')}"
                        elif action_type == 'calendar_update':
                            state['current_output'] = f"✅ 일정이 성공적으로 수정되었습니다!\n\n📅 제목: {extracted_info.get('title', '')}"
                        elif action_type == 'calendar_delete':
                            state['current_output'] = f"✅ 일정이 성공적으로 삭제되었습니다!"
                        elif action_type == 'calendar_search':
                            events = calendar_result.get('events', [])
                            if events:
                                event_list = "\n".join([f"📅 {event['summary']} - {event['start'].get('dateTime', event['start'].get('date', ''))}" for event in events[:5]])
                                state['current_output'] = f"🔍 검색된 일정들:\n\n{event_list}"
                            else:
                                state['current_output'] = "검색된 일정이 없습니다."
                    else:
                        error_msg = calendar_result.get('error', '알 수 없는 오류가 발생했습니다.')
                        state['current_output'] = f"❌ {error_msg}"
                
                # 메시지 히스토리에 추가
                state['messages'].append({"role": "user", "content": state['current_input']})
                state['messages'].append({"role": "assistant", "content": state['current_output']})
                
                return state
                
            except Exception as e:
                print(f"응답 생성 중 오류: {str(e)}")
                state['current_output'] = "죄송합니다. 응답을 생성하는 중 오류가 발생했습니다."
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
            
            # 반복 설정
            repeat_type = extracted_info.get('repeat_type', 'none')
            if repeat_type != 'none':
                rrule = self.calendar_service.create_rrule(
                    repeat_type,
                    interval=extracted_info.get('repeat_interval', 1),
                    count=extracted_info.get('repeat_count'),
                    until=extracted_info.get('repeat_until')
                )
                event_data['recurrence'] = [f"RRULE:{rrule}"]
            
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
    
    # 기존 메서드들 유지
    async def generate_response(
        self,
        messages: List[Dict[str, str]],
        temperature: float = 0.7,
        max_tokens: int = 1000
    ) -> str:
        """
        사용자 메시지에 대한 응답을 생성합니다.
        """
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
        """
        사용자 입력을 처리하여 일정 정보를 추출합니다.
        """
        # 새로운 워크플로우 사용
        return await self.process_calendar_input_with_workflow(user_input)
    
    async def chat_with_graph(
        self,
        message: str,
        session_id: str = "default",
        chat_history: Optional[List[Dict[str, str]]] = None
    ) -> Dict[str, Any]:
        """
        LangGraph를 사용하여 대화형 응답을 생성합니다.
        """
        # 새로운 워크플로우 사용
        return await self.process_calendar_input_with_workflow(message, chat_history) 