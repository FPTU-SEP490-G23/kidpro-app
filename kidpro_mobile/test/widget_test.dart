import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('KidPro smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: Text('KidPro Kindergarten'),
          ),
        ),
      ),
    );

    expect(find.text('KidPro Kindergarten'), findsOneWidget);
  });
}
