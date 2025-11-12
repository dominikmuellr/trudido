/// Utility for converting between Markdown and todo.txt formats
class TodoTxtConverter {
  /// Converts Markdown content to todo.txt format
  /// Extracts checklist items and converts them to todo.txt lines
  static String markdownToTodoTxt(String markdown) {
    final lines = markdown.split('\n');
    final todoLines = <String>[];

    for (var line in lines) {
      // Match Markdown task: - [ ] or - [x] or * [ ] or * [x]
      final match = RegExp(
        r'^[-*]\s+\[( |x|X)\]\s+(.*)',
      ).firstMatch(line.trim());
      if (match != null) {
        final isCompleted = match.group(1)?.toLowerCase() == 'x';
        final text = match.group(2) ?? '';

        // Parse priority if present (A), (B), etc.
        String? priority;
        var taskText = text;
        final priorityMatch = RegExp(r'^\(([A-Z])\)\s+(.*)').firstMatch(text);
        if (priorityMatch != null) {
          priority = priorityMatch.group(1);
          taskText = priorityMatch.group(2) ?? '';
        }

        // Parse contexts (@context) and projects (+project)
        final contexts = <String>[];
        final projects = <String>[];
        final words = taskText.split(' ');
        final cleanWords = <String>[];

        for (var word in words) {
          if (word.startsWith('@') && word.length > 1) {
            contexts.add(word.substring(1));
          } else if (word.startsWith('+') && word.length > 1) {
            projects.add(word.substring(1));
          } else {
            cleanWords.add(word);
          }
        }

        // Build todo.txt line
        var todoLine = '';
        if (isCompleted) todoLine += 'x ';
        if (priority != null) todoLine += '($priority) ';
        todoLine += cleanWords.join(' ');
        for (var project in projects) {
          todoLine += ' +$project';
        }
        for (var context in contexts) {
          todoLine += ' @$context';
        }

        todoLines.add(todoLine.trim());
      }
    }

    return todoLines.join('\n');
  }

  /// Converts todo.txt format to Markdown checklist
  static String todoTxtToMarkdown(String todoTxt) {
    final lines = todoTxt.split('\n');
    final markdownLines = <String>[];

    for (var line in lines) {
      if (line.trim().isEmpty) continue;

      var remaining = line.trim();
      var isCompleted = false;
      String? priority;

      // Check for completion
      if (remaining.startsWith('x ')) {
        isCompleted = true;
        remaining = remaining.substring(2).trim();
      }

      // Check for priority
      final priorityMatch = RegExp(
        r'^\(([A-Z])\)\s+(.*)',
      ).firstMatch(remaining);
      if (priorityMatch != null) {
        priority = priorityMatch.group(1);
        remaining = priorityMatch.group(2) ?? '';
      }

      // Parse dates (completion date and creation date)
      // Format: YYYY-MM-DD
      final datePattern = RegExp(r'^\d{4}-\d{2}-\d{2}\s+');
      while (datePattern.hasMatch(remaining)) {
        remaining = remaining.replaceFirst(datePattern, '').trim();
      }

      // Build markdown line
      final checkbox = isCompleted ? '[x]' : '[ ]';
      var markdownLine = '- $checkbox ';
      if (priority != null) {
        markdownLine += '($priority) ';
      }
      markdownLine += remaining;

      markdownLines.add(markdownLine);
    }

    return markdownLines.join('\n');
  }

  /// Syncs todo.txt content with markdown content
  /// If user edits markdown, update todo.txt; if user edits todo.txt, update markdown
  static String syncFromMarkdown(String markdown) {
    return markdownToTodoTxt(markdown);
  }

  /// Syncs markdown content with todo.txt content
  static String syncFromTodoTxt(String todoTxt) {
    return todoTxtToMarkdown(todoTxt);
  }

  /// Checks if markdown content contains any todo items
  static bool hasMarkdownTasks(String markdown) {
    return RegExp(r'^[-*]\s+\[( |x|X)\]', multiLine: true).hasMatch(markdown);
  }

