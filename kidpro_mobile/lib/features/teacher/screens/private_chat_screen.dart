import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:kidpro_mobile/core/constants/app_colors.dart';
import 'package:kidpro_mobile/features/teacher/models/teacher_models.dart';
import 'package:kidpro_mobile/features/teacher/providers/teacher_provider.dart';
import 'package:kidpro_mobile/features/teacher/widgets/chat_widgets.dart';

/// Nhắn riêng giữa giáo viên và phụ huynh của 1 bé.
class PrivateChatScreen extends StatefulWidget {
  final PrivateChatThread thread;

  const PrivateChatScreen({super.key, required this.thread});

  @override
  State<PrivateChatScreen> createState() => _PrivateChatScreenState();
}

class _PrivateChatScreenState extends State<PrivateChatScreen> {
  final _messageCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  Timer? _poll;
  bool _sending = false;
  int _lastCount = 0;
  late final TeacherProvider _prov;

  @override
  void initState() {
    super.initState();
    _prov = context.read<TeacherProvider>();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
    // Tự cập nhật tin mới của phụ huynh khi đang mở hội thoại
    _poll = Timer.periodic(const Duration(seconds: 10), (_) => _refresh());
  }

  @override
  void dispose() {
    _poll?.cancel();
    _prov.closePrivateChat();
    _messageCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    await _prov.loadPrivateMessages(widget.thread.studentId);
    if (!mounted) return;
    if (_prov.privateMessages.length != _lastCount) {
      _lastCount = _prov.privateMessages.length;
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _send() async {
    final text = _messageCtrl.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    final error = await _prov.sendPrivateMessage(widget.thread.studentId, text);
    if (!mounted) return;
    setState(() => _sending = false);
    if (error == null) {
      _messageCtrl.clear();
      _lastCount = _prov.privateMessages.length;
      _scrollToBottom();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error), backgroundColor: AppColors.error));
    }
  }

  @override
  Widget build(BuildContext context) {
    final messages = context.watch<TeacherProvider>().privateMessages;
    final t = widget.thread;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(t.parentName ?? 'Phụ huynh', style: const TextStyle(fontSize: 16)),
            Text('Phụ huynh bé ${t.studentName}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.normal)),
          ],
        ),
      ),
      body: Column(
        children: [
          if (isChatSilentHours()) const SilentHoursBanner(),
          Expanded(
            child: messages.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'Chưa có tin nhắn. Tin nhắn ở đây chỉ bạn và phụ huynh bé ${t.studentName} xem được.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.grey),
                      ),
                    ),
                  )
                : ListView.builder(
                    controller: _scrollCtrl,
                    padding: const EdgeInsets.all(16),
                    itemCount: messages.length,
                    itemBuilder: (_, i) {
                      final m = messages[i];
                      return ChatBubble(
                        isMe: m.senderType == 'TEACHER',
                        content: m.content,
                        createdAt: m.createdAt,
                      );
                    },
                  ),
          ),
          ChatInputBar(
            controller: _messageCtrl,
            hintText: 'Nhắn riêng cho phụ huynh...',
            sending: _sending,
            onSend: _send,
          ),
        ],
      ),
    );
  }
}
