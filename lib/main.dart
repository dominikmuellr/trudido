import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart'
    show
        defaultTargetPlatform,
        TargetPlatform; // platform check without BuildContext

import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart'
    show FlutterQuillLocalizations;

import 'services/storage_service.dart';
import 'services/permissions_channel.dart';
import 'services/theme_service.dart';
import 'services/text_scale_service.dart';
import 'providers/app_providers.dart';
import 'services/navigation_service.dart';
import 'services/system_settings_service.dart';
import 'widgets/system_permission_dialogs.dart';
import 'screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize text scale settings
  await initTextScale();

  // Set initial system UI overlay style before app starts
  // This prevents the colored band issue on Samsung Galaxy devices
  _setInitialSystemUIOverlayStyle();

  runApp(const ProviderScope(child: TodoApp()));
}

/// Sets the initial system UI overlay style based on system theme
/// Called before runApp() to ensure proper styling from first frame
void _setInitialSystemUIOverlayStyle() {
  // Get system brightness to determine initial styling
  final platformBrightness =
      WidgetsBinding.instance.platformDispatcher.platformBrightness;

  // Set system UI overlay style based on system theme
  // This provides a reasonable default that works for both light and dark themes
  final overlayStyle = _createSystemUIOverlayStyle(platformBrightness);

  // Debug output to verify the fix is working
  debugPrint(
    '🎨 Setting initial system UI for ${platformBrightness.name} theme',
  );

  SystemChrome.setSystemUIOverlayStyle(overlayStyle);
}

/// Creates SystemUiOverlayStyle based on brightness and theme colors
/// This ensures consistent system UI styling throughout the app
SystemUiOverlayStyle _createSystemUIOverlayStyle(
  Brightness brightness, {
  Color? backgroundColor,
}) {
  final isDark = brightness == Brightness.dark;

  return SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
    statusBarBrightness: brightness,
    systemNavigationBarColor:
        backgroundColor ?? (isDark ? Colors.black : Colors.white),
    systemNavigationBarIconBrightness: isDark
        ? Brightness.light
        : Brightness.dark,
    systemNavigationBarDividerColor: Colors.transparent,
  );
}

class TodoApp extends ConsumerStatefulWidget {
  final bool disableSideEffects;
  const TodoApp({super.key, this.disableSideEffects = false});
  @override
  ConsumerState<TodoApp> createState() => _TodoAppState();
}

