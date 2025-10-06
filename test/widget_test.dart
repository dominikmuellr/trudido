import 'package:fake_async/fake_async.dart';
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
  setUpAll(() {
    WidgetsFlutterBinding.ensureInitialized();
    const String testPathChannel = 'plugins.flutter.io/path_provider';
    const MethodChannel channel = MethodChannel(testPathChannel);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'getApplicationDocumentsDirectory') {
            // Return a fake path for tests.
            return 'test_documents';
          }
          return null;
        });
    // Mock shared_preferences
    const MethodChannel spChannel = MethodChannel(
      'plugins.flutter.io/shared_preferences',
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(spChannel, (call) async {
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
        });
  });

  setUp(() async {
    await StorageService.init();
  });

  tearDown(() async {
    await StorageService.dispose();
  });

  testWidgets('TodoApp basic elements render', (WidgetTester tester) async {
    await fakeAsync((async) async {
      final repo = _TestRepo();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [taskRepositoryProvider.overrideWithValue(repo)],
          child: const TodoApp(disableSideEffects: true),
        ),
      );

      async.elapse(const Duration(seconds: 10));
      await tester.pump();

      final hasYet = find.text('No tasks yet').evaluate().isNotEmpty;
      final hasFound = find.text('No todos found').evaluate().isNotEmpty;
      expect(
        hasYet || hasFound,
        isTrue,
        reason: 'Expected an empty state message but none appeared',
      );
      expect(find.byType(FloatingActionButton), findsOneWidget);
    });
  });

  testWidgets('Can open add todo dialog', (WidgetTester tester) async {
    await fakeAsync((async) async {
      final repo = _TestRepo();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [taskRepositoryProvider.overrideWithValue(repo)],
          child: const TodoApp(disableSideEffects: true),
        ),
      );
      async.elapse(const Duration(seconds: 10));
      await tester.pump();

      // Tap FAB
      await tester.tap(find.byType(FloatingActionButton));
      async.elapse(const Duration(seconds: 1));
      await tester.pump();

      expect(find.text('Add Todo'), findsOneWidget);
    });
  });
}
