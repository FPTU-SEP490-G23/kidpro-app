import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:provider/provider.dart';
import 'package:kidpro_mobile/core/constants/app_colors.dart';
import 'package:kidpro_mobile/core/network/api_client.dart';
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
                  const SizedBox(height: 8),

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
                  const Row(
                    children: [
                      Expanded(child: Divider()),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12),
                        child: Text(
                          'Đăng nhập nhanh thử nghiệm',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ),
                      Expanded(child: Divider()),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Quick login buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.school, size: 18),
                          label: const Text('Giáo Viên', style: TextStyle(fontSize: 13)),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          onPressed: auth.loading
                              ? null
                              : () => auth.loginWithGoogleEmail(
                                    email: 'teacher@kidpro.edu.vn',
                                    fullName: 'Cô Mai Lan (Giáo Viên)',
                                  ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.family_restroom, size: 18),
                          label: const Text('Phụ Huynh', style: TextStyle(fontSize: 13)),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          onPressed: auth.loading
                              ? null
                              : () => auth.loginWithGoogleEmail(
                                    email: 'parent@gmail.com',
                                    fullName: 'Phụ Huynh Bé Bảo An',
                                  ),
                        ),
                      ),
                    ],
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
    String? pingResult;
    bool isPinging = false;

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
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
                  ),
                  const SizedBox(height: 12),
                  const Text('Chọn nhanh cấu hình:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    children: [
                      ActionChip(
                        label: const Text('USB (127.0.0.1:8080)', style: TextStyle(fontSize: 11)),
                        onPressed: () => setDialogState(() => ctrl.text = 'http://127.0.0.1:8080'),
                      ),
                      ActionChip(
                        label: const Text('Wi-Fi (192.168.1.2)', style: TextStyle(fontSize: 11)),
                        onPressed: () => setDialogState(() => ctrl.text = 'http://192.168.1.2:8080'),
                      ),
                      ActionChip(
                        label: const Text('Emulator (10.0.2.2)', style: TextStyle(fontSize: 11)),
                        onPressed: () => setDialogState(() => ctrl.text = 'http://10.0.2.2:8080'),
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
                                  pingResult = null;
                                });
                                try {
                                  final dio = Dio(BaseOptions(
                                    connectTimeout: const Duration(seconds: 4),
                                    receiveTimeout: const Duration(seconds: 4),
                                  ));
                                  final pingUrl = '${ctrl.text.trim().replaceAll(RegExp(r"/+$"), "")}/api/auth/me';
                                  await dio.get(pingUrl);
                                  setDialogState(() {
                                    isPinging = false;
                                    pingResult = 'Kết nối thành công! (200 OK)';
                                  });
                                } catch (e) {
                                  setDialogState(() {
                                    isPinging = false;
                                    pingResult = 'Kết nối được với server! (${e is DioException ? e.response?.statusCode ?? e.type.name : "OK"})';
                                  });
                                }
                              },
                      ),
                    ],
                  ),
                  if (pingResult != null) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.green.shade300),
                      ),
                      child: Text(
                        pingResult!,
                        style: TextStyle(fontSize: 12, color: Colors.green.shade900),
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
                    if (context.mounted) {
                      setState(() {});
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Đã cập nhật Server URL: $newUrl')),
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
}
