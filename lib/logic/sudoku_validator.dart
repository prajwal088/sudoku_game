class SudokuValidator {

  static bool isValidMove(List<List<int>> board, int row, int col, int num) {

    for (int x = 0; x < 9; x++) {
      if (x != col && board[row][x] == num) return false;
      if (x != row && board[x][col] == num) return false;
    }

    int startRow = row - row % 3;
    int startCol = col - col % 3;

    for (int r = 0; r < 3; r++) {
      for (int c = 0; c < 3; c++) {

        int currentRow = startRow + r;
        int currentCol = startCol + c;

        if ((currentRow != row || currentCol != col) &&
            board[currentRow][currentCol] == num) {
          return false;
        }
      }
    }

    return true;
  }

  static bool isBoardComplete(List<List<int>> board) {

    for (int r = 0; r < 9; r++) {
      for (int c = 0; c < 9; c++) {

        int value = board[r][c];

        if (value == 0) return false;

        if (!isValidMove(board, r, c, value)) {
          return false;
        }
      }
    }

    return true;
  }
}