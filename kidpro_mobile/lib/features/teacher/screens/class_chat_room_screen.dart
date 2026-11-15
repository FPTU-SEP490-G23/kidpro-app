import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:kidpro_mobile/core/constants/app_colors.dart';
import 'package:kidpro_mobile/features/teacher/models/teacher_models.dart';
import 'package:kidpro_mobile/features/teacher/providers/teacher_provider.dart';
import 'package:kidpro_mobile/features/teacher/screens/private_chat_screen.dart';
import 'package:kidpro_mobile/features/teacher/widgets/chat_widgets.dart';

/// Tab "Tin nhắn" của giáo viên: nhóm chat chung của lớp + nhắn riêng với từng phụ huynh.
class ClassChatRoomScreen extends StatefulWidget {
  const ClassChatRoomScreen({super.key});

  @override
  State<ClassChatRoomScreen> createState() => _ClassChatRoomScreenState();
}

class _ClassChatRoomScreenState extends State<ClassChatRoomScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 2, vsync: this)
    ..addListener(() {
      if (!_tabs.indexIsChanging) setState(() {});
    });

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final prov = context.read<TeacherProvider>();
      prov.loadClassChat(prov.currentClassId);
      prov.loadPrivateThreads();
    });
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _toggleLock(TeacherProvider prov) async {
    final msg = await prov.toggleChatLock(prov.currentClassId, !prov.isChatLocked);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg ?? 'Đã cập nhật trạng thái'), backgroundColor: context.read<TeacherProvider>().lastActionFailed ? AppColors.error : AppColors.success),
    );
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<TeacherProvider>();
    final onGroupTab = _tabs.index == 0;
    final unread = prov.privateUnreadTotal;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tin nhắn'),
        actions: [
          if (onGroupTab)
            IconButton(
              tooltip: prov.isChatLocked ? 'Mở chat cho phụ huynh' : 'Khóa chat của phụ huynh (BR-059)',
              icon: Icon(prov.isChatLocked ? Icons.lock : Icons.lock_open),
              onPressed: () => _toggleLock(prov),
            ),
          IconButton(
            tooltip: 'Tải lại',
            icon: const Icon(Icons.refresh),
            onPressed: () =>
                onGroupTab ? prov.loadClassChat(prov.currentClassId) : prov.loadPrivateThreads(),
          ),
        ],
        bottom: TabBar(
          controller: _tabs,
          tabs: [
            const Tab(icon: Icon(Icons.groups_rounded), text: 'Nhóm lớp'),
            Tab(
              icon: Badge(
                isLabelVisible: unread > 0,
                label: Text('$unread'),
                child: const Icon(Icons.forum_rounded),
              ),
              text: 'Phụ huynh',
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: const [
          _ClassGroupChat(),
          _ParentThreadList(),
        ],
      ),
    );
  }
}

// ── Tab 1: Nhóm chat chung của lớp (G11-UC-04, BR-058, BR-059) ──
class _ClassGroupChat extends StatefulWidget {
  const _ClassGroupChat();

  @override
  State<_ClassGroupChat> createState() => _ClassGroupChatState();
}

class _ClassGroupChatState extends State<_ClassGroupChat> with AutomaticKeepAliveClientMixin {
  final _messageCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    _messageCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _messageCtrl.text.trim();
    if (text.isEmpty) return;
    _messageCtrl.clear();
    final prov = context.read<TeacherProvider>();
    await prov.sendChatMessage(prov.currentClassId, text);
    _scrollToBottom();
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final prov = context.watch<TeacherProvider>();
    final messages = prov.chatMessages;

    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: AppColors.primary.withValues(alpha: 0.06),
          child: Row(
            children: [
              Icon(prov.isChatLocked ? Icons.lock : Icons.groups_rounded, size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  prov.isChatLocked
                      ? 'Nhóm ${prov.currentClassName}: chỉ giáo viên được nhắn'
                      : 'Nhóm ${prov.currentClassName}: giáo viên và phụ huynh cả lớp',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
        if (isChatSilentHours()) const SilentHoursBanner(),
        Expanded(
          child: messages.isEmpty
              ? const Center(
                  child: Text('Chưa có tin nhắn trong nhóm lớp', style: TextStyle(color: Colors.grey)),
                )
              : ListView.builder(
                  controller: _scrollCtrl,
                  padding: const EdgeInsets.all(16),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final m = messages[index];
                    final isMe = m.senderType == 'TEACHER';
                    return ChatBubble(
                      isMe: isMe,
                      senderLabel: isMe
                          ? 'Giáo viên · ${m.senderName}'
                          : '${m.senderName}${m.studentName != null ? ' (PH bé ${m.studentName})' : ''}',
                      content: m.content,
                      createdAt: m.createdAt,
                    );
                  },
                ),
        ),
        ChatInputBar(
          controller: _messageCtrl,
          hintText: 'Nhắn cho cả lớp...',
          onSend: _send,
        ),
      ],
    );
  }
}

