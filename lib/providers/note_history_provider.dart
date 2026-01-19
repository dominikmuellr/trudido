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

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/note_history.dart';
import '../services/storage_service.dart';

/// Provider for note history entries for a specific note.
/// Returns all history entries sorted by timestamp (newest first).
final noteHistoryProvider =
    FutureProvider.family<List<NoteHistoryEntry>, String>((ref, noteId) async {
      return StorageService.getNoteHistoryForNote(noteId);
    });

/// Provider for all note history entries across all notes.
final allNoteHistoryProvider = FutureProvider<List<NoteHistoryEntry>>((
  ref,
) async {
  return StorageService.getAllNoteHistory();
});

/// Represents a node in the history tree with its children (branches).
class HistoryTreeNode {
  final NoteHistoryEntry entry;
  final List<HistoryTreeNode> children;
  HistoryTreeNode? parent;

  HistoryTreeNode({
    required this.entry,
    List<HistoryTreeNode>? children,
    this.parent,
  }) : children = children ?? [];

  /// Check if this node has multiple children (is a branch point).
  bool get isBranchPoint => children.length > 1;

  /// Get all ancestors up to the root.
  List<NoteHistoryEntry> get ancestors {
    final result = <NoteHistoryEntry>[];
    var current = parent;
    while (current != null) {
      result.add(current.entry);
      current = current.parent;
    }
    return result;
  }

  /// Get the branch index of this node among its parent's children.
  int get branchIndex {
    if (parent == null) return 0;
    return parent!.children.indexWhere((c) => c.entry.id == entry.id);
  }
}

/// Builds a tree structure from a flat list of history entries.
class HistoryTree {
  final Map<String, HistoryTreeNode> _nodeMap = {};
  final List<HistoryTreeNode> _roots = [];

  HistoryTree(List<NoteHistoryEntry> entries) {
    if (entries.isEmpty) return;

    // Sort entries by timestamp (oldest first) for proper parent inference
    final sortedEntries = List<NoteHistoryEntry>.from(entries)
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    // First pass: create all nodes
    for (final entry in sortedEntries) {
      _nodeMap[entry.id] = HistoryTreeNode(entry: entry);
    }

    // Second pass: link parents and children
    // For entries without parentEntryId, infer parent from chronological order
    for (int i = 0; i < sortedEntries.length; i++) {
      final entry = sortedEntries[i];
      final node = _nodeMap[entry.id]!;

      if (entry.parentEntryId != null &&
          _nodeMap.containsKey(entry.parentEntryId)) {
        // Explicit parent link exists - use it (this is a branch)
        final parentNode = _nodeMap[entry.parentEntryId]!;
        node.parent = parentNode;
        parentNode.children.add(node);
      } else if (i == 0) {
        // First entry is always a root
        _roots.add(node);
      } else {
        // No explicit parent - infer from chronological order (linear history)
        // The previous entry in time is the parent
        final previousEntry = sortedEntries[i - 1];
        final parentNode = _nodeMap[previousEntry.id]!;
        node.parent = parentNode;
        parentNode.children.add(node);
      }
    }

    // Sort children by timestamp for consistent ordering
    for (final node in _nodeMap.values) {
      node.children.sort(
        (a, b) => a.entry.timestamp.compareTo(b.entry.timestamp),
      );
    }
  }

  /// Get all root nodes (entries without parents).
  List<HistoryTreeNode> get roots => _roots;

  /// Get a node by entry ID.
  HistoryTreeNode? getNode(String entryId) => _nodeMap[entryId];

  /// Get all leaf nodes (entries without children).
  List<HistoryTreeNode> get leaves {
    return _nodeMap.values.where((node) => node.children.isEmpty).toList();
  }

  /// Get the path from root to a specific node.
  List<NoteHistoryEntry> getPathToNode(String entryId) {
    final node = _nodeMap[entryId];
    if (node == null) return [];

    final path = <NoteHistoryEntry>[node.entry];
    var current = node.parent;
    while (current != null) {
      path.insert(0, current.entry);
      current = current.parent;
    }
    return path;
  }

  /// Get all branch points in the tree.
  List<HistoryTreeNode> get branchPoints {
    return _nodeMap.values.where((node) => node.isBranchPoint).toList();
  }

  /// Find the latest entry overall (most recent timestamp).
  NoteHistoryEntry? get latestEntry {
    if (_nodeMap.isEmpty) return null;
    final entries = _nodeMap.values.map((n) => n.entry).toList();
    entries.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return entries.first;
  }

