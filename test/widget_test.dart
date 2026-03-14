// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:marine_safe_app_fixed/main.dart';

void main() {
  testWidgets('App builds smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const MarineSafeApp());
    // Splash screen schedules a short boot timer; advance time so tests don't fail on pending timers.
    await tester.pump(const Duration(seconds: 2));
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
