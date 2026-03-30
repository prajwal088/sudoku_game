class SudokuSolver {
  /// Entry point for solving a board.
  /// [randomize]: Set to true for generating new puzzles.
  static bool solve(List<List<int>> board, {bool randomize = false}) {
    // 1. GUARD CLAUSE: Check if the existing numbers already break the rules.
    // This prevents the "State Space Explosion" that causes hangs.
    if (!_isInitialBoardValid(board)) return false;

    // 2. START THE ENGINE
    return _backtrack(board, randomize);
  }

  /// The core recursive backtracking algorithm.
  static bool _backtrack(List<List<int>> board, bool randomize) {
    for (int row = 0; row < 9; row++) {
      for (int col = 0; col < 9; col++) {
        // Find the next empty cell
        if (board[row][col] == 0) {
          List<int> numbers = List.generate(9, (i) => i + 1);
          if (randomize) numbers.shuffle();

          for (int num in numbers) {
            if (isSafe(board, row, col, num)) {
              board[row][col] = num;

              // Recursive step
              if (_backtrack(board, randomize)) return true;

              // Backtrack: if the path failed, reset and try the next number
              board[row][col] = 0;
            }
          }
          return false; // No numbers 1-9 worked here; go back and change previous cell
        }
      }
    }
    return true; // All cells filled correctly
  }

  /// Checks if [num] is valid at [row], [col] based on Sudoku rules.
  static bool isSafe(List<List<int>> board, int row, int col, int num) {
    // Check row and column in one loop for efficiency
    for (int i = 0; i < 9; i++) {
      if (board[row][i] == num || board[i][col] == num) return false;
    }

    // Check 3x3 box
    int startRow = row - row % 3;
    int startCol = col - col % 3;
    for (int i = 0; i < 3; i++) {
      for (int j = 0; j < 3; j++) {
        if (board[startRow + i][startCol + j] == num) return false;
      }
    }
    return true;
  }

  /// Scans the board for existing conflicts before solving starts.
  static bool _isInitialBoardValid(List<List<int>> board) {
    for (int r = 0; r < 9; r++) {
      for (int c = 0; c < 9; c++) {
        if (board[r][c] != 0) {
          int val = board[r][c];
          board[r][c] = 0; // Temporarily clear to avoid self-conflict
          bool safe = isSafe(board, r, c, val);
          board[r][c] = val; // Restore
          if (!safe) return false; // Found an illegal starting position
        }
      }
    }
    return true;
  }

  /// Helper to get a solved copy (perfect for the hint system).
  static List<List<int>> getSolvedBoard(List<List<int>> board) {
    List<List<int>> copy = board.map((row) => List<int>.from(row)).toList();
    solve(copy, randomize: false);
    return copy;
  }
}

/// ============================================================================
/// SudokuSolver
/// ----------------------------------------------------------------------------
/// A high-performance Sudoku solving engine using recursive backtracking.
/// 
/// Features:
/// - Deterministic and Randomized solving modes.
/// - Validation logic for row, column, and 3x3 grid constraints.
/// - Defensive copying for "hint" generation.
/// ============================================================================