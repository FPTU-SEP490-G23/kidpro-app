import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:kidpro_mobile/core/constants/app_colors.dart';
import 'package:kidpro_mobile/features/parent/providers/parent_provider.dart';

class VietQrPaymentScreen extends StatefulWidget {
  final String invoiceId;

  const VietQrPaymentScreen({super.key, required this.invoiceId});

  @override
  State<VietQrPaymentScreen> createState() => _VietQrPaymentScreenState();
}

class _VietQrPaymentScreenState extends State<VietQrPaymentScreen> {
  final _currencyFormat = NumberFormat.currency(locale: 'vi_VN', symbol: 'đ');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ParentProvider>().loadVietQr(widget.invoiceId);
    });
  }

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Đã sao chép $label'),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final parentProv = context.watch<ParentProvider>();
    final qr = parentProv.currentQr;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Thanh toán VietQR'),
      ),
      body: parentProv.loading
          ? const Center(child: CircularProgressIndicator())
          : qr == null
              ? Center(
                  child: Text(
                    parentProv.error ?? 'Không thể tải mã VietQR',
                    style: const TextStyle(color: AppColors.error),
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Card(
                        elevation: 3,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.qr_code_scanner, color: AppColors.primary, size: 28),
                                  const SizedBox(width: 8),
                                  const Text(
                                    'VietQR - NAPAS 247',
                                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.grey.shade200),
                                ),
                                child: QrImageView(
                                  data: qr.qrDataUrl.isNotEmpty
                                      ? qr.qrDataUrl
                                      : 'https://img.vietqr.io/image/${qr.bankName}-${qr.accountNumber}-compact2.png?amount=${qr.amount.toInt()}&addInfo=${qr.referenceCode}',
                                  version: QrVersions.auto,
                                  size: 220,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Quét bằng ứng dụng ngân hàng hoặc ví điện tử',
                                style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Account information card
                      Card(
                        elevation: 1,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              _InfoRow(
                                label: 'Ngân hàng',
                                value: qr.bankName,
                              ),
                              const Divider(height: 20),
                              _InfoRow(
                                label: 'Số tài khoản',
                                value: qr.accountNumber,
                                onCopy: () => _copyToClipboard(qr.accountNumber, 'số tài khoản'),
                              ),
                              const Divider(height: 20),
                              _InfoRow(
                                label: 'Chủ tài khoản',
                                value: qr.accountName,
                              ),
                              const Divider(height: 20),
                              _InfoRow(
                                label: 'Số tiền',
                                value: _currencyFormat.format(qr.amount),
                                isHighlight: true,
                                onCopy: () => _copyToClipboard(qr.amount.toInt().toString(), 'số tiền'),
                              ),
                              const Divider(height: 20),
                              _InfoRow(
                                label: 'Nội dung CK',
                                value: qr.referenceCode,
                                isHighlight: true,
                                onCopy: () => _copyToClipboard(qr.referenceCode, 'nội dung chuyển khoản'),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // One-tap bank app open button
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Đang mở ứng dụng ngân hàng liên kết...'),
                              ),
                            );
                          },
                          icon: const Icon(Icons.account_balance_wallet_outlined),
                          label: const Text(
                            'Mở App Ngân hàng 1-chạm',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isHighlight;
  final VoidCallback? onCopy;

  const _InfoRow({
    required this.label,
    required this.value,
    this.isHighlight = false,
    this.onCopy,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: TextStyle(
              fontWeight: isHighlight ? FontWeight.bold : FontWeight.w500,
              fontSize: isHighlight ? 15 : 13,
              color: isHighlight ? AppColors.primary : null,
            ),
          ),
        ),
        if (onCopy != null) ...[
          const SizedBox(width: 6),
          InkWell(
            onTap: onCopy,
            borderRadius: BorderRadius.circular(6),
            child: const Padding(
              padding: EdgeInsets.all(4),
              child: Icon(Icons.copy, size: 16, color: AppColors.primary),
            ),
          ),
        ],
      ],
    );
  }
}
