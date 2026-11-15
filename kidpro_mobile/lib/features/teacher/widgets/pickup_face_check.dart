import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:kidpro_mobile/core/constants/app_colors.dart';
import 'package:kidpro_mobile/core/models/pickup_models.dart';
import 'package:kidpro_mobile/core/widgets/auth_network_image.dart';
import 'package:kidpro_mobile/features/teacher/providers/teacher_provider.dart';
import 'package:kidpro_mobile/features/teacher/screens/pickup_face_scan_screen.dart';

/// Quét mặt trực tiếp người đến đón và so khớp AI với ảnh phụ huynh đã đăng ký (BR-022).
/// Báo kết quả qua [onResult]; null khi chưa quét hoặc quét lỗi.
class PickupFaceCheck extends StatefulWidget {
  final String studentId;
  final String personType; // PARENT | GUARDIAN | EMERGENCY
  final String personName;
  final int? guardianId;
  final int? authorizationId;
  final ValueChanged<PickupFaceVerification?> onResult;

  const PickupFaceCheck({
    super.key,
    required this.studentId,
    required this.personType,
    required this.personName,
    this.guardianId,
    this.authorizationId,
    required this.onResult,
  });

  @override
  State<PickupFaceCheck> createState() => _PickupFaceCheckState();
}

class _PickupFaceCheckState extends State<PickupFaceCheck> {
  Uint8List? _photo;
  bool _livenessVerified = false;
  PickupFaceVerification? _result;
  String? _error;
  bool _busy = false;

  Future<void> _scan() async {
    // Mở toàn màn hình (che thanh điều hướng) để quét mặt trực tiếp
    final scan = await Navigator.of(context, rootNavigator: true).push<PickupFaceScanResult>(
      MaterialPageRoute(builder: (_) => PickupFaceScanScreen(personName: widget.personName)),
    );
    if (scan == null || !mounted) return;
    final bytes = scan.bytes;

    setState(() {
      _photo = bytes;
      _livenessVerified = scan.livenessVerified;
      _busy = true;
      _error = null;
      _result = null;
    });
    widget.onResult(null);

    final (result, message) = await context.read<TeacherProvider>().verifyPickupFace(
          studentId: widget.studentId,
          personType: widget.personType,
          guardianId: widget.guardianId,
          authorizationId: widget.authorizationId,
          photo: bytes,
        );
    if (!mounted) return;
    setState(() {
      _busy = false;
      _result = result;
      _error = result == null ? message : null;
    });
    widget.onResult(result);
  }

  @override
  Widget build(BuildContext context) {
    if (_busy) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Column(
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 10),
            Text('Đang so khớp khuôn mặt...', style: TextStyle(fontWeight: FontWeight.w600)),
          ],
        ),
      );
    }

    if (_photo == null) {
      return SizedBox(
        width: double.infinity,
        height: 50,
        child: ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF7C3AED),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onPressed: _scan,
          icon: const Icon(Icons.face_retouching_natural),
          label: const Text('Quét mặt người đón', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      );
    }

    final result = _result;
    final Color color;
    final IconData icon;
    final String title;
    if (result == null) {
      color = AppColors.error;
      icon = Icons.error_outline;
      title = 'Quét khuôn mặt không thành công';
    } else if (!result.hasReference) {
      color = AppColors.warning;
      icon = Icons.no_accounts_outlined;
      title = 'Chưa có ảnh đăng ký để so khớp';
    } else if (result.matched) {
      color = AppColors.success;
      icon = Icons.verified_user_rounded;
      title = 'Khuôn mặt khớp ${result.percent}%';
    } else {
      color = AppColors.error;
      icon = Icons.gpp_bad_rounded;
      title = 'KHÔNG KHỚP: chỉ ${result.percent}%';
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, color: color),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 15),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _photoBox('Ảnh đã đăng ký', result?.referencePhotoUrl, null)),
              const SizedBox(width: 10),
              Expanded(child: _photoBox('Ảnh vừa quét', null, _photo)),
            ],
          ),
          const SizedBox(height: 10),
          Text(result?.message ?? _error ?? '', style: const TextStyle(fontSize: 12.5, height: 1.35)),
          if (!_livenessVerified) ...[
            const SizedBox(height: 6),
            const Text(
              '⚠ Chụp tay, chưa xác thực chớp mắt: hãy chắc chắn đây là người thật, không phải ảnh trên điện thoại.',
              style: TextStyle(fontSize: 12, color: Color(0xFF92400E), fontWeight: FontWeight.w600),
            ),
          ],
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: _scan,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Quét lại'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _photoBox(String label, String? url, Uint8List? bytes) {
    Widget image;
    if (bytes != null) {
      image = Image.memory(bytes, fit: BoxFit.cover);
    } else if (url != null && url.isNotEmpty) {
      image = AuthNetworkImage(url: url);
    } else {
      image = Container(
        color: Colors.grey.shade200,
        child: Center(child: Icon(Icons.person_off_outlined, color: Colors.grey.shade400, size: 36)),
      );
    }
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: AspectRatio(aspectRatio: 3 / 4, child: image),
        ),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade700)),
      ],
    );
  }
}

/// Không được bàn giao (chưa đăng ký mặt / không khớp / AI lỗi): hướng dẫn cô gọi bố mẹ (BR-022).
class CallParentsCard extends StatelessWidget {
  final String title;
  final List<({String name, String? phone})> parents;

  const CallParentsCard({super.key, required this.title, required this.parents});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFCA5A5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.block_rounded, color: AppColors.error, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(title,
                    style: const TextStyle(color: Color(0xFF991B1B), fontWeight: FontWeight.bold, fontSize: 13.5)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text('Không bàn giao trẻ. Vui lòng gọi bố mẹ của bé:',
              style: TextStyle(fontSize: 12.5, color: Color(0xFF991B1B))),
          const SizedBox(height: 6),
          if (parents.isEmpty)
            const Text('(Chưa có số điện thoại bố mẹ trên hệ thống, liên hệ BGH)',
                style: TextStyle(fontSize: 12.5, fontStyle: FontStyle.italic))
          else
            ...parents.map((p) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    children: [
                      const Icon(Icons.phone_rounded, size: 16, color: AppColors.primary),
                      const SizedBox(width: 6),
                      Expanded(
                        child: SelectableText(
                          '${p.name}${p.phone != null ? ' – ${p.phone}' : ''}',
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
                        ),
                      ),
                    ],
                  ),
                )),
          const SizedBox(height: 4),
          Text(
            'Nếu bố mẹ đồng ý cho người này đón, bố mẹ tạo mã đón hộ trên app để cô quét ở tab "Đón hộ".',
            style: TextStyle(fontSize: 11.5, color: Colors.grey.shade700),
          ),
        ],
      ),
    );
  }
}
