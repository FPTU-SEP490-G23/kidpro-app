import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:kidpro_mobile/core/constants/app_colors.dart';
import 'package:kidpro_mobile/features/teacher/providers/teacher_provider.dart';

class LessonPlanScreen extends StatefulWidget {
  const LessonPlanScreen({super.key});

  @override
  State<LessonPlanScreen> createState() => _LessonPlanScreenState();
}

class _LessonPlanScreenState extends State<LessonPlanScreen> {
  final _titleCtrl = TextEditingController();
  final _fileUrlCtrl = TextEditingController(
      text: 'https://storage.kidpro.edu.vn/plans/giao_an_tuan_10_mam_1.pdf');
  int _weekNumber = 10;
  final List<TextEditingController> _dayControllers = [
    TextEditingController(text: 'Thứ 2: Thơ "Cây bàng thời niên thiếu", GD thể chất bật xa'),
    TextEditingController(text: 'Thứ 3: KPKH Tìm hiểu các loài hoa mùa xuân quanh vườn trường'),
    TextEditingController(text: 'Thứ 4: Tạo hình Xé dán cánh hoa ngũ sắc'),
    TextEditingController(text: 'Thứ 5: Làm quen chữ cái O, Ô, Ơ qua trò chơi xếp hạt gấc'),
    TextEditingController(text: 'Thứ 6: Hoạt động âm nhạc Hát & Vận động bài "Màu hoa"'),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final prov = context.read<TeacherProvider>();
      prov.loadLessonPlans(prov.currentClassId);
    });
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _fileUrlCtrl.dispose();
    for (final c in _dayControllers) {
      c.dispose();
    }
    super.dispose();
  }

  void _showSubmitModal() {
    _titleCtrl.text = 'Kế hoạch GD Tuần $_weekNumber: Khám phá Thế giới Thực vật';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
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
                  const Icon(Icons.menu_book, color: AppColors.primary, size: 28),
                  const SizedBox(width: 8),
                  Text(
                    'Nộp Kế hoạch Giáo dục Tuần (BR-053)',
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
                  'Quy tắc BR-053: Nộp trực tuyến trước 17:00 Thứ Sáu. Đảm bảo đủ 5 ngày hoạt động giáo dục từ Thứ 2 đến Thứ 6. Tệp đính kèm tối đa 20MB.',
                  style: TextStyle(fontSize: 12),
                ),
              ),
              const SizedBox(height: 16),

              TextField(
                controller: _titleCtrl,
                decoration: const InputDecoration(
                  labelText: 'Tiêu đề kế hoạch giáo dục tuần',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),

              TextField(
                controller: _fileUrlCtrl,
                decoration: const InputDecoration(
                  labelText: 'Tệp giáo án đính kèm (PDF, DOCX < 20MB)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.attach_file),
                ),
              ),
              const SizedBox(height: 16),

              const Text('Kế hoạch hoạt động 5 ngày trong tuần:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),

              for (int i = 0; i < 5; i++) ...[
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: TextField(
                    controller: _dayControllers[i],
                    decoration: InputDecoration(
                      labelText: 'Ngày ${i + 2} (Thứ ${i + 2})',
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 16),

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
                  label: const Text('Nộp Giáo Án Lên BGH (MSG-188)'),
                  onPressed: () async {
                    Navigator.pop(ctx);
                    final activities = _dayControllers.map((c) => c.text.trim()).toList();
                    final prov = context.read<TeacherProvider>();
                    final msg = await prov.submitLessonPlan(
                      classId: prov.currentClassId,
                      weekNumber: _weekNumber,
                      title: _titleCtrl.text.trim(),
                      fileUrl: _fileUrlCtrl.text.trim(),
                      activities: activities,
                    );
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(msg ?? 'Nộp thành công'), backgroundColor: AppColors.success),
                      );
                    }
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<TeacherProvider>();
    final plans = prov.lessonPlans;
    final dateFmt = DateFormat('dd/MM/yyyy');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kế hoạch Giáo dục Tuần'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => prov.loadLessonPlans(prov.currentClassId),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Soạn Kế Hoạch'),
        onPressed: _showSubmitModal,
      ),
      body: prov.loading
          ? const Center(child: CircularProgressIndicator())
          : plans.isEmpty
              ? const Center(child: Text('Chưa có kế hoạch tuần nào được nộp.'))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: plans.length,
                  itemBuilder: (context, index) {
                    final item = plans[index];
                    final isApproved = item.status == 'APPROVED';

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.shade50,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    'Tuần ${item.weekNumber}',
                                    style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue.shade900),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: isApproved ? Colors.green.shade50 : Colors.amber.shade50,
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: isApproved ? Colors.green : Colors.amber),
                                  ),
                                  child: Text(
                                    isApproved ? 'BGH ĐÃ DUYỆT' : 'CHỜ BGH DUYỆT',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 11,
                                      color: isApproved ? Colors.green.shade800 : Colors.amber.shade900,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Text(
                              item.title,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Ngày nộp: ${dateFmt.format(item.createdAt)}',
                              style: const TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                            if (item.reviewComment != null && item.reviewComment!.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.comment, size: 16, color: Colors.grey),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        'Ý kiến BGH: ${item.reviewComment}',
                                        style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
