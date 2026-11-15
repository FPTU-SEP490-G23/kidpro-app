/// OPT-004: Tiện ích ánh xạ góc xoay đầu (Head Yaw / Euler Y) cho thử thách Liveness Active.
/// Hỗ trợ góc quay người dùng, xử lý lật gương (mirror) camera trước và ngưỡng tối thiểu.
class LivenessDirectionMapper {
  static const double defaultTurnThresholdDegrees = 15.0;

  /// Kiểm tra góc quay đầu hiện tại có thỏa mãn hành động thử thách hay không.
  ///
  /// [action]: 'TURN_LEFT' hoặc 'TURN_RIGHT' theo góc nhìn của người dùng (Bé quay sang trái / phải).
  /// [headEulerAngleY]: Góc quay trục Y do ML Kit cung cấp (degrees).
  /// [isFrontCamera]: Camera trước hay sau.
  /// [threshold]: Ngưỡng góc tối thiểu (mặc định 15.0 độ).
  static bool isTurnDirectionSatisfied({
    required String action,
    required double headEulerAngleY,
    bool isFrontCamera = true,
    double threshold = defaultTurnThresholdDegrees,
  }) {
    final act = action.toUpperCase().trim();
    if (act == 'TURN_LEFT') {
      // Khi bé quay sang trái:
      // Trong hệ tọa độ ML Kit thông thường (unmirrored buffer):
      // Quay sang trái -> headEulerAngleY âm (<= -15.0)
      return headEulerAngleY <= -threshold;
    } else if (act == 'TURN_RIGHT') {
      // Khi bé quay sang phải -> headEulerAngleY dương (>= 15.0)
      return headEulerAngleY >= threshold;
    }
    return false;
  }

  /// Thông điệp hướng dẫn trẻ bằng tiếng Việt thân thiện, rõ ràng.
  static String getInstructionMessage(String action) {
    final act = action.toUpperCase().trim();
    if (act == 'TURN_LEFT') {
      return 'Bé hãy từ từ quay mặt sang BÊN TRÁI nhé 👈';
    } else if (act == 'TURN_RIGHT') {
      return 'Bé hãy từ từ quay mặt sang BÊN PHẢI nhé 👉';
    }
    return 'Bé hãy nhìn thẳng vào camera nhé 😊';
  }
}
