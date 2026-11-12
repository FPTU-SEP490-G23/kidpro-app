import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:kidpro_mobile/core/constants/api_endpoints.dart';
import 'package:kidpro_mobile/core/constants/app_colors.dart';
import 'package:kidpro_mobile/core/network/api_client.dart';
import 'package:kidpro_mobile/features/parent/providers/parent_provider.dart';

/// UC-81: Phụ huynh xem các thông báo cô giáo gửi cho lớp của con.
class ClassAnnouncementsScreen extends StatefulWidget {
  const ClassAnnouncementsScreen({super.key});

  @override
  State<ClassAnnouncementsScreen> createState() => _ClassAnnouncementsScreenState();
}

class _ClassAnnouncementsScreenState extends State<ClassAnnouncementsScreen> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _items = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final studentId = context.read<ParentProvider>().selectedStudentId;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await ApiClient().dio.get(ApiEndpoints.parentClassAnnouncements(studentId));
      final data = res.data is Map ? res.data['data'] : res.data;
      _items = ((data as List?) ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } on DioException catch (e) {
      _error = (e.response?.data is Map ? e.response?.data['message']?.toString() : null) ??
          'Không tải được thông báo lớp.';
      _items = [];
    }
    if (mounted) setState(() => _loading = false);
  }

  String _fmt(dynamic v) {
    final d = DateTime.tryParse(v?.toString() ?? '')?.toLocal();
    if (d == null) return '';
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.hour)}:${two(d.minute)} ${two(d.day)}/${two(d.month)}/${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    final student = context.watch<ParentProvider>().selectedStudent;
    return Scaffold(
      appBar: AppBar(title: Text('Thông báo lớp ${student?.className ?? ''}')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? ListView(children: const [Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator()))])
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (_error != null) Text(_error!, style: const TextStyle(color: AppColors.error)),
                  if (_error == null && _items.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(child: Text('Lớp chưa có thông báo nào.', style: TextStyle(color: Colors.grey))),
                    ),
                  ..._items.map((a) => Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(a['title']?.toString() ?? '',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                              const SizedBox(height: 6),
                              Text(a['content']?.toString() ?? ''),
                              const SizedBox(height: 8),
                              Text('${a['postedBy'] ?? 'Giáo viên'} • ${_fmt(a['createdAt'])}',
                                  style: const TextStyle(color: Colors.grey, fontSize: 12)),
                            ],
                          ),
                        ),
                      )),
                ],
              ),
      ),
    );
  }
}
