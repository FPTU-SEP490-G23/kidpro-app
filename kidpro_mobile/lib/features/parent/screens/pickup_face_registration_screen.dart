import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:kidpro_mobile/core/constants/app_colors.dart';
import 'package:kidpro_mobile/core/models/pickup_models.dart';
import 'package:kidpro_mobile/core/widgets/auth_network_image.dart';
import 'package:kidpro_mobile/features/parent/providers/parent_provider.dart';

/// Phụ huynh đăng ký ảnh khuôn mặt của mình và người đón thường xuyên,
/// để giáo viên quét mặt đối chiếu khi trả trẻ (BR-022).
class PickupFaceRegistrationScreen extends StatefulWidget {
  const PickupFaceRegistrationScreen({super.key});

  @override
  State<PickupFaceRegistrationScreen> createState() => _PickupFaceRegistrationScreenState();
}

class _PickupFaceRegistrationScreenState extends State<PickupFaceRegistrationScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ParentProvider>().loadPickupPersons();
    });
  }

  Future<void> _openUpload(PickupPerson person) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _FaceUploadSheet(person: person),
    );
    if (saved == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Đã lưu ảnh khuôn mặt của ${person.fullName}'),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<ParentProvider>();
    final persons = prov.pickupPersons;
    final registered = persons.where((p) => p.faceRegistered).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Khuôn mặt người đón'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: RefreshIndicator(
        onRefresh: () => prov.loadPickupPersons(),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.face_retouching_natural, color: AppColors.primary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Khi trả trẻ, cô giáo sẽ chụp mặt người đến đón để AI so khớp với ảnh đăng ký tại đây. '
                      'Người chưa có ảnh vẫn đón được nhưng cô phải gọi điện xác minh với bố mẹ.\n\n'
                      'Bé ${prov.selectedStudentName}: $registered/${persons.length} người đã có ảnh.',
                      style: const TextStyle(fontSize: 13, height: 1.35),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (prov.pickupPersonsLoading && persons.isEmpty)
              const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()))
            else if (persons.isEmpty)
              Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  prov.error ?? 'Chưa có người đón nào cho bé.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey.shade600),
                ),
              )
            else
              ...persons.map(_buildPersonCard),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () => context.push('/parent/guardians'),
              icon: const Icon(Icons.person_add_alt_1_outlined),
              label: const Text('Thêm người đón thường xuyên (ông bà, cô chú…)'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPersonCard(PickupPerson p) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: 64,
                height: 64,
                child: p.facePhotoUrl != null
                    ? AuthNetworkImage(url: p.facePhotoUrl!)
                    : Container(
                        color: Colors.grey.shade100,
                        child: Icon(Icons.person_outline, color: Colors.grey.shade400, size: 32),
                      ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(p.fullName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  const SizedBox(height: 2),
                  Text(
                    p.relationship ?? (p.isGuardian ? 'Người đón thường xuyên' : 'Phụ huynh'),
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(
                        p.faceRegistered ? Icons.check_circle : Icons.error_outline,
                        size: 15,
                        color: p.faceRegistered ? AppColors.success : AppColors.warning,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        p.faceRegistered ? 'Đã có ảnh khuôn mặt' : 'Chưa có ảnh khuôn mặt',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: p.faceRegistered ? AppColors.success : const Color(0xFF92400E),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            TextButton(
              onPressed: () => _openUpload(p),
              child: Text(p.faceRegistered ? 'Cập nhật' : 'Đăng ký'),
            ),
          ],
        ),
      ),
    );
  }
}

class _FaceUploadSheet extends StatefulWidget {
  final PickupPerson person;

  const _FaceUploadSheet({required this.person});

  @override
  State<_FaceUploadSheet> createState() => _FaceUploadSheetState();
}

class _FaceUploadSheetState extends State<_FaceUploadSheet> {
  Uint8List? _bytes;
  String _filename = 'face.jpg';
  bool _consent = false;
  bool _saving = false;
  String? _error;

  Future<void> _pick(ImageSource source) async {
    final picked = await ImagePicker().pickImage(
      source: source,
      // Phụ huynh tự chụp chân dung mình thì dùng camera trước
      preferredCameraDevice: widget.person.isGuardian ? CameraDevice.rear : CameraDevice.front,
      maxWidth: 1024,
      imageQuality: 85,
    );
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    if (!mounted) return;
    setState(() {
      _bytes = bytes;
      _filename = picked.name;
      _error = null;
    });
  }

  Future<void> _save() async {
    final bytes = _bytes;
    if (bytes == null) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    final error = await context.read<ParentProvider>().registerPickupFace(widget.person, bytes, _filename);
    if (!mounted) return;
    if (error == null) {
      Navigator.pop(context, true);
    } else {
      setState(() {
        _saving = false;
        _error = error;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Ảnh khuôn mặt: ${widget.person.fullName}',
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Text(
            'Chụp chính diện, đủ sáng, thấy rõ mắt mũi miệng. Không đeo khẩu trang, kính râm hay mũ che mặt.',
            style: TextStyle(fontSize: 12.5, color: Colors.grey.shade700),
          ),
          const SizedBox(height: 14),
          Center(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: SizedBox(
                width: 180,
                height: 240,
                child: _bytes != null
                    ? Image.memory(_bytes!, fit: BoxFit.cover)
                    : Container(
                        color: Colors.grey.shade100,
                        child: Icon(Icons.face_outlined, size: 72, color: Colors.grey.shade400),
                      ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _saving ? null : () => _pick(ImageSource.camera),
                  icon: const Icon(Icons.photo_camera_outlined),
                  label: const Text('Chụp ảnh'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _saving ? null : () => _pick(ImageSource.gallery),
                  icon: const Icon(Icons.photo_library_outlined),
                  label: const Text('Thư viện'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          BiometricConsentTile(
            value: _consent,
            onChanged: _saving ? null : (v) => setState(() => _consent = v),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: const TextStyle(color: AppColors.error, fontWeight: FontWeight.w600)),
          ],
          const SizedBox(height: 12),
          SizedBox(
            height: 48,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: (_bytes != null && _consent && !_saving) ? _save : null,
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Lưu ảnh khuôn mặt', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }
}

/// Ô đồng ý xử lý dữ liệu sinh trắc học theo Nghị định 13/2023/NĐ-CP.
class BiometricConsentTile extends StatelessWidget {
  final bool value;
  final ValueChanged<bool>? onChanged;

  const BiometricConsentTile({super.key, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return CheckboxListTile(
      value: value,
      onChanged: onChanged == null ? null : (v) => onChanged!(v ?? false),
      controlAffinity: ListTileControlAffinity.leading,
      contentPadding: EdgeInsets.zero,
      dense: true,
      title: const Text(
        'Tôi đồng ý và đã được người trong ảnh đồng ý cho nhà trường lưu ảnh khuôn mặt, '
        'chỉ dùng để xác thực người đón trẻ (Nghị định 13/2023/NĐ-CP). Có thể liên hệ nhà trường để yêu cầu xóa.',
        style: TextStyle(fontSize: 12, height: 1.35),
      ),
    );
  }
}
