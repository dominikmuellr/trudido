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

// Example: Updating an existing screen to use animations and haptic feedback

import 'package:flutter/material.dart';
import '../utils/animations.dart';
import '../utils/animated_navigation.dart';
import '../widgets/animated_widgets.dart';
import '../services/haptic_feedback_service.dart';
import '../widgets/common/common.dart';

class ExampleScreen extends StatefulWidget {
  const ExampleScreen({super.key});

  @override
  State<ExampleScreen> createState() => _ExampleScreenState();
}

class _ExampleScreenState extends State<ExampleScreen> {
  bool _showDetails = false;
  int _count = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Example Screen'),
        actions: [
          // Animated icon button with haptic feedback
          AnimatedIconButton(
            icon: Icons.settings,
            onPressed: () {
              AnimatedNavigation.push(context, const SettingsScreen());
            },
            tooltip: 'Settings',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Animated card with haptic feedback
          AnimatedCard(
            onTap: () {
              AnimatedSnackbar.info(context, message: 'Card tapped!');
            },
            child: Column(
              children: [
                const Text('Interactive Card'),
                const SizedBox(height: 8),
                // Animated counter
                AnimatedCounter(
                  value: _count,
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Animated chips
          Wrap(
            spacing: 8,
            children: [
              AnimatedChip(
                label: 'Option 1',
                selected: _showDetails,
                onTap: () => setState(() => _showDetails = !_showDetails),
              ),
              AnimatedChip(label: 'Option 2', selected: false),
            ],
          ),

          const SizedBox(height: 16),

          // Expandable content
          ExpandableContainer(
            expanded: _showDetails,
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    const Text('Additional Details'),
                    const SizedBox(height: 16),
                    // Animated progress
                    AnimatedProgressIndicator(
                      value: 0.7,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Action buttons
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: () {
                    HapticFeedbackService.mediumImpact();
                    setState(() => _count++);
                    AnimatedSnackbar.success(
                      context,
                      message: 'Count increased!',
                    );
                  },
                  child: const Text('Increment'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ExpressiveOutlinedButton(
                  onPressed: () {
                    HapticFeedbackService.warning();
                    setState(() => _count = 0);
                    AnimatedSnackbar.warning(context, message: 'Count reset!');
                  },
                  child: const Text('Reset'),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Dialog example
          FilledButton.tonal(
            onPressed: () {
              AnimatedDialog.show(
                context: context,
                child: AlertDialog(
                  title: const Text('Confirm Action'),
                  content: const Text('Are you sure?'),
                  actions: [
                    ExpressiveTextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                    FilledButton(
                      onPressed: () {
                        Navigator.pop(context);
                        AnimatedSnackbar.success(
                          context,
                          message: 'Action confirmed!',
                        );
                      },
                      child: const Text('Confirm'),
                    ),
                  ],
                ),
              );
            },
            child: const Text('Show Dialog'),
          ),

          const SizedBox(height: 16),

          // Bottom sheet example
          FilledButton.tonal(
            onPressed: () {
              AnimatedBottomSheet.show(
                context: context,
                isScrollControlled: true,
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(28),
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 20),
                        decoration: BoxDecoration(
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurfaceVariant.withOpacity(0.4),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const Text('Bottom Sheet Content'),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Close'),
                      ),
                    ],
                  ),
                ),
              );
            },
            child: const Text('Show Bottom Sheet'),
          ),
        ],
      ),

      // Animated FAB with haptic feedback
      floatingActionButton: AnimatedFAB(
        heroTag: 'example_fab',
        icon: const Icon(Icons.add),
        onPressed: () {
          // Navigate with container transform for expanding effect
          AnimatedNavigation.pushContainerTransform(
            context,
            const DetailScreen(),
          );
        },
      ),
    );
  }
}

// Placeholder screens
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: const Center(child: Text('Settings Screen')),
    );
  }
}

class DetailScreen extends StatelessWidget {
  const DetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Detail')),
      body: const Center(child: Text('Detail Screen')),
    );
  }
}
