import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:intl/intl.dart';
import 'package:kidpro_mobile/core/constants/app_colors.dart';
import 'package:kidpro_mobile/features/parent/models/parent_models.dart';
import 'package:kidpro_mobile/features/parent/providers/parent_provider.dart';
import 'package:kidpro_mobile/features/parent/screens/pickup_face_registration_screen.dart';

class EmergencyPickupScreen extends StatefulWidget {
  const EmergencyPickupScreen({super.key});

  @override
  State<EmergencyPickupScreen> createState() => _EmergencyPickupScreenState();
}

class _EmergencyPickupScreenState extends State<EmergencyPickupScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _formKey = GlobalKey<FormState>();

  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _pinCtrl = TextEditingController();

  bool _submitting = false;
  EmergencyPickup? _newlyCreated;

  // Ảnh chân dung người đón hộ (không bắt buộc) + đồng ý NĐ 13/2023
  Uint8List? _photoBytes;
  String _photoName = 'pickup_person.jpg';
  bool _photoConsent = false;

  Future<void> _pickPhoto(ImageSource source) async {
    final picked = await ImagePicker().pickImage(source: source, maxWidth: 1024, imageQuality: 85);
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    if (!mounted) return;
    setState(() {
      _photoBytes = bytes;
      _photoName = picked.name;
    });
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ParentProvider>().loadEmergencyPickups();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _pinCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleCreate() async {
    if (!_formKey.currentState!.validate()) return;
    if (_photoBytes != null && !_photoConsent) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng tích đồng ý lưu ảnh khuôn mặt, hoặc bỏ ảnh.')),
      );
      return;
    }

    setState(() => _submitting = true);
    final prov = context.read<ParentProvider>();
    final newPickup = EmergencyPickup(
      studentId: prov.selectedStudentId,
      studentName: prov.selectedStudentName,
      pickupPersonName: _nameCtrl.text.trim(),
      pickupPersonPhone: _phoneCtrl.text.trim(),
      pinCode: _pinCtrl.text.trim().isNotEmpty ? _pinCtrl.text.trim() : null,
      validUntil: DateTime.now().add(const Duration(minutes: 60)),
    );

    final result = await prov.createEmergencyPickup(
        newPickup, prov.selectedParentId ?? '');

    // Mã đã tạo; ảnh lỗi thì vẫn dùng được mã, chỉ báo cho phụ huynh biết
    String? photoError;
    final photo = _photoBytes;
    if (result != null && photo != null && result.authorizationId != null) {
      photoError = await prov.attachEmergencyPickupPhoto(result.authorizationId!, photo, _photoName);
    }
    if (!mounted) return;
    setState(() {
      _submitting = false;
      _newlyCreated = result;
    });

    if (result != null) {
      _nameCtrl.clear();
      _phoneCtrl.clear();
      _pinCtrl.clear();
      setState(() {
        _photoBytes = null;
        _photoConsent = false;
      });
      if (photoError != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Đã tạo mã nhưng chưa lưu được ảnh: $photoError'),
            backgroundColor: AppColors.warning,
          ),
        );
      }
      _showPickupSuccessDialog(result);
    }
  }

  void _showPickupSuccessDialog(EmergencyPickup pickup) {
    final messenger = ScaffoldMessenger.of(context);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: const [
                  Icon(Icons.check_circle, color: AppColors.success, size: 28),
                  SizedBox(width: 10),
                  Text('Mã đón khẩn cấp', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 10)
                  ],
                ),
                child: QrImageView(
                  data: pickup.qrData ?? 'KIDPRO_PICKUP:${pickup.authorizationId}:${pickup.studentId}',
                  version: QrVersions.auto,
                  size: 180,
                  backgroundColor: Colors.white,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Mã OTP: ${pickup.otpCode ?? pickup.pinCode ?? "Chưa thiết lập"}',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 4,
                  color: AppColors.primaryDark,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Người đón: ${pickup.pickupPersonName}',
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              ),
              Text(
                'Số điện thoại: ${pickup.pickupPersonPhone}',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.timer_outlined, color: Colors.red, size: 16),
                    SizedBox(width: 6),
                    Flexible(
                      child: Text('Hiệu lực 60 phút (dùng 1 lần duy nhất)',
                          style: TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _tabController.animateTo(1);
                    },
                    child: const Text('Xem danh sách'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(
                        text: 'Mã đón bé ${pickup.studentName} tại KidPro: OTP: ${pickup.otpCode}. Hiệu lực 60 phút.',
                      ));
                      messenger.showSnackBar(
                        const SnackBar(content: Text('Đã sao chép thông tin mã đón vào bộ nhớ tạm!')),
                      );
                      Navigator.pop(ctx);
                      _tabController.animateTo(1);
                    },
                    icon: const Icon(Icons.copy, size: 18),
                    label: const Text('Sao chép'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ủy quyền đón hộ đột xuất'),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: Colors.grey,
          indicatorColor: AppColors.primary,
          tabs: const [
            Tab(icon: Icon(Icons.qr_code_2), text: 'Tạo mã đón 60p'),
            Tab(icon: Icon(Icons.history), text: 'Lịch sử & Thu hồi'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildCreateTab(),
          _buildHistoryTab(),
        ],
      ),
    );
  }

  Widget _buildCreateTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Rule Notice
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.amber.shade300),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.security, color: Colors.amber, size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Quy định BR-022: Mã QR và mã PIN đón hộ đột xuất có hiệu lực tối đa 60 phút và chỉ sử dụng được duy nhất 01 lần tại cổng trường.',
                      style: TextStyle(color: Colors.amber.shade900, fontSize: 13, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Student Name info
            Consumer<ParentProvider>(
              builder: (_, prov, __) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.child_care, color: AppColors.primary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Học sinh: ${prov.selectedStudentName}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            const Text('Họ và tên người đón hộ *',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 8),
            TextFormField(
              controller: _nameCtrl,
              decoration: InputDecoration(
                hintText: 'Ví dụ: Bác Nguyễn Thị Mai (Hàng xóm)',
                prefixIcon: const Icon(Icons.person_outline),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              validator: (v) => v == null || v.trim().isEmpty ? 'Vui lòng nhập họ tên' : null,
            ),
            const SizedBox(height: 16),

            const Text('Số điện thoại người đón *',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 8),
            TextFormField(
              controller: _phoneCtrl,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                hintText: 'Ví dụ: 0912345678',
                prefixIcon: const Icon(Icons.phone_outlined),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Vui lòng nhập số điện thoại';
                if (v.trim().length < 9) return 'Số điện thoại không hợp lệ';
                return null;
              },
            ),
            const SizedBox(height: 16),

            const Text('Mã PIN xác thực bí mật (Tùy chọn, 4-6 số)',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 8),
            TextFormField(
              controller: _pinCtrl,
              keyboardType: TextInputType.number,
              maxLength: 6,
              decoration: InputDecoration(
                hintText: 'Để trống để hệ thống tự cấp ngẫu nhiên',
                prefixIcon: const Icon(Icons.lock_outline),
                counterText: '',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 16),

            // Ảnh chân dung người đón hộ để cô giáo quét mặt so khớp (BR-022)
            const Text('Ảnh chân dung người đón (Tùy chọn)',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 4),
            Text(
              'Có ảnh thì cô giáo quét mặt người đón để AI so khớp. Không có ảnh, cô sẽ gọi điện xác minh với bạn.',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: SizedBox(
                    width: 72,
                    height: 90,
                    child: _photoBytes != null
                        ? Image.memory(_photoBytes!, fit: BoxFit.cover)
                        : Container(
                            color: Colors.grey.shade100,
                            child: Icon(Icons.face_outlined, color: Colors.grey.shade400, size: 36),
                          ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      OutlinedButton.icon(
                        onPressed: _submitting ? null : () => _pickPhoto(ImageSource.camera),
                        icon: const Icon(Icons.photo_camera_outlined, size: 18),
                        label: const Text('Chụp ảnh'),
                      ),
                      OutlinedButton.icon(
                        onPressed: _submitting ? null : () => _pickPhoto(ImageSource.gallery),
                        icon: const Icon(Icons.photo_library_outlined, size: 18),
                        label: const Text('Chọn từ thư viện'),
                      ),
                      if (_photoBytes != null)
                        TextButton(
                          onPressed: _submitting
                              ? null
                              : () => setState(() {
                                    _photoBytes = null;
                                    _photoConsent = false;
                                  }),
                          child: const Text('Bỏ ảnh', style: TextStyle(color: AppColors.error)),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            if (_photoBytes != null)
              BiometricConsentTile(
                value: _photoConsent,
                onChanged: _submitting ? null : (v) => setState(() => _photoConsent = v),
              ),
            const SizedBox(height: 28),

            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: _submitting ? null : _handleCreate,
                icon: _submitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.qr_code),
                label: Text(
                  _submitting ? 'Đang tạo mã...' : 'Tạo mã QR đón khẩn cấp (60 Phút)',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryTab() {
    return Consumer<ParentProvider>(
      builder: (context, prov, child) {
        if (prov.emergencyPickups.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.qr_code_scanner, size: 64, color: Colors.grey.shade400),
                const SizedBox(height: 16),
                Text('Chưa có mã ủy quyền đón nào',
                    style: TextStyle(fontSize: 16, color: Colors.grey.shade600)),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () => prov.loadEmergencyPickups(),
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: prov.emergencyPickups.length,
            itemBuilder: (context, index) {
              final item = prov.emergencyPickups[index];
              final isActive = item.isActive;
              final dateFormat = DateFormat('HH:mm - dd/MM/yyyy');

              return Card(
                elevation: isActive ? 3 : 1,
                margin: const EdgeInsets.only(bottom: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(
                    color: isActive ? AppColors.primary.withOpacity(0.5) : Colors.grey.shade200,
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
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: isActive ? AppColors.success.withOpacity(0.15) : Colors.grey.shade200,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  isActive ? Icons.check_circle : Icons.cancel_outlined,
                                  size: 14,
                                  color: isActive ? AppColors.success : Colors.grey.shade600,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  isActive ? 'CÒN HIỆU LỰC' : (item.status == 'EXPIRED' ? 'ĐÃ HẾT HẠN' : 'ĐÃ ĐÓN'),
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: isActive ? AppColors.success : Colors.grey.shade700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (isActive && item.authorizationId != null)
                            TextButton.icon(
                              onPressed: () async {
                                final confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    title: const Text('Thu hồi mã đón?'),
                                    content: const Text('Bạn có chắc chắn muốn hủy hiệu lực mã đón này ngay lập tức?'),
                                    actions: [
                                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Không')),
                                      ElevatedButton(
                                        style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
                                        onPressed: () => Navigator.pop(ctx, true),
                                        child: const Text('Hủy mã ngay', style: TextStyle(color: Colors.white)),
                                      ),
                                    ],
                                  ),
                                );
                                if (confirm == true) {
                                  await prov.revokeEmergencyPickup(item.authorizationId!);
                                }
                              },
                              icon: const Icon(Icons.block, size: 16, color: AppColors.error),
                              label: const Text('Thu hồi', style: TextStyle(color: AppColors.error, fontSize: 13)),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(item.pickupPersonName,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text('SĐT: ${item.pickupPersonPhone}', style: TextStyle(color: Colors.grey.shade700)),
                      Text('Mã xác thực OTP: ${item.otpCode ?? "---"}',
                          style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.primary)),
                      const SizedBox(height: 4),
                      Text('Hết hạn lúc: ${dateFormat.format(item.validUntil)}',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}
