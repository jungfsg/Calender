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
- ✅ **다중 일정 추가** (한 번에 여러 일정 생성) - **NEW!**
- ✅ 일정 수정 (기존 일정 업데이트)
- ✅ 일정 삭제 (일정 제거)
- ✅ 일정 검색 (키워드 기반 검색)
- ✅ 일정 복사 (일정 복제)
- ✅ 일정 이동 (캘린더 간 이동)
- ✅ 충돌 검사 (시간 겹침 확인)

### 🆕 다중 일정 처리 기능
이제 하나의 메시지로 여러 일정을 한 번에 추가할 수 있습니다!

#### 사용 예시:
- **"내일 저녁 7시에 카페 일정 추가하고 다음주 월요일 오전 11시에 점심 일정 추가해줘"**
- **"오늘 오후 2시에 회의 잡고 내일 오전 10시에 병원 예약해줘"**
- **"다음주 화요일 오후 3시에 프레젠테이션 준비하고 수요일 오전 9시에 팀 미팅 추가해줘"**

#### 기능 특징:
- 🤖 **자동 감지**: AI가 여러 일정이 포함된 메시지를 자동으로 인식
- 🎯 **정확한 분리**: 연결어("그리고", "또", "추가로" 등)를 기준으로 각 일정을 정확히 분리
- 📅 **개별 처리**: 각 일정을 독립적으로 처리하여 오류 시에도 다른 일정에 영향 없음
- 🔄 **일괄 동기화**: 모든 일정이 로컬 및 Google Calendar에 동시 저장
- ✨ **스마트 응답**: 추가된 일정 수와 각 일정의 세부 정보를 포함한 종합 응답 제공

### 🗑️ 다중 일정 삭제 (NEW!)

여러 일정을 한 번에 삭제하거나 특정 날짜의 모든 일정을 삭제할 수 있습니다!

#### 사용 예시:
- **다중 개별 삭제**: "내일 회의 삭제하고 다음주 월요일 점심약속도 삭제해줘"
- **특정 날짜 전체 삭제**: "내일 일정을 모두 다 삭제해줘"
- **특정 날짜 전체 삭제**: "오늘 모든 일정 지워줘"
- **특정 날짜 전체 삭제**: "다음주 월요일 전체 일정 삭제해줘"

#### 기능 특징:
- 🔍 **삭제 유형 자동 감지**: 단일/다중/전체 삭제를 자동으로 구분
- 🗑️ **다중 개별 삭제**: 여러 날짜의 여러 일정을 각각 정확히 삭제
- 📅 **전체 삭제**: 특정 날짜의 모든 일정을 한 번에 안전하게 삭제
- 🛡️ **안전한 처리**: 삭제 실패 시에도 다른 일정 삭제는 계속 진행
- 🔄 **완벽한 동기화**: 로컬 저장소와 Google Calendar에서 동시 삭제

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

#### 단일 일정 추가
```bash
curl -X POST "http://localhost:8000/api/v1/calendar/ai-chat" \
  -H "Content-Type: application/json" \
  -d '{
    "message": "내일 오후 2시에 팀 미팅 일정 추가해줘",
    "session_id": "user123"
  }'
```

#### 다중 일정 추가 (NEW!)
```bash
curl -X POST "http://localhost:8000/api/v1/calendar/ai-chat" \
  -H "Content-Type: application/json" \
  -d '{
    "message": "내일 저녁 7시에 카페 일정 추가하고 다음주 월요일 오전 11시에 점심 일정 추가해줘",
    "session_id": "user123"
  }'
```

### 응답 예시

#### 단일 일정 응답
```json
{
  "response": "✅ 일정이 성공적으로 추가되었습니다!\n\n📅 제목: 팀 미팅\n🕐 시간: 2024-01-15 14:00\n🔗 링크: https://calendar.google.com/...",
  "intent": "calendar_add",
  "extracted_info": {
    "title": "팀 미팅",
    "start_date": "2024-01-15",
    "start_time": "14:00",
    "end_date": "2024-01-15",
    "end_time": "15:00",
    "is_multiple": false
  },
  "calendar_result": {
    "success": true,
    "event_id": "abc123",
    "event_link": "https://calendar.google.com/..."
  }
}
```

#### 다중 일정 응답 (NEW!)
```json
{
  "response": "네! 총 2개의 일정을 성공적으로 추가했습니다! 📅✨\n\n📋 **일정 1: 카페 일정**\n📅 날짜: 2024-01-16\n⏰ 시간: 19:00\n\n📋 **일정 2: 점심 일정**\n📅 날짜: 2024-01-22\n⏰ 시간: 11:00\n\n모든 일정이 캘린더에 잘 저장되었어요! 😊",
  "intent": "calendar_add",
  "extracted_info": {
    "is_multiple": true,
    "events": [
      {
        "title": "카페 일정",
        "start_date": "2024-01-16",
        "start_time": "19:00",
        "end_date": "2024-01-16",
        "end_time": "20:00"
      },
      {
        "title": "점심 일정",
        "start_date": "2024-01-22",
        "start_time": "11:00",
        "end_date": "2024-01-22",
        "end_time": "12:00"
      }
    ]
  },
  "calendar_result": {
    "success": true,
    "is_multiple": true,
    "events_count": 2,
    "created_events": [
      {
        "success": true,
        "event_id": "abc123",
        "message": "일정 1이 성공적으로 생성되었습니다."
      },
      {
        "success": true,
        "event_id": "def456",
        "message": "일정 2가 성공적으로 생성되었습니다."
      }
    ]
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