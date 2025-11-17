import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:math';

import '../services/theme_service.dart';
import '../providers/app_providers.dart';
import '../providers/clock.dart';
import '../services/storage_service.dart';

// Matrix Rain Animation Widget for Hack Theme
class MatrixNameAnimation extends StatefulWidget {
  final String text;
  final TextStyle style;

  const MatrixNameAnimation({
    super.key,
    required this.text,
    required this.style,
  });

  @override
  State<MatrixNameAnimation> createState() => _MatrixNameAnimationState();
}

class _MatrixNameAnimationState extends State<MatrixNameAnimation>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  final ValueNotifier<List<String>> _currentCharsNotifier = ValueNotifier([]);
  final Random _random = Random();

  // Matrix-style characters for the animation
  final List<String> _matrixChars = [
    'ｱ',
    'ｲ',
    'ｳ',
    'ｴ',
    'ｵ',
    'ｶ',
    'ｷ',
    'ｸ',
    'ｹ',
    'ｺ',
    'ｻ',
    'ｼ',
    'ｽ',
    'ｾ',
    'ｿ',
    'ﾀ',
    'ﾁ',
    'ﾂ',
    'ﾃ',
    'ﾄ',
    'ﾅ',
    'ﾆ',
    'ﾇ',
    'ﾈ',
    'ﾉ',
    'ﾊ',
    'ﾋ',
    'ﾌ',
    'ﾍ',
    'ﾎ',
    '0',
    '1',
    '2',
    '3',
    '4',
    '5',
    '6',
    '7',
    '8',
    '9',
    'A',
    'B',
    'C',
    'D',
    'E',
    'F',
    'G',
    'H',
    'I',
    'J',
    'K',
    'L',
    'M',
    'N',
    'O',
    'P',
    'Q',
    'R',
    'S',
    'T',
    'U',
    'V',
    'W',
    'X',
    'Y',
    'Z',
  ];

  late List<String> _finalMatrixChars;

  // Special Matrix Katakana characters for final username display
  final List<String> _matrixKatakana = [
    'ｱ',
    'ｲ',
    'ｳ',
    'ｴ',
    'ｵ',
    'ｶ',
    'ｷ',
    'ｸ',
    'ｹ',
    'ｺ',
    'ｻ',
    'ｼ',
    'ｽ',
    'ｾ',
    'ｿ',
    'ﾀ',
    'ﾁ',
    'ﾂ',
    'ﾃ',
    'ﾄ',
    'ﾅ',
    'ﾆ',
    'ﾇ',
    'ﾈ',
    'ﾉ',
    'ﾊ',
    'ﾋ',
    'ﾌ',
    'ﾍ',
    'ﾎ',
  ];

  // Generate consistent Matrix characters for the final text
  String _generateMatrixChar(String originalChar, int index) {
    if (originalChar == ' ') return ' ';
    if (originalChar == '!') return '!';
    if (originalChar == ',') return ',';

    // Use character and position to generate consistent Matrix Katakana character
    final seed = originalChar.codeUnitAt(0) + index;
    final matrixIndex = seed % _matrixKatakana.length;
    return _matrixKatakana[matrixIndex];
  }

  @override
  void initState() {
    super.initState();
    _initializeAnimation();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _controller.addListener(_updateAnimation);
    _startAnimation();
  }

  void _initializeAnimation() {
    _currentCharsNotifier.value = widget.text.split('');
    // Generate consistent Matrix characters for the final state
    _finalMatrixChars = widget.text
        .split('')
        .asMap()
        .entries
        .map((entry) => _generateMatrixChar(entry.value, entry.key))
        .toList();
  }

  void _startAnimation() {
    _controller.reset();
    _controller.forward();
  }

  void _updateAnimation() {
    if (!mounted) return;

    final progress = _controller.value;
    final current = List<String>.from(_currentCharsNotifier.value);
    if (progress < 0.8) {
      // Still animating - show random characters for the entire string
      if (_random.nextDouble() < 0.3) {
        for (int i = 0; i < current.length; i++) {
          current[i] = _matrixChars[_random.nextInt(_matrixChars.length)];
        }
        _currentCharsNotifier.value = current;
      }
    } else {
      // Animation complete - show final Matrix characters instead of original text
      for (int i = 0; i < current.length; i++) {
        current[i] = _finalMatrixChars[i];
      }
      _currentCharsNotifier.value = current;
    }
  }

  @override
  void didUpdateWidget(MatrixNameAnimation oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) {
      _initializeAnimation();
      _startAnimation();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _currentCharsNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _currentCharsNotifier,
      builder: (context, child) {
        return Text(
          _currentCharsNotifier.value.join(''),
          style: widget.style.copyWith(
            color: const Color(0xFF00FF00), // Matrix green
            shadows: [
              Shadow(
                color: const Color(0xFF00FF00).withValues(alpha: 0.8),
                blurRadius: 8,
              ),
              Shadow(
                color: const Color(0xFF00FF00).withValues(alpha: 0.4),
                blurRadius: 16,
              ),
            ],
          ),
          overflow: TextOverflow.ellipsis,
        );
      },
    );
  }
}

