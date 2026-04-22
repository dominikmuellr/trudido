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
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/app_providers.dart';

/// Scrollable toolbar wrapper with fade effect on edges
class ScrollableToolbar extends StatelessWidget {
  final Widget child;

  const ScrollableToolbar({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      shaderCallback: (Rect bounds) {
        return LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            Colors.transparent,
            Colors.white,
            Colors.white,
            Colors.transparent,
          ],
          stops: const [0.0, 0.02, 0.98, 1.0],
        ).createShader(bounds);
      },
      blendMode: BlendMode.dstIn,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: child,
      ),
    );
  }
}

/// Vertical divider for toolbar sections
class ToolbarDivider extends StatelessWidget {
  const ToolbarDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 24,
      width: 1,
      margin: const EdgeInsets.symmetric(horizontal: 6),
      color: Theme.of(
        context,
      ).colorScheme.outlineVariant.withValues(alpha: 0.5),
    );
  }
}

/// Font size dropdown for Quill editor
class FontSizeDropdown extends ConsumerWidget {
  final quill.QuillController controller;
  final VoidCallback? onChanged;

  const FontSizeDropdown({super.key, required this.controller, this.onChanged});

  static const List<int> fontSizes = [
    12,
    13,
    14,
    15,
    16,
    17,
    18,
    19,
    20,
    21,
    22,
    23,
    24,
  ];

  int _getCurrentSize(int prefSize) {
    try {
      final style = controller.getSelectionStyle();
      final sizeAttr = style.attributes[quill.Attribute.size.key]?.value;

      if (sizeAttr != null) {
        if (sizeAttr is String) {
          final numStr = sizeAttr.replaceAll(RegExp(r'[^0-9]'), '');
          final parsed = int.tryParse(numStr);
          if (parsed != null && fontSizes.contains(parsed)) {
            return parsed;
          }
        } else if (sizeAttr is num) {
          final parsed = sizeAttr.toInt();
          if (fontSizes.contains(parsed)) {
            return parsed;
          }
        }
      }
    } catch (e) {
      // Ignore errors
    }
    return prefSize; // Fall back to global preference
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefSize = ref.watch(preferencesStateProvider).editorFontSize.round();
    final currentSize = _getCurrentSize(prefSize);

    return PopupMenuButton<int>(
      tooltip: 'Font size',
      initialValue: currentSize,
      offset: const Offset(0, 40),
      child: Container(
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$currentSize',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontSize: 14),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.arrow_drop_down,
              size: 20,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
      itemBuilder: (context) => fontSizes.map((size) {
        return PopupMenuItem<int>(
          value: size,
          child: Text(
            '$size',
            style: TextStyle(
              fontSize: 14,
              fontWeight: size == currentSize
                  ? FontWeight.bold
                  : FontWeight.normal,
            ),
          ),
        );
      }).toList(),
      onSelected: (newSize) {
        controller.formatSelection(
          quill.Attribute.fromKeyValue('size', '$newSize'),
        );
        onChanged?.call();
      },
    );
  }
}

/// Header style dropdown for Quill editor
class HeaderStyleDropdown extends StatelessWidget {
  final quill.QuillController controller;
  final VoidCallback? onChanged;

  const HeaderStyleDropdown({
    super.key,
    required this.controller,
    this.onChanged,
  });

  static const List<({String label, int value})> headers = [
    (label: 'Normal', value: 0),
    (label: 'Header 1', value: 1),
    (label: 'Header 2', value: 2),
    (label: 'Header 3', value: 3),
  ];

  int _getCurrentHeader() {
    try {
      final style = controller.getSelectionStyle();
      final headerAttr = style.attributes[quill.Attribute.header.key]?.value;
      if (headerAttr != null && headerAttr is int) {
        return headerAttr;
      }
    } catch (e) {
      // Ignore errors
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final currentHeader = _getCurrentHeader();
    final currentLabel = headers
        .firstWhere((h) => h.value == currentHeader, orElse: () => headers[0])
        .label;

    return PopupMenuButton<int>(
      tooltip: 'Header style',
      offset: const Offset(0, 40),
      child: Container(
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              currentLabel,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontSize: 14),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.arrow_drop_down,
              size: 20,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
      itemBuilder: (context) => headers.map((header) {
        return PopupMenuItem<int>(
          value: header.value,
          child: Text(
            header.label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: header.value == currentHeader
                  ? FontWeight.bold
                  : FontWeight.normal,
            ),
          ),
        );
      }).toList(),
      onSelected: (headerLevel) {
        if (headerLevel == 0) {
          controller.formatSelection(quill.Attribute.header);
        } else {
          controller.formatSelection(
            quill.Attribute.fromKeyValue('header', headerLevel),
          );
        }
        onChanged?.call();
      },
    );
  }
}

/// Font family dropdown for Quill editor
class FontFamilyDropdown extends ConsumerWidget {
  final quill.QuillController controller;
  final VoidCallback? onChanged;

  const FontFamilyDropdown({
    super.key,
    required this.controller,
    this.onChanged,
  });

