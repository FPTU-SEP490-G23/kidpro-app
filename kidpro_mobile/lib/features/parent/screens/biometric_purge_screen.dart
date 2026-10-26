import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:kidpro_mobile/core/constants/app_colors.dart';
import 'package:kidpro_mobile/features/parent/models/parent_models.dart';
import 'package:kidpro_mobile/features/parent/providers/parent_provider.dart';

class BiometricPurgeScreen extends StatefulWidget {
  const BiometricPurgeScreen({super.key});

  @override
  State<BiometricPurgeScreen> createState() => _BiometricPurgeScreenState();
}

class _BiometricPurgeScreenState extends State<BiometricPurgeScreen> {
  final _reasonCtrl = TextEditingController(text: 'Yêu cầu bảo vệ quyền riêng tư gia đình');
  final _otpCtrl = TextEditingController();

  int _step = 1; // 1: Info & Request OTP, 2: Enter OTP, 3: Completed Certificate
  bool _submitting = false;

  @override
  void dispose() {
    _reasonCtrl.dispose();
    _otpCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleRequestOtp() async {
    setState(() => _submitting = true);
    final prov = context.read<ParentProvider>();
    await prov.requestPurgeOtp();
    setState(() {
      _submitting = false;
      _step = 2;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Mã OTP xác thực đã được gửi tới số điện thoại phụ huynh'),
          backgroundColor: AppColors.info,
          duration: Duration(seconds: 4),
        ),
      );
    }
  }

  Future<void> _handleConfirmPurge() async {
    if (_otpCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng nhập mã OTP')),
      );
      return;
    }

