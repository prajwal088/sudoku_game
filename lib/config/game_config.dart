/// ============================================================================
/// GameConfig
/// ----------------------------------------------------------------------------
/// Central source of truth for static game configuration and gameplay rules.
///
/// This class contains immutable configuration that defines how the Sudoku
/// campaign is structured, how hard each level is, and how core gameplay
/// limits behave.
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
/// ---------------------------------------------------------------------------
/// HOW TO EDIT THE CAMPAIGN (everything is in the [GameConfig.worlds] table)
/// ---------------------------------------------------------------------------
/// Each world is a name plus an ordered list of level groups. A group is
/// `LevelGroup(count, difficulty)`. Read a world top to bottom:
///
///     WorldConfig('Meadow', [
///       LevelGroup(10, Difficulty.easy),    // levels 1-10
///       LevelGroup(8,  Difficulty.medium),  // levels 11-18
///       LevelGroup(2,  Difficulty.hard),    // levels 19-20
///     ]),
///
/// The number of levels in a world is the sum of its groups. What each
/// difficulty MEANS (label, empty cells, target time) is defined once in
/// [GameConfig.difficultyProfiles].
///
/// Print [GameConfig.layoutTable] to see the full layout, with the difficulty
/// of every group, before shipping a change.
///
/// Global level numbers run continuously across worlds, so the first level of
/// a world is always the last level of the previous world + 1.
///
/// Example: worlds with 20, 25 and 30 levels
///
///     World 1  -> Global 1  .. 20
///     World 2  -> Global 21 .. 45
///     World 3  -> Global 46 .. 75
///
/// IMPORTANT: ProgressService stores progress by GLOBAL level number.
///
/// After release:
/// - SAFE: moving difficulty between groups, re-tuning
///   [GameConfig.difficultyProfiles], renaming worlds. None of this is stored
///   in saved progress.
/// - UNSAFE: changing the TOTAL number of levels of an existing world (the sum
///   of its groups). That shifts every later level and breaks saved progress.
///   Only add new worlds at the end of the list (or add levels to the last
///   world).
///
/// Implementation note:
/// Public methods validate their arguments exactly once and then use private,
/// unchecked helpers for the arithmetic, so composite operations (for example
/// [splitGlobalLevel]) do not re-validate the same value repeatedly.
/// ============================================================================
library;

// ============================================================================
// DIFFICULTY TYPES
// ============================================================================

/// The difficulty names that can be used when laying out worlds.
///
/// What each one means in the game is defined in
/// [GameConfig.difficultyProfiles].
enum Difficulty { easy, medium, hard, expert }

/// What a [Difficulty] means in the game.
final class DifficultyProfile {
  /// Label shown to the player (e.g. 'Easy').
  final String label;

  /// Number of empty cells used when generating a fallback puzzle.
  final int emptyCells;

  /// Target completion time, in seconds.
  final int targetTimeSeconds;

  const DifficultyProfile({
    required this.label,
    required this.emptyCells,
    required this.targetTimeSeconds,
  });
}

// ============================================================================
// CAMPAIGN TYPES
// ============================================================================

/// A run of consecutive levels inside a world that share one difficulty.
final class LevelGroup {
  /// Number of levels in this group. Must be greater than 0.
  final int levels;

  /// Difficulty applied to every level of this group.
  final Difficulty difficulty;

  const LevelGroup(this.levels, this.difficulty);
}

/// Definition of one campaign world.
final class WorldConfig {
  /// Display name of the world (e.g. for the world map screen).
  final String name;

  /// Level groups in play order. Unmodifiable.
  final List<LevelGroup> groups;

  /// Number of levels contained in this world (the sum of all [groups]).
  /// Must be greater than 0.
  final int levels;

  WorldConfig(this.name, List<LevelGroup> groups)
    : groups = List<LevelGroup>.unmodifiable(groups),
      levels = _sumLevels(groups);

  /// Shortcut for a world where every level has the same [difficulty].
  WorldConfig.uniform(String name, int levels, Difficulty difficulty)
    : this(name, <LevelGroup>[LevelGroup(levels, difficulty)]);

  static int _sumLevels(List<LevelGroup> groups) {
    int total = 0;

    for (final LevelGroup group in groups) {
      total += group.levels;
    }

    return total;
  }
}

abstract final class GameConfig {
  // ==========================================================================
  // PRIVATE CONSTRUCTOR
  // ==========================================================================

  const GameConfig._();

  // ==========================================================================
  // DIFFICULTY DEFINITIONS
  // ==========================================================================

