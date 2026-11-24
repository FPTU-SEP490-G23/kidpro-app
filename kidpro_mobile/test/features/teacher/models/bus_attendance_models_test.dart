import 'package:flutter_test/flutter_test.dart';
import 'package:kidpro_mobile/features/teacher/models/teacher_models.dart';

void main() {
  test('parses a rider registration with its assigned stop', () {
    final student = BusStudentInfo.fromJson({
      'studentId': 'student-1',
      'studentName': 'An',
      'stopId': 12,
      'stopName': 'Trạm 1',
      'parentPhone': '0900000000',
      'status': 'WAITING',
    });

    expect(student.stopId, '12');
    expect(student.stopName, 'Trạm 1');
    expect(student.parentPhone, '0900000000');
  });

  test('parses registered student counts for a stop', () {
    final stop = BusStopInfo.fromJson({
      'stopId': '12',
      'stopName': 'Trạm 1',
      'studentCount': 3,
      'isDestination': false,
    });

    expect(stop.studentCount, 3);
    expect(stop.isDestination, isFalse);
  });
}
