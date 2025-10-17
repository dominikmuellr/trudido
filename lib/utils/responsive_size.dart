import 'package:flutter/material.dart';

/// Scales a size value based on the current text scale factor
double scaledSize(BuildContext context, double baseSize) {
  final textScale = MediaQuery.textScaleFactorOf(context);
  return baseSize * textScale;
}

/// A wrapper around Icon that automatically scales based on text scale factor
/// Use this instead of Icon() for icons that should scale with font size
class ScaledIcon extends StatelessWidget {
  final IconData icon;
  final double? size;
  final Color? color;
  final String? semanticLabel;
  final TextDirection? textDirection;

  const ScaledIcon(
    this.icon, {
    super.key,
    this.size,
    this.color,
    this.semanticLabel,
    this.textDirection,
  });

  @override
  Widget build(BuildContext context) {
    final baseSize = size ?? 24.0;
    final effectiveSize = scaledSize(context, baseSize);

    return Icon(
      icon,
      size: effectiveSize,
      color: color,
      semanticLabel: semanticLabel,
      textDirection: textDirection,
    );
  }
}
