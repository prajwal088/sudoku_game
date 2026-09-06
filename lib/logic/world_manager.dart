import '../services/progress_service.dart';

/// Provides deterministic conversions between global levels, worlds,
/// and batches.
///
/// [ProgressService] is the single source of truth for game configuration
/// such as the number of levels per world.
///
/// Responsibilities:
/// - Global level -> world conversion
/// - World + local level -> global level conversion
/// - World -> batch conversion
/// - World level range calculations
/// - Batch world range calculations
/// - World/batch completion boundary calculations
///
/// This class does NOT:
/// - Store progress
/// - Persist data
/// - Track unlocked worlds
/// - Track completed levels
/// - Track stars or best times
/// - Modify [ProgressService]
///
/// All indexes are 1-based.
///
/// Example with 25 levels per world and 10 worlds per batch:
///
/// ```text
/// Global Level 1   -> World 1, Level 1
/// Global Level 25  -> World 1, Level 25
/// Global Level 26  -> World 2, Level 1
///
/// World 1  -> Batch 1
/// World 10 -> Batch 1
/// World 11 -> Batch 2
///
/// World 1  -> Global Levels 1..25
/// World 2  -> Global Levels 26..50
///
/// Batch 1 -> Worlds 1..10
/// Batch 2 -> Worlds 11..20
/// ```
abstract final class WorldManager {
  // ==========================================================================
  // GAME CONFIGURATION
  // ==========================================================================

  /// Number of levels contained in one world.
  ///
  /// [ProgressService.levelsPerWorld] is the single source of truth.
  static int get levelsPerWorld => ProgressService.levelsPerWorld;

  /// Number of worlds contained in one batch.
  ///
  /// This is structural configuration owned by WorldManager because it
  /// describes how worlds are grouped, not player progression.
  static const int worldsPerBatch = 10;

  /// Minimum valid 1-based index.
  static const int _minimumIndex = 1;

  // ==========================================================================
  // LEVEL -> WORLD
  // ==========================================================================

  /// Converts a global 1-based [levelIndex] to its 1-based world number.
  ///
  /// Examples with 25 levels per world:
  ///
  /// ```text
  /// Level 1   -> World 1
  /// Level 25  -> World 1
  /// Level 26  -> World 2
  /// Level 50  -> World 2
  /// Level 51  -> World 3
  /// ```
  static int getLevelToWorld(int levelIndex) {
    _validatePositiveIndex(levelIndex, 'levelIndex');

    return ((levelIndex - 1) ~/ levelsPerWorld) + 1;
  }

  // ==========================================================================
  // LEVEL -> LOCAL LEVEL
  // ==========================================================================

  /// Converts a global 1-based [levelIndex] to its 1-based level number
  /// within the world.
  ///
  /// Examples with 25 levels per world:
  ///
  /// ```text
  /// Global 1  -> Local Level 1
  /// Global 25 -> Local Level 25
  /// Global 26 -> Local Level 1
  /// Global 50 -> Local Level 25
  /// ```
  static int getLevelInWorld(int levelIndex) {
    _validatePositiveIndex(levelIndex, 'levelIndex');

    return ((levelIndex - 1) % levelsPerWorld) + 1;
  }

  // ==========================================================================
  // WORLD + LOCAL LEVEL -> GLOBAL LEVEL
  // ==========================================================================

  /// Converts a 1-based [worldNumber] and 1-based local [levelNumber]
  /// to a global level number.
  ///
  /// Examples with 25 levels per world:
  ///
  /// ```text
  /// World 1, Level 1  -> Global Level 1
  /// World 1, Level 25 -> Global Level 25
  /// World 2, Level 1  -> Global Level 26
  /// World 2, Level 25 -> Global Level 50
  /// ```
  static int getGlobalLevel(int worldNumber, int levelNumber) {
    _validatePositiveIndex(worldNumber, 'worldNumber');
    _validateLocalLevel(levelNumber);

    return ((worldNumber - 1) * levelsPerWorld) + levelNumber;
  }

