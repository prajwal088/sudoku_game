/// ============================================================================
/// GameConfig
/// ----------------------------------------------------------------------------
/// Central source of truth for static game configuration and gameplay rules.
///
/// This class contains immutable configuration that defines how the Sudoku
/// campaign is structured and how core gameplay limits behave.
///
/// GameConfig does NOT:
/// - Store player progress.
/// - Store unlocked levels.
/// - Store completed levels.
/// - Store stars earned by the player.
/// - Store best times.
/// - Read from or write to SharedPreferences.
/// - Manage runtime game state.
/// - Generate Sudoku puzzles.
/// - Validate a Sudoku board.
///
/// Player-specific state belongs to ProgressService.
///
/// Architecture:
///
///     GameConfig
///          │
///          ├── LevelService
///          ├── ProgressService
///          ├── WorldManager
///          ├── WorldMapScreen
///          ├── LevelMapScreen
///          ├── WinScreen
///          └── GameService
///
/// All campaign numbering is 1-based.
///
/// Example:
///
///     World 1
///       ├── Level 1  -> Global 1
///       └── Level 25 -> Global 25
///
///     World 2
///       ├── Level 1  -> Global 26
///       └── Level 25 -> Global 50
///
///     World 3
///       └── Level 5  -> Global 55
///
///     World 10
///       └── Level 25 -> Global 250
/// ============================================================================

library;

abstract final class GameConfig {
  // ==========================================================================
  // PRIVATE CONSTRUCTOR
  // ==========================================================================

  const GameConfig._();

  // ==========================================================================
  // CAMPAIGN STRUCTURE
  // ==========================================================================

  /// First valid world number.
  static const int minimumWorld = 1;

  /// First valid global campaign level.
  static const int minimumLevel = 1;

  /// First valid local level number inside a world.
  static const int minimumLocalLevel = 1;

  /// Total number of worlds in the campaign.
  static const int totalWorlds = 10;

  /// Number of levels contained in every world.
  static const int levelsPerWorld = 25;

  /// Total number of playable campaign levels.
  ///
  /// This value is derived from the campaign structure and must not be
  /// maintained independently.
  static const int totalLevels =
      totalWorlds * levelsPerWorld;

  // ==========================================================================
  // STAR SYSTEM
  // ==========================================================================

  /// Minimum number of stars that can be awarded for a completed level.
  static const int minStarsPerLevel = 0;

  /// Maximum number of stars that can be awarded for one level.
  static const int maxStarsPerLevel = 3;

  /// Maximum number of stars available in one world.
  static const int maxStarsPerWorld =
      levelsPerWorld * maxStarsPerLevel;

  /// Maximum number of stars available across the complete campaign.
  static const int maxStarsTotal =
      totalLevels * maxStarsPerLevel;

  // ==========================================================================
  // GAMEPLAY LIMITS
  // ==========================================================================

  /// Maximum number of hints that may be used during one level.
  static const int maximumHintsPerLevel = 3;

  /// Maximum number of mistakes permitted during one level.
  ///
  /// A null value means that the game does not enforce a mistake limit.
  static const int? maximumMistakesPerLevel = null;

  // ==========================================================================
  // CONFIGURATION INVARIANTS
  // ==========================================================================

  /// Validates the static configuration itself.
  ///
  /// Intended for startup assertions, tests, and diagnostics.
  ///
  /// This does not validate player state.
  static void validateConfiguration() {
    if (minimumWorld != 1) {
      throw StateError(
        'GameConfig.minimumWorld must equal 1.',
      );
    }

    if (minimumLevel != 1) {
      throw StateError(
        'GameConfig.minimumLevel must equal 1.',
      );
    }

    if (minimumLocalLevel != 1) {
      throw StateError(
        'GameConfig.minimumLocalLevel must equal 1.',
      );
    }

    if (totalWorlds <= 0) {
      throw StateError(
        'GameConfig.totalWorlds must be greater than 0.',
      );
    }

    if (levelsPerWorld <= 0) {
      throw StateError(
        'GameConfig.levelsPerWorld must be greater than 0.',
      );
    }

    if (totalLevels != totalWorlds * levelsPerWorld) {
      throw StateError(
        'GameConfig.totalLevels must equal '
        'totalWorlds * levelsPerWorld.',
      );
    }

    if (minStarsPerLevel < 0) {
      throw StateError(
        'GameConfig.minStarsPerLevel cannot be negative.',
      );
    }

    if (maxStarsPerLevel < minStarsPerLevel) {
      throw StateError(
        'GameConfig.maxStarsPerLevel cannot be less than '
        'minStarsPerLevel.',
      );
    }

    if (maximumHintsPerLevel < 0) {
      throw StateError(
        'GameConfig.maximumHintsPerLevel cannot be negative.',
      );
    }

    final int? maximumMistakes = maximumMistakesPerLevel;

    if (maximumMistakes != null && maximumMistakes < 0) {
      throw StateError(
        'GameConfig.maximumMistakesPerLevel cannot be negative.',
      );
    }

    if (maxStarsPerWorld !=
        levelsPerWorld * maxStarsPerLevel) {
      throw StateError(
        'GameConfig.maxStarsPerWorld is inconsistent '
        'with the campaign configuration.',
      );
    }

    if (maxStarsTotal !=
        totalLevels * maxStarsPerLevel) {
      throw StateError(
        'GameConfig.maxStarsTotal is inconsistent '
        'with the campaign configuration.',
      );
    }
  }

