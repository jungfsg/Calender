from typing import Optional, List, Dict, Any
from langchain_openai import ChatOpenAI
from langchain.chains import ConversationalRetrievalChain
from langchain.chains.conversational_retrieval.base import ConversationalRetrievalChain
from langchain.memory import ConversationBufferMemory
from langchain_core.prompts import PromptTemplate, ChatPromptTemplate
from langchain_core.output_parsers import StrOutputParser
from app.core.config import get_settings
from app.services.vector_store import VectorStoreService

settings = get_settings()

class LLMService:
    def __init__(self):
        self.llm = ChatOpenAI(
            api_key=settings.OPENAI_API_KEY,
            model="gpt-4o-mini",
            temperature=0.7
        )
        self.vector_store = VectorStoreService()

    async def generate_response(
        self,
        messages: List[Dict[str, str]],
        temperature: float = 0.7,
        max_tokens: int = 1000
    ) -> str:
        """
        LangChain을 사용하여 응답을 생성합니다.
        """
        try:
            chat = ChatOpenAI(
                api_key=settings.OPENAI_API_KEY,
                model="gpt-4o-mini",
                temperature=temperature,
                max_tokens=max_tokens
            )
            
            # LangChain 형식의 메시지로 변환
            langchain_messages = []
            for msg in messages:
                if msg["role"] == "system":
                    langchain_messages.append({"type": "system", "content": msg["content"]})
                elif msg["role"] == "user":
                    langchain_messages.append({"type": "human", "content": msg["content"]})
                elif msg["role"] == "assistant":
                    langchain_messages.append({"type": "ai", "content": msg["content"]})
            
            response = chat.invoke(langchain_messages)
            return response.content
        except Exception as e:
            print(f"LLM 요청 중 오류 발생: {str(e)}")
            return None

    async def process_calendar_input(
        self,
        user_input: str,
        context: Optional[List[str]] = None
    ) -> Dict[str, Any]:
        """
        사용자 입력을 처리하여 일정 정보를 추출합니다.
        """
        # 기본 방식 (컨텍스트가 명시적으로 전달된 경우)
        if context:
            messages = [
                {"role": "system", "content": "당신은 일정 관리를 돕는 어시스턴트입니다."},
                {"role": "system", "content": f"참고할 컨텍스트 정보입니다: {' '.join(context)}"},
                {"role": "user", "content": f"다음 내용에서 일정 정보를 추출해주세요: {user_input}"}
            ]
            response = await self.generate_response(messages)
            return {"raw_response": response}
        
        # RAG 방식 (자동으로 관련 컨텍스트 검색)
        else:
            retriever = self.vector_store.get_retriever()
            
            template = """당신은 일정 관리를 돕는 어시스턴트입니다.
            
            다음 컨텍스트 정보를 참고하여 일정 정보를 추출해주세요:
            {context}
            
            사용자 질문: {question}
            """
            
            prompt = ChatPromptTemplate.from_template(template)
            
            chain = (
                {"context": retriever, "question": lambda x: x}
                | prompt
                | self.llm
                | StrOutputParser()
            )
            
            response = chain.invoke(user_input)
            return {"raw_response": response}
    
    async def create_conversational_chain(self, session_id: str = "default"):
        """
        대화형 검색 체인을 생성합니다.
        """
        retriever = self.vector_store.get_retriever()
        
        memory = ConversationBufferMemory(
            memory_key="chat_history",
            return_messages=True
        )
        
        chain = ConversationalRetrievalChain.from_llm(
            llm=self.llm,
            retriever=retriever,
            memory=memory,
            verbose=True
        )
        
        return chain 