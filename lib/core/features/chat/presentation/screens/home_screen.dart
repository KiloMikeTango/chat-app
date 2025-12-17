// lib/screens/home_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:remixicon/remixicon.dart';
import '../../application/chat_provider.dart';
import 'chat_screen.dart';
import 'search_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String? userId;

  @override
  void initState() {
    super.initState();
    _loadUserId();
  }

  Future<void> _loadUserId() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => userId = prefs.getString('userId'));
  }

  @override
  Widget build(BuildContext context) {
    final chatProvider = Provider.of<ChatProvider>(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (userId == null) return const SizedBox.shrink();

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF050505) : theme.colorScheme.background,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: isDark ? const Color(0xFF050505) : theme.scaffoldBackgroundColor,
        title: const Text('Chats'),
        actions: [
          IconButton(
            icon: const Icon(Remix.search_line),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SearchScreen()),
            ),
          ),
          IconButton(
            icon: const Icon(Remix.more_2_fill),
            onPressed: () {},
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF050505) : theme.scaffoldBackgroundColor,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.15),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: TextField(
              readOnly: true,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SearchScreen()),
              ),
              decoration: InputDecoration(
                prefixIcon: const Icon(Remix.search_line),
                hintText: 'Search',
                filled: true,
                fillColor:
                    isDark ? const Color(0xFF111111) : theme.colorScheme.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: chatProvider.getChats(userId!),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Text('Error loading chats: ${snapshot.error}'),
                  );
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Text(
                      'No chats yet. Start a new conversation!',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.textTheme.bodyMedium?.color
                            ?.withOpacity(0.7),
                      ),
                    ),
                  );
                }
                final chats = snapshot.data!.docs;
                return ListView.separated(
                  itemCount: chats.length,
                  padding: const EdgeInsets.only(top: 8, bottom: 80),
                  separatorBuilder: (_, __) => Divider(
                    height: 1,
                    indent: 76,
                    color: theme.dividerColor.withOpacity(isDark ? 0.4 : 0.2),
                  ),
                  itemBuilder: (context, index) {
                    final chatDoc = chats[index];
                    final data = chatDoc.data() as Map<String, dynamic>;

                    final List participants = data['participants'] as List;
                    final String otherUserId = participants.firstWhere(
                      (id) => id != userId,
                    );

                    final Timestamp? lastTs =
                        data['lastMessageTime'] as Timestamp?;
                    final DateTime lastTime =
                        lastTs?.toDate() ?? DateTime.now();
                    final String lastMessage =
                        data['lastMessage'] as String? ?? 'No messages yet';

                    final Map<String, dynamic>? unreadMap =
                        data['unreadCounts'] as Map<String, dynamic>?;
                    final int unreadCount = unreadMap?[userId] is int
                        ? unreadMap![userId] as int
                        : (unreadMap?[userId] is num
                            ? (unreadMap?[userId] as num).toInt()
                            : 0);

                    return Dismissible(
                      key: Key(chatDoc.id),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        margin: const EdgeInsets.only(left: 72),
                        color: Colors.red,
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 24),
                        child: const Icon(Remix.delete_bin_6_line,
                            color: Colors.white),
                      ),
                      onDismissed: (_) {
                        chatProvider.deleteChat(chatDoc.id);
                      },
                      child: StreamBuilder<DocumentSnapshot>(
                        stream: chatProvider.getUser(otherUserId),
                        builder: (context, userSnapshot) {
                          if (!userSnapshot.hasData ||
                              !userSnapshot.data!.exists) {
                            return const SizedBox.shrink();
                          }

                          final username =
                              userSnapshot.data!['username'] as String? ??
                                  'Unknown User';

                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 6,
                            ),
                            leading: CircleAvatar(
                              radius: 24,
                              backgroundColor:
                                  theme.colorScheme.primary.withOpacity(0.15),
                              child: Text(
                                (username.isNotEmpty ? username[0] : 'U')
                                    .toUpperCase(),
                                style: TextStyle(
                                  color: theme.colorScheme.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            title: Text(
                              username,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            subtitle: Text(
                              lastMessage,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.textTheme.bodySmall?.color
                                    ?.withOpacity(0.7),
                              ),
                            ),
                            trailing: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  DateFormat('HH:mm').format(lastTime),
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.textTheme.bodySmall?.color
                                        ?.withOpacity(0.6),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                if (unreadCount > 0)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: theme.colorScheme.primary,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      unreadCount.toString(),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ChatScreen(
                                    chatId: chatDoc.id,
                                    otherUserId: otherUserId,
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: theme.colorScheme.primary,
        child: const Icon(Remix.chat_1_fill),
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const SearchScreen()),
        ),
      ),
    );
  }
}