// ── Tab 2: Danh sách nhắn riêng với phụ huynh, mỗi bé 1 hội thoại ──
class _ParentThreadList extends StatefulWidget {
  const _ParentThreadList();

  @override
  State<_ParentThreadList> createState() => _ParentThreadListState();
}

class _ParentThreadListState extends State<_ParentThreadList> with AutomaticKeepAliveClientMixin {
  String _query = '';

  @override
  bool get wantKeepAlive => true;

  Future<void> _open(PrivateChatThread t) async {
    await Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(builder: (_) => PrivateChatScreen(thread: t)),
    );
    if (mounted) context.read<TeacherProvider>().loadPrivateThreads();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final prov = context.watch<TeacherProvider>();
    final q = _query.trim().toLowerCase();
    final threads = prov.privateThreads
        .where((t) =>
            q.isEmpty ||
            t.studentName.toLowerCase().contains(q) ||
            (t.parentName ?? '').toLowerCase().contains(q))
        .toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: TextField(
            decoration: InputDecoration(
              hintText: 'Tìm theo tên bé hoặc phụ huynh',
              prefixIcon: const Icon(Icons.search),
              isDense: true,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(24)),
            ),
            onChanged: (v) => setState(() => _query = v),
          ),
        ),
        if (prov.privateThreadsError != null)
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(prov.privateThreadsError!, style: const TextStyle(color: AppColors.error)),
          ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: prov.loadPrivateThreads,
            child: prov.privateThreadsLoading && prov.privateThreads.isEmpty
                ? ListView(children: const [
                    SizedBox(height: 120),
                    Center(child: CircularProgressIndicator()),
                  ])
                : threads.isEmpty
                    ? ListView(children: const [
                        SizedBox(height: 120),
                        Center(child: Text('Không có học sinh nào', style: TextStyle(color: Colors.grey))),
                      ])
                    : ListView.separated(
                        physics: const AlwaysScrollableScrollPhysics(),
                        itemCount: threads.length,
                        separatorBuilder: (_, __) => const Divider(height: 1, indent: 72),
                        itemBuilder: (_, i) => _threadTile(threads[i]),
                      ),
          ),
        ),
      ],
    );
  }

  Widget _threadTile(PrivateChatThread t) {
    final hasUnread = t.unreadCount > 0;
    final preview = t.lastMessage == null
        ? 'Chưa có tin nhắn · bấm để nhắn phụ huynh'
        : '${t.lastSenderType == 'TEACHER' ? 'Bạn: ' : ''}${t.lastMessage}';

    return ListTile(
      onTap: () => _open(t),
      leading: CircleAvatar(
        radius: 24,
        backgroundColor: AppColors.primary.withValues(alpha: 0.12),
        child: Text(
          t.studentName.isNotEmpty ? t.studentName.trim().split(' ').last.characters.first : '?',
          style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary),
        ),
      ),
      title: Text(
        t.parentName != null ? 'PH bé ${t.studentName}' : t.studentName,
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (t.parentName != null)
            Text(t.parentName!, style: const TextStyle(fontSize: 12, color: Colors.black54)),
          Text(
            preview,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: hasUnread ? Colors.black87 : Colors.grey,
              fontWeight: hasUnread ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ],
      ),
      isThreeLine: t.parentName != null,
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (t.lastMessageAt != null)
            Text(formatChatTime(t.lastMessageAt!), style: const TextStyle(fontSize: 11, color: Colors.grey)),
          if (hasUnread) ...[
            const SizedBox(height: 4),
            Badge(label: Text('${t.unreadCount}'), backgroundColor: AppColors.primary),
          ],
        ],
      ),
    );
  }
}
