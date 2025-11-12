import 'package:flutter/material.dart';

/// Material Design 3 Animation Constants
/// Based on Material Design motion guidelines - Optimized for speed
class AppAnimations {
  // Duration constants following Material Design 3 - Faster for snappier feel
  static const Duration durationShort1 = Duration(milliseconds: 50);
  static const Duration durationShort2 = Duration(milliseconds: 75);
  static const Duration durationShort3 = Duration(milliseconds: 100);
  static const Duration durationShort4 = Duration(milliseconds: 125);
  static const Duration durationMedium1 = Duration(milliseconds: 150);
  static const Duration durationMedium2 = Duration(milliseconds: 175);
  static const Duration durationMedium3 = Duration(milliseconds: 200);
  static const Duration durationMedium4 = Duration(milliseconds: 225);
  static const Duration durationLong1 = Duration(milliseconds: 250);
  static const Duration durationLong2 = Duration(milliseconds: 275);
  static const Duration durationLong3 = Duration(milliseconds: 300);
  static const Duration durationLong4 = Duration(milliseconds: 325);
  static const Duration durationExtraLong1 = Duration(milliseconds: 350);
  static const Duration durationExtraLong2 = Duration(milliseconds: 400);
  static const Duration durationExtraLong3 = Duration(milliseconds: 450);
  static const Duration durationExtraLong4 = Duration(milliseconds: 500);

  // Material Design 3 Easing curves
  static const Curve emphasized = Curves.easeInOutCubicEmphasized;
  static const Curve emphasizedDecelerate = Curves.easeOutCubic;
  static const Curve emphasizedAccelerate = Curves.easeInCubic;
  static const Curve standard = Curves.easeInOut;
  static const Curve standardDecelerate = Curves.easeOut;
  static const Curve standardAccelerate = Curves.easeIn;

  // Preset animation configurations
  static const AnimationConfig fadeIn = AnimationConfig(
    duration: durationMedium2,
    curve: emphasizedDecelerate,
  );

  static const AnimationConfig fadeOut = AnimationConfig(
    duration: durationShort4,
    curve: emphasizedAccelerate,
  );

  static const AnimationConfig slideIn = AnimationConfig(
    duration: durationMedium3,
    curve: emphasized,
  );

  static const AnimationConfig slideOut = AnimationConfig(
    duration: durationMedium2,
    curve: emphasizedAccelerate,
  );

  static const AnimationConfig scale = AnimationConfig(
    duration: durationMedium2,
    curve: emphasized,
  );

  static const AnimationConfig sharedAxis = AnimationConfig(
    duration: durationMedium4,
    curve: emphasized,
  );

  static const AnimationConfig fadeThrough = AnimationConfig(
    duration: durationMedium2,
    curve: emphasized,
  );
}

/// Animation configuration holder
class AnimationConfig {
  final Duration duration;
  final Curve curve;

  const AnimationConfig({required this.duration, required this.curve});
}

/// Material Design 3 Shared Axis Transition
/// For navigating between peer screens
class SharedAxisTransition extends StatelessWidget {
  final Widget child;
  final Animation<double> animation;
  final SharedAxisTransitionType transitionType;
  final bool fillColor;

  const SharedAxisTransition({
    super.key,
    required this.child,
    required this.animation,
    this.transitionType = SharedAxisTransitionType.horizontal,
    this.fillColor = true,
  });

  @override
  Widget build(BuildContext context) {
    final offsetAnimation =
        Tween<Offset>(
          begin: transitionType == SharedAxisTransitionType.horizontal
              ? const Offset(0.3, 0.0)
              : const Offset(0.0, 0.3),
          end: Offset.zero,
        ).animate(
          CurvedAnimation(parent: animation, curve: AppAnimations.emphasized),
        );

    final fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: animation,
        curve: const Interval(
          0.3,
          1.0,
          curve: AppAnimations.standardDecelerate,
        ),
      ),
    );

    return FadeTransition(
      opacity: fadeAnimation,
      child: SlideTransition(position: offsetAnimation, child: child),
    );
  }
}

enum SharedAxisTransitionType { horizontal, vertical, scaled }

