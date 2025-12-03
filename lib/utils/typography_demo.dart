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

// Typography Demo for the new Montserrat + Inter font system
// This file demonstrates how the new typography hierarchy looks
// You can use this as a reference or temporary test screen

import 'package:flutter/material.dart';
import '../services/theme_service.dart';

class TypographyDemo extends StatelessWidget {
  const TypographyDemo({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('Typography Demo', style: theme.textTheme.titleLarge),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Display styles (Montserrat)
            Text(
              'Display Large (Montserrat)',
              style: theme.textTheme.displayLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Display Medium (Montserrat)',
              style: theme.textTheme.displayMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Display Small (Montserrat)',
              style: theme.textTheme.displaySmall,
            ),
            const SizedBox(height: 24),

            // Headlines (Montserrat)
            Text(
              'Headline Large (Montserrat)',
              style: theme.textTheme.headlineLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Headline Medium (Montserrat)',
              style: theme.textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Headline Small (Montserrat)',
              style: theme.textTheme.headlineSmall,
            ),
            const SizedBox(height: 24),

            // Titles (Montserrat)
            Text('Title Large (Montserrat)', style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              'Title Medium (Montserrat)',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text('Title Small (Montserrat)', style: theme.textTheme.titleSmall),
            const SizedBox(height: 24),

            // Body text (Inter - more readable for longer content)
            Text('Body Large (Inter)', style: theme.textTheme.bodyLarge),
            const SizedBox(height: 8),
            Text(
              'Body Medium (Inter) - This is a longer text to demonstrate readability. Inter font is specifically designed for user interfaces and provides excellent readability at small sizes.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 8),
            Text('Body Small (Inter)', style: theme.textTheme.bodySmall),
            const SizedBox(height: 24),

            // Labels (Montserrat)
            Text('Label Large (Montserrat)', style: theme.textTheme.labelLarge),
            const SizedBox(height: 8),
            Text(
              'Label Medium (Montserrat)',
              style: theme.textTheme.labelMedium,
            ),
            const SizedBox(height: 8),
            Text('Label Small (Montserrat)', style: theme.textTheme.labelSmall),
            const SizedBox(height: 24),

            // Code text example
            const Divider(),
            Text(
              'Code Text (JetBrains Mono)',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'function fibonacci(n) {\n  if (n <= 1) return n;\n  return fibonacci(n-1) + fibonacci(n-2);\n}',
                style: AppTheme.getCodeTextStyle(context),
              ),
            ),
            const SizedBox(height: 24),

            // Typography summary
            const Divider(),
            Text(
              'Typography System Summary',
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            Text(
              'Headlines & Titles: Montserrat',
              style: theme.textTheme.titleMedium,
            ),
            Text(
              '• Modern, geometric design\n• Great for navigation and headers\n• Strong visual hierarchy',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            Text('Body Text: Inter', style: theme.textTheme.titleMedium),
            Text(
              '• Optimized for user interfaces\n• Excellent readability at small sizes\n• Perfect for longer content',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            Text('Code: JetBrains Mono', style: theme.textTheme.titleMedium),
            Text(
              '• Monospace font for code blocks\n• Enhanced readability for developers\n• Available via AppTheme.getCodeTextStyle()',
              style: theme.textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}
