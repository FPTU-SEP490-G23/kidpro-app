import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:kidpro_mobile/core/constants/api_endpoints.dart';
import 'package:kidpro_mobile/core/constants/app_colors.dart';
import 'package:kidpro_mobile/core/network/api_client.dart';
import 'package:kidpro_mobile/features/parent/providers/parent_provider.dart';

/// UC-44: Phụ huynh xem thực đơn đã duyệt trong ngày và ảnh khay cơm thực tế của lớp con.
class DailyMenuScreen extends StatefulWidget {
  const DailyMenuScreen({super.key});

  @override
  State<DailyMenuScreen> createState() => _DailyMenuScreenState();
}

class _DailyMenuScreenState extends State<DailyMenuScreen> {
  static const _mealLabel = {
    'BREAKFAST': 'Bữa sáng',
    'MORNING_SNACK': 'Bữa phụ sáng',
    'LUNCH': 'Bữa trưa',
    'AFTERNOON_SNACK': 'Bữa xế',
    'SNACK': 'Bữa phụ',
  };

  DateTime _date = DateTime.now();
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _dishes = [];
  List<Map<String, dynamic>> _trays = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  String get _iso =>
      '${_date.year}-${_date.month.toString().padLeft(2, '0')}-${_date.day.toString().padLeft(2, '0')}';

  Future<void> _load() async {
    final studentId = context.read<ParentProvider>().selectedStudentId;
    if (studentId.isEmpty) {
      setState(() {
        _loading = false;
        _error = 'Chưa chọn bé.';
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await ApiClient().dio.get(ApiEndpoints.parentDailyMenu(studentId), queryParameters: {'date': _iso});
      final data = (res.data is Map && res.data['data'] is Map) ? res.data['data'] as Map : const {};
      _dishes = ((data['dishes'] as List?) ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
      _trays = ((data['trayPhotos'] as List?) ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } on DioException catch (e) {
      _error = (e.response?.data is Map ? e.response?.data['message']?.toString() : null) ??
          'Không tải được thực đơn. Vui lòng thử lại.';
      _dishes = [];
      _trays = [];
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: now.subtract(const Duration(days: 60)),
      lastDate: now.add(const Duration(days: 7)),
    );
    if (d != null) {
      setState(() => _date = d);
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final student = context.watch<ParentProvider>().selectedStudent;
    final byMeal = <String, List<Map<String, dynamic>>>{};
    for (final d in _dishes) {
      byMeal.putIfAbsent(d['mealType']?.toString() ?? 'LUNCH', () => []).add(d);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Thực đơn & khay cơm'),
        actions: [IconButton(icon: const Icon(Icons.calendar_month), onPressed: _pickDate)],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('${student?.fullName ?? ''} • ${student?.className ?? ''}',
                style: const TextStyle(fontWeight: FontWeight.bold)),
            Text('Ngày ${_date.day.toString().padLeft(2, '0')}/${_date.month.toString().padLeft(2, '0')}/${_date.year}',
                style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 16),
            if (_loading)
              const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()))
            else if (_error != null)
              Text(_error!, style: const TextStyle(color: AppColors.error))
            else ...[
              Text('Thực đơn', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              if (_dishes.isEmpty)
                const Text('Chưa có thực đơn được duyệt cho ngày này.', style: TextStyle(color: Colors.grey))
              else
                ...byMeal.entries.map((e) => Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: const Icon(Icons.restaurant_menu, color: AppColors.primary),
                        title: Text(_mealLabel[e.key] ?? e.key, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(e.value
                            .map((d) => '${d['dishName']}${d['calories'] != null ? ' (${d['calories']} kcal)' : ''}')
                            .join('\n')),
                      ),
                    )),
              const SizedBox(height: 20),
              Text('Ảnh khay cơm thực tế của lớp', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              if (_trays.isEmpty)
                const Text('Cô giáo chưa đăng ảnh khay cơm cho ngày này.', style: TextStyle(color: Colors.grey))
              else
                ..._trays.map((t) => Card(
                      clipBehavior: Clip.antiAlias,
                      margin: const EdgeInsets.only(bottom: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Image.network(
                            t['photoUrl']?.toString() ?? '',
                            height: 200,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const SizedBox(
                              height: 80,
                              child: Center(child: Icon(Icons.broken_image, color: Colors.grey)),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(10),
                            child: Text(
                              '${_mealLabel[t['mealType']] ?? t['mealType']}'
                              '${(t['note'] ?? '').toString().isNotEmpty ? ' • ${t['note']}' : ''}',
                            ),
                          ),
                        ],
                      ),
                    )),
            ],
          ],
        ),
      ),
    );
  }
}
