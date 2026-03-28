import 'package:flutter/material.dart';

/// ============================================================================
/// NumberPad
/// ----------------------------------------------------------------------------
/// Production-ready input panel for Sudoku gameplay.
///
/// Responsibilities:
/// - Provide number input (1–9)
/// - Provide actions: Undo, Hint, Erase
///
/// Design Principles:
/// - Fully responsive layout
/// - Theme-aware (no hardcoded colors)
/// - Strong typing for callbacks
/// - Reusable & scalable
/// ============================================================================

class NumberPad extends StatelessWidget {
  /// Called when a number (1–9) is selected
  final ValueChanged<int> onNumberSelected;

  /// Undo last move
  final VoidCallback onUndo;

  /// Show hint
  final VoidCallback onHint;

  /// Erase current cell
  final VoidCallback onErase;

  const NumberPad({
    super.key,
    required this.onNumberSelected,
    required this.onUndo,
    required this.onHint,
    required this.onErase,
  });

  /// ==========================================================================
  /// NUMBER BUTTON
  /// ==========================================================================
  Widget _buildNumberButton(BuildContext context, int number) {

    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: ElevatedButton(
          onPressed: () => onNumberSelected(number),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
            backgroundColor: Colors.blue.shade500,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            elevation: 2,
          ),
          child: Text(
            "$number",
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  /// ==========================================================================
  /// ACTION BUTTON (Undo / Hint / Erase)
  /// ==========================================================================
  Widget _buildActionButton(
    BuildContext context, {
    required IconData icon,
    required VoidCallback onPressed,
    required Color color,
  }) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
            backgroundColor: color,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            elevation: 2,
          ),
          child: Icon(icon, size: 22),
        ),
      ),
    );
  }

  /// ==========================================================================
  /// BUILD UI
  /// ==========================================================================
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [

        /// ================= NUMBERS ROW 1 =================
        Row(
          children: [
            _buildNumberButton(context, 1),
            _buildNumberButton(context, 2),
            _buildNumberButton(context, 3),
          ],
        ),

        /// ================= NUMBERS ROW 2 =================
        Row(
          children: [
            _buildNumberButton(context, 4),
            _buildNumberButton(context, 5),
            _buildNumberButton(context, 6),
          ],
        ),

        /// ================= NUMBERS ROW 3 =================
        Row(
          children: [
            _buildNumberButton(context, 7),
            _buildNumberButton(context, 8),
            _buildNumberButton(context, 9),
          ],
        ),

        const SizedBox(height: 8),

        /// ================= ACTION BUTTONS =================
        Row(
          children: [
            _buildActionButton(
              context,
              icon: Icons.undo,
              onPressed: onUndo,
              color: Colors.orange,
            ),
            _buildActionButton(
              context,
              icon: Icons.lightbulb,
              onPressed: onHint,
              color: Colors.green,
            ),
            _buildActionButton(
              context,
              icon: Icons.backspace,
              onPressed: onErase,
              color: Colors.red,
            ),
          ],
        ),
      ],
    );
  }
}