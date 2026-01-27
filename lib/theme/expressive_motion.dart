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
import 'package:flutter/physics.dart';
import 'package:vibration/vibration.dart';

/// Material 3 Expressive Motion Abstraction Layer (January 2026)
///
/// This module provides physics-based spring animations and haptic feedback
/// for a modern, expressive Material Design 3 experience.
///
/// Updated to use Flutter's built-in physics engine for real spring animations.

// ============================================================================
// Motion Spring Configuration
// ============================================================================

/// Configuration for physics-based spring animations (M3 Expressive)
///
/// M3 Expressive introduces motion physics springs to replace easing curves.
/// Two motion schemes are defined:
/// - Expressive: Overshoot/bounce for emotional impact
/// - Standard: Minimal bounce for functional apps
///
/// This is a placeholder until Flutter implements M3 Expressive springs.
class MotionSpringConfig {
  /// Spring stiffness (affects speed)
  final double stiffness;

  /// Spring damping ratio (affects bounce)
  /// - 0.0: No damping (infinite oscillation)
  /// - 1.0: Critical damping (no bounce)
  /// - < 1.0: Underdamped (bounce)
  final double dampingRatio;

  /// Initial velocity of the spring
  final double initialVelocity;

  const MotionSpringConfig({
    this.stiffness = 400.0,
    this.dampingRatio = 0.85,
    this.initialVelocity = 0.0,
  });

  /// Default spring for large animations (bottom sheets, navigation rail)
  static const MotionSpringConfig defaultSpring = MotionSpringConfig(
    stiffness: 400.0,
    dampingRatio: 0.85,
  );

  /// Fast spring for small components (switches, buttons, icons)
  static const MotionSpringConfig fastSpring = MotionSpringConfig(
    stiffness: 600.0,
    dampingRatio: 0.9,
  );

  /// Slow spring for full-screen transitions
  static const MotionSpringConfig slowSpring = MotionSpringConfig(
    stiffness: 250.0,
    dampingRatio: 0.8,
  );

  /// Expressive spring with overshoot (for emotional impact)
  static const MotionSpringConfig expressiveSpring = MotionSpringConfig(
    stiffness: 350.0,
    dampingRatio: 0.7, // Lower damping = more bounce
  );

  /// Standard spring without overshoot (for functional apps)
  static const MotionSpringConfig standardSpring = MotionSpringConfig(
    stiffness: 400.0,
    dampingRatio: 1.0, // Critical damping = no bounce
  );

  /// Convert to a physics-based spring curve
  /// Uses Flutter's SpringSimulation for real bouncy animations
  Curve toCurve() {
    // Create a spring description from our config
    final spring = SpringDescription(
      mass: 1.0,
      stiffness: stiffness,
      damping: dampingRatio * 2 * (stiffness).clamp(1.0, double.infinity).abs(),
    );

    // Return a custom spring curve
    return _SpringCurve(spring);
  }

  /// Get animation duration based on spring config
  /// Physics-based duration estimation
  Duration get approximateDuration {
    if (stiffness >= 500) {
      return const Duration(milliseconds: 250);
    } else if (stiffness >= 350) {
      return const Duration(milliseconds: 350);
    } else {
      return const Duration(milliseconds: 450);
    }
  }
}

/// Custom spring curve using Flutter's physics engine
class _SpringCurve extends Curve {
  final SpringDescription spring;

  const _SpringCurve(this.spring);

  @override
  double transformInternal(double t) {
    // Simulate spring from 0 to 1
    final simulation = SpringSimulation(spring, 0.0, 1.0, 0.0);
    return simulation.x(t * simulation.dx(0.0).abs().clamp(0.5, 2.0));
  }
}

// ============================================================================
// Shape Morphing
// ============================================================================

/// Shape morphing configuration for M3 Expressive
///
/// M3 Expressive introduces shape morphing - smooth transitions between
/// different shapes (e.g., button changes shape when pressed).
///
/// This is a placeholder until Flutter implements shape morphing.
class ShapeMorphConfig {
  /// Starting shape
  final ShapeBorder fromShape;

  /// Ending shape
  final ShapeBorder toShape;

  /// Spring configuration for the morph animation
  final MotionSpringConfig spring;

