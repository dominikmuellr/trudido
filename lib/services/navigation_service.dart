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
