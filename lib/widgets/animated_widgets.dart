import 'package:flutter/material.dart';
import '../utils/animations.dart';
import '../services/haptic_feedback_service.dart';

/// Animated FAB with scale, fade transitions, and haptic feedback
class AnimatedFAB extends StatefulWidget {
  final VoidCallback onPressed;
  final Widget icon;
  final String? label;
  final bool visible;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final String? heroTag;
  final bool enableHaptic;

  const AnimatedFAB({
    super.key,
    required this.onPressed,
    required this.icon,
    this.label,
    this.visible = true,
    this.backgroundColor,
    this.foregroundColor,
    this.heroTag,
    this.enableHaptic = true,
  });

  @override
  State<AnimatedFAB> createState() => _AnimatedFABState();
}

class _AnimatedFABState extends State<AnimatedFAB>
    with TickerProviderStateMixin {
  late AnimationController _visibilityController;
  late AnimationController _pressController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<double> _pressScaleAnimation;

  @override
  void initState() {
    super.initState();
    _visibilityController = AnimationController(
      duration: AppAnimations.durationMedium2,
      vsync: this,
    );

    _pressController = AnimationController(
      duration: AppAnimations.durationShort4,
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _visibilityController,
        curve: AppAnimations.emphasized,
      ),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _visibilityController,
        curve: AppAnimations.standardDecelerate,
      ),
    );

    _pressScaleAnimation = Tween<double>(begin: 1.0, end: 0.92).animate(
      CurvedAnimation(
        parent: _pressController,
        curve: AppAnimations.emphasized,
      ),
    );

    if (widget.visible) {
      _visibilityController.forward();
    }
  }

  @override
  void didUpdateWidget(AnimatedFAB oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.visible != widget.visible) {
      if (widget.visible) {
        _visibilityController.forward();
      } else {
        _visibilityController.reverse();
      }
    }
  }

  @override
  void dispose() {
    _visibilityController.dispose();
    _pressController.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails details) {
    _pressController.forward();
  }

  void _handleTapUp(TapUpDetails details) {
    _pressController.reverse();
    if (widget.enableHaptic) {
      HapticFeedbackService.heavyImpact();
    }
  }

  void _handleTapCancel() {
    _pressController.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scaleAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: ScaleTransition(
          scale: _pressScaleAnimation,
          child: widget.label != null
              ? FloatingActionButton.extended(
                  heroTag: widget.heroTag,
                  onPressed: widget.onPressed,
                  icon: widget.icon,
                  label: Text(widget.label!),
                  backgroundColor: widget.backgroundColor,
                  foregroundColor: widget.foregroundColor,
                )
              : GestureDetector(
                  onTapDown: _handleTapDown,
                  onTapUp: _handleTapUp,
                  onTapCancel: _handleTapCancel,
                  child: FloatingActionButton(
                    heroTag: widget.heroTag,
                    onPressed: widget.onPressed,
                    backgroundColor: widget.backgroundColor,
                    foregroundColor: widget.foregroundColor,
                    child: widget.icon,
                  ),
                ),
        ),
      ),
    );
  }
}

/// Animated card with hover and press effects
class AnimatedCard extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? margin;
  final EdgeInsetsGeometry? padding;
  final Color? color;
  final double elevation;
  final BorderRadiusGeometry? borderRadius;

  const AnimatedCard({
    super.key,
    required this.child,
    this.onTap,
    this.margin,
    this.padding,
    this.color,
    this.elevation = 1,
    this.borderRadius,
  });

  @override
  State<AnimatedCard> createState() => _AnimatedCardState();
}

class _AnimatedCardState extends State<AnimatedCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _elevationAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: AppAnimations.durationShort4,
      vsync: this,
    );

    _elevationAnimation =
        Tween<double>(
          begin: widget.elevation,
          end: widget.elevation + 4,
        ).animate(
          CurvedAnimation(parent: _controller, curve: AppAnimations.emphasized),
        );

    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.98).animate(
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
    HapticFeedbackService.mediumImpact();
    widget.onTap?.call();
  }

  void _handleTapCancel() {
    _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: Card(
            margin: widget.margin,
            color: widget.color,
            elevation: _elevationAnimation.value,
            shape: RoundedRectangleBorder(
              borderRadius:
                  widget.borderRadius as BorderRadius? ??
                  BorderRadius.circular(12),
            ),
            child: InkWell(
              onTapDown: widget.onTap != null ? _handleTapDown : null,
              onTapUp: widget.onTap != null ? _handleTapUp : null,
              onTapCancel: widget.onTap != null ? _handleTapCancel : null,
              borderRadius:
                  widget.borderRadius as BorderRadius? ??
                  BorderRadius.circular(12),
              child: Padding(
                padding: widget.padding ?? const EdgeInsets.all(16),
                child: child,
              ),
            ),
          ),
        );
      },
      child: widget.child,
    );
  }
}

/// Animated chip with press effect
class AnimatedChip extends StatefulWidget {
  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final IconData? icon;
  final Color? selectedColor;
  final Color? unselectedColor;

  const AnimatedChip({
    super.key,
    required this.label,
    this.selected = false,
    this.onTap,
    this.icon,
    this.selectedColor,
    this.unselectedColor,
  });

  @override
  State<AnimatedChip> createState() => _AnimatedChipState();
}

