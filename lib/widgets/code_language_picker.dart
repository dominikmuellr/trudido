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

import 'package:flutter/material.dart';

import '../utils/language_detector.dart';
import 'code_block_markdown_builder.dart';

/// Dialog for selecting a programming language for a code block.
///
/// Returns the selected language identifier string (e.g. 'dart', 'python')
/// or null if cancelled.
class CodeLanguagePickerDialog extends StatefulWidget {
  /// If provided, the existing code text is used for auto-detection.
  final String? existingCode;

  /// Pre-selected language (e.g. when editing an existing code block).
  final String? initialLanguage;

  const CodeLanguagePickerDialog({
    super.key,
    this.existingCode,
    this.initialLanguage,
  });

  @override
  State<CodeLanguagePickerDialog> createState() =>
      _CodeLanguagePickerDialogState();
}

class _CodeLanguagePickerDialogState extends State<CodeLanguagePickerDialog> {
  late String _selected;
  String _filter = '';
  String? _autoDetected;

  @override
  void initState() {
    super.initState();
    if (widget.existingCode != null && widget.existingCode!.trim().isNotEmpty) {
      _autoDetected = LanguageDetector.detectLanguage(widget.existingCode!);
    }
    _selected =
        widget.initialLanguage ?? _autoDetected ?? 'plaintext';
  }

  List<String> get _filteredLanguages {
    if (_filter.isEmpty) return LanguageDetector.commonLanguages;
    final lower = _filter.toLowerCase();
    return LanguageDetector.commonLanguages
        .where((l) => l.contains(lower))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return AlertDialog(
      icon: const Icon(Icons.code, size: 32),
      title: const Text('Code Block Language'),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Auto-detect hint
            if (_autoDetected != null && _autoDetected != 'plaintext') ...[
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.auto_awesome,
                        size: 16, color: colorScheme.primary),
                    const SizedBox(width: 8),
                    Text(
                      'Auto-detected: ',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    Text(
                      _autoDetected!,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: colorScheme.primary,
                          ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],

            // Search / filter field
            TextField(
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Search language...',
                prefixIcon: const Icon(Icons.search, size: 20),
                isDense: true,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onChanged: (value) => setState(() => _filter = value),
            ),
            const SizedBox(height: 8),

            // Language list
            Flexible(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 250),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _filteredLanguages.length,
                  itemBuilder: (context, index) {
                    final lang = _filteredLanguages[index];
                    final isSelected = lang == _selected;
                    final isAutoDetected = lang == _autoDetected;
                    return ListTile(
                      dense: true,
                      visualDensity: VisualDensity.compact,
                      selected: isSelected,
                      selectedTileColor:
                          colorScheme.primaryContainer.withValues(alpha: 0.3),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      leading: lang == 'plaintext'
                          ? null
                          : LanguageBadge(language: lang, fontSize: 9),
                      title: Text(
                        lang,
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontWeight:
                              isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                      trailing: isAutoDetected
                          ? Icon(Icons.auto_awesome,
                              size: 16, color: colorScheme.primary)
                          : isSelected
                              ? Icon(Icons.check,
                                  size: 18, color: colorScheme.primary)
                              : null,
                      onTap: () {
                        setState(() => _selected = lang);
                      },
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_selected),
          child: const Text('Insert'),
        ),
      ],
    );
  }
}
