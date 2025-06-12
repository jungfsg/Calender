// lib/screens/chat_screen.dart (최종 수정본)
import 'package:flutter/material.dart';
import 'package:flutter_chat_ui/flutter_chat_ui.dart';
import 'package:flutter_chat_types/flutter_chat_types.dart' as types;
import 'package:uuid/uuid.dart';
import '../utils/font_utils.dart';
import '../services/chat_service.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:convert';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:flutter/foundation.dart';
import '../widgets/common_navigation_bar.dart';
import 'package:gal/gal.dart';

// --- TTS 관련 추가 ---
import '../services/tts_service.dart'; // TTS 서비스 임포트

class EmptyPage extends StatefulWidget {
  final VoidCallback? onCalendarUpdate;
  final dynamic eventManager; // EventManager 타입을 추가 (동적 타입으로 사용)

  const EmptyPage({super.key, this.onCalendarUpdate, this.eventManager});

  @override
  State createState() => _EmptyPageState();
}

class _EmptyPageState extends State<EmptyPage> {
  final List<types.Message> _messages = [];
  final _user = types.User(id: 'user');
  final _botUser = types.User(id: 'bot', firstName: 'AMATTA');
  final _uuid = Uuid();
  final ChatService _chatService = ChatService();
  final ImagePicker _picker = ImagePicker();
  final TextRecognizer _textRecognizer = TextRecognizer(
    script: TextRecognitionScript.korean,
  );
  bool _isLoading = false;
  int _selectedIndex = 2;

  @override
  void initState() {
    super.initState();
    // 초기 시스템 메시지도 음성으로 재생
    const initialMessage = '안녕하세요! 무엇을 도와드릴까요?';
    _addSystemMessage(initialMessage);
    // --- TTS 관련 추가 ---
    // 앱 시작 시 초기 메시지 재생 (TTS가 활성화 되어있을 경우)
    TtsService.instance.speak(initialMessage);
  }

  void _addSystemMessage(String text) {
    final message = types.TextMessage(
      author: _botUser,
      createdAt: DateTime.now().millisecondsSinceEpoch,
      id: _uuid.v4(),
      text: text,
    );
    if (!mounted) return;
    setState(() {
      _messages.insert(0, message);
    });
  }

  Future<void> _handleSendPressed(types.PartialText message) async {
    if (!mounted) return;

    final textMessage = types.TextMessage(
      author: _user,
      createdAt: DateTime.now().millisecondsSinceEpoch,
      id: _uuid.v4(),
      text: message.text,
    );

    setState(() {
      _messages.insert(0, textMessage);
      _isLoading = true;
    });

    try {
      if (!mounted) return;
      final botResponse = await _chatService.sendMessage(
        message.text,
        _user.id,
        onCalendarUpdate: () {
          // 일정이 추가되었을 때 사용자에게 알림
          print('🎉 캘린더 업데이트 콜백이 호출되었습니다!');
          _showCalendarUpdateNotification();

          // 부모 위젯(캘린더 화면)의 콜백도 호출
          widget.onCalendarUpdate?.call();
        },
        eventManager: widget.eventManager, // EventManager 전달하여 Google 동기화 활성화
      );

      if (!mounted) return;
      setState(() {
        _messages.insert(0, botResponse);
        _isLoading = false;
      });

      // --- TTS 관련 추가 ---
      // 봇의 응답이 텍스트 메시지일 경우에만 음성으로 재생
      TtsService.instance.speak(botResponse.text);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
      final errorMessage = '죄송합니다. 서버 통신 중 오류가 발생했습니다: $e';
      _addSystemMessage(errorMessage);
      // --- TTS 관련 추가 ---
      TtsService.instance.speak(errorMessage);
    }
  }

