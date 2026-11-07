import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:kidpro_mobile/core/constants/app_colors.dart';
import 'package:kidpro_mobile/core/models/pickup_models.dart';
import 'package:kidpro_mobile/core/widgets/auth_network_image.dart';
import 'package:kidpro_mobile/features/teacher/models/teacher_models.dart';
import 'package:kidpro_mobile/features/teacher/providers/teacher_provider.dart';
import 'package:kidpro_mobile/features/teacher/widgets/pickup_face_check.dart';

/// Trả trẻ (G5-UC-04, BR-022): chọn người đến đón.
/// - Bố mẹ / người giám hộ chính: bấm "Bàn giao".
/// - Ông bà, cô chú, anh chị đã đăng ký mặt: quét mặt, khớp thì tự động bàn giao.
/// - Chưa đăng ký mặt / không khớp: không được bàn giao, hướng dẫn gọi bố mẹ.
/// Trả về thông báo thành công, hoặc null nếu giáo viên đóng bảng.
Future<String?> showPickupHandoverSheet(BuildContext context, TeacherStudent student) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (_) => _PickupHandoverSheet(student: student),
  );
}

class _PickupHandoverSheet extends StatefulWidget {
  final TeacherStudent student;

  const _PickupHandoverSheet({required this.student});

  @override
  State<_PickupHandoverSheet> createState() => _PickupHandoverSheetState();
}

class _PickupHandoverSheetState extends State<_PickupHandoverSheet> {
  List<PickupPerson>? _persons;
  String? _loadError;
  PickupPerson? _selected;
  PickupFaceVerification? _face;
  bool _submitting = false;
  String? _submitError;

