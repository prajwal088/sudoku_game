import 'dart:developer' as developer;

import '../config/game_config.dart';
import '../models/level.dart';
import '../services/game_service.dart';
import '../services/progress_service.dart';
import '../services/puzzle_repository.dart';

/// ============================================================================
/// LevelService
/// ----------------------------------------------------------------------------
/// Central service for campaign-level data.
///
/// Responsibilities:
/// - Expose world/level calculations (delegated to [GameConfig]).
/// - Load a single campaign level.
/// - Load all levels belonging to a world.
/// - Retrieve puzzle/solution data from [PuzzleRepository].
/// - Generate a safe fallback puzzle when repository data is unavailable.
/// - Apply persisted progress information to level metadata.
/// - Provide difficulty and target time per level.
/// - Delegate level completion persistence to [ProgressService].
///
/// Architecture:
/// - Global level number is the canonical level identifier.
/// - World/local level numbers are derived from the global level.
/// - [GameConfig] owns static game configuration AND the world/level math.
///   This service never re-implements it.
/// - [ProgressService] owns player progression and persistence.
/// - [PuzzleRepository] owns predefined puzzle content.
/// - [GameService] owns generated puzzle creation.
///
/// LevelService does NOT:
/// - Persist player progress directly.
/// - Store completed levels, stars or best times.
/// - Own puzzle content.
///
/// IMPORTANT:
/// [ProgressService.init] must be called during application startup before
/// using methods that require persisted progress.
/// ============================================================================

class LevelService {
  // ==========================================================================
  // DEPENDENCIES
  // ==========================================================================

  final ProgressService _progressService;
  final PuzzleRepository _puzzleRepository;
  final GameService _gameService;

  LevelService({
    ProgressService? progressService,
    PuzzleRepository? puzzleRepository,
    GameService? gameService,
  }) : _progressService = progressService ?? ProgressService(),
       _puzzleRepository = puzzleRepository ?? PuzzleRepository(),
       _gameService = gameService ?? GameService();

  // ==========================================================================
  // CONFIGURATION (mirrors GameConfig; kept for existing callers)
  // ==========================================================================

  /// Number of worlds available in the campaign.
  static const int totalWorlds = GameConfig.totalWorlds;

  /// Number of levels contained in each world.
  static const int levelsPerWorld = GameConfig.levelsPerWorld;

  /// Total number of campaign levels.
  static const int totalLevels = GameConfig.totalLevels;

  /// First valid global level.
  static const int minimumLevel = GameConfig.minimumLevel;

  /// First valid world.
  static const int minimumWorld = GameConfig.minimumWorld;

  // ==========================================================================
  // DIFFICULTY TIERS
  // ==========================================================================

  /// One table drives the difficulty label, the fallback puzzle's empty-cell
  /// count and the target time, so they can never drift apart.
  ///
  /// Tiers are expressed per world:
  /// - World 1       -> Easy   (global levels 1-25)
  /// - Worlds 2-3    -> Medium (26-75)
  /// - Worlds 4-6    -> Hard   (76-150)
  /// - Worlds 7-10   -> Expert (151-250)
  static const List<_DifficultyTier> _difficultyTiers = <_DifficultyTier>[
    _DifficultyTier(
      lastWorld: 1,
      label: 'Easy',
      emptyCells: 35,
      targetTimeSeconds: 300,
    ),
    _DifficultyTier(
      lastWorld: 3,
      label: 'Medium',
      emptyCells: 45,
      targetTimeSeconds: 450,
    ),
    _DifficultyTier(
      lastWorld: 6,
      label: 'Hard',
      emptyCells: 50,
      targetTimeSeconds: 600,
    ),
    _DifficultyTier(
      lastWorld: GameConfig.totalWorlds,
      label: 'Expert',
      emptyCells: 55,
      targetTimeSeconds: 900,
    ),
  ];

  static _DifficultyTier _tierForWorld(int world) {
    for (final _DifficultyTier tier in _difficultyTiers) {
      if (world <= tier.lastWorld) {
        return tier;
      }
    }

    return _difficultyTiers.last;
  }

