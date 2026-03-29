import '../logic/sudoku_generator.dart';
import '../logic/sudoku_solver.dart';
import '../models/sudoku_board.dart';

class GameService {
  static const int _defaultEmptyCells = 40;

  /// Generates a board from scratch (Random Play)
  SudokuBoard newGame({int emptyCells = _defaultEmptyCells}) {
    final SudokuGenerator generator = SudokuGenerator();

    // 1. Generate the raw grid
    final List<List<int>> puzzle = generator.generatePuzzle(emptyCells);

    // 2. Create a solution by solving a copy of the puzzle
    final List<List<int>> solutionCopy = _cloneGrid(puzzle);
    final bool solved = SudokuSolver.solve(solutionCopy);

    if (!solved) {
      throw Exception("Sudoku Engine Error: Generated an unsolvable puzzle.");
    }

    // 3. Define which cells are fixed (not zero)
    final List<List<bool>> fixed = puzzle
        .map((row) => row.map((cell) => cell != 0).toList())
        .toList();

    return SudokuBoard(
      board: _cloneGrid(puzzle),
      puzzle: _cloneGrid(puzzle),
      solution: solutionCopy,
      fixed: fixed,
    );
  }

  /// Deep copy utility to prevent reference pointer bugs
  List<List<int>> _cloneGrid(List<List<int>> source) {
    return source.map((row) => List<int>.from(row)).toList();
  }
}