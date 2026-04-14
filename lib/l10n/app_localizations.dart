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
  static const List<Locale> supportedLocales = <Locale>[Locale('en')];

  /// The main title of the application
  ///
  /// In en, this message translates to:
  /// **'Sudoku World'**
  String get appTitle;

  /// Button to start the game from the main menu
  ///
  /// In en, this message translates to:
  /// **'Play'**
  String get playButton;

  /// Button to continue an ongoing game level
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get continueButton;

  /// game text
  ///
  /// In en, this message translates to:
  /// **'Solve puzzles. Train your brain.'**
  String get footerText;

  /// Message shown when a user tries to access a locked world
  ///
  /// In en, this message translates to:
  /// **'Complete previous world to unlock'**
  String get worldLockedMessage;

  /// Message shown when a user tries to access a locked level
  ///
  /// In en, this message translates to:
  /// **'Complete previous levels first!'**
  String get levelLockedMessage;

  /// Label for the hint feature
  ///
  /// In en, this message translates to:
  /// **'Hint'**
  String get hintButton;

  /// world Text
  ///
  /// In en, this message translates to:
  /// **'World'**
  String get worldText;

  /// Level Text
  ///
  /// In en, this message translates to:
  /// **'Level'**
  String get levelText;

  /// Button to open the settings menu
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsButton;

  /// Button to edit name
  ///
  /// In en, this message translates to:
  /// **'Tap to edit'**
  String get editNameButton;

  /// Link text for the privacy policy
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get privacyPolicy;

  /// Link text for terms and conditions
  ///
  /// In en, this message translates to:
  /// **'Terms & Conditions'**
  String get termsConditions;

  /// Celebratory text shown when a puzzle is solved
  ///
  /// In en, this message translates to:
  /// **'Level Complete!'**
  String get gameWonTitle;

  /// Sub-text shown under the level complete title
  ///
  /// In en, this message translates to:
  /// **'You solved the puzzle!'**
  String get gameWonSubtitle;

  /// Button to progress to the next puzzle
  ///
  /// In en, this message translates to:
  /// **'Next Level'**
  String get nextLevelButton;

  /// Button to restart the current level
  ///
  /// In en, this message translates to:
  /// **'Replay Level'**
  String get replaynButton;

  /// Button to return to level map
  ///
  /// In en, this message translates to:
  /// **'Back to Level Map'**
  String get backToLevelMapButton;

  /// world complete text
  ///
  /// In en, this message translates to:
  /// **'🎉 World Complete!'**
  String get worldComplete;

  /// Lifetime Statistics
  ///
  /// In en, this message translates to:
  /// **'Lifetime Statistics'**
  String get lifeTimeStatistics;

  /// Total Time Played
  ///
  /// In en, this message translates to:
  /// **'Total Time Played'**
  String get totalTimePlayed;

  /// Avg. Solve Time
  ///
  /// In en, this message translates to:
  /// **'Avg. Solve Time'**
  String get avgSolveTime;

  /// Button to close the application
  ///
  /// In en, this message translates to:
  /// **'Exit'**
  String get exitButton;

  /// Title for the world selection screen
  ///
  /// In en, this message translates to:
  /// **'Select World'**
  String get worldSelectionTitle;

  /// Shows the completion percentage of a world
  ///
  /// In en, this message translates to:
  /// **'World Progress: {percentage}%'**
  String worldCompletion(int percentage);

  /// Label for the undo move button
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get undoButton;

  /// Label for the tool used to clear a cell
  ///
  /// In en, this message translates to:
  /// **'Erase'**
  String get eraseButton;

  /// Label for easy difficulty
  ///
  /// In en, this message translates to:
  /// **'Easy'**
  String get difficultyEasy;

  /// Label for medium difficulty
  ///
  /// In en, this message translates to:
  /// **'Medium'**
  String get difficultyMedium;

  /// Label for hard difficulty
  ///
  /// In en, this message translates to:
  /// **'Hard'**
  String get difficultyHard;
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

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