// Provider for user's name
final userNameProvider = StateProvider<String>(
  (ref) => StorageService.getUserName(),
);

// Provider for current greeting language - directly reads from preferences
final greetingLanguageProvider = Provider<int>((ref) {
  final prefs = ref.watch(preferencesStateProvider);
  // Use the greeting language from preferences
  return prefs.greetingLanguage;
});

// Provider for hide greeting preference
// hideGreeting now sourced from unified preferences state; mutation via controller.
final hideGreetingProvider = Provider<bool>(
  (ref) => ref.watch(preferencesStateProvider).hideGreeting,
);

class GreetingHeader extends ConsumerStatefulWidget {
  const GreetingHeader({super.key});

  @override
  ConsumerState<GreetingHeader> createState() => _GreetingHeaderState();
}

class _GreetingHeaderState extends ConsumerState<GreetingHeader> {
  final List<Map<String, String>> _greetings = [
    {'text': 'Hello', 'lang': 'English'},
    {'text': 'Hola', 'lang': 'Español'},
    {'text': 'Bonjour', 'lang': 'Français'},
    {'text': 'Hallo', 'lang': 'Deutsch'},
    {'text': 'Ciao', 'lang': 'Italiano'},
    {'text': 'Hallo', 'lang': 'Nederlands'},
    {'text': 'Olá', 'lang': 'Português'},
    {'text': 'Hej', 'lang': 'Svenska'},
    {'text': 'Hej', 'lang': 'Dansk'},
    {'text': 'Hei', 'lang': 'Norsk'},
    {'text': 'Hei', 'lang': 'Suomi'},
    {'text': 'Cześć', 'lang': 'Polski'},
    {'text': 'Ahoj', 'lang': 'Čeština'},
    {'text': 'Szia', 'lang': 'Magyar'},
    {'text': 'Salut', 'lang': 'Română'},
    {'text': 'Merhaba', 'lang': 'Türkçe'},
    {'text': 'Привіт', 'lang': 'Українська'},
  ];

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final userName = ref.watch(userNameProvider);
    final greetingIndex = ref.watch(greetingLanguageProvider);
    // Add bounds checking to prevent index out of range errors
    final safeGreetingIndex = greetingIndex.clamp(0, _greetings.length - 1);
    final greeting = _greetings[safeGreetingIndex];
    final theme = Theme.of(context);
    final preferences = ref.watch(preferencesStateProvider);
    final isHackTheme =
        preferences.accentColorSeed == 0xFF00FF00 && // Matrix green
        !preferences
            .useDynamicColor; // Dynamic colors should override hack theme
    final appOpts =
        theme.extension<AppOptions>() ??
        const AppOptions(compact: false, highContrast: false);
    final pad = EdgeInsets.all(appOpts.compact ? 12 : 20);
    final headlineStyle = theme.textTheme.titleMedium?.copyWith(
      fontWeight: FontWeight.bold,
      fontSize: appOpts.compact ? 16 : null,
      color: theme.colorScheme.primary,
    );
    final langStyle = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.secondary.withValues(alpha: 0.8),
      fontSize: appOpts.compact ? 10 : null,
    );
    final messageStyle = theme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.secondary,
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
                  duration: const Duration(milliseconds: 300),
                  transitionBuilder: (child, animation) =>
                      FadeTransition(opacity: animation, child: child),
                  child: Align(
                    key: ValueKey<int>(safeGreetingIndex),
                    alignment: Alignment.centerLeft,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        isHackTheme && userName.isNotEmpty
                            ? Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      '${greeting['text']}, ',
                                      style: headlineStyle,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  Flexible(
                                    child: userName.isNotEmpty
                                        ? GestureDetector(
                                            onTap: () =>
                                                _showNameDialog(context),
                                            child: MatrixNameAnimation(
                                              text: '$userName!',
                                              style:
                                                  headlineStyle ??
                                                  const TextStyle(),
                                            ),
                                          )
                                        : MatrixNameAnimation(
                                            text: '$userName!',
                                            style:
                                                headlineStyle ??
                                                const TextStyle(),
                                          ),
                                  ),
                                ],
                              )
                            : GestureDetector(
                                onTap: () => _showNameDialog(context),
                                child: Text(
                                  _getGreetingText(greeting['text']!, userName),
                                  style: headlineStyle?.copyWith(
                                    color: _shouldShowNameHint(userName)
                                        ? theme.colorScheme.primary.withValues(
                                            alpha: 0.8,
                                          )
                                        : theme.colorScheme.primary,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                        // Show language name
                        Text(greeting['lang']!, style: langStyle),
                        // Time-based message as subtitle
                        const SizedBox(height: 4),
                        Text(_getTimeBasedMessage(), style: messageStyle),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _getTimeBasedMessage() {
    final hour = ref.read(clockProvider).now().hour;
    if (hour < 12) {
      return 'Ready to tackle your morning tasks?';
    } else if (hour < 17) {
      return 'How\'s your day going so far?';
    } else {
      return 'Time to wrap up the day!';
    }
  }

  void _showNameDialog(BuildContext context) {
    final currentName = ref.read(userNameProvider);
    final textController = TextEditingController(
      text: (currentName == '_SKIP_NAME_' || currentName == '_CLEARED_NAME_')
          ? ''
          : currentName,
    );
    final hasName =
        currentName.isNotEmpty &&
        currentName != '_SKIP_NAME_' &&
        currentName != '_CLEARED_NAME_';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(hasName ? 'Change your name' : 'What\'s your name?'),
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
          // Show "Clear" option if user currently has a name
          if (hasName)
            TextButton(
              onPressed: () async {
                // Use a special marker to indicate user cleared their name (different from never setting one)
                await StorageService.setUserName('_CLEARED_NAME_');
                ref.read(userNameProvider.notifier).state = '_CLEARED_NAME_';
                if (context.mounted) Navigator.pop(context);
              },
              child: const Text('Clear'),
            ),
          // Show "Skip" option only if user has no name currently
          if (!hasName)
            TextButton(
              onPressed: () async {
                // Set a special marker to indicate user chose not to use name
                await StorageService.setUserName('_SKIP_NAME_');
                ref.read(userNameProvider.notifier).state = '_SKIP_NAME_';
                if (context.mounted) Navigator.pop(context);
              },
              child: const Text('Skip'),
            ),
          TextButton(
            onPressed: () async {
              final name = textController.text.trim();
              if (name.isNotEmpty) {
                await StorageService.setUserName(name);
                ref.read(userNameProvider.notifier).state = name;
              }
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  String _getGreetingText(String greetingText, String userName) {
    if (userName.isEmpty) {
      return '$greetingText! Tap here to set your name';
    } else if (userName == '_SKIP_NAME_' || userName == '_CLEARED_NAME_') {
      return '$greetingText!';
    } else {
      return '$greetingText, $userName!';
    }
  }

  bool _shouldShowNameHint(String userName) {
    return userName.isEmpty;
  }
}
