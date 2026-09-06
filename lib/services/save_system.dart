import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:sudoku_game/models/level_data.dart';

/// ============================================================================
/// SaveSystem
/// ----------------------------------------------------------------------------
/// Handles persistence of legacy/current level-specific save data.
///
/// Responsibilities:
/// - Save/load the current world and level.
/// - Save/load per-level [LevelData].
/// - Load all valid saved level data.
/// - Clear only data owned by this service.
///
/// Architecture:
/// - Singleton service.
/// - SharedPreferences for local persistence.
/// - Defensive validation and error handling.
/// - Invalid/corrupt individual level saves do not prevent other saves from
///   being loaded.
///
/// IMPORTANT:
/// [ProgressService] should remain the canonical source of truth for global
/// progression in the current architecture.
///
/// This service should therefore be used only for level-specific data that is
/// not already managed by ProgressService.
///
/// Public API is preserved for compatibility.
/// ============================================================================

class SaveSystem {
  // ==========================================================================
  // SINGLETON
  // ==========================================================================

  static final SaveSystem _instance = SaveSystem._internal();

  factory SaveSystem() => _instance;

  SaveSystem._internal();

  // ==========================================================================
  // STORAGE KEYS
  // ==========================================================================

  static const String _currentWorldKey = 'current_world';
  static const String _currentLevelKey = 'current_level';

  /// Prefix for per-level save records.
  static const String _levelDataKey = 'level_data';

  /// Default starting world.
  static const int _defaultWorldId = 1;

  /// Default starting level.
  static const int _defaultLevelId = 1;

  /// Minimum valid world/level identifiers.
  static const int _minimumId = 1;

  // ==========================================================================
  // SAVE CURRENT PROGRESS
  // ==========================================================================

  /// Saves the current world and level.
  ///
  /// The values are validated before persistence.
  ///
  /// Throws:
  /// - [ArgumentError] for invalid IDs.
  /// - [StateError] if SharedPreferences cannot be accessed.
  /// - [Exception] if persistence fails.
  Future<void> saveCurrentProgress({
    required int worldId,
    required int levelId,
  }) async {
    _validateId(worldId, 'worldId');
    _validateId(levelId, 'levelId');

    final prefs = await _getPreferences();

    try {
      final worldSaved = await prefs.setInt(_currentWorldKey, worldId);

      if (!worldSaved) {
        throw Exception('SharedPreferences could not save current world.');
      }

      final levelSaved = await prefs.setInt(_currentLevelKey, levelId);

      if (!levelSaved) {
        throw Exception('SharedPreferences could not save current level.');
      }
    } catch (e) {
      throw Exception('Could not save current progress: $e');
    }
  }

  // ==========================================================================
  // LOAD CURRENT PROGRESS
  // ==========================================================================

  /// Loads the saved current world and level.
  ///
  /// Missing values safely fall back to world 1 / level 1.
  ///
  /// Invalid persisted values are also replaced with safe defaults.
  Future<Map<String, int>> loadCurrentProgress() async {
    final prefs = await _getPreferences();

    final storedWorld = prefs.getInt(_currentWorldKey);
    final storedLevel = prefs.getInt(_currentLevelKey);

    final worldId = _isValidId(storedWorld) ? storedWorld! : _defaultWorldId;

    final levelId = _isValidId(storedLevel) ? storedLevel! : _defaultLevelId;

    return <String, int>{'worldId': worldId, 'levelId': levelId};
  }

  // ==========================================================================
  // SAVE LEVEL DATA
  // ==========================================================================

  /// Saves level-specific data.
  ///
  /// [levelId] is expected to be the canonical/global level identifier.
  Future<void> saveLevelData(int levelId, LevelData data) async {
    _validateId(levelId, 'levelId');

    final prefs = await _getPreferences();
    final key = _getLevelDataKey(levelId);

    try {
      final encodedData = jsonEncode(data.toJson());

      final saved = await prefs.setString(key, encodedData);

      if (!saved) {
        throw Exception('SharedPreferences could not save level data.');
      }
    } on FormatException catch (e) {
      throw Exception('Could not encode level $levelId data: $e');
    } catch (e) {
      throw Exception('Could not save level $levelId data: $e');
    }
  }

  // ==========================================================================
  // LOAD LEVEL DATA
  // ==========================================================================

  /// Loads level-specific data.
  ///
  /// Returns null when:
  /// - no save exists for the level, or
  /// - the stored save is malformed.
  ///
  /// A malformed save is ignored rather than crashing the application.
  Future<LevelData?> loadLevelData(int levelId) async {
    _validateId(levelId, 'levelId');

    final prefs = await _getPreferences();
    final key = _getLevelDataKey(levelId);

    final encodedData = prefs.getString(key);

    if (encodedData == null || encodedData.trim().isEmpty) {
      return null;
    }

    try {
      final decodedData = jsonDecode(encodedData);

      if (decodedData is! Map) {
        return null;
      }

      return LevelData.fromJson(Map<String, dynamic>.from(decodedData));
    } catch (e, stackTrace) {
      _logCorruptLevelData(levelId, e, stackTrace);

      return null;
    }
  }

