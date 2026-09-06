/// ============================================================================
/// SudokuValidator
/// ----------------------------------------------------------------------------
/// Stateless validation utilities for a standard 9x9 Sudoku game.
///
/// Responsibilities:
/// - Validate individual player moves.
/// - Validate a board against a known solution.
/// - Determine whether a board is completely and correctly solved.
/// - Validate Sudoku board structure safely.
///
/// Design:
/// - Stateless utility class.
/// - Never mutates caller-provided boards.
/// - Safely handles malformed boards.
/// - Compatible with gameplay, hints, mistake tracking, and completion checks.
///
/// Board representation:
/// - 9 rows x 9 columns.
/// - 0 represents an empty cell.
/// - 1..9 represent Sudoku values.
/// ============================================================================

class SudokuValidator {
  static const int gridSize = 9;
  static const int boxSize = 3;
  static const int minValue = 1;
  static const int maxValue = 9;
  static const int emptyValue = 0;

  // ==========================================================================
  // MOVE VALIDATION
  // ==========================================================================

  /// Checks whether [num] can legally be placed at [row], [col].
  ///
  /// [excludeSelf] should normally remain true when the cell already contains
  /// [num], such as when validating an existing board.
  ///
  /// Examples:
  ///
  /// ```dart
  /// SudokuValidator.isValidMove(
  ///   board,
  ///   0,
  ///   0,
  ///   5,
  /// );
  /// ```
  ///
  /// Returns false when:
  /// - the board is malformed
  /// - row/column is outside 0..8
  /// - num is outside 0..9
  /// - num conflicts with the row
  /// - num conflicts with the column
  /// - num conflicts with the 3x3 box
  static bool isValidMove(
    List<List<int>> board,
    int row,
    int col,
    int num, {
    bool excludeSelf = true,
  }) {
    if (!_isValidBoardShape(board)) {
      return false;
    }

    if (!_isValidPosition(row, col)) {
      return false;
    }

    if (num < emptyValue || num > maxValue) {
      return false;
    }

    // Empty cells do not violate Sudoku rules.
    if (num == emptyValue) {
      return true;
    }

    // ------------------------------------------------------------------------
    // ROW
    // ------------------------------------------------------------------------

    for (int currentCol = 0; currentCol < gridSize; currentCol++) {
      if (excludeSelf && currentCol == col) {
        continue;
      }

      if (board[row][currentCol] == num) {
        return false;
      }
    }

    // ------------------------------------------------------------------------
    // COLUMN
    // ------------------------------------------------------------------------

    for (int currentRow = 0; currentRow < gridSize; currentRow++) {
      if (excludeSelf && currentRow == row) {
        continue;
      }

      if (board[currentRow][col] == num) {
        return false;
      }
    }

    // ------------------------------------------------------------------------
    // 3x3 BOX
    // ------------------------------------------------------------------------

    final startRow = (row ~/ boxSize) * boxSize;
    final startCol = (col ~/ boxSize) * boxSize;

    for (
      int currentRow = startRow;
      currentRow < startRow + boxSize;
      currentRow++
    ) {
      for (
        int currentCol = startCol;
        currentCol < startCol + boxSize;
        currentCol++
      ) {
        if (excludeSelf && currentRow == row && currentCol == col) {
          continue;
        }

        if (board[currentRow][currentCol] == num) {
          return false;
        }
      }
    }

    return true;
  }

  // ==========================================================================
  // SOLUTION VALIDATION
  // ==========================================================================

  /// Checks whether every non-empty value in [currentBoard] matches the
  /// corresponding value in [solution].
  ///
  /// This is useful for real-time mistake detection.
  ///
  /// Empty cells (0) are allowed.
  ///
  /// Example:
  ///
  /// Current:
  ///   5 3 0 ...
  ///
  /// Solution:
  ///   5 3 4 ...
  ///
  /// The current board is considered valid because all entered values match
  /// the solution.
  static bool isValidSolution(
    List<List<int>> currentBoard,
    List<List<int>> solution,
  ) {
    if (!_isValidBoardShape(currentBoard) || !_isValidBoardShape(solution)) {
      return false;
    }

    // The supplied solution must itself be a valid completed Sudoku.
    if (!isBoardComplete(solution)) {
      return false;
    }

    for (int row = 0; row < gridSize; row++) {
      for (int col = 0; col < gridSize; col++) {
        final currentValue = currentBoard[row][col];

        if (currentValue < emptyValue || currentValue > maxValue) {
          return false;
        }

        // Empty cells are allowed while playing.
        if (currentValue == emptyValue) {
          continue;
        }

        if (currentValue != solution[row][col]) {
          return false;
        }
      }
    }

    return true;
  }

  // ==========================================================================
  // COMPLETE BOARD VALIDATION
  // ==========================================================================

