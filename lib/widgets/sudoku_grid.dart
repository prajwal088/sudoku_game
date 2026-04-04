import 'package:flutter/material.dart';
import '../models/sudoku_board.dart';
import 'sudoku_cell.dart';
import '../logic/sudoku_validator.dart';

/// ============================================================================
/// SudokuGrid
/// ----------------------------------------------------------------------------
/// Renders a 9x9 Sudoku grid using GridView.
///
/// Responsibilities:
/// - Display all 81 cells
/// - Handle selection state
/// - Highlight row, column, and 3x3 box
/// - Show validation errors (wrong inputs)
/// - Render proper Sudoku borders (3x3 thick lines)
///
/// Performance Considerations:
/// - Stateless (fast rebuilds)
/// - Uses GridView.builder (lazy rendering)
/// - Minimal per-cell computation
/// ============================================================================

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
  final Set<String> hintedCells;
  final Function(int, int) onCellTap;

  const SudokuGrid({
    super.key,
    required this.board,
    required this.selectedRow,
    required this.selectedCol,
    required this.hintedCells,
    required this.onCellTap,
  });

  /// ==========================================================================
  /// HIGHLIGHT LOGIC
  /// ==========================================================================
  /// Highlights:
  /// - Same row
  /// - Same column
  /// - Same 3x3 box
  bool _isHighlighted(int row, int col) {
    if (selectedRow == -1 || selectedCol == -1) return false;

    final sameRow = row == selectedRow;
    final sameCol = col == selectedCol;

    final sameSubGrid =
        (row ~/ subGridSize == selectedRow ~/ subGridSize) &&
        (col ~/ subGridSize == selectedCol ~/ subGridSize);

    return sameRow || sameCol || sameSubGrid;
  }

  /// ==========================================================================
  /// VALIDATION (SAFE CHECK)
  /// ==========================================================================
  /// Ensures current cell value is valid without self-conflict
  bool _isWrongCell(int row, int col, int value) {
    if (value == 0 || board.fixed[row][col]) return false;

// Use the validator with the excludeSelf flag for a clean check
    return !SudokuValidator.isValidMove(
      board.board, 
      row, 
      col, 
      value, 
      excludeSelf: true
    );
  }

  /// ==========================================================================
  /// BUILD
  /// ==========================================================================
  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1, // Perfect square grid
      child: Container(
        // Outer thick border for the entire grid
        decoration: BoxDecoration(
          border: Border.all(color: Colors.black, width: 2),
        ),
        child: GridView.builder(
          physics: const NeverScrollableScrollPhysics(),
          itemCount: 81,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 9,
          ),
          itemBuilder: (context, index) {
            final int row = index ~/ 9;
            final int col = index % 9;

            final int value = board.board[row][col];

            return Container(
              decoration: _buildCellBoxDecoration(row, col), // Extracted for clarity
              child: SudokuCell(
                number: value,
                fixed: board.fixed[row][col],
                isHinted: hintedCells.contains("$row-$col"),
                selected: row == selectedRow && col == selectedCol,
                highlighted: _isHighlighted(row, col),
                isWrong: _isWrongCell(row, col, value), // Using the helper here
                onTap: () => onCellTap(row, col),
              ),
            );
          },
        ),
      ),
    );
  }

/// Helper to keep the itemBuilder clean of border math
  BoxDecoration _buildCellBoxDecoration(int row, int col) {
    return BoxDecoration(
      border: Border(
        top: BorderSide(width: row % 3 == 0 ? 2 : 0.5, color: Colors.black),
        left: BorderSide(width: col % 3 == 0 ? 2 : 0.5, color: Colors.black),
        right: BorderSide(width: (col + 1) % 3 == 0 ? 2 : 0.5, color: Colors.black),
        bottom: BorderSide(width: (row + 1) % 3 == 0 ? 2 : 0.5, color: Colors.black),
      ),
    );
  }
}