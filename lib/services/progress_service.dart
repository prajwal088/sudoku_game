import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// ============================================================================
/// ProgressService
/// ----------------------------------------------------------------------------
/// Single source of truth for Sudoku gameplay progression.
///
/// Responsibilities:
/// - Global level progression
/// - World unlocking
/// - Completed levels
/// - Best completion times
/// - Stars
/// - Global <-> world/level mapping
/// - Global statistics
/// - World statistics
/// - Replay detection
/// - Progress reset
/// - Progress update notifications
/// - Local persistence
///
/// Architecture:
/// - Global level is the canonical level identifier.
/// - World and local level are derived from the global level.
/// - [completedLevels] is the authoritative progression state.
/// - [currentLevel] is derived from completed levels.
/// - [highestUnlockedWorld] is derived from completed levels.
/// - SharedPreferences provides local persistence.
/// - Progress is cached in memory after initialization.
/// - Mutations are serialized to prevent concurrent-write races.
/// - Returned progress maps are defensive copies.
///
/// IMPORTANT:
/// Call:
///
/// ```dart
/// await ProgressService().init();
/// ```
///
/// before using progression APIs.
///
/// This service is a singleton and is intended to live for the lifetime
/// of the application.
/// ============================================================================
class ProgressService {
  // ==========================================================================
  // SINGLETON
  // ==========================================================================

  static final ProgressService _instance = ProgressService._internal();

  factory ProgressService() => _instance;

  ProgressService._internal();

  // ==========================================================================
  // STORAGE
  // ==========================================================================

  static const String _progressKey = 'sudoku_progress';

  /// Current persistence schema version.
  ///
  /// Increment this when the persisted structure changes and add migration
  /// logic when required.
  static const int _progressVersion = 1;

  // ==========================================================================
  // GAME CONFIGURATION - SINGLE SOURCE OF TRUTH
  // ==========================================================================

  /// Number of levels contained in one world.
  ///
  /// This is the authoritative value used by the entire progression system.
  static const int levelsPerWorld = 25;

  /// Number of worlds contained in the game.
  static const int totalWorlds = 10;

  /// Total number of playable global levels.
  static const int totalLevels = levelsPerWorld * totalWorlds;

  static const int _firstLevel = 1;
  static const int _firstWorld = 1;

  static const int _minimumStars = 0;
  static const int _maximumStars = 3;

  // ==========================================================================
  // STREAMS
  // ==========================================================================

  final StreamController<int> _worldCompletionController =
      StreamController<int>.broadcast();

  final StreamController<void> _progressUpdateController =
      StreamController<void>.broadcast();

  /// Emits the world number when that world is completed for the first time.
  Stream<int> get onWorldCompleted => _worldCompletionController.stream;

  /// Emits after progress has been successfully persisted.
  Stream<void> get onProgressUpdate => _progressUpdateController.stream;

  // ==========================================================================
  // STORAGE / CACHE
  // ==========================================================================

  SharedPreferences? _prefs;

  Map<String, dynamic>? _cachedProgress;

  bool _isInitialized = false;
  Future<void>? _initializationFuture;
  bool _isDisposed = false;

  // ==========================================================================
  // MUTATION QUEUE
  // ==========================================================================

  /// Serializes persistence mutations.
  ///
  /// This prevents concurrent operations from reading the same old state
  /// and subsequently overwriting each other's changes.
  Future<void> _mutationQueue = Future<void>.value();

  Future<T> _runMutation<T>(Future<T> Function() mutation) {
    final completer = Completer<T>();

    _mutationQueue = _mutationQueue.then((_) async {
      try {
        final result = await mutation();
        completer.complete(result);
      } catch (error, stackTrace) {
        completer.completeError(error, stackTrace);
      }
    });

    return completer.future;
  }

  // ==========================================================================
  // INITIALIZATION
  // ==========================================================================

  /// Initializes the service.
  ///
  /// Safe to call multiple times.
  ///
  /// Concurrent callers share the same initialization operation.
  Future<void> init() {
    _ensureNotDisposed();

    if (_isInitialized) {
      return Future<void>.value();
    }

    final existingFuture = _initializationFuture;

    if (existingFuture != null) {
      return existingFuture;
    }

    final future = _initialize();

    _initializationFuture = future;

    return future.whenComplete(() {
      if (identical(_initializationFuture, future)) {
        _initializationFuture = null;
      }
    });
  }

