// lib/screens/chat_screen.dart (최종 수정본 - TTS 기능 완전 제거)
import 'package:flutter/material.dart';
import 'package:flutter_chat_ui/flutter_chat_ui.dart';
import 'package:flutter_chat_types/flutter_chat_types.dart' as types;
import 'package:uuid/uuid.dart';
import '../utils/font_utils.dart';
import '../services/chat_service.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:flutter/foundation.dart';
import '../widgets/common_navigation_bar.dart';
import 'package:gal/gal.dart';

// --- ★★★ 삭제: TTS 서비스 임포트 제거 ★★★ ---
// import '../services/tts_service.dart'; 

// --- ★★★ 수정: 클래스 이름을 파일명과 일치시켜 명확성 향상 ★★★ ---
class ChatScreen extends StatefulWidget {
  final VoidCallback? onCalendarUpdate;
  final dynamic eventManager;

  // --- ★★★ 수정: 생성자에서 TTS 관련 매개변수 제거 ★★★ ---
  const ChatScreen({super.key, this.onCalendarUpdate, this.eventManager});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
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
  
  final TextEditingController _chatInputController = TextEditingController();

  @override
  void initState() {
    super.initState();
    const initialMessage = '안녕하세요! 무엇을 도와드릴까요?';
    _addSystemMessage(initialMessage);
    // --- ★★★ 삭제: 초기 메시지 TTS 호출 제거 ★★★ ---
    // TtsService.instance.speak(initialMessage);
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
          print('🎉 캘린더 업데이트 콜백이 호출되었습니다!');
          _showCalendarUpdateNotification();
          widget.onCalendarUpdate?.call();
        },
        eventManager: widget.eventManager,
      );

      if (!mounted) return;
      setState(() {
        _messages.insert(0, botResponse);
        _isLoading = false;
      });

      // --- ★★★ 삭제: 봇 응답 TTS 호출 제거 ★★★ ---
      // TtsService.instance.speak(botResponse.text);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
      final errorMessage = '죄송합니다. 서버 통신 중 오류가 발생했습니다: $e';
      _addSystemMessage(errorMessage);
      // --- ★★★ 삭제: 에러 메시지 TTS 호출 제거 ★★★ ---
      // TtsService.instance.speak(errorMessage);
    }
  }

  Future<void> _handleImageSelection() async {
    final XFile? result = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
      maxWidth: 1440,
    );
    if (result != null) {
      await _handleImageUpload(File(result.path));
    }
  }

  Future<void> _handleCameraCapture() async {
    if (kIsWeb) return;

    try {
      final XFile? result = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 70,
        maxWidth: 1440,
      );

      if (result != null) {
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
          final inputImage = InputImage.fromFilePath(imageFile.path);
          final RecognizedText recognizedText = await _textRecognizer.processImage(inputImage);
          if (recognizedText.text.isNotEmpty) {
            final textMessage = types.TextMessage(
              author: _user,
              createdAt: DateTime.now().millisecondsSinceEpoch,
              id: _uuid.v4(),
              text: recognizedText.text,
            );
            setState(() {
              _messages.insert(0, textMessage);
            });

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
            // --- ★★★ 삭제: OCR 결과 TTS 호출 제거 ★★★ ---
            // TtsService.instance.speak(botResponse.text);
          } else {
            await _handleImageUpload(imageFile);
          }
        } catch (e) {
          setState(() {
            _isLoading = false;
          });
          final errorMessage = '이미지 처리 중 오류가 발생했습니다: $e';
          _addSystemMessage(errorMessage);
          // --- ★★★ 삭제: 에러 메시지 TTS 호출 제거 ★★★ ---
          // TtsService.instance.speak(errorMessage);
        }
      }
    } catch (e) {
      print('카메라 촬영 중 오류 발생: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('카메라 촬영 중 오류가 발생했습니다: $e')),
        );
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
      // --- ★★★ 삭제: 이미지 업로드 결과 TTS 호출 제거 ★★★ ---
      // TtsService.instance.speak(botResponse.text);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
      final errorMessage = '죄송합니다. 이미지 전송 중 오류가 발생했습니다: $e';
      _addSystemMessage(errorMessage);
      // --- ★★★ 삭제: 에러 메시지 TTS 호출 제거 ★★★ ---
      // TtsService.instance.speak(errorMessage);
    }
  }

  Widget _buildCustomInput() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      color: Colors.black12,
      child: SafeArea(
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.camera_alt),
              onPressed: _showImageSourceDialog,
              tooltip: '이미지 선택',
            ),
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: TextField(
                  controller: _chatInputController,
                  decoration: InputDecoration(
                    hintText: '메시지를 입력하세요',
                    hintStyle: getTextStyle(
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
      Navigator.of(context).pop({'refreshNavigation': true});
    } else if (index == 1) {
      Navigator.of(context).pop({'refreshNavigation': true, 'showVoiceInput': true});
    } else {
      setState(() {
        _selectedIndex = index;
      });
    }
  }

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

  void _showCalendarUpdateNotification() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('일정이 캘린더에 추가되었습니다!'),
        action: SnackBarAction(
          label: '캘린더 보기',
          onPressed: () {
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
        // --- ★★★ 삭제: 화면 나가기 전 TTS 중지 호출 제거 ★★★ ---
        // TtsService.instance.stop();
        Navigator.of(context).pop({'refreshNavigation': true});
        return false;
      },
      child: Scaffold(
        resizeToAvoidBottomInset: true,
        backgroundColor: const Color.fromARGB(255, 162, 222, 141),
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: Text(
            'AI 채팅',
            style: getTextStyle(
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
                  sentMessageBodyTextStyle: getTextStyle(fontSize: 16, color: Colors.white, text: '보낸 메시지'),
                  receivedMessageBodyTextStyle: getTextStyle(fontSize: 16, color: Colors.black, text: '받은 메시지'),
                  inputTextStyle: getTextStyle(fontSize: 14, color: Colors.black, text: '메시지 입력'),
                  emptyChatPlaceholderTextStyle: getTextStyle(fontSize: 14, color: Colors.grey, text: '메시지가 없습니다'),
                  userNameTextStyle: getTextStyle(fontSize: 12, color: Colors.grey[700], text: '사용자 이름'),
                  dateDividerTextStyle: getTextStyle(fontSize: 12, color: Colors.grey[600], text: '날짜 구분선'),
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
      _textRecognizer.close();
    }
    // --- ★★★ 삭제: 화면 종료 시 TTS 중지 호출 제거 ★★★ ---
    // TtsService.instance.stop();
    super.dispose();
  }
}

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