  const ShapeMorphConfig({
    required this.fromShape,
    required this.toShape,
    this.spring = MotionSpringConfig.defaultSpring,
  });

  /// Common morph: rounded rectangle to more rounded
  static ShapeMorphConfig roundedToMoreRounded({
    double fromRadius = 12.0,
    double toRadius = 16.0,
  }) {
    return ShapeMorphConfig(
      fromShape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(fromRadius),
      ),
      toShape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(toRadius),
      ),
    );
  }

  /// Common morph: rectangle to stadium (pill)
  static ShapeMorphConfig rectToStadium({double fromRadius = 12.0}) {
    return ShapeMorphConfig(
      fromShape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(fromRadius),
      ),
      toShape: const StadiumBorder(),
    );
  }
}

/// Mixin for widgets that support shape morphing
///
/// When Flutter implements M3 Expressive, this mixin will provide
/// real shape morphing capabilities. For now, it's a no-op.
mixin ShapeMorphingMixin<T extends StatefulWidget> on State<T> {
  ShapeBorder? _currentShape;
  ShapeBorder? _targetShape;

  /// Get the current (possibly animated) shape
  ShapeBorder get currentShape =>
      _currentShape ??
      _targetShape ??
      RoundedRectangleBorder(borderRadius: BorderRadius.circular(12));

  /// Morph to a new shape
  void morphTo(ShapeBorder newShape, {MotionSpringConfig? spring}) {
    // In M3 Expressive, this would animate the shape change
    // For now, we just set the shape directly
    setState(() {
      _currentShape = newShape;
      _targetShape = newShape;
    });
  }

  /// Reset shape to default
  void resetShape(ShapeBorder defaultShape) {
    setState(() {
      _currentShape = defaultShape;
      _targetShape = defaultShape;
    });
  }
}

// ============================================================================
// Button States with Shape Morphing
// ============================================================================

/// Button state configuration for M3 Expressive
///
/// M3 Expressive buttons can change shape based on interaction state.
class ExpressiveButtonState {
  /// Shape when button is in default state
  final ShapeBorder defaultShape;

  /// Shape when button is hovered
  final ShapeBorder? hoveredShape;

  /// Shape when button is focused
  final ShapeBorder? focusedShape;

  /// Shape when button is pressed
  final ShapeBorder? pressedShape;

  /// Shape when button is selected (for toggle buttons)
  final ShapeBorder? selectedShape;

  const ExpressiveButtonState({
    required this.defaultShape,
    this.hoveredShape,
    this.focusedShape,
    this.pressedShape,
    this.selectedShape,
  });

  /// Get shape for current state
  ShapeBorder getShapeForState({
    bool isHovered = false,
    bool isFocused = false,
    bool isPressed = false,
    bool isSelected = false,
  }) {
    if (isPressed && pressedShape != null) return pressedShape!;
    if (isSelected && selectedShape != null) return selectedShape!;
    if (isFocused && focusedShape != null) return focusedShape!;
    if (isHovered && hoveredShape != null) return hoveredShape!;
    return defaultShape;
  }

  /// Standard M3 button configuration
  static ExpressiveButtonState standard({double baseRadius = 12.0}) {
    return ExpressiveButtonState(
      defaultShape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(baseRadius),
      ),
      pressedShape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(baseRadius + 4),
      ),
    );
  }

  /// FAB configuration with shape morphing
  static ExpressiveButtonState fab({double baseRadius = 16.0}) {
    return ExpressiveButtonState(
      defaultShape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(baseRadius),
      ),
      pressedShape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(baseRadius + 8),
      ),
      hoveredShape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(baseRadius + 4),
      ),
    );
  }
}

// ============================================================================
// Motion Scheme
// ============================================================================

/// Motion scheme for the app (M3 Expressive)
///
/// Two schemes are available:
/// - Expressive: Bouncy, emotional animations
/// - Standard: Smooth, functional animations
enum MotionScheme {
  /// Expressive motion with overshoot/bounce
  expressive,

  /// Standard motion without overshoot
  standard,
}

/// Provider for motion scheme
///
/// This will integrate with the theme system when M3 Expressive is available.
class MotionSchemeProvider {
  static MotionScheme _currentScheme = MotionScheme.standard;

