from typing import Optional, List, Dict, Any, TypedDict, Annotated
from openai import OpenAI
from langgraph.graph import StateGraph, END
from app.core.config import get_settings
# from app.services.google_calendar_service import GoogleCalendarService
# from app.services.vector_store import VectorStoreService
import json
import re
from datetime import datetime, timedelta
from dateutil import parser
import pytz
import logging

settings = get_settings()

# =============================================================================
# 유틸리티 함수들 (글로벌 함수)
# =============================================================================

def get_relative_date_rules(current_date: datetime) -> dict:
    """상대적 날짜 표현을 절대 날짜로 변환하는 규칙을 생성합니다."""
    # 현재 요일 (0=월요일, 6=일요일) -> 일요일 기준으로 변환
    current_weekday = current_date.weekday()
    # 일요일을 0으로 만들기 위해 조정: (일=0, 월=1, 화=2, ..., 토=6)
    current_weekday_sunday_base = (current_weekday + 1) % 7
    
    # 다음 주 일요일까지의 일수
    days_to_next_sunday = 7 - current_weekday_sunday_base
    if days_to_next_sunday == 7:  # 오늘이 일요일인 경우
        days_to_next_sunday = 7
    
    next_sunday = current_date + timedelta(days=days_to_next_sunday)
    
    # 이번 주 남은 요일들 (일요일 기준)
    days_to_this_weekend = 6 - current_weekday_sunday_base  # 이번 주 토요일까지
    
    rules = {
        # 기본 상대적 표현
        "오늘": current_date.strftime('%Y-%m-%d'),
        "내일": (current_date + timedelta(days=1)).strftime('%Y-%m-%d'),
        "모레": (current_date + timedelta(days=2)).strftime('%Y-%m-%d'),
        "글피": (current_date + timedelta(days=3)).strftime('%Y-%m-%d'),
        
        # 주 단위 표현 - 일요일 기준
        "다음주": next_sunday.strftime('%Y-%m-%d'),
        "다음주 일요일": next_sunday.strftime('%Y-%m-%d'),
        "다음주 월요일": (next_sunday + timedelta(days=1)).strftime('%Y-%m-%d'),
        "다음주 화요일": (next_sunday + timedelta(days=2)).strftime('%Y-%m-%d'),
        "다음주 수요일": (next_sunday + timedelta(days=3)).strftime('%Y-%m-%d'),
        "다음주 목요일": (next_sunday + timedelta(days=4)).strftime('%Y-%m-%d'),
        "다음주 금요일": (next_sunday + timedelta(days=5)).strftime('%Y-%m-%d'),
        "다음주 토요일": (next_sunday + timedelta(days=6)).strftime('%Y-%m-%d'),
        
        # 이번 주 각 요일 (일요일 기준)
        "이번주": (current_date - timedelta(days=current_weekday_sunday_base)).strftime('%Y-%m-%d'),
        "이번주 일요일": (current_date - timedelta(days=current_weekday_sunday_base)).strftime('%Y-%m-%d'),
        "이번주 월요일": (current_date - timedelta(days=current_weekday_sunday_base - 1)).strftime('%Y-%m-%d'),
        "이번주 화요일": (current_date - timedelta(days=current_weekday_sunday_base - 2)).strftime('%Y-%m-%d'),
        "이번주 수요일": (current_date - timedelta(days=current_weekday_sunday_base - 3)).strftime('%Y-%m-%d'),
        "이번주 목요일": (current_date - timedelta(days=current_weekday_sunday_base - 4)).strftime('%Y-%m-%d'),
        "이번주 금요일": (current_date - timedelta(days=current_weekday_sunday_base - 5)).strftime('%Y-%m-%d'),
        "이번주 토요일": (current_date - timedelta(days=current_weekday_sunday_base - 6)).strftime('%Y-%m-%d'),
        
        # 이번 주 표현
        "이번 주말": (current_date + timedelta(days=days_to_this_weekend)).strftime('%Y-%m-%d'),
        
        # 월 단위 표현
        "다음달": (current_date.replace(day=1) + timedelta(days=32)).replace(day=1).strftime('%Y-%m-%d'),
        "내년": current_date.replace(year=current_date.year + 1, month=1, day=1).strftime('%Y-%m-%d'),
        
        # 시간 표현
        "오전 9시": "09:00",
        "오전 10시": "10:00",
        "오전 11시": "11:00",
        "오후 1시": "13:00",
        "오후 2시": "14:00",
        "오후 3시": "15:00",
        "오후 4시": "16:00",
        "오후 5시": "17:00",
        "오후 6시": "18:00",
        "저녁 7시": "19:00",
        "저녁 8시": "20:00",
        "저녁 9시": "21:00",
        "밤 10시": "22:00",
        "밤 11시": "23:00",
    }
    
    return rules

def safe_json_parse(response_text: str, fallback_data: dict) -> dict:
    """JSON 파싱을 안전하게 수행"""
    try:
        # JSON 블록 추출 시도
        json_match = re.search(r'\{.*\}', response_text, re.DOTALL)
        if json_match:
            return json.loads(json_match.group())
        return json.loads(response_text)
    except json.JSONDecodeError:
        return fallback_data

def keyword_based_classification(user_input: str) -> dict:
    """키워드 기반 의도 분류 폴백 - 간접적 표현 강화"""
    user_input_lower = user_input.lower()
    
    # 간접적인 일정 추가 표현들 대폭 추가
    intent_keywords = {
        'calendar_add': [
            # 기존 직접적 표현
            '추가', '만들', '생성', '등록', '잡아', '스케줄', '예약', '설정',
            
            # 의무/할 일 표현 (가장 많이 사용됨)
            '해야해', '해야 해', '드려야 해', '줘야해', '줘야 해', 
            '가야해', '가야 해', '와야해', '와야 해', '봐야해', '봐야 해',
            '먹어야해', '먹어야 해', '사야해', '사야 해',
            
            # 계획/예정 표현
            '기로 했어', '기로했어', '할 예정', '할예정', '예정이야', '예정이에요',
            '하려고 해', '하려고해', '계획이야', '계획이에요',
            
            # 약속/만남 표현
            '약속', '만나기로', '만나기로 했어', '만날 예정', '만날예정',
            '참석', '참석해야', '참여', '참여해야',
            
            # 반복/습관 표현
            '매일', '매주', '매월', '마다', '때마다',
            '하루에', '일주일에', '한 달에',
            
            # 기간 표현
            '부터', '까지', '동안', '간',
            '박', '일간', '시간', '분간'
        ],
        
        'calendar_update': [
            '수정', '변경', '바꿔', '업데이트', '이동', '옮겨', '고쳐', '편집', '조정', 
            '이름 바꿔', '시간 바꿔', '날짜 바꿔', '미뤄', '당겨'
        ],
        
        'calendar_delete': [
            '삭제', '지워', '취소', '없애', '빼', '제거', 
            '다 삭제', '모두 삭제', '전체 삭제', '다 지워', '모두 지워', '전부 삭제'
        ],
        
        'calendar_search': [
            '검색', '찾아', '조회', '확인', '뭐 있', '언제', '일정 보', '스케줄 확인',
            # STT에서 물음표 없이 들어오는 의문문 패턴들
            '뭐 있어', '뭐있어', '무슨 일', '언제', 
            '있어', '있나', '뭐야', '언제야',  # 물음표 없는 의문문
            '일정 뭐', '오늘 뭐', '내일 뭐', '이번주 뭐',
            '시간 있어', '시간있어', '바쁘', '바빠',
            # 확인 요청 표현들
            '확인해', '알려줘', '보여줘', '말해줘',
        ],
        
        'calendar_copy': ['복사', '복제', '같은 일정', '동일한']
    }
    
    # 문맥상 의문문인지 판단하는 패턴들 (STT용)
    import re
    question_patterns = [
        r'.*뭐\s*(있어|있나|야)',           # "뭐 있어", "뭐야" 등
        r'.*(언제|몇시|며칠).*',           # 시간 질문
        r'.*시간\s*있어.*',               # "시간 있어"
        r'.*(바쁘|바빠).*',               # "바쁘지", "바빠"
        r'.*일정.*뭐.*',                  # "일정 뭐 있어"
        r'.*(오늘|내일|이번주|다음주)\s*뭐.*', # "오늘 뭐 해"
    ]
    
    # 의문문 패턴 매칭 시 search로 우선 분류
    for pattern in question_patterns:
        if re.search(pattern, user_input_lower):
            return {
                "intent": "calendar_search",
                "confidence": 0.85,
                "reason": f"의문문 패턴 감지: {pattern}"
            }
    
    # 가중치 기반 점수 계산 (간접적 표현에 더 높은 가중치)
    scores = {}
    for intent, keywords in intent_keywords.items():
        score = 0
        matched_keywords = []
        
        for keyword in keywords:
            if keyword in user_input_lower:
                # 간접적 표현에 더 높은 가중치 부여
                if any(pattern in keyword for pattern in ['해야', '줘야', '가야', '기로', '예정', '약속']):
                    score += 2.0  # 간접적 표현에 높은 가중치
                else:
                    score += 1.0  # 직접적 표현에 기본 가중치
                matched_keywords.append(keyword)
        
        if score > 0:
            scores[intent] = {
                'score': score,
                'keywords': matched_keywords
            }
    
    if scores:
        # 가장 높은 점수의 의도 선택
        best_intent = max(scores.keys(), key=lambda x: scores[x]['score'])
        confidence = min(0.9, 0.5 + scores[best_intent]['score'] * 0.1)
        
        return {
            "intent": best_intent,
            "confidence": confidence,
            "reason": f"키워드 기반 분류 (간접표현): {scores[best_intent]['keywords']}"
        }
    
    return {
        "intent": "general_chat",
        "confidence": 0.8,
        "reason": "일정 관련 키워드 없음"
    }

def extract_search_keyword_from_input(user_input: str) -> str:
    """사용자 입력에서 일정 검색을 위한 핵심 키워드 추출"""
    import re
    
    # 수정/삭제 관련 키워드들을 제거하는 패턴
    remove_patterns = [
        r'\s*(일정|스케줄)\s*(수정|변경|바꿔|고쳐|편집|조정|삭제|지워|제거|없애|해줘|해주세요).*',
        r'\s*(수정|변경|바꿔|고쳐|편집|조정|삭제|지워|제거|없애|해줘|해주세요).*',
        r'.*을\s*',  # "맥주를", "회의를" 등
        r'.*를\s*',
        r'^\s*(오늘|내일|모레|이번주|다음주|내주|이번달|다음달)\s*',
        r'\s*(시|시에|시간|분)\s*(에|으로|로|부터|까지)?\s*',
    ]
    
    # 시간 패턴을 먼저 제거
    time_patterns = [
        r'\d{1,2}시\d{0,2}분?',
        r'오전\s*\d{1,2}시\d{0,2}분?',
        r'오후\s*\d{1,2}시\d{0,2}분?',
        r'저녁\s*\d{1,2}시\d{0,2}분?',
        r'아침\s*\d{1,2}시\d{0,2}분?',
        r'\d{1,2}:\d{2}',
        r'\d{1,2}시부터\s*\d{1,2}시까지',
        r'오후\s*\d{1,2}시부터\s*\d{1,2}시까지',
        r'오전\s*\d{1,2}시부터\s*\d{1,2}시까지',
    ]
    
    cleaned_input = user_input
    
    # 시간 패턴 제거
    for pattern in time_patterns:
        cleaned_input = re.sub(pattern, '', cleaned_input)
    
    # 불필요한 키워드 제거
    for pattern in remove_patterns:
        cleaned_input = re.sub(pattern, '', cleaned_input)
    
    # 특정 패턴으로 키워드 추출
    keyword_patterns = [
        r'(.+?)\s*(일정|미팅|회의|만남|약속|수업|세미나)',  # "맥주 일정" -> "맥주"
        r'(.+)',  # 나머지 모든 텍스트
    ]
    
    for pattern in keyword_patterns:
        match = re.search(pattern, cleaned_input.strip())
        if match:
            keyword = match.group(1).strip()
            # 추가적인 정리
            keyword = re.sub(r'\s+', ' ', keyword)  # 연속된 공백 제거
            keyword = keyword.strip()
            
            if len(keyword) > 0:  # 빈 문자열이 아니면
                return keyword
    
    return user_input.strip()  # 원본 입력 반환

