import 'package:flutter/material.dart';
import '../services/stt_service.dart';
import '../utils/font_utils.dart';
import 'dart:math' as math;
import 'dart:async';

/// 음성 입력 위젯 - STT UI만 담당하는 재사용 가능한 위젯
class VoiceInputWidget extends StatefulWidget {
  final Function(String) onVoiceCommand;
  final Function(String, Function(String))?
  onProcessCommand; // 명령 처리 결과를 받기 위한 콜백
  final VoidCallback? onClose;
  final double pulseSensitivity;
  final double scaleMultiplier;
  final double opacityMultiplier;

  const VoiceInputWidget({
    super.key,
    required this.onVoiceCommand,
    this.onProcessCommand,
    this.onClose,
    this.pulseSensitivity = 0.3, // 0.1 (낮음) ~ 1.0 (높음) - 소리 레벨 반응 정도 증가
    this.scaleMultiplier = 0.4, // 크기 변화 강도 - 펄스 크기 변화 증가
    this.opacityMultiplier = 0.7, // 투명도 변화 강도 증가
  });

  @override
  State<VoiceInputWidget> createState() => _VoiceInputWidgetState();
}

class _VoiceInputWidgetState extends State<VoiceInputWidget>
    with TickerProviderStateMixin {
  String _recognizedText = '';
  double _soundLevel = 0.0; // 소리 레벨 추가
  final SpeechService _speechService = SpeechService();
  // 런타임에 조절 가능한 민감도 설정
  late double _currentSensitivity;
  // 음소거 상태 추적
  bool _isMuted = false;
  // 자동 일시정지 상태 추적 (무음 시간 제한에 의한 일시정지)
  bool _isAutoPaused = false;
  // 파형 애니메이션을 위한 컨트롤러들
  late AnimationController _rotationController;
  late AnimationController _pulseController;
  late AnimationController _particleController;
  late AnimationController _colorChangeController;

  // 텍스트 인식 후 전송 버튼을 표시하기까지의 지연 시간 (초)
  final int _delayBeforeSendButton = 5;
  // 전송 버튼 표시 여부
  bool _showSendButton = false;
  // 타이머
  Timer? _sendButtonTimer;

  // 명령 처리 결과를 저장할 변수 추가
  String _commandResponse = '';
  bool _isProcessing = false; // 명령 처리 중 상태

  @override
  void initState() {
    super.initState();
    // 민감도 초기값 설정
    _currentSensitivity = widget.pulseSensitivity;

    // 애니메이션 컨트롤러 초기화
    _rotationController = AnimationController(
      duration: const Duration(seconds: 10),
      vsync: this,
    )..repeat();

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    _particleController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat(); // 색상 변경 애니메이션 컨트롤러 초기화
    _colorChangeController = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    )..forward();

    _initSpeechService().then((_) {
      // 음성 인식 초기화가 완료되면 자동으로 녹음 시작
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) {
          _speechService.startListening(
            onResult: (text) {
              if (mounted) {
                setState(() {
                  _recognizedText = text;

                  // 타이머 취소 후 새로 시작
                  _sendButtonTimer?.cancel();
                  _showSendButton =
                      false; // 타이머 설정 - 마지막 텍스트 인식 후 지연 시간 이후에 전송 버튼 표시
                  if (text.isNotEmpty) {
                    _sendButtonTimer = Timer(
                      Duration(seconds: _delayBeforeSendButton),
                      () {
                        if (mounted) {
                          setState(() {
                            _showSendButton = true;
                          });
                        }
                      },
                    );
                  }
                });
              }
            },
            context: context,
          );
        }
      });
    });
  }

  @override
  void dispose() {
    // 애니메이션 컨트롤러들 dispose
    _rotationController.dispose();
    _pulseController.dispose();
    _particleController.dispose();
    _colorChangeController.dispose(); // 색상 변경 컨트롤러 dispose

    // 타이머 취소
    _sendButtonTimer?.cancel();

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
    } // 음성 인식 콜백은 startListening에서 직접 처리하므로 여기서는 설정하지 않음    // 음성 인식 상태 변경 콜백 설정
    _speechService.onListeningStatusChanged = (isListening) {
      if (mounted) {
        setState(() {
          // 자동 일시정지 상태 감지 - 무음 시간 제한에 의해 자동으로 일시정지된 경우
          if (!isListening && !_isMuted) {
            _isAutoPaused = true;
            print('자동 일시정지 설정됨: $_isAutoPaused'); // 디버깅용
          } else if (isListening) {
            _isAutoPaused = false;
            print('자동 일시정지 해제됨: $_isAutoPaused'); // 디버깅용
          }
        });
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
      setState(() {
        _isProcessing = true;
        _commandResponse = "명령어 처리 중...";
      });

      if (widget.onProcessCommand != null) {
        // 새로운 방식: 명령 처리 결과를 받을 수 있는 콜백 함수 전달
        widget.onProcessCommand!(_recognizedText, (response) {
          if (mounted) {
            setState(() {
              _isProcessing = false;
              _commandResponse = response;
            });
          }
        });
      } else {
        // 기존 방식: 명령어만 전달하고 창 닫기
        widget.onVoiceCommand(_recognizedText);
        _close();
      }
    }
  }

  void _close() {
    _speechService.cancelListening();
    widget.onClose?.call();
  }

  // 음소거 토글 함수
  void _toggleMute() {
    setState(() {
      _isMuted = !_isMuted;
      if (_isMuted) {
        _speechService.pauseListening();
      } else {
        _speechService.resumeListening();
      }
    });
  } // 녹음 다시 시작 함수 추가

  void _restartListening() {
    // 기존 음성 인식 세션 취소
    _speechService.cancelListening();

    setState(() {
      _isAutoPaused = false;
      _recognizedText = ''; // 텍스트 초기화
      _showSendButton = false; // 전송 버튼도 초기화

      // 명령 응답은 유지 (이전 응답 기록을 보존)
      // _commandResponse = '';
    });

    // 약간의 지연 후 새 세션 시작
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        _speechService.startListening(
          onResult: (text) {
            if (mounted) {
              setState(() {
                _recognizedText = text;

                // 타이머 취소 후 새로 시작
                _sendButtonTimer?.cancel();
                _showSendButton = false;
                if (text.isNotEmpty) {
                  _sendButtonTimer = Timer(
                    Duration(seconds: _delayBeforeSendButton),
                    () {
                      if (mounted) {
                        setState(() {
                          _showSendButton = true;
                        });
                      }
                    },
                  );
                }
              });
            }
          },
          context: context,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // 메인 UI - 전체 화면으로 확장
        Container(
          height: MediaQuery.of(context).size.height, // 전체 화면 높이
          width: MediaQuery.of(context).size.width, // 전체 화면 너비
          color: Colors.transparent, // 투명하게 변경
          child: Column(
            children: [
              // 텍스트 표시 영역을 제일 상단으로 이동
              Padding(
                padding: const EdgeInsets.only(top: 0, left: 40, right: 40),
                child: _buildTextDisplay(),
              ),
              // 빈 공간 추가
              const Spacer(),
              // 파형 애니메이션 영역 (버튼 바로 위에 배치)
              if (_speechService.isListening || _isMuted)
                Padding(
                  padding: const EdgeInsets.only(bottom: 20),
                  child: _buildVoiceAnimation(),
                ),
              // 하단 버튼들
              Padding(
                padding: const EdgeInsets.only(
                  left: 24,
                  right: 24,
                  bottom: 50,
                  top: 0,
                ),
                child: _buildActionButtons(),
              ),
            ],
          ),
        ),
        // 음성 인식 중이 아닐 때만 애니메이션 오버레이 제거 (이제 메인 UI에 통합됨)
      ],
    );
  }

  Widget _buildTextDisplay() {
    return Container(
      width: double.infinity,
      height: 400, // 고정 높이로 설정하여 안정성 확보
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.1), // 배경 살짝 어둡게
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.8)),
      ),
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(), // 스크롤 효과 추가
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 인식된 음성 텍스트
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: Text(
                _recognizedText.isEmpty ? '무엇을 도와드릴까요?' : _recognizedText,
                key: ValueKey(_recognizedText),
                style: getTextStyle(
                  fontSize: 16, // 음성 인식 텍스트 크기 증가
                  color:
                      _recognizedText.isEmpty ? Colors.white70 : Colors.white,
                ),
              ),
            ),

            // 명령어 처리 결과가 있을 때만 구분선과 응답 표시
            if (_commandResponse.isNotEmpty) ...[
              const SizedBox(height: 10),
              Divider(color: Colors.white.withOpacity(0.3), thickness: 0.8),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Icon(
                      _isProcessing ? Icons.pending : Icons.chat_bubble_outline,
                      color:
                          _isProcessing ? Colors.amber : Colors.lightBlueAccent,
                      size: 16,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _commandResponse,
                      style: getTextStyle(
                        fontSize: 14, // 줄 간격 추가
                        color:
                            _isProcessing
                                ? Colors.amber
                                : Colors.lightBlueAccent.shade100,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildVoiceAnimation() {
    // 안전한 값 계산 - 민감도 설정 적용
    final safeLevel = (_soundLevel * _currentSensitivity).clamp(0.0, 1.0);

    return Center(
      child: AnimatedScale(
        scale: 1.0 + (safeLevel * 0.1),
        duration: const Duration(milliseconds: 200),
        child: _buildwave(safeLevel),
      ),
    );
  } // 이곳은 파형 애니메이션 관련 함수들의 공간입니다.

  Widget _buildwave(double safeLevel) {
    // 음성 레벨에 따라 움직이는 파형 애니메이션 구현
    return AnimatedBuilder(
      animation: Listenable.merge([
        _rotationController,
        _particleController,
        _pulseController,
      ]),
      builder: (context, child) {
        // 파형을 만들기 위한 바 수 정의
        const int barCount = 24; // 더 많은 막대를 사용하여 더 부드러운 파형

        return SizedBox(
          width: 280,
          height: 110,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            crossAxisAlignment: CrossAxisAlignment.end, // 바닥에서부터 시작하도록
            children: List.generate(barCount, (index) {
              // 인접한 막대끼리는 높이 차이가 너무 크지 않도록 부드럽게 연결
              // 각 바의 기본 높이 계산
              double baseHeight = 10.0 + (safeLevel * 60.0);

              // 다양한 파형 패턴 생성을 위한 시간 값
              double t = _particleController.value;

              // 싸인, 코사인, 탄젠트 등 다양한 함수를 활용하여 복합적인 파형 패턴 생성
              double normalizedIndex = index / (barCount - 1);

              // 여러 가지 파형 패턴을 생성
              double wave1 = math.sin(
                (t * 2 * math.pi) + (normalizedIndex * math.pi * 2),
              ); // 기본 사인파
              double wave2 = math.sin(
                (t * 3.5 * math.pi) + (normalizedIndex * math.pi * 3),
              ); // 빠른 사인파
              double wave3 = math.cos(
                (t * 1.5 * math.pi) + (normalizedIndex * math.pi * 1.5),
              ); // 코사인파
              // 약간의 비대칭성을 위해 탄젠트 파형 추가 (제한된 범위로)
              double wave4 = math.tan(
                (t * 0.5 * math.pi) + (normalizedIndex * math.pi * 0.5),
              );
              wave4 =
                  wave4.clamp(-1.0, 1.0) * 0.2; // 탄젠트는 매우 극단적인 값을 가질 수 있으므로 제한

              // 펄스 효과 - 전체 파형의 진폭을 주기적으로 변화
              double pulseEffect =
                  0.5 + (0.5 * math.sin(_pulseController.value * math.pi * 2));

              // 음성 레벨에 따른 추가 변조
              double voiceModulation = 1.0 + (safeLevel * 0.7);

              // 여러 패턴을 혼합하여 최종 파형 패턴 계산
              double wavePattern =
                  (wave1 * 0.45 + wave2 * 0.25 + wave3 * 0.25 + wave4 * 0.05) *
                  voiceModulation *
                  pulseEffect;

              // 최종 높이 계산
              double height = baseHeight + (wavePattern * 35.0);

              // 최소값 및 최대값 제한
              height = height.clamp(3.0, 90.0); // 막대 너비 (더 균일하게 설정)
              double centerEffect = math.sin(normalizedIndex * math.pi);
              double barWidth = 3.5 + (centerEffect * 2.0);

              // 색상 그라데이션 (중앙에서 바깥쪽으로 색상 변화)
              double colorPosition = normalizedIndex;

              // 음성 레벨에 따른 색상 강도 조정
              double intensityFactor = 0.5 + (safeLevel * 0.5);
              double brightnessBoost =
                  centerEffect * 0.3 * intensityFactor; // 중앙이 더 밝게

              // 기본 색상 팔레트 설정
              Color startColor = Colors.blue.shade500;
              Color midColor = Colors.purple;
              Color endColor = Colors.red.shade500;

              // 음성 레벨이 높을 때는 더 화려한 색상으로
              if (safeLevel > 0.6) {
                startColor = Colors.cyan;
                midColor = Colors.purple.shade300;
                endColor = Colors.orange;
              }

              // 색상 그라데이션 생성
              Color barColor;
              if (colorPosition < 0.5) {
                // 파란색 -> 보라색 변환
                barColor =
                    Color.lerp(startColor, midColor, colorPosition * 2) ??
                    midColor;
              } else {
                // 보라색 -> 빨간색 변환
                barColor =
                    Color.lerp(midColor, endColor, (colorPosition - 0.5) * 2) ??
                    endColor;
              }

              // 레벨이 높으면 색상을 더 밝게
              barColor =
                  Color.lerp(
                    barColor,
                    Colors.white,
                    (brightnessBoost + safeLevel * 0.2).clamp(0.0, 0.6),
                  ) ??
                  barColor;

              // 각 바를 그림
              return AnimatedContainer(
                duration: const Duration(milliseconds: 40),
                width: barWidth,
                height: height,
                margin: const EdgeInsets.symmetric(horizontal: 0.8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      barColor,
                      Color.lerp(barColor, Colors.white, 0.5) ?? barColor,
                    ],
                    stops: const [0.6, 1.0],
                  ),
                  borderRadius: BorderRadius.circular(barWidth / 2),
                  boxShadow: [
                    BoxShadow(
                      color: barColor.withOpacity(0.6),
                      blurRadius: 3.0 + (safeLevel * 4.0),
                      spreadRadius: safeLevel * 1.5,
                    ),
                  ],
                ),
              );
            }),
          ),
        );
      },
    );
  }

  Widget _buildActionButtons() {
    final safeLevel = (_soundLevel * _currentSensitivity).clamp(0.0, 1.0);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        // 취소 버튼 (X 아이콘)
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: 58,
          height: 58,
          margin: const EdgeInsets.only(left: 0, right: 20),
          decoration: BoxDecoration(
            color: Colors.grey[800]?.withOpacity(0.9),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 8,
                spreadRadius: 1,
              ),
            ],
          ),
          child: IconButton(
            icon: const Icon(Icons.close, color: Colors.white, size: 28),
            onPressed: _close,
            tooltip: '취소',
          ),
        ), // 중앙에 상태 표시 또는 다시 시작 버튼 표시
        _isAutoPaused
            ? _buildRestartButton() // 자동 일시정지 상태일 때 다시하기 버튼 표시
            : AnimatedOpacity(
              duration: const Duration(milliseconds: 300),
              opacity: _isMuted || _recognizedText.isNotEmpty ? 1.0 : 0.6,
              child: Container(
                width: 150, // 고정된 너비 추가
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color:
                      _isMuted
                          ? Colors.grey[900]?.withOpacity(0.7)
                          : Colors.grey[900]?.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color:
                        _isMuted
                            ? Colors.white.withOpacity(0.1)
                            : Colors.white.withOpacity(0.1),
                    width: 0.5,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center, // 중앙 정렬 추가
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_isMuted)
                      Icon(
                        Icons.mic_off,
                        color: Colors.red.withOpacity(0.9),
                        size: 16,
                      ),
                    if (_isMuted) const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        _isMuted
                            ? '음소거'
                            : (_recognizedText.isNotEmpty
                                ? '계속 말씀하세요...'
                                : '음성 인식 중...'),
                        style: getCustomTextStyle(
                          fontSize: 13,
                          color: _isMuted ? Colors.white : Colors.white70,
                          fontWeight:
                              _isMuted ? FontWeight.w500 : FontWeight.normal,
                        ),
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        // 음소거 또는 전송 버튼
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: 58,
          height: 58,
          margin: const EdgeInsets.only(right: 0, left: 20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                _isMuted
                    ? Colors.red.shade300
                    : (_recognizedText.isNotEmpty
                        ? Colors.blue.shade400
                        : Colors.red.shade400.withOpacity(
                          0.8 + (safeLevel * 0.2),
                        )),
                _isMuted
                    ? Colors.red.shade600
                    : (_recognizedText.isNotEmpty
                        ? Colors.blue.shade600
                        : Colors.red.shade600.withOpacity(
                          0.8 + (safeLevel * 0.2),
                        )),
              ],
            ),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color:
                    _isMuted
                        ? Colors.red.withOpacity(0.4)
                        : (_recognizedText.isNotEmpty
                            ? Colors.blue.withOpacity(0.4)
                            : Colors.red.withOpacity(0.2 + (safeLevel * 0.3))),
                blurRadius: 10,
                spreadRadius: 2,
              ),
            ],
          ),
          child: _buildPrimaryButton(),
        ),
      ],
    );
  }

  // 다시 시작 버튼 빌드 함수
  Widget _buildRestartButton() {
    return GestureDetector(
      onTap: _restartListening,
      child: Container(
        width: 150, // 고정된 너비 설정
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.green.shade600.withOpacity(0.9),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.green.withOpacity(0.3),
              blurRadius: 8,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center, // 중앙 정렬 추가
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.refresh, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Text(
              '다시 시작',
              style: getCustomTextStyle(
                fontSize: 14,
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPrimaryButton() {
    // 텍스트가 인식되었고 비어있지 않을 때, 타이머가 완료된 후에만 전송 버튼 표시
    if (_recognizedText.isNotEmpty && _showSendButton) {
      return IconButton(
        onPressed: () {
          if (mounted) {
            _handleSendCommand();

            // 명령 처리 후에도 화면 유지
            setState(() {
              _showSendButton = false;
            });

            // 추가 음성 입력을 위해 자동으로 음성 인식 재시작
            Future.delayed(const Duration(seconds: 2), () {
              if (mounted && !_speechService.isListening && !_isMuted) {
                _restartListening();
              }
            });
          }
        },
        tooltip: '명령 전송',
        icon: const Icon(Icons.send, color: Colors.white, size: 26),
      );
    }

    // 텍스트가 인식되었지만 타이머가 완료되지 않았거나, 음소거 상태일 때 마이크 또는 음소거 버튼 표시
    if (_speechService.isListening || _isMuted) {
      final safeLevel = (_soundLevel * _currentSensitivity).clamp(0.0, 1.0);

      return IconButton(
        onPressed: () {
          if (mounted) {
            _toggleMute();
          }
        },
        tooltip: _isMuted ? '음소거 해제' : '음소거',
        icon: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: EdgeInsets.all(_isMuted ? 0 : (safeLevel * 3.0)),
          child: Icon(
            _isMuted ? Icons.mic_off : Icons.mic,
            color: Colors.white,
            size: 28,
          ),
        ),
      );
    }

    // '시작' 버튼 제거 - 대신 자동으로 녹음이 시작되도록 함
    // 아무 버튼도 표시되지 않도록 빈 컨테이너 반환
    return Container();
  }
}
