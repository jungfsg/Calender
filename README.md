# AI Calendar - 인공지능 캘린더 앱

Flutter와 FastAPI를 사용한 AI 기반 캘린더 애플리케이션입니다.
자연어로 일정을 관리하고 Google Calendar와 연동됩니다.

## 주요 기능

### AI 캘린더 워크플로우
- **의도 분류**: 사용자 입력이 일정 관련인지 일반 대화인지 자동 판단
- **정보 추출**: 날짜, 시간, 제목, 참석자, 반복 설정 등 자동 추출
- **작업 실행**: Google Calendar API를 통한 일정 CRUD 작업
- **응답 생성**: 자연스러운 한국어 응답 및 결과 피드백

### 지원하는 일정 작업
- ✅ 일정 추가 (새로운 일정 생성)
- ✅ 일정 수정 (기존 일정 업데이트)
- ✅ 일정 삭제 (일정 제거)
- ✅ 일정 검색 (키워드 기반 검색)
- ✅ 일정 복사 (일정 복제)
- ✅ 일정 이동 (캘린더 간 이동)
- ✅ 충돌 검사 (시간 겹침 확인)

## 설정 방법

### 1. 환경 변수 설정
프로젝트 루트에 `.env` 파일을 생성하고 다음 내용을 추가하세요:

```bash
# OpenAI API 설정
OPENAI_API_KEY=your_openai_api_key_here

# Google Calendar API 설정
GOOGLE_CALENDAR_CREDENTIALS={"installed":{"client_id":"your_client_id","project_id":"your_project_id","auth_uri":"https://accounts.google.com/o/oauth2/auth","token_uri":"https://oauth2.googleapis.com/token","auth_provider_x509_cert_url":"https://www.googleapis.com/oauth2/v1/certs","client_secret":"your_client_secret","redirect_uris":["http://localhost"]}}

# ChromaDB 설정
CHROMADB_HOST=localhost
CHROMADB_PORT=9000
CHROMADB_PERSIST_DIR=./chroma_db

# 로깅 설정
LOG_LEVEL=INFO
```

### 2. Google Calendar API 설정
1. [Google Cloud Console](https://console.cloud.google.com/)에서 새 프로젝트 생성
2. Google Calendar API 활성화
3. OAuth 2.0 클라이언트 ID 생성 (데스크톱 애플리케이션)
4. `credentials.json` 파일 다운로드
5. 파일 내용을 JSON 문자열로 변환하여 `GOOGLE_CALENDAR_CREDENTIALS` 환경 변수에 설정

### 3. OpenAI API 설정
1. [OpenAI Platform](https://platform.openai.com/)에서 API 키 생성
2. `OPENAI_API_KEY` 환경 변수에 설정

## 실행 방법

### 백엔드 서버 실행
```bash
# 가상환경 활성화
.venv\Scripts\activate

# ChromaDB 서버 실행 (터미널 1)
python run_chroma.py

# FastAPI 서버 실행 (터미널 2)
python -m uvicorn app.main:app --reload --port 8000
```

### Flutter 앱 실행
```bash
flutter run -d chrome
```

## API 엔드포인트

### AI 캘린더 API
- `POST /api/v1/calendar/ai-chat` - AI 캘린더 워크플로우 (메인 기능)
- `GET /api/v1/calendar/events/search` - 일정 검색
- `POST /api/v1/calendar/events/create` - 일정 생성
- `PUT /api/v1/calendar/events/{event_id}` - 일정 수정
- `DELETE /api/v1/calendar/events/{event_id}` - 일정 삭제
- `POST /api/v1/calendar/events/{event_id}/copy` - 일정 복사
- `POST /api/v1/calendar/events/{event_id}/move` - 일정 이동
- `GET /api/v1/calendar/events/{event_id}/conflicts` - 충돌 검사

### 기존 API (호환성 유지)
- `POST /api/v1/calendar/process` - 텍스트 처리
- `POST /api/v1/calendar/chat` - 대화형 채팅
- `POST /api/v1/calendar/context` - 컨텍스트 추가
- `POST /api/v1/calendar/ocr_text` - OCR 텍스트 저장

## 사용 예시

### AI 캘린더 채팅 API 사용법
```bash
curl -X POST "http://localhost:8000/api/v1/calendar/ai-chat" \
  -H "Content-Type: application/json" \
  -d '{
    "message": "내일 오후 2시에 팀 미팅 일정 추가해줘",
    "session_id": "user123"
  }'
```

### 응답 예시
```json
{
  "response": "✅ 일정이 성공적으로 추가되었습니다!\n\n📅 제목: 팀 미팅\n🕐 시간: 2024-01-15 14:00\n🔗 링크: https://calendar.google.com/...",
  "intent": "calendar_add",
  "extracted_info": {
    "title": "팀 미팅",
    "start_date": "2024-01-15",
    "start_time": "14:00",
    "end_date": "2024-01-15",
    "end_time": "15:00"
  },
  "calendar_result": {
    "success": true,
    "event_id": "abc123",
    "event_link": "https://calendar.google.com/..."
  }
}
```

## 기술 스택

### 백엔드
- **FastAPI**: 웹 API 프레임워크
- **LangGraph**: AI 워크플로우 관리
- **OpenAI GPT-4o-mini**: 자연어 처리
- **Google Calendar API**: 일정 관리
- **ChromaDB**: 벡터 데이터베이스 (대화 컨텍스트 저장)
- **LangChain**: AI 체인 및 임베딩

### 프론트엔드
- **Flutter**: 크로스 플랫폼 앱 개발
- **Firebase**: 인증 및 데이터베이스
- **Google Sign-In**: 사용자 인증

## 문제점 기록
- 일정을 추가하면 바로 추가가 안 되고 에뮬레이터를 재실행해야 보이는 문제
- 터미널에 알 수 없는 실행문이 무한 출력되는 문제(해결됨: 날씨를 무한으로 로딩하는 문제)
- 달력셀이 크롬에서는 정사각형에 가까운데 기기에서는 너무 길어서 짤리는 문제
- 앱 테두리가 너무 두꺼운 문제(수정됨: 22 -> 15)
- OpenWeatherMap API의 forecast 엔드포인트가 5일 예보를 제공하는데, 10일치 날씨정보를 불러오고 있는 문제(수정: 5일간 정보만 불러오도록 수정)
- 클라이언트 요청과 백엔드 엔드포인트가 일치하지 않음(수정: 백엔드에서 user_id 대신 session_id를 사용하고 있었음)
- 고양이가 셀 아래에서 모습이 가려지는 문제(수정됨)
- 달력 셀의 높이가 고정 높이 대신 화면 비율을 계산하여 가득 채우도록 수정
- 6주가 표시되는 상태를 올바르게 계산하지 못해서 달력 셀 비율이 변하지 않음(수정됨)
- 루트 gitignore 파일에 lib가 명시되어있어 새로 생긴 파일을 추적하지 못하던 문제
- (웹 에뮬레이터)네비게이션바로 채팅화면 -> 홈화면 이동시, 호출된 적 없는 mlkit를 dispose 시도하다 렉이 걸리는 문제 (수정됨)
- 