  /// True in debug/profile builds (asserts enabled), false in release.
  static final bool _assertsEnabled = () {
    bool enabled = false;
    assert(() {
      enabled = true;
      return true;
    }());
    return enabled;
  }();

  // ==========================================================================
  // GLOBAL LEVEL <-> WORLD / LOCAL LEVEL
  // ==========================================================================

  /// Converts a global level number to its world number.
  ///
  /// Examples with 25 levels per world:
  ///
  /// ```text
  /// Global 1   -> World 1
  /// Global 25  -> World 1
  /// Global 26  -> World 2
  /// Global 250 -> World 10
  /// ```
  int getWorldFromGlobalLevel(int globalLevel) {
    return GameConfig.getWorldFromGlobalLevel(globalLevel);
  }

  /// Converts a global level number to its local level number within its world.
  ///
  /// ```text
  /// Global 1   -> Local 1
  /// Global 26  -> Local 1
  /// Global 55  -> Local 5
  /// Global 250 -> Local 25
  /// ```
  int getLocalLevelFromGlobalLevel(int globalLevel) {
    return GameConfig.getLocalLevelFromGlobalLevel(globalLevel);
  }

  /// Converts a world number and local level number into a global level.
  ///
  /// ```text
  /// World 1, Level 1   -> Global 1
  /// World 2, Level 1   -> Global 26
  /// World 3, Level 5   -> Global 55
  /// World 10, Level 25 -> Global 250
  /// ```
  int getGlobalLevel(int world, int localLevel) {
    return GameConfig.getGlobalLevel(world, localLevel);
  }

  /// Returns both world and local level information for a global level.
  ///
  /// ```dart
  /// final result = levelService.getWorldAndLocalLevel(55);
  /// result.world       // 3
  /// result.localLevel  // 5
  /// ```
  ({int world, int localLevel}) getWorldAndLocalLevel(int globalLevel) {
    return (
      world: GameConfig.getWorldFromGlobalLevel(globalLevel),
      localLevel: GameConfig.getLocalLevelFromGlobalLevel(globalLevel),
    );
  }

  // ==========================================================================
  // WORLD LEVEL RANGES
  // ==========================================================================

  /// Returns the first global level belonging to [world].
  int getWorldFirstLevel(int world) {
    return GameConfig.getFirstLevelForWorld(world);
  }

  /// Returns the last global level belonging to [world].
  int getWorldLastLevel(int world) {
    return GameConfig.getLastLevelForWorld(world);
  }

  /// Returns all global levels belonging to [world].
  ///
  /// This method returns the range only; it does not load puzzle data.
  List<int> getGlobalLevelsForWorld(int world) {
    final int firstLevel = GameConfig.getFirstLevelForWorld(world);

    return List<int>.generate(
      GameConfig.levelsPerWorld,
      (int index) => firstLevel + index,
    );
  }

  /// Returns true when [globalLevel] is the final level of its world.
  bool completesWorld(int globalLevel) {
    return GameConfig.completesWorld(globalLevel);
  }

  /// Returns true when [localLevel] is the final level within its world.
  bool isLastLevelInWorld(int localLevel) {
    if (!GameConfig.isValidLocalLevel(localLevel)) {
      throw ArgumentError.value(
        localLevel,
        'localLevel',
        'Local level must be between '
            '${GameConfig.minimumLocalLevel} and ${GameConfig.levelsPerWorld}.',
      );
    }

    return localLevel == GameConfig.levelsPerWorld;
  }

  // ==========================================================================
  // WORLD VALIDATION / NAVIGATION
  // ==========================================================================

  /// Returns true when [world] is a valid configured world.
  bool isValidWorld(int world) => GameConfig.isValidWorld(world);

  /// Returns true when [globalLevel] is a valid configured level.
  bool isValidGlobalLevel(int globalLevel) {
    return GameConfig.isValidGlobalLevel(globalLevel);
  }

  /// Returns the next global level after [globalLevel].
  ///
  /// Returns null when the supplied level is the final campaign level.
  int? getNextGlobalLevel(int globalLevel) {
    return GameConfig.getNextGlobalLevel(globalLevel);
  }

  /// Returns the previous global level before [globalLevel].
  ///
  /// Returns null when the supplied level is the first campaign level.
  int? getPreviousGlobalLevel(int globalLevel) {
    return GameConfig.getPreviousGlobalLevel(globalLevel);
  }

