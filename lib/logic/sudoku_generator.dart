import 'dart:math';
import 'dart:typed_data';

/// ============================================================================
/// SudokuGenerator
/// ----------------------------------------------------------------------------
/// Generates valid 9x9 Sudoku boards and puzzles.
///
/// Responsibilities:
/// - Generate a complete valid Sudoku solution.
/// - Generate a puzzle by removing values from a solution.
/// - Optionally guarantee the puzzle has exactly one solution.
/// - Validate generation parameters.
/// - Keep generated state private to prevent accidental external mutation.
///
/// Design:
/// - Uses randomized backtracking.
/// - Supports an optional Random instance for deterministic generation.
/// - Returns deep copies from all public methods.
/// - Does not depend on SudokuSolver, avoiding circular responsibilities.
///
/// DETERMINISM CONTRACT (default mode):
/// With a seeded [Random], `generateSolvedBoard()` and
/// `generatePuzzle(n)` return the same grids as before. The board is filled
/// in row-major order, a fresh [1..9] list is shuffled per cell, and the
/// removal order is shuffled afterwards. Speed-ups (bitmasks) keep that order
/// exactly, so do not reorder the random calls.
///
/// IMPORTANT:
/// - By default this class generates valid Sudoku boards but does NOT
///   guarantee a puzzle has exactly one solution (blind clue removal).
/// - Pass `ensureUnique: true` to [generatePuzzle] when exactly one solution
///   is required. It is slower and limited to [maxUniqueRemovableCells].
/// ============================================================================

class SudokuGenerator {
  static const int gridSize = 9;
  static const int boxSize = 3;
  static const int minValue = 1;
  static const int maxValue = 9;

  /// Maximum number of cells that can be removed from a solved Sudoku.
  static const int maxRemovableCells = 81;

  /// With `ensureUnique: true`, at most this many cells can be removed: a
  /// 9x9 Sudoku needs at least 17 clues to have a unique solution.
  static const int maxUniqueRemovableCells = 64;

  /// How many fresh solutions are tried when unique removal cannot reach the
  /// requested count.
  static const int _maxUniqueAttempts = 30;

  static const int _cellCount = gridSize * gridSize;

  /// Random source used by this generator.
  final Random _random;

  /// Internal mutable board.
  List<List<int>> _board = _createEmptyBoard();

  /// Bitmasks (bit v set = value v used) for each row, column and box of
  /// [_board], kept in sync during generation for O(1) candidate checks.
  final Uint16List _rowMasks = Uint16List(gridSize);
  final Uint16List _colMasks = Uint16List(gridSize);
  final Uint16List _boxMasks = Uint16List(gridSize);

  /// Creates a generator.
  ///
  /// Pass a seeded [Random] when deterministic generation is required.
  ///
  /// Example:
  /// ```dart
  /// final generator = SudokuGenerator(Random(123));
  /// ```
  SudokuGenerator([Random? random]) : _random = random ?? Random();

  // ==========================================================================
  // BOARD CREATION
  // ==========================================================================

  static List<List<int>> _createEmptyBoard() {
    return List<List<int>>.generate(
      gridSize,
      (_) => List<int>.filled(gridSize, 0),
      growable: false,
    );
  }

  static List<List<int>> _cloneGrid(List<List<int>> source) {
    return List<List<int>>.generate(
      source.length,
      (row) => List<int>.from(source[row]),
      growable: false,
    );
  }

  static int _boxIndex(int row, int col) {
    return ((row ~/ boxSize) * boxSize) + (col ~/ boxSize);
  }

  // ==========================================================================
  // VALIDATION
  // ==========================================================================

  /// Returns true when [row], [col], and [value] are valid Sudoku
  /// coordinates.
  bool _isValidPosition(int row, int col, int value) {
    return row >= 0 &&
        row < gridSize &&
        col >= 0 &&
        col < gridSize &&
        value >= minValue &&
        value <= maxValue;
  }

