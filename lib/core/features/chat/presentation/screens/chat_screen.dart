// lib/screens/chat_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:remixicon/remixicon.dart';
import '../../application/chat_provider.dart';

class ChatScreen extends StatefulWidget {
  final String chatId;
  final String otherUserId;

  const ChatScreen({
    required this.chatId,
    required this.otherUserId,
    super.key,
  });

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
  String? _quotedSenderId;

  final List<String> _reactions = ['😂', '❤️', '👍', '👌', '👏', '😢', '😔'];

  ChatProvider? _chatProvider;

  // NEW: ensure markChatAsRead runs only once per open
  bool _hasMarkedRead = false;

  @override
  void initState() {
    super.initState();
    _loadUserId();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _chatProvider ??= Provider.of<ChatProvider>(context, listen: false);
    _loadOtherUser();
  }

  Future<void> _loadUserId() async {
    final prefs = await SharedPreferences.getInstance();
    final loadedId = prefs.getString('userId');
    if (!mounted) return;
    setState(() => userId = loadedId);
  }

  Future<void> _loadOtherUser() async {
    if (_chatProvider == null) return;
    final userDoc = await _chatProvider!.getUser(widget.otherUserId).first;
    if (userDoc.exists && mounted) {
      setState(() => otherUsername = userDoc['username']);
    }
  }

  void _sendOrEditMessage() {
    if (_chatProvider == null || userId == null) return;
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    if (_editingMessageId != null) {
      _chatProvider!.editMessage(widget.chatId, _editingMessageId!, text);
      setState(() => _editingMessageId = null);
    } else {
      _chatProvider!.sendMessage(
        widget.chatId,
        userId!,
        text,
        participants: [userId!, widget.otherUserId],
        quotedMessageId: _quotedMessageId,
      );
    }

    setState(() {
      _quotedMessageId = null;
      _quotedText = null;
      _quotedSenderId = null;
    });

    _messageController.clear();
    _scrollToBottom();
  }

  void _startEditing(String messageId, String currentText) {
    setState(() {
      _editingMessageId = messageId;
      _messageController.text = currentText;
      _quotedMessageId = null;
      _quotedText = null;
      _quotedSenderId = null;
    });
  }

  void _setQuoted({
    required String messageId,
    required String text,
    required String senderId,
  }) {
    setState(() {
      _quotedMessageId = messageId;
      _quotedText = text;
      _quotedSenderId = senderId;
      _editingMessageId = null;
    });
  }

  void _clearReplyAndEdit() {
    setState(() {
      _quotedMessageId = null;
      _quotedText = null;
      _quotedSenderId = null;
      _editingMessageId = null;
    });
  }