  // ==========================================================================
  // WORLD -> BATCH
  // ==========================================================================

  /// Converts a 1-based [worldNumber] to its 1-based batch number.
  ///
  /// Examples:
  ///
  /// ```text
  /// World 1  -> Batch 1
  /// World 10 -> Batch 1
  /// World 11 -> Batch 2
  /// World 20 -> Batch 2
  /// ```
  static int getWorldToBatch(int worldNumber) {
    _validatePositiveIndex(worldNumber, 'worldNumber');

    return ((worldNumber - 1) ~/ worldsPerBatch) + 1;
  }

  // ==========================================================================
  // BATCH -> WORLD RANGE
  // ==========================================================================

  /// Returns the first world belonging to [batchNumber].
  ///
  /// Examples:
  ///
  /// ```text
  /// Batch 1 -> World 1
  /// Batch 2 -> World 11
  /// Batch 3 -> World 21
  /// ```
  static int getBatchFirstWorld(int batchNumber) {
    _validatePositiveIndex(batchNumber, 'batchNumber');

    return ((batchNumber - 1) * worldsPerBatch) + 1;
  }

  /// Returns the last world belonging to [batchNumber].
  ///
  /// Examples:
  ///
  /// ```text
  /// Batch 1 -> World 10
  /// Batch 2 -> World 20
  /// Batch 3 -> World 30
  /// ```
  static int getBatchLastWorld(int batchNumber) {
    _validatePositiveIndex(batchNumber, 'batchNumber');

    return batchNumber * worldsPerBatch;
  }

  // ==========================================================================
  // WORLD -> LEVEL RANGE
  // ==========================================================================

  /// Returns the first global level belonging to [worldNumber].
  ///
  /// Examples with 25 levels per world:
  ///
  /// ```text
  /// World 1 -> Level 1
  /// World 2 -> Level 26
  /// World 3 -> Level 51
  /// ```
  static int getWorldFirstLevelIndex(int worldNumber) {
    _validatePositiveIndex(worldNumber, 'worldNumber');

    return ((worldNumber - 1) * levelsPerWorld) + 1;
  }

  /// Returns the last global level belonging to [worldNumber].
  ///
  /// Examples with 25 levels per world:
  ///
  /// ```text
  /// World 1 -> Level 25
  /// World 2 -> Level 50
  /// World 3 -> Level 75
  /// ```
  static int getWorldLastLevelIndex(int worldNumber) {
    _validatePositiveIndex(worldNumber, 'worldNumber');

    return worldNumber * levelsPerWorld;
  }

  // ==========================================================================
  // LEVEL -> BATCH
  // ==========================================================================

  /// Converts a global 1-based [levelIndex] to its 1-based batch number.
  ///
  /// This is equivalent to:
  ///
  /// ```dart
  /// getWorldToBatch(getLevelToWorld(levelIndex))
  /// ```
  ///
  /// but avoids performing the intermediate conversion twice.
  static int getLevelToBatch(int levelIndex) {
    _validatePositiveIndex(levelIndex, 'levelIndex');

    final world = ((levelIndex - 1) ~/ levelsPerWorld) + 1;

    return ((world - 1) ~/ worldsPerBatch) + 1;
  }

  // ==========================================================================
  // LEVEL -> WORLD + LOCAL LEVEL
  // ==========================================================================

  /// Returns the world and local level for a global [levelIndex].
  ///
  /// The returned map contains:
  ///
  /// ```text
  /// world -> world number
  /// level -> local level number
  /// ```
  ///
  /// Example:
  ///
  /// ```dart
  /// WorldManager.getWorldAndLevel(26);
  ///
  /// // {
  /// //   'world': 2,
  /// //   'level': 1,
  /// // }
  /// ```
  static Map<String, int> getWorldAndLevel(int levelIndex) {
    _validatePositiveIndex(levelIndex, 'levelIndex');

    return <String, int>{
      'world': getLevelToWorld(levelIndex),
      'level': getLevelInWorld(levelIndex),
    };
  }

