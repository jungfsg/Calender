import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:io';

class TtsService {
  static TtsService? _instance;
  static TtsService get instance {
    _instance ??= TtsService._internal();
    return _instance!;
  }

  TtsService._internal();

  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isEnabled = true;

  final RegExp _nonTextRegex = RegExp(
    r'(\u00a9|\u00ae|[\u2000-\u3300]|\ud83c[\ud000-\udfff]|\ud83d[\ud000-\udfff]|\ud83e[\ud000-\udfff])',
  );

  String _removeNonTextCharacters(String text) {
    return text.replaceAll(_nonTextRegex, ' ').trim();
  }

  void setEnabled(bool enabled) {
    _isEnabled = enabled;
    if (!enabled) {
      stop();
    }
  }

  bool get isEnabled => _isEnabled;

  Future<void> speak(String text) async {
    if (!_isEnabled) {
      print("TTS: 비활성화 상태로 음성 출력을 건너뜁니다.");
      return;
    }

    if (text.trim().isEmpty) {
      print("TTS: 입력 텍스트가 비어있어 음성 출력을 건너뜁니다.");
      return;
    }

    final cleanText = _removeNonTextCharacters(text);

    if (cleanText.trim().isEmpty) {
      print("TTS: 이모티콘 제거 후 텍스트가 비어있어 음성 출력을 건너뜁니다.");
      return;
    }

    await stop();

    print('🔊 TTS.speak() 호출됨 - 재생할 텍스트: "$cleanText"');

    try {
      // .env 파일에서 API 키 읽어오기
      final String? openAIKey = dotenv.env['OPENAI_API_KEY'];

      // API 키가 비어있는지 확인
      if (openAIKey == null || openAIKey.isEmpty) {
        print('❌ OpenAI API 키가 설정되지 않았습니다. .env 파일을 확인해주세요.');
        return;
      }

      // 디버그 로그 추가로 API 키 상태 확인
      print('🔑 API 키 길이: ${openAIKey.length}');
      print('🔑 API 키 시작: ${openAIKey.substring(0, 10)}...');

      final response = await http.post(
        Uri.parse('https://api.openai.com/v1/audio/speech'),
        headers: {
          'Authorization': 'Bearer $openAIKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          "model": "tts-1",
          "input": cleanText,
          "voice": "nova",
        }),
      );

      if (response.statusCode == 200) {
        print('🔊 TTS API 응답 성공, 오디오 재생 시작');
        await _audioPlayer.play(BytesSource(response.bodyBytes));
        print('🔊 TTS 오디오 재생 완료');
      } else {
        print('❌ OpenAI TTS API 오류: ${response.statusCode}');
        print('응답 내용: ${response.body}');
      }
    } catch (e) {
      print('❌ TTS 처리 중 오류 발생: $e');
      print('❌ 오류 타입: ${e.runtimeType}');
      if (e is FormatException) {
        print('❌ FormatException 세부사항: ${e.message}');
      }
    }
  }

  Future<void> stop() async {
    try {
      await _audioPlayer.stop();
    } catch (e) {
      print('TTS 중지 중 오류: $e');
    }
  }

  void dispose() {
    _audioPlayer.dispose();
  }
}
