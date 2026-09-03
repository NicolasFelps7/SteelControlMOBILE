import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renderiza uma interface Flutter básica', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(child: Text('SteelControl')),
        ),
      ),
    );

    expect(find.text('SteelControl'), findsOneWidget);
  });
}
