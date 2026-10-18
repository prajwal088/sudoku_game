/// ============================================================================
/// SudokuSolver
/// ----------------------------------------------------------------------------
/// High-performance Sudoku solving engine.
///
/// Responsibilities:
/// - Solve valid 9x9 Sudoku boards.
/// - Validate existing puzzle data before solving.
/// - Support deterministic solving.
/// - Support randomized solving for puzzle generation.
/// - Provide solved copies for hints/gameplay.
/// - Avoid modifying the caller's board except through [solve].
///
/// Architecture:
/// - The supplied board is mutated by [solve].
/// - [getSolvedBoard] never mutates the caller's board.
/// - Invalid board shapes/values return false instead of throwing during solve.
/// - Internally the search tracks used digits per row/column/box as bitmasks,
///   so candidate lookup is O(1) and the search allocates nothing per node.
///
/// IMPORTANT:
/// - [solve] returns true when a solution is found.
/// - [solve] returns false when the board is invalid or unsolvable. In that
///   case the board is left exactly as it was supplied.
/// - [solve] requires modifiable (growable or fixed-length) row lists; passing
///   `List.unmodifiable` rows will throw when a cell is written.
/// - A solved board is not necessarily a uniquely solvable puzzle.
///   Use [countSolutions] when uniqueness verification is required.
/// ============================================================================
library;

import 'dart:math' show Random;

class SudokuSolver {
  /// Not instantiable: this class only exposes static members.
  SudokuSolver._();

  static const int gridSize = 9;
  static const int boxSize = 3;
  static const int minValue = 1;
  static const int maxValue = 9;

  /// Maximum number of solutions needed when checking uniqueness.
  static const int _solutionSearchLimit = 2;

  /// Bitmask with one bit per digit (bit 0 = digit 1 ... bit 8 = digit 9).
  static const int _allDigitsMask = 0x1FF;

  /// Number of set bits for every possible 9-bit mask (candidate counts).
  static final List<int> _bitCounts = List<int>.generate(
    _allDigitsMask + 1,
    _countBits,
    growable: false,
  );

  static int _countBits(int value) {
    var count = 0;
    var remaining = value;
    while (remaining != 0) {
      remaining &= remaining - 1;
      count++;
    }
    return count;
  }

  // ==========================================================================
  // SOLVE
  // ==========================================================================

  /// Solves [board] in place.
  ///
  /// Returns:
  /// - true  -> a valid solution was found.
  /// - false -> the board is malformed, invalid, or unsolvable.
  ///
  /// When [randomize] is true, candidate numbers are shuffled before trying
  /// them. This is useful when generating different valid Sudoku solutions.
  /// Supply [random] (e.g. `Random(42)`) for reproducible results in tests or
  /// seeded puzzle generation; it is ignored when [randomize] is false.
  static bool solve(
    List<List<int>> board, {
    bool randomize = false,
    Random? random,
  }) {
    if (!_isValidBoardShape(board)) {
      return false;
    }

    final state = _SearchState.fromBoard(board);

    if (state == null) {
      return false;
    }

    final rng = randomize ? (random ?? Random()) : null;

    return _backtrack(state, rng);
  }

  // ==========================================================================
  // BACKTRACKING ENGINE
  // ==========================================================================

  /// Recursive solving engine using MRV (Minimum Remaining Values):
  ///
  /// Instead of blindly selecting the first empty cell, we select the empty
  /// cell with the fewest available candidates. This significantly reduces the
  /// search tree for difficult puzzles.
  static bool _backtrack(_SearchState state, Random? rng) {
    final index = _findBestEmptyCell(state);

    // No empty cells means the board is completely solved.
    if (index < 0) {
      return true;
    }

    final row = index ~/ gridSize;
    final col = index % gridSize;
    final mask = state.candidateMask(row, col);

    if (mask == 0) {
      return false;
    }

    if (rng != null) {
      final digits = _digitsFromMask(mask)..shuffle(rng);

      for (final digit in digits) {
        state.place(row, col, digit);

        if (_backtrack(state, rng)) {
          return true;
        }

        state.remove(row, col, digit);
      }

      return false;
    }

    for (var digit = minValue; digit <= maxValue; digit++) {
      if ((mask & (1 << (digit - 1))) == 0) {
        continue;
      }

      state.place(row, col, digit);

      if (_backtrack(state, rng)) {
        return true;
      }

      state.remove(row, col, digit);
    }

    return false;
  }

