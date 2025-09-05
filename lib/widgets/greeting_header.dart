import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:math';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../services/theme_service.dart';
import '../providers/app_providers.dart';
import '../services/storage_service.dart';

// Provider for user's name
final userNameProvider = StateProvider<String>((ref) => StorageService.getUserName());

// Provider for current greeting language (set once on app start)
final greetingLanguageProvider = StateProvider<int>((ref) {
  // Generate a random greeting when the app starts
  return Random().nextInt(12);
});

// Provider for hide greeting preference
// hideGreeting now sourced from unified preferences state; mutation via controller.
final hideGreetingProvider = Provider<bool>((ref) => ref.watch(preferencesStateProvider).hideGreeting);

class GreetingHeader extends ConsumerStatefulWidget {
  const GreetingHeader({super.key});

  @override
  ConsumerState<GreetingHeader> createState() => _GreetingHeaderState();
}

class _GreetingHeaderState extends ConsumerState<GreetingHeader>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  final List<Map<String, String>> _greetings = [
    {'text': 'Hello', 'lang': 'English'},
    {'text': 'Hola', 'lang': 'Spanish'},
    {'text': 'Bonjour', 'lang': 'French'},
    {'text': 'Hallo', 'lang': 'German'},
    {'text': 'Ciao', 'lang': 'Italian'},
    {'text': 'Olá', 'lang': 'Portuguese'},
    {'text': 'こんにちは', 'lang': 'Japanese'},
    {'text': '안녕하세요', 'lang': 'Korean'},
    {'text': '你好', 'lang': 'Chinese'},
    {'text': 'Привет', 'lang': 'Russian'},
    {'text': 'مرحبا', 'lang': 'Arabic'},
    {'text': 'नमस्ते', 'lang': 'Hindi'},
  ];

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );

    _fadeController.forward();
  }

  void _changeGreeting() {
    _fadeController.reverse().then((_) {
      ref.read(greetingLanguageProvider.notifier).state =
          (ref.read(greetingLanguageProvider) + 1) % _greetings.length;
      _fadeController.forward();
    });
  }

  @override
  void dispose() {
    _fadeController.dispose();
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
                child: AnimatedBuilder(
                  animation: _fadeAnimation,
                  builder: (context, child) {
                    return Opacity(
                      opacity: _fadeAnimation.value,
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
                    );
                  },
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    onPressed: _changeGreeting,
                    icon: Icon(PhosphorIcons.globe()),
                    color: theme.colorScheme.primary,
                    tooltip: 'Change language',
                  ),
                  IconButton(
                    onPressed: () => _showNameDialog(context),
                    icon: Icon(
                      userName.isEmpty ? PhosphorIcons.userPlus() : PhosphorIcons.user(),
                    ),
                    color: theme.colorScheme.primary,
                    tooltip: userName.isEmpty ? 'Set your name' : 'Change name',
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