  // ==========================================================================
  // VALIDATION
  // ==========================================================================

  /// Returns true when [globalLevel] is a valid campaign level.
  static bool isValidGlobalLevel(int globalLevel) {
    return globalLevel >= minimumLevel &&
        globalLevel <= totalLevels;
  }

  /// Returns true when [world] is a valid campaign world.
  static bool isValidWorld(int world) {
    return world >= minimumWorld &&
        world <= totalWorlds;
  }

  /// Returns true when [localLevel] is valid inside a world.
  static bool isValidLocalLevel(int localLevel) {
    return localLevel >= minimumLocalLevel &&
        localLevel <= levelsPerWorld;
  }

  /// Returns true when [stars] is within the configured star range.
  static bool isValidStars(int stars) {
    return stars >= minStarsPerLevel &&
        stars <= maxStarsPerLevel;
  }

  /// Returns true when [hints] is within the configured hint range.
  static bool isValidHints(int hints) {
    return hints >= 0 &&
        hints <= maximumHintsPerLevel;
  }

  /// Returns true when [mistakes] is valid under the configured mistake rule.
  ///
  /// When [maximumMistakesPerLevel] is null, every non-negative mistake count
  /// is valid.
  static bool isValidMistakes(int mistakes) {
    if (mistakes < 0) {
      return false;
    }

    final int? maximum = maximumMistakesPerLevel;

    return maximum == null || mistakes <= maximum;
  }

  // ==========================================================================
  // WORLD / LEVEL CALCULATIONS
  // ==========================================================================

  /// Returns the first global level belonging to [world].
  ///
  /// Examples:
  /// - World 1  -> 1
  /// - World 2  -> 26
  /// - World 3  -> 51
  /// - World 10 -> 226
  static int getFirstLevelForWorld(int world) {
    _validateWorld(world);

    return ((world - minimumWorld) * levelsPerWorld) +
        minimumLevel;
  }

  /// Returns the last global level belonging to [world].
  ///
  /// Examples:
  /// - World 1  -> 25
  /// - World 2  -> 50
  /// - World 3  -> 75
  /// - World 10 -> 250
  static int getLastLevelForWorld(int world) {
    _validateWorld(world);

    return getFirstLevelForWorld(world) +
        levelsPerWorld -
        1;
  }

  /// Converts a global level to its world number.
  ///
  /// Examples:
  /// - Global 1   -> World 1
  /// - Global 25  -> World 1
  /// - Global 26  -> World 2
  /// - Global 55  -> World 3
  /// - Global 250 -> World 10
  static int getWorldFromGlobalLevel(int globalLevel) {
    _validateGlobalLevel(globalLevel);

    return ((globalLevel - minimumLevel) ~/
            levelsPerWorld) +
        minimumWorld;
  }

  /// Converts a global level to its local level inside its world.
  ///
  /// Examples:
  /// - Global 1  -> Local 1
  /// - Global 25 -> Local 25
  /// - Global 26 -> Local 1
  /// - Global 30 -> Local 5
  /// - Global 55 -> Local 5
  static int getLocalLevelFromGlobalLevel(
    int globalLevel,
  ) {
    _validateGlobalLevel(globalLevel);

    return ((globalLevel - minimumLevel) %
            levelsPerWorld) +
        minimumLocalLevel;
  }

  /// Converts a world and local level into a global level.
  ///
  /// Examples:
  /// - World 1, Level 1  -> Global 1
  /// - World 1, Level 25 -> Global 25
  /// - World 2, Level 1  -> Global 26
  /// - World 3, Level 5  -> Global 55
  /// - World 10, Level 25 -> Global 250
  static int getGlobalLevel(
    int world,
    int localLevel,
  ) {
    _validateWorld(world);
    _validateLocalLevel(localLevel);

    return ((world - minimumWorld) * levelsPerWorld) +
        localLevel;
  }

