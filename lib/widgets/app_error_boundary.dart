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
import '../models/app_error.dart';

typedef ErrorViewBuilder =
    Widget Function(BuildContext context, Object error, StackTrace? stackTrace);

/// Lightweight error boundary capturing build errors for child subtree.
class AppErrorBoundary extends StatefulWidget {
  final Widget child;
  final ErrorViewBuilder? builder;
  const AppErrorBoundary({super.key, required this.child, this.builder});

  @override
  State<AppErrorBoundary> createState() => _AppErrorBoundaryState();
}

class _AppErrorBoundaryState extends State<AppErrorBoundary> {
  Object? _error;
  StackTrace? _stack;

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      final b = widget.builder;
      return b != null
          ? b(context, _error!, _stack)
          : _DefaultErrorView(error: _error!, stack: _stack);
    }
    try {
      return widget.child;
    } catch (e, st) {
      setState(() {
        _error = e;
        _stack = st;
      });
      return _DefaultErrorView(error: e, stack: st);
    }
  }
}

class _DefaultErrorView extends StatelessWidget {
  final Object error;
  final StackTrace? stack;
  const _DefaultErrorView({required this.error, this.stack});

  @override
  Widget build(BuildContext context) {
    final isAppError = error is AppError;
    final msg = isAppError ? (error as AppError).message : error.toString();
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          'Oops: $msg',
          style: Theme.of(
            context,
          ).textTheme.bodyLarge?.copyWith(color: Colors.red),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
