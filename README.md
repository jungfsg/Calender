# calander

A calender Flutter project.
Fastapi -> https://github.com/jungfsg/Calendar_project?tab=readme-ov-file

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference

## 실행 명령어
```bash
# 백엔드
python run_chroma.py
python -m uvicorn app.main:app --reload --port 8000

# 플러터
flutter run -d chrome
```


## 문제점
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