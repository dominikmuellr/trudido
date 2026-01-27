import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../theme/expressive_motion.dart';
import '../../providers/app_providers.dart';

/// A wrapped version of common button widgets with ExpressiveTapScale
/// for springy animations and haptic feedback throughout the app.

class ExpressiveIconButton extends ConsumerWidget {
  final VoidCallback? onPressed;
  final Widget icon;
  final String? tooltip;
  final Color? color;
  final double? iconSize;
  final EdgeInsetsGeometry padding;
  final AlignmentGeometry alignment;
  final BoxConstraints? constraints;
  final VisualDensity? visualDensity;
  final ButtonStyle? style;

  const ExpressiveIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.tooltip,
    this.color,
    this.iconSize,
    this.padding = const EdgeInsets.all(8.0),
    this.alignment = Alignment.center,
    this.constraints,
    this.visualDensity,
    this.style,
  });

  // Forward static methods from IconButton
  static ButtonStyle styleFrom({
    Color? foregroundColor,
    Color? backgroundColor,
    Color? disabledForegroundColor,
    Color? disabledBackgroundColor,
    Color? shadowColor,
    Color? surfaceTintColor,
    double? elevation,
    EdgeInsetsGeometry? padding,
    Size? minimumSize,
    Size? fixedSize,
    Size? maximumSize,
    BorderSide? side,
    OutlinedBorder? shape,
    MouseCursor? enabledMouseCursor,
    MouseCursor? disabledMouseCursor,
    VisualDensity? visualDensity,
    MaterialTapTargetSize? tapTargetSize,
    Duration? animationDuration,
    bool? enableFeedback,
    AlignmentGeometry? alignment,
    InteractiveInkFeatureFactory? splashFactory,
  }) {
    return IconButton.styleFrom(
      foregroundColor: foregroundColor,
      backgroundColor: backgroundColor,
      disabledForegroundColor: disabledForegroundColor,
      disabledBackgroundColor: disabledBackgroundColor,
      shadowColor: shadowColor,
      surfaceTintColor: surfaceTintColor,
      elevation: elevation,
      padding: padding,
      minimumSize: minimumSize,
      fixedSize: fixedSize,
      maximumSize: maximumSize,
      side: side,
      shape: shape,
      enabledMouseCursor: enabledMouseCursor,
      disabledMouseCursor: disabledMouseCursor,
      visualDensity: visualDensity,
      tapTargetSize: tapTargetSize,
      animationDuration: animationDuration,
      enableFeedback: enableFeedback,
      alignment: alignment,
      splashFactory: splashFactory,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hapticsEnabled = ref.watch(preferencesStateProvider).hapticsEnabled;
    return Listener(
      onPointerDown: (_) {
        if (onPressed != null) {
          ExpressiveHaptics.lightTap(enabled: hapticsEnabled);
        }
      },
      child: IconButton(
        icon: icon,
        onPressed: onPressed,
        tooltip: tooltip,
        color: color,
        iconSize: iconSize,
        padding: padding,
        alignment: alignment,
        constraints: constraints,
        visualDensity: visualDensity,
        style: style,
      ),
    );
  }
}

class ExpressiveTextButton extends ConsumerWidget {
  final VoidCallback? onPressed;
  final Widget child;
  final ButtonStyle? style;
  final Widget? icon;