  /// Get all entries as a flat list sorted by timestamp (newest first).
  List<NoteHistoryEntry> get allEntries {
    final entries = _nodeMap.values.map((n) => n.entry).toList();
    entries.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return entries;
  }

  /// Check if an entry has children (can navigate forward from it).
  bool hasChildren(String entryId) {
    final node = _nodeMap[entryId];
    return node != null && node.children.isNotEmpty;
  }

  /// Get children of an entry.
  List<NoteHistoryEntry> getChildren(String entryId) {
    final node = _nodeMap[entryId];
    if (node == null) return [];
    return node.children.map((c) => c.entry).toList();
  }
}

/// State for tracking the current position in the history tree.
class NoteHistoryState {
  /// The ID of the entry we're currently viewing (null = at current/live version).
  final String? currentEntryId;

  /// Stack of entry IDs for forward navigation (entries we came from when going back).
  final List<String> forwardStack;

  /// The content of the live version before we started navigating.
  final String? liveContent;

  /// The ID of the entry to branch from (set when user explicitly creates a branch).
  /// When this is set, the next edit will create a branch from this entry.
  final String? branchFromEntryId;

  const NoteHistoryState({
    this.currentEntryId,
    this.forwardStack = const [],
    this.liveContent,
    this.branchFromEntryId,
  });

  NoteHistoryState copyWith({
    String? currentEntryId,
    List<String>? forwardStack,
    String? liveContent,
    String? branchFromEntryId,
    bool clearCurrentEntryId = false,
    bool clearLiveContent = false,
    bool clearBranchFromEntryId = false,
  }) {
    return NoteHistoryState(
      currentEntryId: clearCurrentEntryId
          ? null
          : (currentEntryId ?? this.currentEntryId),
      forwardStack: forwardStack ?? this.forwardStack,
      liveContent: clearLiveContent ? null : (liveContent ?? this.liveContent),
      branchFromEntryId: clearBranchFromEntryId
          ? null
          : (branchFromEntryId ?? this.branchFromEntryId),
    );
  }

  bool get isAtLiveVersion => currentEntryId == null;

  /// True if the next edit should create a new branch.
  bool get isBranchingMode => branchFromEntryId != null;
}

