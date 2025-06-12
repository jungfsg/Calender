from fastapi import APIRouter, Depends, HTTPException
from typing import Optional, List, Dict, Any
from pydantic import BaseModel
from app.services.llm_service import LLMService
# from app.services.vector_store import VectorStoreService
from app.services.event_storage_service import EventStorageService
from datetime import datetime

router = APIRouter()

class CalendarInput(BaseModel):
    text: str
    context_query: Optional[str] = None

class ChatInput(BaseModel):
    message: str
    session_id: Optional[str] = "default"
    weather_context: Optional[List[Dict[str, Any]]] = None

class OCRTextInput(BaseModel):
    text: str
    metadata: Optional[Dict[str, Any]] = None

class CalendarResponse(BaseModel):
    calendar_data: Dict[str, Any]
    relevant_context: Optional[List[dict]] = None

class ChatResponse(BaseModel):
    response: str
    sources: Optional[List[Dict[str, Any]]] = None

class AICalendarInput(BaseModel):
    message: str
    session_id: Optional[str] = "default"
    chat_history: Optional[List[Dict[str, str]]] = None

class AICalendarResponse(BaseModel):
    response: str
    intent: Optional[str] = None
    extracted_info: Optional[Dict[str, Any]] = None
    calendar_result: Optional[Dict[str, Any]] = None
    updated_history: Optional[List[Dict[str, str]]] = None

class EventSearchInput(BaseModel):
    query: Optional[str] = None
    time_min: Optional[str] = None
    time_max: Optional[str] = None
    max_results: Optional[int] = 10

class EventCreateInput(BaseModel):
    summary: str
    start_datetime: str
    end_datetime: str
    description: Optional[str] = None
    location: Optional[str] = None
    attendees: Optional[List[str]] = None
    timezone: Optional[str] = "Asia/Seoul"

@router.post("/ai-chat", response_model=AICalendarResponse)
async def ai_calendar_chat(
    input_data: AICalendarInput,
    llm_service: LLMService = Depends(lambda: LLMService())
):
    """
    AI 캘린더 워크플로우를 사용하여 자연어로 일정을 관리합니다.
    의도 분류, 정보 추출, 작업 실행, 응답 생성을 포함한 완전한 워크플로우를 제공합니다.
    """
    try:
        result = await llm_service.process_calendar_input_with_workflow(
            user_input=input_data.message,
            chat_history=input_data.chat_history
        )
        
        return AICalendarResponse(
            response=result["response"],
            intent=result.get("intent"),
            extracted_info=result.get("extracted_info"),
            calendar_result=result.get("calendar_result"),
            updated_history=result.get("updated_history")
        )
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"AI 캘린더 처리 중 오류 발생: {str(e)}")

@router.get("/events/search")
async def search_events(
    query: Optional[str] = None,
    time_min: Optional[str] = None,
    time_max: Optional[str] = None,
    max_results: Optional[int] = 10,
    calendar_service: EventStorageService = Depends(lambda: EventStorageService())
):
    """
    로컬 저장소에서 일정을 검색합니다.
    """
    try:
        events = calendar_service.search_events(query=query)
        
        # 시간 범위 필터링
        if time_min or time_max:
            filtered_events = []
            for event in events:
                event_start = event.get("start_date")
                event_end = event.get("end_date")
                
                if time_min and event_start < time_min:
                    continue
                if time_max and event_end > time_max:
                    continue
                    
                filtered_events.append(event)
            events = filtered_events
        
        # 결과 수 제한
        events = events[:max_results]
        
        return {
            "success": True,
            "events": events,
            "count": len(events)
        }
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"일정 검색 중 오류 발생: {str(e)}")

