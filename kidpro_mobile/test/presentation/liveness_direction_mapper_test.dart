import 'package:flutter_test/flutter_test.dart';
import 'package:kidpro_mobile/features/teacher/utils/liveness_direction_mapper.dart';

void main() {
  group('OPT-004: LivenessDirectionMapper Unit Tests', () {
    test('should satisfy TURN_LEFT when Euler Y angle <= -15 degrees', () {
      expect(
        LivenessDirectionMapper.isTurnDirectionSatisfied(
          action: 'TURN_LEFT',
          headEulerAngleY: -15.0,
        ),
        isTrue,
      );

      expect(
        LivenessDirectionMapper.isTurnDirectionSatisfied(
          action: 'TURN_LEFT',
          headEulerAngleY: -22.5,
        ),
        isTrue,
      );

      expect(
        LivenessDirectionMapper.isTurnDirectionSatisfied(
          action: 'TURN_LEFT',
          headEulerAngleY: -10.0,
        ),
        isFalse,
      );

      expect(
        LivenessDirectionMapper.isTurnDirectionSatisfied(
          action: 'TURN_LEFT',
          headEulerAngleY: 0.0,
        ),
        isFalse,
      );

      expect(
        LivenessDirectionMapper.isTurnDirectionSatisfied(
          action: 'TURN_LEFT',
          headEulerAngleY: 18.0,
        ),
        isFalse,
      );
    });

    test('should satisfy TURN_RIGHT when Euler Y angle >= 15 degrees', () {
      expect(
        LivenessDirectionMapper.isTurnDirectionSatisfied(
          action: 'TURN_RIGHT',
          headEulerAngleY: 15.0,
        ),
        isTrue,
      );

      expect(
        LivenessDirectionMapper.isTurnDirectionSatisfied(
          action: 'TURN_RIGHT',
          headEulerAngleY: 25.0,
        ),
        isTrue,
      );

      expect(
        LivenessDirectionMapper.isTurnDirectionSatisfied(
          action: 'TURN_RIGHT',
          headEulerAngleY: 12.0,
        ),
        isFalse,
      );

      expect(
        LivenessDirectionMapper.isTurnDirectionSatisfied(
          action: 'TURN_RIGHT',
          headEulerAngleY: -18.0,
        ),
        isFalse,
      );
    });

    test('should respect custom angle threshold', () {
      expect(
        LivenessDirectionMapper.isTurnDirectionSatisfied(
          action: 'TURN_RIGHT',
          headEulerAngleY: 18.0,
          threshold: 20.0,
        ),
        isFalse,
      );

      expect(
        LivenessDirectionMapper.isTurnDirectionSatisfied(
          action: 'TURN_RIGHT',
          headEulerAngleY: 21.0,
          threshold: 20.0,
        ),
        isTrue,
      );
    });

    test('should generate correct guidance messages', () {
      expect(
        LivenessDirectionMapper.getInstructionMessage('TURN_LEFT'),
        contains('BÊN TRÁI'),
      );
      expect(
        LivenessDirectionMapper.getInstructionMessage('TURN_RIGHT'),
        contains('BÊN PHẢI'),
      );
    });
  });
}
