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

    // Single source of truth for unlock logic
    final bool isUnlocked =
        await _progressService.isLevelUnlocked(levelNumber);
    final bool isLocked = !isUnlocked;

    // Safe parsing
    final List<int> completedLevels =
        List<int>.from(progress["completedLevels"] ?? []);

    final Map<String, dynamic> starsMap =
        Map<String, dynamic>.from(progress["stars"] ?? {});

    final Map<String, dynamic> bestTimesMap =
        Map<String, dynamic>.from(progress["bestTimes"] ?? {});

    final bool isCompleted = completedLevels.contains(levelNumber);

    final int stars = starsMap[levelNumber.toString()] ?? 0;
    final int bestTime = bestTimesMap[levelNumber.toString()] ?? 0;

    // Load puzzle
    final puzzleData =
        _puzzleRepository.getPuzzleForLevel(levelNumber);

    return Level(
      levelNumber: levelNumber,
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

  /// Get multiple levels for level map
  Future<List<Level>> getVisibleLevels() async {
    final List<int> visibleLevels =
        await _progressService.getVisibleLevels();

    // Parallel loading (performance optimized)
    return await Future.wait(
      visibleLevels.map((levelNumber) => getLevel(levelNumber)),
    );
  }

  /// Difficulty progression logic
  String _getDifficulty(int level) {
    if (level <= 20) return "Easy";
    if (level <= 60) return "Medium";
    if (level <= 120) return "Hard";
    return "Expert";
  }

  int _getTargetTime(int level) {
    if (level <= 20) return 300;
    if (level <= 60) return 600;
    if (level <= 120) return 900;
    return 1200;
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
    await _progressService.completeLevel(
      levelNumber,
      completionTime,
      stars,
    );
  }

  /// Check if level unlocked (proxy)
  Future<bool> isLevelUnlocked(int levelNumber) async {
    return _progressService.isLevelUnlocked(levelNumber);
  }

  /// Reset all progress (debug / testing)
  Future<void> resetProgress() async {
    await _progressService.resetProgress();
  }
}