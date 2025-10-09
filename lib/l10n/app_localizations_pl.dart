// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Polish (`pl`).
class AppLocalizationsPl extends AppLocalizations {
  AppLocalizationsPl([String locale = 'pl']) : super(locale);

  @override
  String get appTitle => 'Trudido';

  @override
  String get appDescription =>
      'Bogata w funkcje aplikacja zadań zbudowana z Flutter';

  @override
  String get tabs => 'Zadania';

  @override
  String get notes => 'Notatki';

  @override
  String get newTask => 'Nowe zadanie';

  @override
  String get editTask => 'Edytuj zadanie';

  @override
  String get addToTaskList => 'Dodaj do listy zadań';

  @override
  String get taskTitle => 'Tytuł zadania';

  @override
  String get taskTitleHint => 'Co trzeba zrobić?';

  @override
  String get taskTitleValidation => 'Proszę wprowadzić tytuł zadania';

  @override
  String get quickOptions => 'Szybkie opcje';

  @override
  String get displayTheme => 'Wyświetlanie i motyw';

  @override
  String get theme => 'Motyw';

  @override
  String get themeMode => 'Tryb motywu';

  @override
  String get themeModeLight => 'Jasny';

  @override
  String get themeModeDark => 'Ciemny';

  @override
  String get themeModeAuto => 'Auto';

  @override
  String get themeModeSystem => 'Auto (podąża za urządzeniem)';

  @override
  String get themeModeAlwaysLight => 'Zawsze używaj jasnego motywu';

  @override
  String get themeModeAlwaysDark => 'Zawsze używaj ciemnego motywu';

  @override
  String get themeModeFollowDevice => 'Podążaj za ustawieniem urządzenia';

  @override
  String get themeBlackAmoled => 'Czarny (AMOLED)';

  @override
  String get dynamicColor => 'Dynamiczny kolor';

  @override
  String get accentColor => 'Kolor akcentu';

  @override
  String get chooseAccentColor => 'Wybierz kolor akcentu';

  @override
  String get hackThemeNotAvailable => 'Niedostępne dla motywu Hack';

  @override
  String get display => 'Wyświetlanie';

  @override
  String get about => 'O aplikacji';

  @override
  String get openPackageLicenses => 'Otwórz licencje pakietów';

  @override
  String get licenseTitle => 'LICENCJA (GPL-3.0)';

  @override
  String get close => 'Zamknij';

  @override
  String get notificationTesting => 'Notification Testing';

  @override
  String get testManageNotifications => 'Test & Manage Notifications';

  @override
  String get scheduleTest10s => 'Schedule Test (10s)';

  @override
  String get scheduleTest10sDescription =>
      'Schedules a notification 10 seconds from now.';

  @override
  String get error => 'Błąd';

  @override
  String get demoInstructions => 'Demo Instructions';

  @override
  String get tryItOut => 'Try It Out';

  @override
  String get createTestFolder => 'Create Test Folder';

  @override
  String get schedule => 'Schedule';

  @override
  String get debugOnboardingControls => 'DEBUG: Onboarding Controls';

  @override
  String tooltipStatus(String status) {
    return 'Tooltip Status: $status';
  }

  @override
  String get loading => 'Loading...';

  @override
  String get seen => 'Seen';

  @override
  String get notSeen => 'Not seen';

  @override
  String get resetTooltip => 'Reset Tooltip';

  @override
  String get refresh => 'Refresh';

  @override
  String get colorBlue => 'Blue';

  @override
  String get colorPink => 'Pink';

  @override
  String get colorPurple => 'Purple';

  @override
  String get colorDeepPurple => 'Deep Purple';

  @override
  String get colorIndigo => 'Indigo';

  @override
  String get colorTeal => 'Teal';

  @override
  String get colorGreen => 'Green';

  @override
  String get colorLightGreen => 'Light Green';

  @override
  String get colorLime => 'Lime';

  @override
  String get colorAmber => 'Amber';

  @override
  String get colorOrange => 'Orange';

  @override
  String get colorDeepOrange => 'Deep Orange';

  @override
  String get colorBrown => 'Brown';

  @override
  String get colorMonochrome => 'Monochrome';

  @override
  String get colorGrey => 'Grey';

  @override
  String get colorHack => 'Hack';

  @override
  String get colorBlueGrey => 'Blue Grey';

  @override
  String get colorCustom => 'Custom';
}
