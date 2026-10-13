import 'package:flutter/foundation.dart';

/// ============================================================================
/// NAVIGATION TYPES
/// ----------------------------------------------------------------------------
/// Shared navigation/configuration types used across the application.
///
/// This file contains:
/// - Route argument models.
/// - Centralized application route names.
///
/// This file does NOT contain:
/// - Game configuration.
/// - Player progression.
/// - Level counts.
/// - World counts.
/// - Persistence.
/// - Service initialization.
/// - Route construction logic.
///
/// Static game configuration belongs to:
///     config/game_config.dart
///
/// Player progression belongs to:
///     services/progress_service.dart
///
/// Actual route construction belongs to the application's router /
/// MaterialApp navigation configuration.
/// ============================================================================

/// ============================================================================
/// GAME ROUTE ARGUMENTS
/// ============================================================================
///
/// Arguments required to open a Sudoku game.
///
/// A level has exactly one canonical identity throughout the application:
///
///     levelNumber
///
/// World and local-level information must be derived from the global level
/// number when required.
///
/// This prevents multiple representations of the same level from becoming
/// inconsistent across screens and services.
///
/// The value is validated by the router (against GameConfig), not here, so
/// this file stays free of game configuration.
@immutable
class GameArguments {
  final int levelNumber;

  const GameArguments({
    required this.levelNumber,
  });

  @override
  bool operator ==(Object other) {
    return other is GameArguments && other.levelNumber == levelNumber;
  }

  @override
  int get hashCode => levelNumber.hashCode;

  @override
  String toString() {
    return 'GameArguments(levelNumber: $levelNumber)';
  }
}

/// ============================================================================
/// APPLICATION ROUTES
/// ============================================================================
///
/// Centralized application route names.
///
/// Do not scatter literal route strings throughout the application.
///
/// Route names describe destinations only. They must not contain gameplay
/// state or player progression information.
abstract final class AppRoutes {
  /// Application home screen.
  static const String home = '/';

  /// World selection screen.
  static const String worlds = '/worlds';

  /// Level selection screen.
  ///
  /// Argument: the world number (`int`).
  static const String levels = '/levels';

  /// Sudoku gameplay screen.
  ///
  /// Argument: [GameArguments].
  static const String game = '/game';

  /// Application settings screen.
  static const String settings = '/settings';

  /// Player statistics screen.
  static const String statistics = '/statistics';

  /// Controlled screen displayed when mandatory application startup
  /// initialization fails.
  ///
  /// IMPORTANT: this name intentionally has NO leading slash.
  ///
  /// When `MaterialApp.initialRoute` starts with "/", Flutter builds the
  /// parent routes first: for "/startup-error" it would build "/" (the Home
  /// screen) underneath the error screen. Home would then run against
  /// services that failed to initialize. A name without a leading slash is
  /// pushed on its own, so only the error screen is created.
  static const String startupError = 'startup-error';

  /// Every route name, for tests that verify the router handles each one.
  static const List<String> all = <String>[
    home,
    worlds,
    levels,
    game,
    settings,
    statistics,
    startupError,
  ];
}