  // ==========================================================================
  // LOAD ALL LEVEL DATA
  // ==========================================================================

  /// Loads all valid level-specific saves.
  ///
  /// Invalid keys and corrupt individual records are skipped.
  ///
  /// This means one corrupt save cannot prevent the rest of the player's
  /// saved levels from loading.
  Future<Map<int, LevelData>> loadAllLevelData() async {
    final prefs = await _getPreferences();

    final result = <int, LevelData>{};

    for (final key in prefs.getKeys()) {
      final levelId = _parseLevelIdFromKey(key);

      if (levelId == null) {
        continue;
      }

      final encodedData = prefs.getString(key);

      if (encodedData == null || encodedData.trim().isEmpty) {
        continue;
      }

      try {
        final decodedData = jsonDecode(encodedData);

        if (decodedData is! Map) {
          continue;
        }

        final levelData = LevelData.fromJson(
          Map<String, dynamic>.from(decodedData),
        );

        result[levelId] = levelData;
      } catch (e, stackTrace) {
        _logCorruptLevelData(levelId, e, stackTrace);

        // Continue loading the remaining level saves.
      }
    }

    return result;
  }

  // ==========================================================================
  // CLEAR SAVED DATA
  // ==========================================================================

  /// Clears data owned by [SaveSystem].
  ///
  /// IMPORTANT:
  /// This intentionally does NOT call `SharedPreferences.clear()`.
  ///
  /// Calling `clear()` would also delete data belonging to:
  /// - UserService
  /// - ProgressService
  /// - Settings
  /// - Other application services
  ///
  /// Only SaveSystem-owned keys are removed.
  Future<void> clearAllData() async {
    final prefs = await _getPreferences();

    try {
      final keysToRemove = <String>[];

      for (final key in prefs.getKeys()) {
        if (_isOwnedKey(key)) {
          keysToRemove.add(key);
        }
      }

      for (final key in keysToRemove) {
        final removed = await prefs.remove(key);

        if (!removed && prefs.containsKey(key)) {
          throw Exception('SharedPreferences could not remove key "$key".');
        }
      }
    } catch (e) {
      throw Exception('Could not clear saved game data: $e');
    }
  }

  // ==========================================================================
  // KEY HELPERS
  // ==========================================================================

  /// Builds the storage key for a specific global level.
  String _getLevelDataKey(int levelId) {
    return '${_levelDataKey}_$levelId';
  }

  /// Extracts the level ID from a level-data key.
  ///
  /// Valid examples:
  ///   level_data_1
  ///   level_data_25
  ///
  /// Invalid examples:
  ///   level_data
  ///   level_data_abc
  ///   level_data_0
  int? _parseLevelIdFromKey(String key) {
    const prefix = '${_levelDataKey}_';

    if (!key.startsWith(prefix)) {
      return null;
    }

    final suffix = key.substring(prefix.length);

    if (suffix.isEmpty) {
      return null;
    }

    final levelId = int.tryParse(suffix);

    if (!_isValidId(levelId)) {
      return null;
    }

    return levelId;
  }

  /// Returns true for keys owned by SaveSystem.
  bool _isOwnedKey(String key) {
    return key == _currentWorldKey ||
        key == _currentLevelKey ||
        key.startsWith('${_levelDataKey}_');
  }

  // ==========================================================================
  // VALIDATION
  // ==========================================================================

  void _validateId(int id, String parameterName) {
    if (id < _minimumId) {
      throw ArgumentError.value(
        id,
        parameterName,
        '$parameterName must be at least $_minimumId.',
      );
    }
  }

  bool _isValidId(int? id) {
    return id != null && id >= _minimumId;
  }

  // ==========================================================================
  // SHARED PREFERENCES
  // ==========================================================================

  Future<SharedPreferences> _getPreferences() async {
    try {
      return await SharedPreferences.getInstance();
    } catch (e) {
      throw StateError('SaveSystem could not access local storage: $e');
    }
  }

  // ==========================================================================
  // ERROR LOGGING
  // ==========================================================================

  void _logCorruptLevelData(int levelId, Object error, StackTrace stackTrace) {
    // Avoid throwing from persistence recovery.
    //
    // This remains useful during development and diagnostics while allowing
    // the application to continue loading other valid saves.
    //
    // ignore: avoid_print
    print('SaveSystem: corrupt data for level $levelId: $error');

    // ignore: avoid_print
    print(stackTrace);
  }
}
