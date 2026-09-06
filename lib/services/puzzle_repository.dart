import 'dart:math';

/// ============================================================================
/// PuzzleRepository
/// ----------------------------------------------------------------------------
/// Provides deterministic Sudoku puzzles for global level IDs.
///
/// Responsibilities:
/// - Generate a deterministic Sudoku puzzle for each global level.
/// - Generate a valid complete Sudoku solution.
/// - Remove clues while preserving exactly one solution.
/// - Cache generated puzzles in memory.
/// - Return defensive copies to callers.
/// - Keep puzzle-generation rules independent from gameplay progression.
///
/// Architecture:
/// - The global level number is the puzzle identifier.
/// - ProgressService owns progression state and is the progression SOT.
/// - WorldManager owns world/batch calculations.
/// - SudokuGenerator may be used independently for raw Sudoku generation.
/// - This repository owns puzzle identity, difficulty and uniqueness.
///
/// Difficulty:
/// - Levels   1-25  -> Easy
/// - Levels  26-75  -> Medium
/// - Levels  76-150 -> Hard
/// - Levels 151+    -> Expert
///
/// Empty cells:
/// - Easy   -> 35
/// - Medium -> 45
/// - Hard   -> 55
/// - Expert -> 57
///
/// IMPORTANT:
/// - Level numbers are 1-based.
/// - Every accepted puzzle has exactly one solution.
/// - The same level produces the same puzzle across application launches.
/// - The repository does NOT track completion, stars, unlocks or progress.
/// ============================================================================

class PuzzleRepository {
  // ==========================================================================
  // BOARD CONFIGURATION
  // ==========================================================================

  static const int _gridSize = 9;
  static const int _boxSize = 3;
  static const int _cellCount = _gridSize * _gridSize;

  static const int _minimumLevel = 1;

  static const int _minimumValue = 1;
  static const int _maximumValue = 9;

  // ==========================================================================
  // DIFFICULTY CONFIGURATION
  // ==========================================================================

  static const int _easyMaximumLevel = 25;
  static const int _mediumMaximumLevel = 75;
  static const int _hardMaximumLevel = 150;

  /// Number of empty cells for each difficulty.
  ///
  /// These values control generation difficulty.
  /// They do not guarantee a particular human-solving difficulty.
  static const int _easyEmptyCells = 35;
  static const int _mediumEmptyCells = 45;
  static const int _hardEmptyCells = 55;
  static const int _expertEmptyCells = 57;

  // ==========================================================================
  // GENERATION LIMITS
  // ==========================================================================

  /// Maximum number of cell-removal attempts during one puzzle attempt.
  static const int _maximumRemovalAttempts = 5000;

  /// Maximum deterministic retries for one level.
  static const int _maximumGenerationAttempts = 10;

  /// The uniqueness checker only needs to distinguish:
  /// - 0 solutions
  /// - 1 solution
  /// - 2+ solutions
  static const int _solutionCountLimit = 2;

  // ==========================================================================
  // CACHE
  // ==========================================================================

  final Map<int, _PuzzleData> _cache = <int, _PuzzleData>{};

  // ==========================================================================
  // PUBLIC API
  // ==========================================================================

  /// Returns the deterministic puzzle for [levelNumber].
  ///
  /// The same level number produces the same puzzle across application
  /// launches.
  ///
  /// Returns null when [levelNumber] is less than 1.
  ///
  /// A defensive copy is always returned.
  Map<String, dynamic>? getPuzzleForLevel(int levelNumber) {
    if (levelNumber < _minimumLevel) {
      return null;
    }

    final cached = _cache[levelNumber];

    if (cached != null) {
      return cached.toMap();
    }

    final generated = _generatePuzzle(levelNumber);

    _cache[levelNumber] = generated;

    return generated.toMap();
  }

  /// Returns a strongly typed puzzle object.
  ///
  /// This is useful internally or for callers that prefer a typed API.
  ///
  /// A defensive copy is returned.
  Puzzle getPuzzle(int levelNumber) {
    _validateLevel(levelNumber);

    final cached = _cache[levelNumber];

    if (cached != null) {
      return cached.toPuzzle();
    }

    final generated = _generatePuzzle(levelNumber);

    _cache[levelNumber] = generated;

    return generated.toPuzzle();
  }

