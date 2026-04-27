import 'package:flutter_test/flutter_test.dart';
import 'package:trudido/controllers/notes_controller.dart';
import 'package:trudido/models/note.dart';
import 'package:trudido/models/note_folder.dart';

void main() {
  Note note({
    required String id,
    String? folderId,
    required List<String> tags,
  }) {
    return Note(id: id, title: id, content: '', folderId: folderId, tags: tags);
  }

  NoteFolder folder({required String id, required bool isVault}) {
    return NoteFolder(id: id, name: id, isVault: isVault);
  }

  group('buildDrawerTags', () {
    final folders = [
      folder(id: 'work', isVault: false),
      folder(id: 'vault', isVault: true),
    ];

    final notes = [
      note(id: 'n1', folderId: 'work', tags: ['alpha', 'Beta']),
      note(id: 'n2', folderId: 'vault', tags: ['secret', 'alpha']),
      note(id: 'n3', folderId: null, tags: ['gamma', 'beta']),
    ];

    test('all scope excludes vault tags and prioritizes recent tags', () {
      final result = buildDrawerTags(
        notes: notes,
        folders: folders,
        scope: 'all',
        selectedFolderId: null,
        recentTags: const ['gamma', 'beta', 'missing'],
      );

      expect(result, equals(['gamma', 'Beta', 'alpha']));
      expect(result, isNot(contains('secret')));
    });

    test('folder scope limits tags to selected folder', () {
      final result = buildDrawerTags(
        notes: notes,
        folders: folders,
        scope: 'folder',
        selectedFolderId: 'work',
        recentTags: const ['beta', 'gamma'],
      );

      expect(result, equals(['Beta', 'alpha']));
      expect(result, isNot(contains('gamma')));
    });

    test('folder scope supports unfiled selection', () {
      final result = buildDrawerTags(
        notes: notes,
        folders: folders,
        scope: 'folder',
        selectedFolderId: 'UNFILED',
        recentTags: const [],
      );

      expect(result, equals(['beta', 'gamma']));
    });
  });

  group('orderTagsByRecentUsage', () {
    test('dedupes case-insensitively and keeps alphabetical fallback', () {
      final result = orderTagsByRecentUsage(
        tags: const ['Work', 'home', 'Errands', 'work'],
        recentTags: const ['HOME', 'unknown', 'work', 'home'],
      );

      expect(result, equals(['home', 'Work', 'Errands']));
    });
  });
}
