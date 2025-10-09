// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Ukrainian (`uk`).
class AppLocalizationsUk extends AppLocalizations {
  AppLocalizationsUk([String locale = 'uk']) : super(locale);

  @override
  String get appTitle => 'Trudido';

  @override
  String get appDescription =>
      'Багатофункціональний додаток завдань, створений з Flutter';

  @override
  String get tabs => 'Завдання';

  @override
  String get notes => 'Нотатки';

  @override
  String get newTask => 'Нове завдання';

  @override
  String get editTask => 'Редагувати завдання';

  @override
  String get addToTaskList => 'Додати до списку завдань';

  @override
  String get taskTitle => 'Назва завдання';

  @override
  String get taskTitleHint => 'Що потрібно зробити?';

  @override
  String get taskTitleValidation => 'Будь ласка, введіть назву завдання';

  @override
  String get quickOptions => 'Швидкі опції';

  @override
  String get displayTheme => 'Відображення та тема';

  @override
  String get theme => 'Тема';

  @override
  String get themeMode => 'Режим теми';

  @override
  String get themeModeLight => 'Світлий';

  @override
  String get themeModeDark => 'Темний';

  @override
  String get themeModeAuto => 'Авто';

  @override
  String get themeModeSystem => 'Авто (слідує пристрою)';

  @override
  String get themeModeAlwaysLight => 'Завжди використовувати світлу тему';

  @override
  String get themeModeAlwaysDark => 'Завжди використовувати темну тему';

  @override
  String get themeModeFollowDevice => 'Слідувати налаштуванню пристрою';

  @override
  String get themeBlackAmoled => 'Чорний (AMOLED)';

  @override
  String get dynamicColor => 'Динамічний колір';

  @override
  String get accentColor => 'Акцентний колір';

  @override
  String get chooseAccentColor => 'Виберіть акцентний колір';

  @override
  String get hackThemeNotAvailable => 'Недоступно для теми Hack';

  @override
  String get display => 'Відображення';

  @override
  String get about => 'Про додаток';

  @override
  String get openPackageLicenses => 'Відкрити ліцензії пакетів';

  @override
  String get licenseTitle => 'ЛІЦЕНЗІЯ (GPL-3.0)';

  @override
  String get close => 'Закрити';

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
  String get error => 'Помилка';

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
