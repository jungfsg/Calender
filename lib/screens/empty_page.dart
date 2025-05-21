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

class EmptyPage extends StatefulWidget {
  const EmptyPage({Key? key}) : super(key: key);

  @override
  State createState() => _EmptyPageState();
}

class _EmptyPageState extends State<EmptyPage> {
  final List<types.Message> _messages = [];
  final _user = types.User(id: 'user');
  final _botUser = types.User(id: 'bot', firstName: 'AI 어시스턴트');
  final _uuid = Uuid();
  final ChatService _chatService = ChatService();
  final ImagePicker _picker = ImagePicker();
  final TextRecognizer _textRecognizer = TextRecognizer(
    script: TextRecognitionScript.korean,
  );
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _addSystemMessage('안녕하세요! 무엇을 도와드릴까요?');
  }

  void _addSystemMessage(String text) {
    final message = types.TextMessage(
      author: _botUser,
      createdAt: DateTime.now().millisecondsSinceEpoch,
      id: _uuid.v4(),
      text: text,
    );
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
      );
      
      if (!mounted) return;
      setState(() {
        _messages.insert(0, botResponse);
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
      _addSystemMessage('죄송합니다. 서버 통신 중 오류가 발생했습니다: $e');
    }
  }

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
    final XFile? result = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 70,
      maxWidth: 1440,
    );
    if (result != null) {
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
          );

          setState(() {
            _messages.insert(0, botResponse);
            _isLoading = false;
          });
        } else {
          // 텍스트가 인식되지 않은 경우 이미지만 전송
          await _handleImageUpload(imageFile);
        }
      } catch (e) {
        setState(() {
          _isLoading = false;
        });
        _addSystemMessage('이미지 처리 중 오류가 발생했습니다: $e');
      }
    }
  }

  Future<void> _handleImageUpload(File imageFile) async {
    if (!mounted) return;
    
    final bytes = await imageFile.readAsBytes();
    final base64Image = base64Encode(bytes);
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
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
      _addSystemMessage('죄송합니다. 이미지 전송 중 오류가 발생했습니다: $e');
    }
  }

  // 커스텀 입력 영역 위젯
  Widget _buildCustomInput() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      color: Colors.black12,
      child: SafeArea(
        child: Row(
          children: [
            // 카메라 버튼
            IconButton(
              icon: const Icon(Icons.camera_alt),
              onPressed: _handleCameraCapture,
              tooltip: '카메라로 텍스트 인식',
            ),
            // 갤러리 버튼
            IconButton(
              icon: const Icon(Icons.photo),
              onPressed: _handleImageSelection,
              tooltip: '갤러리에서 사진 선택',
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
                      color: Colors.grey,
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

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        if (_isLoading) {
          return false; // 로딩 중에는 뒤로가기 방지
        }
        return true;
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              Navigator.of(context).pop();
            },
          ),
          title: Text(
            'AI 채팅',
            style: getCustomTextStyle(
              fontSize: 14,
              color: Colors.white,
              text: 'AI 채팅',
            ),
          ),
          backgroundColor: Colors.black,
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
      ),
    );
  }

  @override
  void dispose() {
    if (mounted) {
      setState(() {
        _isLoading = false;
        _messages.clear();
      });
    }
    _chatInputController.dispose();
    _textRecognizer.close();
    super.dispose();
  }
}

// 한국어 지역화 클래스
class ChatL10nKo extends ChatL10n {
  const ChatL10nKo({
    String attachmentButtonAccessibilityLabel = '파일 첨부',
    String emptyChatPlaceholder = '메시지가 없습니다',
    String fileButtonAccessibilityLabel = '파일',
    String inputPlaceholder = '메시지를 입력하세요',
    String sendButtonAccessibilityLabel = '전송',
    String and = '그리고',
    String isTyping = '입력 중...',
    String unreadMessagesLabel = '읽지 않은 메시지',
    String others = '+1',
  }) : super(
         attachmentButtonAccessibilityLabel: attachmentButtonAccessibilityLabel,
         emptyChatPlaceholder: emptyChatPlaceholder,
         fileButtonAccessibilityLabel: fileButtonAccessibilityLabel,
         inputPlaceholder: inputPlaceholder,
         sendButtonAccessibilityLabel: sendButtonAccessibilityLabel,
         and: and,
         isTyping: isTyping,
         unreadMessagesLabel: unreadMessagesLabel,
         others: others,
       );
}
