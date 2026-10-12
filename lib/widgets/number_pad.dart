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
/// - Strong typing for callbacks
/// - Reusable & scalable
/// - Accessible (every button has a spoken label)
/// - Button styles are built once and shared, not per button per build
///
/// Colors:
/// The pad uses the game's fixed palette (blue numbers; orange undo, green
/// hint, red erase) with explicit white foregrounds, so it looks the same
/// regardless of the app theme.
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

  /// When false every button is disabled (for example while a finished level
  /// is being saved). Defaults to true, so existing callers are unaffected.
  final bool enabled;

  const NumberPad({
    super.key,
    required this.onNumberSelected,
    required this.onUndo,
    required this.onHint,
    required this.onErase,
    this.enabled = true,
  });

  // ==========================================================================
  // SHARED BUTTON STYLES
  // ==========================================================================

  static const EdgeInsets _buttonPadding = EdgeInsets.symmetric(vertical: 16);

  static final RoundedRectangleBorder _buttonShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(10),
  );

  static ButtonStyle _buildStyle(Color color) {
    return ElevatedButton.styleFrom(
      padding: _buttonPadding,
      backgroundColor: color,
      // Explicit, so digits are readable whatever the app theme's elevated
      // button foreground is.
      foregroundColor: Colors.white,
      disabledBackgroundColor: color.withValues(alpha: 0.4),
      disabledForegroundColor: Colors.white70,
      shape: _buttonShape,
      elevation: 2,
    );
  }

  static final ButtonStyle _numberStyle = _buildStyle(Colors.blue.shade500);
  static final ButtonStyle _undoStyle = _buildStyle(Colors.orange);
  static final ButtonStyle _hintStyle = _buildStyle(Colors.green);
  static final ButtonStyle _eraseStyle = _buildStyle(Colors.red);

  static const TextStyle _numberTextStyle = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.bold,
  );

  // ==========================================================================
  // NUMBER BUTTON
  // ==========================================================================
  Widget _buildNumberButton(int number) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: ElevatedButton(
          onPressed: enabled ? () => onNumberSelected(number) : null,
          style: _numberStyle,
          child: Text('$number', style: _numberTextStyle),
        ),
      ),
    );
  }

  // ==========================================================================
  // ACTION BUTTON (Undo / Hint / Erase)
  // ==========================================================================
  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    required ButtonStyle style,
  }) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: ElevatedButton(
          onPressed: enabled ? onPressed : null,
          style: style,
          // The icon-only button is announced as "Undo" / "Hint" / "Erase".
          child: Icon(icon, size: 22, semanticLabel: label),
        ),
      ),
    );
  }

  // ==========================================================================
  // BUILD UI
  // ==========================================================================
  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        // ================= NUMBERS (3 rows of 1–9) =================
        for (int row = 0; row < 3; row++)
          Row(
            children: <Widget>[
              for (int col = 0; col < 3; col++)
                _buildNumberButton((row * 3) + col + 1),
            ],
          ),

        const SizedBox(height: 8),

        // ================= ACTION BUTTONS =================
        Row(
          children: <Widget>[
            _buildActionButton(
              icon: Icons.undo,
              label: 'Undo',
              onPressed: onUndo,
              style: _undoStyle,
            ),
            _buildActionButton(
              icon: Icons.lightbulb,
              label: 'Hint',
              onPressed: onHint,
              style: _hintStyle,
            ),
            _buildActionButton(
              icon: Icons.backspace,
              label: 'Erase',
              onPressed: onErase,
              style: _eraseStyle,
            ),
          ],
        ),
      ],
    );
  }
}