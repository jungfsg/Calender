import 'package:manual_speech_to_text/manual_speech_to_text.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/material.dart';

/// 순수 음성 인식만 담당하는 서비스 (Manual STT 기능)
class SpeechService {
  static final SpeechService _instance = SpeechService._internal();
  factory SpeechService() => _instance;
  SpeechService._internal();
  ManualSttController? _sttController;

  bool _isListening = false;
  String _recognizedText = '';

  // 설정 가능한 옵션들
  Duration _muteTimeout = const Duration(seconds: 5); // 무음 시간 제한
  bool _clearTextOnStart = true;
  bool _enableHapticFeedback = false;

  bool get isListening => _isListening;
  String get recognizedText => _recognizedText;
  Duration get muteTimeout => _muteTimeout;
  bool get clearTextOnStart => _clearTextOnStart; // 설정값 확인용
  bool get enableHapticFeedback => _enableHapticFeedback; // 설정값 확인용

  // 음성 인식 상태 콜백
  Function(String)? onTextChanged;
  Function(bool)? onListeningStatusChanged;
  Function(String)? onError;
  Function(double)? onSoundLevelChanged; // 소리 레벨 콜백 추가

  /// 무음 시간 제한 설정 (몇 초 동안 말하지 않으면 자동으로 일시정지)
  void setMuteTimeout(Duration timeout) {
    _muteTimeout = timeout;
    if (_sttController != null) {
      _sttController!.pauseIfMuteFor = _muteTimeout;
    }
  }

  /// 시작 시 텍스트 초기화 여부 설정
  void setClearTextOnStart(bool clear) {
    _clearTextOnStart = clear;
    if (_sttController != null) {
      _sttController!.clearTextOnStart = _clearTextOnStart;
    }
  }

  /// 햅틱 피드백 활성화 설정
  void setHapticFeedback(bool enable) {
    _enableHapticFeedback = enable;
    if (_sttController != null) {
      _sttController!.enableHapticFeedback = _enableHapticFeedback;
    }
  }

  /// 음성 인식 초기화
  Future<bool> initialize({BuildContext? context}) async {
    try {
      // 마이크 권한 요청
      final permission = await Permission.microphone.request();
      if (!permission.isGranted) {
        onError?.call('마이크 권한이 필요합니다.');
        return false;
      }
      if (context != null) {
        _sttController = ManualSttController(context); // 콜백 설정
        _sttController!.listen(
          onListeningStateChanged: (state) {
            _isListening = state == ManualSttState.listening;
            onListeningStatusChanged?.call(_isListening);
          },
          onListeningTextChanged: (text) {
            _recognizedText = text;
            onTextChanged?.call(_recognizedText);
          },
          onSoundLevelChanged: (level) {
            onSoundLevelChanged?.call(level);
          },
        );

        // 한국어 설정
        _sttController!.localId = 'ko_KR';

        // 무음 시간 제한 설정
        _sttController!.pauseIfMuteFor = _muteTimeout;

        // 시작 시 텍스트 초기화 설정
        _sttController!.clearTextOnStart = _clearTextOnStart;

        // 햅틱 피드백 설정
        _sttController!.enableHapticFeedback = _enableHapticFeedback;

        // 권한 거부 다이얼로그 커스터마이즈
        _sttController!.handlePermanentlyDeniedPermission(() {
          // 아무것도 하지 않음 - 기본 다이얼로그 비활성화
        });

        return true;
      }

      return false;
    } catch (e) {
      onError?.call('음성 인식 초기화 실패: $e');
      return false;
    }
  }

  /// 음성 인식 시작
  Future<void> startListening({
    required Function(String) onResult,
    BuildContext? context,
  }) async {
    try {
      if (_sttController == null) {
        final initialized = await initialize(context: context);
        if (!initialized) return;
      }

      _isListening = true;
      _recognizedText = '';
      onListeningStatusChanged?.call(_isListening);

      // 결과 콜백 업데이트
      onTextChanged = (text) {
        _recognizedText = text;
        onResult(_recognizedText);
      };

      _sttController!.startStt();
    } catch (e) {
      _isListening = false;
      onListeningStatusChanged?.call(_isListening);
      onError?.call('음성 인식 시작 실패: $e');
    }
  }

  /// 음성 인식 정지
  Future<void> stopListening() async {
    if (_sttController != null) {
      _sttController!.stopStt();
    }
    _isListening = false;
    onListeningStatusChanged?.call(_isListening);
  }

  /// 음성 인식 취소
  Future<void> cancelListening() async {
    if (_sttController != null) {
      _sttController!.stopStt();
    }
    _isListening = false;
    _recognizedText = '';
    onListeningStatusChanged?.call(_isListening);
  }

  /// 음성 인식 일시정지 (Manual STT의 추가 기능)
  Future<void> pauseListening() async {
    if (_sttController != null) {
      _sttController!.pauseStt();
    }
    _isListening = false;
    onListeningStatusChanged?.call(_isListening);
  }

  /// 음성 인식 재개 (Manual STT의 추가 기능)
  Future<void> resumeListening() async {
    if (_sttController != null) {
      _sttController!.resumeStt();
    }
    _isListening = true;
    onListeningStatusChanged?.call(_isListening);
  }

  /// 리소스 정리
  void dispose() {
    if (_sttController != null) {
      _sttController!.dispose();
    }
  }

  /// 사용 가능 여부 확인
  bool get isAvailable => _sttController != null;
}
