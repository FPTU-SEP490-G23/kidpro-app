import 'package:flutter/material.dart';
import 'package:kidpro_mobile/core/constants/app_colors.dart';
import 'package:kidpro_mobile/features/parent/models/parent_models.dart';

class JournalPostDetailSheet extends StatefulWidget {
  final JournalPostModel post;
  final Future<JournalPostModel> Function() loadDetail;

  const JournalPostDetailSheet({
    super.key,
    required this.post,
    required this.loadDetail,
  });

  @override
  State<JournalPostDetailSheet> createState() => _JournalPostDetailSheetState();
}

class _JournalPostDetailSheetState extends State<JournalPostDetailSheet> {
  late Future<JournalPostModel> _detailFuture;

  @override
  void initState() {
    super.initState();
    _detailFuture = widget.loadDetail();
  }

  void _retry() {
    setState(() {
      _detailFuture = widget.loadDetail();
    });
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.55,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Material(
          color: Colors.white,
          clipBehavior: Clip.antiAlias,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 10, bottom: 8),
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              Expanded(
                child: FutureBuilder<JournalPostModel>(
                  future: _detailFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(
                          color: AppColors.primary,
                        ),
                      );
                    }
                    if (snapshot.hasError) {
                      return _buildPostContent(
                        context,
                        widget.post,
                        scrollController,
                        detailLoadFailed: true,
                      );
                    }
                    return _buildPostContent(
                      context,
                      snapshot.data ?? widget.post,
                      scrollController,
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPostContent(
    BuildContext context,
    JournalPostModel post,
    ScrollController scrollController, {
    bool detailLoadFailed = false,
  }) {
    final formattedDate = _formatDate(post.createdAt);
    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                post.title ?? 'Nhật ký hoạt động',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            IconButton(
              tooltip: 'Đóng',
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.close),
            ),
          ],
        ),
        if (detailLoadFailed)
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.amber.shade50,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Không tải mới được chi tiết. Đang hiển thị nội dung trong danh sách.',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
                TextButton(onPressed: _retry, child: const Text('Thử lại')),
              ],
            ),
          ),
        Wrap(
          spacing: 12,
          runSpacing: 6,
          children: [
            if (post.className?.isNotEmpty == true)
              _PostMetadata(icon: Icons.class_outlined, text: post.className!),
            if (post.teacherName?.isNotEmpty == true)
              _PostMetadata(
                icon: Icons.person_outline,
                text: 'Đăng bởi ${post.teacherName}',
              ),
            if (formattedDate != null)
              _PostMetadata(
                icon: Icons.calendar_today_outlined,
                text: formattedDate,
              ),
          ],
        ),
        const SizedBox(height: 18),
        Text(
          post.content?.trim().isNotEmpty == true
              ? post.content!.trim()
              : 'Bài đăng không có nội dung mô tả.',
          style: TextStyle(
            color: Colors.grey.shade800,
            fontSize: 15,
            height: 1.55,
          ),
        ),
        if (post.imageUrls.isNotEmpty) ...[
          const SizedBox(height: 22),
          const Text(
            'Hình ảnh hoạt động',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
          const SizedBox(height: 10),
          for (final imageUrl in post.imageUrls)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  color: Colors.grey.shade100,
                  constraints: const BoxConstraints(maxHeight: 320),
                  child: Image.network(
                    imageUrl,
                    width: double.infinity,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const SizedBox(
                      height: 160,
                      child: Center(
                        child: Icon(
                          Icons.broken_image_outlined,
                          size: 40,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ],
    );
  }

  String? _formatDate(String? value) {
    if (value == null || value.isEmpty) return null;
    final date = DateTime.tryParse(value);
    if (date == null) return value;
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }
}

class _PostMetadata extends StatelessWidget {
  final IconData icon;
  final String text;

  const _PostMetadata({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: AppColors.primary),
        const SizedBox(width: 4),
        Text(text, style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
      ],
    );
  }
}