  const ExpressiveTextButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.style,
  }) : icon = null;

  const ExpressiveTextButton.icon({
    super.key,
    required this.onPressed,
    required Widget icon,
    required Widget label,
    this.style,
  }) : child = label,
       icon = icon;

  // Forward static methods from TextButton
  static ButtonStyle styleFrom({
    Color? foregroundColor,
    Color? backgroundColor,
    Color? disabledForegroundColor,
    Color? disabledBackgroundColor,
    Color? shadowColor,
    Color? surfaceTintColor,
    double? elevation,
    TextStyle? textStyle,
    EdgeInsetsGeometry? padding,
    Size? minimumSize,
    Size? fixedSize,
    Size? maximumSize,
    BorderSide? side,
    OutlinedBorder? shape,
    MouseCursor? enabledMouseCursor,
    MouseCursor? disabledMouseCursor,
    VisualDensity? visualDensity,
    MaterialTapTargetSize? tapTargetSize,
    Duration? animationDuration,
    bool? enableFeedback,
    AlignmentGeometry? alignment,
    InteractiveInkFeatureFactory? splashFactory,
  }) {
    return TextButton.styleFrom(
      foregroundColor: foregroundColor,
      backgroundColor: backgroundColor,
      disabledForegroundColor: disabledForegroundColor,
      disabledBackgroundColor: disabledBackgroundColor,
      shadowColor: shadowColor,
      surfaceTintColor: surfaceTintColor,
      elevation: elevation,
      textStyle: textStyle,
      padding: padding,
      minimumSize: minimumSize,
      fixedSize: fixedSize,
      maximumSize: maximumSize,
      side: side,
      shape: shape,
      enabledMouseCursor: enabledMouseCursor,
      disabledMouseCursor: disabledMouseCursor,
      visualDensity: visualDensity,
      tapTargetSize: tapTargetSize,
      animationDuration: animationDuration,
      enableFeedback: enableFeedback,
      alignment: alignment,
      splashFactory: splashFactory,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hapticsEnabled = ref.watch(preferencesStateProvider).hapticsEnabled;
    return Listener(
      onPointerDown: (_) {
        if (onPressed != null) {
          ExpressiveHaptics.lightTap(enabled: hapticsEnabled);
        }
      },
      child: icon != null
          ? TextButton.icon(
              onPressed: onPressed,
              icon: icon!,
              label: child,
              style: style,
            )
          : TextButton(onPressed: onPressed, style: style, child: child),
    );
  }
}

class ExpressiveElevatedButton extends ConsumerWidget {
  final VoidCallback? onPressed;
  final Widget child;
  final ButtonStyle? style;
  final Widget? icon;

  const ExpressiveElevatedButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.style,
  }) : icon = null;

  const ExpressiveElevatedButton.icon({
    super.key,
    required this.onPressed,
    required Widget icon,
    required Widget label,
    this.style,
  }) : child = label,
       icon = icon;

  // Forward static methods from ElevatedButton
  static ButtonStyle styleFrom({
    Color? foregroundColor,
    Color? backgroundColor,
    Color? disabledForegroundColor,
    Color? disabledBackgroundColor,
    Color? shadowColor,
    Color? surfaceTintColor,
    double? elevation,
    TextStyle? textStyle,
    EdgeInsetsGeometry? padding,
    Size? minimumSize,
    Size? fixedSize,
    Size? maximumSize,
    BorderSide? side,
    OutlinedBorder? shape,
    MouseCursor? enabledMouseCursor,
    MouseCursor? disabledMouseCursor,
    VisualDensity? visualDensity,
    MaterialTapTargetSize? tapTargetSize,
    Duration? animationDuration,
    bool? enableFeedback,
    AlignmentGeometry? alignment,
    InteractiveInkFeatureFactory? splashFactory,
  }) {
    return ElevatedButton.styleFrom(
      foregroundColor: foregroundColor,
      backgroundColor: backgroundColor,
      disabledForegroundColor: disabledForegroundColor,
      disabledBackgroundColor: disabledBackgroundColor,
      shadowColor: shadowColor,
      surfaceTintColor: surfaceTintColor,
      elevation: elevation,
      textStyle: textStyle,
      padding: padding,
      minimumSize: minimumSize,
      fixedSize: fixedSize,
      maximumSize: maximumSize,
      side: side,
      shape: shape,
      enabledMouseCursor: enabledMouseCursor,
      disabledMouseCursor: disabledMouseCursor,
      visualDensity: visualDensity,
      tapTargetSize: tapTargetSize,
      animationDuration: animationDuration,
      enableFeedback: enableFeedback,
      alignment: alignment,
      splashFactory: splashFactory,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hapticsEnabled = ref.watch(preferencesStateProvider).hapticsEnabled;
    return Listener(
      onPointerDown: (_) {
        if (onPressed != null) {
          ExpressiveHaptics.lightTap(enabled: hapticsEnabled);
        }
      },
      child: icon != null
          ? ElevatedButton.icon(
              onPressed: onPressed,
              icon: icon!,
              label: child,
              style: style,
            )
          : ElevatedButton(onPressed: onPressed, style: style, child: child),
    );
  }
}