/// Material Design 3 Fade Through Transition
/// For transitions where the entire screen content changes
class FadeThroughTransition extends StatelessWidget {
  final Widget child;
  final Animation<double> animation;

  const FadeThroughTransition({
    super.key,
    required this.child,
    required this.animation,
  });

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(
          parent: animation,
          curve: const Interval(
            0.35,
            1.0,
            curve: AppAnimations.standardDecelerate,
          ),
        ),
      ),
      child: ScaleTransition(
        scale: Tween<double>(begin: 0.92, end: 1.0).animate(
          CurvedAnimation(parent: animation, curve: AppAnimations.emphasized),
        ),
        child: child,
      ),
    );
  }
}

/// Material Design 3 Container Transform
/// For expanding a widget to fill the screen
class ContainerTransformTransition extends StatelessWidget {
  final Widget child;
  final Animation<double> animation;

  const ContainerTransformTransition({
    super.key,
    required this.child,
    required this.animation,
  });

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: CurvedAnimation(
        parent: animation,
        curve: const Interval(
          0.0,
          0.3,
          curve: AppAnimations.standardDecelerate,
        ),
        reverseCurve: const Interval(
          0.7,
          1.0,
          curve: AppAnimations.standardAccelerate,
        ),
      ),
      child: ScaleTransition(
        scale: Tween<double>(begin: 0.8, end: 1.0).animate(
          CurvedAnimation(parent: animation, curve: AppAnimations.emphasized),
        ),
        child: child,
      ),
    );
  }
}

/// Custom page route with Material Design 3 transitions
class AnimatedMaterialPageRoute<T> extends PageRoute<T> {
  final WidgetBuilder builder;
  final RouteTransitionsBuilder? transitionsBuilder;

  AnimatedMaterialPageRoute({
    required this.builder,
    this.transitionsBuilder,
    RouteSettings? settings,
  }) : super(settings: settings);

  @override
  Color? get barrierColor => null;

  @override
  String? get barrierLabel => null;

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    return builder(context);
  }

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (transitionsBuilder != null) {
      return transitionsBuilder!(context, animation, secondaryAnimation, child);
    }
    return SharedAxisTransition(animation: animation, child: child);
  }

  @override
  bool get maintainState => true;

  @override
  Duration get transitionDuration => AppAnimations.durationMedium4;

  @override
  Duration get reverseTransitionDuration => AppAnimations.durationMedium2;
}

/// Staggered animation helper for lists
class StaggeredListAnimation extends StatelessWidget {
  final Widget child;
  final int index;
  final Animation<double> animation;
  final Duration delay;
  final Curve curve;
  final Duration totalDuration;

  const StaggeredListAnimation({
    super.key,
    required this.child,
    required this.index,
    required this.animation,
    this.delay = const Duration(milliseconds: 50),
    this.curve = AppAnimations.emphasized,
    this.totalDuration = AppAnimations.durationMedium4,
  });

  @override
  Widget build(BuildContext context) {
    final itemDelay = delay.inMilliseconds * index;
    final total = totalDuration.inMilliseconds;
    final start = (itemDelay / total).clamp(0.0, 1.0);
    final end = ((itemDelay + 200) / total).clamp(start, 1.0);

    return FadeTransition(
      opacity: Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(
          parent: animation,
          curve: Interval(start, end, curve: curve),
        ),
      ),
      child: SlideTransition(
        position: Tween<Offset>(begin: const Offset(0.0, 0.3), end: Offset.zero)
            .animate(
              CurvedAnimation(
                parent: animation,
                curve: Interval(start, end, curve: curve),
              ),
            ),
        child: child,
      ),
    );
  }
}

/// Animated list item with micro-interactions
class AnimatedListItem extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final Duration duration;

  const AnimatedListItem({
    super.key,
    required this.child,
    this.onTap,
    this.duration = AppAnimations.durationShort4,
  });

  @override
  State<AnimatedListItem> createState() => _AnimatedListItemState();
}

