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
