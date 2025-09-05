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
import 'package:trudido/repositories/task_repository.dart';
import 'package:trudido/providers/app_providers.dart';
import 'package:flutter/services.dart';

class _TestRepo extends TaskRepository {
  @override
  Future<void> load() async {
    setTestTasks(const []);
  }
}

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
    final repo = _TestRepo();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [taskRepositoryProvider.overrideWithValue(repo)],
        child: const TodoApp(disableSideEffects: true),
      ),
    );

    // Custom wait loop (max 40 frames ~2s)
  for (int i = 0; i < 40 &&
    find.text('No todos yet').evaluate().isEmpty &&
    find.text('No todos found').evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  final hasYet = find.text('No todos yet').evaluate().isNotEmpty;
  final hasFound = find.text('No todos found').evaluate().isNotEmpty;
  expect(hasYet || hasFound, isTrue, reason: 'Expected an empty state message but none appeared');
    expect(find.byType(FloatingActionButton), findsOneWidget);
  });

  testWidgets('Can open add todo dialog', (WidgetTester tester) async {
    final repo = _TestRepo();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [taskRepositoryProvider.overrideWithValue(repo)],
        child: const TodoApp(disableSideEffects: true),
      ),
    );
    // Wait briefly for first frame/providers
    await tester.pump(const Duration(milliseconds: 100));
    // Tap FAB
    await tester.tap(find.byType(FloatingActionButton));
    // Pump a few frames for dialog animation
    for (int i = 0; i < 10 && find.text('Add Todo').evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(find.text('Add Todo'), findsOneWidget);
  });
}
