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
import 'package:flutter_quill/flutter_quill.dart' as quill;

/// Provider to track floating toolbar expanded state
/// Using a simple ValueNotifier instead of Riverpod to keep this widget self-contained

/// Data class for toolbar action items
class _ToolbarItem {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final bool isActive;

  const _ToolbarItem({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.isActive = false,
  });
}

/// Floating toolbar FAB with vertical expandable menu for note formatting
/// Designed for thumb-friendly one-handed use
class FloatingNoteToolbar extends StatefulWidget {
  final quill.QuillController controller;
  final VoidCallback? onInsertImage;
  final VoidCallback? onInsertVideo;
  final VoidCallback? onInsertVoice;
  final VoidCallback? onInsertLink;

  const FloatingNoteToolbar({
    super.key,
    required this.controller,
    this.onInsertImage,
    this.onInsertVideo,
    this.onInsertVoice,
    this.onInsertLink,
  });

  @override
  State<FloatingNoteToolbar> createState() => _FloatingNoteToolbarState();
}

class _FloatingNoteToolbarState extends State<FloatingNoteToolbar>
    with TickerProviderStateMixin {
  bool _isExpanded = false;
  bool _showMoreOptions = false;
  bool _isFaded = false; // Toolbar is faded/transparent
  late AnimationController _expandController;
  late Animation<double> _expandAnimation;

  @override
  void initState() {
    super.initState();
    _expandController = AnimationController(
      duration: const Duration(milliseconds: 250),
      vsync: this,
    );
    _expandAnimation = CurvedAnimation(
      parent: _expandController,
      curve: Curves.easeOutBack,
      reverseCurve: Curves.easeInBack,
    );

    // Listen to controller changes for button state updates and typing detection
    widget.controller.addListener(_onControllerChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    _expandController.dispose();
    super.dispose();
  }

  void _onControllerChanged() {
    if (mounted) {
      // Fade toolbar when document changes (typing)
      // Check if this is a document change vs just selection change
      if (!_isFaded) {
        setState(() {
          _isFaded = true;
        });
      } else {
        setState(() {});
      }
    }
  }

  // Called when user touches/interacts with toolbar
  void _onToolbarTouched() {
    if (_isFaded && mounted) {
      setState(() {
        _isFaded = false;
      });
    }
  }

  void _toggleExpanded() {
    _onToolbarTouched(); // Unfade toolbar when FAB is pressed
    setState(() {
      _isExpanded = !_isExpanded;
      if (_isExpanded) {
        _expandController.forward();
      } else {
        _expandController.reverse();
        // Also reset to primary toolbar when closing
        _showMoreOptions = false;
      }
    });
  }

  void _toggleMoreOptions() {
    setState(() {
      _showMoreOptions = !_showMoreOptions;
    });
  }

  void _closeToolbar() {
    if (_isExpanded) {
      _toggleExpanded();
    }
  }

  // Check if a style is currently active
  bool _isStyleActive(quill.Attribute attribute) {
    final style = widget.controller.getSelectionStyle();
    // For block attributes (lists, headers, etc.), we need to check the value, not just key
    // because ul, ol, and checklist all share the same 'block' key
    if (style.containsKey(attribute.key)) {
      final currentValue = style.attributes[attribute.key]?.value;
      return currentValue == attribute.value;
    }
    return false;
  }

  // Toggle a style on/off
  void _toggleStyle(quill.Attribute attribute) {
    if (_isStyleActive(attribute)) {
      widget.controller.formatSelection(quill.Attribute.clone(attribute, null));
    } else {
      widget.controller.formatSelection(attribute);
    }
  }

  // Available font sizes for cycling (matching common sizes from normal toolbar)
  static const List<int> _fontSizes = [
    10,
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
  ];

  // Get current font size index
  int _getCurrentFontSizeIndex() {
    final style = widget.controller.getSelectionStyle();
    final sizeAttr = style.attributes[quill.Attribute.size.key];
    if (sizeAttr == null) return 3; // default to 16 (index 3)
    final value = sizeAttr.value;

    // Handle both string and numeric values
    int? sizeValue;
    if (value is String) {
      // Extract numeric value (handles both "18" and "18px")
      final numStr = value.replaceAll(RegExp(r'[^0-9]'), '');
      sizeValue = int.tryParse(numStr);
    } else if (value is num) {
      sizeValue = value.toInt();
    }

    if (sizeValue != null) {
      final index = _fontSizes.indexOf(sizeValue);
      if (index >= 0) return index;
      // Find closest size
      for (int i = 0; i < _fontSizes.length; i++) {
        if (_fontSizes[i] >= sizeValue) return i;
      }
    }
    return 3; // default to 16
  }

  // Cycle through font sizes
  void _cycleFontSize({required bool increase}) {
    int currentIndex = _getCurrentFontSizeIndex();
    int newIndex;
    if (increase) {
      newIndex = (currentIndex + 1).clamp(0, _fontSizes.length - 1);
    } else {
      newIndex = (currentIndex - 1).clamp(0, _fontSizes.length - 1);
    }
    // Apply font size using numeric string format (same as normal toolbar)
    widget.controller.formatSelection(
      quill.Attribute.fromKeyValue('size', '${_fontSizes[newIndex]}'),
    );
  }

  // Available font families - same as normal toolbar
  static const List<String> _fontFamilies = [
    'Roboto',
    'Courier',
    'Monospace',
    'Sans-serif',
    'Serif',
  ];

  // Show font picker dialog
  void _showFontPicker() {
    // Get current font family
    String currentFamily = 'Roboto';
    try {
      final style = widget.controller.getSelectionStyle();
      final fontAttr = style.attributes[quill.Attribute.font.key]?.value;
      if (fontAttr != null && fontAttr is String) {
        currentFamily = fontAttr;
      }
    } catch (e) {
      // Ignore errors and use default
    }

    final cs = Theme.of(context).colorScheme;
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                'Choose Font',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: cs.onSurface,
                ),
              ),
            ),
            const Divider(),
            ...(_fontFamilies.map(
              (family) => ListTile(
                title: Text(
                  family,
                  style: TextStyle(
                    fontFamily: family,
                    fontWeight: family == currentFamily
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                ),
                trailing: family == currentFamily
                    ? Icon(Icons.check, color: cs.primary)
                    : null,
                onTap: () {
                  widget.controller.formatSelection(
                    quill.Attribute.fromKeyValue('font', family),
                  );
                  Navigator.pop(context);
                },
              ),
            )),
          ],
        ),
      ),
    );
  }

  // Get primary toolbar items (most commonly used)
  // Order: top-to-bottom visually = Lists, Underline, Italic, Bold (then More button below)
  List<_ToolbarItem> _getPrimaryItems() {
    return [
      // Lists at top (furthest from thumb)
      _ToolbarItem(
        icon: Icons.checklist,
        tooltip: 'Checklist',
        onTap: () => _toggleStyle(quill.Attribute.unchecked),
        isActive:
            _isStyleActive(quill.Attribute.unchecked) ||
            _isStyleActive(quill.Attribute.checked),
      ),
      _ToolbarItem(
        icon: Icons.format_list_numbered,
        tooltip: 'Numbered List',
        onTap: () => _toggleStyle(quill.Attribute.ol),
        isActive: _isStyleActive(quill.Attribute.ol),
      ),
      _ToolbarItem(
        icon: Icons.format_list_bulleted,
        tooltip: 'Bullet List',
        onTap: () => _toggleStyle(quill.Attribute.ul),
        isActive: _isStyleActive(quill.Attribute.ul),
      ),
      // Underline
      _ToolbarItem(
        icon: Icons.format_underlined,
        tooltip: 'Underline',
        onTap: () => _toggleStyle(quill.Attribute.underline),
        isActive: _isStyleActive(quill.Attribute.underline),
      ),
      // Italic
      _ToolbarItem(
        icon: Icons.format_italic,
        tooltip: 'Italic',
        onTap: () => _toggleStyle(quill.Attribute.italic),
        isActive: _isStyleActive(quill.Attribute.italic),
      ),
      // Bold (closest to More button)
      _ToolbarItem(
        icon: Icons.format_bold,
        tooltip: 'Bold',
        onTap: () => _toggleStyle(quill.Attribute.bold),
        isActive: _isStyleActive(quill.Attribute.bold),
      ),
    ];
  }

  // Get secondary toolbar items (less frequently used, behind expander)
  List<_ToolbarItem> _getSecondaryItems() {
    return [
      // Headers
      _ToolbarItem(
        icon: Icons.looks_one_outlined,
        tooltip: 'Heading 1',
        onTap: () => _toggleStyle(quill.Attribute.h1),
        isActive: _isStyleActive(quill.Attribute.h1),
      ),
      _ToolbarItem(
        icon: Icons.looks_two_outlined,
        tooltip: 'Heading 2',
        onTap: () => _toggleStyle(quill.Attribute.h2),
        isActive: _isStyleActive(quill.Attribute.h2),
      ),
      _ToolbarItem(
        icon: Icons.looks_3_outlined,
        tooltip: 'Heading 3',
        onTap: () => _toggleStyle(quill.Attribute.h3),
        isActive: _isStyleActive(quill.Attribute.h3),
      ),
      // Font family
      _ToolbarItem(
        icon: Icons.font_download_outlined,
        tooltip: 'Change Font',
        onTap: _showFontPicker,
        isActive: false,
      ),
      // Font size
      _ToolbarItem(
        icon: Icons.text_increase,
        tooltip: 'Increase Size',
        onTap: () => _cycleFontSize(increase: true),
        isActive: false,
      ),
      _ToolbarItem(
        icon: Icons.text_decrease,
        tooltip: 'Decrease Size',
        onTap: () => _cycleFontSize(increase: false),
        isActive: false,
      ),
      // Text formatting
      _ToolbarItem(
        icon: Icons.format_strikethrough,
        tooltip: 'Strikethrough',
        onTap: () => _toggleStyle(quill.Attribute.strikeThrough),
        isActive: _isStyleActive(quill.Attribute.strikeThrough),
      ),
      _ToolbarItem(
        icon: Icons.code,
        tooltip: 'Inline Code',
        onTap: () => _toggleStyle(quill.Attribute.inlineCode),
        isActive: _isStyleActive(quill.Attribute.inlineCode),
      ),
      _ToolbarItem(
        icon: Icons.format_quote,
        tooltip: 'Quote',
        onTap: () => _toggleStyle(quill.Attribute.blockQuote),
        isActive: _isStyleActive(quill.Attribute.blockQuote),
      ),
      _ToolbarItem(
        icon: Icons.data_object,
        tooltip: 'Code Block',
        onTap: () => _toggleStyle(quill.Attribute.codeBlock),
        isActive: _isStyleActive(quill.Attribute.codeBlock),
      ),
      if (widget.onInsertImage != null)
        _ToolbarItem(
          icon: Icons.image_outlined,
          tooltip: 'Insert Image',
          onTap: () {
            widget.onInsertImage!();
            _closeToolbar();
          },
        ),
      if (widget.onInsertVideo != null)
        _ToolbarItem(
          icon: Icons.videocam_outlined,
          tooltip: 'Insert Video',
          onTap: () {
            widget.onInsertVideo!();
            _closeToolbar();
          },
        ),
      if (widget.onInsertVoice != null)
        _ToolbarItem(
          icon: Icons.mic_outlined,
          tooltip: 'Insert Voice Note',
          onTap: () {
            widget.onInsertVoice!();
            _closeToolbar();
          },
        ),
      if (widget.onInsertLink != null)
        _ToolbarItem(
          icon: Icons.link,
          tooltip: 'Insert Link',
          onTap: () {
            widget.onInsertLink!();
            _closeToolbar();
          },
        ),
      _ToolbarItem(
        icon: Icons.format_clear,
        tooltip: 'Clear Formatting',
        onTap: () {
          widget.controller.formatSelection(
            quill.Attribute.clone(quill.Attribute.bold, null),
          );
          widget.controller.formatSelection(
            quill.Attribute.clone(quill.Attribute.italic, null),
          );
          widget.controller.formatSelection(
            quill.Attribute.clone(quill.Attribute.underline, null),
          );
          widget.controller.formatSelection(
            quill.Attribute.clone(quill.Attribute.strikeThrough, null),
          );
        },
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final primaryItems = _getPrimaryItems();
    final secondaryItems = _getSecondaryItems();

    // Calculate max height - limit to 250px to avoid overlapping title bar
    const maxToolbarHeight = 250.0;

    // Determine which items to show based on _showMoreOptions
    final currentItems = _showMoreOptions ? secondaryItems : primaryItems;

    return GestureDetector(
      onTapDown: (_) => _onToolbarTouched(),
      onPanStart: (_) => _onToolbarTouched(),
      child: AnimatedOpacity(
        opacity: _isFaded ? 0.3 : 1.0,
        duration: const Duration(milliseconds: 200),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Single toolbar - shows either primary or secondary items
            AnimatedBuilder(
              animation: _expandAnimation,
              builder: (context, child) {
                final animValue = _expandAnimation.value.clamp(0.0, 1.0);
                if (animValue == 0) {
                  return const SizedBox.shrink();
                }
                return Transform.scale(
                  scale: 0.8 + (0.2 * animValue),
                  alignment: Alignment.bottomCenter,
                  child: Opacity(opacity: animValue, child: child),
                );
              },
              child: Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: cs.shadow.withOpacity(0.15),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Scrollable items area
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        // Max height minus space for divider and sticky button
                        maxHeight: maxToolbarHeight - 49.0,
                      ),
                      child: NotificationListener<ScrollNotification>(
                        onNotification: (notification) {
                          _onToolbarTouched(); // Unfade on scroll
                          return false;
                        },
                        child: SingleChildScrollView(
                          reverse:
                              true, // Start scrolled to bottom so Bold etc are visible
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 200),
                            transitionBuilder: (child, animation) {
                              return FadeTransition(
                                opacity: animation,
                                child: SlideTransition(
                                  position: Tween<Offset>(
                                    begin: Offset(
                                      _showMoreOptions ? -0.2 : 0.2,
                                      0,
                                    ),
                                    end: Offset.zero,
                                  ).animate(animation),
                                  child: child,
                                ),
                              );
                            },
                            child: Column(
                              key: ValueKey<bool>(_showMoreOptions),
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Items (vertical stack)
                                ...currentItems.map(
                                  (item) => _buildToolbarButton(item, cs),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    // Sticky divider and toggle button (always visible)
                    _buildHorizontalDivider(cs),
                    _buildMoreOptionsToggle(cs),
                  ],
                ),
              ),
            ),

            // Main FAB
            FloatingActionButton(
              onPressed: _toggleExpanded,
              backgroundColor: _isExpanded ? cs.primaryContainer : cs.primary,
              foregroundColor: _isExpanded
                  ? cs.onPrimaryContainer
                  : cs.onPrimary,
              shape: const CircleBorder(),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                transitionBuilder: (child, animation) {
                  return RotationTransition(
                    turns: Tween<double>(
                      begin: 0.5,
                      end: 1.0,
                    ).animate(animation),
                    child: ScaleTransition(scale: animation, child: child),
                  );
                },
                child: Icon(
                  _isExpanded ? Icons.close : Icons.text_fields,
                  key: ValueKey<bool>(_isExpanded),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMoreOptionsToggle(ColorScheme cs) {
    return Tooltip(
      message: _showMoreOptions ? 'Back to basics' : 'More options',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            _onToolbarTouched(); // Unfade toolbar
            _toggleMoreOptions();
          },
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: 40,
            height: 40,
            child: Icon(
              _showMoreOptions
                  ? Icons.keyboard_arrow_down
                  : Icons.keyboard_arrow_up,
              size: 24,
              color: _showMoreOptions ? cs.primary : cs.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildToolbarButton(_ToolbarItem item, ColorScheme cs) {
    return Tooltip(
      message: item.tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            _onToolbarTouched(); // Unfade toolbar
            item.onTap();
          },
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: item.isActive
                  ? cs.primaryContainer.withOpacity(0.5)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              item.icon,
              size: 20,
              color: item.isActive ? cs.primary : cs.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHorizontalDivider(ColorScheme cs) {
    return Container(
      width: 24,
      height: 1,
      margin: const EdgeInsets.symmetric(vertical: 4),
      color: cs.outlineVariant.withOpacity(0.5),
    );
  }
}
