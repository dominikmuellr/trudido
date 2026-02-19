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
