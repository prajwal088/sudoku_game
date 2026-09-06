/// ============================================================================
/// SudokuSolver
/// ----------------------------------------------------------------------------
/// High-performance Sudoku solving engine.
///
/// Responsibilities:
/// - Solve valid 9x9 Sudoku boards.
/// - Validate existing puzzle data before solving.
/// - Support deterministic solving.
/// - Support randomized solving for puzzle generation.
/// - Provide solved copies for hints/gameplay.
/// - Avoid modifying the caller's board except through [solve].
///
/// Architecture:
/// - The supplied board is mutated by [solve].
/// - [getSolvedBoard] never mutates the caller's board.
/// - Invalid board shapes/values return false instead of throwing during solve.
///
/// IMPORTANT:
/// - [solve] returns true when a solution is found.
/// - [solve] returns false when the board is invalid or unsolvable.
/// - A solved board is not necessarily a uniquely solvable puzzle.
///   Use [countSolutions] when uniqueness verification is required.
/// ============================================================================

class SudokuSolver {
  static const int gridSize = 9;
  static const int boxSize = 3;
  static const int minValue = 1;
  static const int maxValue = 9;

  /// Maximum number of solutions needed when checking uniqueness.
  static const int _solutionSearchLimit = 2;

  // ==========================================================================
  // SOLVE
  // ==========================================================================

  /// Solves [board] in place.
  ///
  /// Returns:
  /// - true  -> a valid solution was found.
  /// - false -> the board is malformed, invalid, or unsolvable.
  ///
  /// When [randomize] is true, candidate numbers are shuffled before trying
  /// them. This is useful when generating different valid Sudoku solutions.
  static bool solve(List<List<int>> board, {bool randomize = false}) {
    if (!_isValidBoardShape(board)) {
      return false;
    }

    if (!_isInitialBoardValid(board)) {
      return false;
    }

    return _backtrack(board, randomize: randomize);
  }

  // ==========================================================================
  // BACKTRACKING ENGINE
  // ==========================================================================

  /// Recursive solving engine using MRV:
  ///
  /// Instead of blindly selecting the first empty cell, we select the empty
  /// cell with the fewest available candidates.
  ///
  /// This significantly reduces the search tree for difficult puzzles.
  static bool _backtrack(List<List<int>> board, {required bool randomize}) {
    final cell = _findBestEmptyCell(board);

    // No empty cells means the board is completely solved.
    if (cell == null) {
      return true;
    }

    final row = cell.row;
    final col = cell.col;
    final candidates = _getCandidates(board, row, col);

    if (candidates.isEmpty) {
      return false;
    }

    if (randomize) {
      candidates.shuffle();
    }

    for (final number in candidates) {
      board[row][col] = number;

      if (_backtrack(board, randomize: randomize)) {
        return true;
      }

      board[row][col] = 0;
    }

    return false;
  }

  // ==========================================================================
  // BEST CELL SELECTION
  // ==========================================================================

  /// Finds the empty cell with the fewest legal candidates.
  ///
  /// MRV = Minimum Remaining Values.
  ///
  /// This is considerably faster than scanning for the first empty cell on
  /// difficult Sudoku boards.
  static _EmptyCell? _findBestEmptyCell(List<List<int>> board) {
    _EmptyCell? bestCell;
    var fewestCandidates = maxValue + 1;

    for (var row = 0; row < gridSize; row++) {
      for (var col = 0; col < gridSize; col++) {
        if (board[row][col] != 0) {
          continue;
        }

        final candidates = _getCandidates(board, row, col);

        if (candidates.isEmpty) {
          return _EmptyCell(row: row, col: col);
        }

        if (candidates.length < fewestCandidates) {
          fewestCandidates = candidates.length;

          bestCell = _EmptyCell(row: row, col: col);

          // No cell can have fewer than one candidate.
          if (fewestCandidates == 1) {
            return bestCell;
          }
        }
      }
    }

    return bestCell;
  }

  // ==========================================================================
  // CANDIDATES
  // ==========================================================================

  /// Returns all numbers that can legally be placed at [row], [col].
  static List<int> _getCandidates(List<List<int>> board, int row, int col) {
    final used = <int>{};

    // Row.
    for (var currentCol = 0; currentCol < gridSize; currentCol++) {
      final value = board[row][currentCol];

      if (value != 0) {
        used.add(value);
      }
    }

    // Column.
    for (var currentRow = 0; currentRow < gridSize; currentRow++) {
      final value = board[currentRow][col];

      if (value != 0) {
        used.add(value);
      }
    }

    // 3x3 box.
    final startRow = row - (row % boxSize);
    final startCol = col - (col % boxSize);

    for (
      var currentRow = startRow;
      currentRow < startRow + boxSize;
      currentRow++
    ) {
      for (
        var currentCol = startCol;
        currentCol < startCol + boxSize;
        currentCol++
      ) {
        final value = board[currentRow][currentCol];

        if (value != 0) {
          used.add(value);
        }
      }
    }

    final candidates = <int>[];

    for (var number = minValue; number <= maxValue; number++) {
      if (!used.contains(number)) {
        candidates.add(number);
      }
    }

    return candidates;
  }

  // ==========================================================================
  // SAFETY CHECK
  // ==========================================================================

