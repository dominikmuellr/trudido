import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('af'),
    Locale('ar'),
    Locale('ca'),
    Locale('el'),
    Locale('en'),
    Locale('fi'),
    Locale('he'),
    Locale('hu'),
    Locale('ja'),
    Locale('ko'),
    Locale('no'),
    Locale('ru'),
    Locale('sr'),
    Locale('sv'),
    Locale('tr'),
    Locale('vi'),
    Locale('zh'),
  ];

  /// The name of the application
  ///
  /// In en, this message translates to:
  /// **'Trudido'**
  String get appTitle;

  /// Brief description of the app
  ///
  /// In en, this message translates to:
  /// **'A feature-rich todo app built with Flutter'**
  String get appDescription;

  /// Tasks tab label
  ///
  /// In en, this message translates to:
  /// **'Tasks'**
  String get tabs;

  /// Notes tab label
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get notes;

  /// Title for creating a new task
  ///
  /// In en, this message translates to:
  /// **'New Task'**
  String get newTask;

  /// Title for editing an existing task
  ///
  /// In en, this message translates to:
  /// **'Edit Task'**
  String get editTask;

  /// Subtitle for task creation dialog
  ///
  /// In en, this message translates to:
  /// **'Add to your task list'**
  String get addToTaskList;

  /// Label for task title input field
  ///
  /// In en, this message translates to:
  /// **'Task title'**
  String get taskTitle;

  /// Hint text for task title input
  ///
  /// In en, this message translates to:
  /// **'What needs to be done?'**
  String get taskTitleHint;

  /// Validation message for empty task title
  ///
  /// In en, this message translates to:
  /// **'Please enter a task title'**
  String get taskTitleValidation;

  /// Section title for quick task options
  ///
  /// In en, this message translates to:
  /// **'Quick Options'**
  String get quickOptions;

  /// Title for display and theme settings page
  ///
  /// In en, this message translates to:
  /// **'Display & Theme'**
  String get displayTheme;

  /// Theme section header
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get theme;

  /// Label for theme mode selector
  ///
  /// In en, this message translates to:
  /// **'Theme Mode'**
  String get themeMode;

  /// Light theme mode option
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get themeModeLight;

  /// Dark theme mode option
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get themeModeDark;

  /// Auto theme mode option
  ///
  /// In en, this message translates to:
  /// **'Auto'**
  String get themeModeAuto;

  /// System theme mode description
  ///
  /// In en, this message translates to:
  /// **'Auto (follows device)'**
  String get themeModeSystem;

  /// Light theme mode description
  ///
  /// In en, this message translates to:
  /// **'Always use light theme'**
  String get themeModeAlwaysLight;

  /// Dark theme mode description
  ///
  /// In en, this message translates to:
  /// **'Always use dark theme'**
  String get themeModeAlwaysDark;

  /// Auto theme mode description
  ///
  /// In en, this message translates to:
  /// **'Follow device setting'**
  String get themeModeFollowDevice;

  /// AMOLED black theme option
  ///
  /// In en, this message translates to:
  /// **'Black (AMOLED)'**
  String get themeBlackAmoled;

  /// Dynamic color setting label
  ///
  /// In en, this message translates to:
  /// **'Dynamic Color'**
  String get dynamicColor;

  /// Accent color setting label
  ///
  /// In en, this message translates to:
  /// **'Accent Color'**
  String get accentColor;

  /// Title for accent color selection sheet
  ///
  /// In en, this message translates to:
  /// **'Choose Accent Color'**
  String get chooseAccentColor;

  /// Message shown when a theme mode is not available for hack theme
  ///
  /// In en, this message translates to:
  /// **'Not available for Hack theme'**
  String get hackThemeNotAvailable;

  /// Display section header
  ///
  /// In en, this message translates to:
  /// **'Display'**
  String get display;

  /// About page title
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get about;

  /// Button text to open package licenses
  ///
  /// In en, this message translates to:
  /// **'Open package licenses'**
  String get openPackageLicenses;

  /// License dialog title
  ///
  /// In en, this message translates to:
  /// **'LICENSE (GPL-3.0)'**
  String get licenseTitle;

  /// Close button text
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// Title for notification testing screen
  ///
  /// In en, this message translates to:
  /// **'Notification Testing'**
  String get notificationTesting;

  /// Title for notification testing section
  ///
  /// In en, this message translates to:
  /// **'Test & Manage Notifications'**
  String get testManageNotifications;

  /// Button text for 10 second test notification
  ///
  /// In en, this message translates to:
  /// **'Schedule Test (10s)'**
  String get scheduleTest10s;

  /// Description for 10 second test notification
  ///
  /// In en, this message translates to:
  /// **'Schedules a notification 10 seconds from now.'**
  String get scheduleTest10sDescription;

  /// Generic error label
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get error;

  /// Title for demo instructions section
  ///
  /// In en, this message translates to:
  /// **'Demo Instructions'**
  String get demoInstructions;

  /// Title for try it out section
  ///
  /// In en, this message translates to:
  /// **'Try It Out'**
  String get tryItOut;

  /// Button text to create a test folder
  ///
  /// In en, this message translates to:
  /// **'Create Test Folder'**
  String get createTestFolder;

  /// Schedule section title
  ///
  /// In en, this message translates to:
  /// **'Schedule'**
  String get schedule;

  /// Debug section title for onboarding controls
  ///
  /// In en, this message translates to:
  /// **'DEBUG: Onboarding Controls'**
  String get debugOnboardingControls;

  /// Tooltip status display
  ///
  /// In en, this message translates to:
  /// **'Tooltip Status: {status}'**
  String tooltipStatus(String status);

  /// Loading status text
  ///
  /// In en, this message translates to:
  /// **'Loading...'**
  String get loading;

  /// Status indicating something has been seen
  ///
  /// In en, this message translates to:
  /// **'Seen'**
  String get seen;

  /// Status indicating something has not been seen
  ///
  /// In en, this message translates to:
  /// **'Not seen'**
  String get notSeen;

  /// Button text to reset tooltip
  ///
  /// In en, this message translates to:
  /// **'Reset Tooltip'**
  String get resetTooltip;

  /// Refresh button text
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get refresh;

  /// Blue color name
  ///
  /// In en, this message translates to:
  /// **'Blue'**
  String get colorBlue;

  /// Pink color name
  ///
  /// In en, this message translates to:
  /// **'Pink'**
  String get colorPink;

  /// Purple color name
  ///
  /// In en, this message translates to:
  /// **'Purple'**
  String get colorPurple;

  /// Deep Purple color name
  ///
  /// In en, this message translates to:
  /// **'Deep Purple'**
  String get colorDeepPurple;

  /// Indigo color name
  ///
  /// In en, this message translates to:
  /// **'Indigo'**
  String get colorIndigo;

  /// Teal color name
  ///
  /// In en, this message translates to:
  /// **'Teal'**
  String get colorTeal;

  /// Green color name
  ///
  /// In en, this message translates to:
  /// **'Green'**
  String get colorGreen;

  /// Light Green color name
  ///
  /// In en, this message translates to:
  /// **'Light Green'**
  String get colorLightGreen;

  /// Lime color name
  ///
  /// In en, this message translates to:
  /// **'Lime'**
  String get colorLime;

  /// Amber color name
  ///
  /// In en, this message translates to:
  /// **'Amber'**
  String get colorAmber;

  /// Orange color name
  ///
  /// In en, this message translates to:
  /// **'Orange'**
  String get colorOrange;

  /// Deep Orange color name
  ///
  /// In en, this message translates to:
  /// **'Deep Orange'**
  String get colorDeepOrange;

  /// Brown color name
  ///
  /// In en, this message translates to:
  /// **'Brown'**
  String get colorBrown;

  /// Monochrome color name
  ///
  /// In en, this message translates to:
  /// **'Monochrome'**
  String get colorMonochrome;

  /// Grey color name
  ///
  /// In en, this message translates to:
  /// **'Grey'**
  String get colorGrey;

  /// Hack theme color name
  ///
  /// In en, this message translates to:
  /// **'Hack'**
  String get colorHack;

  /// Blue Grey color name
  ///
  /// In en, this message translates to:
  /// **'Blue Grey'**
  String get colorBlueGrey;

  /// Custom color name
  ///
  /// In en, this message translates to:
  /// **'Custom'**
  String get colorCustom;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
  }

  // If we get here, it means no supported locale was found
  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
