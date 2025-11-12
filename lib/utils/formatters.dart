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
