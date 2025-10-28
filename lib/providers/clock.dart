import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Clock abstraction for testable time-dependent code.
///
/// Use this instead of calling DateTime.now() directly to make time-based
/// logic deterministic and testable. In production, uses SystemClock; in
/// tests, override clockProvider with FixedClock or a custom implementation.
abstract class Clock {
  DateTime now();
}

/// Production clock that returns the actual current time.
class SystemClock implements Clock {
  const SystemClock();

  @override
  DateTime now() => DateTime.now();
}

/// Fixed clock for tests that always returns the same time.
class FixedClock implements Clock {
  final DateTime _now;

  const FixedClock(this._now);

  @override
  DateTime now() => _now;
}

/// Global clock provider. Override in tests to control time.
///
/// Example usage in production code:
/// ```dart
/// final now = ref.watch(clockProvider).now();
/// ```
///
/// Example override in tests:
/// ```dart
/// final container = ProviderContainer(overrides: [
///   clockProvider.overrideWithValue(FixedClock(DateTime(2025, 10, 28))),
/// ]);
/// ```
final clockProvider = Provider<Clock>((ref) => const SystemClock());
