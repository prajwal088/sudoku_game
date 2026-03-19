import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class ProgressService {

  static const String _progressKey = "sudoku_progress";

  static const int levelsPerWorld = 25;

  /// Default progress structure
  Map<String, dynamic> _defaultProgress() {
    return {
      "currentLevel": 1,
      "completedLevels": <int>[],
      "bestTimes": <String, int>{},
      "stars": <String, int>{},

      // 🔥 NEW
      "highestUnlockedWorld": 1,
    };
  }

  /// ================= LOAD =================
  Future<Map<String, dynamic>> loadProgress() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString(_progressKey);

    if (data == null) {
      return _defaultProgress();
    }

    return jsonDecode(data);
  }

  /// ================= SAVE =================
  Future<void> saveProgress(Map<String, dynamic> progress) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString(
      _progressKey,
      jsonEncode(progress),
    );
  }

  /// ================= LEVEL COMPLETE =================
  Future<void> completeLevel(
    int level,
    int timeInSeconds,
    int stars,
  ) async {

    var progress = await loadProgress();

    List<int> completed =
        List<int>.from(progress["completedLevels"]);

    Map<String, dynamic> bestTimes =
        Map<String, dynamic>.from(progress["bestTimes"]);

    Map<String, dynamic> starsMap =
        Map<String, dynamic>.from(progress["stars"]);

    /// Add completed level
    if (!completed.contains(level)) {
      completed.add(level);
    }

    /// Best time (lower is better)
    if (!bestTimes.containsKey(level.toString()) ||
        timeInSeconds < bestTimes[level.toString()]) {

      bestTimes[level.toString()] = timeInSeconds;
    }

    /// Stars (higher is better)
    if (!starsMap.containsKey(level.toString()) ||
        stars > starsMap[level.toString()]) {

      starsMap[level.toString()] = stars;
    }

    /// Unlock next level
    if (progress["currentLevel"] <= level) {
      progress["currentLevel"] = level + 1;
    }

    /// 🔥 WORLD UNLOCK LOGIC
    if (level % levelsPerWorld == 0) {
      int completedWorld = level ~/ levelsPerWorld;

      if (progress["highestUnlockedWorld"] <= completedWorld) {
        progress["highestUnlockedWorld"] = completedWorld + 1;
      }
    }

    /// Save updated values
    progress["completedLevels"] = completed;
    progress["bestTimes"] = bestTimes;
    progress["stars"] = starsMap;

    await saveProgress(progress);
  }

  /// ================= WORLD HELPERS =================

  /// Get world from level
  int getWorldFromLevel(int level) {
    return ((level - 1) ~/ levelsPerWorld) + 1;
  }

  /// Get highest unlocked world
  Future<int> getHighestUnlockedWorld() async {
    var progress = await loadProgress();
    return progress["highestUnlockedWorld"] ?? 1;
  }

  /// Check if world is completed
  Future<bool> isWorldCompleted(int world) async {
    var progress = await loadProgress();

    List<int> completed =
        List<int>.from(progress["completedLevels"]);

    int startLevel = (world - 1) * levelsPerWorld + 1;
    int endLevel = world * levelsPerWorld;

    for (int i = startLevel; i <= endLevel; i++) {
      if (!completed.contains(i)) {
        return false;
      }
    }
    return true;
  }

  /// Manually unlock next world (optional use)
  Future<void> unlockNextWorld(int world) async {
    var progress = await loadProgress();

    if (progress["highestUnlockedWorld"] <= world) {
      progress["highestUnlockedWorld"] = world + 1;
    }

    await saveProgress(progress);
  }

  /// ================= EXISTING METHODS =================

  Future<void> saveLevelProgress({
    required int levelNumber,
    required int stars,
    required int time,
  }) async {
    await completeLevel(levelNumber, time, stars);
  }

  Future<void> unlockNextLevel(int level) async {
    var progress = await loadProgress();

    if (progress["currentLevel"] <= level) {
      progress["currentLevel"] = level + 1;
    }

    await saveProgress(progress);
  }

  Future<int> getNextUnlockedLevel() async {
    var progress = await loadProgress();
    return progress["currentLevel"];
  }

  Future<int> getCurrentLevel() async {
    var progress = await loadProgress();
    return progress["currentLevel"];
  }

  Future<bool> isLevelUnlocked(int level) async {
    int currentLevel = await getCurrentLevel();
    return level <= currentLevel;
  }

  Future<int> getStars(int level) async {
    var progress = await loadProgress();
    Map<String, dynamic> starsMap =
        Map<String, dynamic>.from(progress["stars"]);

    return starsMap[level.toString()] ?? 0;
  }

  Future<int?> getBestTime(int level) async {
    var progress = await loadProgress();
    Map<String, dynamic> bestTimes =
        Map<String, dynamic>.from(progress["bestTimes"]);

    return bestTimes[level.toString()];
  }

  Future<void> resetProgress() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_progressKey);
  }

  Future<List<int>> getVisibleLevels() async {
    int currentLevel = await getCurrentLevel();

    int maxVisible = currentLevel + 20;

    List<int> levels = [];

    for (int i = 1; i <= maxVisible; i++) {
      levels.add(i);
    }

    return levels;
  }
}