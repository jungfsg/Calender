# app/services/llm_service.py
from typing import Optional, List, Dict, Any, TypedDict
from openai import OpenAI
from langgraph.graph import StateGraph, END
from app.core.config import get_settings
from app.services.google_calendar_service import GoogleCalendarService
import json
from datetime import datetime, timedelta

settings = get_settings()

# 간단한 상태 정의
class CalendarState(TypedDict):
    messages: List[Dict[str, str]]
    user_input: str
    is_event_related: Optional[bool]
    event_info: Optional[Dict[str, Any]]
    action_type: Optional[str]
    api_result: Optional[Dict[str, Any]]
    final_response: Optional[str]
    context: Optional[List[str]]  # 나중에 벡터DB 결과가 들어갈 자리

class LLMService:
    def __init__(self):
        self.client = OpenAI(api_key=settings.OPENAI_API_KEY)
        self.calendar_service = GoogleCalendarService()
        # self.vector_store = VectorStoreService()  # 나중에 추가할 부분
        self.workflow = self._create_simple_workflow()
    
    def _create_simple_workflow(self):
        """단순한 3단계 워크플로우"""
        
        def step1_check_event_related(state: CalendarState) -> CalendarState:
            """1단계: 이벤트 관련 여부 판단"""
            try:
                # 벡터 검색 부분 - 나중에 활성화
                state['context'] = []  # 현재는 빈 컨텍스트
                
                # TODO: 나중에 벡터DB 추가시
                # try:
                #     context_results = self.vector_store.search_context(query=state['user_input'], n_results=3)
                #     state['context'] = [result['text'] for result in context_results]
                # except Exception as e:
                #     print(f"벡터 검색 오류: {str(e)}")
                #     state['context'] = []
                
                # 컨텍스트를 포함한 프롬프트 (구조는 유지)
                context_text = "\n".join(state['context']) if state['context'] else "관련 컨텍스트 없음"
                
                prompt = f"""
관련 컨텍스트:
{context_text}

사용자 입력이 캘린더 이벤트와 관련된지 판단하세요.

입력: "{state['user_input']}"

이벤트 관련 예시:
- "내일 3시에 회의 일정 잡아줘"
- "회의 시간을 4시로 변경해줘"
- "오늘 일정 뭐가 있지?"
- "점심약속 삭제해줘"

일반 대화 예시:
- "안녕하세요"
- "날씨가 어때?"
- "고마워"

JSON으로만 응답: {{"is_event_related": true/false}}
"""
                
                response = self.client.chat.completions.create(
                    model="gpt-4o-mini",
                    messages=[{"role": "user", "content": prompt}],
                    temperature=0.1
                )
                
                try:
                    result = json.loads(response.choices[0].message.content.strip())
                    state['is_event_related'] = result.get('is_event_related', False)
                except json.JSONDecodeError:
                    # 키워드 기반 폴백
                    keywords = ['일정', '약속', '회의', '미팅', '스케줄', '캘린더', 
                              '추가', '삭제', '수정', '변경', '예약', '등록', '찾아', '조회']
                    state['is_event_related'] = any(kw in state['user_input'] for kw in keywords)
                
                return state
                
            except Exception as e:
                print(f"이벤트 판단 오류: {str(e)}")
                state['is_event_related'] = False
                return state
        
        def step2_extract_and_execute(state: CalendarState) -> CalendarState:
            """2단계: 이벤트 정보 추출 + 액션 실행"""
            if not state.get('is_event_related'):
                return state  # 이벤트 관련이 아니면 스킵
                
            try:
                current_time = datetime.now()
                context_text = "\n".join(state.get('context', []))
                
                # 컨텍스트를 포함한 정보 추출
                prompt = f"""
관련 컨텍스트:
{context_text}

현재: {current_time.strftime('%Y년 %m월 %d일 %A %H:%M')}

사용자 요청에서 정보를 추출하세요:
"{state['user_input']}"

JSON 형식으로 응답:
{{
    "action": "create|update|delete|search|list",
    "event_info": {{
        "title": "제목",
        "start_date": "YYYY-MM-DD",
        "start_time": "HH:MM",
        "end_date": "YYYY-MM-DD",
        "end_time": "HH:MM",
        "description": "설명",
        "location": "장소",
        "attendees": ["email@example.com"],
        "all_day": false
    }}
}}

액션 가이드:
- create: "잡아줘", "만들어", "추가"
- update: "바꿔", "수정", "변경"
- delete: "지워", "삭제", "취소"
- search: "찾아", "검색", "언제"
- list: "뭐가 있어", "일정 알려줘"

날짜 처리:
- "내일" → {(current_time + timedelta(days=1)).strftime('%Y-%m-%d')}
- "다음주" → {(current_time + timedelta(weeks=1)).strftime('%Y-%m-%d')}
- 시간 없으면 기본 10:00-11:00
"""
                
                response = self.client.chat.completions.create(
                    model="gpt-4o-mini",
                    messages=[{"role": "user", "content": prompt}],
                    temperature=0.1
                )
                
                try:
                    result = json.loads(response.choices[0].message.content.strip())
                    state['action_type'] = result.get('action', 'create')
                    state['event_info'] = result.get('event_info', {})
                except json.JSONDecodeError:
                    # 기본값 설정
                    tomorrow = current_time + timedelta(days=1)
                    state['action_type'] = 'create'
                    state['event_info'] = {
                        "title": "새 일정",
                        "start_date": tomorrow.strftime('%Y-%m-%d'),
                        "start_time": "10:00",
                        "end_date": tomorrow.strftime('%Y-%m-%d'),
                        "end_time": "11:00",
                        "description": "",
                        "location": "",
                        "attendees": [],
                        "all_day": False
                    }
                
                # Google Calendar API 실행
                action = state['action_type']
                event_info = state['event_info']
                
                if action == 'create':
                    event_data = self._to_google_format(event_info)
                    result = self.calendar_service.create_event(event_data)
                    state['api_result'] = result
                    
                    # TODO: 나중에 벡터DB 추가시
                    # if result.get('success'):
                    #     self.vector_store.add_context(
                    #         texts=[f"일정 '{event_info['title']}'이 {event_info['start_date']} {event_info['start_time']}에 생성됨"],
                    #         metadata=[{"action": "create", "date": current_time.isoformat()}]
                    #     )
                    
                elif action == 'update':
                    events = self.calendar_service.search_events(query=event_info.get('title', ''), max_results=1)
                    if events:
                        event_data = self._to_google_format(event_info)
                        result = self.calendar_service.update_event(events[0]['id'], event_data)
                        state['api_result'] = result
                    else:
                        state['api_result'] = {"error": "수정할 일정을 찾을 수 없습니다"}
                        
                elif action == 'delete':
                    events = self.calendar_service.search_events(query=event_info.get('title', ''), max_results=1)
                    if events:
                        result = self.calendar_service.delete_event(events[0]['id'])
                        state['api_result'] = result
                    else:
                        state['api_result'] = {"error": "삭제할 일정을 찾을 수 없습니다"}
                        
                elif action == 'search':
                    events = self.calendar_service.search_events(query=event_info.get('title', ''))
                    state['api_result'] = {"events": events}
                    
                elif action == 'list':
                    events = self.calendar_service.list_events(max_results=10)
                    state['api_result'] = {"events": events}
                
                return state
                
            except Exception as e:
                print(f"정보 추출 및 실행 오류: {str(e)}")
                state['api_result'] = {"error": f"처리 중 오류: {str(e)}"}
                return state
        
        def step3_generate_final_response(state: CalendarState) -> CalendarState:
            """3단계: 최종 응답 생성"""
            try:
                if not state.get('is_event_related'):
                    # 일반 대화 - 컨텍스트 포함
                    messages = state['messages'].copy()
                    
                    # 컨텍스트가 있으면 시스템 메시지에 포함 (나중에 활용)
                    if state.get('context'):
                        context_text = "\n".join(state['context'])
                        system_message = f"당신은 AI 캘린더 어시스턴트입니다. 다음 컨텍스트를 참고하세요:\n{context_text}"
                    else:
                        system_message = "당신은 AI 캘린더 어시스턴트입니다."
                    
                    messages.append({"role": "system", "content": system_message})
                    messages.append({"role": "user", "content": state['user_input']})
                    
                    response = self.client.chat.completions.create(
                        model="gpt-4o-mini",
                        messages=messages,
                        temperature=0.7
                    )
                    
                    state['final_response'] = response.choices[0].message.content
                    
                else:
                    # 이벤트 관련 응답
                    action = state.get('action_type')
                    api_result = state.get('api_result', {})
                    event_info = state.get('event_info', {})
                    
                    if api_result.get('success'):
                        if action == 'create':
                            state['final_response'] = f"✅ '{event_info.get('title', '')}' 일정을 {event_info.get('start_date', '')} {event_info.get('start_time', '')}에 추가했습니다!"
                        elif action == 'update':
                            state['final_response'] = f"✅ '{event_info.get('title', '')}' 일정을 수정했습니다!"
                        elif action == 'delete':
                            state['final_response'] = f"✅ '{event_info.get('title', '')}' 일정을 삭제했습니다!"
                        elif action in ['search', 'list']:
                            events = api_result.get('events', [])
                            if events:
                                event_list = "\n".join([
                                    f"📅 {event['summary']} - {event['start'].get('dateTime', event['start'].get('date'))}" 
                                    for event in events[:5]
                                ])
                                state['final_response'] = f"🔍 찾은 일정:\n\n{event_list}"
                            else:
                                state['final_response'] = "해당 일정을 찾을 수 없습니다."
                    else:
                        error_msg = api_result.get('error', '오류가 발생했습니다')
                        state['final_response'] = f"❌ {error_msg}"
                
                # 히스토리 업데이트
                state['messages'].append({"role": "user", "content": state['user_input']})
                state['messages'].append({"role": "assistant", "content": state['final_response']})
                
                return state
                
            except Exception as e:
                print(f"응답 생성 오류: {str(e)}")
                state['final_response'] = "응답 생성 중 오류가 발생했습니다."
                return state
        
        # LangGraph 워크플로우 구성
        builder = StateGraph(CalendarState)
        
        # 3단계 노드
        builder.add_node("check_event", step1_check_event_related)
        builder.add_node("extract_execute", step2_extract_and_execute)
        builder.add_node("respond", step3_generate_final_response)
        
        # 순차 실행
        builder.set_entry_point("check_event")
        builder.add_edge("check_event", "extract_execute")
        builder.add_edge("extract_execute", "respond")
        builder.add_edge("respond", END)
        
        return builder.compile()
    
    def _to_google_format(self, event_info: Dict[str, Any]) -> Dict[str, Any]:
        """이벤트 정보를 Google Calendar API 형식으로 변환"""
        event_data = {
            'summary': event_info.get('title', '새 일정'),
            'description': event_info.get('description', ''),
            'location': event_info.get('location', ''),
        }
        
        # 시간 설정
        if event_info.get('all_day', False):
            event_data['start'] = {'date': event_info.get('start_date')}
            event_data['end'] = {'date': event_info.get('end_date', event_info.get('start_date'))}
        else:
            start_date = event_info.get('start_date')
            start_time = event_info.get('start_time')
            end_date = event_info.get('end_date', start_date)
            end_time = event_info.get('end_time')
            
            if start_date and start_time:
                start_datetime = f"{start_date}T{start_time}:00"
                event_data['start'] = {
                    'dateTime': start_datetime,
                    'timeZone': 'Asia/Seoul'
                }
            
            if end_date and end_time:
                end_datetime = f"{end_date}T{end_time}:00"
                event_data['end'] = {
                    'dateTime': end_datetime,
                    'timeZone': 'Asia/Seoul'
                }
            elif start_date and start_time:
                # 종료시간 없으면 1시간 후
                start_dt = datetime.strptime(f"{start_date} {start_time}", "%Y-%m-%d %H:%M")
                end_dt = start_dt + timedelta(hours=1)
                event_data['end'] = {
                    'dateTime': end_dt.strftime("%Y-%m-%dT%H:%M:00"),
                    'timeZone': 'Asia/Seoul'
                }
        
        # 참석자
        if event_info.get('attendees'):
            event_data['attendees'] = [{'email': email} for email in event_info['attendees']]
        
        return event_data
    
    async def process_user_input(
        self,
        user_input: str,
        chat_history: Optional[List[Dict[str, str]]] = None
    ) -> Dict[str, Any]:
        """
        Flutter에서 온 사용자 입력 처리 - 메인 엔드포인트
        """
        try:
            if chat_history is None:
                chat_history = []
            
            # 시스템 메시지 추가
            if not any(msg.get("role") == "system" for msg in chat_history):
                chat_history.insert(0, {
                    "role": "system",
                    "content": "당신은 AI 캘린더 어시스턴트입니다. 사용자의 일정을 자연어로 관리해드립니다."
                })
            
            # 워크플로우 초기 상태
            initial_state = {
                "messages": chat_history,
                "user_input": user_input,
                "is_event_related": None,
                "event_info": None,
                "action_type": None,
                "api_result": None,
                "final_response": None,
                "context": None
            }
            
            # LangGraph 워크플로우 실행 (동기)
            final_state = self.workflow.invoke(initial_state)
            
            return {
                "response": final_state["final_response"],
                "is_event_related": final_state.get("is_event_related", False),
                "updated_history": final_state["messages"]
            }
            
        except Exception as e:
            print(f"사용자 입력 처리 오류: {str(e)}")
            return {
                "response": "죄송합니다. 처리 중 오류가 발생했습니다.",
                "is_event_related": False,
                "updated_history": chat_history or []
            }