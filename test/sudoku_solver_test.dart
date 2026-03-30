import 'package:flutter_test/flutter_test.dart';
// Replace 'sudoku_game' with your actual package name from pubspec.yaml
import 'package:sudoku_game/logic/sudoku_solver.dart';

void main() {
  group('SudokuSolver Logic Tests', () {
    
    /// TEST 1: Generation Logic
    /// Verifies the solver can fill a blank board completely and validly.
    test('Should generate a full valid board from empty state', () {
      final List<List<int>> board = List.generate(9, (_) => List.filled(9, 0));
      
      final bool solved = SudokuSolver.solve(board, randomize: true);
      
      expect(solved, isTrue, reason: "Solver failed to fill an empty board");
      
      // Ensure no zeros (empty cells) remain
      for (var row in board) {
        expect(row.contains(0), isFalse, reason: "Board still contains empty cells");
      }

      // Verify row uniqueness (a core Sudoku rule)
      final firstRow = board[0];
      expect(firstRow.toSet().length, 9, reason: "Generated row contains duplicate numbers");
    });

    /// TEST 2: Solving Logic
    /// Verifies the solver correctly completes a classic partial puzzle.
    test('Should solve a known valid Sudoku puzzle', () {
      final List<List<int>> puzzle = [
        [5, 3, 0, 0, 7, 0, 0, 0, 0],
        [6, 0, 0, 1, 9, 5, 0, 0, 0],
        [0, 9, 8, 0, 0, 0, 0, 6, 0],
        [8, 0, 0, 0, 6, 0, 0, 0, 3],
        [4, 0, 0, 8, 0, 3, 0, 0, 1],
        [7, 0, 0, 0, 2, 0, 0, 0, 6],
        [0, 6, 0, 0, 0, 0, 2, 8, 0],
        [0, 0, 0, 4, 1, 9, 0, 0, 5],
        [0, 0, 0, 0, 8, 0, 0, 7, 9]
      ];

      final bool solved = SudokuSolver.solve(puzzle);
      
      expect(solved, isTrue, reason: "Solver failed to solve a known valid puzzle");
      // Check a specific known answer (Row 0, Col 2 should be 4)
      expect(puzzle[0][2], 4, reason: "Incorrect value placed in cell [0,2]");
    });

    /// TEST 3: Rule Validation (isSafe)
    /// Verifies the move validator correctly identifies illegal moves.
    test('isSafe should block invalid placements', () {
      final List<List<int>> board = List.generate(9, (_) => List.filled(9, 0));
      board[0][0] = 5;

      expect(SudokuSolver.isSafe(board, 0, 5, 5), isFalse, reason: "Failed to catch row duplicate");
      expect(SudokuSolver.isSafe(board, 5, 0, 5), isFalse, reason: "Failed to catch column duplicate");
      expect(SudokuSolver.isSafe(board, 1, 1, 5), isFalse, reason: "Failed to catch 3x3 box duplicate");
      expect(SudokuSolver.isSafe(board, 1, 4, 5), isTrue, reason: "Blocked a valid placement");
    });

    /// TEST 4: Integrity/Copying
    /// Ensures getSolvedBoard doesn't ruin the user's current game state.
    test('getSolvedBoard should return a solution without modifying the original', () {
      final List<List<int>> original = List.generate(9, (_) => List.filled(9, 0));
      original[0][0] = 5;

      final solvedCopy = SudokuSolver.getSolvedBoard(original);

      expect(original[0][1], 0, reason: "Original board was accidentally modified");
      expect(solvedCopy[0][1], isNot(0), reason: "Returned copy was not actually solved");
    });

    /// TEST 5: Performance/Error Handling
    /// Verifies the solver exits instantly on broken boards instead of hanging.
    test('Should return false for impossible puzzles instantly', () {
      final List<List<int>> impossible = List.generate(9, (_) => List.filled(9, 0));
      // Two 5s in the first two cells of the same row is mathematically impossible
      impossible[0][0] = 5;
      impossible[0][1] = 5; 

      final bool result = SudokuSolver.solve(impossible);
      
      expect(result, isFalse, reason: "Solver should reject an already conflicted board");
    });
  });
}