import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:kidpro_mobile/core/constants/app_colors.dart';
import 'package:kidpro_mobile/features/parent/models/parent_models.dart';
import 'package:kidpro_mobile/features/parent/providers/parent_provider.dart';

class RequestsOverviewScreen extends StatefulWidget {
  const RequestsOverviewScreen({super.key});

  @override
  State<RequestsOverviewScreen> createState() => _RequestsOverviewScreenState();
}

class _RequestsOverviewScreenState extends State<RequestsOverviewScreen> {
  String _selectedFilter = 'ALL'; // ALL, PENDING, APPROVED, REJECTED

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ParentProvider>().loadAllRequests();
    });
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<ParentProvider>();
    final student = prov.selectedStudent;

    final filteredList = prov.allRequests.where((req) {
      if (_selectedFilter == 'ALL') return true;
      if (_selectedFilter == 'PENDING') {
        return req.status == 'PENDING' || req.status == 'CHO_DUYET';
      }
      if (_selectedFilter == 'APPROVED') {
        return req.status == 'APPROVED' || req.status == 'ACTIVE' || req.status == 'DA_DUYET';
      }
      if (_selectedFilter == 'REJECTED') {
        return req.status == 'REJECTED' ||
            req.status == 'CANCELLED' ||
            req.status == 'EXPIRED' ||
            req.status == 'TU_CHOI';
      }
      return true;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(student != null ? 'Đơn từ • ${student.fullName}' : 'Đơn từ của tôi'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Làm mới',
            onPressed: () => prov.loadAllRequests(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.accent,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Tạo đơn mới', style: TextStyle(fontWeight: FontWeight.bold)),
        onPressed: () => context.push('/parent/requests/center'),
      ),
      body: Column(
        children: [
          // Filter Chips Row
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: Colors.white,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterChip('ALL', 'Tất cả (${prov.allRequests.length})'),
                  const SizedBox(width: 8),
                  _buildFilterChip(
                    'PENDING',
                    'Chờ duyệt (${prov.allRequests.where((r) => r.status == "PENDING" || r.status == "CHO_DUYET").length})',
                  ),
                  const SizedBox(width: 8),
                  _buildFilterChip(
                    'APPROVED',
                    'Đã duyệt (${prov.allRequests.where((r) => r.status == "APPROVED" || r.status == "ACTIVE" || r.status == "DA_DUYET").length})',
                  ),
                  const SizedBox(width: 8),
                  _buildFilterChip('REJECTED', 'Từ chối / Hết hạn'),
                ],
              ),
            ),
          ),
          const Divider(height: 1),

          // List of Requests
          Expanded(
            child: prov.loading && prov.allRequests.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : filteredList.isEmpty
                    ? _buildEmptyView()
                    : RefreshIndicator(
                        onRefresh: () => prov.loadAllRequests(),
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: filteredList.length,
                          itemBuilder: (context, idx) {
                            final item = filteredList[idx];
                            return _buildRequestCard(item);
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String key, String label) {
    final isSelected = _selectedFilter == key;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: AppColors.primary,
      backgroundColor: Colors.grey.shade100,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : Colors.black87,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        fontSize: 12,
      ),
      onSelected: (selected) {
        if (selected) setState(() => _selectedFilter = key);
      },
    );
  }

  Widget _buildRequestCard(ParentUnifiedRequest item) {
    final isPending = item.status == 'PENDING' || item.status == 'CHO_DUYET';
    final isApproved =
        item.status == 'APPROVED' || item.status == 'ACTIVE' || item.status == 'DA_DUYET';

    Color statusColor = isPending
        ? AppColors.warning
        : (isApproved ? AppColors.success : AppColors.error);

    IconData typeIcon = _getIconForType(item.requestType);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                  child: Icon(typeIcon, size: 18, color: AppColors.primary),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.typeLabel,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      if (item.createdAt != null && item.createdAt!.isNotEmpty)
                        Text(
                          item.createdAt!.length >= 10
                              ? 'Ngày gửi: ${item.createdAt!.substring(0, 10)}'
                              : 'Ngày gửi: ${item.createdAt}',
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 11),
                        ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    item.statusLabel,
                    style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 11),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              item.title,
              style: const TextStyle(fontSize: 13, height: 1.3),
            ),
            if (item.metadata.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: item.metadata.entries.map((e) {
                  if (e.value == null || e.value.toString().isEmpty) {
                    return const SizedBox.shrink();
                  }
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '${e.key}: ${e.value}',
                      style: TextStyle(fontSize: 10, color: Colors.grey.shade700),
                    ),
                  );
                }).toList(),
              ),
            ],
            if (item.status != 'CANCELLED' &&
                item.status != 'REJECTED' &&
                item.status != 'TU_CHOI' &&
                ((item.requestType == 'BUS' && (isPending || isApproved)) || isPending)) ...[
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.error,
                      side: const BorderSide(color: AppColors.error),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      visualDensity: VisualDensity.compact,
                    ),
                    icon: const Icon(Icons.cancel_outlined, size: 14),
                    label: Text(
                      item.requestType == 'BUS' && isApproved
                          ? 'Dừng đăng ký xe buýt'
                          : 'Hủy đơn',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    onPressed: () => _confirmCancelRequest(item),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _confirmCancelRequest(ParentUnifiedRequest item) {
    final isBusActive = item.requestType == 'BUS' &&
        (item.status == 'APPROVED' || item.status == 'ACTIVE' || item.status == 'DA_DUYET');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          isBusActive ? 'Dừng đăng ký xe buýt' : 'Xác nhận hủy đơn',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Text(
          isBusActive
              ? 'Bạn có chắc chắn muốn dừng đăng ký dịch vụ xe buýt cho bé từ hôm nay không?'
              : 'Bạn có chắc chắn muốn hủy đơn "${item.title}" không?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Đóng'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              final prov = context.read<ParentProvider>();
              final success = await prov.cancelUnifiedRequest(item.id);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(success ? 'Thao tác thành công' : (prov.error ?? 'Lỗi khi hủy đơn')),
                    backgroundColor: success ? AppColors.success : AppColors.error,
                  ),
                );
              }
            },
            child: const Text('Xác nhận'),
          ),
        ],
      ),
    );
  }

  IconData _getIconForType(String type) {
    switch (type) {
      case 'LEAVE':
        return Icons.event_busy;
      case 'TRANSFER':
        return Icons.swap_horiz;
      case 'EMERGENCY_PICKUP':
        return Icons.qr_code_2;
      case 'GUARDIAN':
        return Icons.people_alt_outlined;
      case 'MEDICATION':
        return Icons.medication_outlined;
      case 'ALLERGY':
        return Icons.warning_amber_rounded;
      case 'BUS':
        return Icons.directions_bus_outlined;
      case 'MEAL':
        return Icons.breakfast_dining_outlined;
      case 'EXTRACURRICULAR':
        return Icons.palette_outlined;
      case 'DISPUTE':
        return Icons.receipt_long;
      case 'OTHER':
        return Icons.description_outlined;
      default:
        return Icons.assignment_outlined;
    }
  }

  Widget _buildEmptyView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 36,
              backgroundColor: AppColors.primary.withValues(alpha: 0.08),
              child: const Icon(Icons.assignment_turned_in_outlined, size: 36, color: AppColors.primary),
            ),
            const SizedBox(height: 16),
            const Text('Không có đơn từ nào', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(
              'Các đơn xin nghỉ học, dặn thuốc, chuyển lớp hoặc đón trẻ sẽ được quản lý tại đây.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () => context.push('/parent/requests/center'),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Tạo đơn đầu tiên'),
            ),
          ],
        ),
      ),
    );
  }
}