  /// Returns true only when [board] is:
  ///
  /// - exactly 9x9
  /// - completely filled
  /// - contains only values 1..9
  /// - has no duplicate values in any row
  /// - has no duplicate values in any column
  /// - has no duplicate values in any 3x3 box
  static bool isBoardComplete(List<List<int>> board) {
    if (!_isValidBoardShape(board)) {
      return false;
    }

    // ------------------------------------------------------------------------
    // ROWS
    // ------------------------------------------------------------------------

    for (int row = 0; row < gridSize; row++) {
      final seen = <int>{};

      for (int col = 0; col < gridSize; col++) {
        final value = board[row][col];

        if (value < minValue || value > maxValue) {
          return false;
        }

        if (!seen.add(value)) {
          return false;
        }
      }
    }

    // ------------------------------------------------------------------------
    // COLUMNS
    // ------------------------------------------------------------------------

    for (int col = 0; col < gridSize; col++) {
      final seen = <int>{};

      for (int row = 0; row < gridSize; row++) {
        final value = board[row][col];

        if (!seen.add(value)) {
          return false;
        }
      }
    }

    // ------------------------------------------------------------------------
    // 3x3 BOXES
    // ------------------------------------------------------------------------

    for (int boxRow = 0; boxRow < gridSize; boxRow += boxSize) {
      for (int boxCol = 0; boxCol < gridSize; boxCol += boxSize) {
        final seen = <int>{};

        for (int row = boxRow; row < boxRow + boxSize; row++) {
          for (int col = boxCol; col < boxCol + boxSize; col++) {
            final value = board[row][col];

            if (!seen.add(value)) {
              return false;
            }
          }
        }
      }
    }

    return true;
  }

  // ==========================================================================
  // PARTIAL BOARD VALIDATION
  // ==========================================================================

  /// Returns true when the current board contains no Sudoku conflicts.
  ///
  /// Unlike [isBoardComplete], empty cells are allowed.
  ///
  /// This is useful for:
  /// - loading saved games
  /// - validating user input
  /// - checking restored game state
  /// - debugging puzzle state
  static bool isValidBoard(List<List<int>> board) {
    if (!_isValidBoardShape(board)) {
      return false;
    }

    // ------------------------------------------------------------------------
    // ROWS
    // ------------------------------------------------------------------------

    for (int row = 0; row < gridSize; row++) {
      final seen = <int>{};

      for (int col = 0; col < gridSize; col++) {
        final value = board[row][col];

        if (value < emptyValue || value > maxValue) {
          return false;
        }

        if (value != emptyValue && !seen.add(value)) {
          return false;
        }
      }
    }

    // ------------------------------------------------------------------------
    // COLUMNS
    // ------------------------------------------------------------------------

    for (int col = 0; col < gridSize; col++) {
      final seen = <int>{};

      for (int row = 0; row < gridSize; row++) {
        final value = board[row][col];

        if (value != emptyValue && !seen.add(value)) {
          return false;
        }
      }
    }

    // ------------------------------------------------------------------------
    // 3x3 BOXES
    // ------------------------------------------------------------------------

    for (int boxRow = 0; boxRow < gridSize; boxRow += boxSize) {
      for (int boxCol = 0; boxCol < gridSize; boxCol += boxSize) {
        final seen = <int>{};

        for (int row = boxRow; row < boxRow + boxSize; row++) {
          for (int col = boxCol; col < boxCol + boxSize; col++) {
            final value = board[row][col];

            if (value != emptyValue && !seen.add(value)) {
              return false;
            }
          }
        }
      }
    }

    return true;
  }

  // ==========================================================================
  // SOLUTION MATCH
  // ==========================================================================

  /// Returns true when [board] is completely solved and exactly matches
  /// [solution].
  ///
  /// This is stricter than [isValidSolution].
  static bool matchesSolution(List<List<int>> board, List<List<int>> solution) {
    if (!_isValidBoardShape(board) || !_isValidBoardShape(solution)) {
      return false;
    }

    if (!isBoardComplete(board) || !isBoardComplete(solution)) {
      return false;
    }

    for (int row = 0; row < gridSize; row++) {
      for (int col = 0; col < gridSize; col++) {
        if (board[row][col] != solution[row][col]) {
          return false;
        }
      }
    }

    return true;
  }

  // ==========================================================================
  // BOARD STRUCTURE
  // ==========================================================================

  /// Validates the basic 9x9 board structure and value range.
  static bool _isValidBoardShape(List<List<int>> board) {
    if (board.length != gridSize) {
      return false;
    }

    for (final row in board) {
      if (row.length != gridSize) {
        return false;
      }

      for (final value in row) {
        if (value < emptyValue || value > maxValue) {
          return false;
        }
      }
    }

    return true;
  }

  static bool _isValidPosition(int row, int col) {
    return row >= 0 && row < gridSize && col >= 0 && col < gridSize;
  }
}
