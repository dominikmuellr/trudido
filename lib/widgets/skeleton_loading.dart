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
import '../theme/spacing_tokens.dart';
import '../utils/animations.dart';

/// Skeleton placeholder for a note card during loading.
class SkeletonNoteCard extends StatelessWidget {
  const SkeletonNoteCard({super.key});

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.surfaceContainerHighest;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Container(
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.4),
          borderRadius: SpacingBorderRadius.lg,
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _bar(color, width: 140, height: 14),
            const SizedBox(height: 12),
            _bar(color, width: double.infinity, height: 10),
            const SizedBox(height: 8),
            _bar(color, width: 200, height: 10),
            const SizedBox(height: 16),
            _bar(color, width: 80, height: 10),
          ],
        ),
      ),
    );
  }

  Widget _bar(Color color, {required double width, required double height}) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(height / 2),
      ),
    );
  }
}

/// Skeleton placeholder for a task item during loading.
class SkeletonTaskItem extends StatelessWidget {
  const SkeletonTaskItem({super.key});

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.surfaceContainerHighest;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Container(
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.4),
          borderRadius: SpacingBorderRadius.md,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _bar(color, width: 160, height: 12),
                  const SizedBox(height: 8),
                  _bar(color, width: 100, height: 10),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _bar(Color color, {required double width, required double height}) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(height / 2),
      ),
    );
  }
}

/// A column of shimmer skeleton cards for note loading states.
class SkeletonNoteList extends StatelessWidget {
  final int count;
  const SkeletonNoteList({super.key, this.count = 5});

  @override
  Widget build(BuildContext context) {
    return ShimmerLoading(
      child: Column(
        children: List.generate(count, (_) => const SkeletonNoteCard()),
      ),
    );
  }
}

/// A column of shimmer skeleton items for task loading states.
class SkeletonTaskList extends StatelessWidget {
  final int count;
  const SkeletonTaskList({super.key, this.count = 6});

  @override
  Widget build(BuildContext context) {
    return ShimmerLoading(
      child: Column(
        children: List.generate(count, (_) => const SkeletonTaskItem()),
      ),
    );
  }
}
