class SudokuValidator {
  /// Checks if a number can be placed in a cell based on standard Sudoku rules.
  /// [excludeSelf] should be true when validating a board that already contains the [num].
  static bool isValidMove(
    List<List<int>> board, 
    int row, 
    int col, 
    int num, 
    {bool excludeSelf = true}
  ) {
    if (num == 0) return true;

    // Check Row and Column simultaneously
    for (int i = 0; i < 9; i++) {
      // Row check
      if (board[row][i] == num && (excludeSelf ? i != col : true)) return false;
      // Column check
      if (board[i][col] == num && (excludeSelf ? i != row : true)) return false;
    }

    // Check 3x3 Box
    int startRow = (row ~/ 3) * 3;
    int startCol = (col ~/ 3) * 3;

    for (int r = startRow; r < startRow + 3; r++) {
      for (int c = startCol; c < startCol + 3; c++) {
        if (board[r][c] == num) {
          if (excludeSelf && r == row && c == col) continue;
          return false;
        }
      }
    }

    return true;
  }

  /// Checks if the current board state matches the pre-generated solution.
  /// Use this for real-time "Mistake" tracking.
  static bool isValidSolution(List<List<int>> currentBoard, List<List<int>> solution) {
    for (int r = 0; r < 9; r++) {
      for (int c = 0; c < 9; c++) {
        if (currentBoard[r][c] != 0 && currentBoard[r][c] != solution[r][c]) {
          return false;
        }
      }
    }
    return true;
  }

  /// Checks if every cell is filled and follows Sudoku rules.
  static bool isBoardComplete(List<List<int>> board) {
    for (int r = 0; r < 9; r++) {
      for (int c = 0; c < 9; c++) {
        int value = board[r][c];
        
        // If any cell is empty, the board is not complete
        if (value == 0) return false;

        // If any cell violates Sudoku rules
        if (!isValidMove(board, r, c, value, excludeSelf: true)) {
          return false;
        }
      }
    }
    return true;
  }
}