// lib/providers/chat_provider.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

class ChatProvider with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Uuid _uuid = Uuid();

  /// All chats where the user participates, ordered by last message time
  Stream<QuerySnapshot> getChats(String userId) {
    return _firestore
        .collection('chats')
        .where('participants', arrayContains: userId)
        .orderBy('lastMessageTime', descending: true)
        .snapshots();
  }

  /// Messages of a single chat, newest first
  Stream<QuerySnapshot> getMessages(String chatId) {
    return _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  /// Get existing chat between two users or create a new one
  Future<String> getOrCreateChat(
    String currentUserId,
    String otherUserId,
  ) async {
    final query = await _firestore
        .collection('chats')
        .where('participants', arrayContains: currentUserId)
        .get();

    for (var doc in query.docs) {
      List participants = doc['participants'];
      if (participants.contains(otherUserId)) {
        return doc.id;
      }
    }

    // Create new chat
    final chatId = _uuid.v4();
    await _firestore.collection('chats').doc(chatId).set({
      'participants': [currentUserId, otherUserId],
      'lastMessageTime': Timestamp.now(),
      'lastMessage': null,
      // per‑user unread counts, start at 0
      'unreadCounts': {currentUserId: 0, otherUserId: 0},
    });
    return chatId;
  }

  /// Send a message and increment unread count for all other participants
  Future<void> sendMessage(
    String chatId,
    String senderId,
    String text, {
    String? quotedMessageId,
  }) async {
    final chatRef = _firestore.collection('chats').doc(chatId);
    final messagesRef = chatRef.collection('messages');

    final now = Timestamp.now();

    await _firestore.runTransaction((tx) async {
      final chatSnap = await tx.get(chatRef);
      final data = chatSnap.data() as Map<String, dynamic>? ?? {};

      final List<dynamic> participants =
          (data['participants'] as List<dynamic>? ?? []);
      final Map<String, dynamic> unreadCounts =
          (data['unreadCounts'] as Map<String, dynamic>? ?? {});

      // increment unread for everyone except sender
      for (final id in participants) {
        final uid = id.toString();
        if (uid == senderId) continue;
        final current = (unreadCounts[uid] ?? 0) as int;
        unreadCounts[uid] = current + 1;
      }

      final msgRef = messagesRef.doc();
      tx.set(msgRef, {
        'text': text,
        'senderId': senderId,
        'timestamp': now,
        'editedAt': null,
        'reactions': {},
        'quotedMessageId': quotedMessageId,
      });

      tx.update(chatRef, {
        'lastMessageTime': now,
        'lastMessage': text,
        'unreadCounts': unreadCounts,
      });
    });
  }

  /// Edit message text (does not touch unread counts)
  Future<void> editMessage(
    String chatId,
    String messageId,
    String newText,
  ) async {
    await _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .doc(messageId)
        .update({'text': newText, 'editedAt': Timestamp.now()});

    // Optionally update lastMessage if this was the last sent message
    final chatRef = _firestore.collection('chats').doc(chatId);
    final lastMsgQuery = await chatRef
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .limit(1)
        .get();

    if (lastMsgQuery.docs.isNotEmpty &&
        lastMsgQuery.docs.first.id == messageId) {
      await chatRef.update({'lastMessage': newText});
    }
  }

  /// Delete message; if it was the last one, clear or update lastMessage
  Future<void> deleteMessage(String chatId, String messageId) async {
    final chatRef = _firestore.collection('chats').doc(chatId);
    final messagesRef = chatRef.collection('messages');

    await messagesRef.doc(messageId).delete();

    final remainingMessages = await messagesRef
        .orderBy('timestamp', descending: true)
        .limit(1)
        .get();

    if (remainingMessages.docs.isEmpty) {
      await chatRef.update({'lastMessage': null});
    } else {
      final last = remainingMessages.docs.first.data();
      await chatRef.update({
        'lastMessage': last['text'],
        'lastMessageTime': last['timestamp'],
      });
    }
  }

  /// Add or change a reaction from one user
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

  /// Delete whole chat document (messages subcollection stays on backend)
  Future<void> deleteChat(String chatId) async {
    await _firestore.collection('chats').doc(chatId).delete();
  }

  /// User document stream
  Stream<DocumentSnapshot> getUser(String userId) {
    return _firestore.collection('users').doc(userId).snapshots();
  }

  /// Simple username search
  Future<List<QueryDocumentSnapshot>> searchUsers(String query) async {
    final result = await _firestore
        .collection('users')
        .where('username', isGreaterThanOrEqualTo: query)
        .where('username', isLessThanOrEqualTo: '$query\uf8ff')
        .get();
    return result.docs;
  }

  /// Mark chat as read for a specific user (set unread count to 0)
  Future<void> markChatAsRead(String chatId, String userId) async {
    final chatRef = _firestore.collection('chats').doc(chatId);
    await _firestore.runTransaction((tx) async {
      final snap = await tx.get(chatRef);
      final data = snap.data() as Map<String, dynamic>? ?? {};
      final Map<String, dynamic> unreadCounts =
          (data['unreadCounts'] as Map<String, dynamic>? ?? {});
      unreadCounts[userId] = 0;
      tx.update(chatRef, {'unreadCounts': unreadCounts});
    });
  }

  /// Number of unread messages for `userId` in a chat (O(1))
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
