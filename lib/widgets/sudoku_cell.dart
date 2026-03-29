import 'package:flutter/material.dart';

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
  final bool isHinted;
  final VoidCallback onTap;

  const SudokuCell({
    super.key,
    required this.number,
    required this.fixed,
    required this.selected,
    required this.highlighted,
    required this.isWrong,
    this.isHinted = false,
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
  /// Logic to determine text color based on how the number got there
  Color _getTextColor() {
    if (isWrong) return Colors.red.shade900;         // Error text
    if (fixed) return Colors.black;                  // 🔒 Permanent puzzle numbers
    if (isHinted) return Colors.deepPurple;          // 💡 Hinted numbers
    return Colors.blue.shade900;                     // ✏️ User input numbers
  }

 @override
  Widget build(BuildContext context) {
    return Material(
      color: _getBackgroundColor(),
      child: InkWell(
        onTap: onTap,
        // Splash color gives a nice feedback when tapped
        splashColor: Colors.blue.withValues(alpha: 0.2), 
        child: Center(
          child: number == 0
              ? const SizedBox.shrink()
              : Text(
                  number.toString(),
                  style: TextStyle(
                    fontSize: 24, // Slightly larger for better readability
                    fontWeight: fixed ? FontWeight.w900 : FontWeight.w500,
                    color: _getTextColor(),
                  ),
                ),
        ),
      ),
    );
  }
}