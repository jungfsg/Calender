from pydantic_settings import BaseSettings
from typing import Optional
from functools import lru_cache

class Settings(BaseSettings):
    # FastAPI 설정
    API_V1_STR: str = "/api/v1"
    PROJECT_NAME: str = "Calendar Server"
    
    # OpenAI API 설정
    OPENAI_API_KEY: Optional[str] = None
    
    # Google Calendar API 설정
    GOOGLE_CALENDAR_CREDENTIALS: Optional[str] = None
    
    # ChromaDB 설정
    CHROMADB_HOST: str = "localhost"
    CHROMADB_PORT: int = 9000

    class Config:
        env_file = ".env"
        case_sensitive = True

@lru_cache()
def get_settings() -> Settings:
    return Settings() 