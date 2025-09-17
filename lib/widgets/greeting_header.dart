import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:math';

import '../services/theme_service.dart';
import '../providers/app_providers.dart';
import '../services/storage_service.dart';
import 'filters_sheet.dart';

// Provider for user's name
final userNameProvider = StateProvider<String>((ref) => StorageService.getUserName());

// Provider for current greeting language (set once on app start)
final greetingLanguageProvider = StateProvider<int>((ref) {
  // Generate a random greeting when the app starts
  return Random().nextInt(11);
});

// Provider for hide greeting preference
// hideGreeting now sourced from unified preferences state; mutation via controller.
final hideGreetingProvider = Provider<bool>((ref) => ref.watch(preferencesStateProvider).hideGreeting);

class GreetingHeader extends ConsumerStatefulWidget {
  const GreetingHeader({super.key});

  @override
  ConsumerState<GreetingHeader> createState() => _GreetingHeaderState();
}

class _GreetingHeaderState extends ConsumerState<GreetingHeader> {

  final List<Map<String, String>> _greetings = [
    {'text': 'Hello', 'lang': 'English'},
    {'text': 'Hola', 'lang': 'Spanish'},
    {'text': 'Hallo', 'lang': 'German'},
    {'text': 'Bonjour', 'lang': 'French'},
    {'text': 'Ciao', 'lang': 'Italian'},
    {'text': 'Olá', 'lang': 'Portuguese'},
    {'text': 'Hallo', 'lang': 'Dutch'},
    {'text': 'Hej', 'lang': 'Danish'},
    {'text': 'Cześć', 'lang': 'Polish'},
    {'text': 'Ahoj', 'lang': 'Czech'},
    {'text': 'Geia sas', 'lang': 'Greek'},
  ];

  @override
  void initState() {
    super.initState();
  }

  void _changeGreeting() {
    final currentGreetingIndex = ref.read(greetingLanguageProvider);
    int newGreetingIndex;
    do {
      newGreetingIndex = Random().nextInt(_greetings.length);
    } while (newGreetingIndex == currentGreetingIndex);
    ref.read(greetingLanguageProvider.notifier).state = newGreetingIndex;
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final userName = ref.watch(userNameProvider);
    final greetingIndex = ref.watch(greetingLanguageProvider);
    final greeting = _greetings[greetingIndex];
    final theme = Theme.of(context);
    final appOpts = theme.extension<AppOptions>() ?? const AppOptions(compact: false, highContrast: false);
    final pad = EdgeInsets.all(appOpts.compact ? 12 : 20);
    final gap = appOpts.compact ? 8.0 : 12.0;
    final headlineStyle = theme.textTheme.headlineSmall?.copyWith(
      fontWeight: FontWeight.bold,
      fontSize: appOpts.compact ? 20 : null,
      color: theme.colorScheme.onSurface,
    );
    final langStyle = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
      fontSize: appOpts.compact ? 10 : null,
    );
    final messageStyle = theme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
      fontSize: appOpts.compact ? 12 : null,
    );

    return Container(
      padding: pad,
      // Method 1: No decoration property = transparent background
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 500),
                  transitionBuilder: (child, animation) => FadeTransition(opacity: animation, child: child),
                  child: Align(
                    key: ValueKey<int>(greetingIndex),
                    alignment: Alignment.centerLeft,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${greeting['text']}${userName.isNotEmpty ? ', $userName!' : '!'}',
                          style: headlineStyle,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(greeting['lang']!, style: langStyle),
                      ],
                    ),
                  ),
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Semantics(
                    label: 'Change greeting language',
                    button: true,
                    child: IconButton(
                      onPressed: _changeGreeting,
                      icon: const Icon(Icons.language),
                      color: theme.colorScheme.primary,
                      tooltip: 'Change language',
                    ),
                  ),
                  Semantics(
                    label: userName.isEmpty ? 'Set your name' : 'Change your name',
                    button: true,
                    child: IconButton(
                      onPressed: () => _showNameDialog(context),
                      icon: Icon(
                        userName.isEmpty ? Icons.person_add_outlined : Icons.person,
                      ),
                      color: theme.colorScheme.primary,
                      tooltip: userName.isEmpty ? 'Set your name' : 'Change name',
                    ),
                  ),
                  Semantics(
                    label: 'Open filters',
                    button: true,
                    child: IconButton(
                      onPressed: () => showFiltersSheet(context),
                      icon: const Icon(Icons.tune),
                      color: theme.colorScheme.primary,
                      tooltip: 'Filters',
                    ),
                  ),
                ],
              ),
            ],
          ),
          SizedBox(height: gap),
          Text(_getTimeBasedMessage(), style: messageStyle),
        ],
      ),
    );
  }

  String _getTimeBasedMessage() {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      return 'Ready to tackle your morning tasks?';
    } else if (hour < 17) {
      return 'How\'s your day going so far?';
    } else {
      return 'Time to wrap up the day!';
    }
  }

  void _showNameDialog(BuildContext context) {
    final textController = TextEditingController(text: ref.read(userNameProvider));
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('What\'s your name?'),
        content: TextField(
          controller: textController,
          decoration: const InputDecoration(
            labelText: 'Your name',
            hintText: 'Enter your name',
            border: OutlineInputBorder(),
          ),
          textCapitalization: TextCapitalization.words,
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              final name = textController.text.trim();
              await StorageService.setUserName(name);
              ref.read(userNameProvider.notifier).state = name;
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}
