# from langchain_community.vectorstores import Chroma
# from langchain_openai import OpenAIEmbeddings
# from langchain_core.documents import Document
# from typing import List, Optional, Dict, Any
# from app.core.config import get_settings
# import uuid

# settings = get_settings()

# class VectorStoreService:
#     def __init__(self):
#         self.embeddings = OpenAIEmbeddings(
#             openai_api_key=settings.OPENAI_API_KEY
#         )
#         self.vectorstore = Chroma(
#             collection_name="calendar_contexts",
#             embedding_function=self.embeddings,
#             persist_directory="./chroma_db"
#         )

#     async def add_context(
#         self,
#         texts: List[str],
#         metadata: Optional[List[dict]] = None
#     ):
#         """
#         컨텍스트를 벡터 저장소에 추가합니다.
#         """
#         if metadata is None:
#             metadata = [{}] * len(texts)
        
#         documents = [
#             Document(
#                 page_content=text,
#                 metadata=meta
#             ) for text, meta in zip(texts, metadata)
#         ]
        
#         self.vectorstore.add_documents(documents)
#         return {"status": "success", "message": "컨텍스트가 성공적으로 추가되었습니다."}

#     async def search_context(
#         self,
#         query: str,
#         n_results: int = 5
#     ) -> List[dict]:
#         """
#         쿼리와 관련된 컨텍스트를 검색합니다.
#         """
#         results = self.vectorstore.similarity_search_with_relevance_scores(
#             query, k=n_results
#         )
        
#         return [
#             {
#                 "text": doc.page_content,
#                 "metadata": doc.metadata,
#                 "score": score
#             }
#             for doc, score in results
#         ]

#     async def delete_context(self, ids: List[str]):
#         """
#         특정 컨텍스트를 삭제합니다.
#         """
#         for doc_id in ids:
#             self.vectorstore.delete([doc_id])
        
#         return {"status": "success", "message": "컨텍스트가 성공적으로 삭제되었습니다."}
        
#     def get_retriever(self, search_kwargs=None):
#         """
#         LangChain Chain에서 사용할 retriever를 반환합니다.
#         """
#         if search_kwargs is None:
#             search_kwargs = {"k": 5}
            
#         return self.vectorstore.as_retriever(
#             search_kwargs=search_kwargs
#         ) 