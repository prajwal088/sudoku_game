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
  String get continueButton => 'Continue';

  @override
  String get footerText => 'Solve puzzles. Train your brain.';

  @override
  String get worldLockedMessage => 'Complete previous world to unlock';

  @override
  String get levelLockedMessage => 'Complete previous levels first!';

  @override
  String get hintButton => 'Hint';

  @override
  String get worldText => 'World';

  @override
  String get levelText => 'Level';

  @override
  String get settingsButton => 'Settings';

  @override
  String get editNameButton => 'Tap to edit';

  @override
  String get privacyPolicy => 'Privacy Policy';

  @override
  String get termsConditions => 'Terms & Conditions';

  @override
  String get gameWonTitle => 'Level Complete!';

  @override
  String get gameWonSubtitle => 'You solved the puzzle!';

  @override
  String get nextLevelButton => 'Next Level';

  @override
  String get replayButton => 'Replay Level';

  @override
  String get backToLevelMapButton => 'Back to Level Map';

  @override
  String get worldComplete => '🎉 World Complete!';

  @override
  String get lifeTimeStatistics => 'Lifetime Statistics';

  @override
  String get totalTimePlayed => 'Total Time Played';

  @override
  String get avgSolveTime => 'Avg. Solve Time';

  @override
  String get exitButton => 'Exit';

  @override
  String get worldSelectionTitle => 'Select World';

  @override
  String worldCompletion(int percentage) {
    return 'World Progress: $percentage%';
  }

  @override
  String get undoButton => 'Undo';

  @override
  String get eraseButton => 'Erase';

  @override
  String get difficultyEasy => 'Easy';

  @override
  String get difficultyMedium => 'Medium';

  @override
  String get difficultyHard => 'Hard';
}
