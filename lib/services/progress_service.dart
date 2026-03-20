import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class ProgressService {
  static const String _progressKey = "sudoku_progress";
  static const int levelsPerWorld = 25;

  /// ================= DEFAULT =================
  Map<String, dynamic> _defaultProgress() {
    return {
      "currentLevel": 1,
      "completedLevels": <int>[],
      "bestTimes": <String, int>{},
      "stars": <String, int>{},
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

    Map<String, dynamic> progress = jsonDecode(data);

    /// ✅ Strong type safety (IMPORTANT)
    progress["currentLevel"] = progress["currentLevel"] ?? 1;

    progress["completedLevels"] =
        List<int>.from(progress["completedLevels"] ?? []);

    progress["bestTimes"] =
        Map<String, int>.from(progress["bestTimes"] ?? {});

    progress["stars"] =
        Map<String, int>.from(progress["stars"] ?? {});

    progress["highestUnlockedWorld"] =
        progress["highestUnlockedWorld"] ?? 1;

    return progress;
  }

  /// ================= SAVE =================
  Future<void> saveProgress(Map<String, dynamic> progress) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_progressKey, jsonEncode(progress));
  }

  /// ================= LEVEL COMPLETE =================
  Future<void> completeLevel(
    int world,
    int level,
    int timeInSeconds,
    int stars,
  ) async {
    var progress = await loadProgress();

    int globalLevel = (world - 1) * levelsPerWorld + level;

    List<int> completed = List<int>.from(progress["completedLevels"]);
    Map<String, int> bestTimes =
        Map<String, int>.from(progress["bestTimes"]);
    Map<String, int> starsMap =
        Map<String, int>.from(progress["stars"]);

    /// Add completed level
    if (!completed.contains(globalLevel)) {
      completed.add(globalLevel);
    }

    /// Best time (lower is better)
    if (!bestTimes.containsKey(globalLevel.toString()) ||
        timeInSeconds < bestTimes[globalLevel.toString()]!) {
      bestTimes[globalLevel.toString()] = timeInSeconds;
    }

    /// Stars (higher is better)
    if (!starsMap.containsKey(globalLevel.toString()) ||
        stars > starsMap[globalLevel.toString()]!) {
      starsMap[globalLevel.toString()] = stars;
    }

    /// Unlock next level
    int currentLevel = progress["currentLevel"];
    if (currentLevel <= globalLevel) {
      progress["currentLevel"] = globalLevel + 1;
    }

    /// Unlock next world
    if (level == levelsPerWorld) {
      int highestWorld = progress["highestUnlockedWorld"];
      if (highestWorld <= world) {
        progress["highestUnlockedWorld"] = world + 1;
      }
    }

    /// Save
    progress["completedLevels"] = completed;
    progress["bestTimes"] = bestTimes;
    progress["stars"] = starsMap;

    await saveProgress(progress);
  }

  /// ================= WORLD HELPERS =================

  int getWorldFromLevel(int level) {
    return ((level - 1) ~/ levelsPerWorld) + 1;
  }

  Future<int> getHighestUnlockedWorld() async {
    var progress = await loadProgress();
    return progress["highestUnlockedWorld"];
  }

  Future<bool> isWorldCompleted(int world) async {
    var progress = await loadProgress();

    List<int> completed = List<int>.from(progress["completedLevels"]);

    int startLevel = (world - 1) * levelsPerWorld + 1;
    int endLevel = world * levelsPerWorld;

    for (int i = startLevel; i <= endLevel; i++) {
      if (!completed.contains(i)) return false;
    }
    return true;
  }

  /// ================= WORLD STAR CALCULATION =================

  Future<int> getStarsForWorld(int world) async {
    var progress = await loadProgress();

    Map<String, int> starsMap =
        Map<String, int>.from(progress["stars"]);

    int totalStars = 0;

    int startLevel = (world - 1) * levelsPerWorld + 1;
    int endLevel = world * levelsPerWorld;

    for (int level = startLevel; level <= endLevel; level++) {
      totalStars += starsMap[level.toString()] ?? 0;
    }

    return totalStars;
  }

  Future<void> unlockNextWorld(int world) async {
    var progress = await loadProgress();

    int highestWorld = progress["highestUnlockedWorld"];

    if (highestWorld <= world) {
      progress["highestUnlockedWorld"] = world + 1;
    }

    await saveProgress(progress);
  }

  /// ================= LEVEL HELPERS =================

  Future<void> saveLevelProgress({
    required int world,
    required int levelNumber,
    required int stars,
    required int time,
  }) async {
    await completeLevel(world, levelNumber, time, stars);
  }

  Future<void> unlockNextLevel(int level) async {
    var progress = await loadProgress();

    int currentLevel = progress["currentLevel"];

    if (currentLevel <= level) {
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

    Map<String, int> starsMap =
        Map<String, int>.from(progress["stars"]);

    return starsMap[level.toString()] ?? 0;
  }

  Future<int?> getBestTime(int level) async {
    var progress = await loadProgress();

    Map<String, int> bestTimes =
        Map<String, int>.from(progress["bestTimes"]);

    return bestTimes[level.toString()];
  }

  Future<void> resetProgress() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_progressKey);
  }

  Future<List<int>> getVisibleLevels() async {
    int currentLevel = await getCurrentLevel();

    /// ✅ FIX: removed hardcoded 25
    int maxVisible =
        ((currentLevel - 1) ~/ levelsPerWorld + 1) *
            levelsPerWorld;

    List<int> levels = [];

    for (int i = 1; i <= maxVisible; i++) {
      levels.add(i);
    }

    return levels;
  }
}