  /// Returns whether [num] can legally be placed at [row], [col].
  static bool isSafe(List<List<int>> board, int row, int col, int num) {
    if (!_isValidBoardShape(board)) {
      return false;
    }

    if (row < 0 ||
        row >= gridSize ||
        col < 0 ||
        col >= gridSize ||
        num < minValue ||
        num > maxValue) {
      return false;
    }

    // Row.
    for (var currentCol = 0; currentCol < gridSize; currentCol++) {
      if (currentCol != col && board[row][currentCol] == num) {
        return false;
      }
    }

    // Column.
    for (var currentRow = 0; currentRow < gridSize; currentRow++) {
      if (currentRow != row && board[currentRow][col] == num) {
        return false;
      }
    }

    // 3x3 box.
    final startRow = row - (row % boxSize);
    final startCol = col - (col % boxSize);

    for (
      var currentRow = startRow;
      currentRow < startRow + boxSize;
      currentRow++
    ) {
      for (
        var currentCol = startCol;
        currentCol < startCol + boxSize;
        currentCol++
      ) {
        if ((currentRow != row || currentCol != col) &&
            board[currentRow][currentCol] == num) {
          return false;
        }
      }
    }

    return true;
  }

  // ==========================================================================
  // INITIAL BOARD VALIDATION
  // ==========================================================================

  /// Validates the board's existing values without modifying it.
  static bool _isInitialBoardValid(List<List<int>> board) {
    for (var row = 0; row < gridSize; row++) {
      for (var col = 0; col < gridSize; col++) {
        final value = board[row][col];

        // Zero means empty.
        if (value == 0) {
          continue;
        }

        if (value < minValue || value > maxValue) {
          return false;
        }

        if (!isSafe(board, row, col, value)) {
          return false;
        }
      }
    }

    return true;
  }

  // ==========================================================================
  // BOARD VALIDATION
  // ==========================================================================

  /// Validates that the supplied board is exactly 9x9 and contains only
  /// integers from 0 to 9.
  static bool _isValidBoardShape(List<List<int>> board) {
    if (board.length != gridSize) {
      return false;
    }

    for (final row in board) {
      if (row.length != gridSize) {
        return false;
      }

      for (final value in row) {
        if (value < 0 || value > maxValue) {
          return false;
        }
      }
    }

    return true;
  }

  // ==========================================================================
  // SOLVED COPY
  // ==========================================================================

  /// Returns a solved copy of [board].
  ///
  /// The original board is never modified.
  ///
  /// Returns null when the board is malformed, invalid, or unsolvable.
  static List<List<int>>? getSolvedBoard(List<List<int>> board) {
    if (!_isValidBoardShape(board)) {
      return null;
    }

    final copy = _cloneGrid(board);

    if (!solve(copy)) {
      return null;
    }

    return copy;
  }

  // ==========================================================================
  // SOLUTION CHECK
  // ==========================================================================

  /// Returns true when [board] is a completely solved valid Sudoku board.
  static bool isSolved(List<List<int>> board) {
    if (!_isValidBoardShape(board)) {
      return false;
    }

    for (var row = 0; row < gridSize; row++) {
      for (var col = 0; col < gridSize; col++) {
        final value = board[row][col];

        if (value == 0) {
          return false;
        }

        if (!isSafe(board, row, col, value)) {
          return false;
        }
      }
    }

    return true;
  }

  // ==========================================================================
  // SOLUTION COUNT / UNIQUENESS
  // ==========================================================================

  /// Returns the number of solutions found, up to [limit].
  ///
  /// By default, the search stops after finding two solutions because:
  ///
  /// - 0 = unsolvable
  /// - 1 = uniquely solvable
  /// - 2 = multiple solutions
  ///
  /// This is useful when validating generated puzzles.
  static int countSolutions(
    List<List<int>> board, {
    int limit = _solutionSearchLimit,
  }) {
    if (limit < 1) {
      throw ArgumentError.value(
        limit,
        'limit',
        'Solution limit must be at least 1.',
      );
    }

    if (!_isValidBoardShape(board)) {
      return 0;
    }

    if (!_isInitialBoardValid(board)) {
      return 0;
    }

    final copy = _cloneGrid(board);

    return _countSolutions(copy, limit);
  }

  static int _countSolutions(List<List<int>> board, int limit) {
    if (limit <= 0) {
      return 0;
    }

    final cell = _findBestEmptyCell(board);

    if (cell == null) {
      return 1;
    }

    final candidates = _getCandidates(board, cell.row, cell.col);

    if (candidates.isEmpty) {
      return 0;
    }

    var solutionCount = 0;

    for (final number in candidates) {
      board[cell.row][cell.col] = number;

      solutionCount += _countSolutions(board, limit - solutionCount);

      board[cell.row][cell.col] = 0;

      if (solutionCount >= limit) {
        return limit;
      }
    }

    return solutionCount;
  }

  // ==========================================================================
  // COPY
  // ==========================================================================

  static List<List<int>> _cloneGrid(List<List<int>> source) {
    return List<List<int>>.generate(
      source.length,
      (row) => List<int>.from(source[row]),
      growable: false,
    );
  }
}

/// Internal representation of an empty Sudoku cell.
class _EmptyCell {
  final int row;
  final int col;

  const _EmptyCell({required this.row, required this.col});
}
