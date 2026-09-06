import '../logic/sudoku_generator.dart';
import '../logic/sudoku_solver.dart';
import '../models/sudoku_board.dart';

/// ============================================================================
/// GameService
/// ----------------------------------------------------------------------------
/// Responsible for creating playable Sudoku games.
///
/// Responsibilities:
/// - Generate a new Sudoku puzzle.
/// - Validate the generated puzzle.
/// - Solve a copy to obtain the solution.
/// - Build the fixed-cell map.
/// - Return an independent [SudokuBoard].
///
/// Architecture:
/// - GameService owns game-generation orchestration.
/// - SudokuGenerator owns puzzle generation.
/// - SudokuSolver owns solving.
/// - SudokuBoard owns the game-board data model.
///
/// The service does not persist game progress. That responsibility belongs to
/// ProgressService.
///
/// Example:
///
/// final gameService = GameService();
/// final board = gameService.newGame();
/// ============================================================================

class GameService {
  // ==========================================================================
  // CONFIGURATION
  // ==========================================================================

  /// Default number of empty cells in a generated puzzle.
  static const int defaultEmptyCells = 40;

  /// Minimum number of empty cells supported by this service.
  ///
  /// A generated Sudoku must contain at least one empty cell to be considered
  /// a new playable puzzle.
  static const int minEmptyCells = 1;

  /// Maximum number of empty cells allowed for a standard 9x9 Sudoku.
  ///
  /// The exact practical difficulty depends on the generator implementation,
  /// but this prevents obviously invalid input from reaching the generator.
  static const int maxEmptyCells = 80;

  static const int _gridSize = 9;

  // ==========================================================================
  // DEPENDENCIES
  // ==========================================================================

  final SudokuGenerator _generator;

  /// Creates a GameService.
  ///
  /// [generator] is optional so production code can use the default generator
  /// while tests can inject a deterministic/fake implementation if the
  /// generator API supports it.
  GameService({SudokuGenerator? generator})
    : _generator = generator ?? SudokuGenerator();

  // ==========================================================================
  // NEW GAME
  // ==========================================================================

  /// Generates a new random Sudoku game.
  ///
  /// The returned [SudokuBoard] contains:
  /// - [SudokuBoard.board]   -> current player state
  /// - [SudokuBoard.puzzle]  -> original puzzle
  /// - [SudokuBoard.solution] -> solved puzzle
  /// - [SudokuBoard.fixed]   -> cells that cannot be edited
  ///
  /// Throws [ArgumentError] when [emptyCells] is outside the supported range.
  ///
  /// Throws [StateError] when the Sudoku engine produces an invalid or
  /// unsolvable puzzle.
  SudokuBoard newGame({int emptyCells = defaultEmptyCells}) {
    _validateEmptyCells(emptyCells);

    // ------------------------------------------------------------------------
    // GENERATE PUZZLE
    // ------------------------------------------------------------------------

    final puzzle = _generator.generatePuzzle(emptyCells);

    _validateGrid(puzzle, name: 'Generated puzzle');

    // ------------------------------------------------------------------------
    // SOLVE PUZZLE
    // ------------------------------------------------------------------------
    //
    // Never pass the original puzzle to the solver.
    //
    // The solver mutates the supplied grid, so solving a clone protects the
    // original puzzle used by the player.
    //

    final solution = _cloneGrid(puzzle);

    final solved = SudokuSolver.solve(solution);

    if (!solved) {
      throw StateError(
        'Sudoku engine error: generated puzzle is not solvable.',
      );
    }

    _validateSolvedGrid(solution);

    // ------------------------------------------------------------------------
    // FIXED CELLS
    // ------------------------------------------------------------------------

    final fixed = _buildFixedGrid(puzzle);

    // ------------------------------------------------------------------------
    // RETURN INDEPENDENT BOARD
    // ------------------------------------------------------------------------
    //
    // Each mutable grid gets its own list structure. This prevents accidental
    // mutations from leaking between board, puzzle, and solution.
    //

    return SudokuBoard(
      board: _cloneGrid(puzzle),
      puzzle: _cloneGrid(puzzle),
      solution: _cloneGrid(solution),
      fixed: _cloneBoolGrid(fixed),
    );
  }