def extract_title_from_input(user_input: str) -> str:
    """사용자 입력에서 제목 추출 - 간접적 표현 강화"""
    import re
    
    # 간접적 표현을 자연스러운 제목으로 변환하는 매핑
    indirect_mappings = {
        # 의무 표현
        r'(.+?)\s*(에|에게|께)\s*(.+?)\s*(줘야해|줘야 해|드려야 해|드려야해)': r'\2 \3',
        r'(.+?)\s*(가야해|가야 해)': r'\1',
        r'(.+?)\s*(와야해|와야 해)': r'\1',
        r'(.+?)\s*(봐야해|봐야 해)': r'\1',
        r'(.+?)\s*(해야해|해야 해|해야돼|해야 돼)': r'\1',
        r'(.+?)\s*(사야해|사야 해)': r'\1 구매',
        r'(.+?)\s*(먹어야해|먹어야 해)': r'\1',
        
        # 계획/예정 표현
        r'(.+?)\s*(기로 했어|기로했어)': r'\1',
        r'(.+?)\s*(할 예정|할예정|예정이야|예정이에요)': r'\1',
        r'(.+?)\s*(하려고 해|하려고해)': r'\1',
        r'(.+?)\s*(계획이야|계획이에요)': r'\1',
        
        # 약속/만남 표현
        r'(.+?)\s*(만나기로|만날 예정|만날예정)': r'\1 만남',
        r'(.+?)\s*(참석해야|참여해야)': r'\1',
        
        # 반복 표현
        r'매일\s*(.+?)': r'\1 (매일)',
        r'매주\s*(.+?)': r'\1 (매주)',
        r'매월\s*(.+?)': r'\1 (매월)',
    }
    
    cleaned_input = user_input
    
    # 간접적 표현 변환
    for pattern, replacement in indirect_mappings.items():
        match = re.search(pattern, cleaned_input)
        if match:
            try:
                transformed = re.sub(pattern, replacement, cleaned_input)
                cleaned_input = transformed
                break
            except:
                continue
    
    # 불필요한 키워드들을 제거하는 패턴
    remove_patterns = [
        r'\s*(일정|스케줄)\s*(추가|만들|생성|등록|잡아|해줘|해주세요).*',
        r'\s*(추가|만들|생성|등록|잡아|해줘|해주세요).*',
        r'.*에\s*',  # "내일에", "오늘에" 등
        r'^\s*(오늘|내일|모레|이번주|다음주|내주|이번달|다음달)\s*',
        r'\s*(시|시에|시간|분)\s*(에|으로|로)?\s*(추가|만들|생성|등록|잡아|해줘|해주세요).*',
    ]
    
    # 시간 패턴을 먼저 제거
    time_patterns = [
        r'\d{1,2}시\d{0,2}분?',
        r'오전\s*\d{1,2}시\d{0,2}분?',
        r'오후\s*\d{1,2}시\d{0,2}분?',
        r'저녁\s*\d{1,2}시\d{0,2}분?',
        r'아침\s*\d{1,2}시\d{0,2}분?',
        r'\d{1,2}:\d{2}',
    ]
    
    # 시간 패턴 제거
    for pattern in time_patterns:
        cleaned_input = re.sub(pattern, '', cleaned_input)
    
    # 불필요한 키워드 제거
    for pattern in remove_patterns:
        cleaned_input = re.sub(pattern, '', cleaned_input)
      # 특정 패턴으로 제목 추출
    title_patterns = [
        r'(.+?)\s*(일정|미팅|회의|만남|약속|수업|세미나)',  # "맥주 일정" -> "맥주"
        r'(.+)',  # 나머지 모든 텍스트
    ]
    
    for pattern in title_patterns:
        match = re.search(pattern, cleaned_input.strip())
        if match:
            title = match.group(1).strip()
            # 추가적인 정리
            title = re.sub(r'\s+', ' ', title)  # 연속된 공백 제거
            title = title.strip()
            
            if len(title) > 0:  # 빈 문자열이 아니면
                return title
    
    return '새 일정'

def validate_and_correct_info(info: dict, current_date: datetime) -> dict:
    """추출된 정보 검증 및 보정"""
    try:
        # 날짜 검증
        start_date = info.get('start_date')
        if start_date:
            try:
                parsed_date = datetime.strptime(start_date, '%Y-%m-%d')
                # 과거 날짜면 내년으로 보정
                if parsed_date.date() < current_date.date():
                    info['start_date'] = (parsed_date + timedelta(days=365)).strftime('%Y-%m-%d')
            except:
                info['start_date'] = (current_date + timedelta(days=1)).strftime('%Y-%m-%d')
          # 시간 검증 및 종일 일정 처리
        start_time = info.get('start_time')
        if start_time and not re.match(r'^\d{2}:\d{2}$', start_time):
            info['start_time'] = None  # 잘못된 형식이면 종일 일정으로 변경
            info['all_day'] = True
        
        # 시간이 없으면 종일 일정으로 설정
        if not start_time or start_time == "":
            info['start_time'] = None
            info['end_time'] = None
            info['all_day'] = True
            print("🕐 시간이 명시되지 않아 종일 일정으로 설정")
        
        # 종료 시간 검증
        end_time = info.get('end_time')
        if end_time and not re.match(r'^\d{2}:\d{2}$', end_time):
            info['end_time'] = None  # 잘못된 형식이면 초기화
          # 종료 시간 자동 설정 (시간이 있는 경우에만)
        if info.get('start_time') and not info.get('end_time') and not info.get('all_day', False):
            try:
                start_dt = datetime.strptime(info['start_time'], '%H:%M')
                # 커스터마이징 포인트: 기본 일정 길이 변경 가능 (현재 1시간)
                end_dt = start_dt + timedelta(hours=1)  # 기본 1시간, 필요시 변경
                info['end_time'] = end_dt.strftime('%H:%M')
                print(f"🕐 종료 시간 자동 설정: {info['start_time']} → {info['end_time']}")
            except:
                info['end_time'] = None
        
        # 종료 시간이 시작 시간보다 빠른 경우 보정 (시간이 있는 경우에만)
        if info.get('start_time') and info.get('end_time') and not info.get('all_day', False):
            try:
                start_dt = datetime.strptime(info['start_time'], '%H:%M')
                end_dt = datetime.strptime(info['end_time'], '%H:%M')
                
                if end_dt <= start_dt:
                    print(f"⚠️ 종료 시간이 시작 시간보다 빠름: {info['start_time']} → {info['end_time']}")
                    # 다음날로 가정하지 않고 1시간 후로 설정
                    end_dt = start_dt + timedelta(hours=1)
                    info['end_time'] = end_dt.strftime('%H:%M')
                    print(f"✅ 종료 시간 보정됨: {info['end_time']}")
            except:
                pass
        
        # 종료 날짜 설정
        if not info.get('end_date'):
            info['end_date'] = info.get('start_date')
        
        return info
        
    except Exception as e:
        logging.error(f"정보 검증 중 오류: {str(e)}")
        return info

def get_default_event_info() -> dict:
    """기본 이벤트 정보 반환"""
    current_date = datetime.now(pytz.timezone('Asia/Seoul'))
    tomorrow = current_date + timedelta(days=1)
    
    # 커스터마이징 포인트: 기본값들 변경 가능
    return {
        "title": "새 일정",
        "start_date": tomorrow.strftime('%Y-%m-%d'),
        "start_time": None,  # 기본값을 None으로 변경 (종일 일정)
        "end_date": tomorrow.strftime('%Y-%m-%d'),
        "end_time": None,    # 기본값을 None으로 변경 (종일 일정)
        "description": "",
        "location": "",
        "attendees": [],
        "repeat_type": "none",
        "repeat_interval": 1,
        "repeat_count": None,
        "repeat_until": None,
        "reminders": [15],     # 기본 알림: 15분 전
        "all_day": True,       # 기본값을 종일 일정으로 변경
        "timezone": "Asia/Seoul",
        "priority": "normal",
        "category": "other"
    }

# =============================================================================
# 상태 정의
# =============================================================================

class CalendarState(TypedDict):
    messages: List[Dict[str, str]]
    current_input: str
    current_output: Optional[str]
    intent: Optional[str]
    extracted_info: Optional[Dict[str, Any]]
    action_type: Optional[str]
    calendar_result: Optional[Dict[str, Any]]
    context: Optional[List[str]]

# =============================================================================
# 메인 서비스 클래스
# =============================================================================

