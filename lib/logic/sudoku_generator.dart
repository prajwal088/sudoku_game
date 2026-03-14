import 'dart:math';

class SudokuGenerator {
  List<List<int>> board = List.generate(9, (_) => List.filled(9, 0));

  /// Check if a number can be placed safely
  bool isSafe(int row, int col, int num) {
    for (int x = 0; x < 9; x++) {
      if (board[row][x] == num ||
          board[x][col] == num ||
          board[row - row % 3 + x ~/ 3][col - col % 3 + x % 3] == num) {
        return false;
      }
    }
    return true;
  }

  /// Fill the board using backtracking
  bool fillBoard() {
    for (int row = 0; row < 9; row++) {
      for (int col = 0; col < 9; col++) {
        if (board[row][col] == 0) {
          List<int> numbers = List.generate(9, (i) => i + 1)..shuffle();

          for (int num in numbers) {
            if (isSafe(row, col, num)) {
              board[row][col] = num;

              if (fillBoard()) {
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

  /// Generate a fully solved Sudoku board
  List<List<int>> generateSolvedBoard() {
    board = List.generate(9, (_) => List.filled(9, 0)); // reset board
    fillBoard();

    // Return deep copy
    return board.map((row) => List<int>.from(row)).toList();
  }

  /// Generate puzzle by removing numbers
  List<List<int>> generatePuzzle(int removeCount) {
    board = generateSolvedBoard();

    List<List<int>> puzzle =
        board.map((row) => List<int>.from(row)).toList();

    Random rand = Random();

    while (removeCount > 0) {
      int row = rand.nextInt(9);
      int col = rand.nextInt(9);

      if (puzzle[row][col] != 0) {
        puzzle[row][col] = 0;
        removeCount--;
      }
    }

    return puzzle;
  }
}