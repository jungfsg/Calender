from fastapi import APIRouter, Depends, HTTPException
from typing import Optional, List, Dict, Any
from pydantic import BaseModel
from app.services.llm_service import LLMService
from app.services.vector_store import VectorStoreService
from datetime import datetime

router = APIRouter()

class CalendarInput(BaseModel):
    text: str
    context_query: Optional[str] = None

class ChatInput(BaseModel):
    message: str
    session_id: Optional[str] = "default"
    weather_context: Optional[List[Dict[str, Any]]] = None

class CalendarResponse(BaseModel):
    calendar_data: Dict[str, Any]
    relevant_context: Optional[List[dict]] = None

class ChatResponse(BaseModel):
    response: str
    sources: Optional[List[Dict[str, Any]]] = None

@router.post("/process", response_model=CalendarResponse)
async def process_calendar_input(
    input_data: CalendarInput,
    llm_service: LLMService = Depends(lambda: LLMService()),
    vector_store: VectorStoreService = Depends(lambda: VectorStoreService())
):
    """
    텍스트 입력을 처리하여 일정 정보를 추출합니다.
    """
    # 관련 컨텍스트 검색
    context = None
    if input_data.context_query:
        search_results = await vector_store.search_context(input_data.context_query)
        context = [result["text"] for result in search_results]

    # LLM을 사용하여 일정 정보 추출
    calendar_data = await llm_service.process_calendar_input(
        input_data.text,
        context=context
    )

    return CalendarResponse(
        calendar_data=calendar_data,
        relevant_context=[{"text": ctx} for ctx in (context or [])]
    )

@router.post("/context")
async def add_context(
    texts: List[str],
    metadata: Optional[List[Dict[str, Any]]] = None,
    vector_store: VectorStoreService = Depends(lambda: VectorStoreService())
):
    """
    새로운 컨텍스트를 벡터 저장소에 추가합니다.
    """
    result = await vector_store.add_context(texts, metadata=metadata)
    return result

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
    
    # 날씨 정보를 포함한 질문 생성
    original_question = input_data.message
    
    # 시스템 정보와 날씨 정보를 포함한 질문 생성
    enhanced_question = f"""
현재 날짜: {formatted_date}
현재 요일: {day_of_week}

사용자 질문: {original_question}
"""

    if weather_info:
        enhanced_question += f"\n참고할 날씨 정보:\n{weather_info}"
    
    chain = await llm_service.create_conversational_chain(input_data.session_id)
    result = chain({"question": enhanced_question})
    
    return ChatResponse(
        response=result["answer"],
        sources=[{"text": doc.page_content, "metadata": doc.metadata} 
                for doc in result.get("source_documents", [])]
    )

def _translate_weather_condition(condition):
    """날씨 상태를 한글로 변환합니다."""
    translations = {
        'sunny': '맑음',
        'cloudy': '흐림',
        'rainy': '비',
        'snowy': '눈',
    }
    return translations.get(condition, condition) 