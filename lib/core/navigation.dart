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
@immutable
class GameArguments {
  final int levelNumber;

  const GameArguments({
    required this.levelNumber,
  });

  @override
  bool operator ==(Object other) {
    return other is GameArguments &&
        other.levelNumber == levelNumber;
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
  static const String levels = '/levels';

  /// Sudoku gameplay screen.
  static const String game = '/game';

  /// Application settings screen.
  static const String settings = '/settings';

  /// Player statistics screen.
  static const String statistics = '/statistics';

  /// Controlled screen displayed when mandatory application startup
  /// initialization fails.
  static const String startupError = '/startup-error';
}