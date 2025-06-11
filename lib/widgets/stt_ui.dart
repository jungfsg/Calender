import 'package:flutter/material.dart';
import '../services/stt_service.dart';
import '../utils/font_utils.dart';

/// 음성 입력 위젯 - STT UI만 담당하는 재사용 가능한 위젯
class VoiceInputWidget extends StatefulWidget {
  final Function(String) onVoiceCommand;
  final VoidCallback? onClose;
  final double pulseSensitivity;
  final double scaleMultiplier;
  final double opacityMultiplier;

  const VoiceInputWidget({
    super.key,
    required this.onVoiceCommand,
    this.onClose,
    this.pulseSensitivity = 0.4, // 0.1 (낮음) ~ 1.0 (높음) - 소리 레벨 반응 정도 증가
    this.scaleMultiplier = 0.5, // 크기 변화 강도 - 펄스 크기 변화 증가
    this.opacityMultiplier = 0.8, // 투명도 변화 강도 증가
  });

  @override
  State<VoiceInputWidget> createState() => _VoiceInputWidgetState();
}

class _VoiceInputWidgetState extends State<VoiceInputWidget> {
  String _recognizedText = '';
  double _soundLevel = 0.0; // 소리 레벨 추가
  final SpeechService _speechService = SpeechService();

  // 런타임에 조절 가능한 민감도 설정
  late double _currentSensitivity;
  late double _currentScaleMultiplier;
  late double _currentOpacityMultiplier;
  @override
  void initState() {
    super.initState();
    // 민감도 초기값 설정
    _currentSensitivity = widget.pulseSensitivity;
    _currentScaleMultiplier = widget.scaleMultiplier;
    _currentOpacityMultiplier = widget.opacityMultiplier;
    _initSpeechService();
  }

  @override
  void dispose() {
    // 모든 콜백을 null로 설정하여 dispose 후 호출 방지
    _speechService.onTextChanged = null;
    _speechService.onListeningStatusChanged = null;
    _speechService.onError = null;
    _speechService.onSoundLevelChanged = null; // 소리 레벨 콜백도 null로 설정

    _speechService.cancelListening();
    super.dispose();
  }

