// lib/providers/auth_provider.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/features/chat/presentation/screens/auth_screen.dart';
import '../main.dart'; // for BottomNavWrapper

class AuthProvider with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String? errorMessage;
  bool _isLoading = false;

  bool get isLoading => _isLoading;

  Future<void> loginWithKey(
    String accessKey,
    BuildContext context,
  ) async {
    if (accessKey.trim().isEmpty) {
      errorMessage = 'Please enter your access key.';
      notifyListeners();
      return;
    }

    _isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      final query = await _firestore
          .collection('users')
          .where('access_key', isEqualTo: accessKey.trim())
          .limit(1)
          .get();

      if (query.docs.isEmpty) {
        errorMessage = 'Invalid key. Please check and try again.';
        _isLoading = false;
        notifyListeners();
        return;
      }

      final doc = query.docs.first;
      final userId = doc.id;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('userId', userId);

      _isLoading = false;
      notifyListeners();

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const BottomNavWrapper()),
        (route) => false,
      );
    } catch (e) {
      errorMessage = 'Something went wrong. Please try again.';
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> logout(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    notifyListeners();

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const AuthScreen()),
      (route) => false,
    );
  }

  Future<void> updateUsername(String userId, String newUsername) async {
    await _firestore.collection('users').doc(userId).update({
      'username': newUsername,
    });
    notifyListeners();
  }
}
