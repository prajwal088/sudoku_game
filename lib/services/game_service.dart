import '../logic/sudoku_generator.dart';
import '../logic/sudoku_solver.dart';
import '../models/sudoku_board.dart';

/// ============================================================================
/// GameService
/// ----------------------------------------------------------------------------
/// Responsible for creating a new Sudoku game instance.
///
/// Responsibilities:
/// - Generate puzzle using SudokuGenerator
/// - Solve puzzle to create solution reference
/// - Identify fixed (immutable) cells
/// - Return a fully initialized SudokuBoard
///
/// Notes:
/// - Ensures deep copies to prevent unintended mutation
/// - Handles solver failure safely
/// - Easily extendable for difficulty levels
/// ============================================================================

class GameService {

  /// Default empty cells (difficulty control)
  /// Higher value = harder puzzle
  static const int _defaultEmptyCells = 45;

  /// ==========================================================================
  /// CREATE NEW GAME
  /// ==========================================================================
  /// Returns a fully initialized SudokuBoard
  ///
  /// Steps:
  /// 1. Generate puzzle
  /// 2. Clone puzzle → solution board
  /// 3. Solve solution
  /// 4. Identify fixed cells
  /// ==========================================================================
  SudokuBoard newGame({int emptyCells = _defaultEmptyCells}) {

    final SudokuGenerator generator = SudokuGenerator();

    /// Step 1: Generate puzzle
    final List<List<int>> puzzle = generator.generatePuzzle(emptyCells);

    /// Step 2: Deep copy for solution
    final List<List<int>> solution =
        puzzle.map((row) => List<int>.from(row)).toList();

    /// Step 3: Solve puzzle (critical step)
    final bool solved = SudokuSolver.solve(solution);

    if (!solved) {
      /// 🚨 Production safety: generator/solver mismatch
      throw Exception("Failed to solve generated Sudoku puzzle");
    }

    /// Step 4: Identify fixed cells (immutable cells)
    final List<List<bool>> fixed = puzzle
        .map((row) => row.map((cell) => cell != 0).toList())
        .toList();

    /// Step 5: Return board (deep copies to avoid mutation bugs)
    return SudokuBoard(
      board: puzzle.map((row) => List<int>.from(row)).toList(),
      puzzle: puzzle.map((row) => List<int>.from(row)).toList(),
      solution: solution,
      fixed: fixed,
    );
  }
}