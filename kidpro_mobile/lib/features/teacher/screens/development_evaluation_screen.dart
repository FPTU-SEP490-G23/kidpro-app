import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:kidpro_mobile/core/constants/app_colors.dart';
import 'package:kidpro_mobile/features/teacher/models/teacher_models.dart';
import 'package:kidpro_mobile/features/teacher/providers/teacher_provider.dart';

class DevelopmentEvaluationScreen extends StatefulWidget {
  const DevelopmentEvaluationScreen({super.key});

  @override
  State<DevelopmentEvaluationScreen> createState() => _DevelopmentEvaluationScreenState();
}

class _DevelopmentEvaluationScreenState extends State<DevelopmentEvaluationScreen> {
  String? _selectedStudentId;
  // Năm học bắt đầu từ tháng 9: 11/2026 -> '2026-2027'
  static final String _schoolYear = () {
    final now = DateTime.now();
    final start = now.month >= 9 ? now.year : now.year - 1;
    return '$start-${start + 1}';
  }();
  String _period = 'HỌC KỲ I - $_schoolYear';
  // Điểm khởi tạo trung tính; giáo viên tự chấm theo quan sát
  double _physical = 5.0;
  double _cognitive = 5.0;
  double _language = 5.0;
  double _social = 5.0;
  double _aesthetic = 5.0;

