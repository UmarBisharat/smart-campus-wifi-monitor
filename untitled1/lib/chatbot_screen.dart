import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:hive_flutter/hive_flutter.dart';

class ChatbotScreen extends StatefulWidget {
  const ChatbotScreen({super.key});

  @override
  State<ChatbotScreen> createState() => _ChatbotScreenState();
}

class _ChatbotScreenState extends State<ChatbotScreen> {
  // TODO: move this off the client (e.g. a small backend proxy) before
  // shipping — a hardcoded key here can be pulled straight out of the
  // compiled app.
  static const String _apiKey = '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';

  final Box _box = Hive.box('chatsBox');
  final TextEditingController _controller = TextEditingController();

  String _currentChatId = '';
  List<Map<String, String>> _messages = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _startNewChat(save: false);
  }

  List<Map<String, dynamic>> _getAllChats() {
    final raw = _box.get('chats', defaultValue: []) as List;
    return raw.map((e) => Map<String, dynamic>.from(e)).toList();
  }

  void _saveCurrentChat() {
    final chats = _getAllChats();
    final index = chats.indexWhere((c) => c['id'] == _currentChatId);

    final title = _messages.firstWhere(
          (m) => m['sender'] == 'user',
      orElse: () => {'text': 'New Chat'},
    )['text'];

    final chatData = {
      'id': _currentChatId,
      'title': title,
      'messages': _messages,
    };

    if (index == -1) {
      chats.add(chatData);
    } else {
      chats[index] = chatData;
    }

    _box.put('chats', chats);
  }

  void _startNewChat({bool save = true}) {
    if (save && _messages.length > 1) _saveCurrentChat();

    setState(() {
      _currentChatId = DateTime.now().millisecondsSinceEpoch.toString();
      _messages = [
        {'sender': 'bot', 'text': 'Hi! How can I help you today?'},
      ];
    });
  }

  void _openChat(Map<String, dynamic> chat) {
    setState(() {
      _currentChatId = chat['id'];
      _messages = (chat['messages'] as List)
          .map((e) => Map<String, String>.from(e))
          .toList();
    });
    Navigator.pop(context);
  }

  void _deleteChat(String id) {
    final chats = _getAllChats();
    chats.removeWhere((c) => c['id'] == id);
    _box.put('chats', chats);

    if (id == _currentChatId) {
      _startNewChat(save: false);
    } else {
      setState(() {});
    }
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _messages.add({'sender': 'user', 'text': text});
      _isLoading = true;
    });
    _controller.clear();
    _saveCurrentChat();

    try {
      final response = await http.post(
        Uri.parse('https://api.groq.com/openai/v1/chat/completions'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_apiKey',
        },
        body: jsonEncode({
          'model': 'openai/gpt-oss-120b',
          'messages': [
            {'role': 'user', 'content': text},
          ],
        }),
      );

      final data = jsonDecode(response.body);

      if (data['error'] != null) {
        setState(() {
          _messages.add({
            'sender': 'bot',
            'text': 'API Error: ${data['error']['message']}',
          });
        });
        return;
      }

      final reply = data['choices']?[0]?['message']?['content'] ??
          'Something went wrong.';

      setState(() {
        _messages.add({'sender': 'bot', 'text': reply});
      });
    } catch (e) {
      setState(() {
        _messages.add({'sender': 'bot', 'text': 'Error: could not reach server.'});
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
      _saveCurrentChat();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Chatbot',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _startNewChat(),
          ),
        ],
      ),
      drawer: Drawer(
        child: SafeArea(
          child: Column(
            children: [
              Container(
                width: double.infinity,
                color: colorScheme.primary,
                padding: const EdgeInsets.all(16),
                child: const Text(
                  'Chat History',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Expanded(
                child: ValueListenableBuilder(
                  valueListenable: _box.listenable(),
                  builder: (context, Box box, _) {
                    final chats = _getAllChats().reversed.toList();

                    if (chats.isEmpty) {
                      return const Center(
                        child: Text('No saved chats yet', style: TextStyle(color: Colors.grey)),
                      );
                    }

                    return ListView.builder(
                      itemCount: chats.length,
                      itemBuilder: (context, index) {
                        final chat = chats[index];
                        return ListTile(
                          leading: Icon(Icons.chat_bubble_outline, color: colorScheme.primary),
                          title: Text(
                            chat['title'] ?? 'Chat',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.grey),
                            onPressed: () => _deleteChat(chat['id']),
                          ),
                          onTap: () => _openChat(chat),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: _messages.length,
                itemBuilder: (context, index) {
                  final msg = _messages[index];
                  final isUser = msg['sender'] == 'user';

                  // AnimatedContainer + a fade/slide-in gives each new
                  // bubble a small pop instead of appearing instantly.
                  return Align(
                    alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                    child: TweenAnimationBuilder<double>(
                      key: ValueKey(index),
                      tween: Tween(begin: 0, end: 1),
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeOut,
                      builder: (context, value, child) {
                        return Opacity(
                          opacity: value,
                          child: Transform.translate(
                            offset: Offset(0, (1 - value) * 8),
                            child: child,
                          ),
                        );
                      },
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: isUser ? colorScheme.primary : colorScheme.secondary,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Text(
                          msg['text'] ?? '',
                          style: TextStyle(
                            // Bot bubbles are colorScheme.secondary, so
                            // their text needs onSecondary for contrast
                            // — onSurface is meant for the page background.
                            color: isUser ? Colors.white : colorScheme.onSecondary,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: SizedBox(
                  height: 16,
                  width: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            Container(
              padding: const EdgeInsets.all(10),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      decoration: InputDecoration(
                        hintText: 'Type a message...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                      ),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  CircleAvatar(
                    backgroundColor: colorScheme.primary,
                    child: IconButton(
                      icon: const Icon(Icons.send, color: Colors.white),
                      onPressed: _isLoading ? null : _sendMessage,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}