  Future<void> _initialize() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final progress = _loadProgressFromPreferences(prefs);

      _prefs = prefs;
      _cachedProgress = progress;
      _isInitialized = true;
    } catch (error, stackTrace) {
      _prefs = null;
      _cachedProgress = null;
      _isInitialized = false;

      Error.throwWithStackTrace(
        StateError('ProgressService initialization failed: $error'),
        stackTrace,
      );
    }
  }

  // ==========================================================================
  // DEFAULT PROGRESS
  // ==========================================================================

  Map<String, dynamic> _defaultProgress() {
    return <String, dynamic>{
      'version': _progressVersion,
      'currentLevel': _firstLevel,
      'completedLevels': <int>[],
      'bestTimes': <String, int>{},
      'stars': <String, int>{},
      'highestUnlockedWorld': _firstWorld,
    };
  }

  // ==========================================================================
  // LOAD PROGRESS
  // ==========================================================================

  /// Returns the current progress as a defensive copy.
  Future<Map<String, dynamic>> loadProgress() async {
    _ensureInitialized();

    final cached = _cachedProgress;

    if (cached == null) {
      throw StateError('ProgressService cache is unavailable.');
    }

    return _deepCopyProgress(cached);
  }

  Map<String, dynamic> _loadProgressFromPreferences(SharedPreferences prefs) {
    final rawData = prefs.getString(_progressKey);

    if (rawData == null || rawData.trim().isEmpty) {
      return _defaultProgress();
    }

    try {
      final decoded = jsonDecode(rawData);

      if (decoded is! Map) {
        return _defaultProgress();
      }

      final rawMap = Map<String, dynamic>.from(decoded);

      return _normalizeProgress(rawMap);
    } catch (_) {
      // Never crash the application because of corrupt local progress.
      //
      // The invalid stored value is intentionally not overwritten here.
      // This avoids destroying potentially recoverable data.
      return _defaultProgress();
    }
  }

  // ==========================================================================
  // NORMALIZATION
  // ==========================================================================

  /// Converts untrusted/persisted data into the canonical progress model.
  ///
  /// IMPORTANT:
  /// completedLevels is authoritative.
  ///
  /// currentLevel and highestUnlockedWorld are derived from completed levels
  /// and therefore cannot be used to bypass progression.
  Map<String, dynamic> _normalizeProgress(Map<String, dynamic> raw) {
    final completedLevels = _normalizeCompletedLevels(raw['completedLevels']);

    final bestTimes = _normalizeBestTimes(raw['bestTimes'], completedLevels);

    final stars = _normalizeStars(raw['stars'], completedLevels);

    final currentLevel = _deriveCurrentLevel(completedLevels);

    final highestUnlockedWorld = _deriveHighestUnlockedWorld(completedLevels);

    return <String, dynamic>{
      'version': _progressVersion,
      'currentLevel': currentLevel,
      'completedLevels': completedLevels.toList()..sort(),
      'bestTimes': bestTimes,
      'stars': stars,
      'highestUnlockedWorld': highestUnlockedWorld,
    };
  }

  Set<int> _normalizeCompletedLevels(dynamic rawCompleted) {
    final completedLevels = <int>{};

    if (rawCompleted is! List) {
      return completedLevels;
    }

    for (final value in rawCompleted) {
      final level = _parseIntOrNull(value);

      if (level != null && level >= _firstLevel && level <= totalLevels) {
        completedLevels.add(level);
      }
    }

    return completedLevels;
  }

  Map<String, int> _normalizeBestTimes(
    dynamic rawBestTimes,
    Set<int> completedLevels,
  ) {
    final bestTimes = <String, int>{};

    if (rawBestTimes is! Map) {
      return bestTimes;
    }

    rawBestTimes.forEach((key, value) {
      final level = int.tryParse(key.toString());
      final time = _parseIntOrNull(value);

      if (level == null ||
          !completedLevels.contains(level) ||
          time == null ||
          time <= 0) {
        return;
      }

      bestTimes[level.toString()] = time;
    });

    return bestTimes;
  }

  Map<String, int> _normalizeStars(dynamic rawStars, Set<int> completedLevels) {
    final stars = <String, int>{};

    if (rawStars is! Map) {
      return stars;
    }

    rawStars.forEach((key, value) {
      final level = int.tryParse(key.toString());
      final starValue = _parseIntOrNull(value);

      if (level == null ||
          !completedLevels.contains(level) ||
          starValue == null ||
          starValue < _minimumStars ||
          starValue > _maximumStars) {
        return;
      }

      stars[level.toString()] = starValue;
    });

    return stars;
  }

  /// Derives the next progression level from completed levels.
  ///
  /// Example:
  ///
  /// completed: [1, 2, 3]
  /// current:   4
  ///
  /// completed: [1, 2, 3, 4, ..., 250]
  /// current:   250
  ///
  /// The final level remains selected after the game is completed.
  int _deriveCurrentLevel(Set<int> completedLevels) {
    for (int level = _firstLevel; level <= totalLevels; level++) {
      if (!completedLevels.contains(level)) {
        return level;
      }
    }

    return totalLevels;
  }

  /// Derives the highest unlocked world from completed world boundaries.
  ///
  /// World 1 is always unlocked.
  ///
  /// World 2 becomes unlocked when the final level of World 1 is completed.
  /// World 3 becomes unlocked when the final level of World 2 is completed.
  /// And so on.
  int _deriveHighestUnlockedWorld(Set<int> completedLevels) {
    int highestWorld = _firstWorld;

    for (int world = _firstWorld; world < totalWorlds; world++) {
      final finalLevel = getGlobalLevel(world, levelsPerWorld);

      if (!completedLevels.contains(finalLevel)) {
        break;
      }

      highestWorld = world + 1;
    }

    return highestWorld;
  }

  // ==========================================================================
  // SAVE PROGRESS
  // ==========================================================================

  /// Persists supplied progress after canonical normalization.
  ///
  /// For normal gameplay, prefer [completeLevel] and [resetProgress].
  ///
  /// This method remains public for controlled migration/testing use.
  Future<void> saveProgress(Map<String, dynamic> progress) {
    _ensureInitialized();

    return _runMutation(() async {
      await _saveProgressInternal(progress);
    });
  }

  Future<void> _saveProgressInternal(Map<String, dynamic> progress) async {
    final prefs = _prefs;

    if (prefs == null) {
      throw StateError('ProgressService storage is unavailable.');
    }

    final normalized = _normalizeProgress(Map<String, dynamic>.from(progress));

    final encoded = jsonEncode(normalized);

    try {
      final saved = await prefs.setString(_progressKey, encoded);

      if (!saved) {
        throw StateError('SharedPreferences could not save progress.');
      }

      _cachedProgress = normalized;
    } catch (error, stackTrace) {
      Error.throwWithStackTrace(
        StateError('Could not save progress: $error'),
        stackTrace,
      );
    }
  }

  // ==========================================================================
  // LEVEL MAPPING
  // ==========================================================================

  /// Converts a world + local level into a global level.
  ///
  /// Examples:
  /// - World 1, Level 1  -> Global 1
  /// - World 1, Level 25 -> Global 25
  /// - World 2, Level 1  -> Global 26
  /// - World 10, Level 25 -> Global 250
  int getGlobalLevel(int world, int level) {
    _validateWorld(world);
    _validateLocalLevel(level);

    return ((world - 1) * levelsPerWorld) + level;
  }

  /// Converts a global level into its world number.
  int getWorldFromGlobal(int globalLevel) {
    _validateGlobalLevel(globalLevel);

    return ((globalLevel - 1) ~/ levelsPerWorld) + 1;
  }

  /// Converts a global level into its local level inside the world.
  int getLevelInWorld(int globalLevel) {
    _validateGlobalLevel(globalLevel);

    return ((globalLevel - 1) % levelsPerWorld) + 1;
  }

  /// Returns the world and local level for a global level.
  Map<String, int> getWorldAndLevel(int globalLevel) {
    _validateGlobalLevel(globalLevel);

    return <String, int>{
      'world': getWorldFromGlobal(globalLevel),
      'level': getLevelInWorld(globalLevel),
    };
  }

  /// Returns the first global level in [world].
  int getWorldFirstLevel(int world) {
    _validateWorld(world);

    return getGlobalLevel(world, _firstLevel);
  }

  /// Returns the last global level in [world].
  int getWorldLastLevel(int world) {
    _validateWorld(world);

    return getGlobalLevel(world, levelsPerWorld);
  }

  // ==========================================================================
  // COMPLETE LEVEL
  // ==========================================================================

  /// Completes a global level and persists the resulting progression.
  ///
  /// Rules:
  /// - New levels must be completed sequentially.
  /// - Completed levels may be replayed.
  /// - Best time is the lowest recorded time.
  /// - Best stars are the highest recorded stars.
  /// - Completing a world's final level unlocks the next world.
  /// - Notifications are emitted only after persistence succeeds.
  Future<void> completeLevel({
    required int globalLevel,
    required int timeInSeconds,
    required int stars,
  }) {
    _ensureInitialized();

    _validateGlobalLevel(globalLevel);

    if (timeInSeconds <= 0) {
      throw ArgumentError.value(
        timeInSeconds,
        'timeInSeconds',
        'Time must be greater than 0 seconds.',
      );
    }

    if (stars < _minimumStars || stars > _maximumStars) {
      throw ArgumentError.value(
        stars,
        'stars',
        'Stars must be between '
            '$_minimumStars and $_maximumStars.',
      );
    }

    return _runMutation(() async {
      final cached = _cachedProgress;

      if (cached == null) {
        throw StateError('ProgressService cache is unavailable.');
      }

      final progress = _deepCopyProgress(cached);

      final completed = <int>{
        ...List<int>.from(progress['completedLevels'] as List<int>),
      };

      final bestTimes = <String, int>{
        ...Map<String, int>.from(progress['bestTimes'] as Map<String, int>),
      };

      final starsMap = <String, int>{
        ...Map<String, int>.from(progress['stars'] as Map<String, int>),
      };

      final currentLevel = _deriveCurrentLevel(completed);

      final previousHighestWorld = _deriveHighestUnlockedWorld(completed);

      final wasAlreadyCompleted = completed.contains(globalLevel);

      // ----------------------------------------------------------------------
      // SEQUENTIAL PROGRESSION
      // ----------------------------------------------------------------------

      if (!wasAlreadyCompleted && globalLevel != currentLevel) {
        throw StateError(
          'Cannot complete level $globalLevel. '
          'Current progression level is $currentLevel.',
        );
      }

      final levelKey = globalLevel.toString();

      // ----------------------------------------------------------------------
      // COMPLETION
      // ----------------------------------------------------------------------

      completed.add(globalLevel);

      // ----------------------------------------------------------------------
      // BEST TIME
      // ----------------------------------------------------------------------

      final previousBestTime = bestTimes[levelKey];

      if (previousBestTime == null || timeInSeconds < previousBestTime) {
        bestTimes[levelKey] = timeInSeconds;
      }

      // ----------------------------------------------------------------------
      // BEST STARS
      // ----------------------------------------------------------------------

      final previousStars = starsMap[levelKey];

      if (previousStars == null || stars > previousStars) {
        starsMap[levelKey] = stars;
      }

      // ----------------------------------------------------------------------
      // DERIVED PROGRESSION
      // ----------------------------------------------------------------------

      final newCurrentLevel = _deriveCurrentLevel(completed);

      final newHighestUnlockedWorld = _deriveHighestUnlockedWorld(completed);

      final world = getWorldFromGlobal(globalLevel);

      final localLevel = getLevelInWorld(globalLevel);

      final isNewWorldCompletion =
          !wasAlreadyCompleted && localLevel == levelsPerWorld;

      final updatedProgress = <String, dynamic>{
        'version': _progressVersion,
        'currentLevel': newCurrentLevel,
        'completedLevels': completed.toList()..sort(),
        'bestTimes': bestTimes,
        'stars': starsMap,
        'highestUnlockedWorld': newHighestUnlockedWorld,
      };

      // Persist first.
      await _saveProgressInternal(updatedProgress);

      // Notify only after persistence succeeds.
      if (isNewWorldCompletion &&
          newHighestUnlockedWorld > previousHighestWorld &&
          !_worldCompletionController.isClosed) {
        _worldCompletionController.add(world);
      }

      if (!_progressUpdateController.isClosed) {
        _progressUpdateController.add(null);
      }
    });
  }

  // ==========================================================================
  // GLOBAL STATISTICS
  // ==========================================================================

  /// Returns aggregated global progression statistics.
  ///
  /// Keys:
  /// - totalLevels
  /// - totalStars
  /// - totalTime
  /// - avgSpeed
  /// - completionPercent
  Future<Map<String, dynamic>> getGlobalStats() async {
    final progress = await loadProgress();

    final completed = List<int>.from(progress['completedLevels'] as List<int>);

    final bestTimes = Map<String, int>.from(
      progress['bestTimes'] as Map<String, int>,
    );

    final starsMap = Map<String, int>.from(
      progress['stars'] as Map<String, int>,
    );

    final totalStars = starsMap.values.fold<int>(
      0,
      (sum, value) => sum + value,
    );

    final totalTime = bestTimes.values.fold<int>(
      0,
      (sum, value) => sum + value,
    );

    final averageTime = completed.isEmpty
        ? 0
        : (totalTime / completed.length).round();

    final completionPercent = totalLevels == 0
        ? 0.0
        : (completed.length / totalLevels).clamp(0.0, 1.0);

    return <String, dynamic>{
      'totalLevels': completed.length,
      'totalStars': totalStars,
      'totalTime': totalTime,
      'avgSpeed': averageTime,
      'completionPercent': completionPercent,
    };
  }

  // ==========================================================================
  // WORLD PROGRESSION
  // ==========================================================================

  /// Returns the highest currently unlocked world.
  Future<int> getHighestUnlockedWorld() async {
    final progress = await loadProgress();

    return progress['highestUnlockedWorld'] as int;
  }

  /// Returns the next progression level.
  ///
  /// Once the entire game is completed, this returns [totalLevels].
  Future<int> getNextUnlockedLevel() async {
    final progress = await loadProgress();

    return progress['currentLevel'] as int;
  }

  // ==========================================================================
  // WORLD STARS
  // ==========================================================================

  /// Returns total stars for each requested world.
  Future<Map<int, int>> getAllWorldStars(int requestedTotalWorlds) async {
    if (requestedTotalWorlds < _firstWorld) {
      throw ArgumentError.value(
        requestedTotalWorlds,
        'requestedTotalWorlds',
        'Total worlds must be at least 1.',
      );
    }

    final progress = await loadProgress();

    final starsMap = Map<String, int>.from(
      progress['stars'] as Map<String, int>,
    );

    final safeTotalWorlds = requestedTotalWorlds.clamp(
      _firstWorld,
      totalWorlds,
    );

    final result = <int, int>{};

    for (int world = _firstWorld; world <= safeTotalWorlds; world++) {
      final start = getWorldFirstLevel(world);

      final end = getWorldLastLevel(world);

      int totalStars = 0;

      for (int globalLevel = start; globalLevel <= end; globalLevel++) {
        totalStars += starsMap[globalLevel.toString()] ?? 0;
      }

      result[world] = totalStars;
    }

    return result;
  }

  /// Returns total stars earned in a specific world.
  Future<int> getStarsForWorld(int world) async {
    _validateWorld(world);

    final progress = await loadProgress();

    final starsMap = Map<String, int>.from(
      progress['stars'] as Map<String, int>,
    );

    final start = getWorldFirstLevel(world);

    final end = getWorldLastLevel(world);

    int totalStars = 0;

    for (int globalLevel = start; globalLevel <= end; globalLevel++) {
      totalStars += starsMap[globalLevel.toString()] ?? 0;
    }

    return totalStars;
  }

  // ==========================================================================
  // COMPLETION HELPERS
  // ==========================================================================

  /// Returns true when [globalLevel] has been completed.
  Future<bool> isLevelCompleted(int globalLevel) async {
    _validateGlobalLevel(globalLevel);

    final progress = await loadProgress();

    final completed = progress['completedLevels'] as List<int>;

    return completed.contains(globalLevel);
  }

  /// Returns true when [globalLevel] can currently be played.
  ///
  /// Completed levels are always replayable.
  ///
  /// New levels unlock sequentially.
  Future<bool> isLevelUnlocked(int globalLevel) async {
    _validateGlobalLevel(globalLevel);

    final progress = await loadProgress();

    final currentLevel = progress['currentLevel'] as int;

    final completed = progress['completedLevels'] as List<int>;

    return completed.contains(globalLevel) || globalLevel == currentLevel;
  }

  /// Returns true when [globalLevel] is being replayed.
  ///
  /// A completed level is considered a replay whenever it is not the current
  /// progression level.
  Future<bool> isReplayingLevel(int globalLevel) async {
    _validateGlobalLevel(globalLevel);

    final progress = await loadProgress();

    final currentLevel = progress['currentLevel'] as int;

    final completed = progress['completedLevels'] as List<int>;

    return completed.contains(globalLevel) && globalLevel != currentLevel;
  }

  // ==========================================================================
  // RESET
  // ==========================================================================

  /// Resets gameplay progress.
  ///
  /// User identity and account information are not affected.
  Future<void> resetProgress() {
    _ensureInitialized();

    return _runMutation(() async {
      final prefs = _prefs;

      if (prefs == null) {
        throw StateError('ProgressService storage is unavailable.');
      }

      try {
        final removed = await prefs.remove(_progressKey);

        if (!removed && prefs.containsKey(_progressKey)) {
          throw StateError('SharedPreferences could not reset progress.');
        }

        _cachedProgress = _defaultProgress();

        if (!_progressUpdateController.isClosed) {
          _progressUpdateController.add(null);
        }
      } catch (error, stackTrace) {
        Error.throwWithStackTrace(
          StateError('Could not reset progress: $error'),
          stackTrace,
        );
      }
    });
  }

  // ==========================================================================
  // CACHE / DEBUG HELPERS
  // ==========================================================================

  /// Returns true when the service has been initialized.
  bool get isInitialized => _isInitialized;

  /// Returns true when the service has been disposed.
  bool get isDisposed => _isDisposed;

  // ==========================================================================
  // VALIDATION
  // ==========================================================================

  void _validateGlobalLevel(int globalLevel) {
    if (globalLevel < _firstLevel || globalLevel > totalLevels) {
      throw ArgumentError.value(
        globalLevel,
        'globalLevel',
        'Global level must be between '
            '$_firstLevel and $totalLevels.',
      );
    }
  }

  void _validateWorld(int world) {
    if (world < _firstWorld || world > totalWorlds) {
      throw ArgumentError.value(
        world,
        'world',
        'World must be between '
            '$_firstWorld and $totalWorlds.',
      );
    }
  }

  void _validateLocalLevel(int level) {
    if (level < _firstLevel || level > levelsPerWorld) {
      throw ArgumentError.value(
        level,
        'level',
        'Level must be between '
            '$_firstLevel and $levelsPerWorld.',
      );
    }
  }

  // ==========================================================================
  // PARSING
  // ==========================================================================

  int? _parseIntOrNull(dynamic value) {
    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    if (value is String) {
      return int.tryParse(value.trim());
    }

    return null;
  }

  // ==========================================================================
  // DEFENSIVE COPY
  // ==========================================================================

  Map<String, dynamic> _deepCopyProgress(Map<String, dynamic> progress) {
    return <String, dynamic>{
      'version': progress['version'] as int? ?? _progressVersion,
      'currentLevel': progress['currentLevel'] as int,
      'completedLevels': List<int>.from(
        progress['completedLevels'] as List<int>,
      ),
      'bestTimes': Map<String, int>.from(
        progress['bestTimes'] as Map<String, int>,
      ),
      'stars': Map<String, int>.from(progress['stars'] as Map<String, int>),
      'highestUnlockedWorld': progress['highestUnlockedWorld'] as int,
    };
  }

  // ==========================================================================
  // LIFECYCLE
  // ==========================================================================

  /// Closes internal streams.
  ///
  /// Because this class is a singleton, normally use this only in tests or
  /// controlled application shutdown.
  ///
  /// Once disposed, the singleton cannot be reused.
  void dispose() {
    if (_isDisposed) {
      return;
    }

    _isDisposed = true;

    _worldCompletionController.close();
    _progressUpdateController.close();
  }

  // ==========================================================================
  // STATE GUARDS
  // ==========================================================================

  void _ensureInitialized() {
    _ensureNotDisposed();

    if (!_isInitialized || _prefs == null) {
      throw StateError(
        'ProgressService not initialized. '
        'Call await ProgressService().init() before using it.',
      );
    }
  }

  void _ensureNotDisposed() {
    if (_isDisposed) {
      throw StateError(
        'ProgressService has been disposed and cannot be reused.',
      );
    }
  }
}
