import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// ============================================================================
/// ProgressService
/// ----------------------------------------------------------------------------
/// Handles:
/// - Level progression
/// - World unlocking
/// - Stars & best time tracking
/// - Global ↔ World/Level mapping
///
/// Architecture:
/// - Global Level = Single source of truth for progression
/// - World/Level = Derived for UI & navigation
/// ============================================================================

class ProgressService {
  /// Key used to store progress in SharedPreferences
  static const String _progressKey = "sudoku_progress";

  /// Total number of levels per world
  static const int levelsPerWorld = 25;

  /// ==========================================================================
  /// DEFAULT PROGRESS STRUCTURE
  /// ==========================================================================
  /// This ensures app never crashes due to missing fields
  Map<String, dynamic> _defaultProgress() {
    return {
      "currentLevel": 1, // Next playable GLOBAL level
      "completedLevels": <int>[], // List of completed GLOBAL levels
      "bestTimes": <String, int>{}, // "globalLevel" -> best time (seconds)
      "stars": <String, int>{}, // "globalLevel" -> stars (0–3)
      "highestUnlockedWorld": 1, // Cached for UI performance
    };
  }

  /// ==========================================================================
  /// LOAD PROGRESS (WITH STRONG TYPE SAFETY)
  /// ==========================================================================
  Future<Map<String, dynamic>> loadProgress() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString(_progressKey);

    /// If no saved data → return default structure
    if (data == null) {
      return _defaultProgress();
    }

    Map<String, dynamic> progress = jsonDecode(data);

    /// 🔒 Type Safety Enforcement (Prevents runtime crashes)
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

  /// ==========================================================================
  /// SAVE PROGRESS
  /// ==========================================================================
  Future<void> saveProgress(Map<String, dynamic> progress) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_progressKey, jsonEncode(progress));
  }

  /// ==========================================================================
  /// GLOBAL ↔ WORLD/LEVEL CONVERSION HELPERS
  /// ==========================================================================
  /// These are CRITICAL to avoid navigation bugs

  /// Convert (world, level) → global level
  int getGlobalLevel(int world, int level) {
    return (world - 1) * levelsPerWorld + level;
  }

  /// Convert global level → world
  int getWorldFromGlobal(int globalLevel) {
    return ((globalLevel - 1) ~/ levelsPerWorld) + 1;
  }

  /// Convert global level → level inside world
  int getLevelInWorld(int globalLevel) {
    return ((globalLevel - 1) % levelsPerWorld) + 1;
  }

  /// Convert global level → {world, level}
  Map<String, int> getWorldAndLevel(int globalLevel) {
    return {
      "world": getWorldFromGlobal(globalLevel),
      "level": getLevelInWorld(globalLevel),
    };
  }

  /// ==========================================================================
  /// LEVEL COMPLETION LOGIC
  /// ==========================================================================
  /// Handles:
  /// - Mark level completed
  /// - Update best time
  /// - Update stars
  /// - Unlock next level
  /// - Unlock next world
  Future<void> completeLevel(
    int world,
    int level,
    int timeInSeconds,
    int stars,
  ) async {
    var progress = await loadProgress();

    /// Convert to GLOBAL level (single source of truth)
    int globalLevel = getGlobalLevel(world, level);

    /// Extract stored data safely
    List<int> completed = List<int>.from(progress["completedLevels"]);
    Map<String, int> bestTimes =
        Map<String, int>.from(progress["bestTimes"]);
    Map<String, int> starsMap =
        Map<String, int>.from(progress["stars"]);

    /// ✅ Mark level as completed
    if (!completed.contains(globalLevel)) {
      completed.add(globalLevel);
    }

    /// ✅ Update best time (lower is better)
    if (!bestTimes.containsKey(globalLevel.toString()) ||
        timeInSeconds < bestTimes[globalLevel.toString()]!) {
      bestTimes[globalLevel.toString()] = timeInSeconds;
    }

    /// ✅ Update stars (higher is better)
    if (!starsMap.containsKey(globalLevel.toString()) ||
        stars > starsMap[globalLevel.toString()]!) {
      starsMap[globalLevel.toString()] = stars;
    }

    /// ✅ Unlock next level (Continue button logic depends on this)
    int currentLevel = progress["currentLevel"];
    if (currentLevel <= globalLevel) {
      progress["currentLevel"] = globalLevel + 1;
    }

    /// ✅ Unlock next world ONLY if last level of world is completed
    if (level == levelsPerWorld) {
      int highestWorld = progress["highestUnlockedWorld"];
      if (highestWorld <= world) {
        progress["highestUnlockedWorld"] = world + 1;
      }
    }

    /// Save updated values
    progress["completedLevels"] = completed;
    progress["bestTimes"] = bestTimes;
    progress["stars"] = starsMap;

    await saveProgress(progress);
  }

  /// ==========================================================================
  /// WORLD HELPERS
  /// ==========================================================================

  /// Get highest unlocked world
  Future<int> getHighestUnlockedWorld() async {
    var progress = await loadProgress();
    return progress["highestUnlockedWorld"];
  }

  /// Check if all levels in a world are completed
  Future<bool> isWorldCompleted(int world) async {
    var progress = await loadProgress();

    List<int> completed = List<int>.from(progress["completedLevels"]);

    int start = getGlobalLevel(world, 1);
    int end = getGlobalLevel(world, levelsPerWorld);

    for (int i = start; i <= end; i++) {
      if (!completed.contains(i)) return false;
    }
    return true;
  }

  /// Get total stars earned in a world
  Future<int> getStarsForWorld(int world) async {
    var progress = await loadProgress();

    Map<String, int> starsMap =
        Map<String, int>.from(progress["stars"]);

    int totalStars = 0;

    int start = getGlobalLevel(world, 1);
    int end = getGlobalLevel(world, levelsPerWorld);

    for (int i = start; i <= end; i++) {
      totalStars += starsMap[i.toString()] ?? 0;
    }

    return totalStars;
  }

  /// ==========================================================================
  /// LEVEL HELPERS
  /// ==========================================================================

  /// Wrapper for saving level completion
  Future<void> saveLevelProgress({
    required int world,
    required int levelNumber,
    required int stars,
    required int time,
  }) async {
    await completeLevel(world, levelNumber, time, stars);
  }

  /// Get next playable GLOBAL level (used by Continue button)
  Future<int> getNextUnlockedLevel() async {
    var progress = await loadProgress();
    return progress["currentLevel"];
  }

  /// Check if a GLOBAL level is unlocked
  Future<bool> isLevelUnlocked(int globalLevel) async {
    int currentLevel = await getNextUnlockedLevel();
    return globalLevel <= currentLevel;
  }

  /// Get stars for a GLOBAL level
  Future<int> getStars(int globalLevel) async {
    var progress = await loadProgress();

    Map<String, int> starsMap =
        Map<String, int>.from(progress["stars"]);

    return starsMap[globalLevel.toString()] ?? 0;
  }

  /// Get best time for a GLOBAL level
  Future<int?> getBestTime(int globalLevel) async {
    var progress = await loadProgress();

    Map<String, int> bestTimes =
        Map<String, int>.from(progress["bestTimes"]);

    return bestTimes[globalLevel.toString()];
  }

  /// Reset all progress (use during testing/debugging)
  Future<void> resetProgress() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_progressKey);
  }

  /// ==========================================================================
  /// UI HELPERS
  /// ==========================================================================

  /// Get all visible levels (ensures full world visibility)
  Future<List<int>> getVisibleLevels() async {
    int currentLevel = await getNextUnlockedLevel();

    /// Ensures entire world is visible in UI
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