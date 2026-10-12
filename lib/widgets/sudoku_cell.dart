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
///    • Hinted (filled by a hint)
/// - Describe itself to screen readers
///
/// Priority of states (top → bottom):
/// 1. Wrong (error)
/// 2. Selected
/// 3. Highlighted
/// 4. Default
///
/// Optimized for:
/// - Fast rebuilds (used in 81-cell grid): colors and text styles are shared
///   static values, nothing is allocated per build except the widgets.
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

  /// Optional zero-based position, used only to give screen readers a full
  /// description such as "Row 3, column 5, 7, given". The grid may pass these;
  /// without them the cell is described by its value and state only.
  final int? row;
  final int? col;

  const SudokuCell({
    super.key,
    required this.number,
    required this.fixed,
    required this.selected,
    required this.highlighted,
    required this.isWrong,
    this.isHinted = false,
    required this.onTap,
    this.row,
    this.col,
  });

  // ==========================================================================
  // SHARED STYLE VALUES
  // ==========================================================================

  static const double _fontSize = 24;

  static final Color _wrongBackground = Colors.red.shade200;
  static final Color _selectedBackground = Colors.blue.shade300;
  static final Color _highlightedBackground = Colors.blue.shade100;

  static final Color _splashColor = Colors.blue.withValues(alpha: 0.2);

  /// Fixed puzzle numbers are bold; everything else is medium weight.
  static final TextStyle _fixedStyle = const TextStyle(
    fontSize: _fontSize,
    fontWeight: FontWeight.w900,
    color: Colors.black,
  );

  static final TextStyle _hintedStyle = const TextStyle(
    fontSize: _fontSize,
    fontWeight: FontWeight.w500,
    color: Colors.deepPurple,
  );

  static final TextStyle _userStyle = TextStyle(
    fontSize: _fontSize,
    fontWeight: FontWeight.w500,
    color: Colors.blue.shade900,
  );

  static final TextStyle _wrongStyle = TextStyle(
    fontSize: _fontSize,
    fontWeight: FontWeight.w500,
    color: Colors.red.shade900,
  );

  static final TextStyle _wrongFixedStyle = TextStyle(
    fontSize: _fontSize,
    fontWeight: FontWeight.w900,
    color: Colors.red.shade900,
  );

  // ==========================================================================
  // DERIVED STATE
  // ==========================================================================

  /// Only 1-9 are drawn; 0 (and anything out of range) is an empty cell.
  bool get _hasNumber => number >= 1 && number <= 9;

  // ==========================================================================
  // BACKGROUND COLOR LOGIC
  // ==========================================================================

  Color _getBackgroundColor() {
    if (isWrong) return _wrongBackground; // ❌ Error state
    if (selected) return _selectedBackground; // 🎯 Selected cell
    if (highlighted) return _highlightedBackground; // 🔍 Related cells
    return Colors.white; // Default
  }

  // ==========================================================================
  // TEXT STYLE
  // ==========================================================================

  /// Chooses the style by how the number got there.
  TextStyle _getTextStyle() {
    if (isWrong) return fixed ? _wrongFixedStyle : _wrongStyle; // Error text
    if (fixed) return _fixedStyle; // 🔒 Permanent puzzle numbers
    if (isHinted) return _hintedStyle; // 💡 Hinted numbers
    return _userStyle; // ✏️ User input numbers
  }

  // ==========================================================================
  // ACCESSIBILITY
  // ==========================================================================

  String get _semanticLabel {
    final int? r = row;
    final int? c = col;

    final String position = (r != null && c != null)
        ? 'Row ${r + 1}, column ${c + 1}, '
        : '';

    final String value = _hasNumber ? '$number' : 'empty';

    final String status;

    if (isWrong) {
      status = ', incorrect';
    } else if (fixed) {
      status = ', given';
    } else if (isHinted) {
      status = ', hint';
    } else {
      status = '';
    }

    return '$position$value$status';
  }

  // ==========================================================================
  // BUILD
  // ==========================================================================

  @override
  Widget build(BuildContext context) {
    // Respect the system "reduce motion" setting. This only rebuilds the cell
    // when that one setting changes, not on every MediaQuery change.
    final bool reduceMotion = MediaQuery.disableAnimationsOf(context);

    return Semantics(
      button: true,
      selected: selected,
      label: _semanticLabel,
      // The visual text is summarised by the label.
      excludeSemantics: true,
      onTap: onTap,
      child: Material(
        color: _getBackgroundColor(),
        animationDuration: reduceMotion ? Duration.zero : kThemeChangeDuration,
        child: InkWell(
          onTap: onTap,
          // Splash color gives a nice feedback when tapped
          splashColor: _splashColor,
          child: Center(
            child: _hasNumber
                ? Padding(
                    padding: const EdgeInsets.all(2),
                    // Scales the digit down (never up) if a large system text
                    // size would otherwise clip it in a small cell.
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        '$number',
                        style: _getTextStyle(),
                      ),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ),
      ),
    );
  }
}