class LLMService:
    def __init__(self):
        self.client = OpenAI(api_key=settings.OPENAI_API_KEY)
        # # self.calendar_service = GoogleCalendarService()
        # self.vector_store = VectorStoreService()
        self.workflow = self._create_calendar_workflow()
        
    def _create_calendar_workflow(self):
        """AI 캘린더를 위한 LangGraph 워크플로우를 생성합니다."""
        def classify_intent(state: CalendarState) -> CalendarState:
            """1단계: 의도 분류 - 간접적 표현 강화"""
            try:
                prompt = f"""
사용자의 입력을 분석하여 의도를 분류해주세요.

**중요**: 한국어에서는 간접적인 표현이 매우 많이 사용됩니다!

**일정 추가 표현 예시:**

1. **의무/할 일 표현 (가장 일반적)**:
   - "나 내일 화분에 물 줘야해" → calendar_add
   - "다음주에 부모님께 안부 전화 드려야 해" → calendar_add
   - "월요일에 보고서 제출해야 돼" → calendar_add
   - "이번주에 치과 가야해" → calendar_add

2. **계획/예정 표현**:
   - "내일 친구랑 영화보기로 했어" → calendar_add
   - "다음주에 출장 가기로 되어있어" → calendar_add
   - "토요일에 등산하기로 약속했어" → calendar_add
   - "오늘 저녁에 헬스장 갈 예정이야" → calendar_add

3. **약속/만남 표현**:
   - "내일 누구랑 만나기로 했어" → calendar_add
   - "금요일에 회식 있어" → calendar_add
   - "다음주에 동창회 참석해야 해" → calendar_add

4. **직접적 명령어 (상대적으로 적음)**:
   - "내일 오후 3시에 회의 일정 잡아줘" → calendar_add
   - "다음주 월요일에 미팅 추가해줘" → calendar_add

**일정 조회 표현 예시:**
- "나 내일 회의 있어?" → calendar_search (의문문)
- "나 내일 뭐 해야하지?" → calendar_search
- "오늘 일정 뭐 있어?" → calendar_search
- "언제 시간 있어?" → calendar_search

사용자 입력: {state['current_input']}

다음 중 하나로 분류해주세요:
1. calendar_add - 새로운 일정 추가 (간접적 표현 포함)
2. calendar_update - 기존 일정 수정
3. calendar_delete - 일정 삭제
4. calendar_search - 일정 조회/검색 (의문문 포함)
5. calendar_copy - 일정 복사
6. general_chat - 일반 대화

**분류 우선순위:**
1. 의무/계획 표현 ("해야해", "기로 했어") → calendar_add 우선
2. 의문문 ("있어?", "뭐야?") → calendar_search 우선
3. 직접적 명령어는 명확한 의도로 분류

반드시 다음 JSON 형식으로만 응답해주세요:
{{"intent": "분류결과", "confidence": 0.95, "reason": "분류 이유"}}
"""
                
                response = self.client.chat.completions.create(
                    model="gpt-4o-mini",
                    messages=[{"role": "user", "content": prompt}],
                    temperature=0.1
                )
                
                response_text = response.choices[0].message.content.strip()
                print(f"의도 분류 응답: {response_text}")
                
                # 안전한 JSON 파싱
                fallback_data = {"intent": "general_chat", "confidence": 0.1, "reason": "파싱 실패"}
                result = safe_json_parse(response_text, fallback_data)
                
                # 신뢰도가 낮으면 개선된 키워드 기반 보완
                if result.get('confidence', 0) < 0.6:  # 임계값 상향 조정
                    result = keyword_based_classification(state['current_input'])
                
                state['intent'] = result.get('intent', 'general_chat')
                return state
                
            except Exception as e:
                print(f"의도 분류 중 오류: {str(e)}")
                # 오류 시에도 키워드 기반 분류 시도
                result = keyword_based_classification(state['current_input'])
                state['intent'] = result.get('intent', 'general_chat')
                return state
        
        def extract_information(state: CalendarState) -> CalendarState:
            """2단계: 정보 추출 (다중 일정 지원)"""
            try:
                if state['intent'] == 'general_chat':
                    return state
                
                current_date = datetime.now(pytz.timezone('Asia/Seoul'))
                
                # 상대적 날짜 규칙 생성 (일요일 기준)
                date_rules = get_relative_date_rules(current_date)
                
                # 규칙을 텍스트로 변환
                rule_text = "\n".join([f'- "{key}" → {value}' for key, value in date_rules.items()])
                
                # 삭제의 경우 특별 처리
                if state['intent'] == 'calendar_delete':
                    return self._extract_delete_information(state, current_date, rule_text)
                
                # 수정의 경우 특별 처리
                if state['intent'] == 'calendar_update':
                    return self._extract_update_information(state, current_date, rule_text)                # 기간/범위 기반 일정인지 먼저 판단 (Multi Day Event로 처리)
                range_patterns = [
                    r'.*(부터|에서).*까지.*',  # "~부터 ~까지", "~에서 ~까지"
                    r'.*\d+일간.*',  # "3일간", "5일간"
                    r'.*\d+박\s*\d+일.*',  # "2박3일", "1박2일"
                    r'.*(연속|계속).*\d+일.*',  # "연속 3일", "계속 5일"
                    r'.*주말.*내내.*',  # "주말 내내"
                    r'.*연휴.*내내.*',  # "연휴 내내"
                    r'.*휴가.*',  # "휴가"
                    r'.*여행.*',  # "여행"
                    r'.*출장.*',  # "출장"
                    r'.*캠프.*',  # "캠프"
                    r'.*워크샵.*',  # "워크샵"
                    r'.*세미나.*',  # "세미나"
                    r'.*교육.*기간.*',  # "교육 기간"
                    r'.*연수.*',  # "연수"
                    r'.*방학.*',  # "방학"
                    r'.*휴업.*',  # "휴업"
                    r'.*\d+월\s*\d+일.*\d+월\s*\d+일.*',  # "6월 15일 ~ 6월 20일"
                    r'.*\d+일.*\d+일.*',  # "15일 ~ 20일"
                ]
                
                is_multi_day = any(re.search(pattern, state['current_input']) for pattern in range_patterns)
                
                # 추가 키워드 기반 검사
                multi_day_keywords = [
                    '휴가', '여행', '출장', '캠프', '워크샵', '세미나', '교육',
                    '연수', '방학', '휴업', '기간', '동안', '내내'
                ]
                  
                # 기간 표현과 함께 키워드가 있는 경우
                if not is_multi_day:
                    input_lower = state['current_input'].lower()
                    for keyword in multi_day_keywords:
                        if keyword in state['current_input'] and ('일' in state['current_input'] or '기간' in state['current_input']):
                            is_multi_day = True
                            break
                
                if is_multi_day or ("부터" in state['current_input'] and "까지" in state['current_input']):
                    return self._extract_range_events(state, current_date, rule_text)
                
                # 여러 개별 일정인지 단일 일정인지 판단
                detection_prompt = f"""
사용자 입력에서 일정의 개수를 분석해주세요:
"{state['current_input']}"

다음 중 하나로 응답해주세요:
- "SINGLE": 하나의 일정만 있음
- "MULTIPLE": 여러 개의 일정이 있음 (개별 일정 나열)
- "RANGE": 기간/범위 기반 일정 (여러 날짜에 같은 일정)

판단 기준:
1. MULTIPLE (개별 일정 나열):
   - "그리고", "또", "그 다음에", "추가로" 등의 연결어로 서로 다른 일정들을 언급
   - 예: "내일 저녁 7시에 카페 일정 추가하고 다음주 월요일 오전 11시에 점심 일정 추가해줘"
   - 예: "오늘 오후 2시에 회의 잡고 내일 오전 10시에 병원 예약해줘"

2. RANGE (기간/범위 기반):
   - "~부터 ~까지", "~에서 ~까지" 등의 기간 표현
   - 요일 범위: "월요일부터 금요일까지", "다음주 월,화,수요일에"
   - 날짜 범위: "6월 15일부터 20일까지", "내일부터 다음주까지"
   - 예: "6월 15일부터 20일까지 휴가"
   - 예: "월요일부터 금요일까지 오전 9시에 운동"
   - 예: "다음주 월,화,수요일에 교육"

3. SINGLE:
   - 위 조건에 해당하지 않는 단일 일정
"""
                detection_response = self.client.chat.completions.create(
                    model="gpt-4o-mini",
                    messages=[{"role": "user", "content": detection_prompt}],
                    temperature=0.1                )
                
                detection_result = detection_response.choices[0].message.content.strip()
                is_multiple = "MULTIPLE" in detection_result
                is_range = "RANGE" in detection_result
                
                if is_range:
                    # 반복되는 개별 일정들로 처리 (예: "월,화,수요일에 회의")
                    return self._extract_range_events(state, current_date, rule_text)
                elif is_multiple:
                    # 다중 일정 처리
                    prompt = f"""
현재 날짜: {current_date.strftime('%Y년 %m월 %d일 %A')}
현재 시간: {current_date.strftime('%H:%M')}

사용자 입력에서 여러 일정 정보를 추출해주세요:
"{state['current_input']}"

**시간 범위 인식 예시:**
- "저녁 6시부터 8시까지 영화" → start_time: "18:00", end_time: "20:00"
- "오후 2시에서 4시까지 회의" → start_time: "14:00", end_time: "16:00"
- "오전 10시부터 12시까지 수업" → start_time: "10:00", end_time: "12:00"
- "3시간 동안 스터디" → start_time 기준으로 3시간 후 end_time 계산
- "2시간 영화 관람" → start_time 기준으로 2시간 후 end_time 계산

상대적 표현 해석 규칙 (주의 시작: 일요일):
{rule_text}

반드시 다음 JSON 형식으로만 응답해주세요 (여러 일정이 있는 경우 배열로):
{{
    "events": [
        {{
            "title": "일정 제목 (필수)",
            "start_date": "YYYY-MM-DD (필수)",
            "start_time": "HH:MM",
            "end_date": "YYYY-MM-DD",
            "end_time": "HH:MM",
            "description": "상세 설명",
            "location": "장소",
            "attendees": ["email1@example.com"],
            "repeat_type": "none|daily|weekly|monthly|yearly",
            "repeat_interval": 1,
            "repeat_count": null,
            "repeat_until": null,
            "reminders": [15, 60],
            "all_day": false,
            "timezone": "Asia/Seoul",
            "priority": "normal|high|low",
            "category": "other"
        }}
    ]
}}

추출 가이드라인:
1. 각 일정을 별도의 객체로 분리하여 추출
2. 제목 추출 시 불필요한 키워드 제거:
   - "추가", "만들어", "생성", "등록", "잡아", "해줘", "해주세요" 등의 동작 키워드 제거
   - "일정 추가" -> "일정" (X), 핵심 내용만 추출
   - 예: "내일 5시에 맥주 일정 추가해줘" -> title: "맥주"
   - 예: "오후 2시에 회의 잡아줘" -> title: "회의"
3. **시간 처리 규칙 - 매우 중요**:
   - 시간이 명시되지 않으면 start_time과 end_time을 null로 설정하고 all_day를 true로 설정
   - 시간이 명시된 경우에만 start_time을 설정하고 all_day를 false로 설정
   - 예: "내일 달리기 일정 추가해줘" -> start_time: null, end_time: null, all_day: true
   - 예: "내일 오후 3시에 회의" -> start_time: "15:00", all_day: false
4. **시간 범위 처리 매우 중요 - 반드시 정확히 추출해야 함**:   - "6시부터 8시까지", "오후 2시에서 4시까지" → start_time: "18:00", end_time: "20:00", all_day: false
   - "저녁 6시부터 8시까지" → start_time: "18:00", end_time: "20:00", all_day: false
   - "오전 10시부터 12시까지" → start_time: "10:00", end_time: "12:00", all_day: false
   - "2시간", "3시간 동안" → 지속 시간만큼 종료 시간 계산, all_day: false
   - "~부터 ~까지" 패턴이 있으면 반드시 end_time을 설정하세요
   - 종료 시간이 명시되지 않으면 시작 시간 + 1시간
5. 반복은 명시적으로 언급된 경우만 설정
6. 우선순위는 "긴급", "중요" 등의 키워드로 판단
7. "다음주"는 다음 주 일요일(주의 시작)을 의미함
8. 연결어("그리고", "또", "추가로" 등)를 기준으로 일정을 분리
"""
                else:
                    # 단일 일정 처리 (기존 로직)                    
                    prompt = f"""
현재 날짜: {current_date.strftime('%Y년 %m월 %d일 %A')}
현재 시간: {current_date.strftime('%H:%M')}

사용자 입력에서 일정 정보를 추출해주세요:
"{state['current_input']}"

**한국어 간접적 표현 인식 가이드:**

1. **의무/할 일 표현**:
   - "화분에 물 줘야해" → title: "화분 물주기"
   - "부모님께 안부 전화 드려야 해" → title: "부모님 안부 전화"
   - "치과 가야해" → title: "치과"
   - "보고서 제출해야 돼" → title: "보고서 제출"

2. **계획/예정 표현**:
   - "친구랑 영화보기로 했어" → title: "친구와 영화"
   - "출장 가기로 되어있어" → title: "출장"
   - "등산하기로 약속했어" → title: "등산"
   - "헬스장 갈 예정이야" → title: "헬스장 운동"

3. **자연스러운 제목 변환**:
   - "해야해", "가야해", "드려야 해" 등은 제목에서 제거
   - "기로 했어", "예정이야" 등도 제목에서 제거
   - 핵심 활동/장소/목적만 추출

**시간 범위 인식 예시:**
- "저녁 6시부터 8시까지 영화" → start_time: "18:00", end_time: "20:00"
- "오후 2시에서 4시까지 회의" → start_time: "14:00", end_time: "16:00"
- "오전 10시부터 12시까지 수업" → start_time: "10:00", end_time: "12:00"
- "3시간 동안 스터디" → start_time 기준으로 3시간 후 end_time 계산
- "2시간 영화 관람" → start_time 기준으로 2시간 후 end_time 계산

상대적 표현 해석 규칙 (주의 시작: 일요일):
{rule_text}

반드시 다음 JSON 형식으로만 응답해주세요:
{{
    "title": "자연스러운 일정 제목 (간접 표현을 직접적으로 변환)",
    "start_date": "YYYY-MM-DD (필수)",
    "start_time": "HH:MM",
    "end_date": "YYYY-MM-DD",
    "end_time": "HH:MM",
    "description": "상세 설명",
    "location": "장소",
    "attendees": ["email1@example.com"],
    "repeat_type": "none|daily|weekly|monthly|yearly",
    "repeat_interval": 1,
    "repeat_count": null,
    "repeat_until": null,
    "reminders": [15, 60],
    "all_day": false,
    "timezone": "Asia/Seoul",
    "priority": "normal|high|low",
    "category": "other"
}}

추출 가이드라인:
1. 제목 추출 시 불필요한 키워드 제거:
   - "추가", "만들어", "생성", "등록", "잡아", "해줘", "해주세요" 등의 동작 키워드 제거
   - "일정 추가" -> "일정" (X), 핵심 내용만 추출
   - 예: "내일 5시에 맥주 일정 추가해줘" -> title: "맥주"
   - 예: "오후 2시에 회의 잡아줘" -> title: "회의"
2. **시간 처리 규칙 - 매우 중요**:
   - 시간이 명시되지 않으면 start_time과 end_time을 null로 설정하고 all_day를 true로 설정
   - 시간이 명시된 경우에만 start_time을 설정하고 all_day를 false로 설정
   - 예: "내일 달리기 일정 추가해줘" -> start_time: null, end_time: null, all_day: true
   - 예: "내일 오후 3시에 회의" -> start_time: "15:00", all_day: false
3. **시간 범위 처리 매우 중요 - 반드시 정확히 추출해야 함**:   - "6시부터 8시까지", "오후 2시에서 4시까지" → start_time: "18:00", end_time: "20:00", all_day: false
   - "저녁 6시부터 8시까지" → start_time: "18:00", end_time: "20:00", all_day: false
   - "오전 10시부터 12시까지" → start_time: "10:00", end_time: "12:00", all_day: false
   - "2시간", "3시간 동안" → 지속 시간만큼 종료 시간 계산, all_day: false
   - "~부터 ~까지" 패턴이 있으면 반드시 end_time을 설정하세요
   - 종료 시간이 명시되지 않으면 시작 시간 + 1시간
4. 반복은 명시적으로 언급된 경우만 설정
5. 우선순위는 "긴급", "중요" 등의 키워드로 판단
6. "다음주"는 다음 주 일요일(주의 시작)을 의미함
"""
                
                response = self.client.chat.completions.create(
                    model="gpt-4o-mini",
                    messages=[{"role": "user", "content": prompt}],
                    temperature=0.1
                )
                
                response_text = response.choices[0].message.content.strip()
                print(f"정보 추출 응답: {response_text}")
                
                # 기본값 설정
                default_info = get_default_event_info()
                default_info["title"] = extract_title_from_input(state['current_input'])
                
                # 안전한 JSON 파싱
                if is_multiple:
                    try:
                        parsed_data = safe_json_parse(response_text, {"events": [default_info]})
                        events = parsed_data.get('events', [default_info])
                        
                        # 각 이벤트 검증 및 보정
                        validated_events = []
                        for event in events:
                            validated_event = validate_and_correct_info(event, current_date)
                            validated_events.append(validated_event)
                        
                        extracted_info = {"events": validated_events, "is_multiple": True}
                    except:
                        extracted_info = {"events": [default_info], "is_multiple": True}
                else:
                    extracted_info = safe_json_parse(response_text, default_info)
                    extracted_info = validate_and_correct_info(extracted_info, current_date)
                    extracted_info["is_multiple"] = False
                
                state['extracted_info'] = extracted_info
                return state
                
            except Exception as e:
                print(f"정보 추출 중 오류: {str(e)}")
                default_info = get_default_event_info()
                state['extracted_info'] = {"events": [default_info], "is_multiple": False}
                return state
        
        def determine_action(state: CalendarState) -> CalendarState:
            """3단계: 작업 유형 결정"""
            try:
                intent = state.get('intent', 'general_chat')
                
                if intent == 'general_chat':
                    state['action_type'] = 'chat'
                elif intent in ['calendar_add', 'calendar_update', 'calendar_delete', 
                               'calendar_search', 'calendar_copy', 'calendar_move']:
                    state['action_type'] = intent
                else:
                    state['action_type'] = 'chat'
                
                return state
                
            except Exception as e:
                print(f"작업 유형 결정 중 오류: {str(e)}")
                state['action_type'] = 'chat'
                return state
        
        def execute_calendar_action(state: CalendarState) -> CalendarState:
            """4단계: 캘린더 작업 실행 (다중 일정 지원)"""
            try:
                action_type = state.get('action_type')
                extracted_info = state.get('extracted_info', {})
                
                print("execute_calendar_action 실행")
                
                if action_type == 'calendar_add':
                    is_multiple = extracted_info.get('is_multiple', False)
                    is_multi_day = extracted_info.get('is_multi_day', False)
                    
                    if is_multi_day:
                        # Multi Day Event 처리
                        events = extracted_info.get('events', [])
                        if events:
                            event = events[0]  # Multi Day Event는 하나의 이벤트
                            event_result = {
                                "success": True,
                                "event_id": "mock_multi_day_event_id",
                                "message": f"Multi Day Event가 성공적으로 생성되었습니다. ({event.get('start_date')} ~ {event.get('end_date')})",
                                "event_data": event,
                                "event_type": "multi_day"
                            }
                            
                            state['calendar_result'] = {
                                "success": True,
                                "is_multi_day": True,
                                "event_id": event_result["event_id"],
                                "created_events": [event_result],
                                "message": event_result["message"],
                                "event_type": "multi_day"
                            }
                        else:
                            state['calendar_result'] = {
                                "success": False,
                                "message": "Multi Day Event 생성에 실패했습니다."
                            }
                    elif is_multiple:
                        # 다중 일정 처리
                        events = extracted_info.get('events', [])
                        created_events = []
                        
                        for i, event in enumerate(events):
                            # 각 일정을 개별적으로 처리
                            event_result = {
                                "success": True,
                                "event_id": f"mock_event_id_{i+1}",
                                "message": f"일정 {i+1}이 성공적으로 생성되었습니다.",
                                "event_data": event
                            }
                            created_events.append(event_result)
                        
                        state['calendar_result'] = {
                            "success": True,
                            "is_multiple": True,
                            "events_count": len(events),
                            "created_events": created_events,
                            "message": f"총 {len(events)}개의 일정이 성공적으로 생성되었습니다."
                        }
                    else:
                        # 단일 일정 처리 (기존 로직)
                        state['calendar_result'] = {
                            "success": True,
                            "event_id": "mock_event_id",
                            "message": "일정이 성공적으로 생성되었습니다.",
                            "event_data": extracted_info
                        }
                    
                    print("calendar_add 실행됨")
                    
                elif action_type == 'calendar_search':
                    # 커스터마이징 포인트: 실제 검색 로직 구현 필요
                    state['calendar_result'] = {"events": [], "search_query": state['current_input']}
                    
                elif action_type == 'calendar_update':
                    # 다중 수정 처리
                    update_type = extracted_info.get('update_type', 'single')
                    
                    if update_type == 'multiple':
                        # 다중 수정 처리
                        updates = extracted_info.get('updates', [])
                        updated_events = []
                        
                        for i, update_request in enumerate(updates):
                            # 각 수정을 개별적으로 처리
                            target = update_request.get('target', {})
                            changes = update_request.get('changes', {})
                            
                            update_result = {
                                "success": True,
                                "target_info": target,
                                "changes": changes,
                                "message": f"수정 {i+1}이 성공적으로 완료되었습니다."
                            }
                            updated_events.append(update_result)
                        
                        state['calendar_result'] = {
                            "success": True,
                            "update_type": "multiple",
                            "events_count": len(updates),
                            "updated_events": updated_events,
                            "message": f"총 {len(updates)}개의 일정이 성공적으로 수정되었습니다."
                        }
                        print(f"다중 수정 실행: {len(updates)}개 일정")
                        
                    else:
                        # 단일 수정 처리 (기존 로직)
                        target = extracted_info.get('target', {})
                        changes = extracted_info.get('changes', {})
                        
                        state['calendar_result'] = {
                            "success": True,
                            "update_type": "single",
                            "target_info": target,
                            "changes": changes,
                            "message": "일정이 성공적으로 수정되었습니다."
                        }
                        print(f"단일 수정 실행: {target.get('title', '일정')}")
                        
                elif action_type == 'calendar_delete':
                    # 다중 삭제 처리
                    delete_type = extracted_info.get('delete_type', 'single')
                    
                    if delete_type == 'bulk':
                        # 전체 삭제 처리
                        target_date = extracted_info.get('target_date')
                        date_description = extracted_info.get('date_description', '해당 날짜')
                        
                        state['calendar_result'] = {
                            "success": True,
                            "delete_type": "bulk",
                            "target_date": target_date,
                            "date_description": date_description,
                            "message": f"{date_description}의 모든 일정이 성공적으로 삭제되었습니다."
                        }
                        print(f"전체 삭제 실행: {target_date} ({date_description})")
                        
                    elif delete_type == 'multiple':
                        # 다중 개별 삭제 처리
                        targets = extracted_info.get('targets', [])
                        deleted_events = []
                        
                        for i, target in enumerate(targets):
                            # 각 일정을 개별적으로 처리
                            delete_result = {
                                "success": True,
                                "target_info": target,
                                "message": f"일정 {i+1}이 성공적으로 삭제되었습니다."
                            }
                            deleted_events.append(delete_result)
                        
                        state['calendar_result'] = {
                            "success": True,
                            "delete_type": "multiple",
                            "events_count": len(targets),
                            "deleted_events": deleted_events,
                            "message": f"총 {len(targets)}개의 일정이 성공적으로 삭제되었습니다."
                        }
                        print(f"다중 삭제 실행: {len(targets)}개 일정")
                        
                    else:
                        # 단일 삭제 처리 (기존 로직)
                        title = extracted_info.get('title', '일정')
                        date = extracted_info.get('date', '')
                        
                        state['calendar_result'] = {
                            "success": True,
                            "delete_type": "single",
                            "title": title,
                            "date": date,
                            "message": f"'{title}' 일정이 성공적으로 삭제되었습니다."
                        }
                        print(f"단일 삭제 실행: {title} ({date})")
                
                return state
                
            except Exception as e:
                print(f"캘린더 작업 실행 중 오류: {str(e)}")
                state['calendar_result'] = {"error": f"작업 실행 중 오류 발생: {str(e)}"}
                return state
        
        def generate_response(state: CalendarState) -> CalendarState:
            """5단계: 응답 생성"""
            try:
                action_type = state.get('action_type', 'chat')
                calendar_result = state.get('calendar_result', {})
                extracted_info = state.get('extracted_info', {})
                
                if action_type == 'chat':
                    # 일반 대화
                    messages = state['messages'].copy()
                    
                    # 커스터마이징 포인트: 시스템 메시지로 AI 성격 조정 가능
                    if not any(msg.get("role") == "system" for msg in messages):
                        system_msg = {
                            "role": "system", 
                            "content": "당신은 친근하고 도움이 되는 AI 캘린더 어시스턴트입니다. 사용자의 일정을 관리하고 자연어로 대화하며 도움을 줍니다."
                        }
                        messages.insert(0, system_msg)
                    
                    messages.append({"role": "user", "content": state['current_input']})
                    
                    response = self.client.chat.completions.create(
                        model="gpt-4o-mini",
                        messages=messages,
                        temperature=0.7  # 자연스러운 대화를 위해 약간 높은 temperature
                    )
                    
                    state['current_output'] = response.choices[0].message.content
                    
                else:
                    # 캘린더 작업 결과 기반 응답
                    if calendar_result.get('success'):
                        if action_type == 'calendar_add':
                            is_multiple = calendar_result.get('is_multiple', False)
                            is_multi_day = calendar_result.get('is_multi_day', False)
                            
                            if is_multi_day:
                                # Multi Day Event 응답 생성
                                created_events = calendar_result.get('created_events', [])
                                if created_events:
                                    event_data = created_events[0].get('event_data', {})
                                    title = event_data.get('title', '일정')
                                    start_date = event_data.get('start_date', '')
                                    end_date = event_data.get('end_date', '')
                                    
                                    state['current_output'] = f"✅ Multi Day Event를 성공적으로 생성했습니다! 📅✨\n\n"
                                    state['current_output'] += f"📋 **'{title}' 일정**\n"
                                    
                                    # 날짜 범위 표시
                                    try:
                                        start_obj = datetime.strptime(start_date, '%Y-%m-%d')
                                        end_obj = datetime.strptime(end_date, '%Y-%m-%d')
                                        
                                        start_formatted = start_obj.strftime('%Y년 %m월 %d일 (%a)')
                                        end_formatted = end_obj.strftime('%Y년 %m월 %d일 (%a)')
                                        
                                        # 기간 계산
                                        duration_days = (end_obj - start_obj).days + 1
                                        
                                        state['current_output'] += f"📅 기간: {start_formatted} ~ {end_formatted}\n"
                                        state['current_output'] += f"⏳ 총 {duration_days}일간\n"
                                        
                                    except:
                                        state['current_output'] += f"📅 기간: {start_date} ~ {end_date}\n"
                                    
                                    # 시간 정보 표시
                                    all_day = event_data.get('all_day', True)
                                    if not all_day:
                                        start_time = event_data.get('start_time')
                                        end_time = event_data.get('end_time')
                                        if start_time:
                                            if end_time:
                                                state['current_output'] += f"⏰ 매일 시간: {start_time} - {end_time}\n"
                                            else:
                                                state['current_output'] += f"⏰ 매일 시간: {start_time}\n"
                                    else:
                                        state['current_output'] += f"🕐 종일 일정\n"
                                    
                                    # 위치 정보 표시
                                    location = event_data.get('location')
                                    if location:
                                        state['current_output'] += f"📍 장소: {location}\n"
                                      # 카테고리는 Chat Service에서 자동 분류됩니다
                                    
                                    state['current_output'] += f"\n Multi Day Event가 캘린더에 잘 등록되었어요! 😊"
                                
                            elif is_multiple:
                                # 다중 일정 응답 생성
                                events_count = calendar_result.get('events_count', 0)
                                created_events = calendar_result.get('created_events', [])
                                is_range = extracted_info.get('is_range', False)
                                range_type = extracted_info.get('range_type', '')
                                
                                if is_range:
                                    # 기간 기반 일정 응답
                                    original_range_data = extracted_info.get('original_range_data', {})
                                    title = original_range_data.get('title', '일정')
                                    range_descriptions = {
                                        'date_range': '날짜 범위',
                                        'cross_week_range': '주간 범위',
                                        'single_week_range': '단일 주',
                                        'weekday_list': '지정 요일'
                                    }
                                    
                                    range_desc = range_descriptions.get(range_type, '기간')
                                    
                                    state['current_output'] = f"✅ {range_desc} 일정을 성공적으로 생성했습니다! 📅✨\n\n"
                                    state['current_output'] += f"📋 **'{title}' 일정**\n"
                                    state['current_output'] += f"📊 총 {events_count}개의 날짜에 등록되었습니다\n"
                                    
                                    # 시간 정보 표시
                                    start_time = original_range_data.get('start_time')
                                    end_time = original_range_data.get('end_time')
                                    if start_time:
                                        if end_time:
                                            state['current_output'] += f"⏰ 시간: {start_time} - {end_time}\n"
                                        else:
                                            state['current_output'] += f"⏰ 시간: {start_time}\n"
                                    
                                    # 위치 정보 표시
                                    location = original_range_data.get('location')
                                    if location:
                                        state['current_output'] += f"📍 장소: {location}\n"
                                    
                                    # 일부 날짜 미리보기 (최대 5개)
                                    if events_count > 0:
                                        state['current_output'] += f"\n📅 **일정 미리보기:**\n"
                                        preview_count = min(5, len(created_events))
                                        for i in range(preview_count):
                                            event_data = created_events[i].get('event_data', {})
                                            event_date = event_data.get('start_date', '')
                                            if event_date:
                                                # 날짜를 더 읽기 쉬운 형식으로 변환
                                                try:
                                                    date_obj = datetime.strptime(event_date, '%Y-%m-%d')
                                                    formatted_date = date_obj.strftime('%m월 %d일 (%a)')
                                                    state['current_output'] += f"   • {formatted_date}\n"
                                                except:
                                                    state['current_output'] += f"   • {event_date}\n"
                                        
                                        if events_count > 5:
                                            state['current_output'] += f"   ... 외 {events_count - 5}개 더\n"
                                    
                                    state['current_output'] += f"\n모든 일정이 캘린더에 잘 저장되었어요! 😊"
                                    
                                else:
                                    # 개별 다중 일정 응답 (기존 로직)
                                    state['current_output'] = f"네! 총 {events_count}개의 일정을 성공적으로 추가했습니다! 📅✨\n\n"
                                    
                                    for i, event_result in enumerate(created_events):
                                        event_data = event_result.get('event_data', {})
                                        title = event_data.get('title', '새 일정')
                                        start_date = event_data.get('start_date', '')
                                        start_time = event_data.get('start_time', '')
                                        location = event_data.get('location', '')
                                        
                                        state['current_output'] += f"📋 **일정 {i+1}: {title}**\n"
                                        if start_date and start_time:
                                            state['current_output'] += f"📅 날짜: {start_date}\n⏰ 시간: {start_time}\n"
                                        elif start_date:
                                            state['current_output'] += f"📅 날짜: {start_date}\n"
                                        
                                        if location:
                                            state['current_output'] += f"📍 장소: {location}\n"
                                        
                                        state['current_output'] += "\n"
                                    
                                    state['current_output'] += "모든 일정이 캘린더에 잘 저장되었어요! 😊"
                            else:
                                # 단일 일정 응답 생성 (기존 로직)
                                title = extracted_info.get('title', '새 일정')
                                start_date = extracted_info.get('start_date', '')
                                start_time = extracted_info.get('start_time', '')
                                location = extracted_info.get('location', '')
                                
                                # 커스터마이징 포인트: 응답 형식 변경 가능
                                state['current_output'] = f"네! '{title}' 일정을 성공적으로 추가했습니다. 📅\n\n"
                                if start_date and start_time:
                                    state['current_output'] += f"📅 날짜: {start_date}\n⏰ 시간: {start_time}\n"
                                elif start_date:
                                    state['current_output'] += f"📅 날짜: {start_date}\n"
                                
                                if location:
                                    state['current_output'] += f"📍 장소: {location}\n"
                                
                                state['current_output'] += "\n일정이 캘린더에 잘 저장되었어요! 😊"
                            
                        elif action_type == 'calendar_update':
                            update_type = calendar_result.get('update_type', 'single')
                            
                            if update_type == 'multiple':
                                # 다중 수정 응답
                                events_count = calendar_result.get('events_count', 0)
                                updated_events = calendar_result.get('updated_events', [])
                                
                                state['current_output'] = f"✅ 총 {events_count}개의 일정을 성공적으로 수정했습니다! ✏️✨\n\n"
                                
                                for i, event_result in enumerate(updated_events):
                                    target_info = event_result.get('target_info', {})
                                    changes = event_result.get('changes', {})
                                    title = target_info.get('title', f'일정 {i+1}')
                                    date = target_info.get('date', '')
                                    
                                    state['current_output'] += f"✏️ **수정 {i+1}: {title}**\n"
                                    if date:
                                        state['current_output'] += f"📅 날짜: {date}\n"
                                    
                                    # 변경된 내용 표시
                                    if changes.get('title'):
                                        state['current_output'] += f"📝 새로운 제목: {changes['title']}\n"
                                    if changes.get('start_time'):
                                        state['current_output'] += f"⏰ 새로운 시간: {changes['start_time']}\n"
                                    if changes.get('start_date'):
                                        state['current_output'] += f"📅 새로운 날짜: {changes['start_date']}\n"
                                    if changes.get('location'):
                                        state['current_output'] += f"📍 새로운 장소: {changes['location']}\n"
                                    if changes.get('description'):
                                        state['current_output'] += f"📄 새로운 설명: {changes['description']}\n"
                                    
                                    state['current_output'] += "\n"
                                
                                state['current_output'] += "모든 변경사항이 캘린더에 반영되었어요! 😊"
                                
                            else:
                                # 단일 수정 응답 (기존 로직 개선)
                                target_info = calendar_result.get('target_info', {})
                                changes = calendar_result.get('changes', {})
                                title = target_info.get('title', '일정')
                                
                                state['current_output'] = f"✅ '{title}' 일정을 성공적으로 수정했습니다! ✏️\n\n"
                                
                                # 변경된 내용 표시
                                if changes.get('title'):
                                    state['current_output'] += f"📝 새로운 제목: {changes['title']}\n"
                                if changes.get('start_time'):
                                    state['current_output'] += f"⏰ 새로운 시간: {changes['start_time']}\n"
                                if changes.get('start_date'):
                                    state['current_output'] += f"📅 새로운 날짜: {changes['start_date']}\n"
                                if changes.get('location'):
                                    state['current_output'] += f"📍 새로운 장소: {changes['location']}\n"
                                if changes.get('description'):
                                    state['current_output'] += f"📄 새로운 설명: {changes['description']}\n"
                                
                                state['current_output'] += "\n변경사항이 캘린더에 반영되었어요! 📝"
                            
                        elif action_type == 'calendar_delete':
                            delete_type = calendar_result.get('delete_type', 'single')
                            
                            if delete_type == 'bulk':
                                # 전체 삭제 응답
                                date_description = calendar_result.get('date_description', '해당 날짜')
                                target_date = calendar_result.get('target_date', '')
                                
                                state['current_output'] = f"✅ {date_description}의 모든 일정을 성공적으로 삭제했습니다! 🗑️\n\n"
                                if target_date:
                                    state['current_output'] += f"📅 삭제된 날짜: {target_date}\n\n"
                                state['current_output'] += "캘린더에서 모든 일정이 깔끔하게 제거되었어요! ✨"
                                
                            elif delete_type == 'multiple':
                                # 다중 개별 삭제 응답
                                events_count = calendar_result.get('events_count', 0)
                                deleted_events = calendar_result.get('deleted_events', [])
                                
                                state['current_output'] = f"✅ 총 {events_count}개의 일정을 성공적으로 삭제했습니다! 🗑️✨\n\n"
                                
                                for i, event_result in enumerate(deleted_events):
                                    target_info = event_result.get('target_info', {})
                                    title = target_info.get('title', f'일정 {i+1}')
                                    date = target_info.get('date', '')
                                    time = target_info.get('time', '')
                                    
                                    state['current_output'] += f"🗑️ **삭제 {i+1}: {title}**\n"
                                    if date:
                                        state['current_output'] += f"📅 날짜: {date}\n"
                                    if time:
                                        state['current_output'] += f"⏰ 시간: {time}\n"
                                    state['current_output'] += "\n"
                                
                                state['current_output'] += "모든 요청하신 일정이 캘린더에서 제거되었어요! 😊"
                                
                            else:
                                # 단일 삭제 응답 (기존 로직)
                                title = calendar_result.get('title', '일정')
                                date = calendar_result.get('date', '')
                                
                                state['current_output'] = f"✅ '{title}' 일정을 성공적으로 삭제했습니다! 🗑️\n\n"
                                if date:
                                    state['current_output'] += f"📅 삭제된 날짜: {date}\n\n"
                                state['current_output'] += "캘린더에서 해당 일정이 제거되었어요! ✨"
                            
                        elif action_type == 'calendar_search':
                            events = calendar_result.get('events', [])
                            if events:
                                event_list = "\n".join([f"📅 {event['summary']} - {event['start'].get('dateTime', event['start'].get('date', ''))}" for event in events[:5]])
                                state['current_output'] = f"🔍 찾은 일정들을 보여드릴게요:\n\n{event_list}"
                            else:
                                state['current_output'] = "🔍 검색하신 조건에 맞는 일정을 찾지 못했어요.\n\n다른 키워드로 다시 검색해보시겠어요?"
                    else:
                        error_msg = calendar_result.get('error', '알 수 없는 오류가 발생했습니다.')
                        state['current_output'] = f"❌ 앗, 문제가 발생했어요.\n\n{error_msg}\n\n다시 시도해주시거나 다른 방법으로 말씀해주세요."
                
                # 메시지 히스토리에 추가
                state['messages'].append({"role": "user", "content": state['current_input']})
                state['messages'].append({"role": "assistant", "content": state['current_output']})
                
                return state
                
            except Exception as e:
                print(f"응답 생성 중 오류: {str(e)}")
                state['current_output'] = "죄송해요, 응답을 생성하는 중에 문제가 발생했어요. 다시 시도해주세요. 😅"
                return state
        
        # 그래프 정의
        builder = StateGraph(CalendarState)
        
        # 노드 추가
        builder.add_node("classify_intent", classify_intent)
        builder.add_node("extract_information", extract_information)
        builder.add_node("determine_action", determine_action)
        builder.add_node("execute_calendar_action", execute_calendar_action)
        builder.add_node("generate_response", generate_response)
        
        # 엣지 정의
        builder.set_entry_point("classify_intent")
        builder.add_edge("classify_intent", "extract_information")
        builder.add_edge("extract_information", "determine_action")
        
        # 조건부 엣지: 일정 관련 작업인지 일반 대화인지에 따라 분기
        def should_execute_calendar_action(state: CalendarState) -> str:
            action_type = state.get('action_type', 'chat')
            if action_type == 'chat':
                return "generate_response"
            else:
                return "execute_calendar_action"
        
        builder.add_conditional_edges(
            "determine_action",
            should_execute_calendar_action,
            {
                "execute_calendar_action": "execute_calendar_action",
                "generate_response": "generate_response"
            }
        )
        
        builder.add_edge("execute_calendar_action", "generate_response")
        builder.add_edge("generate_response", END)
        
        # 그래프 컴파일
        return builder.compile()
    
    def _extract_delete_information(self, state: CalendarState, current_date: datetime, rule_text: str) -> CalendarState:
        """삭제 관련 정보 추출 (다중 삭제 및 전체 삭제 지원)"""
        try:
            user_input = state['current_input']
            
            # 먼저 키워드 기반으로 전체 삭제 여부를 확인
            bulk_keywords = ['모든', '모두', '전체', '다 삭제', '다삭제', '다 지워', '다지워', '모두 삭제', '모두삭제', '전체 삭제', '전체삭제']
            mixed_keywords = ['그리고', '또', '그 다음에', '추가로', '또한', '그리고는', '와', '과', '하고']
            
            has_bulk_keyword = any(keyword in user_input for keyword in bulk_keywords)
            has_mixed_keyword = any(keyword in user_input for keyword in mixed_keywords)
            has_delete_keyword = any(keyword in user_input for keyword in ['삭제', '지워', '제거', '없애'])
            
            print(f"키워드 감지: 전체삭제={has_bulk_keyword}, 혼합={has_mixed_keyword}, 삭제={has_delete_keyword}")
            print(f"사용자 입력: '{user_input}'")
            
            # 혼합 삭제 패턴 강화 - "일정과"나 "의 전체" 패턴 감지
            enhanced_mixed_patterns = [
                r'.*일정[과와].*전체.*일정',  # "헬스 일정과 ... 전체 일정"
                r'.*[과와].*[의의].*전체',    # "일정과 ... 의 전체"
                r'.*삭제.*[과와하고].*전체',  # "삭제하고 ... 전체"
                r'.*전체.*[과와하고].*삭제',  # "전체 ... 와 삭제"
                r'.*일정[과와].*금요일.*전체', # "일정과 금요일 전체"
                r'.*[과와].*요일.*전체',       # "과 ... 요일 전체"
                r'.*요일.*전체.*일정',        # "요일 ... 전체 일정"
            ]
            
            enhanced_mixed_detected = False
            matched_pattern = ""
            for pattern in enhanced_mixed_patterns:
                if re.search(pattern, user_input, re.IGNORECASE):
                    enhanced_mixed_detected = True
                    matched_pattern = pattern
                    print(f"강화된 혼합 패턴 감지: '{pattern}' in '{user_input}'")
                    break
            
            print(f"Enhanced mixed detection: {enhanced_mixed_detected}, Pattern: {matched_pattern}")
            
            is_mixed_delete = (has_bulk_keyword and has_mixed_keyword and has_delete_keyword) or enhanced_mixed_detected
            is_bulk_only = has_bulk_keyword and not has_mixed_keyword and has_delete_keyword and not enhanced_mixed_detected
            
            print(f"Final decision details:")
            print(f"  - has_bulk_keyword: {has_bulk_keyword}")
            print(f"  - has_mixed_keyword: {has_mixed_keyword}")
            print(f"  - has_delete_keyword: {has_delete_keyword}")
            print(f"  - enhanced_mixed_detected: {enhanced_mixed_detected}")
            print(f"  - is_mixed_delete: {is_mixed_delete}")
            print(f"  - is_bulk_only: {is_bulk_only}")
            
            # 더 간단한 패턴으로 전체 삭제 감지 강화
            simple_bulk_patterns = [
                '전체 삭제', '모두 삭제', '다 삭제', '모든 삭제', '전부 삭제',
                '전체 지워', '모두 지워', '다 지워', '모든 지워', '전부 지워',
                '전체삭제', '모두삭제', '다삭제', '모든삭제', '전부삭제',
                '일정 전체', '일정 모두', '일정 다', '일정 모든',
                '스케줄 전체', '스케줄 모두', '스케줄 다', '스케줄 모든'
            ]
            
            if not is_bulk_only and not is_mixed_delete:
                for pattern in simple_bulk_patterns:
                    if pattern in user_input:
                        if any(mixed_word in user_input for mixed_word in mixed_keywords):
                            is_mixed_delete = True
                            print(f"간단 패턴으로 혼합 삭제 감지: '{pattern}'")
                        else:
                            is_bulk_only = True
                            print(f"간단 패턴으로 전체 삭제 감지: '{pattern}'")
                        break
            
            # 정규표현식으로 추가 확인 (더 유연한 패턴)
            if not is_mixed_delete and not is_bulk_only:
                # 혼합 삭제 패턴 확인 (개별 삭제 + 전체 삭제)
                mixed_patterns = [
                    r'.*(삭제|지워|제거).*(그리고|또|그 다음에|추가로).*(모든|모두|전체|다)\s*(일정|스케줄)?.*(삭제|지워|제거)',
                    r'.*(모든|모두|전체|다)\s*(일정|스케줄)?.*(삭제|지워|제거).*(그리고|또|그 다음에|추가로).*(삭제|지워|제거)',
                ]
                
                # 전체 삭제만 있는 패턴 확인 (더 유연하게)
                bulk_only_patterns = [
                    r'(모든|모두|전체|다)\s*(일정|스케줄)?\s*(삭제|지워|제거|없애)',
                    r'(일정|스케줄)?\s*(모든|모두|전체|다)\s*(삭제|지워|제거|없애)',
                    r'(다\s*삭제|모두\s*삭제|전체\s*삭제|모두\s*지워|다\s*지워)',
                ]
                
                # 혼합 삭제 패턴 확인
                for pattern in mixed_patterns:
                    if re.search(pattern, user_input, re.IGNORECASE):
                        is_mixed_delete = True
                        print(f"정규식으로 혼합 삭제 감지: '{user_input}'")
                        break
                
                # 전체 삭제만 있는 패턴 확인 (혼합이 아닌 경우에만)
                if not is_mixed_delete:
                    for pattern in bulk_only_patterns:
                        if re.search(pattern, user_input, re.IGNORECASE):
                            is_bulk_only = True
                            print(f"정규식으로 전체 삭제만 감지: '{user_input}'")
                            break
            
            print(f"최종 판단: 혼합삭제={is_mixed_delete}, 전체삭제={is_bulk_only}")
            
            if is_mixed_delete:
                # 혼합 삭제 처리 (개별 삭제 + 전체 삭제)
                prompt = f"""
현재 날짜: {current_date.strftime('%Y년 %m월 %d일 %A')}
현재 시간: {current_date.strftime('%H:%M')}

사용자가 개별 일정 삭제와 전체 일정 삭제를 함께 요청했습니다:
"{user_input}"

**중요**: 이 입력에는 2개의 서로 다른 삭제 작업이 포함되어 있습니다.

상대적 표현 해석 규칙:
{rule_text}

**단계별 분석 과정:**
1. 먼저 연결어("와", "과", "하고", "그리고" 등)로 문장을 분리하세요
2. 각 부분에서 날짜와 일정명을 따로 추출하세요
3. "전체", "모든", "모두", "다" 키워드가 있는 부분은 bulk 타입
4. 구체적인 일정명이 있는 부분은 individual 타입

**구체적 분석 예시:**
"내일 헬스 일정과 금요일의 전체 일정을 삭제해줘"
→ 분리: ["내일 헬스 일정", "금요일의 전체 일정"]
→ 1번째: "내일 헬스" = individual, 날짜="내일", 제목="헬스"
→ 2번째: "금요일의 전체" = bulk, 날짜="금요일"

"16일 회의 삭제하고 18일 일정 전체 삭제해줘"
→ 분리: ["16일 회의", "18일 일정 전체"]
→ 1번째: "16일 회의" = individual, 날짜="16일", 제목="회의"
→ 2번째: "18일 일정 전체" = bulk, 날짜="18일"

반드시 다음 JSON 형식으로만 응답해주세요:
{{
    "delete_type": "mixed",
    "actions": [
        {{
            "type": "individual",
            "title": "첫 번째 일정의 제목만 (헬스, 회의 등)",
            "date": "첫 번째 날짜를 YYYY-MM-DD 형식으로",
            "time": null,
            "description": "첫 번째 일정 설명"
        }},
        {{
            "type": "bulk", 
            "target_date": "두 번째 날짜를 YYYY-MM-DD 형식으로",
            "date_description": "두 번째 날짜 설명 (금요일, 18일 등)"
        }}
    ]
}}

**날짜 변환 주의사항:**
- "내일" → {(current_date + timedelta(days=1)).strftime('%Y-%m-%d')}
- "이번주 금요일" → 상대적 표현 규칙 참조하여 정확한 날짜
- "16일", "18일" → 현재 월 기준으로 2024-01-16, 2024-01-18
- 반드시 각 액션마다 서로 다른 날짜를 설정하세요

**제목 추출 주의사항:**
- "헬스 일정과" → title: "헬스" (일정, 과 제거)
- "회의 삭제하고" → title: "회의" (삭제하고 제거)
- 순수한 일정명만 추출하세요"""
            elif is_bulk_only:
                # 전체 삭제 처리
                prompt = f"""
현재 날짜: {current_date.strftime('%Y년 %m월 %d일 %A')}
현재 시간: {current_date.strftime('%H:%M')}

사용자가 특정 날짜의 모든 일정을 삭제하고 싶어합니다:
"{user_input}"

상대적 표현 해석 규칙:
{rule_text}

반드시 다음 JSON 형식으로만 응답해주세요:
{{
    "delete_type": "bulk",
    "target_date": "YYYY-MM-DD",
    "date_description": "날짜 설명 (예: 내일, 다음주 월요일)"
}}

추출 가이드라인:
1. 삭제할 날짜를 정확히 파악하세요
2. 상대적 표현을 절대 날짜로 변환하세요
3. 날짜가 명시되지 않으면 "오늘"로 간주하세요
4. 전체 삭제 예시:
   - "오늘 일정 전체 삭제해줘" → target_date: "{current_date.strftime('%Y-%m-%d')}"
   - "내일 모든 일정 지워줘" → target_date: "{(current_date + timedelta(days=1)).strftime('%Y-%m-%d')}"
   - "18일 일정 다 삭제해줘" → target_date: "2024-01-18" (적절한 월/년 추가)
   - "이번주 금요일 일정 모두 삭제" → 해당 금요일 날짜로 변환

반드시 target_date 필드를 정확한 YYYY-MM-DD 형식으로 제공해야 합니다.
"""
            else:
                # 개별 삭제 또는 다중 개별 삭제 처리
                detection_prompt = f"""
사용자 입력에서 삭제할 일정의 개수를 분석해주세요:
"{user_input}"

다음 중 하나로 응답해주세요:
- "SINGLE": 하나의 일정만 삭제
- "MULTIPLE": 여러 개의 일정을 삭제

다중 삭제 판단 기준:
- "그리고", "또", "그 다음에", "추가로" 등의 연결어로 여러 일정을 언급
- 예: "내일 회의 삭제하고 다음주 월요일 점심약속도 삭제해줘"
- 예: "팀 미팅 지우고 개인 약속도 취소해줘"
- 예: "헬스 일정과 요가 일정 삭제해줘" (두 개의 개별 일정)

주의: 다음과 같은 경우는 MULTIPLE이 아닌 SINGLE로 판단하세요:
- "내일 헬스 일정과 금요일의 전체 일정을 삭제해줘" (이미 혼합삭제로 처리됨)
- 개별 일정과 전체 삭제가 섞인 경우 (혼합삭제 패턴)
"""
                
                detection_response = self.client.chat.completions.create(
                    model="gpt-4o-mini",
                    messages=[{"role": "user", "content": detection_prompt}],
                    temperature=0.1
                )
                
                is_multiple = "MULTIPLE" in detection_response.choices[0].message.content.strip()
                
                if is_multiple:
                    # 다중 개별 삭제
                    prompt = f"""
현재 날짜: {current_date.strftime('%Y년 %m월 %d일 %A')}
현재 시간: {current_date.strftime('%H:%M')}

사용자가 여러 일정을 삭제하고 싶어합니다:
"{user_input}"

상대적 표현 해석 규칙:
{rule_text}

반드시 다음 JSON 형식으로만 응답해주세요:
{{
    "delete_type": "multiple",
    "targets": [
        {{
            "title": "삭제할 일정 제목",
            "date": "YYYY-MM-DD",
            "time": "HH:MM (선택사항)",
            "description": "일정 설명"
        }}
    ]
}}

추출 가이드라인:
1. 각 삭제 대상을 별도의 객체로 분리
2. 연결어를 기준으로 일정을 분리
3. 삭제할 일정의 핵심 키워드를 추출 (불필요한 키워드 제거)
   - 사용자 입력: "맥주 일정과 회의 삭제해줘" → ["맥주", "회의"]
   - 불필요한 키워드 제거: "일정", "삭제", "지워", "제거", "해줘" 등
4. 날짜와 시간을 정확히 추출
"""
                else:
                    # 단일 개별 삭제
                    prompt = f"""
현재 날짜: {current_date.strftime('%Y년 %m월 %d일 %A')}
현재 시간: {current_date.strftime('%H:%M')}

사용자가 특정 일정을 삭제하고 싶어합니다:
"{user_input}"

상대적 표현 해석 규칙:
{rule_text}

반드시 다음 JSON 형식으로만 응답해주세요:
{{
    "delete_type": "single",
    "title": "삭제할 일정 제목",
    "date": "YYYY-MM-DD",
    "time": "HH:MM (선택사항)",
    "description": "일정 설명"
}}

추출 가이드라인:
1. 삭제할 일정의 핵심 키워드를 추출 (제목에서 불필요한 키워드 제거)
   - 사용자 입력: "맥주 일정 삭제해줘" → title: "맥주"
   - 사용자 입력: "회의 지워줘" → title: "회의"
   - 불필요한 키워드 제거: "일정", "삭제", "지워", "제거", "해줘" 등
2. 상대적 날짜 표현을 절대 날짜로 변환
3. 시간이 명시되지 않으면 null로 설정
"""
            
            response = self.client.chat.completions.create(
                model="gpt-4o-mini",
                messages=[{"role": "user", "content": prompt}],
                temperature=0.1
            )
            
            response_text = response.choices[0].message.content.strip()
            print(f"삭제 정보 추출 응답: {response_text}")
            
            # 기본값 설정
            default_delete_info = {
                "delete_type": "single",
                "title": "삭제할 일정",
                "date": current_date.strftime('%Y-%m-%d'),
                "time": None,
                "description": ""
            }
            
            # 안전한 JSON 파싱
            extracted_info = safe_json_parse(response_text, default_delete_info)
            
            # 혼합 삭제의 경우 추출된 정보 상세 로깅
            if extracted_info.get('delete_type') == 'mixed':
                print("=== 혼합 삭제 정보 추출 결과 ===")
                actions = extracted_info.get('actions', [])
                print(f"총 액션 수: {len(actions)}")
                
                for i, action in enumerate(actions):
                    print(f"액션 {i+1}:")
                    print(f"  - type: {action.get('type')}")
                    if action.get('type') == 'individual':
                        print(f"  - title: {action.get('title')}")
                        print(f"  - date: {action.get('date')}")
                        print(f"  - time: {action.get('time')}")
                    elif action.get('type') == 'bulk':
                        print(f"  - target_date: {action.get('target_date')}")
                        print(f"  - date_description: {action.get('date_description')}")
                
                # 날짜 유효성 검사
                for i, action in enumerate(actions):
                    if action.get('type') == 'individual' and action.get('date'):
                        try:
                            parsed_date = datetime.strptime(action['date'], '%Y-%m-%d')
                            print(f"액션 {i+1} 개별 삭제 날짜 파싱 성공: {parsed_date}")
                        except ValueError as e:
                            print(f"액션 {i+1} 개별 삭제 날짜 파싱 실패: {e}")
                    
                    if action.get('type') == 'bulk' and action.get('target_date'):
                        try:
                            parsed_date = datetime.strptime(action['target_date'], '%Y-%m-%d')
                            print(f"액션 {i+1} 전체 삭제 날짜 파싱 성공: {parsed_date}")
                        except ValueError as e:
                            print(f"액션 {i+1} 전체 삭제 날짜 파싱 실패: {e}")
                
                print("=== 혼합 삭제 정보 추출 완료 ===")
            
            state['extracted_info'] = extracted_info
            return state
            
        except Exception as e:
           

            print(f"삭제 정보 추출 중 오류: {str(e)}")
            default_delete_info = {
                "delete_type": "single",
                "title": "삭제할 일정",
                "date": current_date.strftime('%Y-%m-%d'),
                "time": None,
                "description": ""
            }
            state['extracted_info'] = default_delete_info
            return state
    
    def _extract_update_information(self, state: CalendarState, current_date: datetime, rule_text: str) -> CalendarState:
        """수정 관련 정보 추출 (다중 수정 지원)"""
        try:
            user_input = state['current_input']
            
            # 다중 수정 여부 판단
            detection_prompt = f"""
사용자 입력에서 수정할 일정의 개수를 분석해주세요:
"{user_input}"

다음 중 하나로 응답해주세요:
- "SINGLE": 하나의 일정만 수정
- "MULTIPLE": 여러 개의 일정을 수정

다중 수정 판단 기준:
- "그리고", "또", "그 다음에", "추가로" 등의 연결어로 여러 수정 요청을 언급
- 예: "오늘 헬스 일정 오후 3시로 바꾸고 다음주 드라이브 일정을 헬스로 이름 바꿔줘"
- 예: "팀 미팅 시간 4시로 바꾸고 프로젝트 회의도 내일로 옮겨줘"
"""
            
            detection_response = self.client.chat.completions.create(
                model="gpt-4o-mini",
                messages=[{"role": "user", "content": detection_prompt}],
                temperature=0.1
            )
            
            is_multiple = "MULTIPLE" in detection_response.choices[0].message.content.strip()
            
            if is_multiple:
                # 다중 수정 처리
                prompt = f"""
현재 날짜: {current_date.strftime('%Y년 %m월 %d일 %A')}
현재 시간: {current_date.strftime('%H:%M')}

사용자가 여러 일정을 수정하고 싶어합니다:
"{user_input}"

상대적 표현 해석 규칙:
{rule_text}

반드시 다음 JSON 형식으로만 응답해주세요:
{{
    "update_type": "multiple",
    "updates": [
        {{
            "target": {{
                "title": "수정할 일정 제목",
                "date": "YYYY-MM-DD",
                "time": "HH:MM (선택사항)",
                "description": "일정 설명"
            }},
            "changes": {{
                "title": "새로운 제목 (변경시에만)",
                "start_time": "새로운 시작 시간 (변경시에만)",
                "end_time": "새로운 종료 시간 (변경시에만)",
                "start_date": "새로운 날짜 (변경시에만)",
                "description": "새로운 설명 (변경시에만)",
                "location": "새로운 장소 (변경시에만)"
            }}
        }}
    ]
}}

중요한 시간 처리 규칙:
1. 사용자가 시간 범위를 명시한 경우 (예: "오후 2시~4시", "14:00-16:00"): start_time과 end_time 모두 설정
2. 사용자가 시작 시간만 명시한 경우 (예: "오후 4시로 바꿔줘", "16:00으로 변경"): start_time만 설정하고 end_time은 null
3. end_time이 null인 경우 프론트엔드에서 자동으로 1시간 후로 설정됨
4. 절대 24시간 이상의 일정을 만들지 말 것

추출 가이드라인:
1. 각 수정 요청을 별도의 객체로 분리
2. 연결어를 기준으로 수정 요청을 분리
3. target에는 수정할 일정의 식별 정보 (키워드로 검색할 수 있도록 핵심 키워드만 추출)
   - 사용자 입력: "맥주 일정을 오후 4시로 수정해줘" → target.title: "맥주"
   - 사용자 입력: "회의 시간을 3시로 바꿔줘" → target.title: "회의"
   - 사용자 입력: "친구와의 저녁 약속을 6시로 변경" → target.title: "친구"
   - 불필요한 키워드 제거: "일정", "수정", "변경", "바꿔", "해줘", "시간을", "으로" 등
4. changes에는 변경할 내용만 포함 (변경되지 않는 항목은 제외)
5. 상대적 날짜 표현을 절대 날짜로 변환
6. 시간 범위가 명확하지 않으면 end_time을 null로 설정하여 기본 1시간 일정으로 처리
"""
            else:
                # 단일 수정 처리
                prompt = f"""
현재 날짜: {current_date.strftime('%Y년 %m월 %d일 %A')}
현재 시간: {current_date.strftime('%H:%M')}

사용자가 특정 일정을 수정하고 싶어합니다:
"{user_input}"

상대적 표현 해석 규칙:
{rule_text}

반드시 다음 JSON 형식으로만 응답해주세요:
{{
    "update_type": "single",
    "target": {{
        "title": "수정할 일정 제목",
        "date": "YYYY-MM-DD",
        "time": "HH:MM (선택사항)",
        "description": "일정 설명"
    }},
    "changes": {{
        "title": "새로운 제목 (변경시에만)",
        "start_time": "새로운 시작 시간 (변경시에만)",
        "end_time": "새로운 종료 시간 (변경시에만)",
        "start_date": "새로운 날짜 (변경시에만)",
        "description": "새로운 설명 (변경시에만)",
        "location": "새로운 장소 (변경시에만)"
    }}
}}

중요한 시간 처리 규칙:
1. 사용자가 시간 범위를 명시한 경우 (예: "오후 2시~4시", "14:00-16:00"): start_time과 end_time 모두 설정
2. 사용자가 시작 시간만 명시한 경우 (예: "오후 4시로 바꿔줘", "16:00으로 변경"): start_time만 설정하고 end_time은 null
3. end_time이 null인 경우 프론트엔드에서 자동으로 1시간 후로 설정됨
4. 절대 24시간 이상의 일정을 만들지 말 것
5. 상대적 날짜 표현을 절대 날짜로 변환
6. 시간이 명시되지 않으면 null로 설정

추출 가이드라인:
1. target에는 수정할 일정의 식별 정보 (키워드로 검색할 수 있도록 핵심 키워드만 추출)
   - 사용자 입력: "맥주 일정을 오후 4시로 수정해줘" → target.title: "맥주"
   - 사용자 입력: "회의 시간을 3시로 바꿔줘" → target.title: "회의"  
   - 사용자 입력: "친구와의 저녁 약속을 6시로 변경" → target.title: "친구"
   - 불필요한 키워드 제거: "일정", "수정", "변경", "바꿔", "해줘", "시간을", "으로" 등
2. changes에는 변경할 내용만 포함 (변경되지 않는 항목은 제외)
3. 시간 범위가 명확하지 않으면 end_time을 null로 설정하여 기본 1시간 일정으로 처리
"""
            
            response = self.client.chat.completions.create(
                model="gpt-4o-mini",
                messages=[{"role": "user", "content": prompt}],
                temperature=0.1
            )
            
            response_text = response.choices[0].message.content.strip()
            print(f"수정 정보 추출 응답: {response_text}")
            
            # 기본값 설정
            default_update_info = {
                "update_type": "single",
                "target": {
                    "title": "수정할 일정",
                    "date": current_date.strftime('%Y-%m-%d'),
                    "time": None,
                    "description": ""
                },
                "changes": {
                    "title": None
                }
            }
            
            # 안전한 JSON 파싱
            extracted_info = safe_json_parse(response_text, default_update_info)
            
            state['extracted_info'] = extracted_info
            return state
            
        except Exception as e:
            print(f"수정 정보 추출 중 오류: {str(e)}")
            default_update_info = {
                "update_type": "single",
                "target": {
                    "title": "수정할 일정",
                    "date": current_date.strftime('%Y-%m-%d'),
                    "time": None,
                    "description": ""
                },
                "changes": {
                    "title": None
                }
            }
            state['extracted_info'] = default_update_info
            return state
    
    def _extract_range_events(self, state: CalendarState, current_date: datetime, rule_text: str) -> CalendarState:
        """기간/범위 기반 일정 정보 추출 및 개별 일정로 변환"""
        try:
            user_input = state['current_input']
            
            # 기간/범위 정보 추출
            prompt = f"""
현재 날짜: {current_date.strftime('%Y년 %m월 %d일 %A')}
현재 시간: {current_date.strftime('%H:%M')}

사용자가 기간이 있는 일정을 요청했습니다. 이를 Multi Day Event로 처리해주세요:
"{user_input}"

상대적 표현 해석 규칙:
{rule_text}

반드시 다음 JSON 형식으로만 응답해주세요:
{{
    "title": "일정 제목",
    "start_date": "YYYY-MM-DD (시작날짜)",
    "end_date": "YYYY-MM-DD (종료날짜)",
    "start_time": "HH:MM (선택사항)",
    "end_time": "HH:MM (선택사항)",
    "description": "상세 설명",
    "location": "장소",
    "all_day": true/false,
    "timezone": "Asia/Seoul",
    "priority": "normal|high|low",
    "category": "other",
    "is_multi_day": true
}}

Multi Day Event 처리 가이드라인:
1. 기간 표현 인식:
   - "6월 15일부터 20일까지" → start_date: "2025-06-15", end_date: "2025-06-20"
   - "내일부터 다음주까지" → 해당 날짜 범위로 변환
   - "3일간", "5일간" → 시작일 기준으로 해당 일수만큼 계산
   - "2박3일", "1박2일" → 박수 기준으로 일수 계산 (2박3일 = 3일간)
   - "주말 내내" → 토요일부터 일요일까지
   - "연휴 내내" → 연휴 기간 전체

    "category": "other",
   - 종료일은 포함되는 마지막 날짜
   - "6월 15일부터 20일까지" → 20일도 포함
   - "3일간" → 시작일 + 2일 (총 3일)

3. 시간 처리:
   - 시간이 명시되지 않은 경우 all_day: true   - "오전 9시부터 오후 6시까지 3일간" → start_time: "09:00", end_time: "18:00", all_day: false
   - 매일 같은 시간대 적용

예시:
- "6월 15일부터 20일까지 휴가" → start_date: "2025-06-15", end_date: "2025-06-20", all_day: true, category: "other"
- "다음주 월요일부터 금요일까지 오전 9시부터 오후 6시까지 교육" → start_date: "다음주월요일", end_date: "다음주금요일", start_time: "09:00", end_time: "18:00", all_day: false
- "3일간 워크샵" → start_date: 시작일, end_date: 시작일+2일, all_day: true
"""
            
            response = self.client.chat.completions.create(
                model="gpt-4o-mini",
                messages=[{"role": "user", "content": prompt}],
                temperature=0.1
            )
            
            response_text = response.choices[0].message.content.strip()
            print(f"기간 정보 추출 응답: {response_text}")
            
            # 기본값 설정
            default_range_info = {
                "title": extract_title_from_input(user_input),
                "start_date": current_date.strftime('%Y-%m-%d'),
                "end_date": (current_date + timedelta(days=1)).strftime('%Y-%m-%d'),
                "start_time": None,
                "end_time": None,
                "description": "",
                "location": "",
                "all_day": True,
                "timezone": "Asia/Seoul",
                "priority": "normal",
                "category": "other",
                "is_multi_day": True
            }
            
            # 안전한 JSON 파싱
            range_data = safe_json_parse(response_text, default_range_info)
            
            # Multi Day Event 검증 및 보정
            validated_event = validate_and_correct_info(range_data, current_date)
            validated_event["is_multi_day"] = True
            
            # 종료일이 시작일보다 이전인 경우 보정
            try:
                start_date = datetime.strptime(validated_event["start_date"], '%Y-%m-%d')
                end_date = datetime.strptime(validated_event["end_date"], '%Y-%m-%d')
                
                if end_date < start_date:
                    validated_event["end_date"] = validated_event["start_date"]
                elif end_date == start_date:
                    # 하루짜리면 Multi Day가 아님
                    validated_event["is_multi_day"] = False
                    
            except:
                validated_event["end_date"] = validated_event["start_date"]
                validated_event["is_multi_day"] = False
            
            extracted_info = {
                "events": [validated_event],
                "is_multiple": False,
                "is_multi_day": True,
                "event_type": "multi_day"
            }
            
            state['extracted_info'] = extracted_info
            return state
            
        except Exception as e:
            print(f"기간 정보 추출 중 오류: {str(e)}")
            default_info = get_default_event_info()
            default_info["title"] = extract_title_from_input(user_input)
            default_info["is_multi_day"] = False
            state['extracted_info'] = {"events": [default_info], "is_multiple": False, "is_multi_day": False}
            return state
    
    def _convert_range_to_events(self, range_data: Dict[str, Any], current_date: datetime) -> List[Dict[str, Any]]:
        """기간 정보를 개별 일정 리스트로 변환"""
        try:
            events = []
            range_type = range_data.get("range_type", "date_range")
            range_info = range_data.get("range_info", {})
            
            # 공통 이벤트 데이터
            base_event = {
                "title": range_data.get("title", "새 일정"),
                "start_time": range_data.get("start_time"),
                "end_time": range_data.get("end_time"),
                "description": range_data.get("description", ""),
                "location": range_data.get("location", ""),
                "all_day": False,
                "timezone": "Asia/Seoul",
                "priority": "normal",
                "category": "other"
            }
            
            if range_type == "date_range":
                # 날짜 범위: "6월 15일부터 20일까지"
                start_date_str = range_info.get("start_date")
                end_date_str = range_info.get("end_date")
                
                if start_date_str and end_date_str:
                    start_date = datetime.strptime(start_date_str, '%Y-%m-%d')
                    end_date = datetime.strptime(end_date_str, '%Y-%m-%d')
                    
                    current = start_date
                    while current <= end_date:
                        event = base_event.copy()                        
                        event["start_date"] = current.strftime('%Y-%m-%d')
                        event["end_date"] = current.strftime('%Y-%m-%d')
                        events.append(event)
                        current += timedelta(days=1)
            
            elif range_type == "weekday_range":
                # 요일 범위: "월요일부터 금요일까지" (이번주와 다음주)
                start_weekday = range_info.get("start_weekday", 1)  # 월요일
                end_weekday = range_info.get("end_weekday", 5)      # 금요일
                base_date_str = range_info.get("base_date")
                repeat_count = range_info.get("repeat_count", 2)    # 기본 2주 (이번주와 다음주)
                
                # 기준 날짜 설정 (다음주 일요일 등)
                if base_date_str:
                    try:
                        base_date = datetime.strptime(base_date_str, '%Y-%m-%d')
                    except:
                        base_date = current_date + timedelta(days=7)  # 다음주로 기본 설정
                else:
                    base_date = current_date + timedelta(days=7)
                
                # 해당 주의 일요일 찾기
                days_to_sunday = (6 - base_date.weekday()) % 7
                week_start = base_date - timedelta(days=days_to_sunday)
                
                for week in range(repeat_count):
                    current_week_start = week_start + timedelta(weeks=week)
                    
                    # 해당 주의 지정된 요일들에 일정 추가
                    if start_weekday <= end_weekday:
                        # 정상적인 범위 (월-금)
                        for weekday in range(start_weekday, end_weekday + 1):
                            event_date = current_week_start + timedelta(days=weekday)
                            if event_date.date() >= current_date.date():  # 과거 날짜 제외
                                event = base_event.copy()
                                event["start_date"] = event_date.strftime('%Y-%m-%d')
                                event["end_date"] = event_date.strftime('%Y-%m-%d')
                                events.append(event)
                    else:
                        # 주말을 포함하는 범위 (금-월)
                        for weekday in list(range(start_weekday, 7)) + list(range(0, end_weekday + 1)):
                            event_date = current_week_start + timedelta(days=weekday)
                            if event_date.date() >= current_date.date():
                                event = base_event.copy()
                                event["start_date"] = event_date.strftime('%Y-%m-%d')
                                event["end_date"] = event_date.strftime('%Y-%m-%d')
                                events.append(event)
            
            elif range_type == "weekday_list":
                # 요일 리스트: "월,수,금요일에"
                weekdays = range_info.get("weekdays", [1, 3, 5])
                base_date_str = range_info.get("base_date")
                repeat_count = range_info.get("repeat_count", 4)    # 기본 4주
                
                # 기준 날짜 설정
                if base_date_str:
                    try:
                        base_date = datetime.strptime(base_date_str, '%Y-%m-%d')
                    except:
                        base_date = current_date + timedelta(days=7)
                else:
                    base_date = current_date + timedelta(days=7)
                # 해당 주의 일요일 찾기
                days_to_sunday = (6 - base_date.weekday()) % 7
                week_start = base_date - timedelta(days=days_to_sunday)
                
                for week in range(repeat_count):
                    current_week_start = week_start + timedelta(weeks=week)
                    
                    for weekday in weekdays:
                        event_date = current_week_start + timedelta(days=weekday)
                        if event_date.date() >= current_date.date():
                            event = base_event.copy()
                            event["start_date"] = event_date.strftime('%Y-%m-%d')
                            event["end_date"] = event_date.strftime('%Y-%m-%d')
                            events.append(event)
            
            elif range_type == "cross_week_range":
                # 주 걸침 범위: "이번주 화요일부터 다음주 목요일까지"
                start_weekday = range_info.get("start_weekday", 1)
                end_weekday = range_info.get("end_weekday", 5)
                start_week = range_info.get("start_week", "this_week")
                end_week = range_info.get("end_week", "next_week")
                
                # 이번 주의 일요일 찾기
                current_week_start = current_date - timedelta(days=current_date.weekday() + 1)
                if current_date.weekday() == 6:  # 일요일인 경우
                    current_week_start = current_date
                
                # 시작 주 계산
                if start_week == "this_week":
                    start_week_date = current_week_start
                elif start_week == "next_week":
                    start_week_date = current_week_start + timedelta(weeks=1)
                else:
                    start_week_date = current_week_start
                
                # 종료 주 계산
                if end_week == "this_week":
                    end_week_date = current_week_start
                elif end_week == "next_week":
                    end_week_date = current_week_start + timedelta(weeks=1)
                else:
                    end_week_date = current_week_start + timedelta(weeks=1)
                
                # 시작 날짜와 종료 날짜 계산
                start_date = start_week_date + timedelta(days=start_weekday)
                end_date = end_week_date + timedelta(days=end_weekday)
                
                # 연속된 날짜들에 일정 추가
                current = start_date
                while current <= end_date:
                    if current.date() >= current_date.date():  # 과거 날짜 제외
                        event = base_event.copy()
                        event["start_date"] = current.strftime('%Y-%m-%d')
                        event["end_date"] = current.strftime('%Y-%m-%d')
                        events.append(event)
                    current += timedelta(days=1)
            
            elif range_type == "single_week_range":
                # 단일 주 범위: "다음주 월요일부터 금요일까지"
                start_weekday = range_info.get("start_weekday", 1)
                end_weekday = range_info.get("end_weekday", 5)
                target_week = range_info.get("target_week", "next_week")
                
                # 이번 주의 일요일 찾기
                current_week_start = current_date - timedelta(days=current_date.weekday() + 1)
                if current_date.weekday() == 6:  # 일요일인 경우
                    current_week_start = current_date
                
                # 대상 주 계산
                if target_week == "this_week":
                    target_week_date = current_week_start
                elif target_week == "next_week":
                    target_week_date = current_week_start + timedelta(weeks=1)
                else:
                    target_week_date = current_week_start + timedelta(weeks=1)
                
                # 해당 주의 지정된 요일들에 일정 추가
                if start_weekday <= end_weekday:
                    # 정상적인 범위 (월-금)
                    for weekday in range(start_weekday, end_weekday + 1):
                        event_date = target_week_date + timedelta(days=weekday)
                        if event_date.date() >= current_date.date():  # 과거 날짜 제외
                            event = base_event.copy()
                            event["start_date"] = event_date.strftime('%Y-%m-%d')
                            event["end_date"] = event_date.strftime('%Y-%m-%d')
                            events.append(event)
                else:
                    # 주말을 포함하는 범위 (금-월)                    for weekday in list(range(start_weekday, 7)) + list(range(0, end_weekday + 1)):
                        event_date = target_week_date + timedelta(days=weekday)
                        if event_date.date() >= current_date.date():
                            event = base_event.copy()
                            event["start_date"] = event_date.strftime('%Y-%m-%d')
                            event["end_date"] = event_date.strftime('%Y-%m-%d')
                            events.append(event)
            
            print(f"기간 변환 결과: {range_type} -> {len(events)}개 일정 생성")
            return events
            
        except Exception as e:
            print(f"기간 변환 중 오류: {str(e)}")
            # 오류 시 기본 단일 일정 반환
            default_info = get_default_event_info()
            default_info["title"] = range_data.get("title", "새 일정")
            return [default_info]

    def _create_event_data(self, extracted_info: Dict[str, Any]) -> Dict[str, Any]:
        """추출된 정보를 Google Calendar API 형식으로 변환"""
        try:
            event_data = {
                'summary': extracted_info.get('title', '새 일정'),
                'description': extracted_info.get('description', ''),
                'location': extracted_info.get('location', ''),
            }
            
            # 시간 설정
            start_date = extracted_info.get('start_date')
            start_time = extracted_info.get('start_time')
            end_date = extracted_info.get('end_date', start_date)
            end_time = extracted_info.get('end_time')
            timezone = extracted_info.get('timezone', 'Asia/Seoul')
            
            if extracted_info.get('all_day', False):
                event_data['start'] = {'date': start_date}
                event_data['end'] = {'date': end_date}
            else:
                if start_time:
                    start_datetime = f"{start_date}T{start_time}:00"
                    event_data['start'] = {
                        'dateTime': start_datetime,
                        'timeZone': timezone
                    }
                
                if end_time:
                    end_datetime = f"{end_date}T{end_time}:00"
                    event_data['end'] = {
                        'dateTime': end_datetime,
                        'timeZone': timezone
                    }
                elif start_time:
                    # 종료 시간이 없으면 1시간 후로 설정
                    start_dt = datetime.strptime(f"{start_date} {start_time}", "%Y-%m-%d %H:%M")
                    end_dt = start_dt + timedelta(hours=1)
                    event_data['end'] = {
                        'dateTime': end_dt.strftime("%Y-%m-%dT%H:%M:00"),
                        'timeZone': timezone
                    }
            
            # 참석자 설정
            attendees = extracted_info.get('attendees', [])
            if attendees:
                event_data['attendees'] = [{'email': email} for email in attendees]
            
            # 알림 설정
            reminders = extracted_info.get('reminders', [15])
            if reminders:
                event_data['reminders'] = {
                    'useDefault': False,
                    'overrides': [
                        {'method': 'popup', 'minutes': minutes} for minutes in reminders
                    ]
                }
            
            return event_data
            
        except Exception as e:
            print(f"이벤트 데이터 생성 중 오류: {str(e)}")
            return {
                'summary': extracted_info.get('title', '새 일정'),
                'start': {'dateTime': datetime.now().isoformat(), 'timeZone': 'Asia/Seoul'},
                'end': {'dateTime': (datetime.now() + timedelta(hours=1)).isoformat(), 'timeZone': 'Asia/Seoul'}
            }
    
    async def process_calendar_input_with_workflow(
        self,
        user_input: str,
        chat_history: Optional[List[Dict[str, str]]] = None
    ) -> Dict[str, Any]:
        """워크플로우를 사용하여 캘린더 입력을 처리합니다."""
        try:
            if chat_history is None:
                chat_history = []
            
            # 시스템 메시지 추가
            if not any(msg.get("role") == "system" for msg in chat_history):
                chat_history.insert(0, {
                    "role": "system", 
                    "content": "당신은 AI 캘린더 어시스턴트입니다. 사용자의 일정을 관리하고 자연어로 대화하며 도움을 줍니다."
                })
            
            # 초기 상태 설정
            initial_state = {
                "messages": chat_history,
                "current_input": user_input,
                "current_output": None,
                "intent": None,
                "extracted_info": None,
                "action_type": None,
                "calendar_result": None,
                "context": None
            }
            
            # 워크플로우 실행
            result = await self._run_workflow_async(initial_state)
            
            return {
                "response": result["current_output"],
                "intent": result.get("intent"),
                "extracted_info": result.get("extracted_info"),
                "calendar_result": result.get("calendar_result"),
                "updated_history": result["messages"]
            }
            
        except Exception as e:
            print(f"워크플로우 처리 중 오류: {str(e)}")
            return {
                "response": "죄송합니다. 요청을 처리하는 중 오류가 발생했습니다.",
                "error": str(e)
            }
    
    async def _run_workflow_async(self, initial_state: CalendarState) -> CalendarState:
        """비동기적으로 워크플로우를 실행합니다."""
        # LangGraph는 동기 실행이므로 비동기 래퍼 사용
        import asyncio
        loop = asyncio.get_event_loop()
        return await loop.run_in_executor(None, self.workflow.invoke, initial_state)
    
    # =============================================================================
    # 기존 메서드들 (호환성 유지)
    # =============================================================================
    
    async def generate_response(
        self,
        messages: List[Dict[str, str]],
        temperature: float = 0.7,
        max_tokens: int = 1000
    ) -> str:
        """사용자 메시지에 대한 응답을 생성합니다."""
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
        """사용자 입력을 처리하여 일정 정보를 추출합니다."""
        # 새로운 워크플로우 사용
        return await self.process_calendar_input_with_workflow(user_input)
    
    async def chat_with_graph(
        self,
        message: str,
        session_id: str = "default",
        chat_history: Optional[List[Dict[str, str]]] = None
    ) -> Dict[str, Any]:
        """LangGraph를 사용하여 대화형 응답을 생성합니다."""
        # 새로운 워크플로우 사용
        return await self.process_calendar_input_with_workflow(message, chat_history)