@router.post("/events/create")
async def create_event(
    event_data: EventCreateInput,
    calendar_service: EventStorageService = Depends(lambda: EventStorageService())
):
    """
    로컬 저장소에 새로운 일정을 생성합니다.
    """
    try:
        # 입력 데이터를 로컬 저장소 형식으로 변환
        calendar_event = {
            'title': event_data.summary,
            'description': event_data.description or '',
            'location': event_data.location or '',
            'start_date': event_data.start_datetime,
            'end_date': event_data.end_datetime,
            'timezone': event_data.timezone,
            'attendees': event_data.attendees or []
        }
        
        result = calendar_service.create_event(calendar_event)
        
        return {
            "success": True,
            "message": "일정이 성공적으로 생성되었습니다.",
            "event_id": result.get('id'),
            "event": result
        }
            
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"일정 생성 중 오류 발생: {str(e)}")

@router.put("/events/{event_id}")
async def update_event(
    event_id: str,
    event_data: Dict[str, Any],
    calendar_service: EventStorageService = Depends(lambda: EventStorageService())
):
    """
    기존 일정을 수정합니다.
    """
    try:
        result = calendar_service.update_event(event_id, event_data)
        
        if result:
            return {
                "success": True,
                "message": "일정이 성공적으로 수정되었습니다.",
                "event_id": result.get('id'),
                "event": result
            }
        else:
            raise HTTPException(status_code=404, detail='일정을 찾을 수 없습니다.')
            
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"일정 수정 중 오류 발생: {str(e)}")

@router.delete("/events/{event_id}")
async def delete_event(
    event_id: str,
    calendar_service: EventStorageService = Depends(lambda: EventStorageService())
):
    """
    일정을 삭제합니다.
    """
    try:
        success = calendar_service.delete_event(event_id)
        
        if success:
            return {
                "success": True,
                "message": "일정이 성공적으로 삭제되었습니다."
            }
        else:
            raise HTTPException(status_code=404, detail='일정을 찾을 수 없습니다.')
            
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"일정 삭제 중 오류 발생: {str(e)}")

@router.post("/events/{event_id}/copy")
async def copy_event(
    event_id: str,
    destination_calendar_id: Optional[str] = "primary",
    calendar_service: EventStorageService = Depends(lambda: EventStorageService())
):
    """
    일정을 복사합니다.
    """
    try:
        result = calendar_service.copy_event(event_id, destination_calendar_id)
        
        if result.get('success'):
            return {
                "success": True,
                "message": "일정이 성공적으로 복사되었습니다.",
                "new_event_id": result.get('event_id')
            }
        else:
            raise HTTPException(status_code=400, detail=result.get('error', '일정 복사에 실패했습니다.'))
            
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"일정 복사 중 오류 발생: {str(e)}")

@router.post("/events/{event_id}/move")
async def move_event(
    event_id: str,
    destination_calendar_id: str,
    calendar_service: EventStorageService = Depends(lambda: EventStorageService())
):
    """
    일정을 다른 캘린더로 이동합니다.
    """
    try:
        result = calendar_service.move_event(event_id, destination_calendar_id)
        
        if result.get('success'):
            return {
                "success": True,
                "message": "일정이 성공적으로 이동되었습니다.",
                "event_id": result.get('event_id')
            }
        else:
            raise HTTPException(status_code=400, detail=result.get('error', '일정 이동에 실패했습니다.'))
            
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"일정 이동 중 오류 발생: {str(e)}")

@router.get("/events/{event_id}/conflicts")
async def check_event_conflicts(
    event_id: str,
    calendar_service: EventStorageService = Depends(lambda: EventStorageService())
):
    """
    특정 일정의 충돌을 확인합니다.
    """
    try:
        # 먼저 해당 일정 정보를 가져옴
        events = calendar_service.search_events(query="", max_results=100)
        target_event = None
        
        for event in events:
            if event['id'] == event_id:
                target_event = event
                break
        
        if not target_event:
            raise HTTPException(status_code=404, detail="일정을 찾을 수 없습니다.")
        
        # 충돌 검사
        conflicts = calendar_service.check_conflicts(
            target_event['start'],
            target_event['end']
        )
        
        # 자기 자신은 제외
        conflicts = [c for c in conflicts if c['id'] != event_id]
        
        return {
            "success": True,
            "conflicts": conflicts,
            "conflict_count": len(conflicts)
        }
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"충돌 검사 중 오류 발생: {str(e)}")

