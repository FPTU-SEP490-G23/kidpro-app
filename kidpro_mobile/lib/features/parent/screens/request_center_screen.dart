import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:kidpro_mobile/core/constants/app_colors.dart';
import 'package:kidpro_mobile/features/parent/providers/parent_provider.dart';

class RequestCenterScreen extends StatefulWidget {
  const RequestCenterScreen({super.key});

  @override
  State<RequestCenterScreen> createState() => _RequestCenterScreenState();
}

class _RequestCenterScreenState extends State<RequestCenterScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ParentProvider>().loadFormOptions();
    });
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<ParentProvider>();
    final student = prov.selectedStudent;

    final List<_RequestCategoryItem> items = [
      _RequestCategoryItem(
        title: 'Đơn xin nghỉ học',
        subtitle: 'Hoàn tiền ăn theo BR-064 khi gửi trước 08:00 sáng',
        icon: Icons.event_busy,
        color: AppColors.warning,
        badge: 'G10-UC-08',
        onTap: () => context.push('/parent/leave'),
      ),
      _RequestCategoryItem(
        title: 'Đơn xin chuyển lớp',
        subtitle: 'Chuyển lớp học trong niên khóa cho học sinh',
        icon: Icons.swap_horiz,
        color: AppColors.primary,
        badge: 'G4-UC-04',
        onTap: () => _showClassTransferDialog(context, prov),
      ),
      _RequestCategoryItem(
        title: 'Mã QR đón hộ đột xuất',
        subtitle: 'Ủy quyền đón khẩn cấp hiệu lực 60 phút (BR-022)',
        icon: Icons.qr_code_2,
        color: Colors.deepOrange,
        badge: 'G5-UC-07',
        onTap: () => context.push('/parent/emergency-pickup'),
      ),
      _RequestCategoryItem(
        title: 'Người đón thường xuyên',
        subtitle: 'Đăng ký tối đa 3 người thân đón bé (BR-012)',
        icon: Icons.people_alt_outlined,
        color: Colors.purple,
        badge: 'G4-UC-03',
        onTap: () => context.push('/parent/guardians'),
      ),
      _RequestCategoryItem(
        title: 'Phiếu dặn uống thuốc',
        subtitle: 'Kê toa y tế, liều lượng và giờ uống cho cô',
        icon: Icons.medication_outlined,
        color: AppColors.success,
        badge: 'G10-UC-01',
        onTap: () => context.push('/parent/medication'),
      ),
      _RequestCategoryItem(
        title: 'Phiếu khai báo dị ứng',
        subtitle: 'Liên thông Bếp ăn & Y tế cảnh báo thực phẩm/thuốc',
        icon: Icons.warning_amber_rounded,
        color: AppColors.error,
        badge: 'G4-UC-06',
        onTap: () => context.push('/parent/allergies'),
      ),
      _RequestCategoryItem(
        title: 'Đăng ký xe buýt đưa đón',
        subtitle: 'Dịch vụ xe tuyến đưa đón tận nhà an toàn',
        icon: Icons.directions_bus_outlined,
        color: Colors.blue,
        badge: 'G4-UC-07',
        onTap: () => _showBusRegisterDialog(context, prov),
      ),
      _RequestCategoryItem(
        title: 'Đăng ký ăn sáng tại trường',
        subtitle: 'Dịch vụ ăn sáng bán trú dinh dưỡng tại trường',
        icon: Icons.breakfast_dining_outlined,
        color: Colors.orange,
        badge: 'Bán trú',
        onTap: () => _showMealRegisterDialog(context, prov),
      ),
      _RequestCategoryItem(
        title: 'Đăng ký lớp năng khiếu',
        subtitle: 'Vẽ, múa, võ thuật, âm nhạc, cờ vua ngoài giờ',
        icon: Icons.palette_outlined,
        color: Colors.teal,
        badge: 'G9-UC-03',
        onTap: () => _showExtracurricularDialog(context, prov),
      ),
      _RequestCategoryItem(
        title: 'Khiếu nại học phí',
        subtitle: 'Đối soát và phản hồi sai sót các khoản thu',
        icon: Icons.receipt_long,
        color: Colors.indigo,
        badge: 'G8-UC-10',
        onTap: () => context.push('/parent/invoices'),
      ),
      _RequestCategoryItem(
        title: 'Đề nghị hành chính khác',
        subtitle: 'Giấy xác nhận học sinh, sổ liên lạc, bảo hiểm...',
        icon: Icons.description_outlined,
        color: Colors.blueGrey,
        badge: 'G4-UC-05',
        onTap: () => _showOtherRequestDialog(context, prov),
      ),
      _RequestCategoryItem(
        title: 'Đơn thôi học / chuyển trường',
        subtitle: 'Gửi đơn rút hồ sơ, theo dõi giáo vụ xử lý',
        icon: Icons.logout,
        color: Colors.brown,
        badge: 'UC-26',
        onTap: () => context.push('/parent/withdrawal'),
      ),
      _RequestCategoryItem(
        title: 'Quyền riêng tư AI (NĐ 13)',
        subtitle: 'Yêu cầu xóa toàn bộ dữ liệu sinh trắc học khuôn mặt',
        icon: Icons.shield_outlined,
        color: Colors.red.shade900,
        badge: 'NĐ 13/2023',
        onTap: () => context.push('/parent/biometric-purge'),
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Trung tâm tạo đơn & yêu cầu'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                const Icon(Icons.child_care, color: AppColors.primary, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Học sinh đang chọn:',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      Text(
                        student?.fullName ?? 'Chưa chọn học sinh',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      Text(
                        'Lớp: ${student?.className ?? "Chưa xếp"} • Mã HS: ${student?.studentCode ?? ""}',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'Chọn loại đơn hoặc thủ tục cần nộp (11 loại):',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
          const SizedBox(height: 12),
          ...items.map((item) => _buildItemCard(item)),
        ],
      ),
    );
  }

  Widget _buildItemCard(_RequestCategoryItem item) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      elevation: 0.8,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          radius: 22,
          backgroundColor: item.color.withValues(alpha: 0.12),
          child: Icon(item.icon, color: item.color, size: 22),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(item.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                item.badge,
                style: TextStyle(fontSize: 10, color: Colors.grey.shade700, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            item.subtitle,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
        ),
        trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
        onTap: item.onTap,
      ),
    );
  }

  // ==========================================
  // FORM 1: CHUYỂN LỚP (G4-UC-04)
  // ==========================================
  void _showClassTransferDialog(BuildContext context, ParentProvider prov) {
    String? selectedToClassId =
        prov.availableClasses.isNotEmpty ? prov.availableClasses.first.id : null;
    final reasonCtrl = TextEditingController();
    String? errorMsg;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Đơn xin chuyển lớp học',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  IconButton(onPressed: () => Navigator.pop(ctx), icon: const Icon(Icons.close)),
                ],
              ),
              const SizedBox(height: 12),
              const Text('Lớp học mong muốn chuyển đến *',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 6),
              if (prov.availableClasses.isEmpty)
                const Text('Đang tải danh sách các lớp...', style: TextStyle(color: Colors.grey))
              else
                DropdownButtonFormField<String>(
                  value: selectedToClassId,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  items: prov.availableClasses
                      .map((c) => DropdownMenuItem(
                            value: c.id,
                            child: Text(c.subtitle != null ? '${c.title} (${c.subtitle})' : c.title),
                          ))
                      .toList(),
                  onChanged: (v) => setModalState(() => selectedToClassId = v),
                ),
              const SizedBox(height: 12),
              const Text('Lý do xin chuyển lớp *',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 6),
              TextField(
                controller: reasonCtrl,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'Nhập nguyện vọng, lý do chuyển lớp...',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              if (errorMsg != null) ...[
                const SizedBox(height: 12),
                Text(errorMsg!,
                    style: const TextStyle(color: AppColors.error, fontWeight: FontWeight.w600)),
              ],
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () async {
                    // Lỗi hiển thị ngay trong form vì SnackBar của màn hình bị bottom sheet che.
                    if (selectedToClassId == null || reasonCtrl.text.trim().isEmpty) {
                      setModalState(() => errorMsg = 'Vui lòng chọn lớp và nhập lý do!');
                      return;
                    }
                    final current = prov.selectedStudent;
                    final toClass =
                        prov.availableClasses.where((c) => c.id == selectedToClassId).firstOrNull;
                    final sameClass = (current?.classId != null &&
                            current!.classId == selectedToClassId) ||
                        (current?.className != null && toClass?.title == current!.className);
                    if (sameClass) {
                      setModalState(() => errorMsg = 'Chọn lớp khác lớp hiện tại');
                      return;
                    }
                    setModalState(() => errorMsg = null);
                    final success = await prov.submitClassTransfer(
                      studentId: prov.selectedStudentId,
                      toClassId: selectedToClassId!,
                      reason: reasonCtrl.text.trim(),
                    );
                    if (!ctx.mounted) return;
                    if (!success) {
                      setModalState(() => errorMsg = prov.error ?? 'Nộp đơn chuyển lớp thất bại');
                      return;
                    }
                    Navigator.pop(ctx);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Nộp đơn xin chuyển lớp thành công!')),
                      );
                    }
                  },
                  child: const Text('Gửi đơn xin chuyển lớp',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==========================================
  // FORM 2: ĐĂNG KÝ XE BUÝT (G4-UC-07)
  // ==========================================
  void _showBusRegisterDialog(BuildContext context, ParentProvider prov) {
    String? selectedBusId =
        prov.availableBuses.isNotEmpty ? prov.availableBuses.first.id : null;
    String? selectedStopId;
    String pickupType = 'TWO_WAY';
    final addressCtrl = TextEditingController();
    final noteCtrl = TextEditingController();

    if (selectedBusId != null) {
      prov.loadBusStops(selectedBusId);
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Đăng ký xe buýt đưa đón',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    IconButton(onPressed: () => Navigator.pop(ctx), icon: const Icon(Icons.close)),
                  ],
                ),
                const SizedBox(height: 12),
                const Text('Chọn tuyến xe buýt *',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 6),
                if (prov.availableBuses.isEmpty)
                  const Text('Chưa có danh sách tuyến xe buýt', style: TextStyle(color: Colors.grey))
                else
                  DropdownButtonFormField<String>(
                    value: selectedBusId,
                    isExpanded: true,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    items: prov.availableBuses
                        .map((b) => DropdownMenuItem(
                              value: b.id,
                              child: Text(b.title, overflow: TextOverflow.ellipsis),
                            ))
                        .toList(),
                    onChanged: (v) {
                      setModalState(() {
                        selectedBusId = v;
                        selectedStopId = null;
                      });
                      if (v != null) {
                        prov.loadBusStops(v).then((_) {
                          if (ctx.mounted) {
                            setModalState(() {});
                          }
                        });
                      }
                    },
                  ),
                const SizedBox(height: 12),

                // Chọn điểm dừng (Bus Stop từ Database API)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Chọn điểm dừng đón/trả (Bus Stop) *',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    if (prov.loadingStops)
                      const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                if (prov.currentBusStops.isEmpty && !prov.loadingStops)
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.amber.shade300),
                    ),
                    child: const Text(
                      'Tuyến xe chưa cấu hình trạm dừng cố định trên hệ thống. Vui lòng nhập địa chỉ bên dưới.',
                      style: TextStyle(fontSize: 12, color: Colors.brown),
                    ),
                  )
                else
                  DropdownButtonFormField<String>(
                    value: selectedStopId,
                    isExpanded: true,
                    decoration: InputDecoration(
                      hintText: prov.loadingStops ? 'Đang tải điểm dừng...' : 'Chọn trạm đón/trả học sinh',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    items: prov.currentBusStops
                        .map((s) => DropdownMenuItem(
                              value: s.stopId,
                              child: Text(
                                'Trạm ${s.stopOrder}: ${s.stopName} (${s.estimatedTime})',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ))
                        .toList(),
                    onChanged: (v) {
                      setModalState(() => selectedStopId = v);
                      if (v != null) {
                        final found = prov.currentBusStops.firstWhere(
                          (s) => s.stopId == v,
                          orElse: () => prov.currentBusStops.first,
                        );
                        if (found.stopAddress.isNotEmpty) {
                          addressCtrl.text = '${found.stopName} - ${found.stopAddress}';
                        }
                      }
                    },
                  ),
                const SizedBox(height: 12),

                const Text('Hình thức đưa đón *',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  value: pickupType,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'TWO_WAY', child: Text('Hai chiều (Đưa & Đón)')),
                    DropdownMenuItem(value: 'ONE_WAY_MORNING', child: Text('Một chiều (Chỉ đón sáng)')),
                    DropdownMenuItem(value: 'ONE_WAY_AFTERNOON', child: Text('Một chiều (Chỉ trả chiều)')),
                  ],
                  onChanged: (v) => setModalState(() => pickupType = v ?? 'TWO_WAY'),
                ),
                const SizedBox(height: 12),
                const Text('Địa chỉ đón/trả trẻ tận nơi *',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 6),
                TextField(
                  controller: addressCtrl,
                  decoration: InputDecoration(
                    hintText: 'Số nhà, tên đường, phường/xã...',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 12),
                const Text('Ghi chú dặn dò lái xe / phụ xe',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 6),
                TextField(
                  controller: noteCtrl,
                  decoration: InputDecoration(
                    hintText: 'Bé say xe, cần đón sớm...',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () async {
                      if (selectedBusId == null || addressCtrl.text.trim().isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Vui lòng chọn tuyến xe và nhập địa chỉ đón!')),
                        );
                        return;
                      }
                      final hasExistingBus = prov.allRequests.any((r) =>
                          (r.studentId == null || r.studentId == prov.selectedStudentId) &&
                          (r.requestType == 'BUS' || r.requestType == 'BUS_REGISTRATION' || r.type == 'BUS' || r.type == 'BUS_REGISTRATION') &&
                          (r.status == 'PENDING' || r.status == 'APPROVED' || r.status == 'CHO_DUYET' || r.status == 'DA_DUYET'));
                      if (hasExistingBus) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Học sinh đã có 01 đơn đăng ký xe buýt đang chờ duyệt hoặc đang hoạt động. Mỗi học sinh chỉ được phép có tối đa 01 đơn.'),
                            backgroundColor: Colors.orange,
                          ),
                        );
                        return;
                      }
                      Navigator.pop(ctx);
                      final success = await prov.submitBusRegister(
                        studentId: prov.selectedStudentId,
                        busId: selectedBusId!,
                        pickupAddress: addressCtrl.text.trim(),
                        pickupType: pickupType,
                        note: noteCtrl.text.trim().isNotEmpty ? noteCtrl.text.trim() : null,
                      );
                      if (success && context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Đăng ký xe buýt thành công!')),
                        );
                        context.pop();
                      } else if (!success && context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(prov.error ?? 'Đăng ký xe buýt thất bại'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    },
                    child: const Text('Gửi đăng ký xe buýt',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ==========================================
  // FORM 3: ĐĂNG KÝ NGOẠI KHÓA (G9-UC-03)
  // ==========================================
  void _showExtracurricularDialog(BuildContext context, ParentProvider prov) {
    String? selectedExtraId =
        prov.availableExtracurricular.isNotEmpty ? prov.availableExtracurricular.first.id : null;
    final noteCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Đăng ký lớp ngoại khóa',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  IconButton(onPressed: () => Navigator.pop(ctx), icon: const Icon(Icons.close)),
                ],
              ),
              const SizedBox(height: 12),
              const Text('Chọn lớp năng khiếu *',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 6),
              if (prov.availableExtracurricular.isEmpty)
                const Text('Chưa có lớp ngoại khóa nào mở đăng ký', style: TextStyle(color: Colors.grey))
              else
                DropdownButtonFormField<String>(
                  value: selectedExtraId,
                  isExpanded: true,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  items: prov.availableExtracurricular
                      .map((e) => DropdownMenuItem(
                            value: e.id,
                            child: Text(e.title, overflow: TextOverflow.ellipsis),
                          ))
                      .toList(),
                  onChanged: (v) => setModalState(() => selectedExtraId = v),
                ),
              const SizedBox(height: 12),
              const Text('Ghi chú dặn dò giáo viên',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 6),
              TextField(
                controller: noteCtrl,
                maxLines: 2,
                decoration: InputDecoration(
                  hintText: 'Bé đã học vẽ cơ bản, chuẩn bị dụng cụ...',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () async {
                    if (selectedExtraId == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Vui lòng chọn lớp năng khiếu!')),
                      );
                      return;
                    }
                    Navigator.pop(ctx);
                    final success = await prov.submitExtracurricularRegister(
                      studentId: prov.selectedStudentId,
                      extracurricularClassId: selectedExtraId!,
                      note: noteCtrl.text.trim().isNotEmpty ? noteCtrl.text.trim() : null,
                    );
                    if (success && context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Đăng ký lớp ngoại khóa thành công!')),
                      );
                      context.pop();
                    }
                  },
                  child: const Text('Gửi đăng ký ngoại khóa',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==========================================
  // FORM 4: ĐỀ NGHỊ HÀNH CHÍNH KHÁC (G4-UC-05)
  // ==========================================
  // ==========================================
  // FORM 3b: ĐĂNG KÝ ĂN SÁNG TẠI TRƯỜNG
  // ==========================================
  void _showMealRegisterDialog(BuildContext context, ParentProvider prov) {
    DateTime startDate = DateTime.now().add(const Duration(days: 1));
    final noteCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Đăng ký ăn sáng bán trú',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  IconButton(onPressed: () => Navigator.pop(ctx), icon: const Icon(Icons.close)),
                ],
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.restaurant, color: Colors.orange),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Dịch vụ ăn sáng gồm các món ăn nóng giàu dinh dưỡng, phục vụ từ 06:45 - 07:45 hàng ngày.',
                        style: TextStyle(fontSize: 12, color: Colors.brown),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              const Text('Ngày bắt đầu ăn sáng *',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 6),
              OutlinedButton.icon(
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: startDate,
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 90)),
                  );
                  if (picked != null) {
                    setModalState(() => startDate = picked);
                  }
                },
                icon: const Icon(Icons.calendar_today, size: 18),
                label: Text(DateFormat('dd/MM/yyyy').format(startDate)),
              ),
              const SizedBox(height: 14),
              const Text('Ghi chú dặn dò (Dị ứng, khẩu vị...)',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 6),
              TextField(
                controller: noteCtrl,
                maxLines: 2,
                decoration: InputDecoration(
                  hintText: 'Bé không ăn hành, dị ứng hải sản...',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () async {
                    if (prov.selectedStudentId.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Vui lòng chọn học sinh trước khi gửi đơn!')),
                      );
                      return;
                    }
                    Navigator.pop(ctx);
                    final success = await prov.submitMealRegister(
                      studentId: prov.selectedStudentId,
                      startDate: DateFormat('yyyy-MM-dd').format(startDate),
                      note: noteCtrl.text.trim().isNotEmpty ? noteCtrl.text.trim() : null,
                    );
                    if (context.mounted) {
                      if (success) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Đăng ký ăn sáng bán trú thành công! Chờ giáo vụ duyệt.')),
                        );
                        context.pop();
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(prov.error ?? 'Đăng ký ăn sáng thất bại. Vui lòng thử lại sau.'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    }
                  },
                  child: const Text('Gửi đơn đăng ký ăn sáng',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showOtherRequestDialog(BuildContext context, ParentProvider prov) {
    final titleCtrl = TextEditingController();
    final contentCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Đề nghị hành chính khác',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                IconButton(onPressed: () => Navigator.pop(ctx), icon: const Icon(Icons.close)),
              ],
            ),
            const SizedBox(height: 12),
            const Text('Tiêu đề đề nghị *',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: 6),
            TextField(
              controller: titleCtrl,
              decoration: InputDecoration(
                hintText: 'Ví dụ: Cấp giấy xác nhận học sinh, xin bản sao...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 12),
            const Text('Chi tiết nội dung yêu cầu *',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: 6),
            TextField(
              controller: contentCtrl,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: 'Nêu rõ thông tin cần hỗ trợ từ nhà trường...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () async {
                  if (titleCtrl.text.trim().isEmpty || contentCtrl.text.trim().isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Vui lòng nhập đầy đủ tiêu đề và nội dung!')),
                    );
                    return;
                  }
                  Navigator.pop(ctx);
                  final success = await prov.submitOtherRequest(
                    studentId: prov.selectedStudentId,
                    title: titleCtrl.text.trim(),
                    content: contentCtrl.text.trim(),
                  );
                  if (success && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Gửi đề nghị hành chính thành công!')),
                    );
                    context.pop();
                  }
                },
                child: const Text('Gửi đề nghị',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RequestCategoryItem {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final String badge;
  final VoidCallback onTap;

  const _RequestCategoryItem({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.badge,
    required this.onTap,
  });
}
