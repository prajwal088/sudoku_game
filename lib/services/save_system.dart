import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sudoku_game/models/level_data.dart';

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
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_currentWorldKey, worldId);
    await prefs.setInt(_currentLevelKey, levelId);
  }

  /// Load current world and level
  Future<Map<String, int>> loadCurrentProgress() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'worldId': prefs.getInt(_currentWorldKey) ?? 1,
      'levelId': prefs.getInt(_currentLevelKey) ?? 1,
    };
  }

  /// Save level data (stars, time, hints)
  Future<void> saveLevelData(int levelId, LevelData data) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '[_levelDataKey}_$levelId';
    await prefs.setString(key, jsonEncode(data.toJson()));
  }

  /// Load level data for a specific level
  Future<LevelData?> loadLevelData(int levelId) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '${_levelDataKey}_$levelId';
    final data = prefs.getString(key);
    
    if (data == null) return null;
    return LevelData.fromJson(jsonDecode(data));
  }

  /// Load all level data
  Future<Map<int, LevelData>> loadAllLevelData() async {
    final prefs = await SharedPreferences.getInstance();
    final result = <int, LevelData>{};
    
    final keys = prefs.getKeys();
    for (final key in keys) {
      if (key.startsWith(_levelDataKey)) {
        final levelId = int.parse(key.split('_')[1]);
        final data = prefs.getString(key);
        if (data != null) {
          result[levelId] = LevelData.fromJson(jsonDecode(data));
        }
      }
    }
    
    return result;
  }

  /// Clear all saved data
  Future<void> clearAllData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }
}