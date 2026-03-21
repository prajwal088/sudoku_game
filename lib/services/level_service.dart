import '../models/level.dart';
import '../models/sudoku_board.dart';
import 'progress_service.dart';
import 'puzzle_repository.dart';

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

  /// ==========================================================================
  /// LOAD SINGLE LEVEL
  /// ==========================================================================
  Future<Level> getLevel(int globalLevel) async {
    final progress = await _progressService.loadProgress();

    final int currentLevel = progress["currentLevel"];

    /// ================= PROGRESS STATE =================
    final bool isLocked = globalLevel > currentLevel;

    final List<int> completedLevels =
        List<int>.from(progress["completedLevels"]);

    final bool isCompleted = completedLevels.contains(globalLevel);

    final Map<String, int> starsMap =
        Map<String, int>.from(progress["stars"]);

    final Map<String, int> bestTimes =
        Map<String, int>.from(progress["bestTimes"]);

    final int stars = starsMap[globalLevel.toString()] ?? 0;
    final int bestTime = bestTimes[globalLevel.toString()] ?? 0;

    /// ================= WORLD / LOCAL =================
    final int world = _progressService.getWorldFromGlobal(globalLevel);
    final int localLevel =
        _progressService.getLevelInWorld(globalLevel);

    /// ================= PUZZLE =================
    final Map<String, dynamic> puzzleData =
        _puzzleRepository.getPuzzleForLevel(globalLevel);

    /// ✅ Safe extraction WITHOUT unnecessary cast
    final List<List<int>> puzzle =
        (puzzleData["puzzle"] ?? []) as List<List<int>>;

    final List<List<int>> solution =
        (puzzleData["solution"] ?? []) as List<List<int>>;

    return Level(
      levelNumber: globalLevel,
      world: world,
      difficulty: _getDifficulty(globalLevel),
      puzzle: puzzle,
      solution: solution,
      isLocked: isLocked,
      isCompleted: isCompleted,
      stars: stars,
      bestTime: bestTime,
      targetTime: _getTargetTime(globalLevel),
    );
  }

  /// ==========================================================================
  /// LOAD LEVELS BY WORLD
  /// ==========================================================================
  Future<List<Level>> getLevelsByWorld(int world) async {
    final List<int> visibleLevels =
        await _progressService.getVisibleLevels();

    List<Level> levels = [];

    for (final globalLevel in visibleLevels) {
      if (_progressService.getWorldFromGlobal(globalLevel) ==
          world) {
        levels.add(await getLevel(globalLevel));
      }
    }

    return levels;
  }

  /// ==========================================================================
  /// LOAD ALL VISIBLE LEVELS
  /// ==========================================================================
  Future<List<Level>> getVisibleLevels() async {
    final List<int> visibleLevels =
        await _progressService.getVisibleLevels();

    return Future.wait(
      visibleLevels.map((lvl) => getLevel(lvl)),
    );
  }

  /// ==========================================================================
  /// DIFFICULTY LOGIC
  /// ==========================================================================
  String _getDifficulty(int level) {
    if (level <= 20) return "Easy";
    if (level <= 60) return "Medium";
    if (level <= 120) return "Hard";
    return "Expert";
  }

  /// ==========================================================================
  /// TARGET TIME (seconds)
  /// ==========================================================================
  int _getTargetTime(int level) {
    if (level <= 20) return 300;
    if (level <= 60) return 600;
    if (level <= 120) return 900;
    return 1200;
  }

  /// ==========================================================================
  /// CREATE GAME BOARD
  /// ==========================================================================
  SudokuBoard createBoardFromLevel(Level level) {
    return SudokuBoard.fromPuzzle(
      level.puzzle,
      level.solution,
    );
  }

  /// ==========================================================================
  /// COMPLETE LEVEL
  /// ==========================================================================
  Future<void> completeLevel(
    int globalLevel,
    int completionTime,
    int stars,
  ) async {
    /// Convert GLOBAL → world/local (CRITICAL)
    final int world =
        _progressService.getWorldFromGlobal(globalLevel);

    final int localLevel =
        _progressService.getLevelInWorld(globalLevel);

    await _progressService.completeLevel(
      world,
      localLevel, // ✅ Correct mapping
      completionTime,
      stars,
    );
  }

  /// ==========================================================================
  /// CHECK IF LEVEL UNLOCKED
  /// ==========================================================================
  Future<bool> isLevelUnlocked(int globalLevel) async {
    return _progressService.isLevelUnlocked(globalLevel);
  }

  /// ==========================================================================
  /// RESET PROGRESS
  /// ==========================================================================
  Future<void> resetProgress() async {
    await _progressService.resetProgress();
  }
}