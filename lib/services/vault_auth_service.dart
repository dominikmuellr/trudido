import 'package:flutter/material.dart';
import 'biometric_auth_service.dart';
import 'vault_password_service.dart';

/// Service for authenticating access to vault folders
/// Tries biometric first, falls back to password after 3 failed attempts
class VaultAuthService {
  // Track failed biometric attempts per folder in memory
  static final Map<String, int> _failedAttempts = {};
  static const int maxBiometricAttempts = 3;

  /// Authenticate to access a vault folder
  /// Returns true if authentication successful, false otherwise
  ///
  /// Flow:
  /// 1. If useBiometric is true and available, try biometric first
  /// 2. After 3 failed biometric attempts, require password
  /// 3. If no biometric available or disabled, go straight to password
  static Future<bool> authenticate({
    required BuildContext context,
    required String folderId,
    required String folderName,
    required bool useBiometric,
    required bool hasPassword,
  }) async {
    debugPrint('[VaultAuth] Starting authentication for $folderName');
    debugPrint(
      '[VaultAuth] useBiometric: $useBiometric, hasPassword: $hasPassword',
    );

    // Check if biometric is available and enabled
    final biometricAvailable =
        useBiometric && await BiometricAuthService.isBiometricsAvailable();

    debugPrint('[VaultAuth] Biometric available: $biometricAvailable');

    // Get failed attempts count
    final attempts = _failedAttempts[folderId] ?? 0;
    debugPrint('[VaultAuth] Failed attempts: $attempts');

    // Try biometric if available and under max attempts
    if (biometricAvailable && attempts < maxBiometricAttempts) {
      debugPrint('[VaultAuth] Attempting biometric authentication...');
      final biometricSuccess = await BiometricAuthService.authenticate(
        reason: 'Authenticate to access $folderName',
        biometricOnly: true,
      );

      debugPrint('[VaultAuth] Biometric result: $biometricSuccess');

      if (biometricSuccess) {
        // Reset failed attempts on success
        _failedAttempts[folderId] = 0;
        return true;
      } else {
        // Increment failed attempts
        _failedAttempts[folderId] = attempts + 1;

        // If reached max attempts, require password
        final currentAttempts = _failedAttempts[folderId] ?? 0;
        if (currentAttempts >= maxBiometricAttempts) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Too many failed biometric attempts. Please enter password.',
                ),
                backgroundColor: Colors.orange,
              ),
            );
          }
        }
      }
    }

    // Fall back to password if:
    // - Biometric not available/disabled
    // - Biometric failed and reached max attempts
    // - User cancelled biometric
    if (hasPassword) {
      if (context.mounted) {
        final password = await _showPasswordDialog(context, folderName);

        if (password != null) {
          final isValid = await VaultPasswordService.verifyVaultPassword(
            folderId,
            password,
          );

          if (isValid) {
            // Reset failed attempts on successful password entry
            _failedAttempts[folderId] = 0;
            return true;
          } else {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Incorrect password'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          }
        }
      }
    }

    return false;
  }

  /// Show password input dialog
  static Future<String?> _showPasswordDialog(
    BuildContext context,
    String folderName,
  ) async {
    final controller = TextEditingController();
    bool obscureText = true;

    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text('Enter Password for $folderName'),
          content: TextField(
            controller: controller,
            obscureText: obscureText,
            autofocus: true,
            decoration: InputDecoration(
              labelText: 'Password',
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                icon: Icon(
                  obscureText ? Icons.visibility : Icons.visibility_off,
                ),
                onPressed: () {
                  setState(() {
                    obscureText = !obscureText;
                  });
                },
              ),
            ),
            onSubmitted: (value) {
              if (value.isNotEmpty) {
                Navigator.of(context).pop(value);
              }
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(null),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final password = controller.text;
                if (password.isNotEmpty) {
                  Navigator.of(context).pop(password);
                }
              },
              child: const Text('Unlock'),
            ),
          ],
        ),
      ),
    );
  }

  /// Reset failed attempts for a folder (call when folder is unlocked successfully)
  static void resetFailedAttempts(String folderId) {
    _failedAttempts[folderId] = 0;
  }

  /// Clear all failed attempts (useful for testing or app restart)
  static void clearAllFailedAttempts() {
    _failedAttempts.clear();
  }
}
