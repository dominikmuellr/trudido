import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/folder_provider.dart';

/// Service to handle migration from categories to folders
class CategoryMigrationService {
  final Ref ref;

  CategoryMigrationService(this.ref);

  /// Creates default folders that correspond to the old category system
  Future<void> createDefaultFolders() async {
    final foldersNotifier = ref.read(folderNotifierProvider.notifier);

    // Get current folders
    final foldersAsync = ref.read(folderNotifierProvider);
    final existingFolders = foldersAsync.value ?? [];

    // Define default folders that replace the old categories
    final defaultFolders = [
      {
        'name': 'Personal',
        'description': 'Personal tasks and reminders',
        'color': 0xFF2196F3, // Blue
        'icon': 'person',
      },
      {
        'name': 'Work',
        'description': 'Work-related tasks and projects',
        'color': 0xFF4CAF50, // Green
        'icon': 'work',
      },
      {
        'name': 'Shopping',
        'description': 'Shopping lists and errands',
        'color': 0xFFFF9800, // Orange
        'icon': 'shopping_cart',
      },
      {
        'name': 'Health',
        'description': 'Health and wellness tasks',
        'color': 0xFFE91E63, // Pink
        'icon': 'favorite',
      },
    ];

    // Create folders that don't already exist
    for (final folderData in defaultFolders) {
      final name = folderData['name'] as String;
      final exists = existingFolders.any(
        (f) => f.name.toLowerCase() == name.toLowerCase(),
      );

      if (!exists) {
        await foldersNotifier.createFolder(
          name: name,
          description: folderData['description'] as String,
          color: folderData['color'] as int,
          icon: folderData['icon'] as String,
        );
      }
    }
  }

  /// Migrates any data by ensuring default folders exist
  /// This should be called once during app startup
  Future<void> migrateFromCategories() async {
    await createDefaultFolders();
    // Note: Since we removed the category field from Todo model,
    // tasks will simply have null folderId and appear
    // in the general task list. Users can manually move them to
    // the appropriate folders.
  }
}

final categoryMigrationProvider = Provider<CategoryMigrationService>((ref) {
  return CategoryMigrationService(ref);
});
