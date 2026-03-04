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
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import '../widgets/common/common.dart';
import '../providers/app_providers.dart';
import '../controllers/preferences_controller.dart';

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

/// Floating toolbar panel with draggable positioning and adaptive layout.
/// The toggle FAB lives in the parent screen; this widget only renders
/// the expanded toolbar panel as an overlay.
class FloatingNoteToolbar extends ConsumerStatefulWidget {
  final quill.QuillController controller;
  final bool isExpanded;
  final VoidCallback onToggle;
  final VoidCallback? onInsertImage;
  final VoidCallback? onInsertVideo;
  final VoidCallback? onInsertVoice;
  final VoidCallback? onInsertLink;
  final double currentLineHeight;
  final double currentParagraphSpacing;
  final Function(double)? onLineHeightChanged;
  final Function(double)? onParagraphSpacingChanged;

  /// The actual available size of the parent container (e.g. from LayoutBuilder).
  /// When the Scaffold has resizeToAvoidBottomInset: true, the body shrinks
  /// when the keyboard opens, so MediaQuery.size is unreliable for positioning.
  /// Pass the real constraints so the toolbar moves up with the keyboard.
  final Size? availableSize;

  /// Called when the toolbar is dragged to the top dock zone, signalling
  /// the parent to switch back to the standard (docked) toolbar.
  final VoidCallback? onDockToTop;

  /// Initial fractional position (0..1) when first created (e.g. after detach).
  /// Overrides saved preferences if non-null.
  final Offset? initialPosition;

  const FloatingNoteToolbar({
    super.key,
    required this.controller,
    required this.isExpanded,
    required this.onToggle,
    this.onInsertImage,
    this.onInsertVideo,
    this.onInsertVoice,
    this.onInsertLink,
    this.currentLineHeight = 1.5,
    this.currentParagraphSpacing = 8.0,
    this.onLineHeightChanged,
    this.onParagraphSpacingChanged,
    this.availableSize,
    this.onDockToTop,
    this.initialPosition,
  });

  @override
  ConsumerState<FloatingNoteToolbar> createState() =>
      _FloatingNoteToolbarState();
}