    setState(() => _submitting = true);
    final prov = context.read<ParentProvider>();
    final success = await prov.confirmBiometricPurge(
      _otpCtrl.text.trim(),
      _reasonCtrl.text.trim(),
    );
    setState(() {
      _submitting = false;
      if (success) _step = 3;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Quyền riêng tư AI (Nghị định 13)'),
      ),
      body: Consumer<ParentProvider>(
        builder: (context, prov, child) {
          if (_step == 3 && prov.purgeCertificate != null) {
            return _buildCertificateView(prov.purgeCertificate!);
          }
          if (_step == 2) {
            return _buildOtpStepView();
          }
          return _buildIntroStepView(prov);
        },
      ),
    );
  }

  Widget _buildIntroStepView(ParentProvider prov) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Decree 13 Legal Card
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.indigo.shade900, Colors.indigo.shade700],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: const [
                    Icon(Icons.gavel, color: Colors.amber, size: 24),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Nghị định số 13/2023/NĐ-CP',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                const Text(
                  'Về bảo vệ dữ liệu cá nhân & Quyền rút lại sự đồng ý thu thập dữ liệu sinh trắc học của trẻ em.',
                  style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Child Context
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Row(
              children: [
                const Icon(Icons.face_retouching_off, color: AppColors.error),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        prov.selectedStudentName,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      Text(
                        'Dữ liệu đăng ký: Vector khuôn mặt 512 chiều (InsightFace)',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          const Text('Quyền lợi và hệ quả sau khi xóa dữ liệu:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 10),
          _bulletItem('Toàn bộ vector đặc trưng khuôn mặt (512 chiều) lưu trong hệ thống AI sẽ bị hủy kích hoạt và xóa vĩnh viễn.'),
          _bulletItem('Camera AI tại cổng trường sẽ không còn tự động nhận diện điểm danh bé khi đến lớp.'),
          _bulletItem('Giáo viên sẽ chuyển sang chế độ điểm danh thủ công truyền thống trên ứng dụng dành cho giáo viên.'),
          _bulletItem('Sau khi hoàn tất, hệ thống sẽ cấp Chứng thư số Tiêu hủy Dữ liệu (SHA-256) có giá trị pháp lý.'),
          const SizedBox(height: 20),

          const Text('Lý do yêu cầu tiêu hủy dữ liệu:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 8),
          TextFormField(
            controller: _reasonCtrl,
            maxLines: 2,
            decoration: InputDecoration(
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 28),

          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: _submitting ? null : _handleRequestOtp,
              icon: _submitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.delete_forever),
              label: const Text('Yêu cầu xóa dữ liệu & Nhận OTP',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOtpStepView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Icon(Icons.phonelink_lock, size: 72, color: AppColors.primary),
          const SizedBox(height: 16),
          const Text(
            'Xác thực OTP 2 lớp (2FA)',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Mã OTP 6 số đã được gửi tới số điện thoại của Quý phụ huynh. Vui lòng nhập mã để hoàn tất thủ tục tiêu hủy dữ liệu sinh trắc học.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade700, fontSize: 14, height: 1.4),
          ),
          const SizedBox(height: 24),

          TextFormField(
            controller: _otpCtrl,
            keyboardType: TextInputType.number,
            maxLength: 6,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 28,
              letterSpacing: 12,
              fontWeight: FontWeight.bold,
              color: AppColors.primaryDark,
            ),
            decoration: InputDecoration(
              counterText: '',
              hintText: '000000',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
            ),
          ),
          const SizedBox(height: 28),

          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: _submitting ? null : _handleConfirmPurge,
              child: _submitting
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('Xác nhận tiêu hủy vĩnh viễn',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(height: 14),
          TextButton(
            onPressed: () => setState(() => _step = 1),
            child: const Text('Quay lại bước trước'),
          ),
        ],
      ),
    );
  }

  Widget _buildCertificateView(BiometricPurgeCertificate cert) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.green.shade600, width: 2),
              boxShadow: [
                BoxShadow(
                  color: Colors.green.withOpacity(0.1),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Icon(Icons.verified, size: 64, color: AppColors.success),
                const SizedBox(height: 12),
                const Text(
                  'CHỨNG THƯ TIÊU HỦY DỮ LIỆU SINH TRẮC HỌC',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                    color: AppColors.primaryDark,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Tuân thủ Nghị định số 13/2023/NĐ-CP',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                ),
                const Divider(height: 28),

                _certRow('Học sinh:', cert.studentName),
                _certRow('Mã chứng thư:', cert.certificateCode),
                _certRow('Thời gian tiêu hủy:', cert.purgedAt),
                _certRow('Số vector khuôn mặt bị xóa:', '${cert.deletedFaceVectorsCount} vector (512 chiều)'),
                const SizedBox(height: 12),

                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Mã băm bằng chứng (SHA-256):',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                ),
                const SizedBox(height: 4),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: SelectableText(
                    cert.hashSha256,
                    style: const TextStyle(fontSize: 11, fontFamily: 'monospace', color: Colors.black87),
                  ),
                ),
                const SizedBox(height: 20),

                // Official Seal badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.red.shade700, width: 2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'ĐÃ TIÊU HỦY VĨNH VIỄN - KIDPRO AI ENGINE',
                    style: TextStyle(
                      color: Colors.red.shade800,
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: () {
                Clipboard.setData(ClipboardData(
                  text: 'Chứng thư tiêu hủy dữ liệu sinh trắc học NĐ 13/2023/NĐ-CP: Mã: ${cert.certificateCode}. SHA-256: ${cert.hashSha256}. Thời gian: ${cert.purgedAt}',
                ));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Đã sao chép mã chứng thư vào bộ nhớ tạm!')),
                );
              },
              icon: const Icon(Icons.copy),
              label: const Text('Sao chép thông tin chứng thư số',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Quay lại Trang chủ Phụ huynh'),
          ),
        ],
      ),
    );
  }

  Widget _certRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(label, style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          ),
        ],
      ),
    );
  }

  Widget _bulletItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.arrow_right, color: AppColors.primary, size: 20),
          const SizedBox(width: 6),
          Expanded(
            child: Text(text, style: TextStyle(color: Colors.grey.shade800, fontSize: 13, height: 1.35)),
          ),
        ],
      ),
    );
  }
}