  /// Get current motion scheme
  static MotionScheme get current => _currentScheme;

  /// Set motion scheme
  static void setScheme(MotionScheme scheme) {
    _currentScheme = scheme;
  }

  /// Get spring config for current scheme
  static MotionSpringConfig getSpatialSpring() {
    return _currentScheme == MotionScheme.expressive
        ? MotionSpringConfig.expressiveSpring
        : MotionSpringConfig.standardSpring;
  }

  /// Get effects spring (for opacity/color changes)
  static MotionSpringConfig getEffectsSpring() {
    // Effects springs don't overshoot even in expressive mode
    return MotionSpringConfig.standardSpring;
  }

  /// Get animation curve for current scheme
  static Curve getCurve() {
    return getSpatialSpring().toCurve();
  }

  /// Get animation duration for current scheme
  static Duration getDuration() {
    return getSpatialSpring().approximateDuration;
  }
}

// ============================================================================
// Future-Proofing Notes
// ============================================================================

/// When Flutter implements M3 Expressive (expected 2026-2027):
///
/// 1. MotionSpringConfig will map to Flutter's physics-based animation system
/// 2. ShapeMorphConfig will use Flutter's shape interpolation
/// 3. ExpressiveButtonState will integrate with MaterialStateProperty
/// 4. MotionSchemeProvider will integrate with ThemeData
///
/// Migration path:
/// 1. Update MotionSpringConfig.toCurve() to return real spring curves
/// 2. Update ShapeMorphingMixin to use Flutter's animation controllers
/// 3. Update button themes to use ExpressiveButtonState
/// 4. Add motion scheme to ThemeData extensions

// ============================================================================
// Haptic Feedback Service
// ============================================================================

/// Haptic feedback utility for Material 3 expressive interactions
///
/// Provides consistent haptic feedback across all interactive elements
/// to enhance the tactile experience of the app.
class ExpressiveHaptics {
  /// Light haptic feedback for taps on buttons, list items, cards
  ///
  /// Set [enabled] to false to skip vibration. Defaults to true.
  static void lightTap({bool enabled = true}) {
    if (!enabled) return;
    // Subtle vibration for button presses
    Vibration.vibrate(duration: 10);
  }

  /// Medium haptic feedback for important interactions
  static void mediumTap({bool enabled = true}) {
    if (!enabled) return;
    Vibration.vibrate(duration: 100);
  }

  /// Heavy haptic feedback for significant actions
  static void heavyTap({bool enabled = true}) {
    if (!enabled) return;
    Vibration.vibrate(duration: 200);
  }

  /// Selection changed feedback (e.g., picker, dropdown)
  static void selectionChanged({bool enabled = true}) {
    if (!enabled) return;
    Vibration.vibrate(duration: 30);
  }

  /// Success feedback after completing an action
  static void success({bool enabled = true}) {
    if (!enabled) return;
    Vibration.vibrate(duration: 150);
  }

  /// Error feedback for failed actions
  static void error({bool enabled = true}) {
    if (!enabled) return;
    Vibration.vibrate(duration: 300);
  }

  /// Vibrate for attention (e.g., long press activated)
  static void vibrate({bool enabled = true}) {
    if (!enabled) return;
    Vibration.vibrate(duration: 100);
  }
}

// ============================================================================
// Animated Scale Widget
// ============================================================================

/// A widget that provides springy scale animation on tap
///
/// Wraps any child widget to add a press animation with haptic feedback.
class ExpressiveTapScale extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double pressedScale;
  final bool enableHaptics;
  final MotionSpringConfig springConfig;

  const ExpressiveTapScale({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.pressedScale = 0.97,
    this.enableHaptics = true,
    this.springConfig = MotionSpringConfig.standardSpring,
  });

  @override
  State<ExpressiveTapScale> createState() => _ExpressiveTapScaleState();
}

