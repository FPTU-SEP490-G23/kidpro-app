import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:provider/provider.dart';
import 'package:kidpro_mobile/core/constants/app_colors.dart';
import 'package:kidpro_mobile/core/network/api_client.dart';
import 'package:kidpro_mobile/core/storage/secure_storage_helper.dart';
import 'package:kidpro_mobile/features/auth/providers/auth_provider.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final auth = context.read<AuthProvider>();
    await auth.login(_emailCtrl.text.trim(), _passwordCtrl.text);
    // Router redirect handles navigation on success.
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Logo
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppColors.primary, Color(0xFFA855F7)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Icon(Icons.child_care,
                        size: 44, color: Colors.white),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'KidPro',
                    style: Theme.of(context)
                        .textTheme
                        .headlineMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Quản lý Mầm non Thông minh',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey,
                        ),
                  ),
                  const SizedBox(height: 40),

                  // Email
                  TextFormField(
                    controller: _emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      prefixIcon: Icon(Icons.email_outlined),
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return 'Vui lòng nhập email';
                      }
                      if (!v.contains('@')) return 'Email không hợp lệ';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Password
                  TextFormField(
                    controller: _passwordCtrl,
                    obscureText: _obscure,
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => _submit(),
                    decoration: InputDecoration(
                      labelText: 'Mật khẩu',
                      prefixIcon: const Icon(Icons.lock_outline),
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: Icon(
                            _obscure ? Icons.visibility_off : Icons.visibility),
                        onPressed: () => setState(() => _obscure = !_obscure),
                      ),
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty) {
                        return 'Vui lòng nhập mật khẩu';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 4),

                  // Nút Quên mật khẩu
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => _showForgotPasswordDialog(context),
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                      ),
                      child: const Text(
                        'Quên mật khẩu?',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),

                  // Error message
                  if (auth.error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        auth.error!,
                        style: const TextStyle(color: AppColors.error),
                      ),
                    ),

                  const SizedBox(height: 16),

                  // Login button
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: FilledButton(
                      onPressed: auth.loading ? null : _submit,
                      child: auth.loading
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : const Text('Đăng nhập',
                              style: TextStyle(fontSize: 16)),
                    ),
                  ),

                  const SizedBox(height: 24),
                  TextButton.icon(
                    icon: const Icon(Icons.settings_ethernet, size: 18),
                    label: Text(
                      'Cấu hình IP máy chủ (${ApiClient().currentBaseUrl})',
                      style: const TextStyle(fontSize: 12),
                    ),
                    onPressed: () => _showServerConfigDialog(context),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showServerConfigDialog(BuildContext context) {
    final ctrl = TextEditingController(text: ApiClient().currentBaseUrl);
    String? backendPingResult;
    bool backendSuccess = false;
    String? aiPingResult;
    bool aiSuccess = false;
    bool isPinging = false;

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final currentInput = ctrl.text.trim().replaceAll(RegExp(r"/+$"), "");
          String derivedAiUrl = 'http://192.168.10.51:8000';
          try {
            final uri = Uri.parse(currentInput);
            if (uri.host.isNotEmpty) {
              final scheme = uri.scheme.isNotEmpty ? uri.scheme : 'http';
              derivedAiUrl = '$scheme://${uri.host}:8000';
            }
          } catch (_) {}

          return AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.dns, color: AppColors.primary),
                SizedBox(width: 8),
                Text('Cấu hình Server Backend', style: TextStyle(fontSize: 17)),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Địa chỉ kết nối đến Spring Boot Backend:',
                    style: TextStyle(fontSize: 13, color: Colors.black87),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: ctrl,
                    decoration: const InputDecoration(
                      labelText: 'Server Base URL',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    onChanged: (_) => setDialogState(() {
                      backendPingResult = null;
                      aiPingResult = null;
                    }),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'AI Face Backend (cổng 8000): $derivedAiUrl',
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                  const SizedBox(height: 12),
                  const Text('Chọn nhanh cấu hình:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      ActionChip(
                        avatar: const Icon(Icons.wifi, size: 14),
                        label: const Text('Wi-Fi LAN (192.168.10.51:8080)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                        onPressed: () => setDialogState(() {
                          ctrl.text = 'http://192.168.10.51:8080';
                          backendPingResult = null;
                          aiPingResult = null;
                        }),
                      ),
                                            ActionChip(
                        avatar: const Icon(Icons.wifi_tethering, size: 14),
                        label: const Text('Hotspot (192.168.137.1)', style: TextStyle(fontSize: 11)),
                        onPressed: () => setDialogState(() {
                          ctrl.text = 'http://192.168.137.1:8080';
                          backendPingResult = null;
                          aiPingResult = null;
                        }),
                      ),
                      ActionChip(
                        avatar: const Icon(Icons.usb, size: 14),
                        label: const Text('USB Cáp (127.0.0.1:8080)', style: TextStyle(fontSize: 11)),
                        onPressed: () => setDialogState(() {
                          ctrl.text = 'http://127.0.0.1:8080';
                          backendPingResult = null;
                          aiPingResult = null;
                        }),
                      ),
                      ActionChip(
                        avatar: const Icon(Icons.phone_android, size: 14),
                        label: const Text('Emulator (10.0.2.2:8080)', style: TextStyle(fontSize: 11)),
                        onPressed: () => setDialogState(() {
                          ctrl.text = 'http://10.0.2.2:8080';
                          backendPingResult = null;
                          aiPingResult = null;
                        }),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      ElevatedButton.icon(
                        icon: isPinging
                            ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.network_check, size: 16),
                        label: const Text('Kiểm tra kết nối', style: TextStyle(fontSize: 12)),
                        onPressed: isPinging
                            ? null
                            : () async {
                                setDialogState(() {
                                  isPinging = true;
                                  backendPingResult = null;
                                  aiPingResult = null;
                                });

                                final base = ctrl.text.trim().replaceAll(RegExp(r"/+$"), "");

                                // 1. Ping Backend Spring Boot (cổng 8080)
                                try {
                                  final dioBe = Dio(BaseOptions(
                                    connectTimeout: const Duration(seconds: 4),
                                    receiveTimeout: const Duration(seconds: 4),
                                  ));
                                  final pingUrl = '$base/api/auth/me';
                                  await dioBe.get(pingUrl);
                                  backendSuccess = true;
                                  backendPingResult = 'Backend (8080): Sẵn sàng (200 OK)';
                                } on DioException catch (e) {
                                  if (e.response != null) {
                                    backendSuccess = true;
                                    backendPingResult = 'Backend (8080): Phản hồi HTTP ${e.response?.statusCode} (Kết nối tốt!)';
                                  } else if (e.type == DioExceptionType.connectionTimeout) {
                                    backendSuccess = false;
                                    backendPingResult = 'Backend (8080): Timeout! Kiểm tra Wi-Fi / Firewall';
                                  } else {
                                    backendSuccess = false;
                                    backendPingResult = 'Backend (8080): Không thể kết nối (${e.type.name}) - Kiểm tra xem Spring Boot đã chạy chưa!';
                                  }
                                } catch (e) {
                                  backendSuccess = false;
                                  backendPingResult = 'Backend (8080): $e';
                                }

                                // 2. Ping Python AI Server (cổng 8000)
                                try {
                                  final dioAi = Dio(BaseOptions(
                                    connectTimeout: const Duration(seconds: 4),
                                    receiveTimeout: const Duration(seconds: 4),
                                  ));
                                  final resAi = await dioAi.get(derivedAiUrl);
                                  aiSuccess = true;
                                  final count = resAi.data is Map ? (resAi.data['registered_students_count'] ?? 0) : 0;
                                  aiPingResult = 'AI Server (8000): ONLINE ($count học sinh)';
                                } on DioException catch (e) {
                                  if (e.response != null) {
                                    aiSuccess = true;
                                    aiPingResult = 'AI Server (8000): Phản hồi HTTP ${e.response?.statusCode} (Kết nối tốt!)';
                                  } else if (e.type == DioExceptionType.connectionTimeout) {
                                    aiSuccess = false;
                                    aiPingResult = 'AI Server (8000): Timeout! Kiểm tra Wi-Fi / Firewall';
                                  } else {
                                    aiSuccess = false;
                                    aiPingResult = 'AI Server (8000): Chưa chạy hoặc bị chặn (${e.type.name}) - Kiểm tra xem Python AI Server đã chạy chưa!';
                                  }
                                } catch (e) {
                                  aiSuccess = false;
                                  aiPingResult = 'AI Server (8000): $e';
                                }

                                setDialogState(() {
                                  isPinging = false;
                                });
                              },
                      ),
                    ],
                  ),
                  if (backendPingResult != null || aiPingResult != null) ...[
                    const SizedBox(height: 10),
                    if (backendPingResult != null)
                      Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(bottom: 6),
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: backendSuccess ? Colors.green.shade50 : Colors.red.shade50,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: backendSuccess ? Colors.green.shade300 : Colors.red.shade300,
                          ),
                        ),
                        child: Text(
                          backendPingResult!,
                          style: TextStyle(
                            fontSize: 12,
                            color: backendSuccess ? Colors.green.shade900 : Colors.red.shade900,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    if (aiPingResult != null)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: aiSuccess ? Colors.green.shade50 : Colors.red.shade50,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: aiSuccess ? Colors.green.shade300 : Colors.red.shade300,
                          ),
                        ),
                        child: Text(
                          aiPingResult!,
                          style: TextStyle(
                            fontSize: 12,
                            color: aiSuccess ? Colors.green.shade900 : Colors.red.shade900,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Hủy'),
              ),
              FilledButton(
                onPressed: () async {
                  final newUrl = ctrl.text.trim();
                  if (newUrl.isNotEmpty) {
                    await ApiClient().updateBaseUrl(newUrl);
                    await SecureStorageHelper.saveAiServerUrl(derivedAiUrl);
                    if (context.mounted) {
                      setState(() {});
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Đã cập nhật Backend ($newUrl) & AI ($derivedAiUrl)')),
                      );
                    }
                  }
                },
                child: const Text('Lưu & Áp dụng'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showForgotPasswordDialog(BuildContext context) {
    final emailCtrl = TextEditingController(text: _emailCtrl.text.trim());
    bool isSubmitting = false;
    String? localError;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 24,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.lock_reset, color: AppColors.primary, size: 26),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Khôi phục mật khẩu',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(ctx),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Text(
                'Nhập địa chỉ Gmail tài khoản của bạn. Hệ thống sẽ tạo một mật khẩu ngẫu nhiên mới và gửi trực tiếp vào hộp thư của bạn.',
                style: TextStyle(color: Colors.black87, fontSize: 13.5, height: 1.4),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: emailCtrl,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: 'Email tài khoản *',
                  prefixIcon: const Icon(Icons.email_outlined),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  errorText: localError,
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          final mail = emailCtrl.text.trim();
                          if (mail.isEmpty || !mail.contains('@')) {
                            setModalState(() => localError = 'Vui lòng nhập đúng định dạng email');
                            return;
                          }
                          setModalState(() {
                            isSubmitting = true;
                            localError = null;
                          });

                          try {
                            final auth = context.read<AuthProvider>();
                            final msg = await auth.forgotPassword(mail);
                            if (ctx.mounted) {
                              Navigator.pop(ctx);
                            }
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Row(
                                    children: [
                                      const Icon(Icons.check_circle, color: Colors.white),
                                      const SizedBox(width: 10),
                                      Expanded(child: Text(msg)),
                                    ],
                                  ),
                                  backgroundColor: Colors.green.shade700,
                                  duration: const Duration(seconds: 5),
                                ),
                              );
                            }
                          } catch (e) {
                            setModalState(() {
                              isSubmitting = false;
                              localError = e.toString();
                            });
                          }
                        },
                  child: isSubmitting
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text(
                          'Gửi mật khẩu mới qua Gmail',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
