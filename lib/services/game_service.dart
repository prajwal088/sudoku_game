import '../logic/sudoku_generator.dart';
import '../models/sudoku_board.dart';

class GameService {
  SudokuBoard newGame() {
    SudokuGenerator generator = SudokuGenerator();

    List<List<int>> puzzle = generator.generatePuzzle(45);

    List<List<bool>> fixed =
        puzzle.map((row) => row.map((n) => n != 0).toList()).toList();

    return SudokuBoard(puzzle, fixed);
  }
}