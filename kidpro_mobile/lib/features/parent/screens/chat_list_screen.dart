import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:kidpro_mobile/core/constants/app_colors.dart';
import 'package:kidpro_mobile/features/parent/providers/parent_provider.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ParentProvider>().loadChatThreads();
    });
  }

  @override
  Widget build(BuildContext context) {
    final parentProv = context.watch<ParentProvider>();
    final timeFormat = DateFormat('HH:mm');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tin nhắn với Giáo viên'),
      ),
      body: parentProv.loading
          ? const Center(child: CircularProgressIndicator())
          : parentProv.chatThreads.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey.shade400),
                      const SizedBox(height: 16),
                      Text(
                        'Chưa có cuộc trò chuyện nào',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.grey),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: () => parentProv.loadChatThreads(),
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: parentProv.chatThreads.length,
                    separatorBuilder: (_, __) => const Divider(height: 1, indent: 72),
                    itemBuilder: (context, index) {
                      final thread = parentProv.chatThreads[index];
                      return ListTile(
                        onTap: () => context.go('/parent/chat/${thread.id}'),
                        leading: CircleAvatar(
                          radius: 24,
                          backgroundColor: AppColors.primary.withOpacity(0.15),
                          child: const Icon(Icons.person, color: AppColors.primary),
                        ),
                        title: Text(
                          thread.otherPartyName.isNotEmpty ? thread.otherPartyName : 'Giáo viên',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          thread.lastMessage ?? 'Bắt đầu cuộc trò chuyện...',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: thread.unreadCount > 0 ? Colors.black87 : Colors.grey,
                            fontWeight: thread.unreadCount > 0 ? FontWeight.w600 : FontWeight.normal,
                          ),
                        ),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            if (thread.lastMessageAt != null)
                              Text(
                                timeFormat.format(thread.lastMessageAt!),
                                style: const TextStyle(fontSize: 11, color: Colors.grey),
                              ),
                            if (thread.unreadCount > 0) ...[
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: const BoxDecoration(
                                  color: AppColors.primary,
                                  shape: BoxShape.circle,
                                ),
                                child: Text(
                                  '${thread.unreadCount}',
                                  style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ],
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
