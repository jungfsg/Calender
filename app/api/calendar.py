from fastapi import APIRouter, Depends, HTTPException
from typing import Optional, List, Dict, Any
from pydantic import BaseModel
from app.services.llm_service import LLMService
from app.services.vector_store import VectorStoreService

router = APIRouter()

class CalendarInput(BaseModel):
    text: str
    context_query: Optional[str] = None

class ChatInput(BaseModel):
    message: str
    session_id: Optional[str] = "default"

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
    chain = await llm_service.create_conversational_chain(input_data.session_id)
    result = chain({"question": input_data.message})
    
    return ChatResponse(
        response=result["answer"],
        sources=[{"text": doc.page_content, "metadata": doc.metadata} 
                for doc in result.get("source_documents", [])]
    ) 