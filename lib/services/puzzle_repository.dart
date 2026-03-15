import 'dart:math';

import '../logic/sudoku_solver.dart';

class PuzzleRepository {

/// Main function used by LevelService
Map<String, List<List<int>>> getPuzzleForLevel(int levelNumber) {

String difficulty = _getDifficulty(levelNumber);

Random random = Random(levelNumber); 
// deterministic puzzle per level

List<List<int>> solution = _generateSolvedBoard(random);

List<List<int>> puzzle = _createPuzzleFromSolution(
  solution,
  difficulty,
  random,
);

return {
  "puzzle": puzzle,
  "solution": solution,
};
}

/// Difficulty mapping
String _getDifficulty(int level) {

if (level <= 20) return "Easy";
if (level <= 60) return "Medium";
if (level <= 120) return "Hard";

return "Expert";
}

/// Generate a solved Sudoku board
List<List<int>> _generateSolvedBoard(Random random) {

List<List<int>> board =
    List.generate(9, (_) => List.filled(9, 0));

SudokuSolver.solve(board);

_shuffleBoard(board, random);

return board;
}

/// Shuffle rows/columns to create variety
void _shuffleBoard(List<List<int>> board, Random random) {

for (int i = 0; i < 20; i++) {

  int block = random.nextInt(3) * 3;

  int row1 = block + random.nextInt(3);
  int row2 = block + random.nextInt(3);

  var temp = board[row1];
  board[row1] = board[row2];
  board[row2] = temp;
}
}

/// Remove numbers based on difficulty
List<List<int>> _createPuzzleFromSolution(
List<List<int>> solution,
String difficulty,
Random random) {
List<List<int>> puzzle =
    solution.map((row) => List<int>.from(row)).toList();

int cellsToRemove;

switch (difficulty) {

  case "Easy":
    cellsToRemove = 35;
    break;

  case "Medium":
    cellsToRemove = 45;
    break;

  case "Hard":
    cellsToRemove = 55;
    break;

  default:
    cellsToRemove = 60;
}

int removed = 0;

while (removed < cellsToRemove) {

  int row = random.nextInt(9);
  int col = random.nextInt(9);

  if (puzzle[row][col] != 0) {

    puzzle[row][col] = 0;

    removed++;
  }
}

return puzzle;
}
}