import '../models/level.dart';
import 'progress_service.dart';
import 'puzzle_repository.dart';
import 'game_service.dart';

/// ============================================================================
/// LevelService
/// ----------------------------------------------------------------------------
/// Handles:
/// - Fetching level data (puzzle + metadata)
/// - Applying progress state (locked/completed/stars/best time)
/// - Converting GLOBAL level ↔ WORLD/LOCAL level
/// - Creating SudokuBoard for gameplay
///
/// Architecture:
/// - Global Level = Source of truth
/// - World/Local Level = Derived values
/// ============================================================================

class LevelService {
  final ProgressService _progressService = ProgressService();
  final PuzzleRepository _puzzleRepository = PuzzleRepository();
  final GameService _gameService = GameService();

  /// ==========================================================================
  /// LOAD SINGLE LEVEL
  /// ==========================================================================
  Future<Level> getLevel(int globalLevel) async {
    final progress = await _progressService.loadProgress();

    final int currentUnlocked = progress["currentLevel"] ?? 1;

    /// ================= PROGRESS STATE =================
    // 1. Status Calculations
    final bool isLocked = globalLevel > currentUnlocked;
    final bool isCompleted = (progress["completedLevels"] as List).contains(globalLevel);
    final int stars = progress["stars"][globalLevel.toString()] ?? 0;
    final int bestTime = progress["bestTimes"][globalLevel.toString()] ?? 0;

    // 2. Puzzle Retrieval (with dynamic fallback)
    Map<String, dynamic>? puzzleData = _puzzleRepository.getPuzzleForLevel(globalLevel);
    
    List<List<int>> puzzle;
    List<List<int>> solution;

    if (puzzleData != null) {
      puzzle = List<List<int>>.from(puzzleData["puzzle"].map((x) => List<int>.from(x)));
      solution = List<List<int>>.from(puzzleData["solution"].map((x) => List<int>.from(x)));
    } else {
      // Production Fallback: Generate a puzzle if the repository is missing this level
      final generatedBoard = _gameService.newGame(emptyCells: _getDifficultyCellCount(globalLevel));
      puzzle = generatedBoard.puzzle;
      solution = generatedBoard.solution;
    }

    return Level(
      levelNumber: globalLevel,
      world: _progressService.getWorldFromGlobal(globalLevel),
      difficulty: _getDifficultyLabel(globalLevel),
      puzzle: puzzle,
      solution: solution,
      isLocked: isLocked,
      isCompleted: isCompleted,
      stars: stars,
      bestTime: bestTime,
      targetTime: _getTargetTime(globalLevel),
    );
  }

  // Helper for generating fallback difficulty
  int _getDifficultyCellCount(int level) {
    if (level <= 25) return 35; // Easy
    if (level <= 75) return 45; // Medium
    return 55; // Hard
  }

  String _getDifficultyLabel(int level) {
    if (level <= 25) return "Easy";
    if (level <= 75) return "Medium";
    if (level <= 150) return "Hard";
    return "Expert";
  }

  int _getTargetTime(int level) {
    if (level <= 25) return 300;
    return 600;
  }

  Future<void> completeLevel(int globalLevel, int time, int stars) async {
    await _progressService.completeLevel(
      globalLevel: globalLevel,
      timeInSeconds: time,
      stars: stars,
    );
  }

  /// Add this to LevelService class in level_service.dart
  Future<List<Level>> getLevelsByWorld(int world) async {
    List<Level> worldLevels = [];
    
    // Calculate the start and end global IDs for this world
    int start = _progressService.getGlobalLevel(world, 1);
    int end = _progressService.getGlobalLevel(world, ProgressService.levelsPerWorld);

    for (int i = start; i <= end; i++) {
      worldLevels.add(await getLevel(i));
    }

    return worldLevels;
  }
}