# =============================================================================
# 테스트 및 디버깅용 함수들
# =============================================================================

def test_relative_date_rules():
    """상대적 날짜 규칙 테스트 함수"""
    # 테스트 날짜들
    test_dates = [
        datetime(2025, 6, 9),   # 월요일
        datetime(2025, 6, 11),  # 수요일  
        datetime(2025, 6, 13),  # 금요일
        datetime(2025, 6, 15),  # 일요일
    ]
    
    for test_date in test_dates:
        print(f"\n{'='*50}")
        print(f"기준 날짜: {test_date.strftime('%Y년 %m월 %d일 %A')}")
        print(f"{'='*50}")
        
        rules = get_relative_date_rules(test_date)
        
        # 주요 규칙들만 출력
        key_rules = ['오늘', '내일', '모레', '다음주', '다음주 월요일', '다음주 일요일']
        for key in key_rules:
            if key in rules:
                print(f"{key}: {rules[key]}")

def test_llm_service():
    """
    LLM 서비스 테스트 함수
    
    커스터마이징 포인트: 테스트 케이스 추가/수정 가능
    """
    import asyncio
    
    async def run_tests():
        service = LLMService()
          # 테스트 케이스들 - 일요일 기준 주 계산 테스트 포함
        test_cases = [
            # 기존 단일/다중 일정
            "내일 오후 3시에 팀 회의 일정 잡아줘",
            "다음주 월요일 오전 10시에 프레젠테이션",
            "다음주 일요일에 가족 모임",
            "내일 저녁 7시에 카페 일정 추가하고 다음주 월요일 오전 11시에 점심 일정 추가해줘",
            
            # 기간 기반 일정 테스트
            "6월 15일부터 20일까지 휴가",
            "월요일부터 금요일까지 오전 9시에 운동",
            "다음주 월,화,수요일에 교육",
            "매일 오전 8시에 조깅",
            "매주 월요일 오후 2시에 팀 미팅",
            "내일부터 다음주 금요일까지 출장",
            
            # 기타
            "오늘 일정 뭐 있어?",
            "회의 시간을 4시로 바꿔줘",
            "내일 미팅 취소해줘",
            "안녕하세요",
        ]
        
        for test_input in test_cases:
            print(f"\n{'='*50}")
            print(f"테스트 입력: {test_input}")
            print(f"{'='*50}")
            
            result = await service.process_calendar_input_with_workflow(test_input)
            
            print(f"의도: {result.get('intent')}")
            print(f"추출된 정보: {result.get('extracted_info')}")
            print(f"응답: {result.get('response')}")
    
    # 비동기 테스트 실행
    # asyncio.run(run_tests())