  // ==========================================================================
  // LOAD SINGLE LEVEL
  // ==========================================================================

  /// Loads a campaign level using its global level number.
  ///
  /// The returned [Level] contains puzzle, solution, world, difficulty,
  /// target time, lock/completion state, earned stars and best time.
  ///
  /// A repository puzzle is always preferred. If the requested puzzle does
  /// not exist (or is invalid in a release build), a generated puzzle is used
  /// as a defensive fallback.
  Future<Level> getLevel(int globalLevel) async {
    // Validates the level (throws ArgumentError when out of range).
    final int world = GameConfig.getWorldFromGlobalLevel(globalLevel);

    final _ProgressSnapshot progress = await _loadProgressSnapshot();

    return _buildLevel(globalLevel, world, progress);
  }

  // ==========================================================================
  // LOAD WORLD LEVELS
  // ==========================================================================

  /// Returns every level belonging to [world], in ascending global order.
  ///
  /// Progress is loaded once and applied to every level.
  Future<List<Level>> getLevelsByWorld(int world) async {
    // Validates the world (throws ArgumentError when out of range).
    final int startGlobalLevel = GameConfig.getFirstLevelForWorld(world);
    final int endGlobalLevel = GameConfig.getLastLevelForWorld(world);

    final _ProgressSnapshot progress = await _loadProgressSnapshot();

    final List<Level> levels = <Level>[];

    for (
      int globalLevel = startGlobalLevel;
      globalLevel <= endGlobalLevel;
      globalLevel++
    ) {
      levels.add(_buildLevel(globalLevel, world, progress));
    }

    return levels;
  }

  // ==========================================================================
  // COMPLETE LEVEL
  // ==========================================================================

  /// Marks a campaign level as completed.
  ///
  /// Progress persistence remains owned by [ProgressService].
  Future<void> completeLevel(int globalLevel, int time, int stars) async {
    if (!GameConfig.isValidGlobalLevel(globalLevel)) {
      throw ArgumentError.value(
        globalLevel,
        'globalLevel',
        'Global level must be between '
            '${GameConfig.minimumLevel} and ${GameConfig.totalLevels}.',
      );
    }

    if (time <= 0) {
      throw ArgumentError.value(
        time,
        'time',
        'Completion time must be greater than 0 seconds.',
      );
    }

    if (!GameConfig.isValidStars(stars)) {
      throw ArgumentError.value(
        stars,
        'stars',
        'Stars must be between '
            '${GameConfig.minStarsPerLevel} and '
            '${GameConfig.maxStarsPerLevel}.',
      );
    }

    await _progressService.completeLevel(
      globalLevel: globalLevel,
      timeInSeconds: time,
      stars: stars,
    );
  }

  // ==========================================================================
  // LEVEL CONSTRUCTION
  // ==========================================================================

  Future<_ProgressSnapshot> _loadProgressSnapshot() async {
    final Map<String, dynamic> progress = await _progressService
        .loadProgress();

    return _ProgressSnapshot.fromProgress(progress);
  }

  /// Builds a [Level] from puzzle data plus the progress snapshot.
  ///
  /// Shared by [getLevel] and [getLevelsByWorld] so both always produce
  /// identical metadata.
  Level _buildLevel(int globalLevel, int world, _ProgressSnapshot progress) {
    final _DifficultyTier tier = _tierForWorld(world);
    final _PuzzleData puzzle = _loadPuzzle(globalLevel, tier);

    return Level(
      levelNumber: globalLevel,
      world: world,
      difficulty: tier.label,
      puzzle: puzzle.puzzle,
      solution: puzzle.solution,
      isLocked: globalLevel > progress.currentLevel,
      isCompleted: progress.completedLevels.contains(globalLevel),
      stars: progress.stars[globalLevel] ?? 0,
      bestTime: progress.bestTimes[globalLevel] ?? 0,
      targetTime: tier.targetTimeSeconds,
    );
  }

  // ==========================================================================
  // PUZZLE LOADING
  // ==========================================================================

