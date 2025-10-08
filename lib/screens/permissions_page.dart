import 'package:flutter/material.dart';

/// (Legacy stub) This page was replaced by UnifiedSettingsPage.
@Deprecated('Use UnifiedSettingsPage instead. Will be removed after v1.1.0.')
class PermissionsPage extends StatelessWidget {
  const PermissionsPage({super.key});
  @override
  Widget build(BuildContext context) {
    assert(() {
      debugPrint(
        '[PermissionsPage] This legacy page is deprecated. Use UnifiedSettingsPage instead.',
      );
      return true;
    }());
    return const SizedBox.shrink();
  }
}
