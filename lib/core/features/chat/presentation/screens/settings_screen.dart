// lib/screens/settings_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:remixicon/remixicon.dart';
import '/../core/theme/app_theme.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDarkMode = themeProvider.isDarkMode(context);

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF050505) : theme.colorScheme.background,
      appBar: AppBar(
        title: const Text('Settings'),
        elevation: 0,
        backgroundColor:
            isDark ? const Color(0xFF050505) : theme.scaffoldBackgroundColor,
      ),
      body: ListView(
        children: [
          SwitchListTile(
            secondary: const Icon(Remix.moon_clear_line),
            title: const Text('Dark mode'),
            subtitle: const Text('Toggle light / dark theme'),
            value: isDarkMode,
            onChanged: (value) {
              themeProvider.toggleTheme(value);
            },
          ),
        ],
      ),
    );
  }
}
