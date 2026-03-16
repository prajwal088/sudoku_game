class SudokuBoard {

/// Current player board
List<List<int>> board;

/// Original puzzle
List<List<int>> puzzle;

/// Solved board
List<List<int>> solution;

/// Fixed cells (cannot edit)
List<List<bool>> fixed;

SudokuBoard({
required this.board,
required this.puzzle,
required this.solution,
required this.fixed,
});

/// Factory constructor to build board from puzzle
factory SudokuBoard.fromPuzzle(
List<List<int>> puzzle,
List<List<int>> solution,
) {

List<List<int>> board =
    puzzle.map((row) => List<int>.from(row)).toList();

List<List<bool>> fixed = List.generate(
  9,
  (r) => List.generate(
    9,
    (c) => puzzle[r][c] != 0,
  ),
);

return SudokuBoard(
  board: board,
  puzzle: puzzle,
  solution: solution,
  fixed: fixed,
);
}

/// Reset board to original puzzle
void reset() {

board = puzzle
    .map((row) => List<int>.from(row))
    .toList();
}

/// Check if puzzle solved
bool isSolved() {

for (int r = 0; r < 9; r++) {

  for (int c = 0; c < 9; c++) {

    if (board[r][c] != solution[r][c]) {
      return false;
    }
  }
}

return true;
}

/// Set number in cell
void setNumber(int row, int col, int value) {

if (!fixed[row][col]) {
  board[row][col] = value;
}
}

/// Clear cell
void clearCell(int row, int col) {

if (!fixed[row][col]) {
  board[row][col] = 0;
}
}

/// Get hint value
int getHint(int row, int col) {
return solution[row][col];
}
}