# @router.post("/process", response_model=CalendarResponse)
# async def process_calendar_input(
#     input_data: CalendarInput,
#     llm_service: LLMService = Depends(lambda: LLMService()),
#     vector_store: VectorStoreService = Depends(lambda: VectorStoreService())
# ):
#     """
#     텍스트 입력을 처리하여 일정 정보를 추출합니다.
#     """
#     # 관련 컨텍스트 검색
#     context = None
#     if input_data.context_query:
#         search_results = await vector_store.search_context(input_data.context_query)
#         context = [result["text"] for result in search_results]

#     # LLM을 사용하여 일정 정보 추출
#     calendar_data = await llm_service.process_calendar_input(
#         input_data.text,
#         context=context
#     )

#     return CalendarResponse(
#         calendar_data=calendar_data,
#         relevant_context=[{"text": ctx} for ctx in (context or [])]
#     )

# @router.post("/context")
# async def add_context(
#     texts: List[str],
#     metadata: Optional[List[Dict[str, Any]]] = None,
#     vector_store: VectorStoreService = Depends(lambda: VectorStoreService())
# ):
#     """
#     새로운 컨텍스트를 벡터 저장소에 추가합니다.
#     """
#     result = await vector_store.add_context(texts, metadata=metadata)
#     return result

@router.post("/chat", response_model=ChatResponse)
async def chat_with_context(
    input_data: ChatInput,
    llm_service: LLMService = Depends(lambda: LLMService())
):
    """
    대화형 방식으로 컨텍스트를 기반으로 응답합니다.
    """
    # 현재 날짜와 요일 정보
    current_date = datetime.now()
    day_of_week = current_date.strftime('%A')  # 요일 (Monday, Tuesday 등)
    formatted_date = current_date.strftime('%Y년 %m월 %d일')
    
    # 날씨 정보가 있는 경우 포맷팅
    weather_info = ""
    if input_data.weather_context:
        weather_info = "현재 날씨 정보:\n"
        for weather in input_data.weather_context:
            condition_kr = _translate_weather_condition(weather['condition'])
            weather_info += f"날짜: {weather['date']}, 상태: {condition_kr}, 온도: {weather['temperature']}°C\n"
    
    # 시스템 정보와 날씨 정보를 포함한 질문 생성
    original_question = input_data.message
    enhanced_question = f"""
현재 날짜: {formatted_date}
현재 요일: {day_of_week}

사용자 질문: {original_question}
"""

    if weather_info:
        enhanced_question += f"\n참고할 날씨 정보:\n{weather_info}"
    
    # LangGraph 워크플로우를 사용하여 응답 생성
    result = await llm_service.chat_with_graph(
        message=enhanced_question,
        session_id=input_data.session_id
    )
    
    return ChatResponse(
        response=result["response"],
        sources=[]  # 벡터 검색 결과가 없으므로 빈 리스트 반환
    )

# @router.post("/ocr_text")
# async def store_ocr_text(
#     input_data: OCRTextInput,
#     vector_store: VectorStoreService = Depends(lambda: VectorStoreService())
# ):
#     """
#     OCR로 추출한 텍스트를 벡터 저장소에 저장합니다.
#     """
#     # 단일 텍스트를 리스트로 변환하여 VectorStoreService.add_context 메소드 호출
#     metadata = [input_data.metadata] if input_data.metadata else [{"source": "ocr", "timestamp": datetime.now().isoformat()}]
#     result = await vector_store.add_context([input_data.text], metadata=metadata)
#     return result

def _translate_weather_condition(condition):
    """날씨 상태를 한글로 변환합니다."""
    translations = {
        'sunny': '맑음',
        'cloudy': '흐림',
        'rainy': '비',
        'snowy': '눈',
    }
    return translations.get(condition, condition)