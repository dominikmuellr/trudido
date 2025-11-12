import 'package:hive/hive.dart';
import '../models/folder_template.dart';
import '../repositories/folder_template_repository.dart';
import '../services/storage_service.dart';

/// Concrete implementation of FolderTemplateRepository using Hive
class HiveFolderTemplateRepository implements FolderTemplateRepository {
  static const String _templatesBoxName = 'folder_templates';
  Box<FolderTemplate>? _templatesBox;

  /// Initialize the repository with Hive box
  Future<void> init() async {
    _templatesBox = await Hive.openBox<FolderTemplate>(_templatesBoxName);
    // Create built-in templates if none exist
    await _createBuiltInTemplatesIfNeeded();
  }

  @override
  Future<List<FolderTemplate>> getAllTemplates() async {
    if (_templatesBox == null) await init();
    final templates = _templatesBox!.values.toList();
    // Sort: built-in first, then by usage count, then by name
    templates.sort((a, b) {
      if (a.isBuiltIn && !b.isBuiltIn) return -1;
      if (!a.isBuiltIn && b.isBuiltIn) return 1;

      final usageComparison = b.useCount.compareTo(a.useCount);
      if (usageComparison != 0) return usageComparison;

      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return templates;
  }

  @override
  Future<FolderTemplate?> getTemplateById(String id) async {
    if (_templatesBox == null) await init();
    return _templatesBox!.get(id);
  }

  @override
  Future<void> createTemplate(FolderTemplate template) async {
    if (_templatesBox == null) await init();
    await _templatesBox!.put(template.id, template);
  }

  @override
  Future<void> updateTemplate(FolderTemplate template) async {
    if (_templatesBox == null) await init();
    final updatedTemplate = template.copyWith(updatedAt: DateTime.now());
    await _templatesBox!.put(template.id, updatedTemplate);
  }

  @override
  Future<bool> deleteTemplate(String id) async {
    if (_templatesBox == null) await init();
    final template = await getTemplateById(id);

    // Only allow deletion of custom templates
    if (template != null && !template.isBuiltIn) {
      await _templatesBox!.delete(id);
      return true;
    }
    return false;
  }

  @override
  Future<List<FolderTemplate>> getBuiltInTemplates() async {
    final allTemplates = await getAllTemplates();
    return allTemplates.where((template) => template.isBuiltIn).toList();
  }

  @override
  Future<List<FolderTemplate>> getCustomTemplates() async {
    final allTemplates = await getAllTemplates();
    return allTemplates.where((template) => !template.isBuiltIn).toList();
  }

  @override
  Future<List<FolderTemplate>> searchTemplates(String query) async {
    final allTemplates = await getAllTemplates();
    final lowercaseQuery = query.toLowerCase();

    return allTemplates.where((template) {
      final nameMatch = template.name.toLowerCase().contains(lowercaseQuery);
      final descriptionMatch =
          template.description?.toLowerCase().contains(lowercaseQuery) ?? false;
      final keywordMatch = template.keywords.any(
        (keyword) => keyword.toLowerCase().contains(lowercaseQuery),
      );
      return nameMatch || descriptionMatch || keywordMatch;
    }).toList();
  }

  @override
  Future<List<FolderTemplate>> suggestTemplatesForFolder(
    String folderName,
  ) async {
    final allTemplates = await getAllTemplates();
    final lowercaseName = folderName.toLowerCase();

    // Find templates with matching keywords
    final suggestions = allTemplates.where((template) {
      return template.keywords.any(
        (keyword) => lowercaseName.contains(keyword.toLowerCase()),
      );
    }).toList();

    // Sort by relevance (more keyword matches = higher relevance)
    suggestions.sort((a, b) {
      final aMatches = a.keywords
          .where((keyword) => lowercaseName.contains(keyword.toLowerCase()))
          .length;
      final bMatches = b.keywords
          .where((keyword) => lowercaseName.contains(keyword.toLowerCase()))
          .length;
      final matchComparison = bMatches.compareTo(aMatches);

      if (matchComparison != 0) return matchComparison;
      return b.useCount.compareTo(a.useCount); // Then by usage
    });

    return suggestions.take(3).toList(); // Top 3 suggestions
  }

  @override
  Future<FolderTemplate> createTemplateFromFolder(
    String folderId,
    String templateName,
  ) async {
    // Get folder and its todos
    await StorageService.waitTodosReady();
    final todos = await StorageService.getAllTodosAsync();
    final folderTodos = todos
        .where((todo) => todo.folderId == folderId)
        .toList();

    // Sort todos by creation order or custom order
    folderTodos.sort((a, b) => a.createdAt.compareTo(b.createdAt));

    // Convert todos to task templates
    final taskTemplates = folderTodos.asMap().entries.map((entry) {
      final index = entry.key;
      final todo = entry.value;

      return TaskTemplate(
        text: todo.text,
        priority: todo.priority,
        tags: todo.tags,
        notes: todo.notes,
        sortOrder: index,
        // Don't copy due dates as they're specific to the original folder
        reminderOffsets: todo.reminderOffsetsMinutes,
      );
    }).toList();

    // Create template
    final template = FolderTemplate(
      name: templateName,
      description: 'Template created from folder',
      keywords: _extractKeywordsFromName(templateName),
      taskTemplates: taskTemplates,
      isBuiltIn: false,
    );

    await createTemplate(template);
    return template;
  }

  @override
  Future<void> incrementTemplateUsage(String templateId) async {
    final template = await getTemplateById(templateId);
    if (template != null) {
      final updatedTemplate = template.copyWith(
        useCount: template.useCount + 1,
        updatedAt: DateTime.now(),
      );
      await updateTemplate(updatedTemplate);
    }
  }

  @override
  Future<List<FolderTemplate>> getMostUsedTemplates(int limit) async {
    final allTemplates = await getAllTemplates();
    final usedTemplates = allTemplates
        .where((template) => template.useCount > 0)
        .toList();
    usedTemplates.sort((a, b) => b.useCount.compareTo(a.useCount));
    return usedTemplates.take(limit).toList();
  }

  @override
  Future<void> resetBuiltInTemplate(String templateId) async {
    final template = await getTemplateById(templateId);
    if (template != null && template.isBuiltIn && template.isCustomized) {
      // Find original built-in template definition and restore it
      final originalTemplate = _getOriginalBuiltInTemplate(templateId);
      if (originalTemplate != null) {
        final restoredTemplate = originalTemplate.copyWith(
          id: templateId,
          useCount: template.useCount, // Keep usage stats
        );
        await updateTemplate(restoredTemplate);
      }
    }
  }

  /// Create built-in templates if they don't exist
  Future<void> _createBuiltInTemplatesIfNeeded() async {
    final existingTemplates = _templatesBox!.values.toList();

    if (existingTemplates.isEmpty ||
        !existingTemplates.any((t) => t.isBuiltIn)) {
      await _createBuiltInTemplates();
    }
  }

  /// Create the default built-in templates
  Future<void> _createBuiltInTemplates() async {
    final builtInTemplates = [
      // Project Management Template
      FolderTemplate(
        name: 'Project Workflow',
        description: 'Standard project management workflow',
        keywords: ['project', 'client', 'development', 'work', 'build'],
        isBuiltIn: true,
        taskTemplates: [
          TaskTemplate(
            text: 'Project Research & Planning',
            priority: 'high',
            sortOrder: 0,
            estimatedMinutes: 120,
          ),
          TaskTemplate(
            text: 'Requirements Gathering',
            priority: 'high',
            sortOrder: 1,
            estimatedMinutes: 90,
          ),
          TaskTemplate(
            text: 'Create Timeline & Milestones',
            priority: 'high',
            sortOrder: 2,
            estimatedMinutes: 60,
          ),
          TaskTemplate(
            text: 'Design & Architecture',
            priority: 'medium',
            sortOrder: 3,
            estimatedMinutes: 180,
          ),
          TaskTemplate(
            text: 'Implementation Phase',
            priority: 'high',
            sortOrder: 4,
            estimatedMinutes: 480,
          ),
          TaskTemplate(
            text: 'Testing & Quality Assurance',
            priority: 'high',
            sortOrder: 5,
            estimatedMinutes: 120,
          ),
          TaskTemplate(
            text: 'Client Review & Feedback',
            priority: 'medium',
            sortOrder: 6,
            estimatedMinutes: 60,
          ),
          TaskTemplate(
            text: 'Final Delivery & Documentation',
            priority: 'high',
            sortOrder: 7,
            estimatedMinutes: 90,
          ),
        ],
      ),

      // Shopping Template
      FolderTemplate(
        name: 'Shopping Trip',
        description: 'Organized shopping workflow',
        keywords: ['shopping', 'groceries', 'store', 'buy', 'purchase'],
        isBuiltIn: true,
        taskTemplates: [
          TaskTemplate(
            text: 'Check pantry & make list',
            priority: 'high',
            sortOrder: 0,
            estimatedMinutes: 15,
          ),
          TaskTemplate(
            text: 'Check weekly ads for deals',
            priority: 'low',
            sortOrder: 1,
            estimatedMinutes: 10,
          ),
          TaskTemplate(
            text: 'Grocery store visit',
            priority: 'high',
            sortOrder: 2,
            estimatedMinutes: 45,
          ),
          TaskTemplate(
            text: 'Pharmacy pickup',
            priority: 'medium',
            sortOrder: 3,
            estimatedMinutes: 10,
          ),
          TaskTemplate(
            text: 'Put everything away',
            priority: 'medium',
            sortOrder: 4,
            estimatedMinutes: 15,
          ),
        ],
      ),

      // Travel Planning Template
      FolderTemplate(
        name: 'Travel Planning',
        description: 'Complete travel preparation workflow',
        keywords: ['travel', 'trip', 'vacation', 'holiday', 'flight'],
        isBuiltIn: true,
        taskTemplates: [
          TaskTemplate(
            text: 'Research destinations & activities',
            priority: 'high',
            sortOrder: 0,
            estimatedMinutes: 120,
            dueDateOffset: -30,
          ),
          TaskTemplate(
            text: 'Book flights',
            priority: 'high',
            sortOrder: 1,
            estimatedMinutes: 30,
            dueDateOffset: -21,
          ),
          TaskTemplate(
            text: 'Find & book accommodation',
            priority: 'high',
            sortOrder: 2,
            estimatedMinutes: 45,
            dueDateOffset: -21,
          ),
          TaskTemplate(
            text: 'Plan daily itinerary',
            priority: 'medium',
            sortOrder: 3,
            estimatedMinutes: 90,
            dueDateOffset: -14,
          ),
          TaskTemplate(
            text: 'Check passport & documents',
            priority: 'high',
            sortOrder: 4,
            estimatedMinutes: 15,
            dueDateOffset: -14,
          ),
          TaskTemplate(
            text: 'Pack bags',
            priority: 'high',
            sortOrder: 5,
            estimatedMinutes: 60,
            dueDateOffset: -1,
          ),
          TaskTemplate(
            text: 'Check in online',
            priority: 'medium',
            sortOrder: 6,
            estimatedMinutes: 10,
            dueDateOffset: -1,
          ),
        ],
      ),

      // Home Maintenance Template
      FolderTemplate(
        name: 'Home Maintenance',
        description: 'Seasonal home maintenance checklist',
        keywords: [
          'home',
          'house',
          'maintenance',
          'repair',
          'cleaning',
          'seasonal',
        ],
        isBuiltIn: true,
        taskTemplates: [
          TaskTemplate(
            text: 'Check & replace air filters',
            priority: 'high',
            sortOrder: 0,
            estimatedMinutes: 15,
          ),
          TaskTemplate(
            text: 'Clean gutters',
            priority: 'medium',
            sortOrder: 1,
            estimatedMinutes: 120,
          ),
          TaskTemplate(
            text: 'Test smoke & carbon detectors',
            priority: 'high',
            sortOrder: 2,
            estimatedMinutes: 20,
          ),
          TaskTemplate(
            text: 'Deep clean carpets/floors',
            priority: 'medium',
            sortOrder: 3,
            estimatedMinutes: 180,
          ),
          TaskTemplate(
            text: 'Inspect & seal windows',
            priority: 'medium',
            sortOrder: 4,
            estimatedMinutes: 60,
          ),
          TaskTemplate(
            text: 'Service HVAC system',
            priority: 'high',
            sortOrder: 5,
            estimatedMinutes: 90,
          ),
        ],
      ),

      // Event Planning Template
      FolderTemplate(
        name: 'Event Planning',
        description: 'General event organization workflow',
        keywords: [
          'event',
          'party',
          'birthday',
          'wedding',
          'celebration',
          'gathering',
        ],
        isBuiltIn: true,
        taskTemplates: [
          TaskTemplate(
            text: 'Set date & create guest list',
            priority: 'high',
            sortOrder: 0,
            estimatedMinutes: 30,
            dueDateOffset: -21,
          ),
          TaskTemplate(
            text: 'Send invitations',
            priority: 'high',
            sortOrder: 1,
            estimatedMinutes: 45,
            dueDateOffset: -14,
          ),
          TaskTemplate(
            text: 'Plan menu & order food/catering',
            priority: 'high',
            sortOrder: 2,
            estimatedMinutes: 60,
            dueDateOffset: -7,
          ),
          TaskTemplate(
            text: 'Buy decorations & supplies',
            priority: 'medium',
            sortOrder: 3,
            estimatedMinutes: 90,
            dueDateOffset: -3,
          ),
          TaskTemplate(
            text: 'Prepare venue & setup',
            priority: 'high',
            sortOrder: 4,
            estimatedMinutes: 120,
            dueDateOffset: -1,
          ),
          TaskTemplate(
            text: 'Day-of coordination',
            priority: 'high',
            sortOrder: 5,
            estimatedMinutes: 60,
          ),
          TaskTemplate(
            text: 'Cleanup & thank guests',
            priority: 'medium',
            sortOrder: 6,
            estimatedMinutes: 90,
            dueDateOffset: 1,
          ),
        ],
      ),
    ];

    for (final template in builtInTemplates) {
      await createTemplate(template);
    }
  }

  /// Extract keywords from template name for searching
  List<String> _extractKeywordsFromName(String name) {
    final words = name.toLowerCase().split(RegExp(r'[\s\-_]+'));
    return words.where((word) => word.length > 2).toList();
  }

  /// Get original built-in template definition (for reset functionality)
  FolderTemplate? _getOriginalBuiltInTemplate(String templateId) {
    // This would contain the original definitions of built-in templates
    // In a real implementation, you'd store these separately or have a reset mechanism
    // For now, return null as this is a complex feature
    return null;
  }
}