  /// Checks whether [value] can safely be placed at [row], [col].
  ///
  /// This method operates against the generator's current internal board
  /// and ignores the cell's own current content.
  bool isSafe(int row, int col, int value) {
    if (!_isValidPosition(row, col, value)) {
      return false;
    }

    // ------------------------------------------------------------------------
    // ROW
    // ------------------------------------------------------------------------

    for (int currentCol = 0; currentCol < gridSize; currentCol++) {
      if (currentCol != col && _board[row][currentCol] == value) {
        return false;
      }
    }

    // ------------------------------------------------------------------------
    // COLUMN
    // ------------------------------------------------------------------------

    for (int currentRow = 0; currentRow < gridSize; currentRow++) {
      if (currentRow != row && _board[currentRow][col] == value) {
        return false;
      }
    }

    // ------------------------------------------------------------------------
    // 3x3 BOX
    // ------------------------------------------------------------------------

    final boxStartRow = row - (row % boxSize);
    final boxStartCol = col - (col % boxSize);

    for (
      int currentRow = boxStartRow;
      currentRow < boxStartRow + boxSize;
      currentRow++
    ) {
      for (
        int currentCol = boxStartCol;
        currentCol < boxStartCol + boxSize;
        currentCol++
      ) {
        if ((currentRow != row || currentCol != col) &&
            _board[currentRow][currentCol] == value) {
          return false;
        }
      }
    }

    return true;
  }

  // ==========================================================================
  // SOLUTION GENERATION
  // ==========================================================================

  /// Generates a complete, valid Sudoku solution.
  ///
  /// Every returned cell contains a value from 1 to 9.
  List<List<int>> generateSolvedBoard() {
    _board = _createEmptyBoard();

    _rowMasks.fillRange(0, gridSize, 0);
    _colMasks.fillRange(0, gridSize, 0);
    _boxMasks.fillRange(0, gridSize, 0);

    final solved = _fillCell(0);

    if (!solved) {
      // This should be practically unreachable with an empty 9x9 board.
      throw StateError('Failed to generate a valid Sudoku solution.');
    }

    return _cloneGrid(_board);
  }

  void _place(int row, int col, int value) {
    final int bit = 1 << value;

    _board[row][col] = value;
    _rowMasks[row] |= bit;
    _colMasks[col] |= bit;
    _boxMasks[_boxIndex(row, col)] |= bit;
  }

  void _unplace(int row, int col, int value) {
    final int bit = 1 << value;

    _board[row][col] = 0;
    _rowMasks[row] &= ~bit;
    _colMasks[col] &= ~bit;
    _boxMasks[_boxIndex(row, col)] &= ~bit;
  }

  /// Backtracking fill, one cell at a time in row-major order.
  ///
  /// The board starts empty and is filled in order, so the first empty cell
  /// is always [index]; there is no need to search for it.
  bool _fillCell(int index) {
    // Past the last cell means the board is complete.
    if (index == _cellCount) {
      return true;
    }

    final row = index ~/ gridSize;
    final col = index % gridSize;

    final int used =
        _rowMasks[row] | _colMasks[col] | _boxMasks[_boxIndex(row, col)];

    final numbers = List<int>.generate(maxValue, (i) => i + minValue);

    numbers.shuffle(_random);

    for (final value in numbers) {
      if ((used & (1 << value)) != 0) {
        continue;
      }

      _place(row, col, value);

      if (_fillCell(index + 1)) {
        return true;
      }

      _unplace(row, col, value);
    }

    return false;
  }

  // ==========================================================================
  // PUZZLE GENERATION
  // ==========================================================================

  /// Generates a Sudoku puzzle by removing [removeCount] values from a
  /// newly generated solved board.
  ///
  /// [removeCount] must be between 0 and 81 (0 and
  /// [maxUniqueRemovableCells] when [ensureUnique] is true).
  ///
  /// By default, cells are removed blindly, which does NOT guarantee a unique
  /// solution. With [ensureUnique] true, a cell is only removed if the puzzle
  /// still has exactly one solution; fresh solutions are tried until the
  /// requested count is reached. This throws a [StateError] if it cannot
  /// (large counts are hard to reach with random removal) and is slower, so
  /// run it off the UI thread for high counts.
  List<List<int>> generatePuzzle(int removeCount, {bool ensureUnique = false}) {
    final int maxAllowed = ensureUnique
        ? maxUniqueRemovableCells
        : maxRemovableCells;

    if (removeCount < 0 || removeCount > maxAllowed) {
      throw ArgumentError.value(
        removeCount,
        'removeCount',
        'Remove count must be between 0 and $maxAllowed.',
      );
    }

    if (ensureUnique) {
      return _generateUniquePuzzle(removeCount);
    }

    final solution = generateSolvedBoard();
    final puzzle = _cloneGrid(solution);

    if (removeCount == 0) {
      return puzzle;
    }

    final positions = <int>[
      for (int index = 0; index < _cellCount; index++) index,
    ];

    positions.shuffle(_random);

    for (int index = 0; index < removeCount; index++) {
      final position = positions[index];

      final row = position ~/ gridSize;
      final col = position % gridSize;

      puzzle[row][col] = 0;
    }

    return puzzle;
  }

