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
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/app_providers.dart';

class AppRefreshService {
  static const AppRefreshService instance = AppRefreshService._();
  const AppRefreshService._();

  /// Refreshes all app data providers after import or major data changes
  Future<void> refreshAllProviders(WidgetRef ref) async {
    try {
      debugPrint('[AppRefreshService] Starting provider refresh...');

      // Refresh tasks
      final tasksNotifier = ref.read(tasksProvider.notifier);
      await tasksNotifier.refresh();
      debugPrint('[AppRefreshService] Tasks refreshed');

      // Refresh preferences state
      ref.invalidate(preferencesStateProvider);
      debugPrint('[AppRefreshService] Preferences state invalidated');

      debugPrint('[AppRefreshService] All providers refreshed successfully');
    } catch (e, stackTrace) {
      debugPrint('[AppRefreshService] Error refreshing providers: $e');
      debugPrint('[AppRefreshService] Stack trace: $stackTrace');
      rethrow;
    }
  }
}
