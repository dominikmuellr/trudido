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

/// Material 3 Expressive Motion Abstraction Layer (January 2026)
///
/// This module provides interfaces and no-op implementations for M3 Expressive
/// features that are not yet available in Flutter. When Flutter implements
/// M3 Expressive (physics-based springs, shape morphing, etc.), this layer
/// can be updated to use the real implementations.
///
/// Current status (January 2026):
/// - Flutter: Original M3 components only
/// - M3 Expressive: Available in Jetpack Compose / MDC-Android
/// - This layer: Provides fallback implementations

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

  /// Convert to Flutter's SpringDescription (when available)
  /// For now, returns a placeholder curve
  Curve toCurve() {
    // When Flutter implements M3 Expressive springs, this will return
    // a proper physics-based curve. For now, approximate with easing.
    if (dampingRatio >= 1.0) {
      return Curves.easeOutCubic;
    } else if (dampingRatio >= 0.85) {
      return Curves.easeOutBack;
    } else {
      return Curves.elasticOut;
    }
  }

  /// Get animation duration based on spring config
  /// In real M3 Expressive, duration is determined by physics
  Duration get approximateDuration {
    if (stiffness >= 500) {
      return const Duration(milliseconds: 200);
    } else if (stiffness >= 350) {
      return const Duration(milliseconds: 300);
    } else {
      return const Duration(milliseconds: 400);
    }
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
