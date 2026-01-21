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

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

class BiometricAuthService {
  static final LocalAuthentication _auth = LocalAuthentication();

  static bool isAuthInProgress = false;

  static DateTime? lastAuthCompletedTime;

  static Future<bool> canCheckBiometrics() async {
    try {
      return await _auth.canCheckBiometrics;
    } on PlatformException {
      return false;
    }
  }

  static Future<bool> isBiometricsAvailable() async {
    try {
      final canCheck = await canCheckBiometrics();
      if (!canCheck) return false;

      final availableBiometrics = await _auth.getAvailableBiometrics();
      return availableBiometrics.isNotEmpty;
    } on PlatformException {
      return false;
    }
  }

  static Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      return await _auth.getAvailableBiometrics();
    } on PlatformException {
      return [];
    }
  }

  static Future<bool> authenticate({
    required String reason,
    bool biometricOnly = false,
  }) async {
    isAuthInProgress = true;

    try {
      if (kDebugMode) {
        debugPrint('[BiometricAuth] Starting authentication');
        debugPrint(
          '[BiometricAuth] Reason: $reason, biometricOnly: $biometricOnly',
        );
      }

      final isAvailable = await isBiometricsAvailable();
      if (kDebugMode) {
        debugPrint('[BiometricAuth] Biometrics available: $isAvailable');
      }

      if (!isAvailable && biometricOnly) {
        if (kDebugMode) {
          debugPrint(
            '[BiometricAuth] Biometrics not available and biometricOnly=true, returning false',
          );
        }
        return false;
      }

      if (kDebugMode) {
        debugPrint('[BiometricAuth] Calling local_auth.authenticate()...');
      }
      final result = await _auth.authenticate(
        localizedReason: reason,
        options: AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: biometricOnly,
        ),
      );

      if (kDebugMode) {
        debugPrint('[BiometricAuth] Authentication result: $result');
      }
      return result;
    } on PlatformException catch (e) {
      if (kDebugMode) {
        debugPrint(
          '[BiometricAuth] Platform exception: ${e.code} - ${e.message}',
        );
        print('Biometric authentication error: $e');
      }
      return false;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[BiometricAuth] Unexpected error: $e');
      }
      return false;
    } finally {
      // Reset global flag after auth completes
      isAuthInProgress = false;
      // Record completion time for grace period
      lastAuthCompletedTime = DateTime.now();
    }
  }

  /// Stops any ongoing authentication
  static Future<void> stopAuthentication() async {
    try {
      await _auth.stopAuthentication();
    } on PlatformException {
      // Ignore errors when stopping
    }
  }

  /// Gets a user-friendly description of available biometric types
  static Future<String> getBiometricTypeDescription() async {
    final types = await getAvailableBiometrics();

    if (types.isEmpty) {
      return 'Device credentials';
    }

    final descriptions = <String>[];
    if (types.contains(BiometricType.face)) {
      descriptions.add('Face ID');
    }
    if (types.contains(BiometricType.fingerprint)) {
      descriptions.add('Fingerprint');
    }
    if (types.contains(BiometricType.iris)) {
      descriptions.add('Iris');
    }

    return descriptions.isEmpty ? 'Biometrics' : descriptions.join(' or ');
  }
}