  static const List<Map<String, String>> fontOptions = [
    {'label': 'Default', 'value': ''},
    {'label': 'Inter', 'value': 'Inter'},
    {'label': 'Open Sans', 'value': 'OpenSans'},
    {'label': 'Lexend', 'value': 'Lexend'},
    {'label': 'JetBrains Mono', 'value': 'JetBrainsMono'},
    {'label': 'Monospace', 'value': 'monospace'},
    {'label': 'Roboto', 'value': 'Roboto'},
  ];

  String _getCurrentFamily(String prefFamily) {
    try {
      final style = controller.getSelectionStyle();
      final fontAttr = style.attributes[quill.Attribute.font.key]?.value;
      if (fontAttr != null && fontAttr is String && fontAttr.isNotEmpty) {
        return fontAttr;
      }
    } catch (e) {
      // Ignore errors
    }
    return prefFamily; // Fall back to global preference
  }

  String _getLabelForValue(String value) {
    for (final opt in fontOptions) {
      if (opt['value'] == value) return opt['label']!;
    }
    return value.isEmpty ? 'Default' : value;
  }

  // Convert the pref key (e.g. 'opensans') to the font value used in the dropdown
  String _prefKeyToFontValue(String prefKey) {
    switch (prefKey) {
      case 'opensans':
        return 'OpenSans';
      case 'inter':
        return 'Inter';
      case 'jetbrains':
        return 'JetBrainsMono';
      case 'lexend':
        return 'Lexend';
      case 'monospace':
        return 'monospace';
      case 'roboto':
        return 'Roboto';
      default: // 'default'
        return '';
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefFontKey = ref.watch(preferencesStateProvider).editorFontFamily;
    final prefFontValue = _prefKeyToFontValue(prefFontKey);
    final currentFamily = _getCurrentFamily(prefFontValue);
    final displayLabel = _getLabelForValue(currentFamily);

    return PopupMenuButton<String>(
      tooltip: 'Font family',
      offset: const Offset(0, 40),
      child: Container(
        height: 36,
        constraints: const BoxConstraints(maxWidth: 140),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                displayLabel,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontSize: 14,
                  fontFamily: currentFamily.isEmpty ? null : currentFamily,
                ),
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.arrow_drop_down,
              size: 20,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
      itemBuilder: (context) => fontOptions.map((opt) {
        final value = opt['value']!;
        final label = opt['label']!;
        final isCurrent = value == currentFamily;
        return PopupMenuItem<String>(
          value: value,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontFamily: value.isEmpty ? null : value,
              fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        );
      }).toList(),
      onSelected: (newFamily) {
        if (newFamily.isEmpty) {
          // Remove font attribute (revert to default)
          controller.formatSelection(
            const quill.Attribute('font', quill.AttributeScope.inline, null),
          );
        } else {
          controller.formatSelection(
            quill.Attribute.fromKeyValue('font', newFamily),
          );
        }
        onChanged?.call();
      },
    );
  }
}

/// Line height dropdown for note formatting
class LineHeightDropdown extends StatelessWidget {
  final double currentHeight;
  final ValueChanged<double>? onChanged;

  const LineHeightDropdown({
    super.key,
    required this.currentHeight,
    this.onChanged,
  });

  static const List<double> lineHeights = [1.0, 1.2, 1.4, 1.6, 1.8, 2.0];

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<double>(
      tooltip: 'Line height',
      offset: const Offset(0, 40),
      itemBuilder: (context) => lineHeights.map((height) {
        return PopupMenuItem<double>(
          value: height,
          child: Text(
            '${height.toStringAsFixed(1)}x',
            style: TextStyle(
              fontSize: 14,
              fontWeight: (height - currentHeight).abs() < 0.01
                  ? FontWeight.bold
                  : FontWeight.normal,
            ),
          ),
        );
      }).toList(),
      onSelected: onChanged,
      child: Container(
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${currentHeight.toStringAsFixed(1)}x',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontSize: 14),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.arrow_drop_down,
              size: 20,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}

/// Paragraph spacing dropdown for note formatting
class ParagraphSpacingDropdown extends StatelessWidget {
  final double currentSpacing;
  final ValueChanged<double>? onChanged;

  const ParagraphSpacingDropdown({
    super.key,
    required this.currentSpacing,
    this.onChanged,
  });

  static const List<double> spacings = [0.0, 4.0, 8.0, 12.0, 16.0, 20.0];

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<double>(
      tooltip: 'Paragraph spacing',
      offset: const Offset(0, 40),
      itemBuilder: (context) => spacings.map((spacing) {
        return PopupMenuItem<double>(
          value: spacing,
          child: Text(
            '${spacing.toStringAsFixed(0)}pt',
            style: TextStyle(
              fontSize: 14,
              fontWeight: (spacing - currentSpacing).abs() < 0.01
                  ? FontWeight.bold
                  : FontWeight.normal,
            ),
          ),
        );
      }).toList(),
      onSelected: onChanged,
      child: Container(
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${currentSpacing.toStringAsFixed(0)}pt',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontSize: 14),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.arrow_drop_down,
              size: 20,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}
