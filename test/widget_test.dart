import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mesut_iptv/main.dart';

void main() {
  testWidgets('Mesut IPTV app renders its start screen', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MesutApp(
        start: Scaffold(
          body: Text('Mesut IPTV test screen'),
        ),
      ),
    );

    expect(find.text('Mesut IPTV test screen'), findsOneWidget);
  });
}