  final _commentCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final prov = context.read<TeacherProvider>();
      prov.loadStudents(prov.currentClassId);
      prov.loadDevelopmentEvaluations(prov.currentClassId);
    });
  }

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  int _countWords(String text) {
    if (text.trim().isEmpty) return 0;
    return text.trim().split(RegExp(r'\s+')).length;
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<TeacherProvider>();
    final students = prov.students;
    final wordCount = _countWords(_commentCtrl.text);
    final isValidWords = wordCount >= 50;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Đánh giá Chuẩn 5 Lĩnh vực'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => prov.loadDevelopmentEvaluations(prov.currentClassId),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            color: Colors.purple.shade50,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.purple.shade200),
            ),
            child: const Padding(
              padding: EdgeInsets.all(12),
              child: Row(
                children: [
                  Icon(Icons.stars, color: Colors.purple),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Quy tắc BR-049: Đánh giá toàn diện 5 lĩnh vực (Thể chất, Nhận thức, Ngôn ngữ, Tình cảm - Xã hội, Thẩm mỹ). Lời nhận xét sư phạm phải đạt tối thiểu 50 từ.',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          DropdownButtonFormField<String>(
            value: _selectedStudentId ?? (students.isNotEmpty ? students.first.id : null),
            decoration: const InputDecoration(
              labelText: 'Học sinh được đánh giá',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.person),
            ),
            items: students.map((s) => DropdownMenuItem(
              value: s.id,
              child: Text(s.fullName),
            )).toList(),
            onChanged: (val) => setState(() => _selectedStudentId = val),
          ),
          const SizedBox(height: 12),

          DropdownButtonFormField<String>(
            value: _period,
            decoration: const InputDecoration(
              labelText: 'Kỳ đánh giá chuẩn phát triển',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.calendar_today),
            ),
            items: [
              DropdownMenuItem(value: 'HỌC KỲ I - $_schoolYear', child: Text('Học kỳ I ($_schoolYear)')),
              DropdownMenuItem(value: 'HỌC KỲ II - $_schoolYear', child: Text('Học kỳ II ($_schoolYear)')),
              DropdownMenuItem(value: 'CUỐI NĂM HỌC - $_schoolYear', child: Text('Tổng kết cuối năm học ($_schoolYear)')),
            ],
            onChanged: (val) => setState(() => _period = val ?? 'HỌC KỲ I - $_schoolYear'),
          ),
          const SizedBox(height: 20),

          Text('Điểm số 5 Lĩnh vực Phát triển (Thang 10):', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),

          _buildDomainSlider('1. Phát triển Thể chất', _physical, (v) => setState(() => _physical = v)),
          _buildDomainSlider('2. Phát triển Nhận thức', _cognitive, (v) => setState(() => _cognitive = v)),
          _buildDomainSlider('3. Phát triển Ngôn ngữ', _language, (v) => setState(() => _language = v)),
          _buildDomainSlider('4. Tình cảm & Kỹ năng Xã hội', _social, (v) => setState(() => _social = v)),
          _buildDomainSlider('5. Phát triển Thẩm mỹ', _aesthetic, (v) => setState(() => _aesthetic = v)),

          const SizedBox(height: 16),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Nhận xét Sư phạm của Giáo viên:', style: TextStyle(fontWeight: FontWeight.bold)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isValidWords ? Colors.green.shade50 : Colors.red.shade50,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: isValidWords ? Colors.green : Colors.red),
                ),
                child: Text(
                  '$wordCount / 50 từ (BR-049)',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: isValidWords ? Colors.green.shade800 : Colors.red.shade800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          TextField(
            controller: _commentCtrl,
            maxLines: 4,
            decoration: InputDecoration(
              hintText: 'Nhập nhận xét chi tiết về hành vi, sự tiến bộ và tính cách của bé...',
              border: const OutlineInputBorder(),
              errorText: isValidWords ? null : 'Cần tối thiểu 50 từ theo quy tắc BR-049',
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 24),

          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: isValidWords ? AppColors.primary : Colors.grey,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            icon: const Icon(Icons.check_circle_outline),
            label: const Text('Lưu Phiếu Đánh Giá 5 Lĩnh Vực (MSG-181)'),
            onPressed: () async {
              if (!isValidWords) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('MSG-183: Nhận xét sư phạm chưa đủ độ dài tối thiểu (tối thiểu 50 từ)!'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }

              if (students.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Chưa có danh sách học sinh từ hệ thống!'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }

              final studentId = _selectedStudentId ?? students.first.id;
              final studentName = students.firstWhere((s) => s.id == studentId, orElse: () => TeacherStudent(id: studentId, fullName: 'Bé')).fullName;

              final item = DevelopmentEvaluationItem(
                studentId: studentId,
                studentName: studentName,
                evaluationPeriod: _period,
                physicalScore: _physical,
                cognitiveScore: _cognitive,
                languageScore: _language,
                socialEmotionalScore: _social,
                aestheticScore: _aesthetic,
                teacherComment: _commentCtrl.text.trim(),
                status: 'SUBMITTED',
              );

              final msg = await prov.submitEvaluation(item);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(msg ?? 'Lưu thành công'), backgroundColor: context.read<TeacherProvider>().lastActionFailed ? AppColors.error : AppColors.success),
                );
              }
            },
          ),
          const SizedBox(height: 28),
          Text('Phiếu đánh giá đã lưu của lớp (${prov.evaluations.length})',
              style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          if (prov.evaluations.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text('Chưa có phiếu đánh giá nào.', style: TextStyle(color: Colors.grey)),
            )
          else
            ...prov.evaluations.map((e) {
              final (label, color) = _statusLabel(e.status);
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  title: Text(e.studentName, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('${e.evaluationPeriod}\n'
                      'TC ${e.physicalScore} · NT ${e.cognitiveScore} · NN ${e.languageScore} · '
                      'XH ${e.socialEmotionalScore} · TM ${e.aestheticScore}'),
                  isThreeLine: true,
                  trailing: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12)),
                ),
              );
            }),
        ],
      ),
    );
  }

  (String, Color) _statusLabel(String status) {
    switch (status.toUpperCase()) {
      case 'APPROVED':
      case 'PUBLISHED':
        return ('ĐÃ DUYỆT', AppColors.success);
      case 'REVISION_REQUESTED':
      case 'REJECTED':
        return ('YÊU CẦU SỬA', AppColors.error);
      case 'DRAFT':
        return ('BẢN NHÁP', Colors.grey);
      default:
        return ('CHỜ BGH DUYỆT', AppColors.warning);
    }
  }

  Widget _buildDomainSlider(String title, double value, ValueChanged<double> onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
            Text('${value.toStringAsFixed(1)} / 10', style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary)),
          ],
        ),
        Slider(
          value: value,
          min: 1.0,
          max: 10.0,
          divisions: 18,
          label: value.toStringAsFixed(1),
          onChanged: onChanged,
        ),
      ],
    );
  }
}
