import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:trudido/repositories/notes_repository.dart';
import 'package:trudido/repositories/note_folder_repository.dart';
import 'package:trudido/services/storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const String testPathChannel = 'plugins.flutter.io/path_provider';
  const MethodChannel channel = MethodChannel(testPathChannel);

  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'getApplicationDocumentsDirectory') {
          return 'test_documents';
        }
        return null;
      });

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

  group('Notes Feature Tests', () {
    final testPath = '${Directory.current.path}/test/test_documents';

    setUpAll(() async {
      Hive.init(testPath);
      await StorageService.init();
    });

    tearDownAll(() async {
      await Hive.close();
      final dir = Directory(testPath);
      if (await dir.exists()) {
        await dir.delete(recursive: true);
      }
    });

    setUp(() async {
      await StorageService.clearAllData();
    });

    test('NotesRepository should create and manage notes', () async {
      final repository = NotesRepository(NoteFolderRepository());

      final note = await repository.createNote(
        title: 'Test Note',
        content: '# Hello World\n\nThis is a **test** note.',
      );

      expect(note.title, 'Test Note');
      expect(note.content.contains('Hello World'), isTrue);
      expect(note.id.isNotEmpty, isTrue);

      final allNotes = await repository.getAllNotes();
      expect(allNotes.any((n) => n.id == note.id), isTrue);
      expect(allNotes.length, greaterThan(0));

      final updatedNote = await repository.updateNote(
        id: note.id,
        title: 'Updated Title',
        content: 'Updated content',
      );

      expect(updatedNote, isNotNull);
      expect(updatedNote!.title, 'Updated Title');
      expect(updatedNote.content, 'Updated content');
      expect(updatedNote.updatedAt.isAfter(note.createdAt), isTrue);

      final searchResults = await repository.searchNotes('Updated');
      expect(searchResults.any((n) => n.id == updatedNote.id), isTrue);

      final deleted = await repository.deleteNote(note.id);
      expect(deleted, isTrue);
      final notesAfterDeletion = await repository.getAllNotes();
      expect(notesAfterDeletion.any((n) => n.id == note.id), isFalse);
    });

    test('NotesNotifier should manage state correctly', () async {
      final container = ProviderContainer();
      final notifier = container.read(notesProvider.notifier);

      await container.read(notesProvider.future);
      final initialNotes = container.read(notesProvider).value ?? [];
      final initialCount = initialNotes.length;

      final newNote = await notifier.createNote(
        title: 'Test State Note',
        content: 'Testing state management',
      );

      final notesAfterCreation = await container.read(notesProvider.future);
      expect(notesAfterCreation.length, initialCount + 1);
      expect(notesAfterCreation.any((n) => n.id == newNote.id), isTrue);

      final updatedNote = await notifier.updateNote(
        id: newNote.id,
        title: 'Updated State Note',
      );

      expect(updatedNote, isNotNull);
      final notesAfterUpdate = await container.read(notesProvider.future);
      expect(
        notesAfterUpdate.any((note) => note.title == 'Updated State Note'),
        isTrue,
      );

      final deleted = await notifier.deleteNote(newNote.id);
      expect(deleted, isTrue);
      final notesAfterDeletion = await container.read(notesProvider.future);
      expect(notesAfterDeletion.length, initialCount);

      container.dispose();
    });

    test('Search functionality should work correctly', () async {
      final repository = NotesRepository(NoteFolderRepository());

      await repository.createNote(
        title: 'Flutter Development',
        content: 'Learning Flutter framework',
      );

      await repository.createNote(
        title: 'Dart Language',
        content: 'Dart programming language basics',
      );

      await repository.createNote(
        title: 'Mobile App',
        content: 'Building mobile applications with Flutter',
      );

      final allNotes = await repository.getAllNotes();
      print('All notes: ${allNotes.map((n) => n.title).toList()}');

      var results = await repository.searchNotes('Flutter');
      print(
        'Search results for "Flutter": ${results.map((n) => n.title).toList()}',
      );
      expect(results.length, 2);

      results = await repository.searchNotes('programming language');
      expect(results.length, 1);

      results = await repository.searchNotes('flutter');
      expect(results.length, 2);

      results = await repository.searchNotes('');
      expect(results.length, greaterThanOrEqualTo(3));
    });
  });
}
