import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/folder_template.dart';
import '../repositories/folder_template_repository.dart';
import '../repositories/hive_folder_template_repository.dart';
import '../use_cases/folder_template_use_cases.dart';

// Repository provider
final folderTemplateRepositoryProvider = Provider<FolderTemplateRepository>((
  ref,
) {
  return HiveFolderTemplateRepository();
});

// Use case providers
final getTemplatesUseCaseProvider = Provider<GetTemplatesUseCase>((ref) {
  return GetTemplatesUseCase(ref.read(folderTemplateRepositoryProvider));
});

final createTemplateUseCaseProvider = Provider<CreateTemplateUseCase>((ref) {
  return CreateTemplateUseCase(ref.read(folderTemplateRepositoryProvider));
});

final suggestTemplatesUseCaseProvider = Provider<SuggestTemplatesUseCase>((
  ref,
) {
  return SuggestTemplatesUseCase(ref.read(folderTemplateRepositoryProvider));
});

final createFromFolderUseCaseProvider =
    Provider<CreateTemplateFromFolderUseCase>((ref) {
      return CreateTemplateFromFolderUseCase(
        ref.read(folderTemplateRepositoryProvider),
      );
    });

final applyTemplateUseCaseProvider = Provider<ApplyTemplateUseCase>((ref) {
  return ApplyTemplateUseCase(ref.read(folderTemplateRepositoryProvider));
});

// State notifier for templates
final templateNotifierProvider =
    StateNotifierProvider<TemplateNotifier, AsyncValue<List<FolderTemplate>>>((
      ref,
    ) {
      return TemplateNotifier(
        ref.read(getTemplatesUseCaseProvider),
        ref.read(folderTemplateRepositoryProvider),
      );
    });

/// State notifier for managing folder templates
class TemplateNotifier extends StateNotifier<AsyncValue<List<FolderTemplate>>> {
  final GetTemplatesUseCase _getTemplatesUseCase;
  final FolderTemplateRepository _repository;

  TemplateNotifier(this._getTemplatesUseCase, this._repository)
    : super(const AsyncValue.loading()) {
    loadTemplates();
  }

  /// Load all templates
  Future<void> loadTemplates() async {
    state = const AsyncValue.loading();
    try {
      final templates = await _getTemplatesUseCase();
      state = AsyncValue.data(templates);
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }

  /// Create a new template
  Future<void> createTemplate(FolderTemplate template) async {
    await _repository.createTemplate(template);
    await loadTemplates(); // Reload to update state
  }

  /// Update a template
  Future<void> updateTemplate(FolderTemplate template) async {
    await _repository.updateTemplate(template);
    await loadTemplates(); // Reload to update state
  }

  /// Delete a template
  Future<bool> deleteTemplate(String templateId) async {
    final result = await _repository.deleteTemplate(templateId);
    await loadTemplates(); // Reload to update state
    return result;
  }

  /// Increment template usage count
  Future<void> incrementUsage(String templateId) async {
    await _repository.incrementTemplateUsage(templateId);
    await loadTemplates(); // Reload to update state
  }

  /// Reset built-in template to original
  Future<void> resetTemplate(String templateId) async {
    await _repository.resetBuiltInTemplate(templateId);
    await loadTemplates(); // Reload to update state
  }
}
