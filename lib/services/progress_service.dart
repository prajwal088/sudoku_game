import 'dart:convert';
import 'dart:async';
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

  // Singleton pattern so all screens share the same Stream controllers
  static final ProgressService _instance = ProgressService._internal();
  factory ProgressService() => _instance;
  ProgressService._internal();

  /// Key used to store progress in SharedPreferences
  static const String _progressKey = "sudoku_progress";

  /// Total number of levels per world
  static const int levelsPerWorld = 25;

  final StreamController<int> _worldCompletionController = StreamController<int>.broadcast();
  Stream<int> get onWorldCompleted => _worldCompletionController.stream;

  final StreamController<void> _progressUpdateController = StreamController<void>.broadcast();
  Stream<void> get onProgressUpdate => _progressUpdateController.stream;

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
    // Ensure lists and maps are cast correctly to avoid type errors
    progress["completedLevels"] = List<int>.from(progress["completedLevels"] ?? []);
    progress["bestTimes"] = Map<String, int>.from(progress["bestTimes"] ?? {});
    progress["stars"] = Map<String, int>.from(progress["stars"] ?? {});
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
  Future<void> completeLevel({
    required int globalLevel,
    required int timeInSeconds,
    required int stars,
  }) async {
    var progress = await loadProgress();

    // ✅ PROFESSIONAL APPROACH: Use Sets for O(1) lookup performance
    Set<int> completed = Set<int>.from(progress["completedLevels"]);
    Map<String, int> bestTimes = Map<String, int>.from(progress["bestTimes"]);
    Map<String, int> starsMap = Map<String, int>.from(progress["stars"]);

    completed.add(globalLevel);

    // Update Best Time (Lower is better)
    String key = globalLevel.toString();
    if (!bestTimes.containsKey(key) || timeInSeconds < bestTimes[key]!) {
      bestTimes[key] = timeInSeconds;
    }

    // Update Stars (Higher is better)
    if (!starsMap.containsKey(key) || stars > starsMap[key]!) {
      starsMap[key] = stars;
    }

    // Unlock next level logic
    if (progress["currentLevel"] == globalLevel) {
      progress["currentLevel"] = globalLevel + 1;
    }

    // Unlock next world gatekeeper
    int worldOfCompletedLevel = getWorldFromGlobal(globalLevel);
    int localLevel = getLevelInWorld(globalLevel);
    
if (localLevel == levelsPerWorld) {
      // Trigger the stream when a world is finished
      _worldCompletionController.add(worldOfCompletedLevel);

      if (progress["highestUnlockedWorld"] <= worldOfCompletedLevel) {
        progress["highestUnlockedWorld"] = worldOfCompletedLevel + 1;
      }
    }

    progress["completedLevels"] = completed.toList();
    progress["bestTimes"] = bestTimes;
    progress["stars"] = starsMap;

    await saveProgress(progress);

    // Tell everyone listening that data has changed!
    _progressUpdateController.add(null);
  }

  /// ==========================================================================
  /// WORLD HELPERS
  /// ==========================================================================
  
  // --- STATISTICS HELPER ---
  /// Fetches aggregated data for the Statistics Screen
  Future<Map<String, dynamic>> getGlobalStats() async {
    final progress = await loadProgress();
    
    // Convert keys to a list to count them
    final Map<String, int> bestTimes = Map<String, int>.from(progress["bestTimes"]);
    final Map<String, int> starsMap = Map<String, int>.from(progress["stars"]);
    final List<int> completed = List<int>.from(progress["completedLevels"]);
    final int highestWorld = progress["highestUnlockedWorld"] ?? 1;

    // 1. Calculate Totals
    int totalStars = 0;
    starsMap.forEach((_, value) => totalStars += value);

    int totalTime = 0;
    bestTimes.forEach((_, value) => totalTime += value);

    // 2. Calculate Averages based ONLY on completed levels
    double avgSpeed = completed.isEmpty ? 0 : totalTime / completed.length;

    // 3. Dynamic Completion Logic
    // We compare completed levels against the total levels available in 
    // all worlds the user has currently unlocked.
    int availableLevels = highestWorld * levelsPerWorld;
    double completionPercent = completed.isEmpty ? 0 : completed.length / availableLevels;

    return {
      "totalLevels": completed.length,
      "totalStars": totalStars,
      "totalTime": totalTime,
      "avgSpeed": avgSpeed.round(),
      "completionPercent": completionPercent.clamp(0.0, 1.0),
    };
  }

  /// Get highest unlocked world
  Future<int> getHighestUnlockedWorld() async {
    final progress = await loadProgress();
    return progress["highestUnlockedWorld"] ?? 1;
  }

  Future<int> getNextUnlockedLevel() async {
    final progress = await loadProgress();
    return progress["currentLevel"] ?? 1;
  }

  // Optimized helper to avoid 10 loop database reads in the UI
  Future<Map<int, int>> getAllWorldStars(int totalWorlds) async {
    final progress = await loadProgress();
    final Map<String, int> starsMap = Map<String, int>.from(progress["stars"] ?? {});

    Map<int, int> worldStars = {};
    for (int w = 1; w <= totalWorlds; w++) {
      int total = 0;
      int start = getGlobalLevel(w, 1);
      int end = getGlobalLevel(w, levelsPerWorld);
      for (int i = start; i <= end; i++) {
        total += starsMap[i.toString()] ?? 0;
      }
      worldStars[w] = total;
    }
    return worldStars;
  }

  /// Get total stars earned in a world (Add this to ProgressService)
  Future<int> getStarsForWorld(int world) async {
    final progress = await loadProgress();
    final Map<String, int> starsMap = Map<String, int>.from(progress["stars"] ?? {});

    int totalStars = 0;
    int start = getGlobalLevel(world, 1);
    int end = getGlobalLevel(world, levelsPerWorld);

    for (int i = start; i <= end; i++) {
      totalStars += starsMap[i.toString()] ?? 0;
    }

    return totalStars;
  }

  /// Checks if the level just played is the one the user was "stuck" on.
  /// If it is lower than currentLevel, it's a replay.
  Future<bool> isReplayingLevel(int globalLevel) async {
    final progress = await loadProgress();
    int current = progress["currentLevel"] ?? 1;
    
  // If the level played is less than the current unlocked level, 
  // it means they are replaying an old one.
  return globalLevel < current;
}

  Future<void> resetProgress() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_progressKey);
  }

  // Dispose for the stream
  void dispose() {
    _worldCompletionController.close();
  }
}