  /// Returns true when [levelNumber] is currently cached.
  bool isCached(int levelNumber) {
    if (levelNumber < _minimumLevel) {
      return false;
    }

    return _cache.containsKey(levelNumber);
  }

  /// Number of puzzles currently stored in the in-memory cache.
  int get cacheSize => _cache.length;

  /// Removes one puzzle from the cache.
  ///
  /// Returns true when a cached puzzle existed.
  bool removeCachedPuzzle(int levelNumber) {
    return _cache.remove(levelNumber) != null;
  }

  /// Clears every cached puzzle.
  ///
  /// This does not affect deterministic generation.
  void clearCache() {
    _cache.clear();
  }

  /// Returns the configured difficulty for [levelNumber].
  ///
  /// This is based only on the level number and never on player progress.
  PuzzleDifficulty getDifficulty(int levelNumber) {
    _validateLevel(levelNumber);

    if (levelNumber <= _easyMaximumLevel) {
      return PuzzleDifficulty.easy;
    }

    if (levelNumber <= _mediumMaximumLevel) {
      return PuzzleDifficulty.medium;
    }

    if (levelNumber <= _hardMaximumLevel) {
      return PuzzleDifficulty.hard;
    }

    return PuzzleDifficulty.expert;
  }

  /// Returns the configured number of empty cells for [levelNumber].
  int getEmptyCellCount(int levelNumber) {
    _validateLevel(levelNumber);

    return _getEmptyCellCount(levelNumber);
  }

  // ==========================================================================
  // PUZZLE GENERATION
  // ==========================================================================

  _PuzzleData _generatePuzzle(int levelNumber) {
    _validateLevel(levelNumber);

    final emptyCells = _getEmptyCellCount(levelNumber);

    for (int attempt = 0; attempt < _maximumGenerationAttempts; attempt++) {
      final random = Random(_createSeed(levelNumber, attempt));

      final solution = _generateSolvedBoard(random);

      final puzzle = _createUniquePuzzle(
        solution: solution,
        emptyCells: emptyCells,
        random: random,
      );

      if (puzzle == null) {
        continue;
      }

      _validateSolvedBoard(solution);
      _validatePuzzle(puzzle);

      return _PuzzleData(
        puzzle: puzzle,
        solution: solution,
        difficulty: getDifficulty(levelNumber),
      );
    }

    throw StateError(
      'Unable to generate a unique Sudoku puzzle for level '
      '$levelNumber after $_maximumGenerationAttempts attempts.',
    );
  }

  /// Creates a deterministic seed from the level and generation attempt.
  ///
  /// The attempt value allows deterministic retries while preserving the
  /// same output for a given level.
  int _createSeed(int levelNumber, int attempt) {
    const int levelMultiplier = 1000003;
    const int attemptMultiplier = 7919;

    return ((levelNumber * levelMultiplier) + (attempt * attemptMultiplier)) &
        0x7fffffff;
  }

  // ==========================================================================
  // DIFFICULTY
  // ==========================================================================

  int _getEmptyCellCount(int levelNumber) {
    if (levelNumber <= _easyMaximumLevel) {
      return _easyEmptyCells;
    }

    if (levelNumber <= _mediumMaximumLevel) {
      return _mediumEmptyCells;
    }

    if (levelNumber <= _hardMaximumLevel) {
      return _hardEmptyCells;
    }

    return _expertEmptyCells;
  }

  // ==========================================================================
  // SOLVED BOARD GENERATION
  // ==========================================================================

  /// Generates a complete valid Sudoku solution using randomized
  /// backtracking.
  List<List<int>> _generateSolvedBoard(Random random) {
    final board = _createEmptyBoard();

    if (!_fillBoard(board, random)) {
      throw StateError('Failed to generate a valid Sudoku solution.');
    }

    return _cloneGrid(board);
  }