  /// Returns both world and local level for a global level.
  ///
  /// The returned map contains:
  /// - `world`
  /// - `level`
  ///
  /// Prefer the individual conversion methods when only one value is needed.
  static Map<String, int> getWorldAndLocalLevel(
    int globalLevel,
  ) {
    _validateGlobalLevel(globalLevel);

    return <String, int>{
      'world': getWorldFromGlobalLevel(globalLevel),
      'level': getLocalLevelFromGlobalLevel(globalLevel),
    };
  }

  // ==========================================================================
  // WORLD COMPLETION
  // ==========================================================================

  /// Returns true when [globalLevel] is the final level of its world.
  ///
  /// Examples:
  /// - Level 25 -> true
  /// - Level 50 -> true
  /// - Level 75 -> true
  /// - Level 26 -> false
  static bool completesWorld(int globalLevel) {
    _validateGlobalLevel(globalLevel);

    return getLocalLevelFromGlobalLevel(globalLevel) ==
        levelsPerWorld;
  }

  /// Returns true when [world] is the final configured world.
  static bool isFinalWorld(int world) {
    _validateWorld(world);

    return world == totalWorlds;
  }

  /// Returns true when [globalLevel] is the final campaign level.
  static bool isFinalLevel(int globalLevel) {
    _validateGlobalLevel(globalLevel);

    return globalLevel == totalLevels;
  }

  // ==========================================================================
  // NAVIGATION
  // ==========================================================================

  /// Returns the next global level.
  ///
  /// Returns null when [globalLevel] is the final campaign level.
  static int? getNextGlobalLevel(int globalLevel) {
    _validateGlobalLevel(globalLevel);

    if (isFinalLevel(globalLevel)) {
      return null;
    }

    return globalLevel + 1;
  }

  /// Returns the previous global level.
  ///
  /// Returns null when [globalLevel] is the first campaign level.
  static int? getPreviousGlobalLevel(
    int globalLevel,
  ) {
    _validateGlobalLevel(globalLevel);

    if (globalLevel == minimumLevel) {
      return null;
    }

    return globalLevel - 1;
  }

  // ==========================================================================
  // WORLD NAVIGATION
  // ==========================================================================

  /// Returns the next world.
  ///
  /// Returns null when [world] is the final world.
  static int? getNextWorld(int world) {
    _validateWorld(world);

    if (isFinalWorld(world)) {
      return null;
    }

    return world + 1;
  }

  /// Returns the previous world.
  ///
  /// Returns null when [world] is the first world.
  static int? getPreviousWorld(int world) {
    _validateWorld(world);

    if (world == minimumWorld) {
      return null;
    }

    return world - 1;
  }

  // ==========================================================================
  // RANGE HELPERS
  // ==========================================================================

  /// Returns the inclusive global-level range for [world].
  ///
  /// Example for World 2:
  ///
  ///     [26, 50]
  static List<int> getLevelRangeForWorld(int world) {
    final int first = getFirstLevelForWorld(world);
    final int last = getLastLevelForWorld(world);

    return <int>[first, last];
  }

  /// Returns the number of levels configured in [world].
  ///
  /// This currently always equals [levelsPerWorld].
  static int getLevelCountForWorld(int world) {
    _validateWorld(world);

    return levelsPerWorld;
  }

  // ==========================================================================
  // CONFIGURATION SUMMARY
  // ==========================================================================

  /// Returns a human-readable configuration summary.
  ///
  /// Primarily useful for diagnostics and development logging.
  static String get summary {
    return 'GameConfig('
        'worlds: $totalWorlds, '
        'levelsPerWorld: $levelsPerWorld, '
        'totalLevels: $totalLevels, '
        'starsPerLevel: $maxStarsPerLevel, '
        'maxStarsPerWorld: $maxStarsPerWorld, '
        'maxStarsTotal: $maxStarsTotal, '
        'maximumHintsPerLevel: $maximumHintsPerLevel, '
        'maximumMistakesPerLevel: '
        '$maximumMistakesPerLevel'
        ')';
  }

  // ==========================================================================
  // PRIVATE VALIDATION HELPERS
  // ==========================================================================

  static void _validateGlobalLevel(int globalLevel) {
    if (!isValidGlobalLevel(globalLevel)) {
      throw ArgumentError.value(
        globalLevel,
        'globalLevel',
        'Global level must be between '
            '$minimumLevel and $totalLevels.',
      );
    }
  }

  static void _validateWorld(int world) {
    if (!isValidWorld(world)) {
      throw ArgumentError.value(
        world,
        'world',
        'World must be between '
            '$minimumWorld and $totalWorlds.',
      );
    }
  }

  static void _validateLocalLevel(int localLevel) {
    if (!isValidLocalLevel(localLevel)) {
      throw ArgumentError.value(
        localLevel,
        'localLevel',
        'Local level must be between '
            '$minimumLocalLevel and $levelsPerWorld.',
      );
    }
  }
}