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
      color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.5),
    );
  }
}

/// Font size dropdown for Quill editor
class FontSizeDropdown extends StatelessWidget {
  final quill.QuillController controller;
  final VoidCallback? onChanged;

  const FontSizeDropdown({super.key, required this.controller, this.onChanged});

  static const List<int> fontSizes = [
    8,
    9,
    10,
    11,
    12,
    14,
    16,
    18,
    20,
    24,
    28,
    32,
    36,
    48,
    72,
  ];

  int _getCurrentSize() {
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
    return 16; // Default size
  }

  @override
  Widget build(BuildContext context) {
    final currentSize = _getCurrentSize();

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
class FontFamilyDropdown extends StatelessWidget {
  final quill.QuillController controller;
  final VoidCallback? onChanged;

  const FontFamilyDropdown({
    super.key,
    required this.controller,
    this.onChanged,
  });

  static const List<String> fontFamilies = [
    'Roboto',
    'Courier',
    'Monospace',
    'Sans-serif',
    'Serif',
  ];

  String _getCurrentFamily() {
    try {
      final style = controller.getSelectionStyle();
      final fontAttr = style.attributes[quill.Attribute.font.key]?.value;
      if (fontAttr != null && fontAttr is String) {
        return fontAttr;
      }
    } catch (e) {
      // Ignore errors
    }
    return 'Roboto';
  }

  @override
  Widget build(BuildContext context) {
    final currentFamily = _getCurrentFamily();

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
                currentFamily,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(fontSize: 14),
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
      itemBuilder: (context) => fontFamilies.map((family) {
        return PopupMenuItem<String>(
          value: family,
          child: Text(
            family,
            style: TextStyle(
              fontSize: 14,
              fontFamily: family,
              fontWeight: family == currentFamily
                  ? FontWeight.bold
                  : FontWeight.normal,
            ),
          ),
        );
      }).toList(),
      onSelected: (newFamily) {
        controller.formatSelection(
          quill.Attribute.fromKeyValue('font', newFamily),
        );
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

  static const List<double> lineHeights = [
    1.0,
    1.2,
    1.5,
    1.8,
    2.0,
    2.2,
    2.5,
    3.0,
  ];

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

  static const List<double> spacings = [0.0, 4.0, 8.0, 12.0, 16.0, 24.0];

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