class ExpressiveOutlinedButton extends ConsumerWidget {
  final VoidCallback? onPressed;
  final Widget child;
  final ButtonStyle? style;
  final Widget? icon;

  const ExpressiveOutlinedButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.style,
  }) : icon = null;

  const ExpressiveOutlinedButton.icon({
    super.key,
    required this.onPressed,
    required Widget icon,
    required Widget label,
    this.style,
  }) : child = label,
       icon = icon;

  // Forward static methods from OutlinedButton
  static ButtonStyle styleFrom({
    Color? foregroundColor,
    Color? backgroundColor,
    Color? disabledForegroundColor,
    Color? disabledBackgroundColor,
    Color? shadowColor,
    Color? surfaceTintColor,
    double? elevation,
    TextStyle? textStyle,
    EdgeInsetsGeometry? padding,
    Size? minimumSize,
    Size? fixedSize,
    Size? maximumSize,
    BorderSide? side,
    OutlinedBorder? shape,
    MouseCursor? enabledMouseCursor,
    MouseCursor? disabledMouseCursor,
    VisualDensity? visualDensity,
    MaterialTapTargetSize? tapTargetSize,
    Duration? animationDuration,
    bool? enableFeedback,
    AlignmentGeometry? alignment,
    InteractiveInkFeatureFactory? splashFactory,
  }) {
    return OutlinedButton.styleFrom(
      foregroundColor: foregroundColor,
      backgroundColor: backgroundColor,
      disabledForegroundColor: disabledForegroundColor,
      disabledBackgroundColor: disabledBackgroundColor,
      shadowColor: shadowColor,
      surfaceTintColor: surfaceTintColor,
      elevation: elevation,
      textStyle: textStyle,
      padding: padding,
      minimumSize: minimumSize,
      fixedSize: fixedSize,
      maximumSize: maximumSize,
      side: side,
      shape: shape,
      enabledMouseCursor: enabledMouseCursor,
      disabledMouseCursor: disabledMouseCursor,
      visualDensity: visualDensity,
      tapTargetSize: tapTargetSize,
      animationDuration: animationDuration,
      enableFeedback: enableFeedback,
      alignment: alignment,
      splashFactory: splashFactory,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hapticsEnabled = ref.watch(preferencesStateProvider).hapticsEnabled;
    return Listener(
      onPointerDown: (_) {
        if (onPressed != null) {
          ExpressiveHaptics.lightTap(enabled: hapticsEnabled);
        }
      },
      child: icon != null
          ? OutlinedButton.icon(
              onPressed: onPressed,
              icon: icon!,
              label: child,
              style: style,
            )
          : OutlinedButton(onPressed: onPressed, style: style, child: child),
    );
  }
}

class ExpressiveFloatingActionButton extends ConsumerWidget {
  final VoidCallback? onPressed;
  final Widget? child;
  final String? tooltip;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final Object? heroTag;
  final double? elevation;
  final double? highlightElevation;
  final ShapeBorder? shape;
  final Widget? label;
  final Widget? icon;
  final bool isExtended;
  final bool isSmall;

  const ExpressiveFloatingActionButton({
    super.key,
    required this.onPressed,
    this.child,
    this.tooltip,
    this.backgroundColor,
    this.foregroundColor,
    this.heroTag,
    this.elevation,
    this.highlightElevation,
    this.shape,
  }) : label = null,
       icon = null,
       isExtended = false,
       isSmall = false;

  const ExpressiveFloatingActionButton.extended({
    super.key,
    required this.onPressed,
    required Widget label,
    Widget? icon,
    this.tooltip,
    this.backgroundColor,
    this.foregroundColor,
    this.heroTag,
    this.elevation,
    this.highlightElevation,
    this.shape,
  }) : child = null,
       label = label,
       icon = icon,
       isExtended = true,
       isSmall = false;

