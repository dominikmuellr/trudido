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

import 'note_history.dart';

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

  bool get isBranchPoint => children.length > 1;

  List<NoteHistoryEntry> get ancestors {
    final result = <NoteHistoryEntry>[];
    var current = parent;
    while (current != null) {
      result.add(current.entry);
      current = current.parent;
    }
    return result;
  }

  int get branchIndex {
    if (parent == null) return 0;
    return parent!.children.indexWhere((c) => c.entry.id == entry.id);
  }
}

/// Builds a tree structure from a flat list of history entries.
/// Supports both linear history and branching scenarios for note versioning.
class HistoryTree {
  final Map<String, HistoryTreeNode> _nodeMap = {};
  final List<HistoryTreeNode> _roots = [];

  HistoryTree(List<NoteHistoryEntry> entries) {
    if (entries.isEmpty) return;

    final sortedEntries = List<NoteHistoryEntry>.from(entries)
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    for (final entry in sortedEntries) {
      _nodeMap[entry.id] = HistoryTreeNode(entry: entry);
    }

    for (int i = 0; i < sortedEntries.length; i++) {
      final entry = sortedEntries[i];
      final node = _nodeMap[entry.id]!;

      if (entry.parentEntryId != null &&
          _nodeMap.containsKey(entry.parentEntryId)) {
        final parentNode = _nodeMap[entry.parentEntryId]!;
        node.parent = parentNode;
        parentNode.children.add(node);
      } else if (i == 0) {
        _roots.add(node);
      } else {
        final previousEntry = sortedEntries[i - 1];
        final parentNode = _nodeMap[previousEntry.id]!;
        node.parent = parentNode;
        parentNode.children.add(node);
      }
    }

    for (final node in _nodeMap.values) {
      node.children.sort(
        (a, b) => a.entry.timestamp.compareTo(b.entry.timestamp),
      );
    }
  }

  List<HistoryTreeNode> get roots => _roots;

  HistoryTreeNode? getNode(String entryId) => _nodeMap[entryId];

  List<HistoryTreeNode> get leaves {
    return _nodeMap.values.where((node) => node.children.isEmpty).toList();
  }

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

  List<HistoryTreeNode> get branchPoints {
    return _nodeMap.values.where((node) => node.isBranchPoint).toList();
  }

  NoteHistoryEntry? get latestEntry {
    if (_nodeMap.isEmpty) return null;
    final entries = _nodeMap.values.map((n) => n.entry).toList();
    entries.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return entries.first;
  }

  List<NoteHistoryEntry> get allEntries {
    final entries = _nodeMap.values.map((n) => n.entry).toList();
    entries.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return entries;
  }

  bool hasChildren(String entryId) {
    final node = _nodeMap[entryId];
    return node != null && node.children.isNotEmpty;
  }

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

  /// Stack of entry IDs for forward navigation.
  final List<String> forwardStack;

  /// The content of the live version before we started navigating.
  final String? liveContent;

  /// The ID of the entry to branch from (set when user explicitly creates a branch).
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

  bool get isBranchingMode => branchFromEntryId != null;
}