  /// Loads a predefined puzzle or generates a fallback puzzle.
  ///
  /// Invalid repository content is a content bug:
  /// - In debug/profile builds the error is rethrown so it is caught early.
  /// - In release builds it is logged and a generated puzzle is used, so one
  ///   bad entry cannot make an entire world impossible to open.
  _PuzzleData _loadPuzzle(int globalLevel, _DifficultyTier tier) {
    final Map<String, dynamic>? repositoryData = _puzzleRepository
        .getPuzzleForLevel(globalLevel);

    if (repositoryData != null) {
      try {
        return _parseRepositoryPuzzle(repositoryData, globalLevel);
      } on StateError catch (error, stackTrace) {
        if (_assertsEnabled) {
          rethrow;
        }

        developer.log(
          'Invalid repository puzzle for level $globalLevel; '
          'using generated fallback.',
          name: 'LevelService',
          level: 1000,
          error: error,
          stackTrace: stackTrace,
        );
      }
    }

    // ------------------------------------------------------------------------
    // FALLBACK
    // ------------------------------------------------------------------------
    //
    // The repository should normally contain every campaign puzzle.
    // Generation exists so a missing/invalid content entry does not make the
    // game unusable.
    // ------------------------------------------------------------------------

    final generatedBoard = _gameService.newGame(emptyCells: tier.emptyCells);

    return _PuzzleData(
      puzzle: _cloneGrid(generatedBoard.puzzle),
      solution: _cloneGrid(generatedBoard.solution),
    );
  }

  /// Parses and validates repository puzzle data.
  _PuzzleData _parseRepositoryPuzzle(
    Map<String, dynamic> data,
    int globalLevel,
  ) {
    final Object? rawPuzzle = data['puzzle'];
    final Object? rawSolution = data['solution'];

    if (rawPuzzle is! List || rawSolution is! List) {
      throw StateError(
        'Invalid puzzle data for level $globalLevel: '
        'puzzle and solution must be lists.',
      );
    }

    final List<List<int>> puzzle = _parseGrid(
      rawPuzzle,
      name: 'puzzle',
      globalLevel: globalLevel,
    );

    final List<List<int>> solution = _parseGrid(
      rawSolution,
      name: 'solution',
      globalLevel: globalLevel,
    );

    _validateSolution(solution, globalLevel);
    _validatePuzzleAgainstSolution(puzzle, solution, globalLevel);

    return _PuzzleData(puzzle: puzzle, solution: solution);
  }

  // ==========================================================================
  // PUZZLE VALIDATION
  // ==========================================================================

  /// Parses a 9x9 Sudoku grid into a fresh (caller-owned) list.
  List<List<int>> _parseGrid(
    List<dynamic> rawGrid, {
    required String name,
    required int globalLevel,
  }) {
    if (rawGrid.length != 9) {
      throw StateError(
        'Invalid $name for level $globalLevel: expected 9 rows.',
      );
    }

    final List<List<int>> grid = <List<int>>[];

    for (int row = 0; row < 9; row++) {
      final dynamic rawRow = rawGrid[row];

      if (rawRow is! List || rawRow.length != 9) {
        throw StateError(
          'Invalid $name for level $globalLevel: '
          'row $row must contain 9 cells.',
        );
      }

      final List<int> parsedRow = <int>[];

      for (int col = 0; col < 9; col++) {
        final dynamic value = rawRow[col];

        if (value is! int || value < 0 || value > 9) {
          throw StateError(
            'Invalid $name for level $globalLevel at '
            'row $row, column $col: expected an integer from 0 to 9.',
          );
        }

        parsedRow.add(value);
      }

      grid.add(parsedRow);
    }

    return grid;
  }