  // ==========================================================================
  // VALIDATION
  // ==========================================================================

  void _validateEmptyCells(int emptyCells) {
    if (emptyCells < minEmptyCells || emptyCells > maxEmptyCells) {
      throw ArgumentError.value(
        emptyCells,
        'emptyCells',
        'emptyCells must be between '
            '$minEmptyCells and $maxEmptyCells.',
      );
    }
  }

  /// Validates that a generated grid has the expected 9x9 structure and
  /// contains only legal Sudoku cell values.
  void _validateGrid(List<List<int>> grid, {required String name}) {
    if (grid.length != _gridSize) {
      throw StateError('$name must contain exactly $_gridSize rows.');
    }

    for (int row = 0; row < _gridSize; row++) {
      if (grid[row].length != _gridSize) {
        throw StateError(
          '$name row $row must contain exactly $_gridSize cells.',
        );
      }

      for (int col = 0; col < _gridSize; col++) {
        final value = grid[row][col];

        if (value < 0 || value > _gridSize) {
          throw StateError(
            '$name contains invalid value $value at '
            'row $row, column $col.',
          );
        }
      }
    }
  }

  /// Ensures the solver returned a complete valid Sudoku grid.
  ///
  /// This deliberately validates the structural result here rather than
  /// assuming the solver implementation is always correct.
  void _validateSolvedGrid(List<List<int>> solution) {
    _validateGrid(solution, name: 'Generated solution');

    for (int row = 0; row < _gridSize; row++) {
      final values = <int>{};

      for (int col = 0; col < _gridSize; col++) {
        final value = solution[row][col];

        if (value < 1 || value > _gridSize) {
          throw StateError(
            'Generated solution contains an empty or invalid cell at '
            'row $row, column $col.',
          );
        }

        values.add(value);
      }

      if (values.length != _gridSize) {
        throw StateError(
          'Generated solution contains duplicate values in row $row.',
        );
      }
    }

    for (int col = 0; col < _gridSize; col++) {
      final values = <int>{};

      for (int row = 0; row < _gridSize; row++) {
        values.add(solution[row][col]);
      }

      if (values.length != _gridSize) {
        throw StateError(
          'Generated solution contains duplicate values in column $col.',
        );
      }
    }

    for (int boxRow = 0; boxRow < _gridSize; boxRow += 3) {
      for (int boxCol = 0; boxCol < _gridSize; boxCol += 3) {
        final values = <int>{};

        for (int row = boxRow; row < boxRow + 3; row++) {
          for (int col = boxCol; col < boxCol + 3; col++) {
            values.add(solution[row][col]);
          }
        }

        if (values.length != _gridSize) {
          throw StateError(
            'Generated solution contains duplicate values in '
            'the $boxRow,$boxCol 3x3 box.',
          );
        }
      }
    }
  }

  // ==========================================================================
  // FIXED GRID
  // ==========================================================================

  List<List<bool>> _buildFixedGrid(List<List<int>> puzzle) {
    return List<List<bool>>.generate(
      _gridSize,
      (row) => List<bool>.generate(_gridSize, (col) => puzzle[row][col] != 0),
    );
  }

  // ==========================================================================
  // GRID COPY HELPERS
  // ==========================================================================

  /// Creates a deep copy of a Sudoku integer grid.
  List<List<int>> _cloneGrid(List<List<int>> source) {
    return source.map((row) => List<int>.from(row)).toList(growable: false);
  }

  /// Creates a deep copy of a Sudoku boolean grid.
  List<List<bool>> _cloneBoolGrid(List<List<bool>> source) {
    return source.map((row) => List<bool>.from(row)).toList(growable: false);
  }
}