  // ==========================================================================
  // WORLD COMPLETION BOUNDARIES
  // ==========================================================================

  /// Returns true when [levelIndex] is the final level of a world.
  ///
  /// Examples with 25 levels per world:
  ///
  /// ```text
  /// Level 25 -> true
  /// Level 50 -> true
  /// Level 26 -> false
  /// ```
  static bool completesWorld(int levelIndex) {
    _validatePositiveIndex(levelIndex, 'levelIndex');

    return levelIndex % levelsPerWorld == 0;
  }

  /// Returns true when [levelNumber] is the final level within a world.
  ///
  /// This is useful when working with a local level number rather than
  /// a global level number.
  static bool isLastLevelInWorld(int levelNumber) {
    _validateLocalLevel(levelNumber);

    return levelNumber == levelsPerWorld;
  }

  // ==========================================================================
  // BATCH COMPLETION BOUNDARIES
  // ==========================================================================

  /// Returns true when [levelIndex] is the final level of the final world
  /// in a batch.
  ///
  /// Examples with 25 levels per world and 10 worlds per batch:
  ///
  /// ```text
  /// Level 250 -> true
  /// Level 500 -> true
  /// Level 225 -> false
  /// ```
  static bool completesBatch(int levelIndex) {
    _validatePositiveIndex(levelIndex, 'levelIndex');

    if (!completesWorld(levelIndex)) {
      return false;
    }

    final world = getLevelToWorld(levelIndex);

    return world % worldsPerBatch == 0;
  }

  /// Returns true when [worldNumber] is the final world in its batch.
  ///
  /// Examples:
  ///
  /// ```text
  /// World 10 -> true
  /// World 20 -> true
  /// World 11 -> false
  /// ```
  static bool completesBatchByWorld(int worldNumber) {
    _validatePositiveIndex(worldNumber, 'worldNumber');

    return worldNumber % worldsPerBatch == 0;
  }

  // ==========================================================================
  // WORLD -> BATCH POSITION
  // ==========================================================================

  /// Returns the 1-based position of [worldNumber] within its batch.
  ///
  /// Examples:
  ///
  /// ```text
  /// World 1  -> 1
  /// World 10 -> 10
  /// World 11 -> 1
  /// World 15 -> 5
  /// ```
  static int getWorldPositionInBatch(int worldNumber) {
    _validatePositiveIndex(worldNumber, 'worldNumber');

    return ((worldNumber - 1) % worldsPerBatch) + 1;
  }

  // ==========================================================================
  // CONFIGURATION VALIDATION
  // ==========================================================================

  /// Validates the configuration supplied by [ProgressService].
  ///
  /// This is primarily a defensive guard against an invalid configuration
  /// such as levelsPerWorld == 0, which would otherwise cause division by
  /// zero during calculations.
  static void _validateConfiguration() {
    if (levelsPerWorld < _minimumIndex) {
      throw StateError(
        'ProgressService.levelsPerWorld must be at least '
        '$_minimumIndex, but was $levelsPerWorld.',
      );
    }

    if (worldsPerBatch < _minimumIndex) {
      throw StateError(
        'WorldManager.worldsPerBatch must be at least '
        '$_minimumIndex, but was $worldsPerBatch.',
      );
    }
  }

  // ==========================================================================
  // VALIDATION
  // ==========================================================================

  static void _validatePositiveIndex(int value, String parameterName) {
    _validateConfiguration();

    if (value < _minimumIndex) {
      throw ArgumentError.value(
        value,
        parameterName,
        'Value must be at least $_minimumIndex.',
      );
    }
  }

  static void _validateLocalLevel(int levelNumber) {
    _validateConfiguration();

    if (levelNumber < _minimumIndex || levelNumber > levelsPerWorld) {
      throw ArgumentError.value(
        levelNumber,
        'levelNumber',
        'Level must be between '
            '$_minimumIndex and $levelsPerWorld.',
      );
    }
  }
}
