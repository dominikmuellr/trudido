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

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:flutter_quill/quill_delta.dart';

/// Custom embed builder that renders an interactive table inside the Quill
/// note editor. Cell data is stored as a JSON CustomBlockEmbed with key
/// 'table' so it survives save/load cycles as part of the Quill Delta.
///
/// Data format: {"rows": int, "cols": int, "cells": List<List<String>>}
///
/// The table is always rendered read-only inside the editor. Tapping it
/// opens a bottom sheet with a full grid of editable cells, row/column
/// management, and Tab navigation — completely outside Quill's focus tree.
class TableEmbedBuilder extends quill.EmbedBuilder {
  @override
  String get key => 'table';

  @override
  Widget build(BuildContext context, quill.EmbedContext embedContext) {
    final dataString = embedContext.node.value.data as String;

    Map<String, dynamic> data;
    try {
      data = jsonDecode(dataString) as Map<String, dynamic>;
    } catch (_) {
      return const SizedBox.shrink();
    }

    final rows = data['rows'] as int;
    final cols = data['cols'] as int;
    final rawCells = data['cells'] as List;
    final cells = List.generate(
      rows,
      (r) => List.generate(cols, (c) => rawCells[r][c] as String),
    );

    return _TableView(
      rows: rows,
      cols: cols,
      cells: cells,
      readOnly: embedContext.readOnly,
      onTapped: () {
        // Move cursor past the embed so Quill doesn't render a
        // block-height cursor beside the table.
        final originalCustomData = jsonEncode({'table': dataString});
        final ops = embedContext.controller.document.toDelta().operations;
        int offset = 0;
        for (final op in ops) {
          if (op.isInsert && op.data is Map) {
            final map = op.data as Map;
            if (map.containsKey('custom') &&
                map['custom'] == originalCustomData) {
              embedContext.controller.updateSelection(
                TextSelection.collapsed(offset: offset + 1),
                quill.ChangeSource.local,
              );
              break;
            }
          }
          offset += op.length!;
        }
      },
      onSave: (newRows, newCols, newCells) {
        final originalCustomData = jsonEncode({'table': dataString});
        final ops = embedContext.controller.document.toDelta().operations;
        int embedOffset = -1;
        int offset = 0;
        for (final op in ops) {
          if (op.isInsert && op.data is Map) {
            final map = op.data as Map;
            if (map.containsKey('custom') &&
                map['custom'] == originalCustomData) {
              embedOffset = offset;
              break;
            }
          }
          offset += op.length!;
        }
        if (embedOffset < 0) return;

        final newCellsJson = jsonEncode({
          'rows': newRows,
          'cols': newCols,
          'cells': newCells,
        });
        final newCustomData = jsonEncode({'table': newCellsJson});
        final replaceDelta = Delta()..insert({'custom': newCustomData});
        embedContext.controller.replaceText(
          embedOffset,
          1,
          replaceDelta,
          TextSelection.collapsed(offset: embedOffset + 1),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Read-only table rendered inside the Quill editor
// ---------------------------------------------------------------------------

class _TableView extends StatelessWidget {
  final int rows;
  final int cols;
  final List<List<String>> cells;
  final bool readOnly;
  final VoidCallback? onTapped;
  final void Function(int rows, int cols, List<List<String>> cells) onSave;

  const _TableView({
    required this.rows,
    required this.cols,
    required this.cells,
    required this.readOnly,
    this.onTapped,
    required this.onSave,
  });

  void _openEditor(BuildContext context) {
    showModalBottomSheet<_TableEditorResult>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _TableEditorSheet(
        initialRows: rows,
        initialCols: cols,
        initialCells: cells,
      ),
    ).then((result) {
      if (result == null) return;
      onSave(result.rows, result.cols, result.cells);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final headerBg = theme.colorScheme.primaryContainer.withValues(alpha: 0.35);
    final borderColor = theme.colorScheme.outlineVariant;

    return GestureDetector(
      onTap: readOnly
          ? null
          : () {
              onTapped?.call();
              _openEditor(context);
            },
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          border: Border.all(color: borderColor),
          borderRadius: BorderRadius.circular(6),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: Stack(
            children: [
              LayoutBuilder(
                builder: (context, constraints) {
                  const minCellWidth = 88.0;
                  final totalMinWidth = cols * minCellWidth;
                  final needsScroll = totalMinWidth > constraints.maxWidth;
                  final cellWidth = needsScroll
                      ? minCellWidth
                      : constraints.maxWidth / cols;

                  final tableContent = Column(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(rows, (r) {
                      final isHeader = r == 0;
                      return IntrinsicHeight(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: List.generate(cols, (c) {
                            return Container(
                              width: cellWidth,
                              constraints: const BoxConstraints(minHeight: 40),
                              decoration: BoxDecoration(
                                color: isHeader
                                    ? headerBg
                                    : theme.colorScheme.surface,
                                border: Border(
                                  right: c < cols - 1
                                      ? BorderSide(color: borderColor)
                                      : BorderSide.none,
                                  bottom: r < rows - 1
                                      ? BorderSide(color: borderColor)
                                      : BorderSide.none,
                                ),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              child: Text(
                                cells[r][c],
                                style: isHeader
                                    ? theme.textTheme.bodyMedium?.copyWith(
                                        fontWeight: FontWeight.w600,
                                      )
                                    : theme.textTheme.bodyMedium,
                              ),
                            );
                          }),
                        ),
                      );
                    }),
                  );

                  if (needsScroll) {
                    return SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: tableContent,
                    );
                  }
                  return tableContent;
                },
              ),
              // Edit affordance icon
              if (!readOnly)
                Positioned(
                  top: 4,
                  right: 4,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest
                          .withValues(alpha: 0.8),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Icon(
                      Icons.edit_outlined,
                      size: 14,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Result returned by the editor sheet
// ---------------------------------------------------------------------------

class _TableEditorResult {
  final int rows;
  final int cols;
  final List<List<String>> cells;
  const _TableEditorResult(this.rows, this.cols, this.cells);
}

// ---------------------------------------------------------------------------
// Bottom sheet with a full editable grid
// ---------------------------------------------------------------------------

class _TableEditorSheet extends StatefulWidget {
  final int initialRows;
  final int initialCols;
  final List<List<String>> initialCells;

  const _TableEditorSheet({
    required this.initialRows,
    required this.initialCols,
    required this.initialCells,
  });

  @override
  State<_TableEditorSheet> createState() => _TableEditorSheetState();
}

class _TableEditorSheetState extends State<_TableEditorSheet> {
  late int _rows;
  late int _cols;
  late List<List<TextEditingController>> _controllers;
  late List<List<FocusNode>> _focusNodes;

  @override
  void initState() {
    super.initState();
    _rows = widget.initialRows;
    _cols = widget.initialCols;
    _buildGrid();
  }

  void _buildGrid() {
    _controllers = List.generate(
      _rows,
      (r) => List.generate(_cols, (c) {
        final text =
            r < widget.initialCells.length && c < widget.initialCells[r].length
            ? widget.initialCells[r][c]
            : '';
        return TextEditingController(text: text);
      }),
    );
    _focusNodes = List.generate(
      _rows,
      (r) => List.generate(_cols, (c) => FocusNode()),
    );
  }

  void _disposeGrid() {
    for (final row in _controllers) {
      for (final ctrl in row) {
        ctrl.dispose();
      }
    }
    for (final row in _focusNodes) {
      for (final fn in row) {
        fn.dispose();
      }
    }
  }

  List<List<String>> _currentCells() {
    return List.generate(
      _rows,
      (r) => List.generate(_cols, (c) => _controllers[r][c].text),
    );
  }

  void _addRow() {
    final saved = _currentCells();
    _disposeGrid();
    _rows++;
    widget.initialCells.clear();
    widget.initialCells.addAll(saved);
    widget.initialCells.add(List.filled(_cols, ''));
    _buildGrid();
    setState(() {});
    // Focus the first cell of the new row after rebuild
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNodes[_rows - 1][0].requestFocus();
    });
  }

  void _removeRow() {
    if (_rows <= 1) return;
    final saved = _currentCells();
    _disposeGrid();
    _rows--;
    widget.initialCells.clear();
    widget.initialCells.addAll(saved.sublist(0, _rows));
    _buildGrid();
    setState(() {});
  }

  void _addColumn() {
    final saved = _currentCells();
    _disposeGrid();
    _cols++;
    widget.initialCells.clear();
    for (final row in saved) {
      widget.initialCells.add([...row, '']);
    }
    _buildGrid();
    setState(() {});
  }

  void _removeColumn() {
    if (_cols <= 1) return;
    final saved = _currentCells();
    _disposeGrid();
    _cols--;
    widget.initialCells.clear();
    for (final row in saved) {
      widget.initialCells.add(row.sublist(0, _cols));
    }
    _buildGrid();
    setState(() {});
  }

  void _moveToNext(int r, int c) {
    int nr = r, nc = c + 1;
    if (nc >= _cols) {
      nc = 0;
      nr++;
    }
    if (nr < _rows) {
      _focusNodes[nr][nc].requestFocus();
    }
  }

  void _done() {
    Navigator.of(
      context,
    ).pop(_TableEditorResult(_rows, _cols, _currentCells()));
  }

  @override
  void dispose() {
    _disposeGrid();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final borderColor = theme.colorScheme.outlineVariant;
    final headerBg = theme.colorScheme.primaryContainer.withValues(alpha: 0.35);

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.3,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            // ── Header bar ──
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerLow,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  const Spacer(),
                  Text('Edit Table', style: theme.textTheme.titleSmall),
                  const Spacer(),
                  FilledButton(onPressed: _done, child: const Text('Done')),
                ],
              ),
            ),
            // ── Row / column controls ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: Row(
                children: [
                  _ActionChip(
                    icon: Icons.add,
                    label: 'Row',
                    onTap: _rows < 50 ? _addRow : null,
                  ),
                  const SizedBox(width: 6),
                  _ActionChip(
                    icon: Icons.remove,
                    label: 'Row',
                    onTap: _rows > 1 ? _removeRow : null,
                  ),
                  const SizedBox(width: 12),
                  _ActionChip(
                    icon: Icons.add,
                    label: 'Col',
                    onTap: _cols < 20 ? _addColumn : null,
                  ),
                  const SizedBox(width: 6),
                  _ActionChip(
                    icon: Icons.remove,
                    label: 'Col',
                    onTap: _cols > 1 ? _removeColumn : null,
                  ),
                  const Spacer(),
                  Text(
                    '$_rows × $_cols',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            // ── Editable grid ──
            Expanded(
              child: SingleChildScrollView(
                controller: scrollController,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: List.generate(_rows, (r) {
                      final isHeader = r == 0;
                      return IntrinsicHeight(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: List.generate(_cols, (c) {
                            final isLastCell = r == _rows - 1 && c == _cols - 1;
                            final textStyle = isHeader
                                ? theme.textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  )
                                : theme.textTheme.bodyMedium;

                            return Container(
                              width: 120,
                              constraints: const BoxConstraints(minHeight: 44),
                              decoration: BoxDecoration(
                                color: isHeader
                                    ? headerBg
                                    : theme.colorScheme.surface,
                                border: Border(
                                  right: BorderSide(color: borderColor),
                                  bottom: BorderSide(color: borderColor),
                                ),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 6,
                              ),
                              child: TextField(
                                controller: _controllers[r][c],
                                focusNode: _focusNodes[r][c],
                                style: textStyle,
                                minLines: 1,
                                maxLines: 4,
                                textInputAction: isLastCell
                                    ? TextInputAction.done
                                    : TextInputAction.next,
                                onEditingComplete: isLastCell
                                    ? _done
                                    : () => _moveToNext(r, c),
                                decoration: const InputDecoration(
                                  isDense: true,
                                  filled: false,
                                  contentPadding: EdgeInsets.zero,
                                  border: InputBorder.none,
                                ),
                              ),
                            );
                          }),
                        ),
                      );
                    }),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Small chip button used in the sheet header
// ---------------------------------------------------------------------------

class _ActionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  const _ActionChip({required this.icon, required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: onTap != null ? cs.secondaryContainer : cs.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 16,
                color: onTap != null
                    ? cs.onSecondaryContainer
                    : cs.onSurfaceVariant.withValues(alpha: 0.5),
              ),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  color: onTap != null
                      ? cs.onSecondaryContainer
                      : cs.onSurfaceVariant.withValues(alpha: 0.5),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
