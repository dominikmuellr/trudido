import 'package:flutter/material.dart';
import 'dart:io' show Platform; // For test environment detection
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'services/storage_service.dart';
import 'services/permissions_channel.dart';
import 'services/theme_service.dart';
import 'services/notification_service.dart';
import 'services/notification_action_sync.dart';
import 'services/navigation_service.dart';
import 'services/lifecycle_sync_observer.dart';
import 'screens/home_screen.dart';
import 'widgets/system_permission_dialogs.dart';
import 'widgets/alarm_settings_watcher.dart';
import 'services/system_settings_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Do not initialize heavy storage here; defer inside bootstrap widget.
  // Root container
  final container = ProviderContainer();
  runApp(UncontrolledProviderScope(container: container, child: const TodoApp()));

  // Defer heavier native/channel init until after first frame for startup perf
  WidgetsBinding.instance.addPostFrameCallback((_) async {
    try {
      await NotificationBridge.instance.initialize();
      await NotificationActionSync.instance.initialize(container);
    } catch (e) { debugPrint('[Startup] deferred init error: $e'); }
  });
}

class TodoApp extends ConsumerStatefulWidget {
  const TodoApp({super.key});
  @override
  ConsumerState<TodoApp> createState() => _TodoAppState();
}

class _TodoAppState extends ConsumerState<TodoApp> {
  LifecycleSyncObserver? _observer; // existing action sync observer
  AlarmSettingsWatcher? _alarmSettingsWatcher; // new unified settings watcher
  bool get _isTestEnv => Platform.environment.containsKey('FLUTTER_TEST');
  bool _ranReliabilityFlow = false; // guard to avoid duplicate dialog chains