  /// Randomized backtracking solver used to generate a complete board.
  bool _fillBoard(List<List<int>> board, Random random) {
    final emptyCell = _findBestEmptyCell(board);

    if (emptyCell == null) {
      return true;
    }

    final row = emptyCell.row;
    final col = emptyCell.col;

    final candidates = <int>[
      for (int value = _minimumValue; value <= _maximumValue; value++) value,
    ];

    candidates.shuffle(random);

    for (final value in candidates) {
      if (!_isSafe(board, row, col, value)) {
        continue;
      }

      board[row][col] = value;

      if (_fillBoard(board, random)) {
        return true;
      }

      board[row][col] = 0;
    }

    return false;
  }

  // ==========================================================================
  // UNIQUE PUZZLE CREATION
  // ==========================================================================

  /// Removes clues while preserving exactly one solution.
  ///
  /// Returns null when the requested number of empty cells cannot be reached
  /// within the configured attempt limit.
  List<List<int>>? _createUniquePuzzle({
    required List<List<int>> solution,
    required int emptyCells,
    required Random random,
  }) {
    if (emptyCells < 0 || emptyCells >= _cellCount) {
      throw ArgumentError.value(
        emptyCells,
        'emptyCells',
        'Empty cells must be between 0 and ${_cellCount - 1}.',
      );
    }

    final puzzle = _cloneGrid(solution);

    if (emptyCells == 0) {
      return puzzle;
    }

    final positions = <int>[
      for (int index = 0; index < _cellCount; index++) index,
    ];

    positions.shuffle(random);

    int removed = 0;
    int attempts = 0;

    for (final position in positions) {
      if (removed >= emptyCells) {
        break;
      }

      if (attempts >= _maximumRemovalAttempts) {
        break;
      }

      attempts++;

      final row = position ~/ _gridSize;
      final col = position % _gridSize;

      final previousValue = puzzle[row][col];

      if (previousValue == 0) {
        continue;
      }

      puzzle[row][col] = 0;

      final solutionCount = _countSolutions(puzzle, limit: _solutionCountLimit);

      if (solutionCount == 1) {
        removed++;
      } else {
        puzzle[row][col] = previousValue;
      }
    }

    if (removed != emptyCells) {
      return null;
    }

    return puzzle;
  }

  // ==========================================================================
  // SOLUTION COUNTING
  // ==========================================================================

  /// Counts solutions up to [limit].
  ///
  /// The returned value never exceeds [limit].
  int _countSolutions(List<List<int>> board, {required int limit}) {
    if (limit < 1) {
      throw ArgumentError.value(
        limit,
        'limit',
        'Solution count limit must be at least 1.',
      );
    }

    final workingBoard = _cloneGrid(board);

    return _countSolutionsRecursive(workingBoard, limit);
  }

  int _countSolutionsRecursive(List<List<int>> board, int limit) {
    if (limit <= 0) {
      return 0;
    }

    final emptyCell = _findBestEmptyCell(board);

    if (emptyCell == null) {
      return 1;
    }

    final row = emptyCell.row;
    final col = emptyCell.col;

    int count = 0;

    for (int value = _minimumValue; value <= _maximumValue; value++) {
      if (!_isSafe(board, row, col, value)) {
        continue;
      }

      board[row][col] = value;

      count += _countSolutionsRecursive(board, limit - count);

      board[row][col] = 0;

      if (count >= limit) {
        return limit;
      }
    }

    return count;
  }

  // ==========================================================================
  // SUDOKU VALIDATION
  // ==========================================================================

  /// Returns true when [value] can safely be placed in the cell.
  bool _isSafe(List<List<int>> board, int row, int col, int value) {
    if (row < 0 ||
        row >= _gridSize ||
        col < 0 ||
        col >= _gridSize ||
        value < _minimumValue ||
        value > _maximumValue) {
      return false;
    }

    // ------------------------------------------------------------------------
    // ROW
    // ------------------------------------------------------------------------

    for (int currentCol = 0; currentCol < _gridSize; currentCol++) {
      if (currentCol != col && board[row][currentCol] == value) {
        return false;
      }
    }

    // ------------------------------------------------------------------------
    // COLUMN
    // ------------------------------------------------------------------------

    for (int currentRow = 0; currentRow < _gridSize; currentRow++) {
      if (currentRow != row && board[currentRow][col] == value) {
        return false;
      }
    }

    // ------------------------------------------------------------------------
    // 3x3 BOX
    // ------------------------------------------------------------------------

    final boxStartRow = row - (row % _boxSize);
    final boxStartCol = col - (col % _boxSize);

    for (
      int currentRow = boxStartRow;
      currentRow < boxStartRow + _boxSize;
      currentRow++
    ) {
      for (
        int currentCol = boxStartCol;
        currentCol < boxStartCol + _boxSize;
        currentCol++
      ) {
        if ((currentRow != row || currentCol != col) &&
            board[currentRow][currentCol] == value) {
          return false;
        }
      }
    }

    return true;
  }

