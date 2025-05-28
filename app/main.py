from fastapi import FastAPI, HTTPException, UploadFile, File, Form
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from typing import Optional, List, Dict, Any
from app.core.config import get_settings
from app.services.llm_service import LLMService

settings = get_settings()

app = FastAPI(
    title=settings.PROJECT_NAME,
    openapi_url=f"{settings.API_V1_STR}/openapi.json"
)

# CORS 미들웨어 설정
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # 실제 운영 환경에서는 구체적인 도메인을 지정해야 합니다
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# 요청/응답 모델
class ChatRequest(BaseModel):
    message: str
    session_id: Optional[str] = "default"
    chat_history: Optional[List[Dict[str, str]]] = None
    weather_context: Optional[List[Dict[str, Any]]] = None  # Flutter 날씨 데이터
    source: Optional[str] = "text"  # "text", "ocr", "voice" 등 출처 표시

class ChatResponse(BaseModel):
    response: str
    is_event_related: bool
    session_id: str

# LLM 서비스 인스턴스
llm_service = LLMService()

@app.get("/")
async def root():
    return {"message": "AI Calendar Assistant API"}

@app.post("/api/v1/calendar/chat", response_model=ChatResponse)
async def calendar_chat_endpoint(request: ChatRequest):
    """
    Flutter에서 자연어 텍스트를 받아 AI로 처리하는 메인 엔드포인트
    텍스트, OCR, 음성 모든 입력을 통합 처리
    """
    try:
        # 날씨 컨텍스트가 있으면 처리
        additional_context = ""
        if request.weather_context:
            weather_info = "\n".join([
                f"{w['date']}: {w['condition']}, {w['temperature']}°C" 
                for w in request.weather_context
            ])
            additional_context = f"\n\n날씨 정보:\n{weather_info}"
        
        # 입력 소스에 따른 컨텍스트 추가
        if request.source == "ocr":
            additional_context += "\n\n[참고: 이 텍스트는 이미지에서 OCR로 추출되었습니다. 불완전하거나 오타가 있을 수 있으니 문맥을 고려해서 해석해주세요.]"
        elif request.source == "voice":
            additional_context += "\n\n[참고: 이 텍스트는 음성에서 변환되었습니다.]"
        
        # 메시지에 컨텍스트 추가
        processed_message = request.message + additional_context
        
        result = await llm_service.process_user_input(
            user_input=processed_message,
            chat_history=request.chat_history
        )
        
        # OCR 텍스트인 경우 향후 벡터DB에 저장 (선택적)
        if request.source == "ocr":
            print(f"OCR 텍스트 처리됨: {request.message[:50]}...")
        
        return ChatResponse(
            response=result["response"],
            is_event_related=result.get("is_event_related", False),
            session_id=request.session_id
        )
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"처리 중 오류 발생: {str(e)}")

# 기존 엔드포인트도 유지 (하위 호환성)
@app.post("/api/v1/chat", response_model=ChatResponse)
async def chat_endpoint(request: ChatRequest):
    """하위 호환성을 위한 기존 엔드포인트"""
    # 동일한 로직 실행
    try:
        result = await llm_service.process_user_input(
            user_input=request.message,
            chat_history=request.chat_history
        )
        
        return ChatResponse(
            response=result["response"],
            is_event_related=result.get("is_event_related", False),
            session_id=request.session_id
        )
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"처리 중 오류 발생: {str(e)}")

@app.get("/health")
async def health_check():
    """서버 상태 확인"""
    return {
        "status": "healthy", 
        "message": "AI Calendar Assistant is running"
    }