import 'package:flutter_test/flutter_test.dart';
import 'package:kidpro_mobile/features/parent/models/parent_models.dart';

void main() {
  test(
    'parses classroom journal photos and author from the backend response',
    () {
      final post = JournalPostModel.fromJson({
        'postId': 42,
        'title': 'Hoạt động ngoài trời',
        'content': 'Các bé cùng chăm sóc cây.',
        'photoUrls': [
          'https://example.com/photo-1.jpg',
          'https://example.com/photo-2.jpg',
        ],
        'authorStaffName': 'Cô Mai',
      });

      expect(post.postId, 42);
      expect(post.imageUrls, [
        'https://example.com/photo-1.jpg',
        'https://example.com/photo-2.jpg',
      ]);
      expect(post.teacherName, 'Cô Mai');
    },
  );
}
