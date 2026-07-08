// Trudido - A privacy-focused todo and notes app
// Copyright (C) 2026 Dominik Müller
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program. If not, see <https://www.gnu.org/licenses/>.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/folder_template.dart';
import '../repositories/folder_template_repository.dart';
import '../repositories/isar_folder_template_repository.dart';
import '../use_cases/folder_template_use_cases.dart';

// Repository provider
final folderTemplateRepositoryProvider = Provider<FolderTemplateRepository>((
  ref,
) {
  return IsarFolderTemplateRepository();
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
    NotifierProvider<TemplateNotifier, AsyncValue<List<FolderTemplate>>>(
      TemplateNotifier.new,
    );

/// State notifier for managing folder templates
class TemplateNotifier extends Notifier<AsyncValue<List<FolderTemplate>>> {
  GetTemplatesUseCase get _getTemplatesUseCase =>
      ref.read(getTemplatesUseCaseProvider);
  FolderTemplateRepository get _repository =>
      ref.read(folderTemplateRepositoryProvider);

  @override
  AsyncValue<List<FolderTemplate>> build() {
    loadTemplates();
    return const AsyncValue.loading();
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
