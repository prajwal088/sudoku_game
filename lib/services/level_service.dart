import '../models/level.dart';
import 'game_service.dart';
import 'progress_service.dart';
import 'puzzle_repository.dart';

/// ============================================================================
/// LevelService
/// ----------------------------------------------------------------------------
/// Central service for campaign-level data.
///
/// Responsibilities:
/// - Load a single campaign level.
/// - Load all levels belonging to a world.
/// - Retrieve puzzle/solution data from [PuzzleRepository].
/// - Generate a safe fallback puzzle when repository data is unavailable.
/// - Apply persisted progress information to level metadata.
/// - Calculate difficulty and target time.
///
/// Architecture:
/// - Global level number is the canonical level identifier.
/// - World/local level numbers are derived through [ProgressService].
/// - [PuzzleRepository] owns predefined puzzle content.
/// - [GameService] owns generated puzzle creation.
/// - [ProgressService] owns progression and completion state.
///
/// LevelService does NOT persist progress directly.
///
/// IMPORTANT:
/// [ProgressService.init] must be called during application startup before
/// using this service.
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

  /// Number of levels per world.
  static const int levelsPerWorld = ProgressService.levelsPerWorld;

  /// First valid global level.
  static const int minimumLevel = 1;

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
  /// not exist, a generated puzzle is used as a fallback.
  ///
  /// Throws [ArgumentError] for an invalid global level.
  Future<Level> getLevel(int globalLevel) async {
    _validateGlobalLevel(globalLevel);

    final progress = await _progressService.loadProgress();

    final currentUnlockedLevel = _readCurrentLevel(progress);

    final completedLevels = _readCompletedLevels(progress);

    final starsMap = _readIntegerMap(progress['stars']);

    final bestTimesMap = _readIntegerMap(progress['bestTimes']);

    final puzzle = _loadPuzzle(globalLevel);

    final world = _progressService.getWorldFromGlobal(globalLevel);

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

    final startGlobalLevel = _progressService.getGlobalLevel(world, 1);

    final endGlobalLevel = _progressService.getGlobalLevel(
      world,
      levelsPerWorld,
    );

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
  Future<void> completeLevel(int globalLevel, int time, int stars) async {
    _validateGlobalLevel(globalLevel);

    if (time <= 0) {
      throw ArgumentError.value(
        time,
        'time',
        'Completion time must be greater than 0 seconds.',
      );
    }

    if (stars < 0 || stars > 3) {
      throw ArgumentError.value(
        stars,
        'stars',
        'Stars must be between 0 and 3.',
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
    // doesn't make the game completely unusable.
    //

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

    _validatePuzzleAgainstSolution(puzzle, solution, globalLevel);

    return _PuzzleData(puzzle: puzzle, solution: solution);
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

  int _readCurrentLevel(Map<String, dynamic> progress) {
    final value = progress['currentLevel'];

    if (value is int && value >= minimumLevel) {
      return value;
    }

    return minimumLevel;
  }

  Set<int> _readCompletedLevels(Map<String, dynamic> progress) {
    final raw = progress['completedLevels'];

    if (raw is! List) {
      return <int>{};
    }

    return raw.whereType<int>().where((level) => level >= minimumLevel).toSet();
  }

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

  void _validateGlobalLevel(int globalLevel) {
    if (globalLevel < minimumLevel) {
      throw ArgumentError.value(
        globalLevel,
        'globalLevel',
        'Global level must be at least $minimumLevel.',
      );
    }
  }

  void _validateWorld(int world) {
    if (world < 1) {
      throw ArgumentError.value(world, 'world', 'World must be at least 1.');
    }
  }

  // ==========================================================================
  // GRID COPYING
  // ==========================================================================

  List<List<int>> _cloneGrid(List<List<int>> source) {
    return source.map((row) => List<int>.from(row)).toList();
  }
}

/// ============================================================================
/// INTERNAL PUZZLE DATA
/// ============================================================================

class _PuzzleData {
  final List<List<int>> puzzle;
  final List<List<int>> solution;

  const _PuzzleData({required this.puzzle, required this.solution});
}