  List<List<int>> _generateUniquePuzzle(int removeCount) {
    for (int attempt = 0; attempt < _maxUniqueAttempts; attempt++) {
      final solution = generateSolvedBoard();

      if (removeCount == 0) {
        return solution;
      }

      final puzzle = _removeKeepingUnique(solution, removeCount);

      if (puzzle != null) {
        return puzzle;
      }
    }

    throw StateError(
      'Could not generate a unique puzzle with $removeCount empty cells '
      'after $_maxUniqueAttempts attempts.',
    );
  }

  /// Removes cells in random order, keeping only removals that leave exactly
  /// one solution. Returns null if [removeCount] cells cannot be removed.
  List<List<int>>? _removeKeepingUnique(
    List<List<int>> solution,
    int removeCount,
  ) {
    final counter = _SolutionCounter.fromGrid(solution);

    final positions = <int>[
      for (int index = 0; index < _cellCount; index++) index,
    ];

    positions.shuffle(_random);

    int removed = 0;

    for (final position in positions) {
      if (removed >= removeCount) {
        break;
      }

      final int previous = counter.valueAt(position);

      counter.clear(position);

      if (counter.countSolutions(2) == 1) {
        removed++;
      } else {
        counter.place(position, previous);
      }
    }

    return removed == removeCount ? counter.toGrid() : null;
  }
}

// ============================================================================
// SOLUTION COUNTER
// ----------------------------------------------------------------------------
// Bitmask-based solver that only COUNTS solutions (up to a limit). Used for
// the optional uniqueness guarantee.
// ============================================================================

class _SolutionCounter {
  static const int _size = SudokuGenerator.gridSize;
  static const int _cells = SudokuGenerator.gridSize * SudokuGenerator.gridSize;

  /// Bits 1..9 set: every legal value.
  static const int _allValues = 0x3FE;

  final Uint8List _values = Uint8List(_cells);
  final Uint16List _rows = Uint16List(_size);
  final Uint16List _cols = Uint16List(_size);
  final Uint16List _boxes = Uint16List(_size);

  _SolutionCounter.fromGrid(List<List<int>> grid) {
    for (int row = 0; row < _size; row++) {
      for (int col = 0; col < _size; col++) {
        final int value = grid[row][col];

        if (value != 0) {
          place((row * _size) + col, value);
        }
      }
    }
  }

  static int _row(int index) => index ~/ _size;
  static int _col(int index) => index % _size;
  static int _box(int index) => ((_row(index) ~/ 3) * 3) + (_col(index) ~/ 3);

  int valueAt(int index) => _values[index];

  void place(int index, int value) {
    final int bit = 1 << value;

    _values[index] = value;
    _rows[_row(index)] |= bit;
    _cols[_col(index)] |= bit;
    _boxes[_box(index)] |= bit;
  }

  void clear(int index) {
    final int bit = 1 << _values[index];

    _values[index] = 0;
    _rows[_row(index)] &= ~bit;
    _cols[_col(index)] &= ~bit;
    _boxes[_box(index)] &= ~bit;
  }

  List<List<int>> toGrid() {
    return List<List<int>>.generate(
      _size,
      (int row) => List<int>.generate(
        _size,
        (int col) => _values[(row * _size) + col],
      ),
      growable: false,
    );
  }

  static int _popCount(int mask) {
    int count = 0;

    while (mask != 0) {
      mask &= mask - 1;
      count++;
    }

    return count;
  }

  /// Counts solutions, stopping once [limit] is reached. The board is
  /// restored before returning.
  int countSolutions(int limit) {
    int bestIndex = -1;
    int bestMask = 0;
    int bestCount = SudokuGenerator.maxValue + 1;

    // Pick the empty cell with the fewest candidates (fails fast).
    for (int index = 0; index < _cells; index++) {
      if (_values[index] != 0) {
        continue;
      }

      final int mask =
          ~(_rows[_row(index)] | _cols[_col(index)] | _boxes[_box(index)]) &
          _allValues;

      final int count = _popCount(mask);

      if (count == 0) {
        return 0;
      }

      if (count < bestCount) {
        bestCount = count;
        bestIndex = index;
        bestMask = mask;

        if (count == 1) {
          break;
        }
      }
    }

    // No empty cell: the board is a complete solution.
    if (bestIndex < 0) {
      return 1;
    }

    int total = 0;
    int remaining = bestMask;

    while (remaining != 0 && total < limit) {
      final int bit = remaining & -remaining;

      remaining ^= bit;

      place(bestIndex, bit.bitLength - 1);

      total += countSolutions(limit - total);

      clear(bestIndex);
    }

    return total;
  }
}