  /// Validates that a board is a complete valid Sudoku solution.
  void _validateSolvedBoard(List<List<int>> board) {
    _validateBoardShape(board);

    for (int row = 0; row < _gridSize; row++) {
      final values = <int>{};

      for (int col = 0; col < _gridSize; col++) {
        final value = board[row][col];

        if (value < _minimumValue || value > _maximumValue) {
          throw StateError(
            'Generated solution contains invalid value '
            '$value at ($row, $col).',
          );
        }

        values.add(value);
      }

      if (values.length != _gridSize) {
        throw StateError(
          'Generated solution contains duplicate values in row $row.',
        );
      }
    }

    for (int col = 0; col < _gridSize; col++) {
      final values = <int>{};

      for (int row = 0; row < _gridSize; row++) {
        values.add(board[row][col]);
      }

      if (values.length != _gridSize) {
        throw StateError(
          'Generated solution contains duplicate values in column $col.',
        );
      }
    }

    for (int boxRow = 0; boxRow < _gridSize; boxRow += _boxSize) {
      for (int boxCol = 0; boxCol < _gridSize; boxCol += _boxSize) {
        final values = <int>{};

        for (int row = boxRow; row < boxRow + _boxSize; row++) {
          for (int col = boxCol; col < boxCol + _boxSize; col++) {
            values.add(board[row][col]);
          }
        }

        if (values.length != _cellCount ~/ _gridSize) {
          throw StateError(
            'Generated solution contains duplicate values '
            'in box ($boxRow, $boxCol).',
          );
        }
      }
    }
  }

  /// Validates a playable puzzle.
  void _validatePuzzle(List<List<int>> puzzle) {
    _validateBoardShape(puzzle);

    for (int row = 0; row < _gridSize; row++) {
      for (int col = 0; col < _gridSize; col++) {
        final value = puzzle[row][col];

        if (value < 0 || value > _maximumValue) {
          throw StateError(
            'Generated puzzle contains invalid value '
            '$value at ($row, $col).',
          );
        }

        if (value == 0) {
          continue;
        }

        final currentValue = puzzle[row][col];

        puzzle[row][col] = 0;

        final safe = _isSafe(puzzle, row, col, currentValue);

        puzzle[row][col] = currentValue;

        if (!safe) {
          throw StateError(
            'Generated puzzle contains an invalid Sudoku conflict '
            'at ($row, $col).',
          );
        }
      }
    }

    final solutionCount = _countSolutions(puzzle, limit: _solutionCountLimit);

    if (solutionCount != 1) {
      throw StateError('Generated puzzle does not have exactly one solution.');
    }
  }

  // ==========================================================================
  // BOARD HELPERS
  // ==========================================================================

  List<List<int>> _createEmptyBoard() {
    return List<List<int>>.generate(
      _gridSize,
      (_) => List<int>.filled(_gridSize, 0, growable: false),
      growable: false,
    );
  }

  List<List<int>> _cloneGrid(List<List<int>> source) {
    return List<List<int>>.generate(
      source.length,
      (row) => List<int>.from(source[row], growable: false),
      growable: false,
    );
  }

  void _validateBoardShape(List<List<int>> board) {
    if (board.length != _gridSize) {
      throw StateError('Sudoku board must contain exactly $_gridSize rows.');
    }

    for (int row = 0; row < _gridSize; row++) {
      if (board[row].length != _gridSize) {
        throw StateError(
          'Sudoku row $row must contain exactly $_gridSize cells.',
        );
      }
    }
  }

  // ==========================================================================
  // BEST EMPTY CELL
  // ==========================================================================

