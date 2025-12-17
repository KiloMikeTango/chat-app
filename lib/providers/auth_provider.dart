// lib/providers/auth_provider.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthProvider with ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String? verificationId;
  String? errorMessage;

  Future<void> verifyPhone(String phone, BuildContext context) async {
    try {
      await _auth.verifyPhoneNumber(
        phoneNumber: phone,
        verificationCompleted: (PhoneAuthCredential credential) async {
          await _signInWithCredential(credential, context);
        },
        verificationFailed: (FirebaseAuthException e) {
          errorMessage = e.message;
          notifyListeners();
        },
        codeSent: (String verId, int? resendToken) {
          verificationId = verId;
          notifyListeners();
        },
        codeAutoRetrievalTimeout: (String verId) {
          verificationId = verId;
        },
      );
    } catch (e) {
      errorMessage = e.toString();
      notifyListeners();
    }
  }

  Future<void> verifyOtp(String otp, BuildContext context, String? username) async {
    try {
      if (verificationId == null) return;
      PhoneAuthCredential credential = PhoneAuthProvider.credential(
        verificationId: verificationId!,
        smsCode: otp,
      );
      await _signInWithCredential(credential, context, username: username);
    } catch (e) {
      errorMessage = e.toString();
      notifyListeners();
    }
  }

  Future<void> _signInWithCredential(PhoneAuthCredential credential, BuildContext context, {String? username}) async {
    UserCredential userCredential = await _auth.signInWithCredential(credential);
    String userId = userCredential.user!.uid;

    // Check if user exists
    DocumentSnapshot userDoc = await _firestore.collection('users').doc(userId).get();
    if (!userDoc.exists && username != null && username.isNotEmpty) {
      await _firestore.collection('users').doc(userId).set({
        'phone': userCredential.user!.phoneNumber,
        'username': username,
        'createdAt': Timestamp.now(),
      });
    } else if (!userDoc.exists) {
      // Handle error if username not provided for new user
      errorMessage = 'Username is required for new accounts.';
      notifyListeners();
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('userId', userId);
    Navigator.pushReplacementNamed(context, '/home');
  }

  Future<void> logout(BuildContext context) async {
    await _auth.signOut();
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    notifyListeners();
    Navigator.pushReplacementNamed(context, '/auth');
  }

  Future<void> updateUsername(String userId, String newUsername) async {
    await _firestore.collection('users').doc(userId).update({'username': newUsername});
    notifyListeners();
  }
}