def debug_intent_classification(user_input: str):
    """
    의도 분류 디버깅 함수
    
    사용법: debug_intent_classification("내일 회의 일정 잡아줘")
    """
    result = keyword_based_classification(user_input)
    print(f"입력: {user_input}")
    print(f"키워드 분류 결과: {result}")
    
    # 제목 추출 테스트
    title = extract_title_from_input(user_input)
    print(f"추출된 제목: {title}")

def debug_time_parsing():
    """
    시간 파싱 디버깅 함수
    """
    current_date = datetime.now(pytz.timezone('Asia/Seoul'))
    test_info = {
        "start_date": current_date.strftime('%Y-%m-%d'),
        "start_time": "14:30",
        "end_time": None
    }
    
    validated = validate_and_correct_info(test_info, current_date)
    print(f"검증 전: {test_info}")
    print(f"검증 후: {validated}")

def debug_date_calculation():
    """
    날짜 계산 디버깅 함수 - 일요일 기준 주 계산 테스트
    """
    print("=== 일요일 기준 주 계산 테스트 ===")
    test_relative_date_rules()
    
    # 특정 입력에 대한 날짜 해석 테스트
    current_date = datetime.now(pytz.timezone('Asia/Seoul'))
    rules = get_relative_date_rules(current_date)
    
    print(f"\n현재 요일: {current_date.strftime('%A')}")
    print(f"다음주 = 다음 주 일요일: {rules.get('다음주')}")
    print(f"다음주 월요일: {rules.get('다음주 월요일')}")