  /// Finds the empty cell with the fewest legal candidates.
  ///
  /// This significantly reduces the search space compared with simply
  /// selecting the first empty cell.
  _CellPosition? _findBestEmptyCell(List<List<int>> board) {
    _CellPosition? bestPosition;
    int bestCandidateCount = _maximumValue + 1;

    for (int row = 0; row < _gridSize; row++) {
      for (int col = 0; col < _gridSize; col++) {
        if (board[row][col] != 0) {
          continue;
        }

        int candidateCount = 0;

        for (int value = _minimumValue; value <= _maximumValue; value++) {
          if (_isSafe(board, row, col, value)) {
            candidateCount++;
          }
        }

        if (candidateCount < bestCandidateCount) {
          bestCandidateCount = candidateCount;

          bestPosition = _CellPosition(row: row, col: col);

          // No legal candidates means this branch is impossible.
          if (candidateCount == 0) {
            return bestPosition;
          }

          // One candidate is optimal for this search.
          if (candidateCount == 1) {
            return bestPosition;
          }
        }
      }
    }

    return bestPosition;
  }

  // ==========================================================================
  // VALIDATION
  // ==========================================================================

  void _validateLevel(int levelNumber) {
    if (levelNumber < _minimumLevel) {
      throw ArgumentError.value(
        levelNumber,
        'levelNumber',
        'Level number must be at least $_minimumLevel.',
      );
    }
  }
}

// ============================================================================
// PUZZLE DIFFICULTY
// ============================================================================

/// Difficulty category assigned to a generated puzzle.
enum PuzzleDifficulty { easy, medium, hard, expert }

// ============================================================================
// PUZZLE DATA
// ============================================================================

/// Internal immutable cache representation.
///
/// The class is private because callers should interact with the repository
/// rather than the cache implementation.
class _PuzzleData {
  final List<List<int>> puzzle;
  final List<List<int>> solution;
  final PuzzleDifficulty difficulty;

  _PuzzleData({
    required List<List<int>> puzzle,
    required List<List<int>> solution,
    required this.difficulty,
  }) : puzzle = _cloneGrid(puzzle),
       solution = _cloneGrid(solution);

  Puzzle toPuzzle() {
    return Puzzle(
      puzzle: _cloneGrid(puzzle),
      solution: _cloneGrid(solution),
      difficulty: difficulty,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'puzzle': _cloneGrid(puzzle),
      'solution': _cloneGrid(solution),
      'difficulty': difficulty.name,
    };
  }

  static List<List<int>> _cloneGrid(List<List<int>> source) {
    return List<List<int>>.generate(
      source.length,
      (row) => List<int>.from(source[row], growable: false),
      growable: false,
    );
  }
}

// ============================================================================
// PUBLIC PUZZLE MODEL
// ============================================================================

/// Immutable public representation of a generated Sudoku puzzle.
///
/// Defensive copies are returned from all getters.
class Puzzle {
  final List<List<int>> _puzzle;
  final List<List<int>> _solution;

  /// Difficulty assigned by the repository.
  final PuzzleDifficulty difficulty;

  Puzzle({
    required List<List<int>> puzzle,
    required List<List<int>> solution,
    required this.difficulty,
  }) : _puzzle = _cloneGrid(puzzle),
       _solution = _cloneGrid(solution);

  /// Puzzle board.
  ///
  /// Zero represents an empty cell.
  List<List<int>> get puzzle => _cloneGrid(_puzzle);

  /// Complete solution board.
  List<List<int>> get solution => _cloneGrid(_solution);

  /// Number of empty cells in the puzzle.
  int get emptyCellCount {
    int count = 0;

    for (final row in _puzzle) {
      for (final value in row) {
        if (value == 0) {
          count++;
        }
      }
    }

    return count;
  }

  /// Converts the puzzle to a map for compatibility with existing code.
  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'puzzle': puzzle,
      'solution': solution,
      'difficulty': difficulty.name,
      'emptyCellCount': emptyCellCount,
    };
  }

  static List<List<int>> _cloneGrid(List<List<int>> source) {
    return List<List<int>>.generate(
      source.length,
      (row) => List<int>.from(source[row], growable: false),
      growable: false,
    );
  }
}

// ============================================================================
// CELL POSITION
// ============================================================================

class _CellPosition {
  final int row;
  final int col;

  const _CellPosition({required this.row, required this.col});
}
