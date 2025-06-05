# 주요 디렉토리 구조

lib/
├── firebase_options.dart # Firebase 연결을 위한 구성 옵션
├── main.dart # 앱의 진입점
├── controllers/ # 상태 관리 컨트롤러
├── managers/ # 비즈니스 로직 관리자
├── models/ # 데이터 모델
├── screens/ # 화면 UI 컴포넌트
├── services/ # 외부 서비스 연동 클래스
├── utils/ # 유틸리티 함수
└── widgets/ # 재사용 가능한 UI 위젯

## 주요 컴포넌트 설명

### Controllers

- calendar_controller.dart: 캘린더의 상태(선택된 날짜, 이벤트 등)를 관리하는 컨트롤러

### Managers

- event_manager.dart: 이벤트 추가, 삭제, 동기화와 같은 이벤트 관련 비즈니스 로직 처리
- popup_manager.dart: 다양한 팝업 대화상자(일정, 날씨 등)의 표시 상태를 관리

### Models

- event.dart: 일정 데이터 모델 (제목, 시간, 날짜, 설명, 색상 등)
- time_slot.dart: 시간대 데이터 모델
- weather_info.dart: 날씨 정보 데이터 모델

### Screens

- calendar_screen.dart: 메인 캘린더 화면
- chat_screen.dart: AI 챗봇 인터페이스 화면
- login_screen.dart: 사용자 인증 화면

### Services

- auth_service.dart: 사용자 인증 관련 서비스
- chat_service.dart: AI 채팅 통신 서비스
- event_storage_service.dart: 로컬 이벤트 저장소 서비스
- google_calendar_service.dart: Google 캘린더 API 연동 서비스
- stt_service.dart: 음성-텍스트 변환 서비스
- stt_command_service.dart: 음성 명령 처리 서비스
- weather_service.dart: 날씨 정보 가져오기 서비스

### Utils

- date_utils.dart: 날짜 관련 유틸리티 함수
- font_utils.dart: 폰트 및 텍스트 스타일 유틸리티

### Widgets

#### calendar_widget.dart

- 기능: 메인 캘린더 UI 위젯
- 핵심 요소:
  - TableCalendar 기반 캘린더 뷰 구현
  - 날짜 선택, 일정 표시, 월 변경 기능
  - 사이드 메뉴, 팝업 관리
  - Google 캘린더 동기화 기능
  - 음성 명령 처리 기능
- 특징: 캘린더 컨트롤러, 이벤트 매니저, 팝업 매니저를 통해 상태 관리

#### color_picker_dialog.dart

- 기능: 일정 색상 선택 다이얼로그
- 핵심 요소:
  - Google 캘린더와 호환되는 색상 팔레트 제공
  - 색상 ID 기반 선택 시스템
  - 선택된 색상에 대한 시각적 표시
- 특징: 정적 메서드로 색상 ID와 실제 색상 간 변환 기능 제공

#### common_navigation_bar.dart

- 기능: 앱 하단 네비게이션 바
- 핵심 요소:
  - 캘린더, 음성 인식, 채팅 화면 전환
  - 물방울 애니메이션 효과
  - 선택된 탭에 따른 색상 변경
  - 특징: WaterDropNavBar 라이브러리를 활용한 시각적 효과

#### event_popup.dart

- 기능: 선택된 날짜의 일정 목록 팝업
- 핵심 요소:
  - 날짜별 이벤트 표시
  - 이벤트 색상 시스템 (고유 ID, Google colorId 기반)
  - 일정 삭제 기능
  - 새 일정 추가 버튼
- 특징: 이벤트 색상 관리를 위한 복합 로직 구현 (ID 기반, 제목 기반 등)

#### side_menu.dart

- 기능: 좌측에서 슬라이드하여 열리는 사이드 메뉴
- 핵심 요소:
  - 날씨 예보, Google 캘린더 동기화 메뉴
  - 업로드/다운로드 기능
  - 로그아웃 기능
- 특징: Google 캘린더 연결 상태에 따라 동적으로 메뉴 항목 표시

#### stt_ui.dart

- 기능: 음성 인식 인터페이스
  - 핵심 요소:
  - 음성 입력 및 텍스트 변환
  - 실시간 리스닝 상태 표시
  - 음성 명령 전송 기능
- 특징: 애니메이션 효과를 통한 리스닝 상태 피드백 제공

#### time_table_popup.dart

- 기능: 시간표 형식의 일정 표시 팝업
- 핵심 요소:
  - 시간대별 일정 목록 표시
  - 새 시간 슬롯 추가 기능
- 특징: 색상으로 구분된 시간 슬롯 시각화

#### weather_calendar_cell.dart

- 기능: 날씨 정보가 포함된 캘린더 셀
- 핵심 요소:
  - 날짜 표시
  - 날씨 아이콘 표시
  - 이벤트 리스트 표시
  - 공휴일 표시
- 특징: 셀 상태(오늘, 선택됨, 주말 등)에 따른 스타일링

#### weather_icon.dart

- 기능: 날씨 상태를 나타내는 아이콘 위젯
- 핵심 요소:
  - 날씨 조건에 따른 아이콘 및 색상
  - 네이버 날씨 연동
- 특징: 터치 시 네이버 날씨 페이지 열기 기능

#### weather_summary_popup.dart

- 기능: 5일간 날씨 예보 팝업
- 핵심 요소:
  - 일별 날씨 정보 목록
  - 날씨 아이콘, 온도, 상태 표시
  - 네이버 날씨 링크
- 특징: 오늘/내일 날씨 강조 표시 및 날짜 포맷팅