def debug_range_events():
    """
    기간 기반 일정 디버깅 함수
    """
    import asyncio
    
    async def test_range_extraction():
        service = LLMService()
        
        range_test_cases = [
            "6월 15일부터 20일까지 휴가",
            "월요일부터 금요일까지 오전 9시에 운동", 
            "다음주 월,화,수요일에 교육",
            "매일 오전 8시에 조깅",
            "매주 월요일 오후 2시에 팀 미팅",
            "내일부터 다음주 금요일까지 출장",
            "매월 15일에 월례회의"
        ]
        
        for test_input in range_test_cases:
            print(f"\n{'='*60}")
            print(f"기간 테스트 입력: {test_input}")
            print(f"{'='*60}")
            
            result = await service.process_calendar_input_with_workflow(test_input)
            
            print(f"의도: {result.get('intent')}")
            extracted_info = result.get('extracted_info', {})
            print(f"기간 여부: {extracted_info.get('is_range', False)}")
            print(f"기간 타입: {extracted_info.get('range_type', 'N/A')}")
            print(f"생성된 일정 수: {len(extracted_info.get('events', []))}")
            
            # 처음 3개 일정만 미리보기
            events = extracted_info.get('events', [])
            if events:
                print("일정 미리보기:")
                for i, event in enumerate(events[:3]):
                    print(f"  {i+1}. {event.get('title')} - {event.get('start_date')} {event.get('start_time', '')}")
                if len(events) > 3:
                    print(f"  ... 외 {len(events) - 3}개 더")
            
            print(f"응답: {result.get('response')}")
    
    # 비동기 테스트 실행
    asyncio.run(test_range_extraction())

# 사용 예시:
# if __name__ == "__main__":
#     debug_date_calculation()
#     test_llm_service()
#     debug_intent_classification("다음주 일요일에 가족 모임")
#     debug_time_parsing()
#     debug_range_events()  # 새로운 기간 기반 일정 테스트