  // ==========================================================================
  // BEST CELL SELECTION
  // ==========================================================================

  /// Finds the empty cell with the fewest legal candidates.
  ///
  /// Returns `row * gridSize + col`, or -1 when there are no empty cells.
  /// A cell with zero candidates (dead end) is returned immediately so the
  /// caller can backtrack without scanning further.
  static int _findBestEmptyCell(_SearchState state) {
    var bestIndex = -1;
    var fewestCandidates = maxValue + 1;

    for (var row = 0; row < gridSize; row++) {
      final boardRow = state.board[row];

      for (var col = 0; col < gridSize; col++) {
        if (boardRow[col] != 0) {
          continue;
        }

        final count = _bitCounts[state.candidateMask(row, col)];

        if (count == 0) {
          return row * gridSize + col;
        }

        if (count < fewestCandidates) {
          fewestCandidates = count;
          bestIndex = row * gridSize + col;

          // No cell can have fewer than one candidate.
          if (count == 1) {
            return bestIndex;
          }
        }
      }
    }

    return bestIndex;
  }

  static List<int> _digitsFromMask(int mask) {
    final digits = <int>[];

    for (var digit = minValue; digit <= maxValue; digit++) {
      if ((mask & (1 << (digit - 1))) != 0) {
        digits.add(digit);
      }
    }

    return digits;
  }

  // ==========================================================================
  // SAFETY CHECK
  // ==========================================================================

  /// Returns whether [num] can legally be placed at [row], [col].
  ///
  /// The cell's own current value is ignored, so this can be used to validate
  /// a value that is already on the board.
  static bool isSafe(List<List<int>> board, int row, int col, int num) {
    if (!_isValidBoardShape(board)) {
      return false;
    }

    return _isSafeUnchecked(board, row, col, num);
  }

  /// Same as [isSafe] but assumes the board shape was already validated.
  static bool _isSafeUnchecked(
    List<List<int>> board,
    int row,
    int col,
    int num,
  ) {
    if (row < 0 ||
        row >= gridSize ||
        col < 0 ||
        col >= gridSize ||
        num < minValue ||
        num > maxValue) {
      return false;
    }

    // Row.
    for (var currentCol = 0; currentCol < gridSize; currentCol++) {
      if (currentCol != col && board[row][currentCol] == num) {
        return false;
      }
    }

    // Column.
    for (var currentRow = 0; currentRow < gridSize; currentRow++) {
      if (currentRow != row && board[currentRow][col] == num) {
        return false;
      }
    }

    // 3x3 box.
    final startRow = row - (row % boxSize);
    final startCol = col - (col % boxSize);

    for (var r = startRow; r < startRow + boxSize; r++) {
      for (var c = startCol; c < startCol + boxSize; c++) {
        if ((r != row || c != col) && board[r][c] == num) {
          return false;
        }
      }
    }

    return true;
  }

  // ==========================================================================
  // BOARD VALIDATION
  // ==========================================================================

  /// Validates that the supplied board is exactly 9x9 and contains only
  /// integers from 0 to 9.
  static bool _isValidBoardShape(List<List<int>> board) {
    if (board.length != gridSize) {
      return false;
    }

    for (final row in board) {
      if (row.length != gridSize) {
        return false;
      }

      for (final value in row) {
        if (value < 0 || value > maxValue) {
          return false;
        }
      }
    }

    return true;
  }

  // ==========================================================================
  // SOLVED COPY
  // ==========================================================================

  /// Returns a solved copy of [board].
  ///
  /// The original board is never modified.
  ///
  /// Returns null when the board is malformed, invalid, or unsolvable.
  static List<List<int>>? getSolvedBoard(List<List<int>> board) {
    if (!_isValidBoardShape(board)) {
      return null;
    }

    final copy = _cloneGrid(board);

    if (!solve(copy)) {
      return null;
    }

    return copy;
  }

  // ==========================================================================
  // SOLUTION CHECK
  // ==========================================================================

  /// Returns true when [board] is a completely solved valid Sudoku board.
  static bool isSolved(List<List<int>> board) {
    if (!_isValidBoardShape(board)) {
      return false;
    }

    for (final row in board) {
      for (final value in row) {
        if (value == 0) {
          return false;
        }
      }
    }

    // Every cell is filled; the board is solved only if it has no conflicts.
    return _SearchState.fromBoard(board) != null;
  }

