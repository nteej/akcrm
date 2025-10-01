// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:finnerp/main.dart';
import 'package:finnerp/providers/auth.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    // Build our app with provider and trigger a frame.
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (context) => Auth(),
        child: const MyApp(),
      ),
    );

    // Just pump once and verify app doesn't crash during build
    await tester.pump();

    // Verify app widget tree is built successfully
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