  /// Ensures the solution is a complete, valid Sudoku grid.
  ///
  /// Every cell must be 1-9 and every row, column and 3x3 box must contain
  /// each digit exactly once. Bitmasks keep this O(81) with no allocations
  /// beyond three small lists.
  void _validateSolution(List<List<int>> solution, int globalLevel) {
    final List<int> rows = List<int>.filled(9, 0);
    final List<int> cols = List<int>.filled(9, 0);
    final List<int> boxes = List<int>.filled(9, 0);

    for (int row = 0; row < 9; row++) {
      for (int col = 0; col < 9; col++) {
        final int value = solution[row][col];

        if (value < 1 || value > 9) {
          throw StateError(
            'Invalid solution for level $globalLevel at '
            'row $row, column $col: cell must be 1-9.',
          );
        }

        final int bit = 1 << value;
        final int box = ((row ~/ 3) * 3) + (col ~/ 3);

        if ((rows[row] & bit) != 0 ||
            (cols[col] & bit) != 0 ||
            (boxes[box] & bit) != 0) {
          throw StateError(
            'Invalid solution for level $globalLevel: '
            'digit $value repeats at row $row, column $col.',
          );
        }

        rows[row] |= bit;
        cols[col] |= bit;
        boxes[box] |= bit;
      }
    }
  }

  /// Ensures puzzle clues agree with the supplied solution.
  void _validatePuzzleAgainstSolution(
    List<List<int>> puzzle,
    List<List<int>> solution,
    int globalLevel,
  ) {
    for (int row = 0; row < 9; row++) {
      for (int col = 0; col < 9; col++) {
        final int puzzleValue = puzzle[row][col];

        if (puzzleValue != 0 && puzzleValue != solution[row][col]) {
          throw StateError(
            'Invalid puzzle data for level $globalLevel: '
            'puzzle clue at row $row, column $col does not match solution.',
          );
        }
      }
    }
  }

  // ==========================================================================
  // GRID COPYING
  // ==========================================================================

  /// Creates a defensive copy of a Sudoku grid.
  List<List<int>> _cloneGrid(List<List<int>> source) {
    return source.map(List<int>.from).toList();
  }
}

// ============================================================================
// INTERNAL TYPES
// ============================================================================

/// Difficulty settings shared by label, fallback generation and target time.
class _DifficultyTier {
  /// Highest world (inclusive) that uses this tier.
  final int lastWorld;

  final String label;

  /// Empty cells used when generating a fallback puzzle.
  final int emptyCells;

  final int targetTimeSeconds;

  const _DifficultyTier({
    required this.lastWorld,
    required this.label,
    required this.emptyCells,
    required this.targetTimeSeconds,
  });
}

/// Internal immutable container for puzzle and solution grids.
class _PuzzleData {
  final List<List<int>> puzzle;
  final List<List<int>> solution;

  const _PuzzleData({required this.puzzle, required this.solution});
}

/// Typed, pre-parsed view of persisted progress.
///
/// Parsed once per request so per-level lookups are O(1) with no string
/// allocation (keys are ints, not `levelNumber.toString()`).
class _ProgressSnapshot {
  final int currentLevel;
  final Set<int> completedLevels;
  final Map<int, int> stars;
  final Map<int, int> bestTimes;

  const _ProgressSnapshot({
    required this.currentLevel,
    required this.completedLevels,
    required this.stars,
    required this.bestTimes,
  });

  factory _ProgressSnapshot.fromProgress(Map<String, dynamic> progress) {
    return _ProgressSnapshot(
      currentLevel: _readCurrentLevel(progress['currentLevel']),
      completedLevels: _readCompletedLevels(progress['completedLevels']),
      stars: _readIntegerMap(progress['stars']),
      bestTimes: _readIntegerMap(progress['bestTimes']),
    );
  }

  /// Reads the next globally unlocked level.
  static int _readCurrentLevel(Object? raw) {
    if (raw is int && GameConfig.isValidGlobalLevel(raw)) {
      return raw;
    }

    return GameConfig.minimumLevel;
  }

  /// Reads completed global levels.
  static Set<int> _readCompletedLevels(Object? raw) {
    if (raw is! List) {
      return <int>{};
    }

    return raw
        .whereType<int>()
        .where(GameConfig.isValidGlobalLevel)
        .toSet();
  }

  /// Safely converts a persisted map into a level -> int map.
  static Map<int, int> _readIntegerMap(Object? raw) {
    if (raw is! Map) {
      return <int, int>{};
    }

    final Map<int, int> result = <int, int>{};

    raw.forEach((Object? key, Object? entry) {
      final int? level = int.tryParse(key.toString());

      if (level != null && entry is int) {
        result[level] = entry;
      }
    });

    return result;
  }
}