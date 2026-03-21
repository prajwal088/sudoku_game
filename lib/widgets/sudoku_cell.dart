import 'package:flutter/material.dart';
import '../core/constants/app_colors.dart';

/// ============================================================================
/// SudokuCell
/// ----------------------------------------------------------------------------
/// Represents a single cell in the Sudoku grid.
///
/// Responsibilities:
/// - Display number (or empty)
/// - Handle tap interaction
/// - Reflect visual states:
///    • Selected
///    • Highlighted (row/col/box)
///    • Fixed (initial puzzle value)
///    • Wrong (invalid input)
///
/// Priority of states (top → bottom):
/// 1. Wrong (error)
/// 2. Selected
/// 3. Highlighted
/// 4. Default
///
/// Optimized for:
/// - Fast rebuilds (used in 81-cell grid)
/// - Clean UI feedback
/// ============================================================================

class SudokuCell extends StatelessWidget {
  final int number;
  final bool fixed;
  final bool selected;
  final bool highlighted;
  final bool isWrong;
  final VoidCallback onTap;

  const SudokuCell({
    super.key,
    required this.number,
    required this.fixed,
    required this.selected,
    required this.highlighted,
    required this.isWrong,
    required this.onTap,
  });

  /// ==========================================================================
  /// BACKGROUND COLOR LOGIC
  /// ==========================================================================
  Color _getBackgroundColor() {
    if (isWrong) return Colors.red.shade200;        // ❌ Error state
    if (selected) return Colors.blue.shade300;      // 🎯 Selected cell
    if (highlighted) return Colors.blue.shade100;   // 🔍 Related cells
    return Colors.white;                            // Default
  }

  /// ==========================================================================
  /// TEXT STYLE
  /// ==========================================================================
  TextStyle _getTextStyle() {
    return TextStyle(
      fontSize: 20,
      fontWeight: FontWeight.bold,
      color: fixed
          ? AppColors.fixedNumber   // 🔒 Pre-filled number
          : AppColors.userNumber,   // ✏️ User input
    );
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _getBackgroundColor(),

      /// InkWell provides proper ripple (better than GestureDetector)
      child: InkWell(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(
              color: AppColors.gridBorder,
              width: 0.5,
            ),
          ),
          alignment: Alignment.center,

          /// Avoid unnecessary Text rebuild logic
          child: number == 0
              ? const SizedBox.shrink()
              : Text(
                  number.toString(),
                  style: _getTextStyle(),
                ),
        ),
      ),
    );
  }
}