  /// Bố mẹ của bé để giáo viên gọi khi không được bàn giao.
  List<({String name, String? phone})> get _parentContacts => (_persons ?? [])
      .where((p) => !p.faceRequired)
      .map((p) => (name: '${p.relationship ?? 'Phụ huynh'} ${p.fullName}', phone: p.phoneNumber))
      .toList();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final (persons, message) = await context.read<TeacherProvider>().loadPickupPersons(widget.student.id);
    if (!mounted) return;
    setState(() {
      _persons = persons;
      _loadError = persons == null ? message : null;
      if (persons != null && persons.length == 1) _selected = persons.first;
    });
  }

  void _select(PickupPerson person) {
    setState(() {
      _selected = person;
      _face = null;
      _submitError = null;
    });
  }

  void _onFaceResult(PickupFaceVerification? result) {
    setState(() {
      _face = result;
      _submitError = null;
    });
    // Khuôn mặt khớp: tự động bàn giao
    if (result != null && result.matched) _handover();
  }

  Future<void> _handover() async {
    final person = _selected;
    if (person == null || _submitting) return;
    setState(() {
      _submitting = true;
      _submitError = null;
    });
    final (success, message) = await context.read<TeacherProvider>().checkoutStudent(
          widget.student.id,
          guardianId: person.isGuardian ? person.guardianId : null,
          faceVerificationId: person.faceRequired ? _face?.verificationId : null,
        );
    if (!mounted) return;
    if (success) {
      Navigator.pop(context, message);
    } else {
      setState(() {
        _submitting = false;
        _submitError = message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      builder: (context, scrollCtrl) => ListView(
        controller: scrollCtrl,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 14),
          Text('Trả bé ${widget.student.fullName}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text('Chọn người đang đến đón bé', style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600)),
          const SizedBox(height: 16),
          ..._buildPersonList(),
          if (_selected != null) ...[
            const SizedBox(height: 16),
            ..._buildHandoverStep(_selected!),
          ],
          if (_submitError != null) ...[
            const SizedBox(height: 12),
            Text(_submitError!, style: const TextStyle(color: AppColors.error, fontWeight: FontWeight.w600)),
          ],
        ],
      ),
    );
  }

  List<Widget> _buildHandoverStep(PickupPerson person) {
    // Bố mẹ: bàn giao trực tiếp
    if (!person.faceRequired) {
      return [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.success.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.success.withValues(alpha: 0.4)),
          ),
          child: Row(
            children: [
              const Icon(Icons.verified_user_rounded, color: AppColors.success),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '${person.relationship ?? 'Phụ huynh'} của bé: bàn giao trực tiếp, không cần quét mặt.',
                  style: const TextStyle(fontSize: 13),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 52,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: _submitting ? null : _handover,
            icon: _submitting
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.how_to_reg_rounded),
            label: const Text('Bàn giao', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ),
        ),
      ];
    }

    // Ông bà, cô chú… chưa đăng ký mặt: không được đón
    if (!person.faceRegistered) {
      return [
        CallParentsCard(
          title: '${person.fullName} chưa đăng ký khuôn mặt nên không được đón bé.',
          parents: _parentContacts,
        ),
      ];
    }

    // Ông bà, cô chú… đã đăng ký mặt: quét mặt, khớp thì tự động bàn giao
    final face = _face;
    return [
      PickupFaceCheck(
        key: ValueKey(person.key),
        studentId: widget.student.id,
        personType: person.personType,
        personName: person.fullName,
        guardianId: person.guardianId,
        onResult: _onFaceResult,
      ),
      if (face != null && face.matched && _submitting) ...[
        const SizedBox(height: 14),
        const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
            SizedBox(width: 10),
            Text('Khuôn mặt khớp, đang bàn giao trẻ...', style: TextStyle(fontWeight: FontWeight.w600)),
          ],
        ),
      ],
      if (face != null && !face.matched) ...[
        const SizedBox(height: 14),
        CallParentsCard(
          title: face.hasReference
              ? 'Khuôn mặt không khớp với ảnh đã đăng ký của ${person.fullName}.'
              : '${person.fullName} chưa có ảnh khuôn mặt hợp lệ.',
          parents: _parentContacts,
        ),
      ],
      if (face == null) ...[
        const SizedBox(height: 10),
        Text(
          'Không quét được? Gọi bố mẹ của bé: '
          '${_parentContacts.map((p) => '${p.name}${p.phone != null ? ' (${p.phone})' : ''}').join(', ')}',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
        ),
      ],
    ];
  }

  List<Widget> _buildPersonList() {
    if (_loadError != null) {
      return [
        Text(_loadError!, style: const TextStyle(color: AppColors.error)),
        TextButton(onPressed: _load, child: const Text('Thử lại')),
      ];
    }
    final persons = _persons;
    if (persons == null) {
      return const [Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator()))];
    }
    if (persons.isEmpty) {
      return const [
        Text('Bé chưa có phụ huynh hay người đón nào trên hệ thống. Liên hệ BGH trước khi trả trẻ.',
            style: TextStyle(color: AppColors.error)),
      ];
    }
    return persons.map((p) {
      final selected = _selected?.key == p.key;
      return Card(
        elevation: 0,
        margin: const EdgeInsets.only(bottom: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: selected ? AppColors.primary : Colors.grey.shade300, width: selected ? 2 : 1),
        ),
        child: ListTile(
          onTap: _submitting ? null : () => _select(p),
          leading: ClipOval(
            child: SizedBox(
              width: 44,
              height: 44,
              child: p.facePhotoUrl != null
                  ? AuthNetworkImage(url: p.facePhotoUrl!)
                  : Container(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      child: const Icon(Icons.person, color: AppColors.primary),
                    ),
            ),
          ),
          title: Text(p.fullName, style: const TextStyle(fontWeight: FontWeight.w700)),
          subtitle: Text(
            '${p.relationship ?? (p.isGuardian ? 'Người đón thường xuyên' : 'Phụ huynh')}'
            '${p.phoneNumber != null ? '  •  ${p.phoneNumber}' : ''}',
            style: const TextStyle(fontSize: 12),
          ),
          trailing: _personBadge(p),
        ),
      );
    }).toList();
  }

  Widget _personBadge(PickupPerson p) {
    final String label;
    final Color color;
    if (!p.faceRequired) {
      label = 'Bàn giao\ntrực tiếp';
      color = AppColors.success;
    } else if (p.faceRegistered) {
      label = 'Quét mặt';
      color = const Color(0xFF7C3AED);
    } else {
      label = 'Chưa có\nảnh mặt';
      color = AppColors.error;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(label,
          textAlign: TextAlign.center, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w700)),
    );
  }
}
