// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:trudido/main.dart';
import 'package:trudido/services/storage_service.dart';
import 'package:flutter/services.dart';

void main() {
  setUpAll(() async {
    WidgetsFlutterBinding.ensureInitialized();
  const String testPathChannel = 'plugins.flutter.io/path_provider';
  const MethodChannel channel = MethodChannel(testPathChannel);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      (call) async {
        if (call.method == 'getApplicationDocumentsDirectory') {
          // Return a fake path for tests.
            return 'test_documents';
        }
        return null;
      },
    );
    // Mock shared_preferences
    const MethodChannel spChannel = MethodChannel('plugins.flutter.io/shared_preferences');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      spChannel,
      (call) async {
        switch (call.method) {
          case 'getAll':
            return <String, Object?>{};
          case 'setBool':
          case 'setString':
          case 'setInt':
          case 'setDouble':
          case 'setStringList':
            return true;
          default:
            return null;
        }
      },
    );
    await StorageService.init();
  });
  testWidgets('TodoApp basic elements render', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(
      const ProviderScope(
        child: TodoApp(),
      ),
    );

    // Wait for the app to load (since we have async initialization)
    await tester.pumpAndSettle();

    // Verify that the empty state appears (since no todos initially)
    expect(find.text('No todos yet'), findsOneWidget);

    // Verify that the floating action button is present
    expect(find.byType(FloatingActionButton), findsOneWidget);
  });

  testWidgets('Can open add todo dialog', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(
      const ProviderScope(
        child: TodoApp(),
      ),
    );

    // Wait for the app to load
    await tester.pumpAndSettle();

    // Tap the floating action button
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    // Verify that the add todo dialog appears
    expect(find.text('Add Todo'), findsOneWidget);
    expect(find.text('Task'), findsOneWidget);
  });
}