  /// What each [Difficulty] means: player-facing label, fallback puzzle empty
  /// cells and target time.
  ///
  /// Every [Difficulty] value must have an entry (checked by
  /// [validateConfiguration]). Safe to re-tune after release: difficulty is
  /// not stored in saved progress.
  ///
  /// Note: [DifficultyProfile.emptyCells] only affects GENERATED fallback
  /// puzzles. The difficulty of predefined repository puzzles comes from the
  /// puzzle content itself, so author each puzzle to match the difficulty the
  /// layout below assigns to its level.
  static const Map<Difficulty, DifficultyProfile> difficultyProfiles =
      <Difficulty, DifficultyProfile>{
        Difficulty.easy: DifficultyProfile(
          label: 'Easy',
          emptyCells: 35,
          targetTimeSeconds: 300,
        ),
        Difficulty.medium: DifficultyProfile(
          label: 'Medium',
          emptyCells: 45,
          targetTimeSeconds: 450,
        ),
        Difficulty.hard: DifficultyProfile(
          label: 'Hard',
          emptyCells: 50,
          targetTimeSeconds: 600,
        ),
        Difficulty.expert: DifficultyProfile(
          label: 'Expert',
          emptyCells: 55,
          targetTimeSeconds: 900,
        ),
      };

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
  /// This table is the ONLY place to edit to change how many worlds exist,
  /// how many levels each world has, and which levels get which difficulty.
  /// Everything else is derived from it.
  ///
  /// Each world lists its level groups top to bottom:
  /// `LevelGroup(count, difficulty)`. For a world with a single difficulty
  /// use `WorldConfig.uniform(name, levels, difficulty)`.
  ///
  /// TODO(production): development layout below. Replace it with the real
  /// layout before release. It must stay in sync with the puzzle sets/assets
  /// you ship and with saved progress (see ProgressService).
  ///
  /// Example of a mixed layout (edit the numbers and difficulties freely
  /// before release; after release keep each world's TOTAL unchanged):
  ///
  /// ```dart
  /// WorldConfig('Meadow', <LevelGroup>[
  ///   LevelGroup(10, Difficulty.easy),    // levels 1-10
  ///   LevelGroup(8, Difficulty.medium),   // levels 11-18
  ///   LevelGroup(2, Difficulty.hard),     // levels 19-20
  /// ]),
  /// WorldConfig('Forest', <LevelGroup>[
  ///   LevelGroup(5, Difficulty.easy),
  ///   LevelGroup(15, Difficulty.medium),
  ///   LevelGroup(4, Difficulty.hard),
  ///   LevelGroup(1, Difficulty.expert),   // boss level
  /// ]),
  /// WorldConfig.uniform('Desert', 30, Difficulty.hard),
  /// // Many similar worlds on one line each via collection-for:
  /// for (int i = 4; i <= 12; i++)
  ///   WorldConfig.uniform('World $i', 30, Difficulty.expert),
  /// ```
  static final List<WorldConfig> worlds = List<WorldConfig>.unmodifiable(
    <WorldConfig>[
      WorldConfig.uniform('World 1', 3, Difficulty.easy), // world 1
      WorldConfig.uniform('World 2', 3, Difficulty.medium), // world 2
      WorldConfig.uniform('World 3', 3, Difficulty.medium), // world 3
      WorldConfig.uniform('World 4', 3, Difficulty.hard), // world 4
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

  /// Difficulty of every global level (index 0 = global level 1), derived
  /// from the level groups in [worlds].
  static final List<Difficulty> _levelDifficulties = _buildLevelDifficulties();

  static List<Difficulty> _buildLevelDifficulties() {
    final List<Difficulty> result = <Difficulty>[];

    for (final WorldConfig world in worlds) {
      for (final LevelGroup group in world.groups) {
        for (int i = 0; i < group.levels; i++) {
          result.add(group.difficulty);
        }
      }
    }

    return List<Difficulty>.unmodifiable(result);
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
  /// This is derived from the number of levels in the world and the
  /// [maxStarsPerLevel] constant. It is not stored in saved progress.
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
  /// against editing mistakes in [worlds], [difficultyProfiles] and the other
  /// constants.
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

      if (world.groups.isEmpty) {
        throw StateError(
          'GameConfig.worlds: world ${i + 1} (${world.name}) needs at least '
          'one LevelGroup.',
        );
      }

      for (final LevelGroup group in world.groups) {
        if (group.levels <= 0) {
          throw StateError(
            'GameConfig.worlds: world ${i + 1} (${world.name}) has a '
            'LevelGroup with ${group.levels} levels; every group must have '
            'more than 0 levels.',
          );
        }

        if (difficultyProfiles[group.difficulty] == null) {
          throw StateError(
            'GameConfig.worlds: world ${i + 1} (${world.name}) uses '
            '${group.difficulty}, which has no entry in difficultyProfiles.',
          );
        }
      }

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

    if (_levelDifficulties.length != totalLevels) {
      throw StateError('GameConfig internal difficulty table is inconsistent.');
    }

    for (final Difficulty difficulty in Difficulty.values) {
      final DifficultyProfile? profile = difficultyProfiles[difficulty];

      if (profile == null) {
        throw StateError(
          'GameConfig.difficultyProfiles is missing an entry for $difficulty.',
        );
      }

      if (profile.label.trim().isEmpty) {
        throw StateError(
          'GameConfig.difficultyProfiles: $difficulty needs a label.',
        );
      }

      if (profile.emptyCells < 1 || profile.emptyCells > 64) {
        throw StateError(
          'GameConfig.difficultyProfiles: ${profile.label} emptyCells must '
          'be between 1 and 64, but is ${profile.emptyCells}.',
        );
      }

      if (profile.targetTimeSeconds <= 0) {
        throw StateError(
          'GameConfig.difficultyProfiles: ${profile.label} '
          'targetTimeSeconds must be greater than 0.',
        );
      }
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
  /// Takes the world, because worlds can have different sizes.
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
  // DIFFICULTY LOOKUP
  // ==========================================================================

  /// Returns the [Difficulty] of [globalLevel].
  static Difficulty getDifficultyForLevel(int globalLevel) {
    _validateGlobalLevel(globalLevel);

    return _levelDifficulties[globalLevel - minimumLevel];
  }

  /// Returns the [DifficultyProfile] (label, empty cells, target time) of
  /// [globalLevel].
  static DifficultyProfile getProfileForLevel(int globalLevel) {
    _validateGlobalLevel(globalLevel);

    return _profileOf(globalLevel);
  }

  /// Returns the player-facing difficulty label of [globalLevel].
  static String getDifficultyLabelForLevel(int globalLevel) {
    _validateGlobalLevel(globalLevel);

    return _profileOf(globalLevel).label;
  }

  /// Returns the level groups of [world], in play order.
  static List<LevelGroup> getLevelGroupsForWorld(int world) {
    _validateWorld(world);

    return worlds[world - minimumWorld].groups;
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

  /// Returns a multi-line table of every world, its level groups and the
  /// difficulty of each group. Use it to check an edit to [worlds] at a glance:
  ///
  /// ```dart
  /// debugPrint(GameConfig.layoutTable);
  /// ```
  ///
  /// Example output:
  ///
  ///     World 1 (Meadow): 20 levels -> global 1-20
  ///         local  1-10 | global  1-10 | Easy   (35 empty, 300s)
  ///         local 11-18 | global 11-18 | Medium (45 empty, 450s)
  ///         local 19-20 | global 19-20 | Hard   (50 empty, 600s)
  ///     World 2 (Forest): 25 levels -> global 21-45
  ///         local  1-25 | global 21-45 | Medium (45 empty, 450s)
  ///     Total: 2 worlds, 45 levels
  static String get layoutTable {
    final StringBuffer buffer = StringBuffer();
    final int worldNumberWidth = totalWorlds.toString().length;
    final int levelNumberWidth = totalLevels.toString().length;
    final int labelWidth = _longestLabelLength;

    String pad(int value) => value.toString().padLeft(levelNumberWidth);

    for (int world = minimumWorld; world <= totalWorlds; world++) {
      final WorldConfig config = worlds[world - minimumWorld];

      buffer.writeln(
        'World ${world.toString().padLeft(worldNumberWidth)} '
        '(${config.name}): ${_levelCountOf(world)} levels -> '
        'global ${_firstLevelOf(world)}-${_lastLevelOf(world)}',
      );

      int local = minimumLocalLevel;
      int global = _firstLevelOf(world);

      for (final LevelGroup group in config.groups) {
        final DifficultyProfile? profile = difficultyProfiles[group.difficulty];
        final String label = (profile?.label ?? group.difficulty.name).padRight(
          labelWidth,
        );
        final String details = profile == null
            ? 'no profile'
            : '${profile.emptyCells} empty, ${profile.targetTimeSeconds}s';

        buffer.writeln(
          '    local ${pad(local)}-${pad(local + group.levels - 1)} | '
          'global ${pad(global)}-${pad(global + group.levels - 1)} | '
          '$label ($details)',
        );

        local += group.levels;
        global += group.levels;
      }
    }

    buffer.write('Total: $totalWorlds worlds, $totalLevels levels');

    return buffer.toString();
  }

  /// Returns a multi-line table of every difficulty and what it means.
  ///
  /// Example output:
  ///
  ///     Easy   : 35 empty cells, target 300s
  ///     Medium : 45 empty cells, target 450s
  static String get difficultyTable {
    final StringBuffer buffer = StringBuffer();
    final int labelWidth = _longestLabelLength;

    for (final Difficulty difficulty in Difficulty.values) {
      final DifficultyProfile? profile = difficultyProfiles[difficulty];

      if (profile == null) {
        buffer.writeln('${difficulty.name}: MISSING PROFILE');
        continue;
      }

      buffer.writeln(
        '${profile.label.padRight(labelWidth)} : '
        '${profile.emptyCells} empty cells, '
        'target ${profile.targetTimeSeconds}s',
      );
    }

    return buffer.toString().trimRight();
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

  static DifficultyProfile _profileOf(int globalLevel) {
    final DifficultyProfile? profile =
        difficultyProfiles[_levelDifficulties[globalLevel - minimumLevel]];

    if (profile == null) {
      throw StateError(
        'GameConfig.difficultyProfiles has no entry for '
        '${_levelDifficulties[globalLevel - minimumLevel]}.',
      );
    }

    return profile;
  }

  static int get _longestLabelLength {
    int longest = 0;

    for (final DifficultyProfile profile in difficultyProfiles.values) {
      if (profile.label.length > longest) {
        longest = profile.label.length;
      }
    }

    return longest;
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