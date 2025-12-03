// Trudido - A privacy-focused todo and notes app
// Copyright (C) 2025 Dominik Müller
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

import 'package:flutter/foundation.dart';
import '../models/folder_template.dart';
import '../models/todo.dart';
import '../repositories/folder_template_repository.dart';
import '../services/storage_service.dart';

/// Use case for getting all templates
class GetTemplatesUseCase {
  final FolderTemplateRepository _repository;

  GetTemplatesUseCase(this._repository);

  Future<List<FolderTemplate>> call() async {
    return await _repository.getAllTemplates();
  }
}

/// Use case for creating a new template
class CreateTemplateUseCase {
  final FolderTemplateRepository _repository;

  CreateTemplateUseCase(this._repository);

  Future<void> call(FolderTemplate template) async {
    await _repository.createTemplate(template);
  }
}

/// Use case for suggesting templates based on folder name
class SuggestTemplatesUseCase {
  final FolderTemplateRepository _repository;

  SuggestTemplatesUseCase(this._repository);

  Future<List<FolderTemplate>> call(String folderName) async {
    return await _repository.suggestTemplatesForFolder(folderName);
  }
}

/// Use case for creating template from a folder
class CreateTemplateFromFolderUseCase {
  final FolderTemplateRepository _repository;

  CreateTemplateFromFolderUseCase(this._repository);

  Future<FolderTemplate> call(String folderId, String templateName) async {
    return await _repository.createTemplateFromFolder(folderId, templateName);
  }
}

/// Use case for applying a template to create tasks in a folder
class ApplyTemplateUseCase {
  final FolderTemplateRepository _repository;

  ApplyTemplateUseCase(this._repository);

  Future<List<Todo>> call(
    FolderTemplate template,
    String folderId, {
    DateTime? baseDueDate,
  }) async {
    final todos = <Todo>[];
    // Ensure storage (lazy todos box) is ready before attempting to save created todos.
    await StorageService.waitTodosReady();

    for (final taskTemplate in template.taskTemplates) {
      // Calculate due date if template has offset
      DateTime? dueDate;
      if (taskTemplate.dueDateOffset != null && baseDueDate != null) {
        dueDate = baseDueDate.add(Duration(days: taskTemplate.dueDateOffset!));
      }

      // Create todo from template
      final todo = Todo(
        text: taskTemplate.text,
        folderId: folderId,
        priority: taskTemplate.priority,
        tags: taskTemplate.tags,
        notes: taskTemplate.notes,
        dueDate: dueDate,
        reminderOffsetsMinutes: taskTemplate.reminderOffsets,
      );

      // Add to storage - protect each save so one failure doesn't abort the rest
      try {
        await StorageService.saveTodo(todo);
        todos.add(todo);
      } catch (e, st) {
        // Log and continue applying remaining tasks
        debugPrint(
          '[ApplyTemplateUseCase] Failed to save todo from template: $e\n$st',
        );
      }
    }

    // Increment template usage
    await _repository.incrementTemplateUsage(template.id);

    return todos;
  }
}
