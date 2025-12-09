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
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/app_lock_service.dart';
import '../services/biometric_auth_service.dart';
import '../screens/lock_screen.dart';

/// Provider to track app lock state
final appLockedProvider = StateProvider<bool>((ref) => true);

/// Widget that wraps the app and shows lock screen when needed
class AppLockWrapper extends ConsumerStatefulWidget {
  final Widget child;

  const AppLockWrapper({super.key, required this.child});

  @override
  ConsumerState<AppLockWrapper> createState() => _AppLockWrapperState();
}

class _AppLockWrapperState extends ConsumerState<AppLockWrapper>
    with WidgetsBindingObserver {
  bool _isLocked = true;
  bool _isCheckingLock = true;
  DateTime? _pausedAt;
  DateTime? _lastUnlockTime; // Track when we last unlocked

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkInitialLockState();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _checkInitialLockState() async {
    final shouldLock = await AppLockService.instance.shouldLock();

    if (mounted) {
      setState(() {
        _isLocked = shouldLock;
        _isCheckingLock = false;
      });
      ref.read(appLockedProvider.notifier).state = shouldLock;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    debugPrint(
      '[AppLockWrapper] Lifecycle: $state, isLocked=$_isLocked, biometricInProgress=${BiometricAuthService.isAuthInProgress}',
    );

    // Ignore all lifecycle events while locked - biometric dialogs cause these
    if (_isLocked) {
      debugPrint('[AppLockWrapper] Ignoring - still locked');
      return;
    }

    // Ignore lifecycle events when any biometric auth is in progress (including vault)
    if (BiometricAuthService.isAuthInProgress) {
      debugPrint('[AppLockWrapper] Ignoring - biometric auth in progress');
      return;
    }

    if (state == AppLifecycleState.paused) {
      // Only record pause when actually going to background (not for dialogs)
      _pausedAt = DateTime.now();
      debugPrint('[AppLockWrapper] Recording pause time');
    } else if (state == AppLifecycleState.resumed) {
      // Check lock on resume
      debugPrint('[AppLockWrapper] Checking lock on resume...');
      _checkLockOnResume();
    }
  }

  Future<void> _checkLockOnResume() async {
    // Skip if we just unlocked (grace period to prevent immediate re-lock from biometric dialog lifecycle)
    if (_lastUnlockTime != null) {
      final sinceUnlock = DateTime.now()
          .difference(_lastUnlockTime!)
          .inMilliseconds;
      if (sinceUnlock < 2000) {
        debugPrint(
          '[AppLockWrapper] Skipping lock check - just unlocked ${sinceUnlock}ms ago',
        );
        return;
      }
    }

    // Skip if any biometric auth just completed (e.g., vault unlock)
    if (BiometricAuthService.lastAuthCompletedTime != null) {
      final sinceAuth = DateTime.now()
          .difference(BiometricAuthService.lastAuthCompletedTime!)
          .inMilliseconds;
      if (sinceAuth < 2000) {
        debugPrint(
          '[AppLockWrapper] Skipping lock check - biometric auth completed ${sinceAuth}ms ago',
        );
        return;
      }
    }

    final enabled = await AppLockService.instance.isEnabled();
    if (!enabled) return;

    final timeout = await AppLockService.instance.getTimeout();

    // -1 means never lock while running
    if (timeout == -1) return;

    // 0 means immediate lock
    if (timeout == 0) {
      _lock();
      return;
    }

    // Check if timeout has passed
    if (_pausedAt != null) {
      final elapsed = DateTime.now().difference(_pausedAt!).inSeconds;
      if (elapsed >= timeout) {
        _lock();
      }
    }
  }

  void _lock() {
    if (mounted) {
      setState(() {
        _isLocked = true;
      });
      ref.read(appLockedProvider.notifier).state = true;
      AppLockService.instance.lock();
    }
  }

  void _unlock() {
    if (mounted) {
      setState(() {
        _isLocked = false;
      });
      ref.read(appLockedProvider.notifier).state = false;
      // Clear pause time and record unlock time to prevent immediate re-lock
      _pausedAt = null;
      _lastUnlockTime = DateTime.now();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Still checking initial state
    if (_isCheckingLock) {
      return Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // Show lock screen if locked
    if (_isLocked) {
      return LockScreen(onUnlocked: _unlock);
    }

    // Show normal app
    return widget.child;
  }
}
