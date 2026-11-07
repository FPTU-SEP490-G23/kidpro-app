import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:kidpro_mobile/core/network/api_client.dart';

/// Hiển thị ảnh từ backend. Đường dẫn /uploads/** cần JWT nên tải qua Dio (có Authorization);
/// URL tuyệt đối (Cloudinary) tải trực tiếp.
class AuthNetworkImage extends StatefulWidget {
  final String url;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Widget? placeholder;

  const AuthNetworkImage({
    super.key,
    required this.url,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.placeholder,
  });

  @override
  State<AuthNetworkImage> createState() => _AuthNetworkImageState();
}

class _AuthNetworkImageState extends State<AuthNetworkImage> {
  Future<Uint8List?>? _bytes;

  bool get _isAbsolute => widget.url.startsWith('http');

  @override
  void initState() {
    super.initState();
    if (!_isAbsolute) _bytes = _load();
  }

  @override
  void didUpdateWidget(covariant AuthNetworkImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url && !_isAbsolute) _bytes = _load();
  }

  Future<Uint8List?> _load() async {
    try {
      final res = await ApiClient().dio.get<List<int>>(
            widget.url,
            options: Options(responseType: ResponseType.bytes),
          );
      return res.data != null ? Uint8List.fromList(res.data!) : null;
    } catch (_) {
      return null;
    }
  }

  Widget get _fallback =>
      widget.placeholder ??
      Container(
        width: widget.width,
        height: widget.height,
        color: Colors.grey.shade200,
        child: Icon(Icons.person, color: Colors.grey.shade400),
      );

  @override
  Widget build(BuildContext context) {
    if (_isAbsolute) {
      return Image.network(
        widget.url,
        width: widget.width,
        height: widget.height,
        fit: widget.fit,
        errorBuilder: (_, __, ___) => _fallback,
      );
    }
    return FutureBuilder<Uint8List?>(
      future: _bytes,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return SizedBox(
            width: widget.width,
            height: widget.height,
            child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
          );
        }
        final data = snap.data;
        if (data == null) return _fallback;
        return Image.memory(data, width: widget.width, height: widget.height, fit: widget.fit);
      },
    );
  }
}
