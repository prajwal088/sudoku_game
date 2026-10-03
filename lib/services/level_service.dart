import '../config/game_config.dart';
import '../models/level.dart';
import '../services/game_service.dart';
import '../services/progress_service.dart';
import '../services/puzzle_repository.dart';

/// ============================================================================
/// LevelService
/// ----------------------------------------------------------------------------
/// Central service for campaign-level data and world/level calculations.
///
/// Responsibilities:
/// - Convert between global levels and world/local levels.
/// - Calculate world level ranges.
/// - Determine world completion boundaries.
/// - Load a single campaign level.
/// - Load all levels belonging to a world.
/// - Retrieve puzzle/solution data from [PuzzleRepository].
/// - Generate a safe fallback puzzle when repository data is unavailable.
/// - Apply persisted progress information to level metadata.
/// - Calculate difficulty and target time.
/// - Delegate level completion persistence to [ProgressService].
///
/// Architecture:
/// - Global level number is the canonical level identifier.
/// - World/local level numbers are derived from the global level.
/// - [GameConfig] owns static game configuration.
/// - [ProgressService] owns player progression and persistence.
/// - [PuzzleRepository] owns predefined puzzle content.
/// - [GameService] owns generated puzzle creation.
///
/// LevelService does NOT:
/// - Persist player progress directly.
/// - Store completed levels.
/// - Store stars.
/// - Store best times.
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
  // CONFIGURATION
  // ==========================================================================

  /// Number of worlds available in the campaign.
  static const int totalWorlds = GameConfig.totalWorlds;

  /// Number of levels contained in each world.
  static const int levelsPerWorld = GameConfig.levelsPerWorld;

  /// Total number of campaign levels.
  static const int totalLevels = GameConfig.totalLevels;

  /// First valid global level.
  static const int minimumLevel = 1;

  /// First valid world.
  static const int minimumWorld = 1;

  // ==========================================================================
  // GLOBAL LEVEL <-> WORLD / LOCAL LEVEL
  // ==========================================================================

  /// Converts a global level number to its world number.
  ///
  /// Global levels are the canonical identifiers used throughout the game.
  ///
  /// Examples with 25 levels per world:
  ///
  /// ```text
  /// Global 1   -> World 1
  /// Global 25  -> World 1
  /// Global 26  -> World 2
  /// Global 50  -> World 2
  /// Global 51  -> World 3
  /// Global 250 -> World 10
  /// ```
  int getWorldFromGlobalLevel(int globalLevel) {
    _validateGlobalLevel(globalLevel);

    return ((globalLevel - 1) ~/ levelsPerWorld) + 1;
  }

  /// Converts a global level number to its local level number within its world.
  ///
  /// Examples:
  ///
  /// ```text
  /// Global 1   -> Local 1
  /// Global 25  -> Local 25
  /// Global 26  -> Local 1
  /// Global 30  -> Local 5
  /// Global 55  -> Local 5
  /// Global 250 -> Local 25
  /// ```
  int getLocalLevelFromGlobalLevel(int globalLevel) {
    _validateGlobalLevel(globalLevel);

    return ((globalLevel - 1) % levelsPerWorld) + 1;
  }

  /// Converts a world number and local level number into a global level.
  ///
  /// Examples:
  ///
  /// ```text
  /// World 1, Level 1  -> Global 1
  /// World 1, Level 25 -> Global 25
  /// World 2, Level 1  -> Global 26
  /// World 2, Level 5  -> Global 30
  /// World 3, Level 5  -> Global 55
  /// World 10, Level 25 -> Global 250
  /// ```
  int getGlobalLevel(int world, int localLevel) {
    _validateWorld(world);
    _validateLocalLevel(localLevel);

    final globalLevel = ((world - 1) * levelsPerWorld) + localLevel;

    _validateGlobalLevel(globalLevel);

    return globalLevel;
  }

  /// Returns both world and local level information for a global level.
  ///
  /// Example:
  ///
  /// ```dart
  /// final result = levelService.getWorldAndLocalLevel(55);
  ///
  /// result.world       // 3
  /// result.localLevel  // 5
  /// ```
  ({int world, int localLevel}) getWorldAndLocalLevel(int globalLevel) {
    _validateGlobalLevel(globalLevel);

    return (
      world: getWorldFromGlobalLevel(globalLevel),
      localLevel: getLocalLevelFromGlobalLevel(globalLevel),
    );
  }

  // ==========================================================================
  // WORLD LEVEL RANGES
  // ==========================================================================

  /// Returns the first global level belonging to [world].
  ///
  /// Examples:
  ///
  /// ```text
  /// World 1 -> Global 1
  /// World 2 -> Global 26
  /// World 3 -> Global 51
  /// World 10 -> Global 226
  /// ```
  int getWorldFirstLevel(int world) {
    _validateWorld(world);

    return ((world - 1) * levelsPerWorld) + 1;
  }

  /// Returns the last global level belonging to [world].
  ///
  /// Examples:
  ///
  /// ```text
  /// World 1 -> Global 25
  /// World 2 -> Global 50
  /// World 3 -> Global 75
  /// World 10 -> Global 250
  /// ```
  int getWorldLastLevel(int world) {
    _validateWorld(world);

    return world * levelsPerWorld;
  }

  /// Returns all global levels belonging to [world].
  ///
  /// This method returns the range only; it does not load puzzle data.
  List<int> getGlobalLevelsForWorld(int world) {
    final firstLevel = getWorldFirstLevel(world);
    final lastLevel = getWorldLastLevel(world);

    return List<int>.generate(
      lastLevel - firstLevel + 1,
      (index) => firstLevel + index,
    );
  }

  /// Returns true when [globalLevel] is the final level of its world.
  ///
  /// Examples:
  ///
  /// ```text
  /// Level 25 -> true
  /// Level 50 -> true
  /// Level 75 -> true
  /// Level 26 -> false
  /// ```
  bool completesWorld(int globalLevel) {
    _validateGlobalLevel(globalLevel);

    return globalLevel % levelsPerWorld == 0;
  }

  /// Returns true when [localLevel] is the final level within its world.
  bool isLastLevelInWorld(int localLevel) {
    _validateLocalLevel(localLevel);

    return localLevel == levelsPerWorld;
  }

  // ==========================================================================
  // WORLD VALIDATION / NAVIGATION
  // ==========================================================================

  /// Returns true when [world] is a valid configured world.
  bool isValidWorld(int world) {
    return world >= minimumWorld && world <= totalWorlds;
  }

  /// Returns true when [globalLevel] is a valid configured level.
  bool isValidGlobalLevel(int globalLevel) {
    return globalLevel >= minimumLevel && globalLevel <= totalLevels;
  }

  /// Returns the next global level after [globalLevel].
  ///
  /// Returns null when the supplied level is the final campaign level.
  int? getNextGlobalLevel(int globalLevel) {
    _validateGlobalLevel(globalLevel);

    if (globalLevel >= totalLevels) {
      return null;
    }

    return globalLevel + 1;
  }

  /// Returns the previous global level before [globalLevel].
  ///
  /// Returns null when the supplied level is the first campaign level.
  int? getPreviousGlobalLevel(int globalLevel) {
    _validateGlobalLevel(globalLevel);

    if (globalLevel <= minimumLevel) {
      return null;
    }

    return globalLevel - 1;
  }

  // ==========================================================================
  // LOAD SINGLE LEVEL
  // ==========================================================================

  /// Loads a campaign level using its global level number.
  ///
  /// The returned [Level] contains:
  /// - puzzle
  /// - solution
  /// - world
  /// - difficulty
  /// - target time
  /// - completion state
  /// - earned stars
  /// - best time
  ///
  /// A repository puzzle is always preferred. If the requested puzzle does
  /// not exist, a generated puzzle is used as a defensive fallback.
  Future<Level> getLevel(int globalLevel) async {
    _validateGlobalLevel(globalLevel);

    final progress = await _progressService.loadProgress();

    final currentUnlockedLevel = _readCurrentLevel(progress);
    final completedLevels = _readCompletedLevels(progress);
    final starsMap = _readIntegerMap(progress['stars']);
    final bestTimesMap = _readIntegerMap(progress['bestTimes']);

    final puzzle = _loadPuzzle(globalLevel);

    final world = getWorldFromGlobalLevel(globalLevel);

    return Level(
      levelNumber: globalLevel,
      world: world,
      difficulty: _getDifficultyLabel(globalLevel),
      puzzle: puzzle.puzzle,
      solution: puzzle.solution,
      isLocked: globalLevel > currentUnlockedLevel,
      isCompleted: completedLevels.contains(globalLevel),
      stars: starsMap[globalLevel.toString()] ?? 0,
      bestTime: bestTimesMap[globalLevel.toString()] ?? 0,
      targetTime: _getTargetTime(globalLevel),
    );
  }

  // ==========================================================================
  // LOAD WORLD LEVELS
  // ==========================================================================

  /// Returns every level belonging to [world].
  ///
  /// Levels are returned in ascending global-level order.
  ///
  /// Progress is loaded once and applied to every level, avoiding repeated
  /// SharedPreferences reads.
  Future<List<Level>> getLevelsByWorld(int world) async {
    _validateWorld(world);

    final progress = await _progressService.loadProgress();

    final currentUnlockedLevel = _readCurrentLevel(progress);
    final completedLevels = _readCompletedLevels(progress);
    final starsMap = _readIntegerMap(progress['stars']);
    final bestTimesMap = _readIntegerMap(progress['bestTimes']);

    final startGlobalLevel = getWorldFirstLevel(world);
    final endGlobalLevel = getWorldLastLevel(world);

    final levels = <Level>[];

    for (
      int globalLevel = startGlobalLevel;
      globalLevel <= endGlobalLevel;
      globalLevel++
    ) {
      final puzzle = _loadPuzzle(globalLevel);

      levels.add(
        Level(
          levelNumber: globalLevel,
          world: world,
          difficulty: _getDifficultyLabel(globalLevel),
          puzzle: puzzle.puzzle,
          solution: puzzle.solution,
          isLocked: globalLevel > currentUnlockedLevel,
          isCompleted: completedLevels.contains(globalLevel),
          stars: starsMap[globalLevel.toString()] ?? 0,
          bestTime: bestTimesMap[globalLevel.toString()] ?? 0,
          targetTime: _getTargetTime(globalLevel),
        ),
      );
    }

    return levels;
  }

  // ==========================================================================
  // COMPLETE LEVEL
  // ==========================================================================

  /// Marks a campaign level as completed.
  ///
  /// Progress persistence remains owned by [ProgressService].
  Future<void> completeLevel(
    int globalLevel,
    int time,
    int stars,
  ) async {
    _validateGlobalLevel(globalLevel);

    if (time <= 0) {
      throw ArgumentError.value(
        time,
        'time',
        'Completion time must be greater than 0 seconds.',
      );
    }

    if (stars < GameConfig.minStarsPerLevel ||
        stars > GameConfig.maxStarsPerLevel) {
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
  // PUZZLE LOADING
  // ==========================================================================

  /// Loads a predefined puzzle or generates a fallback puzzle.
  _PuzzleData _loadPuzzle(int globalLevel) {
    final repositoryData = _puzzleRepository.getPuzzleForLevel(globalLevel);

    if (repositoryData != null) {
      return _parseRepositoryPuzzle(repositoryData, globalLevel);
    }

    // ------------------------------------------------------------------------
    // FALLBACK
    // ------------------------------------------------------------------------
    //
    // The repository should normally contain every campaign puzzle.
    //
    // Generation exists as a defensive fallback so a missing content entry
    // does not make the game completely unusable.
    // ------------------------------------------------------------------------

    final generatedBoard = _gameService.newGame(
      emptyCells: _getDifficultyCellCount(globalLevel),
    );

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
    final rawPuzzle = data['puzzle'];
    final rawSolution = data['solution'];

    if (rawPuzzle is! List || rawSolution is! List) {
      throw StateError(
        'Invalid puzzle data for level $globalLevel: '
        'puzzle and solution must be lists.',
      );
    }

    final puzzle = _parseGrid(
      rawPuzzle,
      name: 'puzzle',
      globalLevel: globalLevel,
    );

    final solution = _parseGrid(
      rawSolution,
      name: 'solution',
      globalLevel: globalLevel,
    );

    _validatePuzzleAgainstSolution(
      puzzle,
      solution,
      globalLevel,
    );

    return _PuzzleData(
      puzzle: puzzle,
      solution: solution,
    );
  }

  // ==========================================================================
  // DIFFICULTY
  // ==========================================================================

  /// Returns the number of empty cells used when generating fallback puzzles.
  int _getDifficultyCellCount(int globalLevel) {
    if (globalLevel <= 25) {
      return 35;
    }

    if (globalLevel <= 75) {
      return 45;
    }

    if (globalLevel <= 150) {
      return 50;
    }

    return 55;
  }

  /// Returns the display difficulty for a campaign level.
  String _getDifficultyLabel(int globalLevel) {
    if (globalLevel <= 25) {
      return 'Easy';
    }

    if (globalLevel <= 75) {
      return 'Medium';
    }

    if (globalLevel <= 150) {
      return 'Hard';
    }

    return 'Expert';
  }

  /// Returns the target completion time in seconds.
  int _getTargetTime(int globalLevel) {
    if (globalLevel <= 25) {
      return 300;
    }

    if (globalLevel <= 75) {
      return 450;
    }

    if (globalLevel <= 150) {
      return 600;
    }

    return 900;
  }

  // ==========================================================================
  // PROGRESS PARSING
  // ==========================================================================

  /// Reads the next globally unlocked level from persisted progress.
  int _readCurrentLevel(Map<String, dynamic> progress) {
    final value = progress['currentLevel'];

    if (value is int && isValidGlobalLevel(value)) {
      return value;
    }

    return minimumLevel;
  }

  /// Reads completed global levels from persisted progress.
  Set<int> _readCompletedLevels(Map<String, dynamic> progress) {
    final raw = progress['completedLevels'];

    if (raw is! List) {
      return <int>{};
    }

    return raw
        .whereType<int>()
        .where(isValidGlobalLevel)
        .toSet();
  }

  /// Safely converts a persisted map into a String -> int map.
  Map<String, int> _readIntegerMap(dynamic value) {
    if (value is! Map) {
      return <String, int>{};
    }

    final result = <String, int>{};

    value.forEach((key, value) {
      if (value is int) {
        result[key.toString()] = value;
      }
    });

    return result;
  }

  // ==========================================================================
  // PUZZLE VALIDATION
  // ==========================================================================

  /// Parses a 9x9 Sudoku grid.
  List<List<int>> _parseGrid(
    List<dynamic> rawGrid, {
    required String name,
    required int globalLevel,
  }) {
    if (rawGrid.length != 9) {
      throw StateError(
        'Invalid $name for level $globalLevel: '
        'expected 9 rows.',
      );
    }

    final grid = <List<int>>[];

    for (int row = 0; row < 9; row++) {
      final rawRow = rawGrid[row];

      if (rawRow is! List || rawRow.length != 9) {
        throw StateError(
          'Invalid $name for level $globalLevel: '
          'row $row must contain 9 cells.',
        );
      }

      final parsedRow = <int>[];

      for (int col = 0; col < 9; col++) {
        final value = rawRow[col];

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

  /// Ensures puzzle clues agree with the supplied solution.
  void _validatePuzzleAgainstSolution(
    List<List<int>> puzzle,
    List<List<int>> solution,
    int globalLevel,
  ) {
    for (int row = 0; row < 9; row++) {
      for (int col = 0; col < 9; col++) {
        final puzzleValue = puzzle[row][col];
        final solutionValue = solution[row][col];

        if (puzzleValue != 0 && puzzleValue != solutionValue) {
          throw StateError(
            'Invalid puzzle data for level $globalLevel: '
            'puzzle clue at row $row, column $col does not match solution.',
          );
        }
      }
    }
  }

  // ==========================================================================
  // VALIDATION
  // ==========================================================================

  /// Validates a global campaign level.
  void _validateGlobalLevel(int globalLevel) {
    if (!isValidGlobalLevel(globalLevel)) {
      throw ArgumentError.value(
        globalLevel,
        'globalLevel',
        'Global level must be between '
            '$minimumLevel and $totalLevels.',
      );
    }
  }

  /// Validates a configured world number.
  void _validateWorld(int world) {
    if (!isValidWorld(world)) {
      throw ArgumentError.value(
        world,
        'world',
        'World must be between '
            '$minimumWorld and $totalWorlds.',
      );
    }
  }

  /// Validates a local level number.
  void _validateLocalLevel(int localLevel) {
    if (localLevel < minimumLevel ||
        localLevel > levelsPerWorld) {
      throw ArgumentError.value(
        localLevel,
        'localLevel',
        'Local level must be between '
            '$minimumLevel and $levelsPerWorld.',
      );
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
// INTERNAL PUZZLE DATA
// ============================================================================

/// Internal immutable container for puzzle and solution grids.
class _PuzzleData {
  final List<List<int>> puzzle;
  final List<List<int>> solution;

  const _PuzzleData({
    required this.puzzle,
    required this.solution,
  });
}