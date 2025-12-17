// lib/screens/profile_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/auth_provider.dart';
import '../providers/chat_provider.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String? userId;
  String? currentUsername;
  final _usernameController = TextEditingController();
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => userId = prefs.getString('userId'));
    if (userId != null) {
      final chatProvider = Provider.of<ChatProvider>(context, listen: false);
      final userDoc = await chatProvider.getUser(userId!).first;
      if (userDoc.exists) {
        setState(() {
          currentUsername = userDoc['username'];
          _usernameController.text = currentUsername ?? '';
        });
      }
    }
  }

  Future<void> _updateUsername() async {
    if (_usernameController.text.isNotEmpty && _usernameController.text != currentUsername) {
      await Provider.of<AuthProvider>(context, listen: false).updateUsername(userId!, _usernameController.text);
      setState(() {
        currentUsername = _usernameController.text;
        _isEditing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);

    if (userId == null || currentUsername == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Profile Avatar (placeholder)
          Center(
            child: Stack(
              children: [
                CircleAvatar(
                  radius: 60,
                  backgroundColor: Colors.blue.shade100,
                  child: Text(currentUsername![0], style: const TextStyle(fontSize: 50, color: Colors.blue)),
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: GestureDetector(
                    onTap: () {
                      // Add photo picker logic here
                    },
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(color: Colors.blue, shape: BoxShape.circle),
                      child: const Icon(Icons.camera_alt, color: Colors.white, size: 20),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          // Username Edit
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Text('Name', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _usernameController,
                          enabled: _isEditing,
                          decoration: InputDecoration(
                            border: const OutlineInputBorder(),
                            hintText: 'Enter new name',
                          ),
                        ),
                      ),
                      if (!_isEditing) ...[
                        IconButton(
                          icon: const Icon(Icons.edit),
                          onPressed: () => setState(() => _isEditing = true),
                        ),
                      ] else ...[
                        IconButton(
                          icon: const Icon(Icons.save),
                          onPressed: _updateUsername,
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () {
                            setState(() {
                              _isEditing = false;
                              _usernameController.text = currentUsername ?? '';
                            });
                          },
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          // Settings Options
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.privacy_tip),
                  title: const Text('Privacy'),
                  trailing: const Icon(Icons.arrow_forward_ios),
                  onTap: () {
                    // Add privacy settings
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.notifications),
                  title: const Text('Notifications'),
                  trailing: const Icon(Icons.arrow_forward_ios),
                  onTap: () {
                    // Add notification settings
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.logout, color: Colors.red),
                  title: const Text('Logout', style: TextStyle(color: Colors.red)),
                  onTap: () async {
                    await authProvider.logout(context);
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}