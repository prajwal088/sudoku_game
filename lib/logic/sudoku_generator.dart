import 'dart:math';

/// ============================================================================
/// SudokuGenerator
/// ----------------------------------------------------------------------------
/// Generates valid 9x9 Sudoku boards and puzzles.
///
/// Responsibilities:
/// - Generate a complete valid Sudoku solution.
/// - Generate a puzzle by removing values from a solution.
/// - Validate generation parameters.
/// - Keep generated state private to prevent accidental external mutation.
///
/// Design:
/// - Uses randomized backtracking.
/// - Supports an optional Random instance for deterministic generation.
/// - Returns deep copies from all public methods.
/// - Does not depend on SudokuSolver, avoiding circular responsibilities.
///
/// IMPORTANT:
/// - This class generates valid Sudoku boards.
/// - It does NOT guarantee a puzzle has exactly one solution.
/// - If uniqueness is required, use a solver/count-solutions check in the
///   repository before accepting a generated puzzle.
/// ============================================================================

class SudokuGenerator {
  static const int gridSize = 9;
  static const int boxSize = 3;
  static const int minValue = 1;
  static const int maxValue = 9;

  /// Maximum number of cells that can be removed from a solved Sudoku.
  static const int maxRemovableCells = 81;

  /// Random source used by this generator.
  final Random _random;

  /// Internal mutable board.
  List<List<int>> _board = _createEmptyBoard();

  /// Creates a generator.
  ///
  /// Pass a seeded [Random] when deterministic generation is required.
  ///
  /// Example:
  /// ```dart
  /// final generator = SudokuGenerator(Random(123));
  /// ```
  SudokuGenerator([Random? random]) : _random = random ?? Random();

  // ==========================================================================
  // BOARD CREATION
  // ==========================================================================

  static List<List<int>> _createEmptyBoard() {
    return List<List<int>>.generate(
      gridSize,
      (_) => List<int>.filled(gridSize, 0),
      growable: false,
    );
  }

  List<List<int>> _cloneGrid(List<List<int>> source) {
    return List<List<int>>.generate(
      source.length,
      (row) => List<int>.from(source[row]),
      growable: false,
    );
  }

  // ==========================================================================
  // VALIDATION
  // ==========================================================================

  /// Returns true when [row], [col], and [num] are valid Sudoku coordinates.
  bool _isValidPosition(int row, int col, int num) {
    return row >= 0 &&
        row < gridSize &&
        col >= 0 &&
        col < gridSize &&
        num >= minValue &&
        num <= maxValue;
  }

  /// Checks whether [num] can safely be placed at [row], [col].
  ///
  /// This method operates against the generator's current internal board.
  bool isSafe(int row, int col, int num) {
    if (!_isValidPosition(row, col, num)) {
      return false;
    }

    // ------------------------------------------------------------------------
    // ROW
    // ------------------------------------------------------------------------

    for (int currentCol = 0; currentCol < gridSize; currentCol++) {
      if (currentCol != col && _board[row][currentCol] == num) {
        return false;
      }
    }

    // ------------------------------------------------------------------------
    // COLUMN
    // ------------------------------------------------------------------------

    for (int currentRow = 0; currentRow < gridSize; currentRow++) {
      if (currentRow != row && _board[currentRow][col] == num) {
        return false;
      }
    }

    // ------------------------------------------------------------------------
    // 3x3 BOX
    // ------------------------------------------------------------------------

    final boxStartRow = row - (row % boxSize);
    final boxStartCol = col - (col % boxSize);

    for (
      int currentRow = boxStartRow;
      currentRow < boxStartRow + boxSize;
      currentRow++
    ) {
      for (
        int currentCol = boxStartCol;
        currentCol < boxStartCol + boxSize;
        currentCol++
      ) {
        if ((currentRow != row || currentCol != col) &&
            _board[currentRow][currentCol] == num) {
          return false;
        }
      }
    }

    return true;
  }

  // ==========================================================================
  // SOLUTION GENERATION
  // ==========================================================================

  /// Generates a complete, valid Sudoku solution.
  ///
  /// Every returned cell contains a value from 1 to 9.
  List<List<int>> generateSolvedBoard() {
    _board = _createEmptyBoard();

    final solved = _fillBoard();

    if (!solved) {
      // This should be practically unreachable with an empty 9x9 board.
      throw StateError('Failed to generate a valid Sudoku solution.');
    }

    return _cloneGrid(_board);
  }

  /// Backtracking algorithm used to fill the board.
  bool _fillBoard() {
    final emptyCell = _findEmptyCell();

    // No empty cells means the board is complete.
    if (emptyCell == null) {
      return true;
    }

    final row = emptyCell.$1;
    final col = emptyCell.$2;

    final numbers = List<int>.generate(maxValue, (index) => index + minValue);

    numbers.shuffle(_random);

    for (final num in numbers) {
      if (!isSafe(row, col, num)) {
        continue;
      }

      _board[row][col] = num;

      if (_fillBoard()) {
        return true;
      }

      _board[row][col] = 0;
    }

    return false;
  }

  (int, int)? _findEmptyCell() {
    for (int row = 0; row < gridSize; row++) {
      for (int col = 0; col < gridSize; col++) {
        if (_board[row][col] == 0) {
          return (row, col);
        }
      }
    }

    return null;
  }

  // ==========================================================================
  // PUZZLE GENERATION
  // ==========================================================================

  /// Generates a Sudoku puzzle by removing [removeCount] values from a
  /// newly generated solved board.
  ///
  /// [removeCount] must be between 0 and 81.
  ///
  /// NOTE:
  /// Removing cells does not guarantee a unique solution.
  /// For production gameplay, uniqueness should be verified before accepting
  /// a generated puzzle if your game requires exactly one solution.
  List<List<int>> generatePuzzle(int removeCount) {
    if (removeCount < 0 || removeCount > maxRemovableCells) {
      throw ArgumentError.value(
        removeCount,
        'removeCount',
        'Remove count must be between 0 and $maxRemovableCells.',
      );
    }

    final solution = generateSolvedBoard();
    final puzzle = _cloneGrid(solution);

    if (removeCount == 0) {
      return puzzle;
    }

    final positions = <int>[
      for (int index = 0; index < gridSize * gridSize; index++) index,
    ];

    positions.shuffle(_random);

    for (int index = 0; index < removeCount; index++) {
      final position = positions[index];

      final row = position ~/ gridSize;
      final col = position % gridSize;

      puzzle[row][col] = 0;
    }

    return puzzle;
  }
}
