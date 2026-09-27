// Shared navigation/config types used across the app.
// This file extracts types that were previously declared in main.dart
// so other modules can import them without creating circular imports.

import '../services/progress_service.dart';

class GameArguments {
  final int levelNumber;

  const GameArguments({required this.levelNumber});
}

class AppRoutes {
  static const String home = '/';
  static const String levels = '/levels';
  static const String game = '/game';
  static const String win = '/win';
}

class GameConfig {
  /// Number of worlds currently available in the game.
  static const int totalWorlds = 10;

  /// Number of levels per world (canonical source is ProgressService).
  static int get levelsPerWorld => ProgressService.levelsPerWorld;

  /// Total levels in the game.
  static int get totalLevels => levelsPerWorld * totalWorlds;
}