  // ... (기존 _handleImageSelection 함수는 변경 없음) ...
  Future _handleImageSelection() async {
    final XFile? result = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
      maxWidth: 1440,
    );
    if (result != null) {
      await _handleImageUpload(File(result.path));
    }
  }

  Future _handleCameraCapture() async {
    if (kIsWeb) return; // 웹에서는 기능을 호출하지 않음

    try {
      final XFile? result = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 70,
        maxWidth: 1440,
      );

      if (result != null) {
        // 갤러리에 저장
        try {
          await Gal.putImage(result.path);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('📸 사진이 갤러리에 저장되었습니다.')),
            );
          }
        } catch (e) {
          print('갤러리 저장 실패: $e');
        }

        final File imageFile = File(result.path);

        // 이미지 메시지 생성
        final imageMessage = types.ImageMessage(
          author: _user,
          createdAt: DateTime.now().millisecondsSinceEpoch,
          id: _uuid.v4(),
          name: imageFile.path.split('/').last,
          size: await imageFile.length(),
          uri: imageFile.path,
        );

        setState(() {
          _messages.insert(0, imageMessage);
          _isLoading = true;
        });

        try {
          // OCR 처리
          final inputImage = InputImage.fromFilePath(imageFile.path);
          final RecognizedText recognizedText = await _textRecognizer
              .processImage(inputImage);
          if (recognizedText.text.isNotEmpty) {
            // 인식된 텍스트 메시지 생성
            final textMessage = types.TextMessage(
              author: _user,
              createdAt: DateTime.now().millisecondsSinceEpoch,
              id: _uuid.v4(),
              text: recognizedText.text,
            );
            setState(() {
              _messages.insert(0, textMessage);
            });

            // 인식된 텍스트를 서버로 전송
            final botResponse = await _chatService.sendMessage(
              recognizedText.text,
              _user.id,
              onCalendarUpdate: () {
                print('🎉 캘린더 업데이트 콜백이 호출되었습니다! (OCR)');
                _showCalendarUpdateNotification();
                widget.onCalendarUpdate?.call();
              },
              eventManager: widget.eventManager,
            );

            setState(() {
              _messages.insert(0, botResponse);
              _isLoading = false;
            });
            // --- TTS 관련 추가 ---
            TtsService.instance.speak(botResponse.text);
          } else {
            // 텍스트가 인식되지 않은 경우 이미지만 전송
            await _handleImageUpload(imageFile);
          }
        } catch (e) {
          setState(() {
            _isLoading = false;
          });
          final errorMessage = '이미지 처리 중 오류가 발생했습니다: $e';
          _addSystemMessage(errorMessage);
          // --- TTS 관련 추가 ---
          TtsService.instance.speak(errorMessage);
        }
      }
    } catch (e) {
      print('카메라 촬영 중 오류 발생: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('카메라 촬영 중 오류가 발생했습니다: $e')));
      }
    }
  }

  Future<void> _handleImageUpload(File imageFile) async {
    if (!mounted) return;

    final bytes = await imageFile.readAsBytes();
    final size = bytes.length;

    final imageMessage = types.ImageMessage(
      author: _user,
      createdAt: DateTime.now().millisecondsSinceEpoch,
      id: _uuid.v4(),
      name: imageFile.path.split('/').last,
      size: size,
      uri: imageFile.path,
    );

    setState(() {
      _messages.insert(0, imageMessage);
      _isLoading = true;
    });

    try {
      if (!mounted) return;
      final botResponse = await _chatService.sendImage(imageFile, _user.id);

      if (!mounted) return;
      setState(() {
        _messages.insert(0, botResponse);
        _isLoading = false;
      });
      // --- TTS 관련 추가 ---
      TtsService.instance.speak(botResponse.text);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
      final errorMessage = '죄송합니다. 이미지 전송 중 오류가 발생했습니다: $e';
      _addSystemMessage(errorMessage);
      // --- TTS 관련 추가 ---
      TtsService.instance.speak(errorMessage);
    }
  }

  // ... (이후 _buildCustomInput, _onItemTapped 등 나머지 코드는 기존과 동일합니다) ...
  // 커스텀 입력 영역 위젯
  Widget _buildCustomInput() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      color: Colors.black12,
      child: SafeArea(
        child: Row(
          children: [
            // 카메라 버튼 (이제 다이얼로그를 보여줌)
            IconButton(
              icon: const Icon(Icons.camera_alt),
              onPressed: _showImageSourceDialog,
              tooltip: '이미지 선택',
            ),
            // 메시지 입력 필드
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: TextField(
                  controller: _chatInputController,
                  decoration: InputDecoration(
                    hintText: '메시지를 입력하세요',
                    hintStyle: getCustomTextStyle(
                      fontSize: 14,
                      color: const Color.fromARGB(255, 0, 0, 0),
                      text: '메시지를 입력하세요',
                    ),
                    border: InputBorder.none,
                  ),
                  maxLines: null,
                  textCapitalization: TextCapitalization.sentences,
                  onSubmitted: _handleSubmitted,
                ),
              ),
            ),
            // 전송 버튼
            IconButton(
              icon: const Icon(Icons.send),
              onPressed: _handleSubmitPressed,
              tooltip: '메시지 전송',
            ),
          ],
        ),
      ),
    );
  }

  final TextEditingController _chatInputController = TextEditingController();

  void _handleSubmitted(String text) {
    if (text.trim().isNotEmpty) {
      _handleSendPressed(types.PartialText(text: text.trim()));
      _chatInputController.clear();
    }
  }

  void _handleSubmitPressed() {
    _handleSubmitted(_chatInputController.text);
  }

  void _onItemTapped(int index) {
    if (index == 0) {
      // 캘린더로 돌아가기 - 결과와 함께 pop
      Navigator.of(context).pop({'refreshNavigation': true});
    } else if (index == 1) {
      // 마이크 버튼 - 캘린더로 돌아가기 (캘린더 화면에서 음성 인식 UI 표시)
      Navigator.of(
        context,
      ).pop({'refreshNavigation': true, 'showVoiceInput': true});
    } else {
      setState(() {
        _selectedIndex = index;
      });
    }
  }
  // 음성 명령 관련 함수는 캘린더 화면으로 이동하므로 이 화면에서는 제거

  // 이미지 소스 선택 다이얼로그
  Future<void> _showImageSourceDialog() async {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text('카메라로 촬영'),
                onTap: () {
                  Navigator.pop(context);
                  _handleCameraCapture();
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo),
                title: const Text('갤러리에서 선택'),
                onTap: () {
                  Navigator.pop(context);
                  _handleImageSelection();
                },
              ),
              ListTile(
                leading: const Icon(Icons.cancel),
                title: const Text('취소'),
                onTap: () {
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  // 캘린더 업데이트 알림 표시
  void _showCalendarUpdateNotification() {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('일정이 캘린더에 추가되었습니다!'),
        action: SnackBarAction(
          label: '캘린더 보기',
          onPressed: () {
            // 캘린더 탭으로 이동 (이전 화면으로 돌아가기)
            Navigator.of(context).pop();
          },
        ),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        if (_isLoading) {
          return false;
        }
        // --- TTS 관련 추가 ---
        // 화면을 나가기 전에 TTS 중지
        TtsService.instance.stop();
        Navigator.of(context).pop({'refreshNavigation': true});
        return false;
      },
      child: Scaffold(
        resizeToAvoidBottomInset: true, // 입력시 네비게이션 바 위치 고정 여부(false시 고정)
        backgroundColor: const Color.fromARGB(255, 162, 222, 141),
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: Text(
            'AI 채팅',
            style: getCustomTextStyle(
              fontSize: 16,
              color: const Color.fromARGB(255, 255, 255, 255),
              text: 'AI 채팅',
            ),
          ),
          backgroundColor: const Color.fromARGB(255, 162, 222, 141),
        ),
        body: Column(
          children: [
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.all(8.0),

                child: LinearProgressIndicator(),
              ),
            Expanded(
              child: Chat(
                messages: _messages,
                onSendPressed: _handleSendPressed,
                user: _user,
                showUserNames: true,
                customBottomWidget: _buildCustomInput(),
                theme: DefaultChatTheme(
                  inputBackgroundColor: Colors.black12,
                  backgroundColor: Colors.white,
                  inputTextColor: Colors.black,
                  sentMessageBodyTextStyle: getCustomTextStyle(
                    fontSize: 16,
                    color: Colors.white,
                    text: '보낸 메시지',
                  ),
                  receivedMessageBodyTextStyle: getCustomTextStyle(
                    fontSize: 16,
                    color: Colors.black,
                    text: '받은 메시지',
                  ),
                  inputTextStyle: getCustomTextStyle(
                    fontSize: 14,
                    color: Colors.black,
                    text: '메시지 입력',
                  ),
                  emptyChatPlaceholderTextStyle: getCustomTextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                    text: '메시지가 없습니다',
                  ),
                  userNameTextStyle: getCustomTextStyle(
                    fontSize: 12,
                    color: Colors.grey[700],
                    text: '사용자 이름',
                  ),
                  dateDividerTextStyle: getCustomTextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    text: '날짜 구분선',
                  ),
                ),
                l10n: const ChatL10nKo(),
              ),
            ),
          ],
        ),
        bottomNavigationBar: CommonNavigationBar(
          selectedIndex: _selectedIndex,
          onItemTapped: _onItemTapped,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _chatInputController.dispose();
    if (!kIsWeb) {
      _textRecognizer.close(); // 웹이 아닐 때만 리소스 해제
    }
    // --- TTS 관련 추가 ---
    // 화면이 완전히 종료될 때 TTS 중지
    TtsService.instance.stop();
    super.dispose();
  }
}

// 한국어 지역화 클래스
class ChatL10nKo extends ChatL10n {
  const ChatL10nKo({
    super.attachmentButtonAccessibilityLabel = '파일 첨부',
    super.emptyChatPlaceholder = '메시지가 없습니다',
    super.fileButtonAccessibilityLabel = '파일',
    super.inputPlaceholder = '메시지를 입력하세요',
    super.sendButtonAccessibilityLabel = '전송',
    super.and = '그리고',
    super.isTyping = '입력 중...',
    super.unreadMessagesLabel = '읽지 않은 메시지',
    super.others = '+1',
  });
}
