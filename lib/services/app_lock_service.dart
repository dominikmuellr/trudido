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

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';

import 'biometric_auth_service.dart';

/// Service for managing app-wide lock with PIN and biometrics
class AppLockService {
  static const _storage = FlutterSecureStorage();
  static const _pinKey = 'app_lock_pin_hash';
  static const _enabledKey = 'app_lock_enabled';
  static const _biometricEnabledKey = 'app_lock_biometric_enabled';
  static const _timeoutKey = 'app_lock_timeout'; // in seconds
  static const _lastUnlockKey = 'app_lock_last_unlock';

  // Singleton instance
  static final AppLockService _instance = AppLockService._();
  static AppLockService get instance => _instance;
  AppLockService._();

  // In-memory state
  bool _isUnlocked = false;
  DateTime? _lastUnlockTime;

  // Track biometric auth state to prevent looping
  bool _biometricAttemptedThisSession = false;
  bool _isBiometricAuthInProgress = false;

  // Track failed biometric attempts (similar to vault)
  int _failedBiometricAttempts = 0;
  static const int maxBiometricAttempts = 3;

  bool get biometricAttemptedThisSession => _biometricAttemptedThisSession;

  bool get isBiometricAuthInProgress => _isBiometricAuthInProgress;

  int get failedBiometricAttempts => _failedBiometricAttempts;

  bool get shouldDisableBiometric =>
      _failedBiometricAttempts >= maxBiometricAttempts;

  void markBiometricAttempted() {
    _biometricAttemptedThisSession = true;
  }

  void resetBiometricAttempt() {
    _biometricAttemptedThisSession = false;
    _isBiometricAuthInProgress = false;
    _failedBiometricAttempts = 0; // Reset failed attempts
  }

  void incrementFailedBiometricAttempts() {
    _failedBiometricAttempts++;
  }

  Future<bool> isEnabled() async {
    final enabled = await _storage.read(key: _enabledKey);
    return enabled == 'true';
  }

  Future<bool> isBiometricEnabled() async {
    final enabled = await _storage.read(key: _biometricEnabledKey);
    return enabled == 'true';
  }

  Future<int> getTimeout() async {
    final timeout = await _storage.read(key: _timeoutKey);
    return int.tryParse(timeout ?? '0') ?? 0;
  }

  String _hashPin(String pin) {
    final bytes = utf8.encode(pin);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  Future<void> setupPin(String pin) async {
    if (pin.length < 4 || pin.length > 6) {
      throw ArgumentError('PIN must be 4-6 digits');
    }
    if (!RegExp(r'^\d+$').hasMatch(pin)) {
      throw ArgumentError('PIN must contain only digits');
    }

    final hashedPin = _hashPin(pin);
    await _storage.write(key: _pinKey, value: hashedPin);
    await _storage.write(key: _enabledKey, value: 'true');
    _isUnlocked = true;
    _lastUnlockTime = DateTime.now();
  }

  Future<bool> verifyPin(String pin) async {
    final storedHash = await _storage.read(key: _pinKey);
    if (storedHash == null) return false;

    final inputHash = _hashPin(pin);
    final isValid = storedHash == inputHash;

    if (isValid) {
      _isUnlocked = true;
      _lastUnlockTime = DateTime.now();
      await _storage.write(
        key: _lastUnlockKey,
        value: _lastUnlockTime!.toIso8601String(),
      );
      // Reset failed biometric attempts on successful PIN entry
      _failedBiometricAttempts = 0;
    }

    return isValid;
  }

  Future<bool> unlockWithBiometrics() async {
    // Prevent concurrent biometric auth attempts
    if (_isBiometricAuthInProgress) return false;

    final biometricEnabled = await isBiometricEnabled();
    if (!biometricEnabled) return false;

    // Check if too many failed attempts
    if (shouldDisableBiometric) return false;

    _isBiometricAuthInProgress = true;

    try {
      final success = await BiometricAuthService.authenticate(
        reason: 'Unlock Trudido',
        biometricOnly: false,
      );

      if (success) {
        _isUnlocked = true;
        _lastUnlockTime = DateTime.now();
        await _storage.write(
          key: _lastUnlockKey,
          value: _lastUnlockTime!.toIso8601String(),
        );
        // Reset failed attempts on success
        _failedBiometricAttempts = 0;
      } else {
        // Increment failed attempts on failure
        _failedBiometricAttempts++;
      }

      return success;
    } finally {
      _isBiometricAuthInProgress = false;
    }
  }

  Future<void> setBiometricEnabled(bool enabled) async {
    await _storage.write(key: _biometricEnabledKey, value: enabled.toString());
  }

  Future<void> setTimeout(int seconds) async {
    await _storage.write(key: _timeoutKey, value: seconds.toString());
  }

  Future<bool> changePin(String oldPin, String newPin) async {
    final isValid = await verifyPin(oldPin);
    if (!isValid) return false;

    await setupPin(newPin);
    return true;
  }

  Future<bool> disable(String pin) async {
    final isValid = await verifyPin(pin);
    if (!isValid) return false;

    await _storage.delete(key: _pinKey);
    await _storage.write(key: _enabledKey, value: 'false');
    await _storage.delete(key: _biometricEnabledKey);
    await _storage.delete(key: _timeoutKey);
    await _storage.delete(key: _lastUnlockKey);
    _isUnlocked = true;
    return true;
  }

  /// Check if app should be locked based on timeout
  Future<bool> shouldLock() async {
    final enabled = await isEnabled();
    if (!enabled) return false;

    // If never unlocked in this session, require unlock
    if (!_isUnlocked) return true;

    final timeout = await getTimeout();

    // -1 means never lock while app is running
    if (timeout == -1) return false;

    // 0 means immediate lock when going to background
    if (timeout == 0) return true;

    if (_lastUnlockTime == null) return true;

    final elapsed = DateTime.now().difference(_lastUnlockTime!).inSeconds;
    return elapsed > timeout;
  }

  /// Lock the app (called when app goes to background)
  void lock() {
    _isUnlocked = false;
    // Reset biometric attempt so it can auto-trigger again next time
    resetBiometricAttempt();
  }

  /// Check if currently unlocked
  bool get isUnlocked => _isUnlocked;

  /// Mark app as locked (for testing or forced lock)
  void forceUnlock() {
    _isUnlocked = true;
    _lastUnlockTime = DateTime.now();
  }

  /// Check if PIN is set up
  Future<bool> hasPinSetup() async {
    final pin = await _storage.read(key: _pinKey);
    return pin != null;
  }

  /// Reset all app lock data (for testing or recovery)
  Future<void> reset() async {
    await _storage.delete(key: _pinKey);
    await _storage.delete(key: _enabledKey);
    await _storage.delete(key: _biometricEnabledKey);
    await _storage.delete(key: _timeoutKey);
    await _storage.delete(key: _lastUnlockKey);
    _isUnlocked = true;
    _lastUnlockTime = null;
  }

  /// Get available timeout options
  static List<({int seconds, String label})> get timeoutOptions => [
    (seconds: 0, label: 'Immediately'),
    (seconds: 30, label: 'After 30 seconds'),
    (seconds: 60, label: 'After 1 minute'),
    (seconds: 300, label: 'After 5 minutes'),
    (seconds: -1, label: 'Never while app is open'),
  ];

  /// Get label for a timeout value
  static String getTimeoutLabel(int seconds) {
    for (final option in timeoutOptions) {
      if (option.seconds == seconds) return option.label;
    }
    return 'After $seconds seconds';
  }
}