class _ExpressiveTapScaleState extends State<ExpressiveTapScale>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.springConfig.approximateDuration,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: widget.pressedScale)
        .animate(
          CurvedAnimation(
            parent: _controller,
            curve: widget.springConfig.toCurve(),
          ),
        );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) {
    _controller.forward();
    if (widget.enableHaptics) {
      ExpressiveHaptics.lightTap();
    }
  }

  void _onTapUp(TapUpDetails details) {
    _controller.reverse();
  }

  void _onTapCancel() {
    _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      onTap: widget.onTap,
      onLongPress: widget.onLongPress != null
          ? () {
              if (widget.enableHaptics) {
                ExpressiveHaptics.mediumTap();
              }
              widget.onLongPress?.call();
            }
          : null,
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(scale: _scaleAnimation.value, child: child);
        },
        child: widget.child,
      ),
    );
  }
}

// ============================================================================
// Expressive Page Transitions
// ============================================================================

/// Material 3 expressive page route with spring-based transitions
class ExpressivePageRoute<T> extends PageRouteBuilder<T> {
  final Widget page;
  final MotionSpringConfig springConfig;

  ExpressivePageRoute({
    required this.page,
    this.springConfig = MotionSpringConfig.defaultSpring,
    super.settings,
  }) : super(
         pageBuilder: (context, animation, secondaryAnimation) => page,
         transitionDuration: springConfig.approximateDuration,
         reverseTransitionDuration: springConfig.approximateDuration,
         transitionsBuilder: (context, animation, secondaryAnimation, child) {
           final curvedAnimation = CurvedAnimation(
             parent: animation,
             curve: springConfig.toCurve(),
           );

           return FadeTransition(
             opacity: Tween<double>(
               begin: 0.0,
               end: 1.0,
             ).animate(curvedAnimation),
             child: SlideTransition(
               position: Tween<Offset>(
                 begin: const Offset(0.0, 0.05),
                 end: Offset.zero,
               ).animate(curvedAnimation),
               child: child,
             ),
           );
         },
       );
}

/// Shared axis transition for navigation within the same hierarchy
class ExpressiveSharedAxisRoute<T> extends PageRouteBuilder<T> {
  final Widget page;
  final SharedAxisTransitionType type;

  ExpressiveSharedAxisRoute({
    required this.page,
    this.type = SharedAxisTransitionType.horizontal,
    super.settings,
  }) : super(
         pageBuilder: (context, animation, secondaryAnimation) => page,
         transitionDuration: const Duration(milliseconds: 350),
         reverseTransitionDuration: const Duration(milliseconds: 350),
         transitionsBuilder: (context, animation, secondaryAnimation, child) {
           return SharedAxisTransition(
             animation: animation,
             secondaryAnimation: secondaryAnimation,
             transitionType: type,
             child: child,
           );
         },
       );
}

/// Shared axis transition type
enum SharedAxisTransitionType { horizontal, vertical, scaled }

/// Shared axis transition widget
class SharedAxisTransition extends StatelessWidget {
  final Animation<double> animation;
  final Animation<double> secondaryAnimation;
  final SharedAxisTransitionType transitionType;
  final Widget child;

  const SharedAxisTransition({
    super.key,
    required this.animation,
    required this.secondaryAnimation,
    required this.transitionType,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final fadeIn = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: animation, curve: const Interval(0.3, 1.0)),
    );
    final fadeOut = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: secondaryAnimation,
        curve: const Interval(0.0, 0.3),
      ),
    );

    Offset beginOffset;
    switch (transitionType) {
      case SharedAxisTransitionType.horizontal:
        beginOffset = const Offset(0.1, 0.0);
        break;
      case SharedAxisTransitionType.vertical:
        beginOffset = const Offset(0.0, 0.1);
        break;
      case SharedAxisTransitionType.scaled:
        beginOffset = Offset.zero;
        break;
    }

    final slideIn = Tween<Offset>(
      begin: beginOffset,
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic));

    return FadeTransition(
      opacity: fadeIn,
      child: FadeTransition(
        opacity: fadeOut,
        child: SlideTransition(
          position: slideIn,
          child: transitionType == SharedAxisTransitionType.scaled
              ? ScaleTransition(
                  scale: Tween<double>(begin: 0.95, end: 1.0).animate(
                    CurvedAnimation(
                      parent: animation,
                      curve: Curves.easeOutCubic,
                    ),
                  ),
                  child: child,
                )
              : child,
        ),
      ),
    );
  }
}
