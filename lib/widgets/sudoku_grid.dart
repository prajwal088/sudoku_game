import 'package:flutter/material.dart';

import '../logic/sudoku_validator.dart';
import '../models/sudoku_board.dart';
import 'sudoku_cell.dart';

/// ============================================================================
/// SudokuGrid
/// ----------------------------------------------------------------------------
/// Renders a 9x9 Sudoku grid.
///
/// Responsibilities:
/// - Display all 81 cells
/// - Handle selection state
/// - Highlight row, column, and 3x3 box
/// - Show validation errors (wrong inputs)
/// - Render proper Sudoku borders (3x3 thick lines)
/// - Describe the board and each cell to screen readers
///
/// Performance Considerations:
/// - Stateless (fast rebuilds)
/// - A fixed 9x9 board is laid out with Column/Row instead of a scrolling
///   GridView: no Scrollable, viewport, sliver or 81 per-child repaint
///   boundaries for something that never scrolls.
/// - Cell border decorations and hint keys are built once and shared.
/// - One RepaintBoundary isolates the board from the rest of the screen.
/// ============================================================================

class SudokuGrid extends StatelessWidget {
  /// Constants for grid dimensions
  static const int gridSize = 9;
  static const int subGridSize = 3;
  static const int totalCells = gridSize * gridSize;

  static const double _thickBorderWidth = 2;
  static const double _thinBorderWidth = 0.5;

  /// Sudoku board data model
  final SudokuBoard board;

  /// Currently selected cell position (-1 means none)
  final int selectedRow;
  final int selectedCol;

  /// Cells filled by a hint, as `'row-col'` keys.
  final Set<String> hintedCells;

  final void Function(int row, int col) onCellTap;

  const SudokuGrid({
    super.key,
    required this.board,
    required this.selectedRow,
    required this.selectedCol,
    required this.hintedCells,
    required this.onCellTap,
  });

  // ==========================================================================
  // SHARED, BUILT-ONCE DATA
  // ==========================================================================

  /// Outer thick border for the entire grid.
  static const BoxDecoration _outerDecoration = BoxDecoration(
    border: Border.fromBorderSide(
      BorderSide(color: Colors.black, width: _thickBorderWidth),
    ),
  );

  /// Border decoration for every cell, indexed by `row * 9 + col`.
  ///
  /// Previously 81 decorations were created on every build.
  static final List<BoxDecoration> _cellDecorations =
      List<BoxDecoration>.generate(
        totalCells,
        (int index) => _buildCellBoxDecoration(
          index ~/ gridSize,
          index % gridSize,
        ),
        growable: false,
      );

  /// `'row-col'` keys (the format GameScreen uses for hinted cells), built
  /// once instead of allocating 81 strings on every build.
  static final List<String> _cellKeys = List<String>.generate(
    totalCells,
    (int index) => '${index ~/ gridSize}-${index % gridSize}',
    growable: false,
  );

  // ==========================================================================
  // HIGHLIGHT LOGIC
  // ==========================================================================
  /// Highlights:
  /// - Same row
  /// - Same column
  /// - Same 3x3 box
  bool _isHighlighted(int row, int col) {
    if (selectedRow < 0 || selectedCol < 0) return false;

    final bool sameRow = row == selectedRow;
    final bool sameCol = col == selectedCol;

    final bool sameSubGrid =
        (row ~/ subGridSize == selectedRow ~/ subGridSize) &&
        (col ~/ subGridSize == selectedCol ~/ subGridSize);

    return sameRow || sameCol || sameSubGrid;
  }

  // ==========================================================================
  // VALIDATION (SAFE CHECK)
  // ==========================================================================
  /// Ensures current cell value is valid without self-conflict.
  bool _isWrongCell(int row, int col, int value) {
    if (value == 0 || board.fixed[row][col]) return false;

    // Use the validator with the excludeSelf flag for a clean check.
    return !SudokuValidator.isValidMove(
      board.board,
      row,
      col,
      value,
      excludeSelf: true,
    );
  }

  // ==========================================================================
  // BUILD
  // ==========================================================================
  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: 'Sudoku board',
      child: RepaintBoundary(
        child: AspectRatio(
          aspectRatio: 1, // Perfect square grid
          child: Container(
            decoration: _outerDecoration,
            child: Column(
              children: <Widget>[
                for (int row = 0; row < gridSize; row++)
                  Expanded(
                    child: Row(
                      // Tight height so every cell fills its row.
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        for (int col = 0; col < gridSize; col++)
                          Expanded(child: _buildCell(row, col)),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCell(int row, int col) {
    final int index = (row * gridSize) + col;
    final int value = board.board[row][col];

    // Container (not DecoratedBox) on purpose: it insets its child by the
    // border widths, so the cell's background never paints over the lines.
    return Container(
      decoration: _cellDecorations[index],
      child: SudokuCell(
        row: row,
        col: col,
        number: value,
        fixed: board.fixed[row][col],
        isHinted: hintedCells.contains(_cellKeys[index]),
        selected: row == selectedRow && col == selectedCol,
        highlighted: _isHighlighted(row, col),
        isWrong: _isWrongCell(row, col, value),
        onTap: () => onCellTap(row, col),
      ),
    );
  }

  /// Border math for one cell: thick lines on 3x3 box edges, thin elsewhere.
  static BoxDecoration _buildCellBoxDecoration(int row, int col) {
    const Color color = Colors.black;

    return BoxDecoration(
      border: Border(
        top: BorderSide(
          width: row % subGridSize == 0 ? _thickBorderWidth : _thinBorderWidth,
          color: color,
        ),
        left: BorderSide(
          width: col % subGridSize == 0 ? _thickBorderWidth : _thinBorderWidth,
          color: color,
        ),
        right: BorderSide(
          width: (col + 1) % subGridSize == 0
              ? _thickBorderWidth
              : _thinBorderWidth,
          color: color,
        ),
        bottom: BorderSide(
          width: (row + 1) % subGridSize == 0
              ? _thickBorderWidth
              : _thinBorderWidth,
          color: color,
        ),
      ),
    );
  }
}