  /// Checks if content is in todo.txt format
  static bool isTodoTxtFormat(String content) {
    final lines = content.split('\n').where((l) => l.trim().isNotEmpty);
    if (lines.isEmpty) return false;

    // Check if any line matches todo.txt patterns
    for (var line in lines) {
      // Must start with optional 'x ', optional priority, or just text
      if (RegExp(r'^(x\s+)?(\([A-Z]\)\s+)?.*').hasMatch(line.trim())) {
        return true;
      }
    }
    return false;
  }

  /// Sorts todo.txt lines by priority and completion status
  /// Incomplete tasks first, then by priority (A-Z), then alphabetically
  static String sortTodoTxt(String todoTxt) {
    return _sortTodoTxtBy(todoTxt, 'priority');
  }

  /// Sorts todo.txt by different criteria
  static String sortByPriority(String todoTxt) {
    return _sortTodoTxtBy(todoTxt, 'priority');
  }

  static String sortByProject(String todoTxt) {
    return _sortTodoTxtBy(todoTxt, 'project');
  }

  static String sortByContext(String todoTxt) {
    return _sortTodoTxtBy(todoTxt, 'context');
  }

  static String sortByCompletion(String todoTxt) {
    return _sortTodoTxtBy(todoTxt, 'completion');
  }

  /// Internal sorting function
  static String _sortTodoTxtBy(String todoTxt, String sortBy) {
    final lines = todoTxt.split('\n');
    final tasks = <_TodoTask>[];
    final comments = <String>[];
    final headerLines = <String>[]; // For title and subtitle

    // Extract title (first line) and optional subtitle (second line if not a task)
    int taskStartIndex = 0;
    if (lines.isNotEmpty) {
      final firstLine = lines.first.trim();
      if (firstLine.isNotEmpty) {
        headerLines.add(lines.first); // Keep original with spacing
        taskStartIndex = 1;

        // Check if second line is a subtitle (not a task)
        if (lines.length > 1) {
          final secondLine = lines[1].trim();
          if (secondLine.isNotEmpty &&
              !secondLine.startsWith('x ') &&
              !RegExp(r'^\([A-Z]\)').hasMatch(secondLine) &&
              !secondLine.startsWith('#')) {
            headerLines.add(lines[1]); // Keep original with spacing
            taskStartIndex = 2;
          }
        }
      }
    }

    for (var i = taskStartIndex; i < lines.length; i++) {
      final line = lines[i];
      if (line.trim().isEmpty) {
        continue; // Skip empty lines
      }

      if (line.trim().startsWith('#')) {
        comments.add(line); // Keep comments at top
        continue;
      }

      var remaining = line.trim();
      var isCompleted = false;
      String? priority;
      String? project;
      String? context;

      // Check for completion
      if (remaining.startsWith('x ')) {
        isCompleted = true;
        remaining = remaining.substring(2).trim();
      }

      // Check for priority
      final priorityMatch = RegExp(
        r'^\(([A-Z])\)\s+(.*)',
      ).firstMatch(remaining);
      if (priorityMatch != null) {
        priority = priorityMatch.group(1);
        remaining = priorityMatch.group(2) ?? '';
      }

      // Extract first project and context
      final projectMatch = RegExp(r'\+(\w+)').firstMatch(line);
      if (projectMatch != null) {
        project = projectMatch.group(1);
      }

      final contextMatch = RegExp(r'@(\w+)').firstMatch(line);
      if (contextMatch != null) {
        context = contextMatch.group(1);
      }

      tasks.add(
        _TodoTask(
          line: line,
          isCompleted: isCompleted,
          priority: priority,
          text: remaining,
          project: project,
          context: context,
        ),
      );
    }

    // Sort based on criteria
    tasks.sort((a, b) {
      switch (sortBy) {
        case 'priority':
          // Incomplete first, then by priority, then alphabetically (case-insensitive)
          if (a.isCompleted != b.isCompleted) {
            return a.isCompleted ? 1 : -1;
          }
          if (a.priority != null && b.priority != null) {
            return a.priority!.compareTo(b.priority!);
          }
          if (a.priority != null) return -1;
          if (b.priority != null) return 1;
          return a.text.toLowerCase().compareTo(b.text.toLowerCase());

        case 'project':
          // Group by project (case-insensitive)
          if (a.project != null && b.project != null) {
            final projectCompare = a.project!.toLowerCase().compareTo(
              b.project!.toLowerCase(),
            );
            if (projectCompare != 0) return projectCompare;
          }
          if (a.project != null) return -1;
          if (b.project != null) return 1;
          // Then by completion
          if (a.isCompleted != b.isCompleted) {
            return a.isCompleted ? 1 : -1;
          }
          return a.text.toLowerCase().compareTo(b.text.toLowerCase());

        case 'context':
          // Group by context (case-insensitive)
          if (a.context != null && b.context != null) {
            final contextCompare = a.context!.toLowerCase().compareTo(
              b.context!.toLowerCase(),
            );
            if (contextCompare != 0) return contextCompare;
          }
          if (a.context != null) return -1;
          if (b.context != null) return 1;
          // Then by completion
          if (a.isCompleted != b.isCompleted) {
            return a.isCompleted ? 1 : -1;
          }
          return a.text.toLowerCase().compareTo(b.text.toLowerCase());

        case 'completion':
          // Incomplete first, then completed (case-insensitive text)
          if (a.isCompleted != b.isCompleted) {
            return a.isCompleted ? 1 : -1;
          }
          return a.text.toLowerCase().compareTo(b.text.toLowerCase());

        default:
          return a.text.toLowerCase().compareTo(b.text.toLowerCase());
      }
    });

    // Combine header, comments, and sorted tasks
    final result = <String>[];

    // Add title and subtitle first
    if (headerLines.isNotEmpty) {
      result.addAll(headerLines);
      if (comments.isNotEmpty || tasks.isNotEmpty) {
        result.add(''); // Empty line after header
      }
    }

    // Then comments
    if (comments.isNotEmpty) {
      result.addAll(comments);
      if (tasks.isNotEmpty) {
        result.add(''); // Empty line after comments
      }
    }

    // Finally sorted tasks
    result.addAll(tasks.map((t) => t.line));

    return result.join('\n');
  }

