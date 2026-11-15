import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:kidpro_mobile/core/constants/app_colors.dart';
import 'package:kidpro_mobile/features/teacher/providers/teacher_provider.dart';

/// UC-81: Giáo viên đăng thông báo cho phụ huynh của lớp mình phụ trách.
class ClassAnnouncementScreen extends StatefulWidget {
  const ClassAnnouncementScreen({super.key});

  @override
  State<ClassAnnouncementScreen> createState() => _ClassAnnouncementScreenState();
}

class _ClassAnnouncementScreenState extends State<ClassAnnouncementScreen> {
  final _titleCtrl = TextEditingController();
  final _contentCtrl = TextEditingController();
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TeacherProvider>().loadClassAnnouncements();
    });
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _contentCtrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final title = _titleCtrl.text.trim();
    final content = _contentCtrl.text.trim();
    String? err;
    if (title.length < 5) err = 'Tiêu đề tối thiểu 5 ký tự';
    if (content.length < 10) err = 'Nội dung tối thiểu 10 ký tự';
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err), backgroundColor: AppColors.error));
      return;
    }
    setState(() => _sending = true);
    final prov = context.read<TeacherProvider>();
    final msg = await prov.postClassAnnouncement(title, content);
    if (!mounted) return;
    setState(() => _sending = false);
    if (!prov.lastActionFailed) {
      _titleCtrl.clear();
      _contentCtrl.clear();
    }
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: prov.lastActionFailed ? AppColors.error : AppColors.success,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<TeacherProvider>();
    final list = prov.classAnnouncements;

    return Scaffold(
      appBar: AppBar(title: Text('Thông báo lớp ${prov.currentClassName}')),
      body: RefreshIndicator(
        onRefresh: prov.loadClassAnnouncements,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextField(
              controller: _titleCtrl,
              maxLength: 255,
              decoration: const InputDecoration(labelText: 'Tiêu đề *', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _contentCtrl,
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: 'Nội dung *',
                hintText: 'VD: Thứ Sáu 20/11 lớp tổ chức văn nghệ, phụ huynh cho bé mặc áo dài...',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(48),
              ),
              onPressed: _sending ? null : _send,
              icon: _sending
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.campaign),
              label: const Text('Gửi cho phụ huynh cả lớp'),
            ),
            const SizedBox(height: 24),
            Text('Đã gửi (${list.length})', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            if (list.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Text('Chưa có thông báo nào cho lớp.', style: TextStyle(color: Colors.grey)),
              )
            else
              ...list.map((a) => Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: const Icon(Icons.campaign_outlined, color: AppColors.primary),
                      title: Text(a['title']?.toString() ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text('${a['content'] ?? ''}\n${_fmt(a['createdAt'])}'),
                      isThreeLine: true,
                    ),
                  )),
          ],
        ),
      ),
    );
  }

  String _fmt(dynamic v) {
    final d = DateTime.tryParse(v?.toString() ?? '')?.toLocal();
    if (d == null) return '';
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.hour)}:${two(d.minute)} ${two(d.day)}/${two(d.month)}/${d.year}';
  }
}
