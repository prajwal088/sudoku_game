// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Sudoku World';

  @override
  String get playButton => 'Play';

  @override
  String get resumeButton => 'Resume';

  @override
  String get settingsButton => 'Settings';

  @override
  String get exitButton => 'Exit';

  @override
  String get worldSelectionTitle => 'Select World';

  @override
  String get worldLockedMessage => 'Unlock previous world to enter';

  @override
  String worldCompletion(int percentage) {
    return 'World Progress: $percentage%';
  }

  @override
  String levelLabel(int number) {
    return 'Level $number';
  }

  @override
  String get gameWonTitle => 'Level Complete!';

  @override
  String get gameWonSubtitle => 'You solved the puzzle!';

  @override
  String get nextLevelButton => 'Next Level';

  @override
  String get tryAgainButton => 'Try Again';

  @override
  String timerLabel(String minutes, String seconds) {
    return 'Time: $minutes:$seconds';
  }

  @override
  String mistakesLabel(int count) {
    return 'Mistakes: $count/3';
  }

  @override
  String get hintButton => 'Hint';

  @override
  String get undoButton => 'Undo';

  @override
  String get eraseButton => 'Erase';

  @override
  String get notesButton => 'Notes';

  @override
  String get difficultyEasy => 'Easy';

  @override
  String get difficultyMedium => 'Medium';

  @override
  String get difficultyHard => 'Hard';

  @override
  String get difficultyExpert => 'Expert';

  @override
  String get privacyPolicy => 'Privacy Policy';

  @override
  String get termsConditions => 'Terms & Conditions';
}
