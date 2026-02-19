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

/// Global navigation service for handling navigation from outside the widget tree
/// (such as from notification callbacks)
class NavigationService {
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  /// Get the current navigator state
  static NavigatorState? get navigator => navigatorKey.currentState;

  /// Get the current context
  static BuildContext? get context => navigatorKey.currentContext;

  /// Navigate to a new route
  static Future<T?> navigateTo<T extends Object?>(Route<T> route) {
    final navigator = NavigationService.navigator;
    if (navigator == null) {
      throw Exception(
        'Navigator not available. Make sure NavigationService.navigatorKey is assigned to MaterialApp.navigatorKey',
      );
    }
    return navigator.push(route);
  }

  /// Navigate to a new route and replace the current one
  static Future<T?> navigateAndReplace<T extends Object?, TO extends Object?>(
    Route<T> newRoute,
  ) {
    final navigator = NavigationService.navigator;
    if (navigator == null) {
      throw Exception(
        'Navigator not available. Make sure NavigationService.navigatorKey is assigned to MaterialApp.navigatorKey',
      );
    }
    return navigator.pushReplacement(newRoute);
  }

  /// Pop the current route
  static void pop<T extends Object?>([T? result]) {
    final navigator = NavigationService.navigator;
    if (navigator == null) {
      throw Exception(
        'Navigator not available. Make sure NavigationService.navigatorKey is assigned to MaterialApp.navigatorKey',
      );
    }
    if (navigator.canPop()) {
      navigator.pop(result);
    }
  }

  /// Navigate to a named route
  static Future<T?> navigateToNamed<T extends Object?>(
    String routeName, {
    Object? arguments,
  }) {
    final navigator = NavigationService.navigator;
    if (navigator == null) {
      throw Exception(
        'Navigator not available. Make sure NavigationService.navigatorKey is assigned to MaterialApp.navigatorKey',
      );
    }
    return navigator.pushNamed<T>(routeName, arguments: arguments);
  }

  /// Pop until a specific route
  static void popUntil(RoutePredicate predicate) {
    final navigator = NavigationService.navigator;
    if (navigator == null) {
      throw Exception(
        'Navigator not available. Make sure NavigationService.navigatorKey is assigned to MaterialApp.navigatorKey',
      );
    }
    navigator.popUntil(predicate);
  }

  /// Check if we can pop the current route
  static bool canPop() {
    final navigator = NavigationService.navigator;
    if (navigator == null) return false;
    return navigator.canPop();
  }
}
