// Trudido - A privacy-focused todo and notes app
// Copyright (C) 2026 Dominik Müller
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
import '../theme/spacing_tokens.dart';
import '../widgets/common/common.dart';

/// Separate screen for vault password setup to avoid dialog context issues.
/// Provides a full-screen form for creating vault passwords with optional biometric.
class VaultSetupScreen extends StatefulWidget {
  final String folderName;
  final bool biometricAvailable;

  const VaultSetupScreen({
    super.key,
    required this.folderName,
    required this.biometricAvailable,
  });

  @override
  State<VaultSetupScreen> createState() => _VaultSetupScreenState();
}

class _VaultSetupScreenState extends State<VaultSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _useBiometric = true;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      Navigator.of(context).pop({
        'password': _passwordController.text,
        'useBiometric': _useBiometric,
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Setup ${widget.folderName}'),
        leading: ExpressiveIconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(null),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: SpacingEdgeInsets.insets16,
          children: [
            Text(
              'Create a password/PIN to protect this vault folder',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            SpacingGap.gapV24,
            TextFormField(
              controller: _passwordController,
              obscureText: _obscurePassword,
              decoration: InputDecoration(
                labelText: 'Password/PIN',
                border: const OutlineInputBorder(),
                suffixIcon: ExpressiveIconButton(
                  icon: Icon(
                    _obscurePassword ? Icons.visibility : Icons.visibility_off,
                  ),
                  onPressed: () {
                    setState(() {
                      _obscurePassword = !_obscurePassword;
                    });
                  },
                ),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter a password';
                }
                if (value.length < 4) {
                  return 'Password must be at least 4 characters';
                }
                return null;
              },
            ),
            SpacingGap.gapV16,
            TextFormField(
              controller: _confirmPasswordController,
              obscureText: _obscureConfirm,
              decoration: InputDecoration(
                labelText: 'Confirm Password',
                border: const OutlineInputBorder(),
                suffixIcon: ExpressiveIconButton(
                  icon: Icon(
                    _obscureConfirm ? Icons.visibility : Icons.visibility_off,
                  ),
                  onPressed: () {
                    setState(() {
                      _obscureConfirm = !_obscureConfirm;
                    });
                  },
                ),
              ),
              validator: (value) {
                if (value != _passwordController.text) {
                  return 'Passwords do not match';
                }
                return null;
              },
            ),
            if (widget.biometricAvailable) ...[
              SpacingGap.gapV16,
              CheckboxListTile(
                title: const Text('Use biometric authentication'),
                subtitle: const Text(
                  'Use fingerprint/face ID for quick access',
                ),
                value: _useBiometric,
                onChanged: (value) {
                  setState(() {
                    _useBiometric = value ?? true;
                  });
                },
              ),
            ],
            SpacingGap.gapV24,
            ExpressiveElevatedButton(
              onPressed: _submit,
              child: const Padding(
                padding: SpacingEdgeInsets.insets16,
                child: Text('Setup Vault'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Helper function to show vault setup and return result.
Future<Map<String, dynamic>?> showVaultSetup(
  BuildContext context, {
  required String folderName,
  required bool biometricAvailable,
}) async {
  return Navigator.of(context).push<Map<String, dynamic>>(
    MaterialPageRoute(
      builder: (context) => VaultSetupScreen(
        folderName: folderName,
        biometricAvailable: biometricAvailable,
      ),
    ),
  );
}
