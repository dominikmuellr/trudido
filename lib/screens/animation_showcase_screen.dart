import 'package:flutter/material.dart';
import '../utils/animations.dart';
import '../utils/animated_navigation.dart';
import '../widgets/animated_widgets.dart';

/// Animation Showcase Screen
/// Demonstrates all Material Design 3 animations implemented in the app
class AnimationShowcaseScreen extends StatefulWidget {
  const AnimationShowcaseScreen({super.key});

  @override
  State<AnimationShowcaseScreen> createState() =>
      _AnimationShowcaseScreenState();
}

class _AnimationShowcaseScreenState extends State<AnimationShowcaseScreen>
    with TickerProviderStateMixin {
  bool _fabVisible = true;
  bool _expanded = false;
  bool _chipsSelected = false;
  bool _switchValue = false;
  bool _loading = false;
  int _counter = 0;
  double _progress = 0.3;
  bool _showContent = true;

  late AnimationController _listController;

  @override
  void initState() {
    super.initState();
    _listController = AnimationController(
      duration: AppAnimations.durationLong2,
      vsync: this,
    );
    _listController.forward();
  }

  @override
  void dispose() {
    _listController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Animation Showcase'), elevation: 0),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Section: Navigation Transitions
          _buildSection(
            title: 'Navigation Transitions',
            children: [
              _buildButton(
                'Shared Axis Transition',
                () => AnimatedNavigation.push(
                  context,
                  const _DemoScreen(title: 'Shared Axis'),
                ),
              ),
              const SizedBox(height: 8),
              _buildButton(
                'Fade Through Transition',
                () => AnimatedNavigation.pushFadeThrough(
                  context,
                  const _DemoScreen(title: 'Fade Through'),
                ),
              ),
              const SizedBox(height: 8),
              _buildButton(
                'Container Transform',
                () => AnimatedNavigation.pushContainerTransform(
                  context,
                  const _DemoScreen(title: 'Container Transform'),
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Section: Dialogs & Sheets
          _buildSection(
            title: 'Dialogs & Bottom Sheets',
            children: [
              _buildButton(
                'Animated Dialog',
                () => AnimatedDialog.show(
                  context: context,
                  child: AlertDialog(
                    title: const Text('Animated Dialog'),
                    content: const Text(
                      'This dialog appears with a smooth fade and scale animation.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Close'),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              _buildButton(
                'Animated Bottom Sheet',
                () => AnimatedBottomSheet.show(
                  context: context,
                  isScrollControlled: true,
                  child: Container(
                    height: 400,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: colorScheme.surface,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(28),
                      ),
                    ),
                    child: Column(
                      children: [
                        Container(
                          width: 40,
                          height: 4,
                          margin: const EdgeInsets.only(bottom: 20),
                          decoration: BoxDecoration(
                            color: colorScheme.onSurfaceVariant.withOpacity(
                              0.4,
                            ),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        Text(
                          'Bottom Sheet',
                          style: theme.textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'This bottom sheet slides up with smooth animation.',
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Section: Snackbars
          _buildSection(
            title: 'Snackbars',
            children: [
              Row(
                children: [
                  Expanded(
                    child: _buildButton(
                      'Success',
                      () => AnimatedSnackbar.success(
                        context,
                        message: 'Task completed!',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildButton(
                      'Error',
                      () => AnimatedSnackbar.error(
                        context,
                        message: 'Failed to save',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _buildButton(
                      'Info',
                      () => AnimatedSnackbar.info(
                        context,
                        message: 'Sync in progress',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildButton(
                      'Warning',
                      () => AnimatedSnackbar.warning(
                        context,
                        message: 'Storage almost full',
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Section: Animated Widgets
          _buildSection(
            title: 'Animated FAB',
            children: [
              Center(
                child: AnimatedFAB(
                  visible: _fabVisible,
                  icon: const Icon(Icons.add),
                  label: 'Add Task',
                  onPressed: () {
                    AnimatedSnackbar.info(context, message: 'FAB pressed!');
                  },
                ),
              ),
              const SizedBox(height: 16),
              Center(
                child: ElevatedButton(
                  onPressed: () => setState(() => _fabVisible = !_fabVisible),
                  child: Text(_fabVisible ? 'Hide FAB' : 'Show FAB'),
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Section: Animated Card
          _buildSection(
            title: 'Animated Card',
            children: [
              AnimatedCard(
                onTap: () {
                  AnimatedSnackbar.info(context, message: 'Card tapped!');
                },
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Interactive Card',
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    const Text('Tap this card to see the press animation.'),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Section: Animated Chips
          _buildSection(
            title: 'Animated Chips',
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  AnimatedChip(
                    label: 'High Priority',
                    icon: Icons.priority_high,
                    selected: _chipsSelected,
                    onTap: () =>
                        setState(() => _chipsSelected = !_chipsSelected),
                  ),
                  AnimatedChip(
                    label: 'Work',
                    icon: Icons.work,
                    selected: !_chipsSelected,
                    onTap: () =>
                        setState(() => _chipsSelected = !_chipsSelected),
                  ),
                  AnimatedChip(
                    label: 'Personal',
                    icon: Icons.person,
                    selected: false,
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Section: Counters and Progress
          _buildSection(
            title: 'Animated Counter & Progress',
            children: [
              Center(
                child: AnimatedCounter(
                  value: _counter,
                  style: theme.textTheme.displayMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.primary,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton(
                    onPressed: () => setState(() => _counter++),
                    child: const Text('Increment'),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton(
                    onPressed: () => setState(
                      () => _counter = (_counter - 1) < 0 ? 0 : _counter - 1,
                    ),
                    child: const Text('Decrement'),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              AnimatedProgressIndicator(
                value: _progress,
                color: colorScheme.primary,
              ),
              const SizedBox(height: 16),
              Slider(
                value: _progress,
                onChanged: (value) => setState(() => _progress = value),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Section: Animated Text
          _buildSection(
            title: 'Animated Text',
            children: [
              Center(
                child: AnimatedText(
                  text: _switchValue ? 'Enabled' : 'Disabled',
                  style: theme.textTheme.headlineMedium,
                ),
              ),
              const SizedBox(height: 16),
              Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Toggle: '),
                    AnimatedSwitch(
                      value: _switchValue,
                      onChanged: (value) =>
                          setState(() => _switchValue = value),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Section: Expandable Container
          _buildSection(
            title: 'Expandable Container',
            children: [
              Card(
                child: Column(
                  children: [
                    ListTile(
                      title: const Text('Expandable Section'),
                      trailing: Icon(
                        _expanded ? Icons.expand_less : Icons.expand_more,
                      ),
                      onTap: () => setState(() => _expanded = !_expanded),
                    ),
                    ExpandableContainer(
                      expanded: _expanded,
                      child: const Padding(
                        padding: EdgeInsets.all(16),
                        child: Text(
                          'This content expands and collapses smoothly with '
                          'fade and size animations.',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Section: Loading Indicator
          _buildSection(
            title: 'Animated Loading',
            children: [
              Center(
                child: AnimatedLoadingIndicator(
                  loading: _loading,
                  size: 32,
                  child: const Icon(Icons.check_circle, size: 32),
                ),
              ),
              const SizedBox(height: 16),
              Center(
                child: ElevatedButton(
                  onPressed: () => setState(() => _loading = !_loading),
                  child: Text(_loading ? 'Hide Loading' : 'Show Loading'),
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Section: Visibility Toggle
          _buildSection(
            title: 'Animated Visibility',
            children: [
              AnimatedVisibility(
                visible: _showContent,
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        const Icon(Icons.info, size: 48),
                        const SizedBox(height: 8),
                        Text('Content', style: theme.textTheme.titleLarge),
                        const SizedBox(height: 8),
                        const Text(
                          'This content fades and slides in/out smoothly.',
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Center(
                child: ElevatedButton(
                  onPressed: () => setState(() => _showContent = !_showContent),
                  child: Text(_showContent ? 'Hide Content' : 'Show Content'),
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Section: Staggered List
          _buildSection(
            title: 'Staggered List Animation',
            children: [
              const Text(
                'Items appear with staggered timing:',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 16),
              ...List.generate(
                5,
                (index) => StaggeredListAnimation(
                  index: index,
                  animation: _listController,
                  child: Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: CircleAvatar(child: Text('${index + 1}')),
                      title: Text('List Item ${index + 1}'),
                      subtitle: const Text('Staggered animation'),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Center(
                child: ElevatedButton(
                  onPressed: () {
                    _listController.reset();
                    _listController.forward();
                  },
                  child: const Text('Replay Animation'),
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Section: Shimmer Loading
          _buildSection(
            title: 'Shimmer Loading Effect',
            children: [
              ShimmerLoading(
                child: Column(
                  children: [
                    Container(
                      height: 20,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      height: 20,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      height: 20,
                      width: 200,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        ...children,
      ],
    );
  }

  Widget _buildButton(String label, VoidCallback onPressed) {
    return FilledButton.tonal(onPressed: onPressed, child: Text(label));
  }
}

/// Demo screen for navigation transitions
class _DemoScreen extends StatelessWidget {
  final String title;

  const _DemoScreen({Key? key, required this.title}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.check_circle,
              size: 80,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 24),
            Text(
              'You navigated with:',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 32),
            FilledButton.tonal(
              onPressed: () => Navigator.pop(context),
              child: const Text('Go Back'),
            ),
          ],
        ),
      ),
    );
  }
}
