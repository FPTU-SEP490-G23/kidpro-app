import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:kidpro_mobile/core/constants/app_colors.dart';
import 'package:kidpro_mobile/features/teacher/providers/teacher_provider.dart';

class ClassroomJournalScreen extends StatefulWidget {
  const ClassroomJournalScreen({super.key});

  @override
  State<ClassroomJournalScreen> createState() => _ClassroomJournalScreenState();
}

class _ClassroomJournalScreenState extends State<ClassroomJournalScreen> {
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  // Danh sách đường dẫn ảnh đã chọn (mỗi dòng 1 ảnh), tải lên server khi đăng album
  final _photosCtrl = TextEditingController();
  final Set<String> _taggedStudentIds = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final prov = context.read<TeacherProvider>();
      prov.loadStudents(prov.currentClassId);
      prov.loadClassroomJournal(prov.currentClassId);
    });
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _photosCtrl.dispose();
    super.dispose();
  }

  void _showCreateAlbumModal() {
    _titleCtrl.clear();
    _descCtrl.clear();
    _photosCtrl.clear();
    _taggedStudentIds.clear();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          final students = context.watch<TeacherProvider>().students;

          return Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 20,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.photo_library, color: AppColors.primary, size: 28),
                      const SizedBox(width: 8),
                      Text(
                        'Đăng Album Ảnh Lớp (BR-060)',
                        style: Theme.of(ctx).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'Quy tắc BR-060: Tối đa không quá 50 ảnh/hoạt động. Định dạng ảnh hỗ trợ JPG, JPEG, PNG, WEBP. Phụ huynh có con được gắn thẻ sẽ nhận được thông báo.',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                  const SizedBox(height: 16),

                  TextField(
                    controller: _titleCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Tiêu đề hoạt động / Tên album',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),

                  TextField(
                    controller: _descCtrl,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Mô tả bài học & hoạt động',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),

                  Builder(builder: (_) {
                    final count = _photosCtrl.text.split('\n').where((u) => u.trim().isNotEmpty).length;
                    return OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                      icon: Icon(count > 0 ? Icons.check_circle : Icons.photo_library,
                          color: count > 0 ? AppColors.success : null),
                      label: Text(count > 0
                          ? 'Đã chọn $count ảnh (chạm để chọn lại, tối đa 50)'
                          : 'Chọn ảnh hoạt động (tối đa 50 ảnh)'),
                      onPressed: () async {
                        final photos = await ImagePicker().pickMultiImage(maxWidth: 1280, imageQuality: 85);
                        if (photos.isEmpty) return;
                        setModalState(() => _photosCtrl.text = photos.map((p) => p.path).join('\n'));
                      },
                    );
                  }),
                  const SizedBox(height: 16),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Gắn thẻ các học sinh có mặt:', style: TextStyle(fontWeight: FontWeight.bold)),
                      TextButton(
                        onPressed: () {
                          setModalState(() {
                            if (_taggedStudentIds.length == students.length) {
                              _taggedStudentIds.clear();
                            } else {
                              _taggedStudentIds.addAll(students.map((s) => s.id));
                            }
                          });
                        },
                        child: Text(_taggedStudentIds.length == students.length ? 'Bỏ chọn hết' : 'Chọn tất cả'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),

                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: students.map((s) {
                      final isSelected = _taggedStudentIds.contains(s.id);
                      return FilterChip(
                        label: Text(s.fullName),
                        selected: isSelected,
                        onSelected: (selected) {
                          setModalState(() {
                            if (selected) {
                              _taggedStudentIds.add(s.id);
                            } else {
                              _taggedStudentIds.remove(s.id);
                            }
                          });
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: const Icon(Icons.cloud_upload),
                      label: const Text('Đăng Album Ảnh (MSG-238)'),
                      onPressed: () async {
                        final rawUrls = _photosCtrl.text
                            .split('\n')
                            .map((u) => u.trim())
                            .where((u) => u.isNotEmpty)
                            .toList();

                        if (rawUrls.isEmpty || _titleCtrl.text.trim().isEmpty) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            const SnackBar(
                              content: Text('Vui lòng nhập tiêu đề và chọn ít nhất 1 ảnh!'),
                              backgroundColor: Colors.red,
                            ),
                          );
                          return;
                        }
                        if (rawUrls.length > 50) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            const SnackBar(
                              content: Text('MSG-239: Số lượng ảnh vượt quá giới hạn tối đa 50 ảnh!'),
                              backgroundColor: Colors.red,
                            ),
                          );
                          return;
                        }

                        Navigator.pop(ctx);
                        final prov = context.read<TeacherProvider>();
                        final msg = await prov.createClassroomJournal(
                          title: _titleCtrl.text.trim(),
                          content: _descCtrl.text.trim(),
                          photoUrls: rawUrls,
                          taggedStudentIds: _taggedStudentIds.toList(),
                        );
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(msg ?? 'Đăng album thành công'), backgroundColor: context.read<TeacherProvider>().lastActionFailed ? AppColors.error : AppColors.success),
                          );
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<TeacherProvider>();
    final posts = prov.journalPosts;
    final dateFmt = DateFormat('dd/MM/yyyy HH:mm');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Album Ảnh & Nhật Ký Lớp'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => prov.loadClassroomJournal(prov.currentClassId),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_photo_alternate),
        label: const Text('Tạo Album'),
        onPressed: _showCreateAlbumModal,
      ),
      body: prov.loading
          ? const Center(child: CircularProgressIndicator())
          : posts.isEmpty
              ? const Center(child: Text('Chưa có album hoạt động nào.'))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: posts.length,
                  itemBuilder: (context, index) {
                    final item = posts[index];

                    return Card(
                      margin: const EdgeInsets.only(bottom: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (item.photoUrls.isNotEmpty)
                            ClipRRect(
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                              child: AspectRatio(
                                aspectRatio: 16 / 9,
                                child: Image.network(
                                  item.photoUrls.first,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Container(
                                    color: Colors.grey.shade200,
                                    child: const Icon(Icons.broken_image, size: 48, color: Colors.grey),
                                  ),
                                ),
                              ),
                            ),
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: Colors.purple.shade50,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        item.className,
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 11,
                                          color: Colors.purple.shade900,
                                        ),
                                      ),
                                    ),
                                    Text(
                                      '${item.photoUrls.length} ảnh',
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  item.title,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  item.content,
                                  style: const TextStyle(fontSize: 13, color: Colors.black87),
                                ),
                                const SizedBox(height: 10),
                                if (item.taggedStudentIds.isNotEmpty) ...[
                                  Wrap(
                                    spacing: 6,
                                    children: [
                                      const Icon(Icons.label, size: 14, color: AppColors.primary),
                                      Text(
                                        'Gắn thẻ: ${item.taggedStudentIds.length} học sinh',
                                        style: const TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                ],
                                Text(
                                  dateFmt.format(item.createdAt),
                                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}
