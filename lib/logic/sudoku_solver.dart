class SudokuSolver {

  /// Solve the Sudoku board using backtracking
  static bool solve(List<List<int>> board) {

    for (int row = 0; row < 9; row++) {
      for (int col = 0; col < 9; col++) {

        if (board[row][col] == 0) {

          for (int num = 1; num <= 9; num++) {

            if (isSafe(board, row, col, num)) {

              board[row][col] = num;

              if (solve(board)) {
                return true;
              }

              board[row][col] = 0;
            }
          }

          return false;
        }
      }
    }

    return true;
  }

  /// Check if a number placement is valid
  static bool isSafe(List<List<int>> board, int row, int col, int num) {

    return !usedInRow(board, row, num) &&
        !usedInCol(board, col, num) &&
        !usedInBox(board, row - row % 3, col - col % 3, num);
  }

  /// Check row
  static bool usedInRow(List<List<int>> board, int row, int num) {

    for (int col = 0; col < 9; col++) {
      if (board[row][col] == num) {
        return true;
      }
    }

    return false;
  }

  /// Check column
  static bool usedInCol(List<List<int>> board, int col, int num) {

    for (int row = 0; row < 9; row++) {
      if (board[row][col] == num) {
        return true;
      }
    }

    return false;
  }

  /// Check 3x3 box
  static bool usedInBox(
      List<List<int>> board, int startRow, int startCol, int num) {

    for (int r = 0; r < 3; r++) {
      for (int c = 0; c < 3; c++) {

        if (board[startRow + r][startCol + c] == num) {
          return true;
        }
      }
    }

    return false;
  }

  /// Returns a solved copy of the board (used for hints)
  static List<List<int>> getSolvedBoard(List<List<int>> board) {

    List<List<int>> copy =
        board.map((row) => List<int>.from(row)).toList();

    solve(copy);

    return copy;
  }
}