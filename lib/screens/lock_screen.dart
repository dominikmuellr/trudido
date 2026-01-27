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
import '../services/app_lock_service.dart';
import '../services/biometric_auth_service.dart';
import '../theme/spacing_tokens.dart';
import '../widgets/common/common.dart';

/// Lock screen that requires PIN or biometric authentication
class LockScreen extends StatefulWidget {
  final VoidCallback onUnlocked;

  const LockScreen({super.key, required this.onUnlocked});

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  String _enteredPin = '';
  bool _isLoading = false;
  String? _errorMessage;
  bool _biometricAvailable = false;
  bool _biometricEnabled = false;
  int _failedAttempts = 0;

  @override
  void initState() {
    super.initState();
    debugPrint('[LockScreen] initState called');
    _checkBiometricAvailability();
  }

  Future<void> _checkBiometricAvailability() async {
    final available = await BiometricAuthService.isBiometricsAvailable();
    final enabled = await AppLockService.instance.isBiometricEnabled();
    final alreadyAttempted =
        AppLockService.instance.biometricAttemptedThisSession;
    final inProgress = AppLockService.instance.isBiometricAuthInProgress;

    debugPrint(
      '[LockScreen] available=$available, enabled=$enabled, alreadyAttempted=$alreadyAttempted, inProgress=$inProgress',
    );

    setState(() {
      _biometricAvailable = available;
      _biometricEnabled = enabled;
    });

    // Auto-trigger biometric only once per lock session (tracked in service)
    if (available && enabled && !alreadyAttempted) {
      debugPrint('[LockScreen] Auto-triggering biometric...');
      AppLockService.instance.markBiometricAttempted();
      _tryBiometricUnlock();
    } else {
      debugPrint('[LockScreen] Skipping auto-trigger');
    }
  }

  Future<void> _tryBiometricUnlock() async {
    // Service-level guard prevents concurrent attempts
    if (AppLockService.instance.isBiometricAuthInProgress) {
      debugPrint(
        '[LockScreen] _tryBiometricUnlock: already in progress, skipping',
      );
      return;
    }

    debugPrint('[LockScreen] _tryBiometricUnlock: starting...');

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final success = await AppLockService.instance.unlockWithBiometrics();
      debugPrint('[LockScreen] Biometric result: $success');
      if (success) {
        debugPrint('[LockScreen] Calling onUnlocked...');
        widget.onUnlocked();
        return;
      } else {
        debugPrint('[LockScreen] Biometric failed or cancelled');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _onKeyPressed(String key) {
    HapticFeedback.lightImpact();

    if (_enteredPin.length >= 6) return;

    setState(() {
      _enteredPin += key;
      _errorMessage = null;
    });
  }

  void _onSubmit() {
    if (_enteredPin.length < 4) {
      setState(() {
        _errorMessage = 'PIN must be at least 4 digits';
      });
      return;
    }
    _verifyPin();
  }

  void _onBackspace() {
    HapticFeedback.lightImpact();

    if (_enteredPin.isEmpty) return;

    setState(() {
      _enteredPin = _enteredPin.substring(0, _enteredPin.length - 1);
      _errorMessage = null;
    });
  }

  Future<void> _verifyPin() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
    });

    // Small delay for UX
    await Future.delayed(const Duration(milliseconds: 100));

    final success = await AppLockService.instance.verifyPin(_enteredPin);

