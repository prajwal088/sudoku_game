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
  final SudokuBoard board;
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
  bool isHighlighted(int row, int col) {
    if (selectedRow == -1 || selectedCol == -1) return false;

    return row == selectedRow ||
        col == selectedCol ||
        (row ~/ 3 == selectedRow ~/ 3 &&
            col ~/ 3 == selectedCol ~/ 3);
  }

  /// ==========================================================================
  /// VALIDATION (SAFE CHECK)
  /// ==========================================================================
  /// Ensures current cell value is valid without self-conflict
  bool isWrongCell(int row, int col, int value) {
    if (value == 0) return false;

    // Temporarily remove value to avoid self-check conflict
    final temp = board.board[row][col];
    board.board[row][col] = 0;

    final isValid =
        SudokuValidator.isValidMove(board.board, row, col, value);

    // Restore value
    board.board[row][col] = temp;

    return !isValid;
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

            // ✅ Check if this specific cell was provided by a hint
            final bool isHinted = hintedCells.contains("$row-$col");

            final bool isWrong = value != 0 && 
                !board.fixed[row][col] && 
                !SudokuValidator.isValidMove(board.board, row, col, value, excludeSelf: true);

            final bool highlighted = isHighlighted(row, col);

            return Container(
              decoration: BoxDecoration(
                border: Border(
                  /// TOP BORDER
                  top: BorderSide(
                    width: row % 3 == 0 ? 2 : 0.5,
                    color: Colors.black,
                  ),

                  /// LEFT BORDER
                  left: BorderSide(
                    width: col % 3 == 0 ? 2 : 0.5,
                    color: Colors.black,
                  ),

                  /// RIGHT BORDER
                  right: BorderSide(
                    width: (col + 1) % 3 == 0 ? 2 : 0.5,
                    color: Colors.black,
                  ),

                  /// BOTTOM BORDER
                  bottom: BorderSide(
                    width: (row + 1) % 3 == 0 ? 2 : 0.5,
                    color: Colors.black,
                  ),
                ),
              ),

              child: SudokuCell(
                number: value,
                fixed: board.fixed[row][col],
                isHinted: isHinted,
                selected: row == selectedRow && col == selectedCol,
                highlighted: highlighted,
                isWrong: isWrong,
                onTap: () => onCellTap(row, col),
              ),
            );
          },
        ),
      ),
    );
  }
}