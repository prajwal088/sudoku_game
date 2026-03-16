import '../logic/sudoku_generator.dart';
import '../logic/sudoku_solver.dart';
import '../models/sudoku_board.dart';

class GameService {

  SudokuBoard newGame() {

    SudokuGenerator generator = SudokuGenerator();

    List<List<int>> puzzle = generator.generatePuzzle(45);

    // Copy puzzle to create solution board
    List<List<int>> solution =
        puzzle.map((row) => List<int>.from(row)).toList();

    // Solve puzzle
    SudokuSolver.solve(solution);

    // Fixed cells
    List<List<bool>> fixed =
        puzzle.map((row) => row.map((n) => n != 0).toList()).toList();

    return SudokuBoard(
      board: puzzle.map((row) => List<int>.from(row)).toList(),
      puzzle: puzzle,
      solution: solution,
      fixed: fixed,
    );
  }

}