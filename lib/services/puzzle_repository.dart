import 'dart:math';
import '../logic/sudoku_solver.dart';

class PuzzleRepository {
  /// FIXED: Added '?' to return type to allow null safety checks in LevelService
  Map<String, dynamic>? getPuzzleForLevel(int levelNumber) {
    // Safety check: Prevent negative or zero levels if your logic starts at 1
    if (levelNumber < 1) return null;

    String difficulty = _getDifficulty(levelNumber);
    
    // Seed the Random with the level number 
    // This ensures Level 1 is always the same "Level 1" for every player
    Random random = Random(levelNumber); 

    List<List<int>> solution = _generateSolvedBoard(random);
    List<List<int>> puzzle = _createPuzzleFromSolution(
      solution,
      difficulty,
      random,
    );

    return {
      "puzzle": puzzle,
      "solution": solution,
    };
  }

  String _getDifficulty(int level) {
    if (level <= 20) return "Easy";
    if (level <= 60) return "Medium";
    if (level <= 120) return "Hard";
    return "Expert";
  }

  List<List<int>> _generateSolvedBoard(Random random) {
    // Start with a valid seed or empty board
    List<List<int>> board = List.generate(9, (_) => List.filled(9, 0));

    // Note: Your SudokuSolver.solve() needs to handle an empty board 
    // by filling it with a random valid sequence to ensure variety.
    SudokuSolver.solve(board); 

    _shuffleBoard(board, random);
    return board;
  }

  void _shuffleBoard(List<List<int>> board, Random random) {
    // Shuffle rows within their 3x3 blocks to maintain Sudoku validity
    for (int i = 0; i < 20; i++) {
      int block = random.nextInt(3) * 3;
      int r1 = block + random.nextInt(3);
      int r2 = block + random.nextInt(3);

      var temp = board[r1];
      board[r1] = board[r2];
      board[r2] = temp;
    }
  }

  List<List<int>> _createPuzzleFromSolution(
      List<List<int>> solution, String difficulty, Random random) {
    
    List<List<int>> puzzle = solution.map((row) => List<int>.from(row)).toList();
    int cellsToRemove;

    switch (difficulty) {
      case "Easy":
        cellsToRemove = 35;
        break;
      case "Medium":
        cellsToRemove = 45;
        break;
      case "Hard":
        cellsToRemove = 55;
        break;
      default:
        cellsToRemove = 60;
    }

    int removed = 0;
    while (removed < cellsToRemove) {
      int row = random.nextInt(9);
      int col = random.nextInt(9);

      if (puzzle[row][col] != 0) {
        puzzle[row][col] = 0;
        removed++;
      }
    }
    return puzzle;
  }
}