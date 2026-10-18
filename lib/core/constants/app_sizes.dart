/// Shared layout and typography sizes.
///
/// Values are logical pixels. Font sizes are scaled by the user's system text
/// scale at render time, so wide numbers (like the board digits) should still
/// be placed in a fixed-size cell, ideally with `FittedBox` or a clamped
/// `MediaQuery.textScalerOf(context)`.
abstract final class AppSizes {
  // --------------------------------------------------------------------------
  // Board
  // --------------------------------------------------------------------------

  /// Padding around the Sudoku grid.
  static const double gridPadding = 8;

  /// Font size for digits inside board cells.
  static const double cellFont = 20;
}