  Future<void> _initSpeechService() async {
    bool available = await _speechService.initialize(context: context);
    if (!available) {
      _showError('음성 인식 초기화에 실패했습니다.');
      return;
    }

    // 음성 인식 결과 콜백 설정
    _speechService.onTextChanged = (text) {
      if (mounted) {
        setState(() {
          _recognizedText = text;
        });
      }
    };

    // 음성 인식 상태 변경 콜백 설정
    _speechService.onListeningStatusChanged = (isListening) {
      if (mounted) {
        setState(() {});
      }
    }; // 오류 콜백 설정
    _speechService.onError = (error) {
      _showError(error);
    }; // 소리 레벨 콜백 설정
    _speechService.onSoundLevelChanged = (level) {
      if (mounted) {
        setState(() {
          _soundLevel = level.clamp(0.0, 1.0); // 안전한 범위로 제한
        });
      }
    };
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  void _handleSendCommand() {
    if (_recognizedText.isNotEmpty) {
      widget.onVoiceCommand(_recognizedText);
      _close();
    }
  }

  void _close() {
    _speechService.cancelListening();
    widget.onClose?.call();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // 메인 UI
        Container(
          height: MediaQuery.of(context).size.height * 0.5,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 10,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: Column(
            children: [
              _buildHandle(),
              _buildHeader(),
              Divider(height: 1, color: Colors.grey.shade200),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        children: [
                          _buildTextDisplay(),
                          const SizedBox(height: 12),
                          _buildStatusIndicator(),
                        ],
                      ),
                      _buildActionButtons(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ), // 원형 애니메이션 오버레이 (UI에 완전히 분리, 고정 위치)
        if (_speechService.isListening)
          Positioned(
            top: 235, // 텍스트 박스 바로 아래 위치로 조정
            left: 0,
            right: 0,
            child: IgnorePointer(
              child: Container(
                height: 80, // 고정 높이로 제한
                alignment: Alignment.center,
                child: _buildVoiceAnimation(),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildHandle() {
    return Container(
      width: 40,
      height: 4,
      margin: const EdgeInsets.only(top: 12, bottom: 8),
      decoration: BoxDecoration(
        color: Colors.grey.shade300,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        children: [
          Container(
            width: 40, // 고정 너비
            height: 40, // 고정 높이
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color:
                  _speechService.isListening
                      ? Colors.red.withOpacity(0.2)
                      : Colors.transparent,
            ),
            child: Center(
              child: Icon(
                _speechService.isListening
                    ? Icons.favorite
                    : Icons.favorite_border,
                color: _speechService.isListening ? Colors.red : Colors.grey,
                size: 24, // 고정 크기
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _speechService.isListening ? '음성을 듣고 있습니다...' : '음성 인식 완료',
              style: getTextStyle(fontSize: 16, color: Colors.black),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextDisplay() {
    return Container(
      width: double.infinity,
      height: 120, // 고정 높이로 설정하여 안정성 확보
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: SingleChildScrollView(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: Text(
            _recognizedText.isEmpty ? '음성을 입력하세요...' : _recognizedText,
            key: ValueKey(_recognizedText),
            style: getTextStyle(
              fontSize: 14,
              color:
                  _recognizedText.isEmpty
                      ? Colors.grey.shade500
                      : Colors.black87,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusIndicator() {
    // 음성 인식 중 텍스트 제거 - 펄스 애니메이션으로 대체
    return const SizedBox.shrink();
  }

  Widget _buildVoiceAnimation() {
    // 안전한 값 계산 - 민감도 설정 적용
    final safeLevel = (_soundLevel * _currentSensitivity).clamp(0.0, 1.0);

    return SizedBox(
      width: 60, // 고정 크기로 레이아웃 안정화
      height: 60,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // 외부 펄스 링 1 - Transform.scale 사용으로 레이아웃 안정화
          Transform.scale(
            scale: (1.0 + (safeLevel * _currentScaleMultiplier)).clamp(
              1.0,
              1.0 + _currentScaleMultiplier,
            ),
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 300),
              opacity: (0.2 + (safeLevel * _currentOpacityMultiplier)).clamp(
                0.0,
                0.4,
              ),
              child: Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.pink, width: 1.5),
                ),
              ),
            ),
          ),
          // 외부 펄스 링 2 - Transform.scale 사용으로 레이아웃 안정화
          Transform.scale(
            scale: (1.0 + (safeLevel * _currentScaleMultiplier * 0.75)).clamp(
              1.0,
              1.0 + (_currentScaleMultiplier * 0.75),
            ),
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 250),
              opacity: (0.3 + (safeLevel * _currentOpacityMultiplier)).clamp(
                0.0,
                0.5,
              ),
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.pink, width: 1.5),
                ),
              ),
            ),
          ),
          // 메인 원형 컨테이너 - 고정 크기로 안정화
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  Colors.pink.withOpacity(
                    (0.7 + (safeLevel * _currentOpacityMultiplier)).clamp(
                      0.0,
                      0.9,
                    ),
                  ),
                  Colors.pink.withOpacity(
                    (0.4 + (safeLevel * _currentOpacityMultiplier)).clamp(
                      0.0,
                      0.6,
                    ),
                  ),
                  Colors.pink.withOpacity(
                    (0.1 + (safeLevel * _currentOpacityMultiplier * 0.5)).clamp(
                      0.0,
                      0.2,
                    ),
                  ),
                ],
                stops: const [0.2, 0.6, 1.0],
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.pink.withOpacity(
                    (safeLevel * _currentOpacityMultiplier * 2).clamp(0.0, 0.4),
                  ),
                  blurRadius: (4 + (safeLevel * _currentScaleMultiplier * 40))
                      .clamp(4.0, 10.0),
                  spreadRadius: (safeLevel * _currentScaleMultiplier * 13)
                      .clamp(0.0, 2.0),
                ),
              ],
            ),
            child: Icon(
              Icons.favorite,
              size: 26, // 고정 크기
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: _close,
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
              side: BorderSide(color: Colors.grey.shade300),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              '취소',
              style: getTextStyle(fontSize: 14, color: Colors.grey.shade600),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(child: _buildPrimaryButton()),
      ],
    );
  }

  Widget _buildPrimaryButton() {
    if (_speechService.isListening) {
      return ElevatedButton(
        onPressed: () {
          if (mounted) {
            _speechService.stopListening();
          }
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.red,
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: Text(
          '중지',
          style: getTextStyle(fontSize: 14, color: Colors.white),
        ),
      );
    }

    if (_recognizedText.isNotEmpty) {
      return ElevatedButton(
        onPressed: () {
          if (mounted) {
            _handleSendCommand();
          }
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blue,
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: Text(
          '전송',
          style: getTextStyle(fontSize: 14, color: Colors.white),
        ),
      );
    }
    return ElevatedButton(
      onPressed: () {
        if (mounted) {
          _speechService.startListening(
            onResult: (text) {
              if (mounted) {
                setState(() {
                  _recognizedText = text;
                });
              }
            },
            context: context,
          );
        }
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.green,
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: Text('시작', style: getTextStyle(fontSize: 14, color: Colors.white)),
    );
  }
}
