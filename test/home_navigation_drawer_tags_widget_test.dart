import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trudido/controllers/notes_controller.dart';
import 'package:trudido/models/note_folder.dart';
import 'package:trudido/providers/filter_providers.dart';
import 'package:trudido/repositories/note_folder_repository.dart';
import 'package:trudido/screens/home_navigation_drawer.dart';
import 'package:trudido/utils/state_notifiers.dart';

class _FixedNoteFoldersNotifier extends NoteFoldersNotifier {
  _FixedNoteFoldersNotifier(this.folders);

  final List<NoteFolder> folders;

  @override
  Future<List<NoteFolder>> build() async => folders;
}

class _FixedTabDrawerModuleNotifier extends TabDrawerModuleNotifier {
  _FixedTabDrawerModuleNotifier(this.initialModule) : super(1);

  final String initialModule;

  @override
  String build() => initialModule;

  @override
  void setModule(String moduleType) {
    state = moduleType;
  }
}

class _TestNotesDrawerTagScopeNotifier extends NotesDrawerTagScopeNotifier {
  _TestNotesDrawerTagScopeNotifier(this.initialScope);

  final String initialScope;

  @override
  String build() => initialScope;

  @override
  Future<void> setScope(String scope) async {
    state = scope;
  }
}

Future<void> _pumpDrawer(
  WidgetTester tester,
  ProviderContainer container,
) async {
  final scaffoldKey = GlobalKey<ScaffoldState>();

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        home: Scaffold(
          key: scaffoldKey,
          drawer: HomeNavigationDrawer(
            currentTab: 2,
            isCalendarExpanded: false,
            onCalendarToggle: () {},
            onVaultSetup: (context, folder) async => true,
            onCreateNoteFolder: () {},
            onClearVaultSelection: () {},
          ),
          body: const SizedBox.expand(),
        ),
      ),
    ),
  );

  scaffoldKey.currentState!.openDrawer();
  await tester.pumpAndSettle();
}

void main() {
  final folders = [
    NoteFolder(id: 'work', name: 'Work', color: 0xFF2196F3),
    NoteFolder(id: 'vault', name: 'Vault', isVault: true, color: 0xFFFFC107),
  ];

  group('HomeNavigationDrawer tag interactions', () {
    testWidgets('switching segment updates drawer tag scope', (tester) async {
      final container = ProviderContainer(
        overrides: [
          noteFoldersProvider.overrideWith(
            () => _FixedNoteFoldersNotifier(folders),
          ),
          drawerNoteTagsProvider.overrideWith((ref) => const ['alpha', 'beta']),
          tasksDrawerModuleProvider.overrideWith(
            () => _FixedTabDrawerModuleNotifier('none'),
          ),
          notesDrawerTagScopeProvider.overrideWith(
            () => _TestNotesDrawerTagScopeNotifier('all'),
          ),
          selectedNoteTagProvider.overrideWith(
            () => StateHolder<String?>(null),
          ),
          selectedNoteFolderProvider.overrideWith(
            () => StateHolder<String?>('work'),
          ),
        ],
      );
      addTearDown(container.dispose);

      await _pumpDrawer(tester, container);

      expect(container.read(notesDrawerTagScopeProvider), 'all');

      await tester.tap(find.text('Current folder'));
      await tester.pumpAndSettle();

      expect(container.read(notesDrawerTagScopeProvider), 'folder');
    });

    testWidgets('tapping a tag in all scope selects tag and resets folder', (
      tester,
    ) async {
      final container = ProviderContainer(
        overrides: [
          noteFoldersProvider.overrideWith(
            () => _FixedNoteFoldersNotifier(folders),
          ),
          drawerNoteTagsProvider.overrideWith((ref) => const ['alpha', 'beta']),
          tasksDrawerModuleProvider.overrideWith(
            () => _FixedTabDrawerModuleNotifier('none'),
          ),
          notesDrawerTagScopeProvider.overrideWith(
            () => _TestNotesDrawerTagScopeNotifier('all'),
          ),
          selectedNoteTagProvider.overrideWith(
            () => StateHolder<String?>(null),
          ),
          selectedNoteFolderProvider.overrideWith(
            () => StateHolder<String?>('work'),
          ),
        ],
      );
      addTearDown(container.dispose);

      await _pumpDrawer(tester, container);

      expect(container.read(selectedNoteFolderProvider), 'work');
      expect(container.read(selectedNoteTagProvider), isNull);

      await tester.ensureVisible(find.text('#alpha').first);
      await tester.tap(find.text('#alpha').first);
      await tester.pumpAndSettle();

      expect(container.read(selectedNoteTagProvider), 'alpha');
      expect(container.read(selectedNoteFolderProvider), isNull);
    });
  });
}
