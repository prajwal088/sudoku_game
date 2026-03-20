import '../models/level.dart';
import '../models/sudoku_board.dart';
import 'progress_service.dart';
import 'puzzle_repository.dart';

class LevelService {
  final ProgressService _progressService = ProgressService();
  final PuzzleRepository _puzzleRepository = PuzzleRepository();

  /// Load a level with puzzle + progress state
  Future<Level> getLevel(int levelNumber) async {
    final progress = await _progressService.loadProgress();

    int currentLevel = progress["currentLevel"];

    bool isLocked = levelNumber > currentLevel;

    List completedLevels = progress["completedLevels"];

    bool isCompleted = completedLevels.contains(levelNumber);

    int stars = progress["stars"][levelNumber.toString()] ?? 0;

    int bestTime = progress["bestTimes"][levelNumber.toString()] ?? 0;

    /// Load puzzle for this level
    final puzzleData = _puzzleRepository.getPuzzleForLevel(levelNumber);

    return Level(
      levelNumber: levelNumber,
      world: _getWorld(levelNumber), // ✅ FIXED
      difficulty: _getDifficulty(levelNumber),
      puzzle: puzzleData["puzzle"] as List<List<int>>,
      solution: puzzleData["solution"] as List<List<int>>,
      isLocked: isLocked,
      isCompleted: isCompleted,
      stars: stars,
      bestTime: bestTime,
      targetTime: _getTargetTime(levelNumber),
    );
  }

  /// ✅ OPTIMIZED: Load only levels for specific world
  Future<List<Level>> getLevelsByWorld(int world) async {
    List<int> visibleLevels = await _progressService.getVisibleLevels();

    List<Level> levels = [];

    for (int levelNumber in visibleLevels) {
      if (_getWorld(levelNumber) == world) {
        Level level = await getLevel(levelNumber);
        levels.add(level);
      }
    }

    return levels;
  }

  /// Get multiple levels for level map
  Future<List<Level>> getVisibleLevels() async {
    List<int> visibleLevels = await _progressService.getVisibleLevels();

    List<Level> levels = [];

    for (int levelNumber in visibleLevels) {
      Level level = await getLevel(levelNumber);
      levels.add(level);
    }

    return levels;
  }

  /// ✅ NEW: World calculation (25 levels per world)
  int _getWorld(int level) {
    return ((level - 1) ~/ 25) + 1;
  }

  /// Difficulty progression logic
  String _getDifficulty(int level) {
    if (level <= 20) {
      return "Easy";
    }

    if (level <= 60) {
      return "Medium";
    }

    if (level <= 120) {
      return "Hard";
    }

    return "Expert";
  }

  int _getTargetTime(int level) {
    if (level <= 20) {
      return 300; // 5 minutes
    }

    if (level <= 60) {
      return 600; // 10 minutes
    }

    if (level <= 120) {
      return 900; // 15 minutes
    }

    return 1200; // 20 minutes
  }

  /// Convert Level puzzle to SudokuBoard
  SudokuBoard createBoardFromLevel(Level level) {
    return SudokuBoard.fromPuzzle(
      level.puzzle,
      level.solution,
    );
  }

  /// Mark level completed and unlock next
  Future<void> completeLevel(
    int levelNumber,
    int completionTime,
    int stars,
  ) async {

    // derive world from global level
      int world = _getWorld(levelNumber);

    await _progressService.completeLevel(
      world,
      levelNumber,
      completionTime,
      stars,
    );
  }

  /// Check if level unlocked
  Future<bool> isLevelUnlocked(int levelNumber) async {
    return await _progressService.isLevelUnlocked(levelNumber);
  }

  /// Reset all progress (debug / testing)
  Future<void> resetProgress() async {
    await _progressService.resetProgress();
  }
}