class _TodoAppState extends ConsumerState<TodoApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (!widget.disableSideEffects) {
      // Defer reliability flow until after first frame & minimal init.
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _maybeRunInitialReliabilityFlow(),
      );
    }
    // Kick off preferences initialization early so settings apply immediately.
    _initPrefs();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangePlatformBrightness() {
    super.didChangePlatformBrightness();
    // Invalidate dynamic color schemes when platform brightness changes
    // This helps detect system theme/wallpaper changes that affect dynamic colors
    ref.invalidate(dynamicColorSchemesProvider);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // Refresh dynamic colors when app resumes (user might have changed wallpaper)
    if (state == AppLifecycleState.resumed) {
      ref.invalidate(dynamicColorSchemesProvider);
    }
  }

  Future<void> _initPrefs() async {
    final svc = ref.read(preferencesServiceProvider);
    if (!svc.isReady) {
      await svc.ensureInitialized();
      if (mounted) {
        // Push hydrated snapshot into reactive state provider.
        ref.read(preferencesStateProvider.notifier).state = svc.snapshot;
      }
    }
  }

  Future<void> _maybeRunInitialReliabilityFlow() async {
    if (!mounted || widget.disableSideEffects) return;
    try {
      await SystemSettingsService.instance.ensureReady();
    } catch (_) {}
    if (!mounted) return;
    await _maybeRequestNotificationsOnce();
    if (!mounted) return;
    await showExactAlarmDialogIfNeededAuto();
    if (!mounted) return;
    await Future.delayed(const Duration(milliseconds: 250));
    if (!mounted) return;
    await showBatteryOptimizationDialogIfNeededAuto();
  }

  Future<void> _maybeRequestNotificationsOnce() async {
    if (!mounted) return;
    // Touch preferences to ensure early snapshot initialization (no direct use needed)
    ref.read(preferencesStateProvider);
    final isAndroid = defaultTargetPlatform == TargetPlatform.android;
    if (!isAndroid) return;
    const flagKey = 'notif_perm_requested_v1';
    StorageService.kickOffPrefsInit();
    final already = StorageService.getMeta(flagKey);
    if (already == '1') return;
    int sdk = 0;
    for (var attempt = 0; attempt < 5; attempt++) {
      sdk = await PermissionsChannel.instance.getSdkInt();
      if (sdk > 0) break;
      await Future.delayed(Duration(milliseconds: 60 * (attempt + 1)));
    }
    if (sdk == 0) sdk = 33; // assume new enough so prompt path executes once
    if (sdk < 33) {
      StorageService.setMeta(flagKey, '1');
      return;
    }
    final initiallyEnabled = await PermissionsChannel.instance
        .areNotificationsEnabled();
    if (initiallyEnabled) {
      StorageService.setMeta(flagKey, '1');
      return;
    }
    // Wait for localizations / navigator to be ready.
    for (var i = 0; i < 10; i++) {
      final ctx = NavigationService.navigatorKey.currentContext;
      final loc = ctx == null
          ? null
          : Localizations.of<MaterialLocalizations>(ctx, MaterialLocalizations);
      if (loc != null) break;
      await Future.delayed(Duration(milliseconds: 50 * (i + 1)));
    }
    if (!mounted) return;
    final proceed = await _showNotificationPrompt();
    if (proceed == true) {
      await PermissionsChannel.instance.requestPostNotifications();
      const resumeTimeout = Duration(seconds: 8);
      final resumeStart = DateTime.now();
      while (mounted &&
          WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed &&
          DateTime.now().difference(resumeStart) < resumeTimeout) {
        await Future.delayed(const Duration(milliseconds: 150));
      }
      bool enabledNow = false;
      for (var i = 0; i < 8; i++) {
        enabledNow = await PermissionsChannel.instance
            .areNotificationsEnabled();
        if (enabledNow) break;
        await Future.delayed(Duration(milliseconds: 120 * (i + 1)));
      }
      if (!enabledNow && mounted) {
        final open = await _showNotificationStillDisabledPrompt();
        if (open == true) {
          await PermissionsChannel.instance.openAppNotificationSettings();
        }
      }
      StorageService.setMeta(flagKey, '1');
    }
  }

  Future<bool?> _showNotificationPrompt() async {
    try {
      final ctx = NavigationService.navigatorKey.currentContext;
      if (ctx == null) return null;
      return showDialog<bool>(
        context: ctx,
        builder: (dCtx) => AlertDialog(
          title: const Text('Allow Notifications'),
          content: const Text(
            'Enable notifications so task reminders can appear on time.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dCtx, false),
              child: const Text('Later'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dCtx, true),
              child: const Text('Allow'),
            ),
          ],
        ),
      );
    } catch (e) {
      debugPrint('[StartupPerms] dialog error: $e');
      return null;
    }
  }

  Future<bool?> _showNotificationStillDisabledPrompt() async {
    try {
      final ctx = NavigationService.navigatorKey.currentContext;
      if (ctx == null) return null;
      return showDialog<bool>(
        context: ctx,
        builder: (c) => AlertDialog(
          title: const Text('Still Disabled'),
          content: const Text(
            'Notifications are still disabled. Open system notification settings?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Open Settings'),
            ),
          ],
        ),
      );
    } catch (e) {
      debugPrint('[StartupPerms] dialog2 error: $e');
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final prefs = ref.watch(preferencesStateProvider);
    final themeMode = prefs.themeMode == 'light'
        ? ThemeMode.light
        : prefs.themeMode == 'dark'
        ? ThemeMode.dark
        : ThemeMode.system;
    final compact = prefs.compactDensity;
    final highContrast = prefs.highContrast;
    final accentColor = Color(prefs.accentColorSeed);
    final schemesAsync = ref.watch(dynamicColorSchemesProvider);
    final schemes = schemesAsync.value;
    final themes = AppTheme.buildThemes(
      dynamicLight: schemes?.light,
      dynamicDark: schemes?.dark,
      accentColorSeed: accentColor,
      compact: compact,
      highContrast: highContrast,
    );
    final useBlack = ref.watch(blackThemeEnabledProvider);
    // Don't apply black theme to Solarized (or other incompatible themes)
    final isSolarized =
        prefs.accentColorSeed == 0xFF268BD2 && !prefs.useDynamicColor;
    final darkThemeEffective = (useBlack && !isSolarized)
        ? AppTheme.blackify(themes.$2)
        : themes.$2;

    return ValueListenableBuilder<double>(
      valueListenable: textScaleNotifier,
      builder: (context, scale, _) {
        return ValueListenableBuilder<bool>(
          valueListenable: ignoreSystemNotifier,
          builder: (context, ignoreSystem, __) {
            return MaterialApp(
              title: 'Trudido',
              debugShowCheckedModeBanner: false,
              navigatorKey: NavigationService.navigatorKey,
              theme: themes.$1,
              darkTheme: darkThemeEffective,
              themeMode: themeMode,
              localizationsDelegates: [
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
                FlutterQuillLocalizations.delegate,
              ],
              supportedLocales: const [Locale('en')],
              // Ensure MaterialApp uses theme background color to prevent visual gaps
              // This helps eliminate the colored band issue on Samsung Galaxy devices
              builder: (context, child) {
                // Apply system UI overlay style that matches the current theme
                final currentTheme = Theme.of(context);
                final overlayStyle = _createSystemUIOverlayStyle(
                  currentTheme.brightness,
                  backgroundColor: currentTheme.scaffoldBackgroundColor,
                );
                SystemChrome.setSystemUIOverlayStyle(overlayStyle);

                // Apply text scale factor
                final mq = MediaQuery.of(context);
                final effective = ignoreSystem
                    ? scale
                    : mq.textScaleFactor * scale;

                return MediaQuery(
                  data: mq.copyWith(textScaleFactor: effective),
                  child: child ?? const SizedBox.shrink(),
                );
              },
              home: const SystemNavigationBarHandler(child: AppBootstrap()),
            );
          },
        );
      },
    );
  }
}

