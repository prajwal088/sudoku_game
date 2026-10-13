/// ============================================================================
/// SudokuBoard
/// ----------------------------------------------------------------------------
/// The game-board data model: the player's current grid, the original puzzle,
/// the solution and the map of fixed (given) cells.
///
/// - All grids are 9x9; 0 means an empty cell.
/// - [SudokuBoard.fromPuzzle] validates its input and takes its OWN copies,
///   so later changes to the lists a caller passed in can never corrupt the
///   board (and vice versa).
/// - Fixed cells can never be changed through [setNumber] / [clearCell].
/// ============================================================================
class SudokuBoard {
  /// Grid width/height.
  static const int size = 9;

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

  /// Factory constructor to build board from puzzle.
  ///
  /// Throws an [ArgumentError] when [puzzle] or [solution] is not a valid
  /// 9x9 grid (puzzle values 0-9, solution values 1-9), instead of failing
  /// later with an obscure index error or producing an unwinnable board.
  factory SudokuBoard.fromPuzzle(
    List<List<int>> puzzle,
    List<List<int>> solution,
  ) {
    _validateGrid(puzzle, name: 'puzzle', minValue: 0);
    _validateGrid(solution, name: 'solution', minValue: 1);

    final List<List<bool>> fixed = List<List<bool>>.generate(
      size,
      (int r) => List<bool>.generate(
        size,
        (int c) => puzzle[r][c] != 0,
        growable: false,
      ),
      growable: false,
    );

    return SudokuBoard(
      board: _copyGrid(puzzle),
      puzzle: _copyGrid(puzzle),
      solution: _copyGrid(solution),
      fixed: fixed,
    );
  }

  /// Reset board to original puzzle.
  ///
  /// Copies in place, so any reference to the existing grid stays valid.
  void reset() {
    for (int r = 0; r < size; r++) {
      board[r].setAll(0, puzzle[r]);
    }
  }

  /// Check if puzzle solved (every cell equals the stored solution).
  bool isSolved() {
    for (int r = 0; r < size; r++) {
      for (int c = 0; c < size; c++) {
        if (board[r][c] != solution[r][c]) {
          return false;
        }
      }
    }

    return true;
  }

  /// Set number in cell (0 clears it).
  ///
  /// Returns true when the cell was changed, false when it is a fixed cell
  /// (which is never modified). Existing callers can ignore the result.
  ///
  /// Throws a [RangeError] for an invalid cell and an [ArgumentError] when
  /// [value] is not between 0 and 9.
  bool setNumber(int row, int col, int value) {
    _checkCell(row, col);

    if (value < 0 || value > size) {
      throw ArgumentError.value(value, 'value', 'Must be between 0 and $size.');
    }

    if (fixed[row][col]) {
      return false;
    }

    board[row][col] = value;

    return true;
  }

  /// Clear cell.
  ///
  /// Returns true when the cell was changed, false when it is a fixed cell.
  bool clearCell(int row, int col) {
    return setNumber(row, col, 0);
  }

  /// Get hint value
  int getHint(int row, int col) {
    _checkCell(row, col);

    return solution[row][col];
  }

  @override
  String toString() {
    final StringBuffer buffer = StringBuffer('SudokuBoard(\n');

    for (final List<int> row in board) {
      buffer.writeln('  ${row.map((int v) => v == 0 ? '.' : '$v').join(' ')}');
    }

    buffer.write(')');

    return buffer.toString();
  }

  // ==========================================================================
  // HELPERS
  // ==========================================================================

  static void _checkCell(int row, int col) {
    if (row < 0 || row >= size) {
      throw RangeError.range(row, 0, size - 1, 'row');
    }

    if (col < 0 || col >= size) {
      throw RangeError.range(col, 0, size - 1, 'col');
    }
  }

  static List<List<int>> _copyGrid(List<List<int>> source) {
    return List<List<int>>.generate(
      size,
      (int r) => List<int>.from(source[r]),
      growable: false,
    );
  }

  static void _validateGrid(
    List<List<int>> grid, {
    required String name,
    required int minValue,
  }) {
    if (grid.length != size) {
      throw ArgumentError.value(
        grid.length,
        name,
        'Expected $size rows.',
      );
    }

    for (int r = 0; r < size; r++) {
      if (grid[r].length != size) {
        throw ArgumentError.value(
          grid[r].length,
          name,
          'Row $r must contain $size cells.',
        );
      }

      for (int c = 0; c < size; c++) {
        final int value = grid[r][c];

        if (value < minValue || value > size) {
          throw ArgumentError.value(
            value,
            name,
            'Invalid value at row $r, column $c '
                '(expected $minValue-$size).',
          );
        }
      }
    }
  }
}