/// StateNotifier for managing navigation through the history tree.
class NoteHistoryNavigator
    extends StateNotifier<Map<String, NoteHistoryState>> {
  NoteHistoryNavigator() : super({});

  NoteHistoryState _getState(String noteId) {
    return state[noteId] ?? const NoteHistoryState();
  }

  /// Navigate back to a specific entry in history.
  void navigateToEntry(
    String noteId,
    String entryId, {
    String? currentLiveContent,
  }) {
    final currentState = _getState(noteId);

    // Save live content if we're leaving live version
    String? liveContent = currentState.liveContent;
    if (currentState.isAtLiveVersion && currentLiveContent != null) {
      liveContent = currentLiveContent;
    }

    // Build forward stack
    final newForwardStack = List<String>.from(currentState.forwardStack);
    if (currentState.currentEntryId != null) {
      newForwardStack.add(currentState.currentEntryId!);
    }

    state = {
      ...state,
      noteId: NoteHistoryState(
        currentEntryId: entryId,
        forwardStack: newForwardStack,
        liveContent: liveContent,
      ),
    };
  }

  /// Navigate back one step (to parent entry).
  /// Returns the entry ID to navigate to, or null if can't go back.
  String? navigateBack(
    String noteId,
    HistoryTree tree, {
    String? currentLiveContent,
  }) {
    final currentState = _getState(noteId);

    if (currentState.isAtLiveVersion) {
      // At live version, go to the most recent entry
      final latestEntry = tree.latestEntry;
      if (latestEntry == null) return null;

      state = {
        ...state,
        noteId: NoteHistoryState(
          currentEntryId: latestEntry.id,
          forwardStack: [],
          liveContent: currentLiveContent,
        ),
      };
      return latestEntry.id;
    } else {
      // At an entry, go to its parent
      final currentNode = tree.getNode(currentState.currentEntryId!);
      if (currentNode?.parent != null) {
        final parentId = currentNode!.parent!.entry.id;

        state = {
          ...state,
          noteId: currentState.copyWith(
            currentEntryId: parentId,
            forwardStack: [
              ...currentState.forwardStack,
              currentState.currentEntryId!,
            ],
          ),
        };
        return parentId;
      }
    }
    return null;
  }

  /// Navigate forward one step.
  /// Returns the entry ID to navigate to, or null if returning to live version.
  String? navigateForward(String noteId) {
    final currentState = _getState(noteId);

    if (currentState.forwardStack.isEmpty) {
      // At the end of forward stack, return to live version
      if (!currentState.isAtLiveVersion) {
        state = {...state, noteId: const NoteHistoryState()};
      }
      return null; // Signal to restore live content
    }

    // Pop from forward stack
    final newForwardStack = List<String>.from(currentState.forwardStack);
    final nextEntryId = newForwardStack.removeLast();

    state = {
      ...state,
      noteId: currentState.copyWith(
        currentEntryId: nextEntryId,
        forwardStack: newForwardStack,
      ),
    };
    return nextEntryId;
  }

  /// Reset navigation state (return to live version).
  void resetToLive(String noteId) {
    state = {...state, noteId: const NoteHistoryState()};
  }

  /// Start a new branch from a specific entry.
  /// The next edit will create a branch from this entry.
  void startBranchFrom(String noteId, String entryId) {
    final currentState = _getState(noteId);
    state = {
      ...state,
      noteId: currentState.copyWith(branchFromEntryId: entryId),
    };
  }

  /// Clear branching mode (called after the branch is created).
  void clearBranchingMode(String noteId) {
    final currentState = _getState(noteId);
    state = {
      ...state,
      noteId: currentState.copyWith(clearBranchFromEntryId: true),
    };
  }

  /// Check if in branching mode.
  bool isInBranchingMode(String noteId) {
    return _getState(noteId).isBranchingMode;
  }

  /// Get the entry ID to branch from (if in branching mode).
  String? getBranchFromEntryId(String noteId) {
    return _getState(noteId).branchFromEntryId;
  }

  /// Get the parent entry ID for creating a new branch.
  /// When in branching mode, returns the branchFromEntryId.
  /// When at live version, returns the latest entry ID (no branch).
  /// When at a past entry (not branching), returns the latest entry ID (no branch).
  String? getParentForNewEntry(String noteId, List<NoteHistoryEntry> entries) {
    final currentState = _getState(noteId);

    if (entries.isEmpty) return null;

    // If explicitly branching, use that entry as parent
    if (currentState.isBranchingMode) {
      return currentState.branchFromEntryId;
    }

    // Otherwise, always continue from the latest entry (no automatic branching)
    final sortedEntries = List<NoteHistoryEntry>.from(entries)
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return sortedEntries.first.id;
  }

  /// Check if we can navigate back.
  bool canNavigateBack(String noteId, HistoryTree? tree) {
    if (tree == null) return false;

    final currentState = _getState(noteId);
    if (currentState.isAtLiveVersion) {
      return tree.latestEntry != null;
    }

    // Check if current entry has a parent
    final currentNode = tree.getNode(currentState.currentEntryId!);
    return currentNode?.parent != null;
  }

  /// Check if we can navigate forward.
  bool canNavigateForward(String noteId) {
    final currentState = _getState(noteId);
    return currentState.forwardStack.isNotEmpty ||
        !currentState.isAtLiveVersion;
  }

  /// Get the saved live content (for restoring when going forward to live).
  String? getLiveContent(String noteId) {
    return _getState(noteId).liveContent;
  }

  /// Check if currently at live version.
  bool isAtLiveVersion(String noteId) {
    return _getState(noteId).isAtLiveVersion;
  }
}

/// Provider for the history navigator.
final noteHistoryNavigatorProvider =
    StateNotifierProvider<NoteHistoryNavigator, Map<String, NoteHistoryState>>(
      (ref) => NoteHistoryNavigator(),
    );

/// Provider for building a history tree from entries.
final historyTreeProvider = Provider.family<HistoryTree?, String>((
  ref,
  noteId,
) {
  final historyAsync = ref.watch(noteHistoryProvider(noteId));
  return historyAsync.when(
    data: (entries) => entries.isEmpty ? null : HistoryTree(entries),
    loading: () => null,
    error: (_, __) => null,
  );
});

/// Helper provider to check if back navigation is available.
final canUndoProvider = Provider.family<bool, String>((ref, noteId) {
  final tree = ref.watch(historyTreeProvider(noteId));
  final navigator = ref.watch(noteHistoryNavigatorProvider.notifier);
  return navigator.canNavigateBack(noteId, tree);
});

