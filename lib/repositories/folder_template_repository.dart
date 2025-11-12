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
