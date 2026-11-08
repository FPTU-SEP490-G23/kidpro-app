import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:kidpro_mobile/core/constants/app_colors.dart';

/// BR-058: ngoài khung 07:00 - 21:30 là giờ yên tĩnh.
bool isChatSilentHours([DateTime? at]) {
  final now = at ?? DateTime.now();
  final minutes = now.hour * 60 + now.minute;
  return minutes >= 21 * 60 + 30 || minutes < 7 * 60;
}

class SilentHoursBanner extends StatelessWidget {
  const SilentHoursBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: Colors.blueGrey.shade100,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: const Row(
        children: [
          Icon(Icons.bedtime, size: 16, color: Colors.blueGrey),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Ngoài khung giờ 07:00 - 21:30: đang ở chế độ yên tĩnh, phụ huynh sẽ nhận tin vào sáng mai (BR-058).',
              style: TextStyle(fontSize: 11, color: Colors.blueGrey),
            ),
          ),
        ],
      ),
    );
  }
}

/// Bong bóng tin nhắn dùng chung cho nhóm lớp và nhắn riêng.
class ChatBubble extends StatelessWidget {
  final bool isMe;
  final String? senderLabel;
  final String content;
  final DateTime createdAt;

  const ChatBubble({
    super.key,
    required this.isMe,
    this.senderLabel,
    required this.content,
    required this.createdAt,
  });

  @override
  Widget build(BuildContext context) {
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
                if (senderLabel != null) ...[
                  Text(
                    senderLabel!,
                    style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 3),
                ],
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
                    content,
                    style: TextStyle(color: isMe ? Colors.white : Colors.black87, fontSize: 14),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  formatChatTime(createdAt),
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
  }
}

/// Hôm nay: HH:mm; ngày khác: dd/MM HH:mm.
String formatChatTime(DateTime t) {
  final now = DateTime.now();
  final sameDay = t.year == now.year && t.month == now.month && t.day == now.day;
  return DateFormat(sameDay ? 'HH:mm' : 'dd/MM HH:mm').format(t);
}

/// Ô nhập tin nhắn.
class ChatInputBar extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final bool sending;
  final VoidCallback onSend;

  const ChatInputBar({
    super.key,
    required this.controller,
    required this.hintText,
    required this.onSend,
    this.sending = false,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4, offset: const Offset(0, -2)),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.send,
                decoration: InputDecoration(
                  hintText: hintText,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                onSubmitted: (_) => onSend(),
              ),
            ),
            IconButton(
              icon: sending
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.send, color: AppColors.primary),
              onPressed: sending ? null : onSend,
            ),
          ],
        ),
      ),
    );
  }
}
