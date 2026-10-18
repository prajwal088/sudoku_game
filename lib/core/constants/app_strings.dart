/// User-facing strings used across the app.
///
/// Keeping them in one place avoids typos and duplicated literals. When you
/// add more languages, migrate these to Flutter's built-in localization
/// (`flutter_localizations` + ARB files) and keep these names as the keys.
abstract final class AppStrings {
  // --------------------------------------------------------------------------
  // App
  // --------------------------------------------------------------------------

  static const String appName = 'Sudoku';

  // --------------------------------------------------------------------------
  // Game actions
  // --------------------------------------------------------------------------

  static const String newGame = 'New Game';

  // --------------------------------------------------------------------------
  // Difficulty levels
  // --------------------------------------------------------------------------

  static const String easy = 'Easy';
  static const String medium = 'Medium';
  static const String hard = 'Hard';
}