// lib/screens/chat_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/chat_provider.dart';

class ChatScreen extends StatefulWidget {
  final String chatId;
  final String otherUserId;

  const ChatScreen({required this.chatId, required this.otherUserId, super.key});

  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  String? userId;
  String? otherUsername;
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  String? _quotedMessageId;
  String? _editingMessageId;
  String? _quotedText;

  final List<String> _reactions = ['😂', '❤️', '👍', '👌', '👏', '😢', '😔'];

  @override
  void initState() {
    super.initState();
    _loadUserId();
    _loadOtherUser();
  }

  Future<void> _loadUserId() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => userId = prefs.getString('userId'));
  }

  Future<void> _loadOtherUser() async {
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    final userDoc = await chatProvider.getUser(widget.otherUserId).first;
    if (userDoc.exists) {
      setState(() => otherUsername = userDoc['username']);
    }
  }

  void _sendOrEditMessage(ChatProvider chatProvider) {
    if (_messageController.text.trim().isNotEmpty) {
      if (_editingMessageId != null) {
        chatProvider.editMessage(widget.chatId, _editingMessageId!, _messageController.text.trim());
        setState(() => _editingMessageId = null);
      } else {
        chatProvider.sendMessage(widget.chatId, userId!, _messageController.text.trim(), quotedMessageId: _quotedMessageId);
        setState(() {
          _quotedMessageId = null;
          _quotedText = null;
        });
      }
      _messageController.clear();
      _scrollToBottom();
    }
  }

  void _startEditing(String messageId, String currentText) {
    setState(() {
      _editingMessageId = messageId;
      _messageController.text = currentText;
    });
  }

  void _showReactions(String messageId) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Wrap(
        children: _reactions.map((reaction) => IconButton(
          icon: Text(reaction, style: const TextStyle(fontSize: 24)),
          onPressed: () {
            Provider.of<ChatProvider>(context, listen: false).addReaction(widget.chatId, messageId, userId!, reaction);
            Navigator.pop(context);
          },
        )).toList(),
      ),
    );
  }

  Widget _buildQuotedMessage(Map<String, dynamic>? quotedData) {
    if (quotedData == null) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(8),
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        color: Colors.grey[300],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(quotedData['text'] ?? '', style: const TextStyle(color: Colors.black54)),
    );
  }

  Widget _buildReactionBubble(Map<String, dynamic> reactions, bool isMe) {
    if (reactions.isEmpty) return const SizedBox.shrink();
    final reactionCounts = <String, int>{};
    reactions.forEach((user, reaction) {
      reactionCounts[reaction] = (reactionCounts[reaction] ?? 0) + 1;
    });
    return Positioned(
      bottom: 0,
      right: isMe ? 0 : null,
      left: isMe ? null : 0,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.9),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.3), blurRadius: 2)],
        ),
        child: Wrap(
          spacing: 2,
          children: reactionCounts.entries.map((e) => Text('${e.key}${e.value > 1 ? e.value.toString() : ''}', style: const TextStyle(fontSize: 12))).toList(),
        ),
      ),
    );
  }

  void _scrollToBottom() {
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  void _setQuoted(String messageId, String text) {
    setState(() {
      _quotedMessageId = messageId;
      _quotedText = text;
    });
  }

  @override
  Widget build(BuildContext context) {
    final chatProvider = Provider.of<ChatProvider>(context);

    if (userId == null || otherUsername == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(otherUsername!),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              // Handle forward, etc.
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'React', child: Text('React')),
              const PopupMenuItem(value: 'Reply', child: Text('Reply')),
              const PopupMenuItem(value: 'Forward', child: Text('Forward')),
              const PopupMenuItem(value: 'Delete', child: Text('Delete')),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          if (_quotedMessageId != null || _editingMessageId != null)
            Container(
              color: Colors.grey[200],
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_editingMessageId != null ? 'Editing message' : 'Replying to message'),
                      if (_quotedText != null) Text(_quotedText!, maxLines: 1, overflow: TextOverflow.ellipsis),
                    ],
                  )),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => setState(() {
                      _quotedMessageId = null;
                      _quotedText = null;
                      _editingMessageId = null;
                      _messageController.clear();
                    }),
                  ),
                ],
              ),
            ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: chatProvider.getMessages(widget.chatId),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final messages = snapshot.data!.docs;
                WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
                return ListView.builder(
                  controller: _scrollController,
                  reverse: true,
                  padding: const EdgeInsets.all(8),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final doc = messages[index];
                    final data = doc.data() as Map<String, dynamic>;
                    final isMe = data['senderId'] == userId;
                    final timestamp = (data['timestamp'] as Timestamp).toDate();
                    final editedAt = data['editedAt'] as Timestamp?;
                    final reactions = data['reactions'] as Map<String, dynamic>? ?? {};
                    final quotedId = data['quotedMessageId'] as String?;
                    Widget? quotedWidget;
                    if (quotedId != null) {
                      final quotedDoc = messages.firstWhere((m) => m.id == quotedId, orElse: () => doc);
                      quotedWidget = _buildQuotedMessage(quotedDoc.data() as Map<String, dynamic>?);
                    }
                    return Dismissible(
                      key: Key(doc.id),
                      direction: isMe ? DismissDirection.endToStart : DismissDirection.startToEnd,
                      onDismissed: (_) {
                        if (isMe) {
                          chatProvider.deleteMessage(widget.chatId, doc.id);
                        } else {
                          _setQuoted(doc.id, data['text']);
                        }
                      },
                      background: Container(
                        color: isMe ? Colors.red : Colors.green,
                        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                        child: Icon(isMe ? Icons.delete : Icons.reply, color: Colors.white),
                      ),
                      child: GestureDetector(
                        onLongPress: () {
                          if (isMe) {
                            _startEditing(doc.id, data['text']);
                          } else {
                            _showReactions(doc.id);
                          }
                        },
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Align(
                              alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                              child: Container(
                                margin: const EdgeInsets.symmetric(vertical: 4),
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                decoration: BoxDecoration(
                                  color: isMe ? Colors.blue : Colors.grey[200],
                                  borderRadius: BorderRadius.only(
                                    topLeft: Radius.circular(isMe ? 20 : 0),
                                    topRight: Radius.circular(isMe ? 0 : 20),
                                    bottomLeft: const Radius.circular(20),
                                    bottomRight: const Radius.circular(20),
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (quotedWidget != null) quotedWidget,
                                    Text(
                                      data['text'],
                                      style: TextStyle(color: isMe ? Colors.white : Colors.black),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${DateFormat('HH:mm').format(timestamp)}${editedAt != null ? ' (edited)' : ''}',
                                      style: TextStyle(fontSize: 10, color: isMe ? Colors.white70 : Colors.black54),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            _buildReactionBubble(reactions, isMe),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.2), blurRadius: 10, offset: const Offset(0, -5))],
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: InputDecoration(
                      hintText: 'Type a message...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Colors.grey[100],
                    ),
                    onSubmitted: (_) => _sendOrEditMessage(chatProvider),
                  ),
                ),
                const SizedBox(width: 8),
                FloatingActionButton(
                  mini: true,
                  backgroundColor: Colors.blue,
                  onPressed: () => _sendOrEditMessage(chatProvider),
                  child: const Icon(Icons.send, color: Colors.white),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}