class _FloatingNoteToolbarState extends ConsumerState<FloatingNoteToolbar>
    with TickerProviderStateMixin {
  bool _showMoreOptions = false;
  bool _isFaded = false; // Toolbar is faded/transparent
  late AnimationController _expandController;
  late Animation<double> _expandAnimation;

  // Position tracking — stored as fractional (0..1) of the panel's LEFT/TOP
  // relative to screen size. -1 means "not set yet" → will use default.
  double _fracX = -1.0;
  double _fracY = -1.0;
  bool _isDragging = false;
  // During drag: absolute pixel left/top of the panel
  double _dragLeft = 0.0;
  double _dragTop = 0.0;
  // Whether we're near the top dock zone during drag
  bool _nearDockZone = false;

  // Toolbar panel padding
  static const double _edgePadding = 8.0;

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

    // Load saved position from preferences
    final prefs = ref.read(preferencesStateProvider);
    _fracX = prefs.floatingToolbarX;
    _fracY = prefs.floatingToolbarY;

    // If an initial position was passed (e.g. from drag-detach), use it
    if (widget.initialPosition != null) {
      _fracX = widget.initialPosition!.dx;
      _fracY = widget.initialPosition!.dy;
    }

    // Start expanded if parent says so
    if (widget.isExpanded) {
      _expandController.value = 1.0;
    }

    // Listen to controller changes for button state updates and typing detection
    widget.controller.addListener(_onControllerChanged);
  }

  @override
  void didUpdateWidget(covariant FloatingNoteToolbar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isExpanded != oldWidget.isExpanded) {
      if (widget.isExpanded) {
        _expandController.forward();
      } else {
        _expandController.reverse();
        _showMoreOptions = false;
      }
    }
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

  void _toggleMoreOptions() {
    setState(() {
      _showMoreOptions = !_showMoreOptions;
    });
  }

  void _closeToolbar() {
    if (widget.isExpanded) {
      widget.onToggle();
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

  void _showLineHeightMenu() {
    final lineHeights = [1.0, 1.2, 1.5, 1.8, 2.0];
    // ignore: unused_local_variable
    final currentHeight = widget.currentLineHeight;

    _showPopupMenu(
      menuItems: lineHeights.map((height) {
        return PopupMenuItem<double>(
          value: height,
          child: Text('${height.toStringAsFixed(1)}x'),
        );
      }).toList(),
      onSelected: (newHeight) {
        widget.onLineHeightChanged?.call(newHeight);
      },
    );
  }

  void _showParagraphSpacingMenu() {
    final spacings = [0.0, 4.0, 8.0, 12.0, 16.0, 24.0];
    // ignore: unused_local_variable
    final currentSpacing = widget.currentParagraphSpacing;

    _showPopupMenu(
      menuItems: spacings.map((spacing) {
        return PopupMenuItem<double>(
          value: spacing,
          child: Text('${spacing.toStringAsFixed(0)}pt'),
        );
      }).toList(),
      onSelected: (newSpacing) {
        widget.onParagraphSpacingChanged?.call(newSpacing);
      },
    );
  }

  void _showPopupMenu({
    required List<PopupMenuEntry> menuItems,
    required Function(dynamic) onSelected,
  }) {
    final RenderBox button = context.findRenderObject() as RenderBox;
    final RenderBox overlay =
        Navigator.of(context).overlay!.context.findRenderObject() as RenderBox;
    final RelativeRect position = RelativeRect.fromRect(
      Rect.fromPoints(
        button.localToGlobal(Offset.zero, ancestor: overlay),
        button.localToGlobal(
          button.size.bottomRight(Offset.zero),
          ancestor: overlay,
        ),
      ),
      Offset.zero & overlay.size,
    );

    showMenu(context: context, position: position, items: menuItems).then((
      value,
    ) {
      if (value != null) {
        onSelected(value);
      }
    });
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
      // Line Height
      _ToolbarItem(
        icon: Icons.height,
        tooltip: 'Line Height',
        onTap: _showLineHeightMenu,
        isActive: false,
      ),
      // Paragraph Spacing
      _ToolbarItem(
        icon: Icons.space_bar,
        tooltip: 'Paragraph Spacing',
        onTap: _showParagraphSpacingMenu,
        isActive: false,
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

  /// Compute the pixel position of the toolbar panel center from fractional coords.
  /// If not set (-1), default to bottom-right (above FAB area).
  /// [areaSize] is the actual usable area (may already exclude the keyboard).
  /// Returns the LEFT/TOP of the panel, given its size.
  Offset _resolveLeftTop(Size areaSize, double panelW, double panelH) {
    if (_fracX < 0 || _fracY < 0) {
      // Default: bottom-right, above FAB area
      return Offset(
        areaSize.width - panelW - _edgePadding,
        areaSize.height - panelH - 100,
      );
    }
    return Offset(
      (_fracX * areaSize.width).clamp(
        _edgePadding,
        areaSize.width - panelW - _edgePadding,
      ),
      (_fracY * areaSize.height).clamp(
        _edgePadding,
        areaSize.height - panelH - _edgePadding,
      ),
    );
  }

  /// Save fractional toolbar position to preferences.
  /// [left]/[top] are the panel's pixel left/top, converted to fractional.
  void _savePosition(double left, double top, Size screenSize) {
    _fracX = screenSize.width > 0
        ? (left / screenSize.width).clamp(0.0, 1.0)
        : 0.0;
    _fracY = screenSize.height > 0
        ? (top / screenSize.height).clamp(0.0, 1.0)
        : 0.0;
    final controller = ref.read(preferencesControllerProvider);
    controller.setFloatingToolbarPosition(_fracX, _fracY);
  }

  /// Safe clamp that handles min > max by returning the average.
  double _safeClamp(double value, double min, double max) {
    if (min > max) return (min + max) / 2;
    return value.clamp(min, max);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final mq = MediaQuery.of(context);
    final screenSize = widget.availableSize ?? mq.size;
    final keyboardHeight = widget.availableSize != null
        ? 0.0
        : mq.viewInsets.bottom;
    // Account for system navigation bar (3-button nav) via padding.bottom
    final bottomInset = mq.padding.bottom;
    final usableHeight = screenSize.height - keyboardHeight - bottomInset;

    // If not expanded, render nothing (the FAB lives in the parent)
    if (!widget.isExpanded) return const SizedBox.shrink();

    final primaryItems = _getPrimaryItems();
    final secondaryItems = _getSecondaryItems();
    final currentItems = _showMoreOptions ? secondaryItems : primaryItems;

    // Always use vertical layout for now
    const panelWidth = 48.0;
    final panelHeight = _verticalPanelHeight(currentItems.length);

    // Compute left/top: during drag use raw pixels, otherwise from fractional
    double panelLeft;
    double panelTop;
    if (_isDragging) {
      panelLeft = _dragLeft;
      panelTop = _dragTop;
    } else {
      final resolved = _resolveLeftTop(
        Size(screenSize.width, usableHeight),
        panelWidth,
        panelHeight,
      );
      panelLeft = resolved.dx;
      panelTop = resolved.dy;
    }

    // Clamp to visible area
    panelLeft = _safeClamp(
      panelLeft,
      _edgePadding,
      screenSize.width - panelWidth - _edgePadding,
    );
    panelTop = _safeClamp(
      panelTop,
      _edgePadding,
      usableHeight - panelHeight - _edgePadding,
    );

    final panelWidget = AnimatedOpacity(
      opacity: _isFaded ? 0.3 : 1.0,
      duration: const Duration(milliseconds: 200),
      child: AnimatedBuilder(
        animation: _expandAnimation,
        builder: (context, child) {
          final animValue = _expandAnimation.value.clamp(0.0, 1.0);
          if (animValue == 0) return const SizedBox.shrink();
          return Transform.scale(
            scale: 0.8 + (0.2 * animValue),
            alignment: Alignment.center,
            child: Opacity(opacity: animValue, child: child),
          );
        },
        child: _buildVerticalPanel(
          currentItems,
          cs,
          panelLeft,
          panelTop,
          screenSize,
          usableHeight,
        ),
      ),
    );

    // Use a SizedBox.expand with a Stack so Positioned works inside
    // LayoutBuilder. The Stack itself is hit-test translucent so only
    // the toolbar panel receives touches.
    return SizedBox.expand(
      child: Stack(
        children: [
          Positioned(left: panelLeft, top: panelTop, child: panelWidget),
        ],
      ),
    );
  }

  /// Build the drag handle grip widget.
  /// [currentLeft]/[currentTop] are the panel's current pixel position.
  Widget _buildDragHandle(
    ColorScheme cs,
    double currentLeft,
    double currentTop,
    Size screenSize,
    double usableHeight,
  ) {
    return GestureDetector(
      onPanStart: (_) {
        _onToolbarTouched();
        setState(() {
          _isDragging = true;
          _nearDockZone = false;
          _dragLeft = currentLeft;
          _dragTop = currentTop;
        });
      },
      onPanUpdate: (details) {
        if (!_isDragging) return;
        setState(() {
          _dragLeft += details.delta.dx;
          _dragTop += details.delta.dy;
          // Update fractional for layout recalculation (horizontal/vertical)
          _fracX = screenSize.width > 0
              ? (_dragLeft / screenSize.width).clamp(0.0, 1.0)
              : 0.0;
          _fracY = screenSize.height > 0
              ? (_dragTop / screenSize.height).clamp(0.0, 1.0)
              : 0.0;
          _nearDockZone = _dragTop < 40;
        });
      },
      onPanEnd: (_) {
        final wasDocking = _nearDockZone;
        final left = _dragLeft;
        final top = _dragTop;
        setState(() {
          _isDragging = false;
          _nearDockZone = false;
        });
        if (wasDocking && widget.onDockToTop != null) {
          widget.onDockToTop!();
          return;
        }
        _savePosition(left, top, screenSize);
      },
      child: MouseRegion(
        cursor: SystemMouseCursors.grab,
        child: Container(
          width: 40,
          height: 16,
          alignment: Alignment.center,
          child: Container(
            width: 24,
            height: 4,
            decoration: BoxDecoration(
              color: cs.onSurfaceVariant.withValues(
                alpha: _isDragging ? 0.6 : 0.35,
              ),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
      ),
    );
  }

  // ── Vertical panel (when toolbar is on the left/right side) ──────────────

  double _verticalPanelHeight(int itemCount) {
    // Each item 40px + more toggle 40px + divider 9px + drag handle 16px + padding 8px
    const maxToolbarHeight = 266.0; // 250 + 16 for drag handle
    final naturalHeight = (itemCount * 40.0) + 49.0 + 16.0 + 8.0;
    return naturalHeight.clamp(0.0, maxToolbarHeight);
  }

  Widget _buildVerticalPanel(
    List<_ToolbarItem> items,
    ColorScheme cs,
    double currentLeft,
    double currentTop,
    Size screenSize,
    double usableHeight,
  ) {
    const maxToolbarHeight = 266.0;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(16),
        border: _isDragging
            ? Border.all(color: cs.primary.withValues(alpha: 0.6), width: 2)
            : null,
        boxShadow: [
          BoxShadow(
            color: cs.shadow.withValues(alpha: _isDragging ? 0.25 : 0.15),
            blurRadius: _isDragging ? 12 : 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Scrollable items area
          ConstrainedBox(
            constraints: const BoxConstraints(
              maxHeight:
                  maxToolbarHeight -
                  65.0, // subtract toggle+divider+drag handle
            ),
            child: NotificationListener<ScrollNotification>(
              onNotification: (notification) {
                _onToolbarTouched();
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
                          begin: Offset(_showMoreOptions ? -0.2 : 0.2, 0),
                          end: Offset.zero,
                        ).animate(animation),
                        child: child,
                      ),
                    );
                  },
                  child: Column(
                    key: ValueKey<bool>(_showMoreOptions),
                    mainAxisSize: MainAxisSize.min,
                    children: items
                        .map((item) => _buildToolbarButton(item, cs))
                        .toList(),
                  ),
                ),
              ),
            ),
          ),
          // Sticky divider and toggle button (always visible)
          _buildHorizontalDivider(cs),
          _buildMoreOptionsToggle(cs),
          // Drag handle at the bottom (easy thumb reach)
          _buildDragHandle(
            cs,
            currentLeft,
            currentTop,
            screenSize,
            usableHeight,
          ),
        ],
      ),
    );
  }

  Widget _buildMoreOptionsToggle(ColorScheme cs) {
    return Tooltip(
      message: _showMoreOptions ? 'Back to basics' : 'More options',
      child: Material(
        color: Colors.transparent,
        child: ExpressiveInkWell(
          onTap: () {
            _onToolbarTouched(); // Unfade toolbar
            _toggleMoreOptions();
          },
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
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
        child: ExpressiveInkWell(
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
                  ? cs.primaryContainer.withValues(alpha: 0.5)
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
      color: cs.outlineVariant.withValues(alpha: 0.5),
    );
  }
}
