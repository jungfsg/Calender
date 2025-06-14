// lib/services/tts_service.dart 
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:audioplayers/audioplayers.dart';
// import '../config.dart'; // API 키를 보관하는 설정 파일 - 임시 비활성화

class TtsService {
  final AudioPlayer _audioPlayer = AudioPlayer();

  // --- 삭제: 싱글톤 패턴 및 TTS On/Off 관련 코드 전체 제거 ---
  // 이 서비스는 이제 외부에서 인스턴스화하여 사용하며, '활성화' 상태를 갖지 않습니다.
  
  // 이모티콘, 특수기호 등 텍스트가 아닌 문자를 제거하기 위한 정규 표현식
  final RegExp _nonTextRegex = RegExp(
    r'(\u00a9|\u00ae|[\u2000-\u3300]|\ud83c[\ud000-\udfff]|\ud83d[\ud000-\udfff]|\ud83e[\ud000-\udfff])');

  // 텍스트가 아닌 문자를 공백으로 대체하는 함수
  String _removeNonTextCharacters(String text) {
    return text.replaceAll(_nonTextRegex, ' ').trim();
  }

  // OpenAI TTS API를 호출하여 텍스트를 음성으로 변환하고 재생하는 핵심 함수
  Future<void> speak(String text) async {

    // 이제 speak 함수는 호출되면 항상 실행을 시도합니다.
    if (text.trim().isEmpty) {
      print("TTS: 입력 텍스트가 비어있어 음성 출력을 건너뜁니다.");
      return;
    }
    
    // 이모티콘 및 특수문자 제거
    final cleanText = _removeNonTextCharacters(text);

    if (cleanText.trim().isEmpty) {
      print("TTS: 이모티콘 제거 후 텍스트가 비어있어 음성 출력을 건너뜁니다.");
      return;
    }
    
    // 이전에 재생 중인 소리가 있다면 중지
    await stop();

    print('🔊 TTS.speak() 호출됨 - 재생할 텍스트: "$cleanText"');

    try {
      // 임시로 API 키를 하드코딩 (실제 사용 시에는 환경변수나 보안 저장소 사용 권장)
      const String openAIKey = 'YOUR_OPENAI_API_KEY_HERE'; // 실제 키로 교체 필요
      
      final response = await http.post(
        Uri.parse('https://api.openai.com/v1/audio/speech'),
        headers: {
          'Authorization': 'Bearer $openAIKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          "model": "tts-1",
          "input": cleanText,
          "voice": "nova" // 선호하는 목소리 (alloy, echo, fable, onyx, nova, shimmer)
        }),
      );

      if (response.statusCode == 200) {
        await _audioPlayer.play(BytesSource(response.bodyBytes));
      } else {
        print('Error from OpenAI TTS API: ${response.statusCode}');
        print('Response body: ${response.body}');
      }
    } catch (e) {
      print('An error occurred during TTS processing: $e');
    }
  }

  // 음성 재생 중지 함수
  Future<void> stop() async {
    await _audioPlayer.stop();
  }
}
