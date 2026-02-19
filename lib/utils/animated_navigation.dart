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
import 'animations.dart';
import '../services/haptic_feedback_service.dart';

/// Navigation helper with Material Design 3 animated transitions
class AnimatedNavigation {
  static bool disableAnimations = false;

  static Future<T?> push<T>(
    BuildContext context,
    Widget page, {
    SharedAxisTransitionType transitionType =
        SharedAxisTransitionType.horizontal,
  }) {
    return Navigator.of(context).push<T>(
      AnimatedMaterialPageRoute<T>(
        builder: (context) => page,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return SharedAxisTransition(
            animation: animation,
            transitionType: transitionType,
            child: child,
          );
        },
      ),
    );
  }

  static Future<T?> pushFadeThrough<T>(BuildContext context, Widget page) {
    return Navigator.of(context).push<T>(
      AnimatedMaterialPageRoute<T>(
        builder: (context) => page,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeThroughTransition(animation: animation, child: child);
        },
      ),
    );
  }

  static Future<T?> pushContainerTransform<T>(
    BuildContext context,
    Widget page,
  ) {
    if (disableAnimations) {
      return Navigator.of(
        context,
      ).push<T>(MaterialPageRoute<T>(builder: (context) => page));
    }

    return Navigator.of(context).push<T>(
      AnimatedMaterialPageRoute<T>(
        builder: (context) => page,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return ContainerTransformTransition(
            animation: animation,
            child: child,
          );
        },
      ),
    );
  }

  static Future<T?> pushReplacement<T, TO>(
    BuildContext context,
    Widget page, {
    TO? result,
    SharedAxisTransitionType transitionType =
        SharedAxisTransitionType.horizontal,
  }) {
    return Navigator.of(context).pushReplacement<T, TO>(
      AnimatedMaterialPageRoute<T>(
        builder: (context) => page,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return SharedAxisTransition(
            animation: animation,
            transitionType: transitionType,
            child: child,
          );
        },
      ),
      result: result,
    );
  }

  /// Pop with default animation
  static void pop<T>(BuildContext context, [T? result]) {
    Navigator.of(context).pop(result);
  }

  /// Navigate to a named route with animated transition
  static Future<T?> pushNamed<T>(
    BuildContext context,
    String routeName, {
    Object? arguments,
  }) {
    return Navigator.of(context).pushNamed<T>(routeName, arguments: arguments);
  }
}

/// Modal dialog with Material Design 3 animations
class AnimatedDialog {
  /// Show a dialog with fade and scale animation
  static Future<T?> show<T>({
    required BuildContext context,
    required Widget child,
    bool barrierDismissible = true,
    Color? barrierColor,
    String? barrierLabel,
  }) {
    return showGeneralDialog<T>(
      context: context,
      barrierDismissible: barrierDismissible,
      barrierColor: barrierColor ?? Colors.black54,
      barrierLabel:
          barrierLabel ??
          MaterialLocalizations.of(context).modalBarrierDismissLabel,
      transitionDuration: AppAnimations.durationMedium2,
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: CurvedAnimation(
            parent: animation,
            curve: AppAnimations.emphasizedDecelerate,
          ),
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.8, end: 1.0).animate(
              CurvedAnimation(
                parent: animation,
                curve: AppAnimations.emphasized,
              ),
            ),
            child: child,
          ),
        );
      },
      pageBuilder: (context, animation, secondaryAnimation) {
        return child;
      },
    );
  }
}

/// Bottom sheet with Material Design 3 animations
class AnimatedBottomSheet {
  /// Show a modal bottom sheet with smooth slide animation
  static Future<T?> show<T>({
    required BuildContext context,
    required Widget child,
    bool isScrollControlled = false,
    bool isDismissible = true,
    bool enableDrag = true,
    Color? backgroundColor,
    double? elevation,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: isScrollControlled,
      isDismissible: isDismissible,
      enableDrag: enableDrag,
      backgroundColor: backgroundColor ?? Colors.transparent,
      elevation: elevation ?? 0,
      transitionAnimationController: _createBottomSheetController(context),
      builder: (context) => child,
    );
  }

  static AnimationController _createBottomSheetController(
    BuildContext context,
  ) {
    return BottomSheet.createAnimationController(Navigator.of(context))
      ..duration = AppAnimations.durationMedium3;
  }
}

/// Snackbar with smooth animations
class AnimatedSnackbar {
  /// Show a snackbar with Material Design 3 styling
  static void show(
    BuildContext context, {
    required String message,
    Duration duration = const Duration(milliseconds: 2500),
    SnackBarAction? action,
    Color? backgroundColor,
    Color? textColor,
    IconData? icon,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            if (icon != null) ...[
              Icon(icon, color: textColor ?? colorScheme.onInverseSurface),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  color: textColor ?? colorScheme.onInverseSurface,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: backgroundColor ?? colorScheme.inverseSurface,
        behavior: SnackBarBehavior.floating,
        duration: duration,
        action: action,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  /// Show a success snackbar
  static void success(
    BuildContext context, {
    required String message,
    Duration duration = const Duration(milliseconds: 2500),
  }) {
    HapticFeedbackService.success();
    show(
      context,
      message: message,
      duration: duration,
      icon: Icons.check_circle_outline,
      backgroundColor: Colors.green.shade700,
      textColor: Colors.white,
    );
  }

  /// Show an error snackbar
  static void error(
    BuildContext context, {
    required String message,
    Duration duration = const Duration(milliseconds: 2500),
  }) {
    HapticFeedbackService.error();
    show(
      context,
      message: message,
      duration: duration,
      icon: Icons.error_outline,
      backgroundColor: Colors.red.shade700,
      textColor: Colors.white,
    );
  }

  /// Show an info snackbar
  static void info(
    BuildContext context, {
    required String message,
    Duration duration = const Duration(milliseconds: 2500),
  }) {
    HapticFeedbackService.lightImpact();
    show(
      context,
      message: message,
      duration: duration,
      icon: Icons.info_outline,
    );
  }

  /// Show a warning snackbar
  static void warning(
    BuildContext context, {
    required String message,
    Duration duration = const Duration(milliseconds: 2500),
  }) {
    HapticFeedbackService.warning();
    show(
      context,
      message: message,
      duration: duration,
      icon: Icons.warning_amber_outlined,
      backgroundColor: Colors.orange.shade700,
      textColor: Colors.white,
    );
  }
}
