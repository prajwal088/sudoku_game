import 'package:flutter/material.dart';

/// App-wide color constants.
///
/// All values are compile-time constants, so they cost nothing at runtime.
/// Prefer reading brand/surface colors through `Theme.of(context)` where a
/// widget should adapt to light/dark themes; use these tokens for the Sudoku
/// board, which has its own palette.
abstract final class AppColors {
  // --------------------------------------------------------------------------
  // Brand / surfaces
  // --------------------------------------------------------------------------

  /// Brand green (Material Green 500).
  static const Color primary = Color(0xFF4CAF50);

  /// Scaffold background (light gray).
  static const Color background = Color(0xFFF5F5F5);

  // --------------------------------------------------------------------------
  // Sudoku board
  // --------------------------------------------------------------------------

  /// Grid lines between cells and around boxes.
  static const Color gridBorder = Colors.black26;

  /// Background of the currently selected cell.
  static const Color cellSelected = Color(0xFFE3F2FD);

  /// Pre-filled (given) digits that the player cannot change.
  static const Color fixedNumber = Colors.black;

  /// Digits entered by the player.
  ///
  /// Typed as [MaterialColor] so existing usages such as
  /// `AppColors.userNumber.shade700` keep compiling.
  static const MaterialColor userNumber = Colors.blue;

  // --------------------------------------------------------------------------
  // Feedback (new, additive: not used until you reference them)
  // --------------------------------------------------------------------------

  /// Digits or cells that conflict with the rules.
  static const Color error = Color(0xFFD32F2F);

  /// Soft highlight for cells related to the selection (same row/column/box).
  static const Color cellRelated = Color(0xFFF1F8FE);
}