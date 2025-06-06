import 'package:flutter/material.dart';
import '../services/stt_service.dart';
import '../utils/font_utils.dart';

/// 음성 입력 위젯 - STT UI만 담당하는 재사용 가능한 위젯
class VoiceInputWidget extends StatefulWidget {
  final Function(String) onVoiceCommand;
  final VoidCallback? onClose;

  const VoiceInputWidget({
    super.key,
    required this.onVoiceCommand,
    this.onClose,
  });

  @override
  State<VoiceInputWidget> createState() => _VoiceInputWidgetState();
}

class _VoiceInputWidgetState extends State<VoiceInputWidget> {
  String _recognizedText = '';
  final SpeechService _speechService = SpeechService();

  @override
  void initState() {
    super.initState();
    _initSpeechService();
  }

  @override
  void dispose() {
    _speechService.cancelListening();
    super.dispose();
  }

  Future<void> _initSpeechService() async {
    bool available = await _speechService.initialize();
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
    };

    // 오류 콜백 설정
    _speechService.onError = (error) {
      _showError(error);
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
    return Container(
      height: MediaQuery.of(context).size.height * 0.4,
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
                children: [
                  _buildTextDisplay(),
                  const SizedBox(height: 16),
                  _buildStatusIndicator(),
                  const SizedBox(height: 16),
                  _buildActionButtons(),
                ],
              ),
            ),
          ),
        ],
      ),
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
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            child: Icon(
              _speechService.isListening ? Icons.mic : Icons.mic_none,
              color: _speechService.isListening ? Colors.red : Colors.grey,
              size: 24,
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
    return Expanded(
      child: Container(
        width: double.infinity,
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
      ),
    );
  }

  Widget _buildStatusIndicator() {
    if (!_speechService.isListening) return const SizedBox.shrink();

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: const BoxDecoration(
            color: Colors.red,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '음성 인식 중...',
          style: getTextStyle(fontSize: 14, color: Colors.red),
        ),
      ],
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
        onPressed: () => _speechService.stopListening(),
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
        onPressed: _handleSendCommand,
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
        _speechService.startListening(
          onResult: (text) {
            setState(() {
              _recognizedText = text;
            });
          },
        );
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