class _AnimatedChipState extends State<AnimatedChip>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: AppAnimations.durationShort3,
      vsync: this,
    );

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
    HapticFeedbackService.lightImpact();
    widget.onTap?.call();
  }

  void _handleTapCancel() {
    _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return ScaleTransition(
      scale: _scaleAnimation,
      child: GestureDetector(
        onTapDown: widget.onTap != null ? _handleTapDown : null,
        onTapUp: widget.onTap != null ? _handleTapUp : null,
        onTapCancel: widget.onTap != null ? _handleTapCancel : null,
        child: AnimatedContainer(
          duration: AppAnimations.durationMedium2,
          curve: AppAnimations.emphasized,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: widget.selected
                ? (widget.selectedColor ?? colorScheme.primaryContainer)
                : (widget.unselectedColor ??
                      colorScheme.surfaceContainerHighest),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.icon != null) ...[
                Icon(
                  widget.icon,
                  size: 18,
                  color: widget.selected
                      ? colorScheme.onPrimaryContainer
                      : colorScheme.onSurface,
                ),
                const SizedBox(width: 6),
              ],
              Text(
                widget.label,
                style: TextStyle(
                  color: widget.selected
                      ? colorScheme.onPrimaryContainer
                      : colorScheme.onSurface,
                  fontWeight: widget.selected
                      ? FontWeight.w600
                      : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Animated icon button with ripple effect
class AnimatedIconButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final Color? color;
  final double size;
  final String? tooltip;

  const AnimatedIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.color,
    this.size = 24,
    this.tooltip,
  });

  @override
  State<AnimatedIconButton> createState() => _AnimatedIconButtonState();
}

class _AnimatedIconButtonState extends State<AnimatedIconButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: AppAnimations.durationShort4,
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.85).animate(
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
    HapticFeedbackService.mediumImpact();
    widget.onPressed();
  }

  void _handleTapCancel() {
    _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final button = GestureDetector(
      onTapDown: _handleTapDown,
      onTapUp: _handleTapUp,
      onTapCancel: _handleTapCancel,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Icon(widget.icon, color: widget.color, size: widget.size),
      ),
    );

    return widget.tooltip != null
        ? Tooltip(message: widget.tooltip!, child: button)
        : button;
  }
}

/// Animated switch with smooth transition and haptic feedback
class AnimatedSwitch extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  final Color? activeColor;

  const AnimatedSwitch({
    super.key,
    required this.value,
    required this.onChanged,
    this.activeColor,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.0, end: value ? 1.0 : 0.0),
      duration: AppAnimations.durationMedium2,
      curve: AppAnimations.emphasized,
      builder: (context, animValue, child) {
        return Switch(
          value: value,
          onChanged: (newValue) {
            HapticFeedbackService.lightImpact();
            onChanged(newValue);
          },
          activeColor: activeColor,
        );
      },
    );
  }
}

/// Animated text with fade and slide
class AnimatedText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final Duration duration;
  final Curve curve;

  const AnimatedText({
    super.key,
    required this.text,
    this.style,
    this.duration = AppAnimations.durationMedium2,
    this.curve = AppAnimations.emphasized,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: duration,
      switchInCurve: curve,
      switchOutCurve: curve,
      transitionBuilder: (child, animation) {
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0.0, 0.2),
              end: Offset.zero,
            ).animate(animation),
            child: child,
          ),
        );
      },
      child: Text(text, key: ValueKey<String>(text), style: style),
    );
  }
}

/// Animated visibility with fade and slide
class AnimatedVisibility extends StatelessWidget {
  final bool visible;
  final Widget child;
  final Duration duration;
  final Curve curve;
  final Axis axis;

  const AnimatedVisibility({
    super.key,
    required this.visible,
    required this.child,
    this.duration = AppAnimations.durationMedium2,
    this.curve = AppAnimations.emphasized,
    this.axis = Axis.vertical,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: duration,
      switchInCurve: curve,
      switchOutCurve: curve,
      transitionBuilder: (child, animation) {
        return FadeTransition(
          opacity: animation,
          child: SizeTransition(
            sizeFactor: animation,
            axis: axis,
            child: child,
          ),
        );
      },
      child: visible ? child : const SizedBox.shrink(),
    );
  }
}

/// Loading indicator with smooth fade in/out
class AnimatedLoadingIndicator extends StatelessWidget {
  final bool loading;
  final Widget child;
  final double size;
  final Color? color;

  const AnimatedLoadingIndicator({
    super.key,
    required this.loading,
    required this.child,
    this.size = 24,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: AppAnimations.durationMedium2,
      switchInCurve: AppAnimations.emphasized,
      switchOutCurve: AppAnimations.emphasized,
      transitionBuilder: (child, animation) {
        return FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.8, end: 1.0).animate(animation),
            child: child,
          ),
        );
      },
      child: loading
          ? SizedBox(
              width: size,
              height: size,
              child: CircularProgressIndicator(strokeWidth: 2, color: color),
            )
          : child,
    );
  }
}

/// Staggered grid with animated items
class AnimatedStaggeredGrid extends StatefulWidget {
  final List<Widget> children;
  final int crossAxisCount;
  final double mainAxisSpacing;
  final double crossAxisSpacing;
  final EdgeInsetsGeometry? padding;

  const AnimatedStaggeredGrid({
    super.key,
    required this.children,
    this.crossAxisCount = 2,
    this.mainAxisSpacing = 8,
    this.crossAxisSpacing = 8,
    this.padding,
  });

  @override
  State<AnimatedStaggeredGrid> createState() => _AnimatedStaggeredGridState();
}

class _AnimatedStaggeredGridState extends State<AnimatedStaggeredGrid>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: AppAnimations.durationLong2,
      vsync: this,
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: widget.padding,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: widget.crossAxisCount,
        mainAxisSpacing: widget.mainAxisSpacing,
        crossAxisSpacing: widget.crossAxisSpacing,
      ),
      itemCount: widget.children.length,
      itemBuilder: (context, index) {
        return StaggeredListAnimation(
          index: index,
          animation: _controller,
          child: widget.children[index],
        );
      },
    );
  }
}
