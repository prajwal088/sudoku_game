import 'package:flutter/material.dart';
import '../models/sudoku_board.dart';
import 'sudoku_cell.dart';
import '../logic/sudoku_validator.dart';

/// A widget that renders a complete 9x9 Sudoku grid.
///
/// Responsibilities:
/// - Display numbers from the board
/// - Highlight selected row, column, and subgrid
/// - Indicate invalid (wrong) entries
/// - Handle user interaction (cell taps)

class SudokuGrid extends StatelessWidget {
  /// Constants for grid dimensions
  static const int gridSize = 9;
  static const int subGridSize = 3;
  static const int totalCells = gridSize * gridSize;

  /// Sudoku board data model
  final SudokuBoard board;

  /// Currently selected cell position (-1 means none)
  final int selectedRow;
  final int selectedCol;

  /// Callback when a cell is tapped
  final Function(int row, int col) onCellTap;

  const SudokuGrid({
    super.key,
    required this.board,
    required this.selectedRow,
    required this.selectedCol,
    required this.onCellTap,
  });

  /// Determines whether a cell should be highlighted.
  ///
  /// Highlights:
  /// - Same row
  /// - Same column
  /// - Same 3x3 subgrid
  bool isHighlighted(int row, int col) {
    if (selectedRow == -1 || selectedCol == -1) return false;

    final sameRow = row == selectedRow;
    final sameCol = col == selectedCol;

    final sameSubGrid =
        (row ~/ subGridSize == selectedRow ~/ subGridSize) &&
        (col ~/ subGridSize == selectedCol ~/ subGridSize);

    return sameRow || sameCol || sameSubGrid;
  }

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1, // Keep grid perfectly square
      child: GridView.builder(
        physics: const NeverScrollableScrollPhysics(),
        itemCount: totalCells,

        /// Defines a 9-column grid
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: gridSize,
        ),
        itemBuilder: (context, index) {
          /// Convert 1D index into 2D row/column
          final row = index ~/ gridSize;
          final col = index % gridSize;

          /// Extract cell value
          final value = board.board[row][col];

          /// Determine if the current value is invalid
          bool isWrong  = false;
          if (value != 0) {
            isWrong  =
                !SudokuValidator.isValidMove(board.board, row, col, value);
          }

          /// UI states
          final isCellHighlighted = isHighlighted(row, col);
          final isSelected = row == selectedRow && col == selectedCol;

          /// Build cell border (thicker for 3x3 grid separation)
          BorderSide borderSide(bool condition) => BorderSide(
                width: condition ? 2.0 : 0.5,
                color: Colors.black,
              );
          
          return Container(
            decoration: BoxDecoration(
              border: Border(
                top: borderSide(row % subGridSize == 0),
                left: borderSide(col % subGridSize == 0),
                right: borderSide((col + 1) % subGridSize == 0),
                bottom: borderSide((row + 1) % subGridSize == 0),
              ),
            ),

            /// Individual Sudoku cell widget
            child: SudokuCell(
              number: value,
              fixed: board.fixed[row][col],
              selected: isSelected,
              highlighted: isCellHighlighted,
              isWrong: isWrong,
              onTap: () => onCellTap(row, col),
            ),
          );
        },
      ),
    );
  }
}