  /// Filters todo.txt by project
  static String filterByProject(String todoTxt, String project) {
    final lines = todoTxt.split('\n');
    final filtered = lines.where((line) => line.contains('+$project')).toList();
    return filtered.join('\n');
  }

  /// Filters todo.txt by context
  static String filterByContext(String todoTxt, String context) {
    final lines = todoTxt.split('\n');
    final filtered = lines.where((line) => line.contains('@$context')).toList();
    return filtered.join('\n');
  }

  /// Gets all projects from todo.txt content
  static Set<String> getProjects(String todoTxt) {
    final projects = <String>{};
    final projectPattern = RegExp(r'\+(\w+)');
    final matches = projectPattern.allMatches(todoTxt);
    for (var match in matches) {
      projects.add(match.group(1)!);
    }
    return projects;
  }

  /// Gets all contexts from todo.txt content
  static Set<String> getContexts(String todoTxt) {
    final contexts = <String>{};
    final contextPattern = RegExp(r'@(\w+)');
    final matches = contextPattern.allMatches(todoTxt);
    for (var match in matches) {
      contexts.add(match.group(1)!);
    }
    return contexts;
  }
}

/// Helper class for sorting todo.txt tasks
class _TodoTask {
  final String line;
  final bool isCompleted;
  final String? priority;
  final String text;
  final String? project;
  final String? context;

  _TodoTask({
    required this.line,
    required this.isCompleted,
    this.priority,
    required this.text,
    this.project,
    this.context,
  });
}
