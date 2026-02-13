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

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../screens/home_screen_notifiers.dart';
import '../controllers/notes_controller.dart';
import '../repositories/note_folder_repository.dart';
import '../widgets/common/common.dart';

/// Input context type for quick input bar
enum QuickInputContext { tasks, notes, vaultNotes }

/// Modern Material 3 bottom input bar for quick task/note creation
/// Experimental feature that replaces FAB menu when enabled
class QuickInputBar extends ConsumerStatefulWidget {
  /// Opens full task editor with the typed text
  final void Function(String text) onAddTask;

  /// Opens full note editor with the typed text
  final void Function(String text) onAddNote;

  /// Quick save note directly without opening editor
  final void Function(String text)? onQuickSaveNote;

  /// Opens full vault note editor
  final void Function(String text) onAddVaultNote;

  /// Quick save vault note directly
  final void Function(String text)? onQuickSaveVaultNote;

  const QuickInputBar({
    super.key,
    required this.onAddTask,
    required this.onAddNote,
    this.onQuickSaveNote,
    required this.onAddVaultNote,
    this.onQuickSaveVaultNote,
  });

  @override
  ConsumerState<QuickInputBar> createState() => _QuickInputBarState();
}

class _QuickInputBarState extends ConsumerState<QuickInputBar> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  /// Get the current input context based on active tab and folder selection
  QuickInputContext _getInputContext() {
    final currentTab = ref.watch(currentTabProvider);

    // Tab 0 = Tasks, Tab 1 = Notes
    if (currentTab == 0) {
      return QuickInputContext.tasks;
    }

    // Check if we're in a vault folder
    final selectedFolderId = ref.watch(selectedNoteFolderProvider);
    if (selectedFolderId != null) {
      final foldersAsync = ref.watch(noteFoldersProvider);
      final folders = foldersAsync.value ?? [];
      final folder = folders.where((f) => f.id == selectedFolderId).firstOrNull;
      if (folder != null && folder.isVault) {
        return QuickInputContext.vaultNotes;
      }
    }

    return QuickInputContext.notes;
  }

  /// Get placeholder text based on context
  String _getPlaceholder(QuickInputContext context) {
    switch (context) {
      case QuickInputContext.tasks:
        return 'Add task for today...';
      case QuickInputContext.notes:
        return 'Add quick note...';
      case QuickInputContext.vaultNotes:
        return 'Add quick vault note...';
    }
  }

  /// Handle main submit action (opens full editor)
  void _handleSubmit() {
    final text = _controller.text.trim();
    // Opens full editor even with empty text

    final context = _getInputContext();
    switch (context) {
      case QuickInputContext.tasks:
        widget.onAddTask(text);
        break;
      case QuickInputContext.notes:
        widget.onAddNote(text);
        break;
      case QuickInputContext.vaultNotes:
        widget.onAddVaultNote(text);
        break;
    }

    // Clear input after submit
    _controller.clear();
    _focusNode.unfocus();
  }

  /// Handle quick save (saves note directly without opening editor)
  void _handleQuickSave() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    final context = _getInputContext();
    switch (context) {
      case QuickInputContext.tasks:
        // For tasks, quick save is same as submit
        widget.onAddTask(text);
        break;
      case QuickInputContext.notes:
        if (widget.onQuickSaveNote != null) {
          widget.onQuickSaveNote!(text);
        } else {
          widget.onAddNote(text);
        }
        break;
      case QuickInputContext.vaultNotes:
        if (widget.onQuickSaveVaultNote != null) {
          widget.onQuickSaveVaultNote!(text);
        } else {
          widget.onAddVaultNote(text);
        }
        break;
    }

    // Clear input after submit
    _controller.clear();
    _focusNode.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final inputContext = _getInputContext();
    final isTasksContext = inputContext == QuickInputContext.tasks;

    return Material(
      color: Colors.transparent,
      child: Row(
        children: [
          // Text input field - simple, no container
          Expanded(
            child: TextField(
              controller: _controller,
              focusNode: _focusNode,
              maxLines: 2,
              minLines: 1,
              textInputAction: TextInputAction.send,
              // Enter key always quick saves (for both notes and tasks)
              onSubmitted: (_) => _handleQuickSave(),
              style: theme.textTheme.bodyLarge?.copyWith(
                color: colorScheme.onTertiaryContainer,
              ),
              decoration: InputDecoration(
                hintText: _getPlaceholder(inputContext),
                hintStyle: theme.textTheme.bodyLarge?.copyWith(
                  color: colorScheme.onTertiaryContainer.withValues(alpha: 0.7),
                ),
                filled: true,
                fillColor: colorScheme.tertiaryContainer,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
            ),
          ),

          // Pencil icon - only for Tasks tab (opens task editor)
          if (isTasksContext) ...[
            const SizedBox(width: 8),
            ExpressiveIconButton(
              onPressed: _handleSubmit,
              icon: Icon(Icons.edit_outlined, color: colorScheme.primary),
              tooltip: 'Open task editor',
              visualDensity: VisualDensity.compact,
            ),
          ],
        ],
      ),
    );
  }
}
