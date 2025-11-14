import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

///
/// Usage:
/// ```dart
/// NotesOnboardingTooltip(
///   child: YourNotesListWidget(),
/// )
/// ```
class NotesOnboardingTooltip extends StatefulWidget {
  final Widget child;
  final String? customMessage;

  const NotesOnboardingTooltip({
    super.key,
    required this.child,
    this.customMessage,
  });

  @override
  State<NotesOnboardingTooltip> createState() => _NotesOnboardingTooltipState();
}

class _NotesOnboardingTooltipState extends State<NotesOnboardingTooltip>
    with TickerProviderStateMixin {
  static const String _tooltipSeenKey = 'notes_onboarding_tooltip_seen';
  bool _showTooltip = false;
  bool _isLoading = true;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _checkTooltipStatus();
  }

  void _initializeAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOutCubicEmphasized,
      ),
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic),
    );
  }

  Future<void> _checkTooltipStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final hasSeenTooltip = prefs.getBool(_tooltipSeenKey) ?? false;

      setState(() {
        _showTooltip = !hasSeenTooltip;
        _isLoading = false;
      });

      if (_showTooltip) {
        // Small delay to allow the UI to settle
        await Future.delayed(const Duration(milliseconds: 350));
        if (mounted) {
          _animationController.forward();
        }
      }
    } catch (e) {
      // Handle SharedPreferences error gracefully
      setState(() {
        _showTooltip = false;
        _isLoading = false;
      });
    }
  }

  Future<void> _dismissTooltip() async {
    try {
      // Animate out
      await _animationController.reverse();

      // Save to SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_tooltipSeenKey, true);

      // Update state
      if (mounted) {
        setState(() {
          _showTooltip = false;
        });
      }
    } catch (e) {
      // Even if saving fails, hide the tooltip
      if (mounted) {
        setState(() {
          _showTooltip = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Show loading state briefly while checking SharedPreferences
    if (_isLoading) {
      return widget.child;
    }

    return Stack(
      children: [
        // Main content
        widget.child,

        // Onboarding overlay
        if (_showTooltip)
          AnimatedBuilder(
            animation: _animationController,
            builder: (context, child) {
              return Opacity(
                opacity: _fadeAnimation.value,
                child: GestureDetector(
                  onTap: _dismissTooltip,
                  child: Container(
                    width: double.infinity,
                    height: double.infinity,
                    color: Colors.black.withOpacity(0.75),
                    child: Center(
                      child: Transform.scale(
                        scale: _scaleAnimation.value,
                        child: Container(
                          margin: const EdgeInsets.all(32),
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surface,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.3),
                                blurRadius: 20,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Header
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.primaryContainer,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Icon(
                                      Icons.pan_tool,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onPrimaryContainer,
                                      size: 24,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Text(
                                      'Gesture Guide',
                                      style: Theme.of(context)
                                          .textTheme
                                          .headlineSmall
                                          ?.copyWith(
                                            fontWeight: FontWeight.bold,
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.onSurface,
                                          ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 24),

                              // Gesture instructions
                              _buildGestureInstruction(
                                context,
                                icon: Icons.pan_tool,
                                title: 'Tap to preview',
                                description:
                                    'Quick tap on any note to see the full content with rendered markdown.',
                              ),
                              const SizedBox(height: 16),
                              _buildGestureInstruction(
                                context,
                                icon: Icons.touch_app,
                                title: 'Press and hold to edit',
                                description:
                                    'Long press on any note to jump directly into edit mode.',
                              ),
                              const SizedBox(height: 32),

                              // Dismissal instruction
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .surfaceContainerHighest
                                      .withOpacity(0.5),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.info,
                                      size: 16,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'Tap anywhere to dismiss this guide',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(
                                              color: Theme.of(
                                                context,
                                              ).colorScheme.onSurfaceVariant,
                                            ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
      ],
    );
  }

  Widget _buildGestureInstruction(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            color: Theme.of(context).colorScheme.primary,
            size: 20,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withOpacity(0.8),
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Complete example implementation with dummy data
/// This shows how to integrate the onboarding tooltip into your notes screen
class NotesScreenWithOnboarding extends StatelessWidget {
  const NotesScreenWithOnboarding({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Notes')),
      body: NotesOnboardingTooltip(
        child: ListView.builder(
          padding: const EdgeInsets.all(8),
          itemCount: _dummyNotes.length,
          itemBuilder: (context, index) {
            final note = _dummyNotes[index];
            return _NoteCard(note: note);
          },
        ),
      ),
    );
  }
}

/// Dummy note model for example
class DummyNote {
  final String title;
  final String content;
  final DateTime updatedAt;

  DummyNote({
    required this.title,
    required this.content,
    required this.updatedAt,
  });
}

/// Example note card with gesture detection
class _NoteCard extends StatelessWidget {
  final DummyNote note;

  const _NoteCard({required this.note});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        // Handle tap - navigate to preview
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Preview: ${note.title}'),
            duration: const Duration(seconds: 1),
          ),
        );
      },
      onLongPress: () {
        // Handle long press - navigate to editor
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Edit: ${note.title}'),
            duration: const Duration(seconds: 1),
            backgroundColor: Theme.of(context).colorScheme.primary,
          ),
        );
      },
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                note.title,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              Text(
                note.content,
                style: Theme.of(context).textTheme.bodyMedium,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              Text(
                _formatDate(note.updatedAt),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 0) {
      return '${difference.inDays} day${difference.inDays == 1 ? '' : 's'} ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hour${difference.inHours == 1 ? '' : 's'} ago';
    } else {
      return 'Just now';
    }
  }
}

/// Dummy data for example
final List<DummyNote> _dummyNotes = [
  DummyNote(
    title: 'Meeting Notes',
    content:
        '# Weekly Standup\n\n- Discussed project progress\n- **Action items** assigned\n- Next meeting scheduled',
    updatedAt: DateTime.now().subtract(const Duration(hours: 2)),
  ),
  DummyNote(
    title: 'Shopping List',
    content: '- Milk\n- Eggs\n- Bread\n- *Don\'t forget* the organic apples',
    updatedAt: DateTime.now().subtract(const Duration(days: 1)),
  ),
  DummyNote(
    title: 'Recipe Ideas',
    content:
        '## Pasta Night\n\n`Ingredients`: tomatoes, basil, garlic\n\n**Preparation**: 30 minutes',
    updatedAt: DateTime.now().subtract(const Duration(days: 2)),
  ),
  DummyNote(
    title: 'Book Quotes',
    content:
        '> "The only way to do great work is to love what you do."\n\nFrom Steve Jobs biography',
    updatedAt: DateTime.now().subtract(const Duration(days: 3)),
  ),
];

/// Example main app to test the onboarding
class OnboardingExampleApp extends StatelessWidget {
  const OnboardingExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Notes Onboarding Example',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
      ),
      home: const NotesScreenWithOnboarding(),
    );
  }
}