/// Lightweight first-frame widget that shows a minimal splash while heavy
/// async initialization (Hive boxes, notifications) completes.
class AppBootstrap extends StatefulWidget {
  const AppBootstrap({super.key});
  @override
  State<AppBootstrap> createState() => _AppBootstrapState();
}

class _AppBootstrapState extends State<AppBootstrap>
    with SingleTickerProviderStateMixin {
  bool _ready = false;
  late final AnimationController _fadeCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 250),
  );

  @override
  void initState() {
    super.initState();
    // Defer heavy init until after first frame so initial paint is fast.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        await StorageService.init();
      } catch (e) {
        debugPrint('[Bootstrap] storage init error: $e');
      }
      if (!mounted) return;
      setState(() {
        _ready = true;
      });
      _fadeCtrl.forward();
    });
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return const Scaffold(
        body: Center(
          child: SizedBox(
            width: 42,
            height: 42,
            child: CircularProgressIndicator(strokeWidth: 3),
          ),
        ),
      );
    }
    return FadeTransition(opacity: _fadeCtrl, child: const HomeScreen());
  }
}

class SystemNavigationBarHandler extends StatelessWidget {
  final Widget child;
  const SystemNavigationBarHandler({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    // Apply system UI overlay style that matches the current theme
    // This works in conjunction with the initial styling set in main()
    final currentTheme = Theme.of(context);
    final overlayStyle = _createSystemUIOverlayStyle(
      currentTheme.brightness,
      backgroundColor: currentTheme.scaffoldBackgroundColor,
    );
    SystemChrome.setSystemUIOverlayStyle(overlayStyle);

    return child;
  }
}
