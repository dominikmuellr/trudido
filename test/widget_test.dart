import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:trudido/main.dart';
import 'package:trudido/services/storage_service.dart';
import 'package:trudido/repositories/task_repository.dart';
import 'package:trudido/providers/app_providers.dart';
import 'package:trudido/screens/task_editor_screen.dart';
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
    // Prevent google_fonts from trying to fetch fonts from the network
    // during widget tests which run with TestWidgetsFlutterBinding.
    GoogleFonts.config.allowRuntimeFetching = false;
    // We rely on bundled fonts, so don't disable AppTheme GoogleFonts usage here.
    // AppTheme.disableGoogleFonts = true; // no longer needed when fonts are bundled
    // Run storage deferred opens synchronously in tests to avoid background
    // timers that the test harness treats as pending.
    StorageService.performDeferredSynchronously = true;
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
    final repo = _TestRepo();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [taskRepositoryProvider.overrideWithValue(repo)],
        child: const TodoApp(disableSideEffects: true),
      ),
    );

    // Use a fixed pump to advance frames without waiting for full quiescence.
    // Some widgets use repeating timers/animations which prevent pumpAndSettle
    // from completing in the test environment.
    await tester.pump(const Duration(milliseconds: 500));

    final hasYet = find.text('No tasks yet').evaluate().isNotEmpty;
    final hasFound = find.text('No todos found').evaluate().isNotEmpty;
    expect(
      hasYet || hasFound,
      isTrue,
      reason: 'Expected an empty state message but none appeared',
    );
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
    // Advance frames after navigation without waiting indefinitely.
    await tester.pump(const Duration(milliseconds: 500));

    // Tap FAB
    await tester.tap(find.byType(FloatingActionButton));
    // Let the navigation animation run (advance several frames)
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));

    // Expect the TaskEditorScreen to be present after navigation
    expect(find.byType(TaskEditorScreen), findsOneWidget);
  });
}
