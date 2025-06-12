import 'package:flutter/material.dart';
import '../utils/font_utils.dart';

class CalendarSideMenu extends StatelessWidget {
  final VoidCallback onWeatherForecastTap;
  final VoidCallback onGoogleCalendarDownload; // 다운로드 콜백
  final VoidCallback onGoogleCalendarUpload; // 업로드 콜백
  final VoidCallback onLogoutTap; // 로그아웃 콜백 추가
  final bool isGoogleCalendarConnected; // Google Calendar 연결 상태

  // --- TTS 관련 추가 ---
  final bool isTtsEnabled; // TTS 활성화 상태
  final ValueChanged<bool> onTtsToggle; // TTS 상태 변경 콜백

  const CalendarSideMenu({
    super.key,
    required this.onWeatherForecastTap,
    required this.onGoogleCalendarDownload, // 다운로드 콜백 필수
    required this.onGoogleCalendarUpload, // 업로드 콜백 필수
    required this.onLogoutTap, // 필수 매개변수로 추가
    this.isGoogleCalendarConnected = false, // 기본값은 연결되지 않음
    // --- TTS 관련 추가 ---
    required this.isTtsEnabled,
    required this.onTtsToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Theme(
      // Drawer의 모서리를 직각으로 변경
      data: Theme.of(context).copyWith(
        drawerTheme: const DrawerThemeData(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.zero, // 모서리 각도 0으로 설정
          ),
        ),
      ),
      child: Drawer(
        width: MediaQuery.of(context).size.width * 0.75, // 화면 너비의 75%로 설정
        backgroundColor: Colors.white,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(16, 40, 16, 16),
              color: Colors.black,
              width: double.infinity,
              child: Text(
                '캘린더 메뉴',
                style: getTextStyle(fontSize: 14, color: Colors.white),
              ),
            ),
            const SizedBox(height: 20),
            // 5일간 날씨 예보 버튼
            ListTile(
              leading: const Icon(Icons.wb_sunny, color: Colors.orange),
              title: Text(
                '5일간 날씨 예보',
                style: getTextStyle(fontSize: 12, color: Colors.black),
              ),
              onTap: () {
                // 드로어 닫기
                Navigator.pop(context);
                // 날씨 예보 다이얼로그 표시
                onWeatherForecastTap();
              },
            ),
            // 수동 동기화 버튼 부분 주석처리 했습니다.
            // Google Calendar 동기화 - 다운로드
            // ListTile(
            //   leading: Icon(
            //     Icons.download,
            //     color: isGoogleCalendarConnected ? Colors.green : Colors.blue,
            //   ),
            //   title: Text(
            //     isGoogleCalendarConnected
            //         ? 'Google → 앱으로 다운로드'
            //         : 'Google Calendar 연결',
            //     style: getTextStyle(fontSize: 12, color: Colors.black),
            //   ),
            //   subtitle:
            //       isGoogleCalendarConnected
            //           ? Text(
            //             'Google Calendar의 일정을 앱으로 가져오기',
            //             style: getTextStyle(fontSize: 10, color: Colors.green),
            //           )
            //           : Text(
            //             '터치하여 연결하기',
            //             style: getTextStyle(fontSize: 10, color: Colors.grey),
            //           ),
            //   onTap: () {
            //     // 드로어 닫기
            //     Navigator.pop(context);
            //     // Google Calendar에서 앱으로 다운로드
            //     onGoogleCalendarDownload();
            //   },
            // ),

            // // Google Calendar 동기화 - 업로드 (연결된 경우에만 표시)
            // if (isGoogleCalendarConnected)
            //   ListTile(
            //     leading: const Icon(Icons.upload, color: Colors.orange),
            //     title: Text(
            //       '앱 → Google로 업로드',
            //       style: getTextStyle(fontSize: 12, color: Colors.black),
            //     ),
            //     subtitle: Text(
            //       '앱의 일정을 Google Calendar로 보내기',
            //       style: getTextStyle(fontSize: 10, color: Colors.orange),
            //     ),
            //     onTap: () {
            //       // 드로어 닫기
            //       Navigator.pop(context);
            //       // 앱에서 Google Calendar로 업로드
            //       onGoogleCalendarUpload();
            //     },
            //   ),

            // --- TTS 설정 스위치 추가 ---
            const Divider(), // 구분선
            SwitchListTile(
              secondary: Icon(
                Icons.volume_up,
                color: isTtsEnabled ? Colors.blueAccent : Colors.grey,
              ),
              title: Text(
                'AI 음성 (TTS) 사용',
                style: getTextStyle(fontSize: 12, color: Colors.black),
              ),
              subtitle: Text(
                isTtsEnabled ? 'AI 답변을 음성으로 듣습니다.' : '음성 안내가 꺼져 있습니다.',
                style: getTextStyle(
                  fontSize: 10,
                  color: isTtsEnabled ? Colors.blueAccent : Colors.grey,
                ),
              ),
              value: isTtsEnabled,
              onChanged: (bool value) {
                onTtsToggle(value);
                // 스위치 클릭 시 메뉴가 닫히지 않도록 Navigator.pop(context)를 호출하지 않음
              },
            ),
            const Spacer(),
            const Divider(), // 구분선
            // 색상 카테고리 팔레트 부분
            ListTile(
              leading: const Icon(Icons.category, color: Colors.blue),
              title: Text(
                '카테고리',
                style: getTextStyle(fontSize: 12, color: Colors.black),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4, // 한 줄에 4개씩
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                  childAspectRatio: 1,
                ),
                itemCount: 11, // 총 11개 색상
                itemBuilder: (context, index) {
                  final colors = [
                    const Color(0xFF9AA0F5), // 라벤더
                    const Color(0xFF33B679), // 세이지
                    const Color(0xFF8E24AA), // 포도
                    const Color(0xFFE67C73), // 플라밍고
                    const Color(0xFFF6BF26), // 바나나
                    const Color(0xFFFF8A65), // 귤
                    const Color(0xFF039BE5), // 공작새
                    const Color(0xFF616161), // 그래파이트
                    const Color(0xFF3F51B5), // 블루베리
                    const Color(0xFF0B8043), // 바질
                    const Color(0xFFD50000), // 토마토
                  ];

                  final categories = [
                    '업무',
                    '집안일',
                    '기념일',
                    '학교',
                    '운동',
                    '공부',
                    '여행',
                    '기타',
                    '친구',
                    '가족',
                    '병원',
                  ];

                  return Container(
                    decoration: BoxDecoration(
                      color: colors[index],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Colors.grey.shade300,
                        width: 0.5,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        categories[index],
                        style: getTextStyle(fontSize: 10, color: Colors.white),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                },
              ),
            ),

            // 하단에 로그아웃 버튼을 배치하기 위한 Spacer
            // 구분선
            const Divider(
              color: Color.fromARGB(255, 230, 103, 94),
              thickness: 1,
              indent: 16,
              endIndent: 16,
            ),
            // 로그아웃 버튼
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: Text(
                '로그아웃',
                style: getTextStyle(fontSize: 12, color: Colors.red),
              ),
              subtitle: Text(
                'Google 계정에서 로그아웃',
                style: getTextStyle(fontSize: 10, color: Colors.grey),
              ),
              onTap: () {
                // 드로어 닫기
                Navigator.pop(context);
                // 로그아웃 확인 다이얼로그 표시
                _showLogoutConfirmDialog(context);
              },
            ),
            const SizedBox(height: 20), // 하단 여백
          ],
        ),
      ),
    );
  }

  // 로그아웃 확인 다이얼로그
  void _showLogoutConfirmDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            '로그아웃',
            style: getTextStyle(fontSize: 16, color: Colors.black),
          ),
          content: Text(
            'Google 계정에서 로그아웃하시겠습니까?\n로그인 화면으로 돌아갑니다.',
            style: getTextStyle(fontSize: 12, color: Colors.black),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // 다이얼로그 닫기
              },
              child: Text(
                '취소',
                style: getTextStyle(fontSize: 12, color: Colors.grey),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // 다이얼로그 닫기
                onLogoutTap(); // 로그아웃 실행
              },
              child: Text(
                '로그아웃',
                style: getTextStyle(fontSize: 12, color: Colors.red),
              ),
            ),
          ],
        );
      },
    );
  }
}
