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
import 'models/custom_theme.dart';
import 'services/auto_backup_service.dart';
import 'services/permissions_channel.dart';
import 'services/theme_service.dart';
import 'services/text_scale_service.dart';
import 'services/widget_service.dart';
import 'services/notification_service.dart';
import 'services/notification_action_sync.dart';
import 'providers/app_providers.dart';
import 'providers/filter_providers.dart';
import 'services/folder_provider.dart';
import 'services/navigation_service.dart';
import 'services/system_settings_service.dart';
import 'widgets/system_permission_dialogs.dart';
import 'widgets/app_lock_wrapper.dart';
import 'screens/home_screen.dart';
import 'widgets/common/common.dart';
import 'utils/state_notifiers.dart';

/// Provider to signal widget-triggered task creation request.
/// HomeScreen listens to this and opens TaskEditorScreen when triggered.
final widgetTaskCreationRequestProvider = stateProvider<int>(0);

/// Provider for widget task creation date
final widgetTaskCreationDateProvider = stateProvider<DateTime?>(null);

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
      // Cache backup data for auto-backup when app becomes active
      _cacheBackupDataIfNeeded();
    }
  }

  /// Caches backup data for auto-backup if auto-backup is enabled
  Future<void> _cacheBackupDataIfNeeded() async {
    try {
      final isScheduled = await AutoBackupService.instance
          .isAutoBackupScheduled();
      if (isScheduled) {
        debugPrint('[Main] Auto-backup is enabled, caching backup data...');
        await AutoBackupService.instance.cacheBackupData();
      }
    } catch (e) {
      debugPrint('[Main] Error caching backup data: $e');
    }
  }

  Future<void> _initPrefs() async {
    final svc = ref.read(preferencesServiceProvider);
    if (!svc.isReady) {
      await svc.ensureInitialized();
      if (mounted) {
        // Push hydrated snapshot into reactive state provider.
        ref.read(preferencesStateProvider.notifier).update(svc.snapshot);
      }
    }

    // Hydrate showCompletedProvider from persisted storage
    if (mounted) {
      // Ensure SharedPreferences is ready before reading the persisted value
      await StorageService.ensurePrefs();
      final savedShowCompleted = StorageService.getShowCompletedTasks();
      ref.read(showCompletedProvider.notifier).update(savedShowCompleted);

      // Listen for changes and persist them
      ref.listen<bool>(showCompletedProvider, (previous, next) {
        StorageService.setShowCompletedTasks(next);
      });

      // Restore last selected folder if it exists and is still valid
      final lastSelectedFolder = StorageService.getLastSelectedFolder();
      if (lastSelectedFolder != null) {
        ref.read(selectedFolderProvider.notifier).update(lastSelectedFolder);
      }

      // Listen for folder selection changes and persist them
      ref.listen<String?>(selectedFolderProvider, (previous, next) {
        if (next != null) {
          StorageService.setLastSelectedFolder(next);
        }
      });
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
    await _waitForLocalizations();
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

  /// Waits until MaterialLocalizations are available via the navigator.
  static Future<void> _waitForLocalizations() async {
    for (var i = 0; i < 10; i++) {
      if (NavigationService.navigatorKey.currentContext != null) {
        return;
      }
      await Future.delayed(Duration(milliseconds: 50 * (i + 1)));
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
            ExpressiveTextButton(
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
            ExpressiveTextButton(
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
    final contrastLevel = prefs.contrastLevel;
    final accentColor = Color(prefs.accentColorSeed);
    final fontFamily = prefs.fontFamily;
    final schemesAsync = ref.watch(dynamicColorSchemesProvider);
    final schemes = schemesAsync.value;

    // Load active custom theme if set
    ColorScheme? customLightScheme;
    ColorScheme? customDarkScheme;
    final activeCustomId = prefs.activeCustomThemeId;
    // Watch revision counter to rebuild when custom theme content changes
    ref.watch(customThemeRevisionProvider);
    if (activeCustomId != null && !prefs.useDynamicColor) {
      final themeJson = StorageService.getCustomTheme(activeCustomId);
      if (themeJson != null) {
        try {
          final customTheme = CustomTheme.fromJsonString(themeJson);
          customLightScheme = customTheme.buildColorScheme(Brightness.light);
          customDarkScheme = customTheme.buildColorScheme(Brightness.dark);
        } catch (_) {}
      }
    }

    final themes = AppTheme.buildThemes(
      dynamicLight: schemes?.light,
      dynamicDark: schemes?.dark,
      accentColorSeed: accentColor,
      fontFamily: fontFamily,
      compact: compact,
      highContrast: highContrast,
      contrastLevel: contrastLevel,
      customLightScheme: customLightScheme,
      customDarkScheme: customDarkScheme,
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
          builder: (context, ignoreSystem, _) {
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
                    : mq.textScaler.scale(1.0) * scale;

                return MediaQuery(
                  data: mq.copyWith(textScaler: TextScaler.linear(effective)),
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
class AppBootstrap extends ConsumerStatefulWidget {
  const AppBootstrap({super.key});
  @override
  ConsumerState<AppBootstrap> createState() => _AppBootstrapState();
}

class _AppBootstrapState extends ConsumerState<AppBootstrap>
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
        debugPrint('[Bootstrap] ✓ StorageService initialized');

        // Initialize notification bridge (sets up method channel handlers)
        await NotificationBridge.instance.initialize();
        debugPrint('[Bootstrap] ✓ NotificationBridge initialized');

        // Initialize notification action sync (pulls pending actions from native)
        if (!mounted) return;
        await NotificationActionSync.instance.initialize(
          ProviderScope.containerOf(context),
        );
        debugPrint('[Bootstrap] ✓ NotificationActionSync initialized');

        // Initialize lifecycle observer (handles widget sync)
        ref.read(lifecycleSyncObserverProvider);

        // Initialize widget service
        await WidgetService.instance.initialize();
        debugPrint('[Bootstrap] ✓ WidgetService initialized');

        // Listen for task creation requests from widget
        WidgetService.instance.onOpenTaskCreation.listen((dateMillis) {
          _openTaskCreation(dateMillis);
        });
        // Update widget with current tasks after storage is ready
        _updateWidgetData();
      } catch (e, st) {
        debugPrint('[Bootstrap] ✗ Initialization error: $e');
        debugPrint('[Bootstrap] Stack trace: $st');
      }
      if (!mounted) return;
      setState(() {
        _ready = true;
      });
      _fadeCtrl.forward();
    });
  }

  void _openTaskCreation(int? dateMillis) {
    // Trigger task creation via provider that HomeScreen listens to
    // This increments a counter which HomeScreen listens to and opens TaskEditorScreen
    if (dateMillis != null) {
      ref
          .read(widgetTaskCreationDateProvider.notifier)
          .update(DateTime.fromMillisecondsSinceEpoch(dateMillis));
    } else {
      ref.read(widgetTaskCreationDateProvider.notifier).update(null);
    }
    final currentCount = ref.read(widgetTaskCreationRequestProvider);
    ref
        .read(widgetTaskCreationRequestProvider.notifier)
        .update(currentCount + 1);
    debugPrint('[Bootstrap] Triggered task creation from widget');
  }

  Future<void> _updateWidgetData() async {
    try {
      final tasks = ref.read(tasksProvider);
      final incomplete = tasks.where((t) => !t.isCompleted).toList();
      await WidgetService.instance.updateWidgetData(incomplete);
    } catch (e) {
      debugPrint('[Bootstrap] widget update error: $e');
    }
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
    return FadeTransition(
      opacity: _fadeCtrl,
      child: const AppLockWrapper(child: HomeScreen()),
    );
  }
}

class SystemNavigationBarHandler extends StatelessWidget {
  final Widget child;
  const SystemNavigationBarHandler({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    // Apply system UI overlay style that matches the current theme
    // Using AnnotatedRegion is more reliable than SystemChrome.setSystemUIOverlayStyle
    final currentTheme = Theme.of(context);
    final overlayStyle = _createSystemUIOverlayStyle(
      currentTheme.brightness,
      backgroundColor: currentTheme.colorScheme.surface,
    );

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: overlayStyle,
      child: child,
    );
  }
}
