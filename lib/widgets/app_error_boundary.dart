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
