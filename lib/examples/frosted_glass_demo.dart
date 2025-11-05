import 'package:flutter/material.dart';
import '../widgets/glass_card.dart';

/// Example screen demonstrating Frosted Glass theme usage
///
/// This shows how to use GlassCard and GlassScaffold widgets
/// to create a modern frosted glass UI effect.
class FrostedGlassDemo extends StatelessWidget {
  const FrostedGlassDemo({super.key});

  @override
  Widget build(BuildContext context) {
    return GlassScaffold(
      appBar: AppBar(
        title: const Text('Frosted Glass Demo'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: ListView(
            children: [
              const SizedBox(height: 16),

              // Example 1: Simple glass card
              GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Glass Card',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'This card has a frosted glass effect with blur background.',
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Example 2: Tappable glass card
              GlassCard(
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Glass card tapped!')),
                  );
                },
                child: Row(
                  children: [
                    Icon(
                      Icons.touch_app,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Text('Tap me! This card is interactive.'),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Example 3: Custom colored glass card
              GlassCard(
                color: Theme.of(context).colorScheme.primary,
                opacity: 0.2,
                blur: 15,
                strongBorder: true,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Colored Glass',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'This card has a custom color tint and stronger blur effect.',
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Example 4: Multiple cards in a row
              Row(
                children: [
                  Expanded(
                    child: GlassCard(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        children: [
                          Icon(
                            Icons.task_alt,
                            size: 32,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(height: 8),
                          const Text('Tasks', textAlign: TextAlign.center),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GlassCard(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        children: [
                          Icon(
                            Icons.note,
                            size: 32,
                            color: Theme.of(context).colorScheme.secondary,
                          ),
                          const SizedBox(height: 8),
                          const Text('Notes', textAlign: TextAlign.center),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Example 5: List items with glass effect
              ...List.generate(
                3,
                (index) => Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: GlassCard(
                    margin: EdgeInsets.zero,
                    padding: const EdgeInsets.all(12),
                    onTap: () {},
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: Theme.of(
                            context,
                          ).colorScheme.primaryContainer,
                          child: Text('${index + 1}'),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Task ${index + 1}',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              Text(
                                'This is a description of task ${index + 1}',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.arrow_forward_ios,
                          size: 16,
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withOpacity(0.5),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {},
        child: const Icon(Icons.add),
      ),
    );
  }
}
