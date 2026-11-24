import 'package:flutter_test/flutter_test.dart';
import 'package:kidpro_mobile/features/parent/models/parent_models.dart';

void main() {
  group('AvailableOption.fromBusJson', () {
    test('includes route start and end locations', () {
      final option = AvailableOption.fromBusJson({
        'busId': 'bus-1',
        'busNumber': '29B-333.68',
        'routeStart': 'Khu đô thị A',
        'routeEnd': 'Trường KIDPRO',
      });

      expect(option.title, 'Tuyến xe: 29B-333.68');
      expect(
        option.subtitle,
        'Điểm đầu: Khu đô thị A • Điểm cuối: Trường KIDPRO',
      );
    });

    test('uses route description when endpoint fields are unavailable', () {
      final option = AvailableOption.fromBusJson({
        'busId': 'bus-1',
        'busNumber': '29B-333.68',
        'routeDescription': 'Khu đô thị A -> Trường KIDPRO',
      });

      expect(option.subtitle, 'Khu đô thị A -> Trường KIDPRO');
    });
  });
}