  // ==========================================================================
  // SOLUTION COUNT / UNIQUENESS
  // ==========================================================================

  /// Returns the number of solutions found, up to [limit].
  ///
  /// By default, the search stops after finding two solutions because:
  ///
  /// - 0 = unsolvable
  /// - 1 = uniquely solvable
  /// - 2 = multiple solutions
  ///
  /// This is useful when validating generated puzzles. The caller's board is
  /// never modified.
  static int countSolutions(
    List<List<int>> board, {
    int limit = _solutionSearchLimit,
  }) {
    if (limit < 1) {
      throw ArgumentError.value(
        limit,
        'limit',
        'Solution limit must be at least 1.',
      );
    }

    if (!_isValidBoardShape(board)) {
      return 0;
    }

    // The search state works on its own copy of the grid.
    final state = _SearchState.fromBoard(_cloneGrid(board));

    if (state == null) {
      return 0;
    }

    return _countSolutions(state, limit);
  }

  static int _countSolutions(_SearchState state, int limit) {
    if (limit <= 0) {
      return 0;
    }

    final index = _findBestEmptyCell(state);

    if (index < 0) {
      return 1;
    }

    final row = index ~/ gridSize;
    final col = index % gridSize;
    final mask = state.candidateMask(row, col);

    if (mask == 0) {
      return 0;
    }

    var solutionCount = 0;

    for (var digit = minValue; digit <= maxValue; digit++) {
      if ((mask & (1 << (digit - 1))) == 0) {
        continue;
      }

      state.place(row, col, digit);
      solutionCount += _countSolutions(state, limit - solutionCount);
      state.remove(row, col, digit);

      if (solutionCount >= limit) {
        return limit;
      }
    }

    return solutionCount;
  }

  // ==========================================================================
  // COPY
  // ==========================================================================

  static List<List<int>> _cloneGrid(List<List<int>> source) {
    return List<List<int>>.generate(
      source.length,
      (row) => List<int>.from(source[row]),
      growable: false,
    );
  }
}

/// Mutable search state: the board plus bitmasks of digits already used in
/// each row, column and 3x3 box.
///
/// Bit `n - 1` of a mask is set when digit `n` is used.
class _SearchState {
  _SearchState._(this.board);

  final List<List<int>> board;
  final List<int> _rows = List<int>.filled(SudokuSolver.gridSize, 0);
  final List<int> _cols = List<int>.filled(SudokuSolver.gridSize, 0);
  final List<int> _boxes = List<int>.filled(SudokuSolver.gridSize, 0);

  /// Builds the state from [board] (which must already have a valid 9x9 shape
  /// with values 0-9). Returns null when the givens contain a duplicate in any
  /// row, column or box.
  static _SearchState? fromBoard(List<List<int>> board) {
    final state = _SearchState._(board);

    for (var row = 0; row < SudokuSolver.gridSize; row++) {
      for (var col = 0; col < SudokuSolver.gridSize; col++) {
        final value = board[row][col];

        if (value == 0) {
          continue;
        }

        final bit = 1 << (value - 1);
        final box = _boxIndex(row, col);

        if (((state._rows[row] | state._cols[col] | state._boxes[box]) & bit) !=
            0) {
          return null;
        }

        state._rows[row] |= bit;
        state._cols[col] |= bit;
        state._boxes[box] |= bit;
      }
    }

    return state;
  }

  static int _boxIndex(int row, int col) =>
      (row ~/ SudokuSolver.boxSize) * SudokuSolver.boxSize +
      (col ~/ SudokuSolver.boxSize);

  /// Bitmask of digits that may legally be placed at [row], [col].
  int candidateMask(int row, int col) {
    final used = _rows[row] | _cols[col] | _boxes[_boxIndex(row, col)];
    return ~used & SudokuSolver._allDigitsMask;
  }

  void place(int row, int col, int digit) {
    final bit = 1 << (digit - 1);
    board[row][col] = digit;
    _rows[row] |= bit;
    _cols[col] |= bit;
    _boxes[_boxIndex(row, col)] |= bit;
  }

  void remove(int row, int col, int digit) {
    final bit = ~(1 << (digit - 1));
    board[row][col] = 0;
    _rows[row] &= bit;
    _cols[col] &= bit;
    _boxes[_boxIndex(row, col)] &= bit;
  }
}