    if (success) {
      widget.onUnlocked();
    } else {
      _failedAttempts++;
      setState(() {
        _isLoading = false;
        _enteredPin = '';
        _errorMessage = _failedAttempts >= 3
            ? 'Incorrect PIN. Please try again.'
            : 'Incorrect PIN';
      });

      // Vibrate on error
      HapticFeedback.heavyImpact();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(flex: 2),

            // App icon or logo
            Icon(Icons.lock_outline, size: 64, color: colorScheme.primary),

            SpacingGap.gapV24,

            // Title
            Text(
              'Trudido is Locked',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),

            SpacingGap.gapV8,

            Text(
              'Enter your PIN to unlock',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),

            const SizedBox(height: 32),

            // PIN dots indicator
            _PinDotsIndicator(
              length: _enteredPin.length,
              maxLength: 6,
              isError: _errorMessage != null,
            ),

            // Error message
            SizedBox(
              height: 40,
              child: _errorMessage != null
                  ? Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(
                        _errorMessage!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.error,
                        ),
                      ),
                    )
                  : null,
            ),

            const Spacer(),

            // Keypad
            _PinKeypad(
              onKeyPressed: _onKeyPressed,
              onBackspace: _onBackspace,
              onBiometric: _biometricAvailable && _biometricEnabled
                  ? _tryBiometricUnlock
                  : null,
              isLoading: _isLoading,
            ),

            SpacingGap.gapV24,

            // Unlock button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 48),
              child: FilledButton(
                onPressed: _enteredPin.length >= 4 && !_isLoading
                    ? _onSubmit
                    : null,
                style: FilledButton.styleFrom(
                  minimumSize: const Size(double.infinity, 56),
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Unlock'),
              ),
            ),

            SpacingGap.gapV32,
          ],
        ),
      ),
    );
  }
}

/// PIN dots indicator
class _PinDotsIndicator extends StatelessWidget {
  final int length;
  final int maxLength;
  final bool isError;

  const _PinDotsIndicator({
    required this.length,
    required this.maxLength,
    this.isError = false,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(maxLength, (index) {
        final isFilled = index < length;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          margin: const EdgeInsets.symmetric(horizontal: 8),
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isFilled
                ? (isError ? colorScheme.error : colorScheme.primary)
                : Colors.transparent,
            border: Border.all(
              color: isError
                  ? colorScheme.error
                  : (isFilled
                        ? colorScheme.primary
                        : colorScheme.outlineVariant),
              width: 2,
            ),
          ),
        );
      }),
    );
  }
}

/// PIN keypad widget
class _PinKeypad extends StatelessWidget {
  final void Function(String key) onKeyPressed;
  final VoidCallback onBackspace;
  final VoidCallback? onBiometric;
  final bool isLoading;

