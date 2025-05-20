import chromadb
from chromadb.config import Settings
from app.core.config import get_settings

settings = get_settings()

# ChromaDB 서버 설정
chroma_settings = Settings(
    chroma_db_impl="duckdb+parquet",
    persist_directory="./chroma_db"
)

# 서버 시작
print(f"ChromaDB 서버를 시작합니다...")
chromadb.PersistentClient(path="./chroma_db")
print(f"ChromaDB 서버가 {settings.CHROMADB_HOST}:{settings.CHROMADB_PORT}에서 실행 중입니다...")