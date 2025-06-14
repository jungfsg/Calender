from pydantic_settings import BaseSettings
from typing import Optional, List
from functools import lru_cache

class Settings(BaseSettings):
    # FastAPI 설정
    API_V1_STR: str = "/api/v1"
    PROJECT_NAME: str = "Calendar Server"
    
    # OpenAI API 설정
    OPENAI_API_KEY: Optional[str] = None
    
    # Google Calendar API 설정 (OAuth 방식)
    GOOGLE_CALENDAR_CREDENTIALS: Optional[str] = None
    GOOGLE_CALENDAR_TOKEN_FILE: str = "token.json"
    GOOGLE_CALENDAR_SCOPES: List[str] = ['https://www.googleapis.com/auth/calendar']
    
    # Google Calendar API 설정 (서비스 계정 방식 - 권장)
    GOOGLE_SERVICE_ACCOUNT_FILE: Optional[str] = None
    GOOGLE_SERVICE_ACCOUNT_JSON: Optional[str] = None
    GOOGLE_CALENDAR_ID: str = "primary"
    
    # # ChromaDB 설정
    # CHROMADB_HOST: str = "localhost"
    # CHROMADB_PORT: int = 9000
    # CHROMADB_PERSIST_DIR: str = "./chroma_db"
    
    # TTS 설정 (향후 음성 응답을 위해)
    TTS_ENABLED: bool = False
    TTS_VOICE: str = "ko-KR-Wavenet-A"
    
    # 로깅 설정
    LOG_LEVEL: str = "INFO"
    
    # 보안 설정
    SECRET_KEY: Optional[str] = None
    ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 30

    class Config:
        env_file = ".env"
        case_sensitive = True

@lru_cache()
def get_settings() -> Settings:
    return Settings() 