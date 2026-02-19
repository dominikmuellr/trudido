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

import 'dart:io' show Platform;
import 'package:flutter/services.dart';

/// Service for managing privacy settings like blackout in recents view
class PrivacyService {
  static const MethodChannel _channel = MethodChannel('app.perms');

  /// Enables or disables the black overlay that hides app content
  /// in the Android recents view
  Future<void> setSecureFlag(bool secure) async {
    if (!Platform.isAndroid) return;

    try {
      await _channel.invokeMethod('setSecureFlag', {'secure': secure});
    } catch (_) {}
  }
}
