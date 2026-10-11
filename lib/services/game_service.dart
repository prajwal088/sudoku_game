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
/// - Verify the solution is a valid, complete Sudoku that agrees with the
///   puzzle's clues.
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
/// Performance note:
/// Generation and solving are CPU-bound and run synchronously. For high empty
/// cell counts this can take noticeable time, so avoid calling [newGame]
/// repeatedly inside a single frame (for example once per level in a loop).
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

  /// Maximum number of empty cells accepted by this service.
  ///
  /// This only rejects obviously invalid input. Note that a 9x9 Sudoku needs
  /// at least 17 clues to have a unique solution (at most 64 empty cells), so
  /// values above 64 can only produce puzzles with multiple solutions. The
  /// campaign uses far fewer.
  static const int maxEmptyCells = 80;

  static const int _gridSize = 9;
  static const int _boxSize = 3;

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
  /// Every grid in the returned board is an independent list structure, so
  /// mutating one never affects the others.
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

    final List<List<int>> puzzle = _generator.generatePuzzle(emptyCells);

    _validateGrid(puzzle, name: 'Generated puzzle');
    _validateHasEmptyCell(puzzle);

    // ------------------------------------------------------------------------
    // SOLVE PUZZLE
    // ------------------------------------------------------------------------
    //
    // Never pass the original puzzle to the solver.
    //
    // The solver mutates the supplied grid, so solving a clone protects the
    // original puzzle used by the player. This clone is exclusively owned by
    // this method, so it is returned directly as the solution (no extra copy).
    //

    final List<List<int>> solution = _cloneGrid(puzzle);

    final bool solved = SudokuSolver.solve(solution);

    if (!solved) {
      throw StateError(
        'Sudoku engine error: generated puzzle is not solvable.',
      );
    }

    _validateSolvedGrid(solution);
    _validateSolutionMatchesPuzzle(puzzle, solution);

    // ------------------------------------------------------------------------
    // RETURN INDEPENDENT BOARD
    // ------------------------------------------------------------------------
    //
    // - board / puzzle : separate clones, because the generator may keep a
    //   reference to the list it returned.
    // - solution       : exclusively owned (see above).
    // - fixed          : freshly built here, so it needs no further copy.
    //

    return SudokuBoard(
      board: _cloneGrid(puzzle),
      puzzle: _cloneGrid(puzzle),
      solution: solution,
      fixed: _buildFixedGrid(puzzle),
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
        final int value = grid[row][col];

        if (value < 0 || value > _gridSize) {
          throw StateError(
            '$name contains invalid value $value at '
            'row $row, column $col.',
          );
        }
      }
    }
  }

  /// A puzzle with no empty cell is already solved and not playable.
  void _validateHasEmptyCell(List<List<int>> puzzle) {
    for (final List<int> row in puzzle) {
      if (row.contains(0)) {
        return;
      }
    }

    throw StateError(
      'Sudoku engine error: generated puzzle has no empty cells.',
    );
  }

  /// Ensures the solver returned a complete valid Sudoku grid.
  ///
  /// This deliberately validates the result here rather than assuming the
  /// solver implementation is always correct.
  ///
  /// Uses one pass with bitmasks (one int per row, column and box) instead
  /// of allocating a Set for each of the 27 units.
  void _validateSolvedGrid(List<List<int>> solution) {
    _validateGrid(solution, name: 'Generated solution');

    final List<int> rows = List<int>.filled(_gridSize, 0);
    final List<int> cols = List<int>.filled(_gridSize, 0);
    final List<int> boxes = List<int>.filled(_gridSize, 0);

    for (int row = 0; row < _gridSize; row++) {
      for (int col = 0; col < _gridSize; col++) {
        final int value = solution[row][col];

        if (value < 1 || value > _gridSize) {
          throw StateError(
            'Generated solution contains an empty or invalid cell at '
            'row $row, column $col.',
          );
        }

        final int bit = 1 << value;
        final int boxRow = (row ~/ _boxSize) * _boxSize;
        final int boxCol = (col ~/ _boxSize) * _boxSize;
        final int boxIndex = (boxRow ~/ _boxSize) * _boxSize + (col ~/ _boxSize);

        if ((rows[row] & bit) != 0) {
          throw StateError(
            'Generated solution contains duplicate values in row $row.',
          );
        }

        if ((cols[col] & bit) != 0) {
          throw StateError(
            'Generated solution contains duplicate values in column $col.',
          );
        }

        if ((boxes[boxIndex] & bit) != 0) {
          throw StateError(
            'Generated solution contains duplicate values in '
            'the $boxRow,$boxCol 3x3 box.',
          );
        }

        rows[row] |= bit;
        cols[col] |= bit;
        boxes[boxIndex] |= bit;
      }
    }
  }

  /// Ensures every given clue is preserved by the solution.
  ///
  /// Guards against a solver that overwrites clues, which would otherwise
  /// produce a puzzle whose "solution" contradicts what the player sees.
  void _validateSolutionMatchesPuzzle(
    List<List<int>> puzzle,
    List<List<int>> solution,
  ) {
    for (int row = 0; row < _gridSize; row++) {
      for (int col = 0; col < _gridSize; col++) {
        final int clue = puzzle[row][col];

        if (clue != 0 && clue != solution[row][col]) {
          throw StateError(
            'Sudoku engine error: solution does not match puzzle clue at '
            'row $row, column $col.',
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
      (int row) => List<bool>.generate(
        _gridSize,
        (int col) => puzzle[row][col] != 0,
        growable: false,
      ),
      growable: false,
    );
  }

  // ==========================================================================
  // GRID COPY HELPERS
  // ==========================================================================

  /// Creates a deep copy of a Sudoku integer grid.
  List<List<int>> _cloneGrid(List<List<int>> source) {
    return source
        .map((List<int> row) => List<int>.from(row, growable: false))
        .toList(growable: false);
  }
}