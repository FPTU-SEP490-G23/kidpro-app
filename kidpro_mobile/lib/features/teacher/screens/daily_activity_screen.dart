import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:kidpro_mobile/core/constants/app_colors.dart';
import 'package:kidpro_mobile/features/teacher/providers/teacher_provider.dart';

class DailyActivityScreen extends StatefulWidget {
  const DailyActivityScreen({super.key});

  @override
  State<DailyActivityScreen> createState() => _DailyActivityScreenState();
}

class _DailyActivityScreenState extends State<DailyActivityScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Nap form state
  String? _selectedNapStudentId;
  TimeOfDay _napStart = const TimeOfDay(hour: 11, minute: 45);
  TimeOfDay _napEnd = const TimeOfDay(hour: 14, minute: 0);
  String _sleepQuality = 'NGỦ SÂU';
  final _napNoteCtrl = TextEditingController();

  // Meal form state
  String? _selectedMealStudentId;
  String _mealType = 'BỮA TRƯA';
  String _consumptionLevel = 'ALL'; // ALL, HALF, LITTLE, NONE
  final _mealNoteCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final prov = context.read<TeacherProvider>();
      prov.loadStudents(prov.currentClassId);
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _napNoteCtrl.dispose();
    _mealNoteCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<TeacherProvider>();
    final students = prov.students;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Nhật ký Hoạt động (Ăn & Ngủ)'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.bedtime), text: 'Giấc ngủ trưa'),
            Tab(icon: Icon(Icons.restaurant), text: 'Khẩu phần ăn'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // ── Tab 1: Nhật ký Giấc ngủ (G10-UC-04, BR-032) ──
          ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                color: Colors.indigo.shade50,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: Colors.indigo.shade200),
                ),
                child: const Padding(
                  padding: EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Icon(Icons.bedtime, color: Colors.indigo),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Quy tắc BR-032: Ghi nhận giờ bắt đầu ngủ, giờ thức dậy và chất lượng giấc ngủ của trẻ. Giờ thức phải sau giờ ngủ.',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              DropdownButtonFormField<String>(
                value: _selectedNapStudentId ?? (students.isNotEmpty ? students.first.id : null),
                decoration: const InputDecoration(
                  labelText: 'Chọn học sinh',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.child_care),
                ),
                items: students.map((s) => DropdownMenuItem(
                  value: s.id,
                  child: Text(s.fullName),
                )).toList(),
                onChanged: (val) => setState(() => _selectedNapStudentId = val),
              ),
              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(
                    child: ListTile(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: BorderSide(color: Colors.grey.shade300),
                      ),
                      title: const Text('Bắt đầu ngủ', style: TextStyle(fontSize: 12, color: Colors.grey)),
                      subtitle: Text(_napStart.format(context), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      trailing: const Icon(Icons.access_time),
                      onTap: () async {
                        final t = await showTimePicker(context: context, initialTime: _napStart);
                        if (t != null) setState(() => _napStart = t);
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ListTile(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: BorderSide(color: Colors.grey.shade300),
                      ),
                      title: const Text('Thức dậy', style: TextStyle(fontSize: 12, color: Colors.grey)),
                      subtitle: Text(_napEnd.format(context), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      trailing: const Icon(Icons.access_time),
                      onTap: () async {
                        final t = await showTimePicker(context: context, initialTime: _napEnd);
                        if (t != null) setState(() => _napEnd = t);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              const Text('Chất lượng giấc ngủ:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  ChoiceChip(
                    label: const Text('Ngủ sâu, ngon giấc'),
                    selected: _sleepQuality == 'NGỦ SÂU',
                    onSelected: (val) => setState(() => _sleepQuality = 'NGỦ SÂU'),
                  ),
                  ChoiceChip(
                    label: const Text('Hay giật mình'),
                    selected: _sleepQuality == 'HAY GIẬT MÌNH',
                    onSelected: (val) => setState(() => _sleepQuality = 'HAY GIẬT MÌNH'),
                  ),
                  ChoiceChip(
                    label: const Text('Khó vào giấc'),
                    selected: _sleepQuality == 'KHÓ VÀO GIẤC',
                    onSelected: (val) => setState(() => _sleepQuality = 'KHÓ VÀO GIẤC'),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              TextField(
                controller: _napNoteCtrl,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Ghi chú thêm của giáo viên',
                  hintText: 'Bé trằn trọc khoảng 15 phút đầu, sau đó ngủ ngoan...',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 24),

              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.save),
                label: const Text('Lưu nhật ký giấc ngủ (MSG-208)'),
                onPressed: () async {
                  if (students.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Chưa có danh sách học sinh!'),
                        backgroundColor: Colors.red,
                      ),
                    );
                    return;
                  }
                  final studentId = _selectedNapStudentId ?? students.first.id;
                  final startStr = '${_napStart.hour.toString().padLeft(2, '0')}:${_napStart.minute.toString().padLeft(2, '0')}';
                  final endStr = '${_napEnd.hour.toString().padLeft(2, '0')}:${_napEnd.minute.toString().padLeft(2, '0')}';

                  final msg = await prov.recordNap(
                    studentId: studentId,
                    napStartTime: startStr,
                    napEndTime: endStr,
                    sleepQuality: _sleepQuality,
                    note: _napNoteCtrl.text.trim(),
                  );
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(msg ?? 'Lưu thành công'), backgroundColor: AppColors.success),
                    );
                  }
                },
              ),
            ],
          ),

          // ── Tab 2: Khẩu phần Ăn Bán Trú (G10-UC-05, BR-032) ──
          ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                color: Colors.green.shade50,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: Colors.green.shade200),
                ),
                child: const Padding(
                  padding: EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Icon(Icons.restaurant, color: Colors.green),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Quy tắc BR-032: Ghi nhận mức tiêu thụ thức ăn gồm 4 mức: Hết suất, Nửa suất, Ăn ít và Bỏ ăn.',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              DropdownButtonFormField<String>(
                value: _selectedMealStudentId ?? (students.isNotEmpty ? students.first.id : null),
                decoration: const InputDecoration(
                  labelText: 'Chọn học sinh',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.child_care),
                ),
                items: students.map((s) => DropdownMenuItem(
                  value: s.id,
                  child: Text(s.fullName),
                )).toList(),
                onChanged: (val) => setState(() => _selectedMealStudentId = val),
              ),
              const SizedBox(height: 16),

              DropdownButtonFormField<String>(
                value: _mealType,
                decoration: const InputDecoration(
                  labelText: 'Bữa ăn',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.lunch_dining),
                ),
                items: const [
                  DropdownMenuItem(value: 'BỮA TRƯA', child: Text('Bữa trưa chính')),
                  DropdownMenuItem(value: 'BỮA XẾ', child: Text('Bữa phụ xế chiều')),
                  DropdownMenuItem(value: 'BỮA SÁNG', child: Text('Bữa ăn sáng tại trường')),
                ],
                onChanged: (val) => setState(() => _mealType = val ?? 'BỮA TRƯA'),
              ),
              const SizedBox(height: 16),

              const Text('Mức độ ăn uống của bé:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),

              RadioListTile<String>(
                value: 'ALL',
                groupValue: _consumptionLevel,
                title: const Text('Ăn hết suất (100%)'),
                subtitle: const Text('Bé ăn ngoan, tự xúc hoặc cô hỗ trợ ăn hết cơm và canh'),
                onChanged: (val) => setState(() => _consumptionLevel = val!),
              ),
              RadioListTile<String>(
                value: 'HALF',
                groupValue: _consumptionLevel,
                title: const Text('Ăn nửa suất (50%)'),
                subtitle: const Text('Bé ăn được một nửa phần ăn'),
                onChanged: (val) => setState(() => _consumptionLevel = val!),
              ),
              RadioListTile<String>(
                value: 'LITTLE',
                groupValue: _consumptionLevel,
                title: const Text('Ăn ít (< 30%)'),
                subtitle: const Text('Bé biếng ăn, chỉ ăn vài thìa thức ăn'),
                onChanged: (val) => setState(() => _consumptionLevel = val!),
              ),
              RadioListTile<String>(
                value: 'NONE',
                groupValue: _consumptionLevel,
                title: const Text('Bỏ ăn (0%)'),
                subtitle: const Text('Bé không chịu ăn, nôn trớ hoặc mệt mỏi'),
                onChanged: (val) => setState(() => _consumptionLevel = val!),
              ),
              const SizedBox(height: 12),

              TextField(
                controller: _mealNoteCtrl,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Ghi chú chi tiết cho phụ huynh',
                  hintText: 'Hôm nay bé ăn rất tốt món cá hồi, canh bí đỏ ăn hết...',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 24),

              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.success,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.check_circle),
                label: const Text('Lưu khẩu phần ăn bán trú (MSG-211)'),
                onPressed: () async {
                  if (students.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Chưa có danh sách học sinh!'),
                        backgroundColor: Colors.red,
                      ),
                    );
                    return;
                  }
                  final studentId = _selectedMealStudentId ?? students.first.id;
                  final msg = await prov.recordMeal(
                    studentId: studentId,
                    mealType: _mealType,
                    portionEaten: _consumptionLevel,
                    note: _mealNoteCtrl.text.trim(),
                  );
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(msg ?? 'Lưu thành công'), backgroundColor: AppColors.success),
                    );
                  }
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}
