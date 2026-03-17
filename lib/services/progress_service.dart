import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class ProgressService {

  static const String _progressKey = "sudoku_progress";

  /// Default progress structure
  Map<String, dynamic> _defaultProgress() {
    return {
      "currentLevel": 1,
      "completedLevels": <int>[],
      "bestTimes": <String, int>{},
      "stars": <String, int>{}
    };
  }

  /// Load progress
  Future<Map<String, dynamic>> loadProgress() async {

    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString(_progressKey);

    if (data == null) {
      return _defaultProgress();
    }

    return jsonDecode(data);
  }

  /// Save progress
  Future<void> saveProgress(Map<String, dynamic> progress) async {

    final prefs = await SharedPreferences.getInstance();

    await prefs.setString(
      _progressKey,
      jsonEncode(progress),
    );
  }

  /// Save level progress (called from GameScreen)
  Future<void> saveLevelProgress({
    required int levelNumber,
    required int stars,
    required int time,
  }) async {

    await completeLevel(levelNumber, time, stars);
  }

  /// Complete level
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

    /// Save updated values back
    progress["completedLevels"] = completed;
    progress["bestTimes"] = bestTimes;
    progress["stars"] = starsMap;

    await saveProgress(progress);
  }

  /// Unlock next level manually (optional)
  Future<void> unlockNextLevel(int level) async {

    var progress = await loadProgress();

    if (progress["currentLevel"] <= level) {
      progress["currentLevel"] = level + 1;
    }

    await saveProgress(progress);
  }

  /// Next playable level
  Future<int> getNextUnlockedLevel() async {

    var progress = await loadProgress();
    return progress["currentLevel"];
  }

  /// Current unlocked level
  Future<int> getCurrentLevel() async {

    var progress = await loadProgress();
    return progress["currentLevel"];
  }

  /// Check level unlocked
  Future<bool> isLevelUnlocked(int level) async {

    int currentLevel = await getCurrentLevel();
    return level <= currentLevel;
  }

  /// Get stars
  Future<int> getStars(int level) async {

    var progress = await loadProgress();
    Map<String, dynamic> starsMap =
        Map<String, dynamic>.from(progress["stars"]);

    return starsMap[level.toString()] ?? 0;
  }

  /// Get best time (in seconds)
  Future<int?> getBestTime(int level) async {

    var progress = await loadProgress();
    Map<String, dynamic> bestTimes =
        Map<String, dynamic>.from(progress["bestTimes"]);

    return bestTimes[level.toString()];
  }

  /// Reset progress
  Future<void> resetProgress() async {

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_progressKey);
  }

  /// Visible levels (completed + next 20 locked)
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