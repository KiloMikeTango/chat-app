// lib/providers/chat_provider.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

class ChatProvider with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Uuid _uuid = Uuid();

  Stream<QuerySnapshot> getChats(String userId) {
    return _firestore.collection('chats')
        .where('participants', arrayContains: userId)
        .orderBy('lastMessageTime', descending: true)
        .snapshots();
  }

  Stream<QuerySnapshot> getMessages(String chatId) {
    return _firestore.collection('chats').doc(chatId).collection('messages')
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  Future<String> getOrCreateChat(String currentUserId, String otherUserId) async {
    final query = await _firestore.collection('chats')
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
      'lastMessage': null,  // Explicitly set to null for new chats
    });
    return chatId;
  }

  Future<void> sendMessage(String chatId, String senderId, String text, {String? quotedMessageId}) async {
    final messageData = {
      'text': text,
      'senderId': senderId,
      'timestamp': Timestamp.now(),
      'editedAt': null,
      'reactions': {},
      'quotedMessageId': quotedMessageId,
    };
    await _firestore.collection('chats').doc(chatId).collection('messages').add(messageData);
    await _firestore.collection('chats').doc(chatId).update({
      'lastMessageTime': Timestamp.now(),
      'lastMessage': text,
    });
  }

  Future<void> editMessage(String chatId, String messageId, String newText) async {
    await _firestore.collection('chats').doc(chatId).collection('messages').doc(messageId).update({
      'text': newText,
      'editedAt': Timestamp.now(),
    });
    // Update lastMessage to edited one
    await _firestore.collection('chats').doc(chatId).update({
      'lastMessage': newText,
    });
  }

  Future<void> deleteMessage(String chatId, String messageId) async {
    // Get the message before delete to check if it's the last one
    final messageDoc = await _firestore.collection('chats').doc(chatId).collection('messages').doc(messageId).get();
    await _firestore.collection('chats').doc(chatId).collection('messages').doc(messageId).delete();
    // If it was the last message, set lastMessage to null
    final remainingMessages = await _firestore.collection('chats').doc(chatId).collection('messages').get();
    if (remainingMessages.docs.isEmpty) {
      await _firestore.collection('chats').doc(chatId).update({
        'lastMessage': null,
      });
    }
  }

  Future<void> addReaction(String chatId, String messageId, String userId, String reaction) async {
    // Set the reaction for the user (overrides previous, one per user)
    await _firestore.collection('chats').doc(chatId).collection('messages').doc(messageId).update({
      'reactions.$userId': reaction,
    });
  }

  Future<void> deleteChat(String chatId) async {
    await _firestore.collection('chats').doc(chatId).delete();
    // Note: Subcollections remain, but for UI, it's fine
  }

  Stream<DocumentSnapshot> getUser(String userId) {
    return _firestore.collection('users').doc(userId).snapshots();
  }

  Future<List<QueryDocumentSnapshot>> searchUsers(String query) async {
    final result = await _firestore.collection('users')
        .where('username', isGreaterThanOrEqualTo: query)
        .where('username', isLessThanOrEqualTo: query + '\uf8ff')
        .get();
    return result.docs;
  }
}