  @override
  void initState() {
    super.initState();
    // Defer observer setup until first frame so ProviderScope is in the widget tree.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _observer = LifecycleSyncObserver(ProviderScope.containerOf(context))..start();
      _alarmSettingsWatcher = AlarmSettingsWatcher()..start();
      if (!_isTestEnv) {
        // Defer reliability flow until storage (settings + prefs) initialized.
        // Boxes/categories may still be deferred, but settings/prefs ready.
        Future(() async {
          try {
            await StorageService.ensureReady();
          } catch (_) {}
          if (!mounted) return;
          if (!_ranReliabilityFlow) {
            _ranReliabilityFlow = true;
            _maybeRunInitialReliabilityFlow();
          }
        });
      }
    });
  }

  @override
  void dispose() {
  _observer?.dispose();
  _alarmSettingsWatcher?.disposeWatcher();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeNotifierProvider);
    return MaterialApp(
      title: 'Trudido',
      debugShowCheckedModeBanner: false,
      navigatorKey: NavigationService.navigatorKey,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
  home: const SystemNavigationBarHandler(child: AppBootstrap()),
    );
  }

  Future<void> _maybeRunInitialReliabilityFlow() async {
    if (!mounted) return;
    // Ensure native channel is ready before any permission dialogs (avoids MissingPluginException on cold start)
    try { await SystemSettingsService.instance.ensureReady(); } catch (_) {}
    if (!mounted) return;
    // First, on Android 13+ request notifications if not yet granted (only once)
    await _maybeRequestNotificationsOnce();
    if (!mounted) return;
    // Then show other reliability dialogs (exact alarm, battery optimization)
  final dialogContext = NavigationService.navigatorKey.currentContext ?? context;
  await showExactAlarmDialogIfNeeded(dialogContext);
  if (!mounted) return;
  // Small delay to avoid stacking dialogs back-to-back visually.
  await Future.delayed(const Duration(milliseconds: 250));
  if (!mounted) return;
  await showBatteryOptimizationDialogIfNeeded(dialogContext);
  }

  Future<void> _maybeRequestNotificationsOnce() async {
    if (!mounted) return;
    if (!(Theme.of(context).platform == TargetPlatform.android)) return;
  // Simple key using SharedPreferences now (removed Hive settings box)
  const flagKey = 'notif_perm_requested_v1';
  StorageService.kickOffPrefsInit();
  final already = StorageService.getMeta(flagKey); // reuse meta namespace
  if (already == '1') return; // already ran
    // Retry getSdkInt a few times because channel may not yet be attached; wrapper returns 0 on error.
    int sdk = 0;
    for (var attempt = 0; attempt < 5; attempt++) {
      sdk = await PermissionsChannel.instance.getSdkInt();
      if (sdk > 0) break;
      await Future.delayed(Duration(milliseconds: 60 * (attempt + 1)));
    }
    if (sdk == 0) {
      debugPrint('[StartupPerms] getSdkInt unresolved after retries; assuming 33+ to be safe');
      sdk = 33; // assume new enough so we attempt permission prompt
    }
  if (sdk < 33) { StorageService.setMeta(flagKey, '1'); return; }
    final initiallyEnabled = await PermissionsChannel.instance.areNotificationsEnabled();
  if (initiallyEnabled) { StorageService.setMeta(flagKey, '1'); return; }

    // Wait until MaterialLocalizations available to avoid "No MaterialLocalizations found" error.
    for (var i = 0; i < 10; i++) {
      if (!mounted) return;
      final loc = Localizations.of<MaterialLocalizations>(context, MaterialLocalizations);
      if (loc != null) break;
      await Future.delayed(Duration(milliseconds: 50 * (i + 1)));
    }
    if (!mounted) return;

    final dialogContext = NavigationService.navigatorKey.currentContext ?? context;
    bool? proceed;
    try {
      proceed = await showDialog<bool>(
        context: dialogContext,
        builder: (ctx) => AlertDialog(
          title: const Text('Allow Notifications'),
          content: const Text('Enable notifications so task reminders can appear on time.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Later')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Allow')),
          ],
        ),
      );
    } catch (e) {
      debugPrint('[StartupPerms] showDialog threw: $e');
    }
    if (proceed == true) {
      await PermissionsChannel.instance.requestPostNotifications();
      // Wait until the app resumes (permission sheet dismissed) or timeout
      const resumeTimeout = Duration(seconds: 8);
      final resumeStart = DateTime.now();
      while (mounted && WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed && DateTime.now().difference(resumeStart) < resumeTimeout) {
        await Future.delayed(const Duration(milliseconds: 150));
      }
      // Poll for permission state (user may take a moment or system may not update instantly)
      bool enabledNow = false;
      for (var i = 0; i < 8; i++) {
        enabledNow = await PermissionsChannel.instance.areNotificationsEnabled();
        if (enabledNow) break;
        await Future.delayed(Duration(milliseconds: 120 * (i + 1)));
      }
  if (!enabledNow && mounted) {
        // Only now show secondary rationale
        bool? open;
        try {
          open = await showDialog<bool>(
            context: dialogContext,
            builder: (c) => AlertDialog(
              title: const Text('Still Disabled'),
              content: const Text('Notifications are still disabled. Open system notification settings?'),
              actions: [
                TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
                FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Open Settings')),
              ],
            ),
          );
        } catch (e) { debugPrint('[StartupPerms] secondary dialog error: $e'); }
        if (open == true) {
          await PermissionsChannel.instance.openAppNotificationSettings();
        }
      }
    }
  StorageService.setMeta(flagKey, '1'); // mark flow done so we do not spam user on subsequent launches
  }
}

/// Lightweight first-frame widget that shows a minimal splash while heavy
/// async initialization (Hive boxes, notifications) completes.
class AppBootstrap extends StatefulWidget {
  const AppBootstrap({super.key});
  @override
  State<AppBootstrap> createState() => _AppBootstrapState();
}

class _AppBootstrapState extends State<AppBootstrap> with SingleTickerProviderStateMixin {
  bool _ready = false;
  late final AnimationController _fadeCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 350));

  @override
  void initState() {
    super.initState();
    // Defer heavy init until after first frame so initial paint is fast.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        await StorageService.init();
      } catch (e) { debugPrint('[Bootstrap] storage init error: $e'); }
      if (!mounted) return;
      setState(() { _ready = true; });
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
          child: SizedBox(width: 42, height: 42, child: CircularProgressIndicator(strokeWidth: 3)),
        ),
      );
    }
    return FadeTransition(
      opacity: _fadeCtrl,
      child: const HomeScreen(),
    );
  }
}

class SystemNavigationBarHandler extends StatelessWidget {
  final Widget child;
  const SystemNavigationBarHandler({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final scaffoldBackgroundColor = Theme.of(context).scaffoldBackgroundColor;
    final brightness = Theme.of(context).brightness;
    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        systemNavigationBarColor: scaffoldBackgroundColor,
        systemNavigationBarIconBrightness: brightness == Brightness.dark
            ? Brightness.light
            : Brightness.dark,
      ),
    );
    return child;
  }
}
