import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:kidpro_mobile/core/constants/app_colors.dart';
import 'package:kidpro_mobile/features/teacher/providers/teacher_provider.dart';

class ClassChatRoomScreen extends StatefulWidget {
  const ClassChatRoomScreen({super.key});

  @override
  State<ClassChatRoomScreen> createState() => _ClassChatRoomScreenState();
}

class _ClassChatRoomScreenState extends State<ClassChatRoomScreen> {
  final _messageCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final prov = context.read<TeacherProvider>();
      prov.loadClassChat(prov.currentClassId);
    });
  }

  @override
  void dispose() {
    _messageCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _sendMessage() async {
    final text = _messageCtrl.text.trim();
    if (text.isEmpty) return;
    _messageCtrl.clear();

    final prov = context.read<TeacherProvider>();
    await prov.sendChatMessage(prov.currentClassId, text);

    // Scroll to bottom
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
    final prov = context.watch<TeacherProvider>();
    final messages = prov.chatMessages;
    final isLocked = prov.isChatLocked;
    final timeFmt = DateFormat('HH:mm');

    final now = DateTime.now();
    final isSilentHours = now.hour >= 21 && now.minute >= 30 || now.hour < 7;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Nhóm Chat Lớp Mầm 1', style: TextStyle(fontSize: 16)),
            Text(
              isLocked ? '🔒 Chỉ Giáo viên được nhắn tin' : 'Mở thảo luận phụ huynh',
              style: TextStyle(
                fontSize: 11,
                color: isLocked ? Colors.red.shade200 : Colors.green.shade200,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: isLocked ? 'Mở chat cho phụ huynh' : 'Khóa chat của phụ huynh (BR-059)',
            icon: Icon(isLocked ? Icons.lock : Icons.lock_open),
            onPressed: () async {
              final newLockState = !isLocked;
              final msg = await prov.toggleChatLock(prov.currentClassId, newLockState);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(msg ?? 'Đã cập nhật trạng thái'),
                    backgroundColor: AppColors.primary,
                  ),
                );
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => prov.loadClassChat(prov.currentClassId),
          ),
        ],
      ),
      body: Column(
        children: [
          if (isSilentHours)
            Container(
              color: Colors.blueGrey.shade100,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: const Row(
                children: [
                  Icon(Icons.bedtime, size: 16, color: Colors.blueGrey),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'BR-058: Ngoài khung giờ 07:00 - 21:30. Đang bật chế độ Yên tĩnh (Silent Mode).',
                      style: TextStyle(fontSize: 11, color: Colors.blueGrey),
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: ListView.builder(
              controller: _scrollCtrl,
              padding: const EdgeInsets.all(16),
              itemCount: messages.length,
              itemBuilder: (context, index) {
                final m = messages[index];
                final isMe = m.senderType == 'TEACHER';

                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (!isMe) ...[
                        CircleAvatar(
                          backgroundColor: Colors.orange.shade100,
                          radius: 16,
                          child: const Icon(Icons.person, size: 18, color: Colors.orange),
                        ),
                        const SizedBox(width: 8),
                      ],
                      Flexible(
                        child: Column(
                          crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                          children: [
                            Text(
                              isMe ? 'Cô Giáo (Chủ nhiệm)' : '${m.senderName} (${m.studentName ?? "Phụ huynh"})',
                              style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 3),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                color: isMe ? AppColors.primary : Colors.grey.shade200,
                                borderRadius: BorderRadius.circular(16).copyWith(
                                  bottomRight: isMe ? Radius.zero : const Radius.circular(16),
                                  bottomLeft: !isMe ? Radius.zero : const Radius.circular(16),
                                ),
                              ),
                              child: Text(
                                m.content,
                                style: TextStyle(
                                  color: isMe ? Colors.white : Colors.black87,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              timeFmt.format(m.createdAt),
                              style: const TextStyle(fontSize: 10, color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                      if (isMe) ...[
                        const SizedBox(width: 8),
                        const CircleAvatar(
                          backgroundColor: AppColors.primary,
                          radius: 16,
                          child: Icon(Icons.school, size: 18, color: Colors.white),
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 4,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageCtrl,
                    decoration: const InputDecoration(
                      hintText: 'Nhập tin nhắn thông báo tới phụ huynh...',
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send, color: AppColors.primary),
                  onPressed: _sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
