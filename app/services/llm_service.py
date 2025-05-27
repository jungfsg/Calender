from typing import Optional, List, Dict, Any, TypedDict, Annotated
from openai import OpenAI
from langgraph.graph import StateGraph, END
from app.core.config import get_settings
import json

settings = get_settings()

# 상태 정의
class ChatState(TypedDict):
    messages: List[Dict[str, str]]
    current_input: str
    current_output: Optional[str]

class LLMService:
    def __init__(self):
        self.client = OpenAI(api_key=settings.OPENAI_API_KEY)
        self.workflow = self._create_chat_workflow()
        
    def _create_chat_workflow(self):
        """
        LangGraph 워크플로우를 생성합니다.
        """
        # 노드 정의
        def generate_response(state: ChatState) -> ChatState:
            """
            OpenAI API를 사용하여 응답을 생성합니다.
            """
            try:
                messages = state['messages'].copy()
                
                response = self.client.chat.completions.create(
                    model="gpt-4o-mini",
                    messages=messages,
                    temperature=0.7,
                    max_tokens=1000
                )
                
                state['current_output'] = response.choices[0].message.content
                state['messages'].append({
                    "role": "assistant", 
                    "content": state['current_output']
                })
                return state
            except Exception as e:
                print(f"LLM 요청 중 오류 발생: {str(e)}")
                state['current_output'] = "죄송합니다, 응답을 생성하는 중 오류가 발생했습니다."
                return state
        
        # 그래프 정의
        builder = StateGraph(ChatState)
        builder.add_node("generate_response", generate_response)
        
        # 엣지 정의
        builder.set_entry_point("generate_response")
        builder.add_edge("generate_response", END)
        
        # 그래프 컴파일
        return builder.compile()
    
    async def generate_response(
        self,
        messages: List[Dict[str, str]],
        temperature: float = 0.7,
        max_tokens: int = 1000
    ) -> str:
        """
        사용자 메시지에 대한 응답을 생성합니다.
        """
        try:
            response = self.client.chat.completions.create(
                model="gpt-4o-mini",
                messages=messages,
                temperature=temperature,
                max_tokens=max_tokens
            )
            return response.choices[0].message.content
        except Exception as e:
            print(f"LLM 요청 중 오류 발생: {str(e)}")
            return "죄송합니다, 응답을 생성하는 중 오류가 발생했습니다."

    async def process_calendar_input(
        self,
        user_input: str,
        context: Optional[List[str]] = None
    ) -> Dict[str, Any]:
        """
        사용자 입력을 처리하여 일정 정보를 추출합니다.
        """
        # 기본 방식 (컨텍스트가 명시적으로 전달된 경우)
        messages = [
            {"role": "system", "content": "당신은 일정 관리를 돕는 어시스턴트입니다."},
        ]
        
        if context:
            messages.append({"role": "system", "content": f"참고할 컨텍스트 정보입니다: {' '.join(context)}"})
        
        messages.append({"role": "user", "content": f"다음 내용에서 일정 정보를 추출해주세요: {user_input}"})
        
        response = await self.generate_response(messages)
        return {"raw_response": response}
    
    async def chat_with_graph(
        self,
        message: str,
        session_id: str = "default",
        chat_history: Optional[List[Dict[str, str]]] = None
    ) -> Dict[str, Any]:
        """
        LangGraph를 사용하여 대화형 응답을 생성합니다.
        """
        if chat_history is None:
            chat_history = []
            
        # 시스템 메시지 추가
        if not any(msg.get("role") == "system" for msg in chat_history):
            chat_history.insert(0, {
                "role": "system", 
                "content": "당신은 일정 관리를 돕는 어시스턴트입니다. 사용자의 일정을 관리하고 정보를 추출하는 데 도움을 줍니다."
            })
        
        # 사용자 메시지 추가
        chat_history.append({"role": "user", "content": message})
        
        # 초기 상태 설정
        initial_state = {
            "messages": chat_history,
            "current_input": message,
            "current_output": None
        }
        
        # 워크플로우 실행
        result = self.workflow.invoke(initial_state)
        
        return {
            "response": result["current_output"],
            "updated_history": result["messages"]
        } 