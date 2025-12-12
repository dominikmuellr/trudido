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
import 'package:table_calendar/table_calendar.dart';

/// Utility class for week start day configuration.
///
/// Week day indices follow the Material convention:
/// 0 = Sunday, 1 = Monday, 2 = Tuesday, ..., 6 = Saturday
class WeekStartUtils {
  /// Maps the preference index (0-6, where 0=Sunday) to TableCalendar's StartingDayOfWeek.
  ///
  /// TableCalendar enum order: monday=0, tuesday=1, ..., saturday=5, sunday=6
  /// Material/preference order: sunday=0, monday=1, ..., saturday=6
  static StartingDayOfWeek toTableCalendarDay(int index) {
    // Convert from Material convention (0=Sunday) to TableCalendar convention (0=Monday)
    switch (index) {
      case 0: // Sunday
        return StartingDayOfWeek.sunday;
      case 1: // Monday
        return StartingDayOfWeek.monday;
      case 2: // Tuesday
        return StartingDayOfWeek.tuesday;
      case 3: // Wednesday
        return StartingDayOfWeek.wednesday;
      case 4: // Thursday
        return StartingDayOfWeek.thursday;
      case 5: // Friday
        return StartingDayOfWeek.friday;
      case 6: // Saturday
        return StartingDayOfWeek.saturday;
      default:
        return StartingDayOfWeek.monday; // Default to Monday
    }
  }

  /// Returns the localized name for a day index (0=Sunday, 1=Monday, etc.)
  static String getDayName(int index) {
    const days = [
      'Sunday',
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
    ];
    return days[index.clamp(0, 6)];
  }

  /// Returns the short name for a day index
  static String getDayShortName(int index) {
    const days = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
    return days[index.clamp(0, 6)];
  }
}

/// A MaterialLocalizations that overrides only firstDayOfWeekIndex.
///
/// Extends DefaultMaterialLocalizations so we get all the English strings
/// and only override the week start.
class _WeekStartMaterialLocalizations extends DefaultMaterialLocalizations {
  final int _firstDayOfWeekIndex;

  const _WeekStartMaterialLocalizations(this._firstDayOfWeekIndex);

  @override
  int get firstDayOfWeekIndex => _firstDayOfWeekIndex;
}

/// A LocalizationsDelegate that provides MaterialLocalizations
/// with a custom firstDayOfWeekIndex.
class WeekStartLocalizationsDelegate
    extends LocalizationsDelegate<MaterialLocalizations> {
  final int firstDayOfWeekIndex;

  const WeekStartLocalizationsDelegate(this.firstDayOfWeekIndex);

  @override
  bool isSupported(Locale locale) => true;

  @override
  Future<MaterialLocalizations> load(Locale locale) async {
    return _WeekStartMaterialLocalizations(firstDayOfWeekIndex);
  }

  @override
  bool shouldReload(WeekStartLocalizationsDelegate old) =>
      old.firstDayOfWeekIndex != firstDayOfWeekIndex;
}

/// Helper widget to wrap child widgets with custom week start localization.
///
/// Use this to wrap date pickers so they respect the user's week start preference.
class WeekStartOverride extends StatelessWidget {
  final int firstDayOfWeekIndex;
  final Widget child;

  const WeekStartOverride({
    super.key,
    required this.firstDayOfWeekIndex,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Localizations.override(
      context: context,
      delegates: [WeekStartLocalizationsDelegate(firstDayOfWeekIndex)],
      child: child,
    );
  }
}