  void _showReactions(String messageId) {
    if (_chatProvider == null || userId == null) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 12.0),
        child: Wrap(
          alignment: WrapAlignment.center,
          children: _reactions
              .map(
                (reaction) => IconButton(
                  icon: Text(reaction, style: const TextStyle(fontSize: 26)),
                  onPressed: () {
                    _chatProvider!.addReaction(
                      widget.chatId,
                      messageId,
                      userId!,
                      reaction,
                    );
                    Navigator.pop(context);
                  },
                ),
              )
              .toList(),
        ),
      ),
    );
  }

  Widget _buildQuotedMessage(Map<String, dynamic>? quotedData) {
    if (quotedData == null) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final quotedText = quotedData['text'] as String? ?? '';
    final quotedSenderId = quotedData['senderId'] as String?;
    final isMe = quotedSenderId == userId;
    final title = isMe ? 'You' : otherUsername ?? 'User';

    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isDark
            ? const Color.fromARGB(255, 36, 36, 36)
            : const Color.fromARGB(255, 184, 222, 255),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: theme.colorScheme.primary.withOpacity(isDark ? 0.6 : 0.8),
          width: 1.2,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 3,
            margin: const EdgeInsets.only(right: 8, top: 2, bottom: 2),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  quotedText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.textTheme.bodySmall?.color?.withOpacity(0.9),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReactionBubble(Map<String, dynamic> reactions, bool isMe) {
    if (reactions.isEmpty) return const SizedBox.shrink();
    final reactionCounts = <String, int>{};
    reactions.forEach((user, reaction) {
      reactionCounts[reaction] = (reactionCounts[reaction] ?? 0) + 1;
    });
    return Positioned(
      bottom: -4,
      right: isMe ? 12 : null,
      left: isMe ? null : 12,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.5),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Wrap(
          spacing: 4,
          children: reactionCounts.entries
              .map(
                (e) => Text(
                  '${e.key}${e.value > 1 ? e.value.toString() : ''}',
                  style: const TextStyle(fontSize: 11, color: Colors.white),
                ),
              )
              .toList(),
        ),
      ),
    );
  }

  void _scrollToBottom() {
    if (!mounted) return;
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (userId == null || otherUsername == null || _chatProvider == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF050505)
          : theme.colorScheme.background,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: isDark
            ? const Color(0xFF050505)
            : theme.scaffoldBackgroundColor,
        titleSpacing: 0,
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: theme.colorScheme.primary.withOpacity(0.15),
              child: Text(
                otherUsername![0].toUpperCase(),
                style: TextStyle(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              otherUsername!,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(icon: const Icon(Remix.phone_line), onPressed: () {}),
          IconButton(icon: const Icon(Remix.video_line), onPressed: () {}),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Container(
              color: isDark
                  ? const Color(0xFF050505)
                  : theme.colorScheme.background,
              child: StreamBuilder<QuerySnapshot>(
                stream: _chatProvider!.getMessages(widget.chatId),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final messages = snapshot.data!.docs;

                  // Mark as read ONCE per open when there are messages.
                  if (userId != null &&
                      messages.isNotEmpty &&
                      !_hasMarkedRead) {
                    final hasMessageFromOthers = messages.any(
                      (m) =>
                          (m.data() as Map<String, dynamic>)['senderId'] !=
                          userId,
                    );

                    if (hasMessageFromOthers) {
                      WidgetsBinding.instance.addPostFrameCallback((_) async {
                        if (!mounted || _chatProvider == null) return;
                        await _chatProvider!.markChatAsRead(
                          widget.chatId,
                          userId!,
                        );
                        if (!mounted) return;
                        setState(() {
                          _hasMarkedRead = true;
                        });
                      });
                    }
                  }

                  WidgetsBinding.instance.addPostFrameCallback(
                    (_) => _scrollToBottom(),
                  );

                  return ListView.builder(
                    controller: _scrollController,
                    reverse: true,
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      final doc = messages[index];
                      final data = doc.data() as Map<String, dynamic>;
                      final isMe = data['senderId'] == userId;
                      final timestamp = (data['timestamp'] as Timestamp)
                          .toDate();
                      final editedAt = data['editedAt'] as Timestamp?;
                      final reactions =
                          data['reactions'] as Map<String, dynamic>? ?? {};
                      final quotedId = data['quotedMessageId'] as String?;
                      Widget? quotedWidget;

                      if (quotedId != null) {
                        QueryDocumentSnapshot? quotedDoc;
                        for (final m in messages) {
                          if (m.id == quotedId) {
                            quotedDoc = m;
                            break;
                          }
                        }
                        if (quotedDoc != null) {
                          quotedWidget = _buildQuotedMessage(
                            quotedDoc.data() as Map<String, dynamic>?,
                          );
                        }
                      }

                      final bubbleColor = theme.cardColor;
                      final textColor = isDark
                          ? Colors.white
                          : theme.textTheme.bodyMedium?.color;

                      return Dismissible(
                        key: Key(doc.id),
                        direction: isMe
                            ? DismissDirection.horizontal
                            : DismissDirection.startToEnd,
                        confirmDismiss: (direction) async {
                          if (direction == DismissDirection.endToStart &&
                              isMe) {
                            _chatProvider!.deleteMessage(widget.chatId, doc.id);
                            return true;
                          }

                          if (direction == DismissDirection.startToEnd) {
                            _setQuoted(
                              messageId: doc.id,
                              text: data['text'],
                              senderId: data['senderId'],
                            );
                            return false;
                          }

                          return false;
                        },
                        background: Align(
                          alignment: Alignment.centerLeft,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12.0,
                            ),
                            child: Icon(
                              Remix.reply_line,
                              color: theme.colorScheme.primary.withOpacity(0.8),
                            ),
                          ),
                        ),
                        secondaryBackground: isMe
                            ? Align(
                                alignment: Alignment.centerRight,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12.0,
                                  ),
                                  child: Icon(
                                    Remix.delete_bin_6_line,
                                    color: Colors.red.withOpacity(0.8),
                                  ),
                                ),
                              )
                            : const SizedBox.shrink(),
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
                              Row(
                                mainAxisAlignment: isMe
                                    ? MainAxisAlignment.end
                                    : MainAxisAlignment.start,
                                children: [
                                  IntrinsicWidth(
                                    child: ConstrainedBox(
                                      constraints: BoxConstraints(
                                        minWidth: 80,
                                        maxWidth:
                                            MediaQuery.of(context).size.width *
                                            0.78,
                                      ),
                                      child: Container(
                                        margin: const EdgeInsets.symmetric(
                                          vertical: 4,
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 14,
                                          vertical: 10,
                                        ),
                                        decoration: BoxDecoration(
                                          color: bubbleColor,
                                          borderRadius: BorderRadius.only(
                                            topLeft: Radius.circular(
                                              isMe ? 16 : 4,
                                            ),
                                            topRight: Radius.circular(
                                              isMe ? 4 : 16,
                                            ),
                                            bottomLeft: const Radius.circular(
                                              16,
                                            ),
                                            bottomRight: const Radius.circular(
                                              16,
                                            ),
                                          ),
                                        ),
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            if (quotedWidget != null)
                                              quotedWidget,
                                            Text(
                                              data['text'],
                                              style: theme.textTheme.bodyMedium
                                                  ?.copyWith(color: textColor),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              '${DateFormat('h:mm a').format(timestamp)}${editedAt != null ? ' · edited' : ''}',
                                              style: theme.textTheme.bodySmall
                                                  ?.copyWith(
                                                    fontSize: 11,
                                                    color:
                                                        (isDark
                                                                ? Colors.white70
                                                                : theme
                                                                      .textTheme
                                                                      .bodySmall
                                                                      ?.color)
                                                            ?.withOpacity(0.7),
                                                  ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
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
          ),
          if (_quotedMessageId != null || _editingMessageId != null)
            _ReplyEditBar(
              isEditing: _editingMessageId != null,
              quotedText: _quotedText,
              isReplyingToMe: _quotedSenderId == userId,
              otherUsername: otherUsername,
              onClear: _clearReplyAndEdit,
            ),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 12.0,
              vertical: 10.0,
            ),
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFF111111)
                  : theme.scaffoldBackgroundColor,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.15),
                  blurRadius: 12,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: SafeArea(
              top: false,
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Remix.add_circle_line),
                    onPressed: () {},
                  ),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF1B1B1D)
                            : theme.colorScheme.surface,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: TextField(
                        controller: _messageController,
                        minLines: 1,
                        maxLines: 5,
                        decoration: const InputDecoration(
                          hintText: 'Type a message...',
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                        ),
                        onSubmitted: (_) => _sendOrEditMessage(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: theme.colorScheme.primary,
                    child: IconButton(
                      icon: const Icon(
                        Remix.send_plane_2_fill,
                        color: Colors.white,
                      ),
                      onPressed: _sendOrEditMessage,
                    ),
                  ),
                ],
              ),
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

class _ReplyEditBar extends StatelessWidget {
  final bool isEditing;
  final String? quotedText;
  final bool isReplyingToMe;
  final String? otherUsername;
  final VoidCallback onClear;

  const _ReplyEditBar({
    required this.isEditing,
    required this.quotedText,
    required this.isReplyingToMe,
    required this.otherUsername,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final label = isEditing
        ? 'Editing'
        : isReplyingToMe
        ? 'Replying to Yourself'
        : 'Replying to ${otherUsername ?? 'user'}';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withOpacity(
          theme.brightness == Brightness.dark ? 0.9 : 1,
        ),
        border: Border(
          top: BorderSide(color: theme.dividerColor.withOpacity(0.2)),
        ),
      ),
      child: Row(
        children: [
          Icon(
            isEditing ? Remix.edit_2_line : Remix.reply_line,
            size: 18,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (!isEditing && quotedText != null)
                  Text(
                    quotedText!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.textTheme.bodySmall?.color?.withOpacity(0.7),
                    ),
                  ),
              ],
            ),
          ),
          IconButton(icon: const Icon(Remix.close_line), onPressed: onClear),
        ],
      ),
    );
  }
}
