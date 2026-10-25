import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:kidpro_mobile/core/constants/app_colors.dart';
import 'package:kidpro_mobile/features/parent/models/parent_models.dart';
import 'package:kidpro_mobile/features/parent/providers/parent_provider.dart';

class AuthorizedGuardiansScreen extends StatefulWidget {
  const AuthorizedGuardiansScreen({super.key});

  @override
  State<AuthorizedGuardiansScreen> createState() =>
      _AuthorizedGuardiansScreenState();
}

class _AuthorizedGuardiansScreenState extends State<AuthorizedGuardiansScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ParentProvider>().loadGuardians();
    });
  }

  void _showAddGuardianModal(BuildContext context) {
    final prov = context.read<ParentProvider>();
    final activeCount = prov.guardians.where((g) => g.isAllowedPickup).length;

    // BR-012 check: Max 3 authorized guardians
    if (activeCount >= 3) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Row(
            children: const [
              Icon(Icons.warning_amber_rounded, color: AppColors.warning, size: 28),
              SizedBox(width: 8),
              Text('Giới hạn người đón'),
            ],
          ),
          content: const Text(
            'Theo quy định BR-012 của nhà trường, mỗi học sinh chỉ được ủy quyền tối đa 03 người đón thường xuyên ngoài bố mẹ.\n\nQuý phụ huynh vui lòng thu hồi quyền của người đón cũ trước khi thêm người mới.',
            style: TextStyle(height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Đã hiểu'),
            ),
          ],
        ),
      );
      return;
    }

    final formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final noteCtrl = TextEditingController();
    String selectedRelation = 'Bà Ngoại';

    final relations = [
      'Bà Ngoại',
      'Bà Nội',
      'Ông Ngoại',
      'Ông Nội',
      'Bác Ruột',
      'Cô/Dì',
      'Chú/Cậu',
      'Tài xế xe đưa đón',
      'Người giúp việc',
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 24,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Thêm người đón thường xuyên',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Đang có $activeCount / 3 người đón ủy quyền (Quy tắc BR-012)',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                  ),
                  const SizedBox(height: 16),

                  const Text('Họ và tên người đón *',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: nameCtrl,
                    decoration: InputDecoration(
                      hintText: 'Ví dụ: Lê Thị Lan',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    validator: (v) => v == null || v.trim().isEmpty ? 'Vui lòng nhập họ tên' : null,
                  ),
                  const SizedBox(height: 14),

                  const Text('Số điện thoại *',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: phoneCtrl,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                      hintText: 'Ví dụ: 0908123456',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    validator: (v) => v == null || v.trim().length < 9 ? 'SĐT không hợp lệ' : null,
                  ),
                  const SizedBox(height: 14),

                  const Text('Mối quan hệ với học sinh *',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    value: selectedRelation,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    items: relations
                        .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                        .toList(),
                    onChanged: (v) => setModalState(() => selectedRelation = v!),
                  ),
                  const SizedBox(height: 14),

                  const Text('Ghi chú giờ đón / lưu ý',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: noteCtrl,
                    maxLines: 2,
                    decoration: InputDecoration(
                      hintText: 'Ví dụ: Đón bé các buổi chiều Thứ Ba và Thứ Năm',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 24),

                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: () async {
                        if (!formKey.currentState!.validate()) return;
                        final guardian = AuthorizedGuardian(
                          studentId: prov.selectedStudentId,
                          fullName: nameCtrl.text.trim(),
                          phoneNumber: phoneCtrl.text.trim(),
                          relationshipToStudent: selectedRelation,
                          note: noteCtrl.text.trim().isNotEmpty ? noteCtrl.text.trim() : null,
                          isAllowedPickup: true,
                          createdAt: DateTime.now(),
                        );
                        Navigator.pop(ctx);
                        final success = await prov.registerGuardian(guardian);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(success ? 'Thêm người đón thành công!' : 'Thất bại'),
                              backgroundColor: success ? AppColors.success : AppColors.error,
                            ),
                          );
                        }
                      },
                      child: const Text('Xác nhận đăng ký người đón',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd/MM/yyyy');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Người đón thường xuyên'),
      ),
      body: Consumer<ParentProvider>(
        builder: (context, prov, child) {
          final activeCount = prov.guardians.where((g) => g.isAllowedPickup).length;

          return Column(
            children: [
              // Rule banner
              Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.primary.withOpacity(0.25)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.shield_outlined, color: AppColors.primary, size: 28),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Quy định an toàn trả trẻ BR-012',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: AppColors.primaryDark,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Tối đa 03 người được ủy quyền đón ngoài bố mẹ. Hiện tại: $activeCount / 3 người.',
                            style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              Expanded(
                child: prov.guardians.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.people_outline, size: 64, color: Colors.grey.shade400),
                            const SizedBox(height: 16),
                            Text('Chưa có người đón ủy quyền nào',
                                style: TextStyle(fontSize: 16, color: Colors.grey.shade600)),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: () => prov.loadGuardians(),
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: prov.guardians.length,
                          itemBuilder: (context, index) {
                            final g = prov.guardians[index];
                            final isAllowed = g.isAllowedPickup;

                            return Card(
                              margin: const EdgeInsets.only(bottom: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                                side: BorderSide(
                                  color: isAllowed
                                      ? Colors.grey.shade300
                                      : Colors.red.shade100,
                                ),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Row(
                                          children: [
                                            CircleAvatar(
                                              backgroundColor: isAllowed
                                                  ? AppColors.primary.withOpacity(0.12)
                                                  : Colors.grey.shade200,
                                              child: Icon(
                                                Icons.person,
                                                color: isAllowed
                                                    ? AppColors.primary
                                                    : Colors.grey.shade500,
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  g.fullName,
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 16,
                                                  ),
                                                ),
                                                Text(
                                                  'Quan hệ: ${g.relationshipToStudent}',
                                                  style: TextStyle(
                                                    color: Colors.grey.shade600,
                                                    fontSize: 13,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: isAllowed
                                                ? AppColors.success.withOpacity(0.15)
                                                : Colors.red.shade50,
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            isAllowed ? 'ĐƯỢC ĐÓN' : 'ĐÃ THU HỒI',
                                            style: TextStyle(
                                              color: isAllowed
                                                  ? AppColors.success
                                                  : AppColors.error,
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const Divider(height: 24),
                                    Row(
                                      children: [
                                        const Icon(Icons.phone, size: 16, color: Colors.grey),
                                        const SizedBox(width: 6),
                                        Text(g.phoneNumber,
                                            style: const TextStyle(fontWeight: FontWeight.w600)),
                                      ],
                                    ),
                                    if (g.note != null && g.note!.isNotEmpty) ...[
                                      const SizedBox(height: 6),
                                      Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Icon(Icons.notes, size: 16, color: Colors.grey),
                                          const SizedBox(width: 6),
                                          Expanded(
                                            child: Text(
                                              g.note!,
                                              style: TextStyle(
                                                  color: Colors.grey.shade700, fontSize: 13),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                    if (isAllowed && g.guardianId != null) ...[
                                      const SizedBox(height: 12),
                                      Align(
                                        alignment: Alignment.centerRight,
                                        child: OutlinedButton.icon(
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor: AppColors.error,
                                            side: const BorderSide(color: AppColors.error),
                                            shape: RoundedRectangleBorder(
                                                borderRadius: BorderRadius.circular(10)),
                                          ),
                                          onPressed: () async {
                                            final confirm = await showDialog<bool>(
                                              context: context,
                                              builder: (ctx) => AlertDialog(
                                                title: const Text('Thu hồi quyền đón?'),
                                                content: Text(
                                                    'Bạn có chắc chắn muốn ngừng cho phép ${g.fullName} đón bé?'),
                                                actions: [
                                                  TextButton(
                                                    onPressed: () => Navigator.pop(ctx, false),
                                                    child: const Text('Không'),
                                                  ),
                                                  ElevatedButton(
                                                    style: ElevatedButton.styleFrom(
                                                        backgroundColor: AppColors.error),
                                                    onPressed: () => Navigator.pop(ctx, true),
                                                    child: const Text('Thu hồi ngay',
                                                        style: TextStyle(color: Colors.white)),
                                                  ),
                                                ],
                                              ),
                                            );
                                            if (confirm == true) {
                                              await prov.revokeGuardian(g.guardianId!);
                                            }
                                          },
                                          icon: const Icon(Icons.person_remove, size: 16),
                                          label: const Text('Thu hồi quyền đón',
                                              style: TextStyle(fontSize: 13)),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
              ),

              // Bottom add button
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, -2))
                  ],
                ),
                child: SafeArea(
                  child: SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: () => _showAddGuardianModal(context),
                      icon: const Icon(Icons.person_add),
                      label: Text(
                        'Thêm người đón mới ($activeCount/3)',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
