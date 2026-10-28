import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:kidpro_mobile/core/constants/app_colors.dart';
import 'package:kidpro_mobile/features/parent/models/parent_models.dart';
import 'package:kidpro_mobile/features/parent/providers/parent_provider.dart';

class ParentNotificationScreen extends StatefulWidget {
  const ParentNotificationScreen({super.key});

  @override
  State<ParentNotificationScreen> createState() => _ParentNotificationScreenState();
}

class _ParentNotificationScreenState extends State<ParentNotificationScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ParentProvider>().loadNotifications();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String _formatDateTime(String? raw) {
    if (raw == null || raw.isEmpty) return '';
    try {
      final dt = DateTime.parse(raw);
      return DateFormat('HH:mm - dd/MM/yyyy').format(dt);
    } catch (_) {
      return raw;
    }
  }

  Color _getTypeColor(String type) {
    switch (type.toUpperCase()) {
      case 'BILLING':
        return Colors.orange.shade700;
      case 'ATTENDANCE':
        return Colors.blue.shade700;
      case 'REQUEST':
        return Colors.teal.shade700;
      case 'ANNOUNCEMENT':
        return Colors.purple.shade700;
      default:
        return AppColors.primary;
    }
  }

  IconData _getTypeIcon(String type) {
    switch (type.toUpperCase()) {
      case 'BILLING':
        return Icons.receipt_long_rounded;
      case 'ATTENDANCE':
        return Icons.badge_outlined;
      case 'REQUEST':
        return Icons.assignment_turned_in_outlined;
      case 'ANNOUNCEMENT':
        return Icons.campaign_rounded;
      default:
        return Icons.notifications_active_rounded;
    }
  }

  String _getTypeLabel(String type) {
    switch (type.toUpperCase()) {
      case 'BILLING':
        return 'Học phí';
      case 'ATTENDANCE':
        return 'Điểm danh';
      case 'REQUEST':
        return 'Đơn từ';
      case 'ANNOUNCEMENT':
        return 'Tin nhà trường';
      default:
        return 'Thông báo';
    }
  }

  void _showNotificationDetail(BuildContext context, NotificationItem item) {
    if (!item.isRead) {
      context.read<ParentProvider>().markNotificationAsRead(item.notificationId);
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: _getTypeColor(item.type).withValues(alpha: 0.15),
                  child: Icon(_getTypeIcon(item.type), color: _getTypeColor(item.type), size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: _getTypeColor(item.type).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          _getTypeLabel(item.type),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: _getTypeColor(item.type),
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _formatDateTime(item.createdAt),
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              item.title,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Text(
                item.body,
                style: const TextStyle(
                  fontSize: 14,
                  height: 1.5,
                  color: Colors.black87,
                ),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('Đóng', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final parentProv = context.watch<ParentProvider>();
    final allNotifications = parentProv.notifications;
    final unreadNotifications = allNotifications.where((n) => !n.isRead).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Thông báo', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          if (parentProv.unreadNotificationCount > 0)
            TextButton.icon(
              onPressed: () async {
                final messenger = ScaffoldMessenger.of(context);
                await parentProv.markAllNotificationsAsRead();
                if (!mounted) return;
                messenger.showSnackBar(
                  const SnackBar(
                    content: Text('Đã đánh dấu tất cả thông báo là đã đọc'),
                    duration: Duration(seconds: 2),
                  ),
                );
              },
              icon: const Icon(Icons.done_all, color: Colors.white, size: 18),
              label: const Text(
                'Đọc tất cả',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13),
              ),
            ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          tabs: [
            Tab(text: 'Tất cả (${allNotifications.length})'),
            Tab(text: 'Chưa đọc (${unreadNotifications.length})'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildNotificationList(allNotifications, parentProv),
          _buildNotificationList(unreadNotifications, parentProv),
        ],
      ),
    );
  }

  Widget _buildNotificationList(List<NotificationItem> list, ParentProvider prov) {
    if (list.isEmpty) {
      return RefreshIndicator(
        onRefresh: () => prov.loadNotifications(),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(height: MediaQuery.of(context).size.height * 0.25),
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.notifications_off_outlined, size: 64, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  Text(
                    'Không có thông báo nào',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Các cập nhật học tập, điểm danh và học phí sẽ xuất hiện ở đây',
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => prov.loadNotifications(),
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        itemCount: list.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (ctx, index) {
          final item = list[index];
          final typeColor = _getTypeColor(item.type);
          final typeIcon = _getTypeIcon(item.type);

          return Material(
            color: item.isRead ? Colors.white : Colors.blue.shade50.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(12),
            elevation: item.isRead ? 0.5 : 1.5,
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => _showNotificationDetail(context, item),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: item.isRead ? Colors.grey.shade200 : AppColors.primary.withValues(alpha: 0.3),
                    width: item.isRead ? 1 : 1.2,
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: typeColor.withValues(alpha: 0.12),
                      child: Icon(typeIcon, color: typeColor, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: typeColor.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  _getTypeLabel(item.type),
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: typeColor,
                                  ),
                                ),
                              ),
                              const Spacer(),
                              if (!item.isRead)
                                Container(
                                  width: 8,
                                  height: 8,
                                  margin: const EdgeInsets.only(right: 6),
                                  decoration: const BoxDecoration(
                                    color: AppColors.primary,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              Text(
                                _formatDateTime(item.createdAt),
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey.shade500,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            item.title,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: item.isRead ? FontWeight.w600 : FontWeight.bold,
                              color: Colors.black87,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            item.body,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade700,
                              height: 1.35,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