/// Helper provider to check if forward navigation is available.
final canRedoProvider = Provider.family<bool, String>((ref, noteId) {
  ref.watch(noteHistoryProvider(noteId)); // Depend on history for reactivity
  final navigator = ref.watch(noteHistoryNavigatorProvider.notifier);
  return navigator.canNavigateForward(noteId);
});

/// Provider to get the current history position state.
final currentHistoryPositionProvider =
    Provider.family<NoteHistoryState?, String>((ref, noteId) {
      final states = ref.watch(noteHistoryNavigatorProvider);
      return states[noteId];
    });

/// Legacy stack-based notifier - now uses navigator internally.
class NoteHistoryStackNotifier
    extends StateNotifier<Map<String, NoteHistoryStacks>> {
  final Ref _ref;

  NoteHistoryStackNotifier(this._ref) : super({});

  /// Push a new entry - saves to storage with parent link for branching.
  Future<void> pushUndo(String noteId, NoteHistoryEntry entry) async {
    // Get parent entry ID from navigator (enables branching)
    final history = await StorageService.getNoteHistoryForNote(noteId);
    final navigator = _ref.read(noteHistoryNavigatorProvider.notifier);
    final parentId = navigator.getParentForNewEntry(noteId, history);

    // Check if we're creating a branch
    final isBranching = navigator.isInBranchingMode(noteId);

    // Create entry with parent link
    final entryWithParent = NoteHistoryEntry(
      id: entry.id,
      noteId: entry.noteId,
      contentBefore: entry.contentBefore,
      contentAfter: entry.contentAfter,
      timestamp: entry.timestamp,
      parentEntryId: parentId,
      branchLabel: isBranching ? 'Branch' : entry.branchLabel,
    );

    // Save to storage
    await StorageService.saveNoteHistoryEntry(entryWithParent);

    // Clear branching mode after creating the branch
    if (isBranching) {
      navigator.clearBranchingMode(noteId);
    }

    // Reset navigator to live version after making a change
    navigator.resetToLive(noteId);

    // Invalidate history provider to refresh
    _ref.invalidate(noteHistoryProvider(noteId));
  }

  /// Navigate back (undo) - returns the entry to restore from.
  NoteHistoryEntry? undo(String noteId) {
    final tree = _ref.read(historyTreeProvider(noteId));
    if (tree == null) return null;

    final navigator = _ref.read(noteHistoryNavigatorProvider.notifier);
    final entryId = navigator.navigateBack(noteId, tree);
    if (entryId == null) return null;

    return tree.getNode(entryId)?.entry;
  }

  /// Navigate forward (redo) - returns the entry to restore to.
  NoteHistoryEntry? redo(String noteId) {
    final navigator = _ref.read(noteHistoryNavigatorProvider.notifier);
    final entryId = navigator.navigateForward(noteId);

    if (entryId == null) {
      // Returning to live version - no entry to return
      return null;
    }

    final tree = _ref.read(historyTreeProvider(noteId));
    return tree?.getNode(entryId)?.entry;
  }

  /// Initialize from history - ensures tree is built.
  void initializeFromHistory(String noteId, List<NoteHistoryEntry> history) {
    // History is managed by noteHistoryProvider
    // Just invalidate to ensure fresh data
    _ref.invalidate(noteHistoryProvider(noteId));
  }

  /// Check if at live version (not viewing history).
  bool isAtLiveVersion(String noteId) {
    final navigator = _ref.read(noteHistoryNavigatorProvider.notifier);
    return navigator.isAtLiveVersion(noteId);
  }

  /// Get the saved live content for restoring.
  String? getLiveContent(String noteId) {
    final navigator = _ref.read(noteHistoryNavigatorProvider.notifier);
    return navigator.getLiveContent(noteId);
  }
}

/// Legacy class for API compatibility.
class NoteHistoryStacks {
  final List<NoteHistoryEntry> undoStack;
  final List<NoteHistoryEntry> redoStack;

  NoteHistoryStacks({this.undoStack = const [], this.redoStack = const []});

  NoteHistoryStacks copyWith({
    List<NoteHistoryEntry>? undoStack,
    List<NoteHistoryEntry>? redoStack,
  }) {
    return NoteHistoryStacks(
      undoStack: undoStack ?? this.undoStack,
      redoStack: redoStack ?? this.redoStack,
    );
  }
}

/// Provider for the legacy stack notifier.
final noteHistoryStackProvider =
    StateNotifierProvider<
      NoteHistoryStackNotifier,
      Map<String, NoteHistoryStacks>
    >((ref) => NoteHistoryStackNotifier(ref));
