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

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Generic state holder notifier for simple state management
/// Replaces StateProvider from Riverpod 2.x
class StateHolder<T> extends Notifier<T> {
  final T initialValue;

  StateHolder(this.initialValue);

  @override
  T build() => initialValue;

  void update(T value) {
    debugPrint('[StateHolder] Updating from $state to $value');
    state = value;
    debugPrint('[StateHolder] New state: $state');
  }
}

/// Helper function to create a simple state provider (replacement for StateProvider)
NotifierProvider<StateHolder<T>, T> stateProvider<T>(T initialValue) {
  return NotifierProvider<StateHolder<T>, T>(() => StateHolder(initialValue));
}
