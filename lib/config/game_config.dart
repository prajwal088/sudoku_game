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
/// All campaign numbering is 1-based.
///
/// Each world defines its OWN number of levels (see [GameConfig.worlds]).
/// Global level numbers run continuously across worlds, so the first level of
/// a world is always the last level of the previous world + 1.
///
/// Example: worlds with 20, 25 and 30 levels
///
///     World 1  -> Global 1  .. 20
///     World 2  -> Global 21 .. 45
///     World 3  -> Global 46 .. 75
///
/// IMPORTANT: ProgressService stores progress by GLOBAL level number. After
/// release, do not change the level count of an existing world, because that
/// shifts every later level and breaks saved progress. Only add new worlds at
/// the end of the list (or add levels to the last world).
///
/// Implementation note:
/// Public methods validate their arguments exactly once and then use private,
/// unchecked helpers for the arithmetic, so composite operations (for example
/// [splitGlobalLevel]) do not re-validate the same value repeatedly.
/// ============================================================================
library;

/// Definition of one campaign world.
final class WorldConfig {
  /// Display name of the world (e.g. for the world map screen).
  final String name;

  /// Number of levels contained in this world. Must be greater than 0.
  final int levels;

  const WorldConfig(this.name, this.levels);
}

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

  /// The campaign layout: one entry per world, in order (first entry = world 1).
  ///
  /// Edit ONLY this list to change how many worlds exist and how many levels
  /// each world has. Everything else is derived from it.
  ///
  /// TODO(production): development layout below. Replace it with the real
  /// layout before release. It must stay in sync with the puzzle sets/assets
  /// you ship and with saved progress (see ProgressService).
  ///
  /// Tip: use collection-for to describe many worlds with the same size on a
  /// single line, and write out special worlds individually. Example:
  ///
  /// ```dart
  /// static final List<WorldConfig> worlds = List.unmodifiable(<WorldConfig>[
  ///   WorldConfig('Meadow', 20),                                // world 1
  ///   WorldConfig('Forest', 25),                                // world 2
  ///   for (int i = 3; i <= 12; i++) WorldConfig('World $i', 30), // worlds 3-12
  ///   for (int i = 13; i <= 50; i++) WorldConfig('World $i', 40), // 13-50
  /// ]);
  /// ```
  static final List<WorldConfig> worlds = List<WorldConfig>.unmodifiable(
    <WorldConfig>[
      WorldConfig('World 1', 3), // world 1
      WorldConfig('World 2', 3), // world 2
      WorldConfig('World 3', 3), // world 3
      WorldConfig('World 4', 3), // world 4
    ],
  );

  /// Total number of worlds in the campaign.
  static int get totalWorlds => worlds.length;

  /// Total number of playable campaign levels.
  ///
  /// Derived from [worlds]; never maintain it independently.
  /// NOTE: this is no longer a compile-time constant, so it cannot be used in
  /// `const` expressions.
  static final int totalLevels = _firstLevels.last - minimumLevel;

  /// First global level of each world (index 0 = world 1), plus one final
  /// sentinel entry equal to `totalLevels + 1`.
  static final List<int> _firstLevels = _buildFirstLevels();

  static List<int> _buildFirstLevels() {
    final List<int> starts = <int>[];
    int next = minimumLevel;

    for (final WorldConfig world in worlds) {
      starts.add(next);
      next += world.levels;
    }

    starts.add(next); // Sentinel: one past the last level.

    return List<int>.unmodifiable(starts);
  }

  // ==========================================================================
  // STAR SYSTEM
  // ==========================================================================

  /// Minimum number of stars that can be awarded for a completed level.
  static const int minStarsPerLevel = 0;

  /// Maximum number of stars that can be awarded for one level.
  static const int maxStarsPerLevel = 3;

  /// Maximum number of stars available across the complete campaign.
  static final int maxStarsTotal = totalLevels * maxStarsPerLevel;

  /// Maximum number of stars available in [world].
  ///
  /// Replaces the old constant `maxStarsPerWorld`, which only made sense when
  /// every world had the same number of levels.
  static int getMaxStarsForWorld(int world) {
    _validateWorld(world);

    return _levelCountOf(world) * maxStarsPerLevel;
  }

  // ==========================================================================
  // GAMEPLAY LIMITS
  // ==========================================================================

  /// Maximum number of hints usable in one level.
  ///
  /// TODO(production): development value. 1000 is effectively unlimited, which
  /// makes hint-based star rules trivial. Replace it with the real limit (or a
  /// player-inventory service) once the hint economy is decided.
  static const int maximumHintsPerLevel = 1000;

  /// Maximum number of mistakes permitted during one level.
  ///
  /// A null value means that the game does not enforce a mistake limit.
  static const int? maximumMistakesPerLevel = null;

  // ==========================================================================
  // CONFIGURATION INVARIANTS
  // ==========================================================================

  /// Validates the static configuration itself.
  ///
  /// Intended for startup assertions, tests, and diagnostics. It guards
  /// against editing mistakes in [worlds] and the other constants.
  ///
  /// Recommended usage (debug builds only, zero cost in release):
  ///
  /// ```dart
  /// assert(() {
  ///   GameConfig.validateConfiguration();
  ///   return true;
  /// }());
  /// ```
  ///
  /// This does not validate player state.
  static void validateConfiguration() {
    if (minimumWorld != 1) {
      throw StateError('GameConfig.minimumWorld must equal 1.');
    }

    if (minimumLevel != 1) {
      throw StateError('GameConfig.minimumLevel must equal 1.');
    }

    if (minimumLocalLevel != 1) {
      throw StateError('GameConfig.minimumLocalLevel must equal 1.');
    }

    if (worlds.isEmpty) {
      throw StateError('GameConfig.worlds must contain at least one world.');
    }

    int levelSum = 0;

    for (int i = 0; i < worlds.length; i++) {
      final WorldConfig world = worlds[i];

      if (world.levels <= 0) {
        throw StateError(
          'GameConfig.worlds: world ${i + 1} (${world.name}) must have '
          'more than 0 levels, but has ${world.levels}.',
        );
      }

      levelSum += world.levels;
    }

    if (totalLevels != levelSum) {
      throw StateError(
        'GameConfig.totalLevels ($totalLevels) must equal the sum of all '
        'world level counts ($levelSum).',
      );
    }

    if (_firstLevels.length != worlds.length + 1) {
      throw StateError('GameConfig internal level table is inconsistent.');
    }

    if (minStarsPerLevel < 0) {
      throw StateError('GameConfig.minStarsPerLevel cannot be negative.');
    }

    if (maxStarsPerLevel < minStarsPerLevel) {
      throw StateError(
        'GameConfig.maxStarsPerLevel cannot be less than minStarsPerLevel.',
      );
    }

    if (maximumHintsPerLevel < 0) {
      throw StateError('GameConfig.maximumHintsPerLevel cannot be negative.');
    }

    final int? maximumMistakes = maximumMistakesPerLevel;

    if (maximumMistakes != null && maximumMistakes < 0) {
      throw StateError(
        'GameConfig.maximumMistakesPerLevel cannot be negative.',
      );
    }

    if (maxStarsTotal != totalLevels * maxStarsPerLevel) {
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
    return globalLevel >= minimumLevel && globalLevel <= totalLevels;
  }

  /// Returns true when [world] is a valid campaign world.
  static bool isValidWorld(int world) {
    return world >= minimumWorld && world <= totalWorlds;
  }

  /// Returns true when [localLevel] is valid inside [world].
  ///
  /// Now takes the world, because worlds can have different sizes.
  static bool isValidLocalLevel(int world, int localLevel) {
    return isValidWorld(world) &&
        localLevel >= minimumLocalLevel &&
        localLevel <= _levelCountOf(world);
  }

  /// Returns true when [stars] is within the configured star range.
  static bool isValidStars(int stars) {
    return stars >= minStarsPerLevel && stars <= maxStarsPerLevel;
  }

  /// Returns true when [hints] is within the configured hint range.
  static bool isValidHints(int hints) {
    return hints >= 0 && hints <= maximumHintsPerLevel;
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

  /// Returns the display name of [world].
  static String getWorldName(int world) {
    _validateWorld(world);

    return worlds[world - minimumWorld].name;
  }

  /// Returns the first global level belonging to [world].
  static int getFirstLevelForWorld(int world) {
    _validateWorld(world);

    return _firstLevelOf(world);
  }

  /// Returns the last global level belonging to [world].
  static int getLastLevelForWorld(int world) {
    _validateWorld(world);

    return _lastLevelOf(world);
  }

  /// Converts a global level to its world number.
  static int getWorldFromGlobalLevel(int globalLevel) {
    _validateGlobalLevel(globalLevel);

    return _worldOf(globalLevel);
  }

  /// Converts a global level to its local level inside its world.
  static int getLocalLevelFromGlobalLevel(int globalLevel) {
    _validateGlobalLevel(globalLevel);

    return _localLevelOf(globalLevel, _worldOf(globalLevel));
  }

  /// Converts a world and local level into a global level.
  static int getGlobalLevel(int world, int localLevel) {
    _validateWorld(world);
    _validateLocalLevel(world, localLevel);

    return _firstLevelOf(world) + (localLevel - minimumLocalLevel);
  }

  /// Returns both world and local level for a global level.
  ///
  /// The returned map contains:
  /// - `world`
  /// - `level`
  ///
  /// Prefer [splitGlobalLevel] in new code: it is type-safe and does not
  /// allocate a map. This method is kept for backwards compatibility.
  static Map<String, int> getWorldAndLocalLevel(int globalLevel) {
    _validateGlobalLevel(globalLevel);

    final int world = _worldOf(globalLevel);

    return <String, int>{
      'world': world,
      'level': _localLevelOf(globalLevel, world),
    };
  }

  /// Returns the world and local level for [globalLevel] as a record.
  ///
  /// ```dart
  /// final (:world, :level) = GameConfig.splitGlobalLevel(55);
  /// ```
  static ({int world, int level}) splitGlobalLevel(int globalLevel) {
    _validateGlobalLevel(globalLevel);

    final int world = _worldOf(globalLevel);

    return (world: world, level: _localLevelOf(globalLevel, world));
  }

  // ==========================================================================
  // WORLD COMPLETION
  // ==========================================================================

  /// Returns true when [globalLevel] is the final level of its world.
  static bool completesWorld(int globalLevel) {
    _validateGlobalLevel(globalLevel);

    return globalLevel == _lastLevelOf(_worldOf(globalLevel));
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
  // LEVEL NAVIGATION
  // ==========================================================================

  /// Returns the next global level.
  ///
  /// Returns null when [globalLevel] is the final campaign level.
  static int? getNextGlobalLevel(int globalLevel) {
    _validateGlobalLevel(globalLevel);

    return globalLevel == totalLevels ? null : globalLevel + 1;
  }

  /// Returns the previous global level.
  ///
  /// Returns null when [globalLevel] is the first campaign level.
  static int? getPreviousGlobalLevel(int globalLevel) {
    _validateGlobalLevel(globalLevel);

    return globalLevel == minimumLevel ? null : globalLevel - 1;
  }

  // ==========================================================================
  // WORLD NAVIGATION
  // ==========================================================================

  /// Returns the next world.
  ///
  /// Returns null when [world] is the final world.
  static int? getNextWorld(int world) {
    _validateWorld(world);

    return world == totalWorlds ? null : world + 1;
  }

  /// Returns the previous world.
  ///
  /// Returns null when [world] is the first world.
  static int? getPreviousWorld(int world) {
    _validateWorld(world);

    return world == minimumWorld ? null : world - 1;
  }

  // ==========================================================================
  // RANGE HELPERS
  // ==========================================================================

  /// Returns the inclusive global-level range for [world] as `[first, last]`.
  static List<int> getLevelRangeForWorld(int world) {
    _validateWorld(world);

    return <int>[_firstLevelOf(world), _lastLevelOf(world)];
  }

  /// Returns the number of levels configured in [world].
  static int getLevelCountForWorld(int world) {
    _validateWorld(world);

    return _levelCountOf(world);
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
        'totalLevels: $totalLevels, '
        'starsPerLevel: $maxStarsPerLevel, '
        'maxStarsTotal: $maxStarsTotal, '
        'maximumHintsPerLevel: $maximumHintsPerLevel, '
        'maximumMistakesPerLevel: $maximumMistakesPerLevel'
        ')';
  }

  /// Returns a multi-line table of every world, its level count and its global
  /// level range. Handy for checking a large layout at a glance:
  ///
  /// ```dart
  /// debugPrint(GameConfig.layoutTable);
  /// ```
  ///
  /// Example output:
  ///
  ///     World  1 (Meadow): 20 levels -> global 1-20
  ///     World  2 (Forest): 25 levels -> global 21-45
  ///     Total: 2 worlds, 45 levels
  static String get layoutTable {
    final StringBuffer buffer = StringBuffer();
    final int widthOfWorldNumber = totalWorlds.toString().length;

    for (int world = minimumWorld; world <= totalWorlds; world++) {
      buffer.writeln(
        'World ${world.toString().padLeft(widthOfWorldNumber)} '
        '(${worlds[world - minimumWorld].name}): '
        '${_levelCountOf(world)} levels -> '
        'global ${_firstLevelOf(world)}-${_lastLevelOf(world)}',
      );
    }

    buffer.write('Total: $totalWorlds worlds, $totalLevels levels');

    return buffer.toString();
  }

  // ==========================================================================
  // PRIVATE ARITHMETIC (UNCHECKED)
  // ==========================================================================
  //
  // These assume their argument has already been validated by the caller.
  // They exist so each public method validates once and the formulas live in
  // exactly one place.
  // ==========================================================================

  static int _levelCountOf(int world) {
    return worlds[world - minimumWorld].levels;
  }

  static int _firstLevelOf(int world) {
    return _firstLevels[world - minimumWorld];
  }

  static int _lastLevelOf(int world) {
    // The next entry is the first level of the following world (or the
    // sentinel for the final world).
    return _firstLevels[world - minimumWorld + 1] - 1;
  }

  /// Binary search: finds the last world whose first level is <= [globalLevel].
  static int _worldOf(int globalLevel) {
    int low = 0;
    int high = worlds.length - 1;

    while (low < high) {
      final int middle = (low + high + 1) >> 1;

      if (_firstLevels[middle] <= globalLevel) {
        low = middle;
      } else {
        high = middle - 1;
      }
    }

    return low + minimumWorld;
  }

  static int _localLevelOf(int globalLevel, int world) {
    return globalLevel - _firstLevelOf(world) + minimumLocalLevel;
  }

  // ==========================================================================
  // PRIVATE VALIDATION HELPERS
  // ==========================================================================

  static void _validateGlobalLevel(int globalLevel) {
    if (!isValidGlobalLevel(globalLevel)) {
      throw ArgumentError.value(
        globalLevel,
        'globalLevel',
        'Global level must be between $minimumLevel and $totalLevels.',
      );
    }
  }

  static void _validateWorld(int world) {
    if (!isValidWorld(world)) {
      throw ArgumentError.value(
        world,
        'world',
        'World must be between $minimumWorld and $totalWorlds.',
      );
    }
  }

  static void _validateLocalLevel(int world, int localLevel) {
    if (!isValidLocalLevel(world, localLevel)) {
      throw ArgumentError.value(
        localLevel,
        'localLevel',
        'Local level must be between $minimumLocalLevel and '
            '${_levelCountOf(world)} for world $world.',
      );
    }
  }
}