  const ExpressiveFloatingActionButton.small({
    super.key,
    required this.onPressed,
    this.child,
    this.tooltip,
    this.backgroundColor,
    this.foregroundColor,
    this.heroTag,
    this.elevation,
    this.highlightElevation,
    this.shape,
  }) : label = null,
       icon = null,
       isExtended = false,
       isSmall = true;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hapticsEnabled = ref.watch(preferencesStateProvider).hapticsEnabled;
    return Listener(
      onPointerDown: (_) {
        if (onPressed != null) {
          ExpressiveHaptics.lightTap(enabled: hapticsEnabled);
        }
      },
      child: isExtended
          ? FloatingActionButton.extended(
              onPressed: onPressed,
              label: label!,
              icon: icon,
              tooltip: tooltip,
              backgroundColor: backgroundColor,
              foregroundColor: foregroundColor,
              heroTag: heroTag,
              elevation: elevation,
              shape: shape,
            )
          : isSmall
          ? FloatingActionButton.small(
              onPressed: onPressed,
              tooltip: tooltip,
              backgroundColor: backgroundColor,
              foregroundColor: foregroundColor,
              heroTag: heroTag,
              elevation: elevation,
              shape: shape,
              child: child,
            )
          : FloatingActionButton(
              onPressed: onPressed,
              tooltip: tooltip,
              backgroundColor: backgroundColor,
              foregroundColor: foregroundColor,
              heroTag: heroTag,
              elevation: elevation,
              shape: shape,
              child: child,
            ),
    );
  }
}

class ExpressiveInkWell extends ConsumerWidget {
  final VoidCallback? onTap;
  final Widget child;
  final BorderRadius? borderRadius;
  final Color? splashColor;
  final Color? highlightColor;
  final GestureTapDownCallback? onTapDown;
  final GestureTapUpCallback? onTapUp;
  final GestureTapCancelCallback? onTapCancel;
  final GestureLongPressCallback? onLongPress;
  final bool enableHaptics;

  const ExpressiveInkWell({
    super.key,
    this.onTap,
    required this.child,
    this.borderRadius,
    this.splashColor,
    this.highlightColor,
    this.onTapDown,
    this.onTapUp,
    this.onTapCancel,
    this.onLongPress,
    this.enableHaptics = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hapticsEnabled = ref.watch(preferencesStateProvider).hapticsEnabled;
    return Listener(
      onPointerDown: (_) {
        if (onTap != null && enableHaptics) {
          ExpressiveHaptics.lightTap(enabled: hapticsEnabled);
        }
      },
      child: InkWell(
        onTap: onTap,
        borderRadius: borderRadius,
        splashColor: splashColor,
        highlightColor: highlightColor,
        onTapDown: onTapDown,
        onTapUp: onTapUp,
        onTapCancel: onTapCancel,
        onLongPress: onLongPress,
        child: child,
      ),
    );
  }
}

class ExpressiveGestureDetector extends ConsumerWidget {
  final VoidCallback? onTap;
  final Widget child;
  final GestureTapDownCallback? onTapDown;
  final GestureTapUpCallback? onTapUp;
  final GestureTapCancelCallback? onTapCancel;
  final GestureLongPressCallback? onLongPress;
  final GestureDoubleTapCallback? onDoubleTap;
  final GestureDragUpdateCallback? onVerticalDragUpdate;
  final GestureDragUpdateCallback? onPanUpdate;
  final GestureDragStartCallback? onPanStart;
  final HitTestBehavior? behavior;
  final bool enableHaptics;

  const ExpressiveGestureDetector({
    super.key,
    this.onTap,
    required this.child,
    this.onTapDown,
    this.onTapUp,
    this.onTapCancel,
    this.onLongPress,
    this.onDoubleTap,
    this.onVerticalDragUpdate,
    this.onPanUpdate,
    this.onPanStart,
    this.behavior,
    this.enableHaptics = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hapticsEnabled = ref.watch(preferencesStateProvider).hapticsEnabled;
    return Listener(
      onPointerDown: (_) {
        if (onTap != null && enableHaptics) {
          ExpressiveHaptics.lightTap(enabled: hapticsEnabled);
        }
      },
      child: GestureDetector(
        onTap: onTap,
        onTapDown: onTapDown,
        onTapUp: onTapUp,
        onTapCancel: onTapCancel,
        onLongPress: onLongPress,
        onDoubleTap: onDoubleTap,
        onVerticalDragUpdate: onVerticalDragUpdate,
        onPanUpdate: onPanUpdate,
        onPanStart: onPanStart,
        behavior: behavior,
        child: child,
      ),
    );
  }
}
