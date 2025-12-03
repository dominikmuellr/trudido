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

import '../models/folder_template.dart';

/// Abstract repository interface for folder template operations
abstract class FolderTemplateRepository {
  /// Get all templates (built-in + custom)
  Future<List<FolderTemplate>> getAllTemplates();

  /// Get template by ID
  Future<FolderTemplate?> getTemplateById(String id);

  /// Create a new template
  Future<void> createTemplate(FolderTemplate template);

  /// Update an existing template
  Future<void> updateTemplate(FolderTemplate template);

  /// Delete a template by ID (only custom templates)
  Future<bool> deleteTemplate(String id);

  /// Get built-in templates only
  Future<List<FolderTemplate>> getBuiltInTemplates();

  /// Get user-created templates only
  Future<List<FolderTemplate>> getCustomTemplates();

  /// Search templates by name or keywords
  Future<List<FolderTemplate>> searchTemplates(String query);

  /// Suggest templates based on folder name
  Future<List<FolderTemplate>> suggestTemplatesForFolder(String folderName);

  /// Create template from existing folder
  Future<FolderTemplate> createTemplateFromFolder(
    String folderId,
    String templateName,
  );

  /// Track template usage
  Future<void> incrementTemplateUsage(String templateId);

  /// Get most used templates
  Future<List<FolderTemplate>> getMostUsedTemplates(int limit);

  /// Reset built-in template to original (if customized)
  Future<void> resetBuiltInTemplate(String templateId);
}
