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

// Formats an integer minutes offset into a human readable string.
String formatMinutesReadable(int minutes) {
  String result;
  if (minutes == 0) {
    result = 'At time of due date';
  } else if (minutes < 60) {
    result = '$minutes ${minutes == 1 ? 'minute' : 'minutes'} before';
  } else if (minutes < 1440) {
    final hours = minutes ~/ 60;
    final remMinutes = minutes % 60;
    if (remMinutes == 0) {
      result = '$hours ${hours == 1 ? 'hour' : 'hours'} before';
    } else {
      result =
          '$hours ${hours == 1 ? 'hour' : 'hours'} $remMinutes ${remMinutes == 1 ? 'minute' : 'minutes'} before';
    }
  } else {
    final days = minutes ~/ 1440;
    final remHours = (minutes % 1440) ~/ 60;
    if (remHours == 0) {
      result = '$days ${days == 1 ? 'day' : 'days'} before';
    } else {
      result =
          '$days ${days == 1 ? 'day' : 'days'} $remHours ${remHours == 1 ? 'hour' : 'hours'} before';
    }
  }

  return result;
}