class _AnimatedListItemState extends State<AnimatedListItem>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: widget.duration, vsync: this);
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _controller, curve: AppAnimations.emphasized),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails details) {
    _controller.forward();
  }

  void _handleTapUp(TapUpDetails details) {
    _controller.reverse();
    widget.onTap?.call();
  }

  void _handleTapCancel() {
    _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: widget.onTap != null ? _handleTapDown : null,
      onTapUp: widget.onTap != null ? _handleTapUp : null,
      onTapCancel: widget.onTap != null ? _handleTapCancel : null,
      child: ScaleTransition(scale: _scaleAnimation, child: widget.child),
    );
  }
}

/// Shimmer loading effect
class ShimmerLoading extends StatefulWidget {
  final Widget child;
  final Color? baseColor;
  final Color? highlightColor;
  final Duration duration;

  const ShimmerLoading({
    super.key,
    required this.child,
    this.baseColor,
    this.highlightColor,
    this.duration = AppAnimations.durationExtraLong4,
  });

  @override
  State<ShimmerLoading> createState() => _ShimmerLoadingState();
}

class _ShimmerLoadingState extends State<ShimmerLoading>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: widget.duration, vsync: this)
      ..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final baseColor =
        widget.baseColor ?? theme.colorScheme.surfaceContainerHighest;
    final highlightColor =
        widget.highlightColor ??
        theme.colorScheme.surfaceContainerHighest.withOpacity(0.5);

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return ShaderMask(
          shaderCallback: (bounds) {
            return LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [baseColor, highlightColor, baseColor],
              stops: [
                _controller.value - 0.3,
                _controller.value,
                _controller.value + 0.3,
              ].map((e) => e.clamp(0.0, 1.0)).toList(),
            ).createShader(bounds);
          },
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

/// Animated counter with number roll effect
class AnimatedCounter extends StatelessWidget {
  final int value;
  final TextStyle? style;
  final Duration duration;

  const AnimatedCounter({
    super.key,
    required this.value,
    this.style,
    this.duration = AppAnimations.durationMedium2,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<int>(
      tween: IntTween(begin: 0, end: value),
      duration: duration,
      curve: AppAnimations.emphasized,
      builder: (context, value, child) {
        return Text(value.toString(), style: style);
      },
    );
  }
}

/// Animated progress indicator with smooth transitions
class AnimatedProgressIndicator extends StatelessWidget {
  final double value;
  final Color? color;
  final Color? backgroundColor;
  final Duration duration;

  const AnimatedProgressIndicator({
    super.key,
    required this.value,
    this.color,
    this.backgroundColor,
    this.duration = AppAnimations.durationMedium3,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.0, end: value),
      duration: duration,
      curve: AppAnimations.emphasized,
      builder: (context, value, child) {
        return LinearProgressIndicator(
          value: value,
          color: color,
          backgroundColor: backgroundColor,
        );
      },
    );
  }
}

/// Hero-like shared element transition helper
class SharedElement extends StatelessWidget {
  final Object tag;
  final Widget child;

  const SharedElement({super.key, required this.tag, required this.child});

  @override
  Widget build(BuildContext context) {
    return Hero(
      tag: tag,
      child: Material(type: MaterialType.transparency, child: child),
    );
  }
}

/// Expandable container with smooth animation
class ExpandableContainer extends StatefulWidget {
  final Widget child;
  final bool expanded;
  final Duration duration;
  final Curve curve;

  const ExpandableContainer({
    super.key,
    required this.child,
    required this.expanded,
    this.duration = AppAnimations.durationMedium3,
    this.curve = AppAnimations.emphasized,
  });

  @override
  State<ExpandableContainer> createState() => _ExpandableContainerState();
}

class _ExpandableContainerState extends State<ExpandableContainer>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: widget.duration, vsync: this);
    _animation = CurvedAnimation(parent: _controller, curve: widget.curve);
    if (widget.expanded) {
      _controller.value = 1.0;
    }
  }

  @override
  void didUpdateWidget(ExpandableContainer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.expanded != widget.expanded) {
      if (widget.expanded) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizeTransition(
      sizeFactor: _animation,
      child: FadeTransition(opacity: _animation, child: widget.child),
    );
  }
}
