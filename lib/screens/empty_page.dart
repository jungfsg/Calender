import 'package:flutter/material.dart';
import 'package:flutter_chat_ui/flutter_chat_ui.dart';
import 'package:flutter_chat_types/flutter_chat_types.dart' as types;
import 'package:uuid/uuid.dart';
import '../utils/font_utils.dart';
import '../services/chat_service.dart';

class EmptyPage extends StatefulWidget {
  const EmptyPage({Key? key}) : super(key: key);

  @override
  State<EmptyPage> createState() => _EmptyPageState();
}

class _EmptyPageState extends State<EmptyPage> {
  final List<types.Message> _messages = [];
  final _user = types.User(id: 'user');
  final _botUser = types.User(id: 'bot', firstName: 'AI 어시스턴트');
  final _uuid = Uuid();
  final ChatService _chatService = ChatService();
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

  void _handleSendPressed(types.PartialText message) async {
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
      // 서버로 메시지 전송 및 응답 받기
      final botResponse = await _chatService.sendMessage(
        message.text,
        _user.id,
      );

      setState(() {
        _messages.insert(0, botResponse);
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _addSystemMessage('죄송합니다. 서버 통신 중 오류가 발생했습니다: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
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
    );
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
