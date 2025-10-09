// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Czech (`cs`).
class AppLocalizationsCs extends AppLocalizations {
  AppLocalizationsCs([String locale = 'cs']) : super(locale);

  @override
  String get appTitle => 'Trudido';

  @override
  String get appDescription =>
      'Aplikace pro úkoly s bohatými funkcemi postavená s Flutter';

  @override
  String get tabs => 'Úkoly';

  @override
  String get notes => 'Poznámky';

  @override
  String get newTask => 'Nový úkol';

  @override
  String get editTask => 'Upravit úkol';

  @override
  String get addToTaskList => 'Přidat do seznamu úkolů';

  @override
  String get taskTitle => 'Název úkolu';

  @override
  String get taskTitleHint => 'Co je třeba udělat?';

  @override
  String get taskTitleValidation => 'Zadejte prosím název úkolu';

  @override
  String get quickOptions => 'Rychlé možnosti';

  @override
  String get displayTheme => 'Zobrazení a motiv';

  @override
  String get theme => 'Motiv';

  @override
  String get themeMode => 'Režim motivu';

  @override
  String get themeModeLight => 'Světlý';

  @override
  String get themeModeDark => 'Tmavý';

  @override
  String get themeModeAuto => 'Auto';

  @override
  String get themeModeSystem => 'Auto (následuje zařízení)';

  @override
  String get themeModeAlwaysLight => 'Vždy používat světlý motiv';

  @override
  String get themeModeAlwaysDark => 'Vždy používat tmavý motiv';

  @override
  String get themeModeFollowDevice => 'Následovat nastavení zařízení';

  @override
  String get themeBlackAmoled => 'Černý (AMOLED)';

  @override
  String get dynamicColor => 'Dynamická barva';

  @override
  String get accentColor => 'Barva zvýraznění';

  @override
  String get chooseAccentColor => 'Vyberte barvu zvýraznění';

  @override
  String get hackThemeNotAvailable => 'Není k dispozici pro motiv Hack';

  @override
  String get display => 'Zobrazení';

  @override
  String get about => 'O aplikaci';

  @override
  String get openPackageLicenses => 'Otevřít licence balíčků';

  @override
  String get licenseTitle => 'LICENCE (GPL-3.0)';

  @override
  String get close => 'Zavřít';

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
  String get error => 'Chyba';

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
