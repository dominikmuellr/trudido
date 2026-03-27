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
import '../widgets/common/common.dart';

class TodoSearchBar extends StatefulWidget {
  final String searchQuery;
  final Function(String) onSearchChanged;

  const TodoSearchBar({
    super.key,
    required this.searchQuery,
    required this.onSearchChanged,
  });

  @override
  State<TodoSearchBar> createState() => _TodoSearchBarState();
}

class _TodoSearchBarState extends State<TodoSearchBar>
    with SingleTickerProviderStateMixin {
  late TextEditingController _controller;
  late FocusNode _focusNode;
  late AnimationController _animationController;
  late Animation<double> _elevationAnimation;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.searchQuery);
    _focusNode = FocusNode();
    _focusNode.addListener(_onFocusChanged);

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 250),
      vsync: this,
    );
    _elevationAnimation = Tween<double>(begin: 0.5, end: 3.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic),
    );
  }

  void _onFocusChanged() {
    if (_focusNode.hasFocus) {
      _animationController.forward();
    } else {
      _animationController.reverse();
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChanged);
    _focusNode.dispose();
    _animationController.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final borderRadius = BorderRadius.circular(28);

    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Material(
          elevation: _elevationAnimation.value,
          shadowColor: colorScheme.shadow.withValues(alpha: 0.3),
          borderRadius: borderRadius,
          color: Colors.transparent,
          child: child,
        );
      },
      child: TextField(
        controller: _controller,
        focusNode: _focusNode,
        decoration: InputDecoration(
          hintText: 'Search todos...',
          prefixIcon: Icon(Icons.search, color: colorScheme.onSurfaceVariant),
          suffixIcon: widget.searchQuery.isNotEmpty
              ? ExpressiveIconButton(
                  icon: Icon(Icons.close, color: colorScheme.onSurfaceVariant),
                  onPressed: () {
                    _controller.clear();
                    widget.onSearchChanged('');
                  },
                )
              : null,
          filled: true,
          fillColor: colorScheme.surfaceContainerHigh,
          border: OutlineInputBorder(
            borderRadius: borderRadius,
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: borderRadius,
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: borderRadius,
            borderSide: BorderSide(
              color: colorScheme.primary.withValues(alpha: 0.4),
              width: 1.5,
            ),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
        ),
        style: TextStyle(color: colorScheme.onSurface),
        onChanged: widget.onSearchChanged,
      ),
    );
  }
}
