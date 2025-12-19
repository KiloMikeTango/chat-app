// lib/providers/chat_provider.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

class ChatProvider with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Uuid _uuid = Uuid();

  /// All chats where the user participates, ordered by last message time.
  Stream<QuerySnapshot> getChats(String userId) {
    return _firestore
        .collection('chats')
        .where('participants', arrayContains: userId)
        .orderBy('lastMessageTime', descending: true)
        .snapshots();
  }

  /// Messages of a single chat, newest first.
  Stream<QuerySnapshot> getMessages(String chatId) {
    return _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  /// Build a deterministic chatId from two userIds (sorted).
  /// This does NOT create any document.
  String buildChatId(String userA, String userB) {
    final List<String> ids = [userA, userB]..sort();
    return '${ids[0]}_${ids[1]}';
  }

  /// Legacy helper: get existing chat or create a new one.
  /// Prefer [buildChatId] + lazy creation on first message.
  Future<String> getOrCreateChat(
    String currentUserId,
    String otherUserId,
  ) async {
    final query = await _firestore
        .collection('chats')
        .where('participants', arrayContains: currentUserId)
        .get();

    for (var doc in query.docs) {
      final List participants = doc['participants'];
      if (participants.contains(otherUserId)) {
        return doc.id;
      }
    }

    final chatId = _uuid.v4();
    await _firestore.collection('chats').doc(chatId).set({
      'participants': [currentUserId, otherUserId],
      'lastMessageTime': null,
      'lastMessage': null,
      'lastMessageSenderId': null,
      'unreadCounts': {currentUserId: 0, otherUserId: 0},
    });
    return chatId;
  }

  /// Send a message and increment unread count for all other participants.
  /// If the chat document does not exist yet, it will be created.
  Future<void> sendMessage(
    String chatId,
    String senderId,
    String text, {
    required List<String> participants,
    String? quotedMessageId,
  }) async {
    final chatRef = _firestore.collection('chats').doc(chatId);
    final messagesRef = chatRef.collection('messages');
    final now = Timestamp.now();

    await _firestore.runTransaction((tx) async {
      final chatSnap = await tx.get(chatRef);
      final data = chatSnap.data() as Map<String, dynamic>? ?? {};

      // Prefer stored participants/unreadCounts if chat already exists.
      final List<dynamic> storedParticipants =
          (data['participants'] as List<dynamic>? ?? participants);
      final Map<String, dynamic> unreadCounts =
          (data['unreadCounts'] as Map<String, dynamic>? ?? {});

      // Ensure all participants have an entry in unreadCounts.
      for (final id in storedParticipants) {
        final uid = id.toString();
        unreadCounts.putIfAbsent(uid, () => 0);
      }

      // Increment unread for everyone except sender.
      for (final id in storedParticipants) {
        final uid = id.toString();
        if (uid == senderId) continue;
        final current = (unreadCounts[uid] ?? 0) as int;
        unreadCounts[uid] = current + 1;
      }

      // Create message document.
      final msgRef = messagesRef.doc();
      tx.set(msgRef, {
        'text': text,
        'senderId': senderId,
        'timestamp': now,
        'editedAt': null,
        'reactions': {},
        'quotedMessageId': quotedMessageId,
      });

      // Update chat meta.
      tx.set(
        chatRef,
        {
          'participants': storedParticipants,
          'lastMessageTime': now,
          'lastMessage': text,
          'lastMessageSenderId': senderId,
          'unreadCounts': unreadCounts,
        },
        SetOptions(merge: true),
      );
    });
  }

  Future<void> editMessage(
    String chatId,
    String messageId,
    String newText,
  ) async {
    final chatRef = _firestore.collection('chats').doc(chatId);
    final msgRef = chatRef.collection('messages').doc(messageId);

    await msgRef.update({'text': newText, 'editedAt': Timestamp.now()});

    final lastMsgQuery = await chatRef
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .limit(1)
        .get();

    if (lastMsgQuery.docs.isNotEmpty &&
        lastMsgQuery.docs.first.id == messageId) {
      final docData =
          lastMsgQuery.docs.first.data() as Map<String, dynamic>;
      await chatRef.update({
        'lastMessage': newText,
        'lastMessageSenderId': docData['senderId'],
      });
    }
  }

  Future<void> deleteMessage(String chatId, String messageId) async {
    final chatRef = _firestore.collection('chats').doc(chatId);
    final messagesRef = chatRef.collection('messages');

    await messagesRef.doc(messageId).delete();

    final remainingMessages = await messagesRef
        .orderBy('timestamp', descending: true)
        .limit(1)
        .get();

    if (remainingMessages.docs.isEmpty) {
      await chatRef.update({
        'lastMessage': null,
        'lastMessageTime': null,
        'lastMessageSenderId': null,
      });
    } else {
      final last =
          remainingMessages.docs.first.data() as Map<String, dynamic>;
      await chatRef.update({
        'lastMessage': last['text'],
        'lastMessageTime': last['timestamp'],
        'lastMessageSenderId': last['senderId'],
      });
    }
  }

  Future<void> addReaction(
    String chatId,
    String messageId,
    String userId,
    String reaction,
  ) async {
    await _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .doc(messageId)
        .update({'reactions.$userId': reaction});
  }

  Future<void> deleteChat(String chatId) async {
    final chatRef = _firestore.collection('chats').doc(chatId);
    final messagesRef = chatRef.collection('messages');

    // Delete all messages in this chat.
    final messagesSnap = await messagesRef.get();
    for (final doc in messagesSnap.docs) {
      await doc.reference.delete();
    }

    // Now delete the chat document itself.
    await chatRef.delete();
  }

  Stream<DocumentSnapshot> getUser(String userId) {
    return _firestore.collection('users').doc(userId).snapshots();
  }

  Future<List<QueryDocumentSnapshot>> searchUsers(String query) async {
    final result = await _firestore
        .collection('users')
        .where('username', isGreaterThanOrEqualTo: query)
        .where('username', isLessThanOrEqualTo: '$query\uf8ff')
        .get();
    return result.docs;
  }

  /// Mark chat as read for one user.
  /// Only that user's entry in unreadCounts is set to 0.
  Future<void> markChatAsRead(String chatId, String userId) async {
    final chatRef = _firestore.collection('chats').doc(chatId);
    await chatRef.update({
      'unreadCounts.$userId': 0,
    });
  }

  /// Get unread count for one user in one chat.
  Future<int> getUnreadCount(String chatId, String userId) async {
    final chatSnap = await _firestore.collection('chats').doc(chatId).get();
    final data = chatSnap.data() as Map<String, dynamic>?;

    if (data == null) return 0;
    final Map<String, dynamic>? unreadCounts =
        data['unreadCounts'] as Map<String, dynamic>?;
    if (unreadCounts == null) return 0;

    final value = unreadCounts[userId];
    if (value is int) return value;
    if (value is num) return value.toInt();
    return 0;
  }
}
