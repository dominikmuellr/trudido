import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

/// Service for handling biometric authentication for vault access
class BiometricAuthService {
  static final LocalAuthentication _auth = LocalAuthentication();

  /// Checks if the device supports biometric authentication
  static Future<bool> canCheckBiometrics() async {
    try {
      return await _auth.canCheckBiometrics;
    } on PlatformException {
      return false;
    }
  }

  /// Checks if biometrics are available (enrolled)
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

  /// Gets list of available biometric types
  static Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      return await _auth.getAvailableBiometrics();
    } on PlatformException {
      return [];
    }
  }

  /// Authenticates the user using biometrics or device credentials
  /// Returns true if authentication was successful
  static Future<bool> authenticate({
    required String reason,
    bool biometricOnly = false,
  }) async {
    try {
      final isAvailable = await isBiometricsAvailable();

      if (!isAvailable && biometricOnly) {
        return false;
      }

      return await _auth.authenticate(
        localizedReason: reason,
        options: AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: biometricOnly,
        ),
      );
    } on PlatformException catch (e) {
      print('Biometric authentication error: $e');
      return false;
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
