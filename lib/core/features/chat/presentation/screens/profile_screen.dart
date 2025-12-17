// lib/screens/profile_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:remixicon/remixicon.dart';
import '../../../../../providers/auth_provider.dart';
import '../../application/chat_provider.dart';
import 'settings_screen.dart';

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
    if (_usernameController.text.isNotEmpty &&
        _usernameController.text != currentUsername) {
      await Provider.of<AuthProvider>(
        context,
        listen: false,
      ).updateUsername(userId!, _usernameController.text);
      setState(() {
        currentUsername = _usernameController.text;
        _isEditing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (userId == null || currentUsername == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF050505)
          : theme.colorScheme.background,
      appBar: AppBar(
        title: const Text('Profile'),
        elevation: 0,
        backgroundColor: isDark
            ? const Color(0xFF050505)
            : theme.scaffoldBackgroundColor,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Center(
            child: Stack(
              children: [
                CircleAvatar(
                  radius: 56,
                  backgroundColor: theme.colorScheme.primary.withOpacity(0.15),
                  child: Text(
                    currentUsername![0].toUpperCase(),
                    style: TextStyle(
                      fontSize: 40,
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Positioned(
                  bottom: 4,
                  right: 4,
                  child: GestureDetector(
                    onTap: () {
                      // Add photo picker logic here
                    },
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Remix.camera_line,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Display name',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: theme.textTheme.labelLarge?.color?.withOpacity(
                        0.8,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _usernameController,
                          enabled: _isEditing,
                          decoration: InputDecoration(
                            hintText: 'Enter new name',
                            prefixIcon: const Icon(Remix.user_3_line),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (!_isEditing) ...[
                        IconButton(
                          icon: const Icon(Remix.edit_2_line),
                          onPressed: () => setState(() => _isEditing = true),
                        ),
                      ] else ...[
                        IconButton(
                          icon: const Icon(
                            Remix.check_line,
                            color: Colors.green,
                          ),
                          onPressed: _updateUsername,
                        ),
                        IconButton(
                          icon: const Icon(Remix.close_line),
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
          const SizedBox(height: 24),
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Remix.settings_3_line),
                  title: const Text('Settings'),
                  trailing: const Icon(Remix.arrow_right_s_line),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const SettingsScreen()),
                    );
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(
                    Remix.logout_box_r_line,
                    color: Colors.red,
                  ),
                  title: const Text(
                    'Logout',
                    style: TextStyle(color: Colors.red),
                  ),
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
