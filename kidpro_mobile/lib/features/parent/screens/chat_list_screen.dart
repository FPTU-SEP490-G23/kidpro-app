import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:kidpro_mobile/core/constants/app_colors.dart';
import 'package:kidpro_mobile/features/parent/providers/parent_provider.dart';

/// Tin nhắn của phụ huynh: nhóm chat lớp + nhắn riêng với giáo viên chủ nhiệm của từng con.
class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
  }

  Future<void> _refresh() async {
    final prov = context.read<ParentProvider>();
    await Future.wait([prov.loadChatThreads(), prov.loadPrivateThreads()]);
  }

  String _time(DateTime? t) {
    if (t == null) return '';
    final now = DateTime.now();
    final sameDay = t.year == now.year && t.month == now.month && t.day == now.day;
    return DateFormat(sameDay ? 'HH:mm' : 'dd/MM').format(t);
  }

  Future<void> _openPath(String path) async {
    await context.push(path);
    if (mounted) _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<ParentProvider>();
    final groups = prov.chatThreads;
    final privates = prov.privateThreads;

    return Scaffold(
      appBar: AppBar(title: const Text('Tin nhắn')),
      body: prov.loading && groups.isEmpty && privates.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  _sectionTitle('Nhóm lớp', Icons.groups_rounded),
                  if (groups.isEmpty) _emptyText('Chưa có nhóm lớp'),
                  ...groups.map((g) => _tile(
                        icon: Icons.groups_rounded,
                        title: g.otherPartyName.isNotEmpty ? g.otherPartyName : 'Nhóm lớp',
                        subtitle: g.lastMessage ?? 'Nhóm trao đổi giáo viên & phụ huynh cả lớp',
                        time: _time(g.lastMessageAt),
                        unread: g.unreadCount,
                        onTap: () => _openPath(Uri(
                          path: '/parent/chat/${g.id}',
                          queryParameters: {'title': 'Nhóm lớp'},
                        ).toString()),
                      )),
                  const SizedBox(height: 8),
                  _sectionTitle('Nhắn riêng với cô', Icons.forum_rounded),
                  if (prov.privateThreadsError != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Text(prov.privateThreadsError!, style: const TextStyle(color: AppColors.error)),
                    )
                  else if (privates.isEmpty)
                    _emptyText('Chưa có thông tin con để nhắn tin'),
                  ...privates.map((t) {
                    final teacher = t.teacherName ?? 'Giáo viên chủ nhiệm';
                    final preview = t.lastMessage == null
                        ? 'Chỉ bạn và cô xem được · bấm để nhắn'
                        : '${t.lastSenderType == 'PARENT' ? 'Bạn: ' : ''}${t.lastMessage}';
                    return _tile(
                      icon: Icons.person_rounded,
                      title: teacher,
                      caption: 'Về bé ${t.studentName}${t.className != null ? ' · ${t.className}' : ''}',
                      subtitle: preview,
                      time: _time(t.lastMessageAt),
                      unread: t.unreadCount,
                      onTap: () => _openPath(Uri(
                        path: '/parent/chat/private/${t.studentId}',
                        queryParameters: {'title': '$teacher · bé ${t.studentName}'},
                      ).toString()),
                    );
                  }),
                ],
              ),
            ),
    );
  }

  Widget _sectionTitle(String text, IconData icon) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
        child: Row(
          children: [
            Icon(icon, size: 18, color: AppColors.primary),
            const SizedBox(width: 6),
            Text(text, style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary)),
          ],
        ),
      );

  Widget _emptyText(String text) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Text(text, style: const TextStyle(color: Colors.grey)),
      );

  Widget _tile({
    required IconData icon,
    required String title,
    String? caption,
    required String subtitle,
    required String time,
    required int unread,
    required VoidCallback onTap,
  }) {
    final hasUnread = unread > 0;
    return ListTile(
      onTap: onTap,
      leading: CircleAvatar(
        radius: 24,
        backgroundColor: AppColors.primary.withValues(alpha: 0.15),
        child: Icon(icon, color: AppColors.primary),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (caption != null) Text(caption, style: const TextStyle(fontSize: 12, color: Colors.black54)),
          Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: hasUnread ? Colors.black87 : Colors.grey,
              fontWeight: hasUnread ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ],
      ),
      isThreeLine: caption != null,
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (time.isNotEmpty) Text(time, style: const TextStyle(fontSize: 11, color: Colors.grey)),
          if (hasUnread) ...[
            const SizedBox(height: 4),
            Badge(label: Text('$unread'), backgroundColor: AppColors.primary),
          ],
        ],
      ),
    );
  }
}
