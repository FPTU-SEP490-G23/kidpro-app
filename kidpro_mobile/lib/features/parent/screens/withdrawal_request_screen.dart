import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:kidpro_mobile/core/constants/api_endpoints.dart';
import 'package:kidpro_mobile/core/constants/app_colors.dart';
import 'package:kidpro_mobile/core/network/api_client.dart';
import 'package:kidpro_mobile/features/parent/providers/parent_provider.dart';

/// UC-26: Phụ huynh gửi đơn xin thôi học / chuyển trường và theo dõi trạng thái xử lý.
class WithdrawalRequestScreen extends StatefulWidget {
  const WithdrawalRequestScreen({super.key});

  @override
  State<WithdrawalRequestScreen> createState() => _WithdrawalRequestScreenState();
}

class _WithdrawalRequestScreenState extends State<WithdrawalRequestScreen> {
  static const _statusLabel = {
    'PENDING': ('CHỜ GIÁO VỤ XỬ LÝ', Colors.orange),
    'ACCOUNTING_APPROVED': ('ĐÃ ĐỐI SOÁT HỌC PHÍ', Colors.blue),
    'COMPLETED': ('ĐÃ HOÀN TẤT', Colors.green),
    'CANCELLED': ('ĐÃ HỦY', Colors.grey),
  };

  final _formKey = GlobalKey<FormState>();
  final _schoolCtrl = TextEditingController();
  final _reasonCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  DateTime? _expectedDate;
  bool _sending = false;
  bool _loading = true;
  List<Map<String, dynamic>> _history = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadHistory());
  }

  @override
  void dispose() {
    _schoolCtrl.dispose();
    _reasonCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  String _iso(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String _err(Object e, String fallback) {
    if (e is DioException && e.response?.data is Map && e.response?.data['message'] != null) {
      return e.response!.data['message'].toString();
    }
    return fallback;
  }

  Future<void> _loadHistory() async {
    final studentId = context.read<ParentProvider>().selectedStudentId;
    setState(() => _loading = true);
    try {
      final res = await ApiClient().dio.get(ApiEndpoints.parentWithdrawalRequests,
          queryParameters: {'studentId': studentId});
      final data = res.data is Map ? res.data['data'] : res.data;
      _history = ((data as List?) ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (_) {
      _history = [];
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xác nhận gửi đơn'),
        content: const Text(
            'Sau khi giáo vụ hoàn tất thủ tục, bé sẽ thôi học tại trường. Phụ huynh cần thanh toán hết công nợ học phí trước khi nhận hồ sơ.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Hủy')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Gửi đơn')),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    setState(() => _sending = true);
    final studentId = context.read<ParentProvider>().selectedStudentId;
    String msg;
    bool ok = false;
    try {
      final res = await ApiClient().dio.post(ApiEndpoints.parentWithdrawalRequests, data: {
        'studentId': studentId,
        'destinationSchool': _schoolCtrl.text.trim(),
        'reason': _reasonCtrl.text.trim(),
        if (_expectedDate != null) 'expectedDate': _iso(_expectedDate!),
        if (_notesCtrl.text.trim().isNotEmpty) 'notes': _notesCtrl.text.trim(),
      });
      msg = res.data['message']?.toString() ?? 'Đã gửi đơn.';
      ok = true;
      _schoolCtrl.clear();
      _reasonCtrl.clear();
      _notesCtrl.clear();
      _expectedDate = null;
    } catch (e) {
      msg = _err(e, 'Không gửi được đơn. Vui lòng thử lại.');
    }
    if (!mounted) return;
    setState(() => _sending = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: ok ? AppColors.success : AppColors.error),
    );
    if (ok) _loadHistory();
  }

  @override
  Widget build(BuildContext context) {
    final student = context.watch<ParentProvider>().selectedStudent;
    return Scaffold(
      appBar: AppBar(title: const Text('Thôi học / Chuyển trường')),
      body: RefreshIndicator(
        onRefresh: _loadHistory,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('Học sinh: ${student?.fullName ?? ''} (${student?.className ?? ''})',
                style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Form(
              key: _formKey,
              child: Column(
                children: [
                  TextFormField(
                    controller: _schoolCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Trường chuyển đến *',
                      hintText: 'Ghi "Không chuyển trường" nếu chỉ thôi học',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Trường tiếp nhận không được để trống' : null,
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _reasonCtrl,
                    maxLines: 3,
                    decoration: const InputDecoration(labelText: 'Lý do *', border: OutlineInputBorder()),
                    validator: (v) => (v == null || v.trim().length < 10) ? 'Vui lòng nhập lý do (tối thiểu 10 ký tự)' : null,
                  ),
                  const SizedBox(height: 10),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.event),
                    title: Text(_expectedDate == null
                        ? 'Ngày dự kiến nghỉ (mặc định sau 7 ngày)'
                        : 'Ngày dự kiến nghỉ: ${_expectedDate!.day}/${_expectedDate!.month}/${_expectedDate!.year}'),
                    onTap: () async {
                      final now = DateTime.now();
                      final d = await showDatePicker(
                        context: context,
                        initialDate: now.add(const Duration(days: 7)),
                        firstDate: now,
                        lastDate: now.add(const Duration(days: 180)),
                      );
                      if (d != null) setState(() => _expectedDate = d);
                    },
                  ),
                  TextFormField(
                    controller: _notesCtrl,
                    decoration: const InputDecoration(labelText: 'Ghi chú (tùy chọn)', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 14),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(48),
                    ),
                    onPressed: _sending ? null : _submit,
                    icon: _sending
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.send),
                    label: const Text('Gửi đơn cho nhà trường'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Text('Đơn đã gửi', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            if (_loading)
              const Center(child: CircularProgressIndicator())
            else if (_history.isEmpty)
              const Text('Chưa có đơn nào.', style: TextStyle(color: Colors.grey))
            else
              ..._history.map((h) {
                final st = _statusLabel[h['status']] ?? (h['status']?.toString() ?? '', Colors.grey);
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    title: Text('Chuyển đến: ${h['destinationSchool'] ?? ''}'),
                    subtitle: Text('Lý do: ${h['reason'] ?? ''}\nDự kiến: ${h['expectedDate'] ?? ''}'),
                    isThreeLine: true,
                    trailing: Text(st.$1, style: TextStyle(color: st.$2, fontWeight: FontWeight.bold, fontSize: 11)),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}
