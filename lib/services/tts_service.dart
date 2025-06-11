import 'dart:async';
import 'package:flutter_tts/flutter_tts.dart';
import '../enums/tts_state.dart';

class TtsService {
  static final TtsService instance = TtsService._internal();
  factory TtsService() => instance;

  final FlutterTts _flutterTts = FlutterTts();
  TtsState _ttsState = TtsState.stopped;

  TtsService._internal() {
    _initializeTts();
  }

  void _initializeTts() async {
    // iOS 호환성 및 안정성 강화를 위한 코드
    await _flutterTts.setSharedInstance(true);
    await _flutterTts.setIosAudioCategory(
      IosTextToSpeechAudioCategory.playback,
      [
        IosTextToSpeechAudioCategoryOptions.allowBluetooth,
        IosTextToSpeechAudioCategoryOptions.allowBluetoothA2DP,
        IosTextToSpeechAudioCategoryOptions.mixWithOthers,
        IosTextToSpeechAudioCategoryOptions.defaultToSpeaker,
      ],
      IosTextToSpeechAudioMode.defaultMode,
    );

    _flutterTts.setLanguage('ko-KR');
    _flutterTts.setSpeechRate(0.5);
    _flutterTts.setPitch(1.0);

    _flutterTts.setStartHandler(() {
      print("▶️ TTS 재생 시작");
      _ttsState = TtsState.playing;
    });

    _flutterTts.setCompletionHandler(() {
      print("⏹️ TTS 재생 완료");
      _ttsState = TtsState.stopped;
    });

    _flutterTts.setErrorHandler((msg) {
      print("❌ TTS 오류 발생: $msg");
      _ttsState = TtsState.stopped;
    });
  }

  bool _isTtsEnabled = false;

  bool get isTtsEnabled => _isTtsEnabled;

  void setTtsEnabled(bool isEnabled) {
    _isTtsEnabled = isEnabled;
    print(' TTS 서비스 상태 변경: ${isEnabled ? '활성화' : '비활성화'}');
    
    if (!isEnabled && _ttsState == TtsState.playing) {
      stop();
    }
  }

  Future<void> speak(String text) async {
    print('🔊 speak() 호출됨. TTS 활성화 상태: $_isTtsEnabled'); // 디버깅 로그
    if (_isTtsEnabled && text.isNotEmpty) {
      if (_ttsState == TtsState.playing) {
        await stop();
      }
      print('   - 재생할 텍스트: "$text"'); // 디버깅 로그
      await _flutterTts.speak(text);
    } else {
      print('   - TTS가 비활성화되었거나 텍스트가 비어있어 재생하지 않음.'); // 디버깅 로그
    }
  }

  Future<void> stop() async {
    await _flutterTts.stop();
    _ttsState = TtsState.stopped;
  }
}
