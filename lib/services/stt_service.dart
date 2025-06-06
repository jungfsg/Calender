import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:permission_handler/permission_handler.dart';

/// 순수 음성 인식만 담당하는 서비스 (STT 기능만)
class SpeechService {
  static final SpeechService _instance = SpeechService._internal();
  factory SpeechService() => _instance;
  SpeechService._internal();

  final stt.SpeechToText _speech = stt.SpeechToText();

  bool _isListening = false;
  String _recognizedText = '';

  bool get isListening => _isListening;
  String get recognizedText => _recognizedText;
  // 음성 인식 상태 콜백
  Function(String)? onTextChanged;
  Function(bool)? onListeningStatusChanged;
  Function(String)? onError;

  /// 음성 인식 초기화
  Future<bool> initialize() async {
    try {
      // 마이크 권한 요청
      final permission = await Permission.microphone.request();
      if (!permission.isGranted) {
        onError?.call('마이크 권한이 필요합니다.');
        return false;
      }

      return await _speech.initialize(
        onStatus: (status) {
          if (status == 'notListening') {
            _isListening = false;
            onListeningStatusChanged?.call(_isListening);
          } else if (status == 'listening') {
            _isListening = true;
            onListeningStatusChanged?.call(_isListening);
          }
        },
        onError: (error) {
          _isListening = false;
          onListeningStatusChanged?.call(_isListening);
          onError?.call('음성 인식 오류: ${error.errorMsg}');
        },
      );
    } catch (e) {
      onError?.call('음성 인식 초기화 실패: $e');
      return false;
    }
  }

  /// 음성 인식 시작
  Future<void> startListening({required Function(String) onResult}) async {
    if (!_speech.isAvailable) {
      await initialize();
    }

    _isListening = true;
    _recognizedText = '';
    onListeningStatusChanged?.call(_isListening);

    await _speech.listen(
      localeId: 'ko_KR', // 한국어 설정
      listenFor: const Duration(seconds: 30), // 최대 인식 시간
      pauseFor: const Duration(seconds: 3), // 일시정지 감지 시간
      onResult: (result) {
        _recognizedText = result.recognizedWords;
        onResult(_recognizedText);
        onTextChanged?.call(_recognizedText);
      },
      cancelOnError: true,
      partialResults: true,
    );
  }

  /// 음성 인식 정지
  Future<void> stopListening() async {
    await _speech.stop();
    _isListening = false;
    onListeningStatusChanged?.call(_isListening);
  }

  /// 음성 인식 취소
  Future<void> cancelListening() async {
    await _speech.cancel();
    _isListening = false;
    _recognizedText = '';
    onListeningStatusChanged?.call(_isListening);
  }
}
