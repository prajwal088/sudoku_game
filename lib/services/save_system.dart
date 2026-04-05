import 'dart:convert';
import 'package:flutter/foundation.dart'; // For debugPrint
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sudoku_game/models/level_data.dart';
import 'analytics_service.dart';

class SaveSystem {
  static final SaveSystem _instance = SaveSystem._internal();
  
  factory SaveSystem() {
    return _instance;
  }
  
  SaveSystem._internal();

  static const String _currentWorldKey = 'current_world';
  static const String _currentLevelKey = 'current_level';
  static const String _levelDataKey = 'level_data';

  /// Save current world and level
  Future<void> saveCurrentProgress({
    required int worldId,
    required int levelId,
  }) async {
    try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_currentWorldKey, worldId);
    await prefs.setInt(_currentLevelKey, levelId);
    } catch (e) {
      AnalyticsService.logError("save_progress_io_error", e.toString());
    }
  }

  /// Load current world and level
  Future<Map<String, int>> loadCurrentProgress() async {
    try {
    final prefs = await SharedPreferences.getInstance();
    return {
      'worldId': prefs.getInt(_currentWorldKey) ?? 1,
      'levelId': prefs.getInt(_currentLevelKey) ?? 1,
    };
    } catch (e) {
      AnalyticsService.logError("load_progress_io_error", e.toString());
      return {'worldId': 1, 'levelId': 1};
    }
  }

  /// Save level data (stars, time, hints)
  Future<void> saveLevelData(int levelId, LevelData data) async {
    try {
    final prefs = await SharedPreferences.getInstance();
    final key = '[_levelDataKey}_$levelId';
    await prefs.setString(key, jsonEncode(data.toJson()));
    } catch (e) {
      // Track: Disk full or serialization errors
      AnalyticsService.logError("save_level_data_fail", "Level: $levelId | Error: $e");
    }
  }

  /// Load level data for a specific level
  Future<LevelData?> loadLevelData(int levelId) async {
    try {
    final prefs = await SharedPreferences.getInstance();
    final key = '${_levelDataKey}_$levelId';
    final data = prefs.getString(key);
    
    if (data == null) return null;
    return LevelData.fromJson(jsonDecode(data));
    } catch (e) {
      // Track: Data corruption (invalid JSON)
      AnalyticsService.logError("load_level_data_corrupt", "Level: $levelId | Error: $e");
      return null;
    }
  }

  /// Load all level data
  Future<Map<int, LevelData>> loadAllLevelData() async {
    try {
    final prefs = await SharedPreferences.getInstance();
    final result = <int, LevelData>{};
    
    final keys = prefs.getKeys();
    for (final key in keys) {
      if (key.startsWith(_levelDataKey)) {
        // Wrap inner parsing in try-catch to skip corrupted keys without crashing the whole list
          try {
            final parts = key.split('_');
            if (parts.length < 3) continue; // Ensure correct format
            
            final levelId = int.parse(parts[2]);
            final data = prefs.getString(key);
            if (data != null) {
              result[levelId] = LevelData.fromJson(jsonDecode(data));
            }
          } catch (innerError) {
            debugPrint("Skipping corrupted key: $key");
          }
      }
    }
    
    return result;
    } catch (e) {
      AnalyticsService.logError("load_all_data_critical_fail", e.toString());
      return {};
    }
  }

  /// Clear all saved data
  Future<void> clearAllData() async {
    try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    } catch (e) {
      AnalyticsService.logError("clear_data_io_error", e.toString());
    }
  }
}