  const _PinKeypad({
    required this.onKeyPressed,
    required this.onBackspace,
    this.onBiometric,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 48),
      child: Column(
        children: [
          _buildRow(['1', '2', '3']),
          SpacingGap.gapV16,
          _buildRow(['4', '5', '6']),
          SpacingGap.gapV16,
          _buildRow(['7', '8', '9']),
          SpacingGap.gapV16,
          _buildBottomRow(context),
        ],
      ),
    );
  }

  Widget _buildRow(List<String> keys) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: keys.map((key) => _buildKey(key)).toList(),
    );
  }

  Widget _buildBottomRow(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        // Biometric or empty
        onBiometric != null
            ? _buildActionKey(
                icon: Icons.fingerprint,
                onTap: isLoading ? null : onBiometric,
              )
            : const SizedBox(width: 72, height: 72),
        // Zero
        _buildKey('0'),
        // Backspace
        _buildActionKey(
          icon: Icons.backspace_outlined,
          onTap: isLoading ? null : onBackspace,
        ),
      ],
    );
  }

  Widget _buildKey(String key) {
    return Builder(
      builder: (context) {
        final colorScheme = Theme.of(context).colorScheme;
        return Material(
          color: Colors.transparent,
          child: ExpressiveInkWell(
            onTap: isLoading ? null : () => onKeyPressed(key),
            borderRadius: BorderRadius.circular(36),
            child: Container(
              width: 72,
              height: 72,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: colorScheme.outlineVariant, width: 1),
              ),
              child: Text(
                key,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildActionKey({required IconData icon, VoidCallback? onTap}) {
    return Builder(
      builder: (context) {
        final colorScheme = Theme.of(context).colorScheme;
        return Material(
          color: Colors.transparent,
          child: ExpressiveInkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(36),
            child: Container(
              width: 72,
              height: 72,
              alignment: Alignment.center,
              child: Icon(
                icon,
                size: 28,
                color: onTap == null
                    ? colorScheme.onSurfaceVariant.withOpacity(0.5)
                    : colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        );
      },
    );
  }
}

/// PIN setup screen for initial setup or changing PIN
class PinSetupScreen extends StatefulWidget {
  final String? title;
  final String? subtitle;
  final bool isChangingPin;
  final VoidCallback? onComplete;

  const PinSetupScreen({
    super.key,
    this.title,
    this.subtitle,
    this.isChangingPin = false,
    this.onComplete,
  });

  @override
  State<PinSetupScreen> createState() => _PinSetupScreenState();
}

class _PinSetupScreenState extends State<PinSetupScreen> {
  String _enteredPin = '';
  String? _firstPin;
  bool _isConfirming = false;
  String? _errorMessage;
  bool _isLoading = false;

  String get _title {
    if (widget.title != null) return widget.title!;
    if (_isConfirming) return 'Confirm PIN';
    return widget.isChangingPin ? 'Enter New PIN' : 'Create PIN';
  }

  String get _subtitle {
    if (widget.subtitle != null && !_isConfirming) return widget.subtitle!;
    if (_isConfirming) return 'Enter the same PIN again';
    return 'Enter a 4-6 digit PIN';
  }

  void _onKeyPressed(String key) {
    HapticFeedback.lightImpact();

    if (_enteredPin.length >= 6) return;

    setState(() {
      _enteredPin += key;
      _errorMessage = null;
    });
  }

  void _onSubmit() {
    if (_enteredPin.length < 4) {
      setState(() {
        _errorMessage = 'PIN must be at least 4 digits';
      });
      return;
    }
    _handleSubmit();
  }

  void _onBackspace() {
    HapticFeedback.lightImpact();

    if (_enteredPin.isEmpty) return;

    setState(() {
      _enteredPin = _enteredPin.substring(0, _enteredPin.length - 1);
      _errorMessage = null;
    });
  }

  Future<void> _handleSubmit() async {
    if (_isLoading) return;

    // Small delay for UX
    await Future.delayed(const Duration(milliseconds: 100));

    if (!_isConfirming) {
      // First entry - move to confirmation
      setState(() {
        _firstPin = _enteredPin;
        _enteredPin = '';
        _isConfirming = true;
      });
    } else {
      // Confirmation entry - verify match
      if (_enteredPin == _firstPin) {
        // PINs match - save
        setState(() {
          _isLoading = true;
        });

        try {
          await AppLockService.instance.setupPin(_enteredPin);

          if (mounted) {
            widget.onComplete?.call();
            Navigator.of(context).pop(true);
          }
        } catch (e) {
          setState(() {
            _isLoading = false;
            _errorMessage = 'Failed to save PIN';
          });
        }
      } else {
        // PINs don't match
        setState(() {
          _enteredPin = '';
          _firstPin = null;
          _isConfirming = false;
          _errorMessage = 'PINs do not match. Try again.';
        });
        HapticFeedback.heavyImpact();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Set Up PIN'),
        backgroundColor: Colors.transparent,
      ),
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(),

            // Title
            Text(
              _title,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),

            SpacingGap.gapV8,

            Text(
              _subtitle,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),

            SpacingGap.gapV32,

            // PIN dots indicator
            _PinDotsIndicator(
              length: _enteredPin.length,
              maxLength: 6,
              isError: _errorMessage != null,
            ),

            // Error message
            SizedBox(
              height: 40,
              child: _errorMessage != null
                  ? Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(
                        _errorMessage!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.error,
                        ),
                      ),
                    )
                  : null,
            ),

            const Spacer(),

            // Keypad
            _PinKeypad(
              onKeyPressed: _onKeyPressed,
              onBackspace: _onBackspace,
              isLoading: _isLoading,
            ),

            SpacingGap.gapV24,

            // Continue button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 48),
              child: FilledButton(
                onPressed: _enteredPin.length >= 4 && !_isLoading
                    ? _onSubmit
                    : null,
                style: FilledButton.styleFrom(
                  minimumSize: const Size(double.infinity, 56),
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(_isConfirming ? 'Confirm' : 'Continue'),
              ),
            ),

            SpacingGap.gapV32,
          ],
        ),
      ),
    );
  }
}

/// Dialog to verify current PIN before making changes
class VerifyPinDialog extends StatefulWidget {
  final String title;
  final String subtitle;

  const VerifyPinDialog({
    super.key,
    this.title = 'Enter PIN',
    this.subtitle = 'Enter your current PIN to continue',
  });

  @override
  State<VerifyPinDialog> createState() => _VerifyPinDialogState();
}

class _VerifyPinDialogState extends State<VerifyPinDialog> {
  String _enteredPin = '';
  String? _errorMessage;
  bool _isLoading = false;

  void _onKeyPressed(String key) {
    HapticFeedback.lightImpact();

    if (_enteredPin.length >= 6) return;

    setState(() {
      _enteredPin += key;
      _errorMessage = null;
    });
  }

  void _onSubmit() {
    if (_enteredPin.length < 4) {
      setState(() {
        _errorMessage = 'PIN must be at least 4 digits';
      });
      return;
    }
    _verifyPin();
  }

  void _onBackspace() {
    HapticFeedback.lightImpact();

    if (_enteredPin.isEmpty) return;

    setState(() {
      _enteredPin = _enteredPin.substring(0, _enteredPin.length - 1);
      _errorMessage = null;
    });
  }

  Future<void> _verifyPin() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
    });

    await Future.delayed(const Duration(milliseconds: 100));

    final success = await AppLockService.instance.verifyPin(_enteredPin);

    if (success) {
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } else {
      setState(() {
        _isLoading = false;
        _enteredPin = '';
        _errorMessage = 'Incorrect PIN';
      });
      HapticFeedback.heavyImpact();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Dialog(
      child: Padding(
        padding: SpacingEdgeInsets.insets24,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(widget.title, style: theme.textTheme.titleLarge),
            SpacingGap.gapV8,
            Text(
              widget.subtitle,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            SpacingGap.gapV24,

            // PIN dots
            _PinDotsIndicator(
              length: _enteredPin.length,
              maxLength: 6,
              isError: _errorMessage != null,
            ),

            if (_errorMessage != null) ...[
              SpacingGap.gapV8,
              Text(
                _errorMessage!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.error,
                ),
              ),
            ],

            SpacingGap.gapV24,

            // Compact keypad
            _CompactPinKeypad(
              onKeyPressed: _onKeyPressed,
              onBackspace: _onBackspace,
              isLoading: _isLoading,
            ),

            SpacingGap.gapV16,

            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                ExpressiveTextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Cancel'),
                ),
                SpacingGap.gapH8,
                FilledButton(
                  onPressed: _enteredPin.length >= 4 && !_isLoading
                      ? _onSubmit
                      : null,
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Verify'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Compact keypad for dialogs
class _CompactPinKeypad extends StatelessWidget {
  final void Function(String key) onKeyPressed;
  final VoidCallback onBackspace;
  final bool isLoading;

  const _CompactPinKeypad({
    required this.onKeyPressed,
    required this.onBackspace,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildRow(['1', '2', '3'], context),
        _buildRow(['4', '5', '6'], context),
        _buildRow(['7', '8', '9'], context),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(width: 56),
            _buildKey('0', context),
            _buildActionKey(Icons.backspace_outlined, onBackspace, context),
          ],
        ),
      ],
    );
  }

  Widget _buildRow(List<String> keys, BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: keys.map((key) => _buildKey(key, context)).toList(),
    );
  }

  Widget _buildKey(String key, BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: ExpressiveInkWell(
        onTap: isLoading ? null : () => onKeyPressed(key),
        borderRadius: BorderRadius.circular(28),
        child: Container(
          width: 56,
          height: 56,
          alignment: Alignment.center,
          child: Text(key, style: Theme.of(context).textTheme.titleLarge),
        ),
      ),
    );
  }

  Widget _buildActionKey(
    IconData icon,
    VoidCallback onTap,
    BuildContext context,
  ) {
    return Material(
      color: Colors.transparent,
      child: ExpressiveInkWell(
        onTap: isLoading ? null : onTap,
        borderRadius: BorderRadius.circular(28),
        child: Container(
          width: 56,
          height: 56,
          alignment: Alignment.center,
          child: Icon(icon, size: 24),
        ),
      ),
    );
  }
}
