import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;

import 'package:shared_preferences/shared_preferences.dart';

import '../config/game_config.dart';

/// ============================================================================
/// ProgressService
/// ----------------------------------------------------------------------------
/// Single source of truth for Sudoku gameplay progression and persistence.
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
/// - [GameConfig] owns all static game configuration and gameplay rules.
/// - Global level is the canonical level identifier.
/// - World and local level are derived from the global level.
/// - [completedLevels] is the authoritative progression state.
/// - [currentLevel] is derived from completed levels.
/// - [highestUnlockedWorld] is derived from completed levels.
/// - SharedPreferences provides local persistence.
/// - Progress is cached in memory after initialization.
/// - Mutations are serialized to prevent concurrent-write races.
/// - Public progress maps are defensive copies; internal reads use the cache
///   directly (read-only) to avoid copying on every query.
/// - All Future-returning APIs report errors through the returned Future
///   (never by throwing synchronously).
///
/// This service does NOT:
/// - Own static game configuration.
/// - Own puzzle content.
/// - Generate Sudoku puzzles.
/// - Manage UI state.
///
/// IMPORTANT:
/// Call:
///
/// ```dart
/// await ProgressService().init();
/// ```
///
/// before using progression APIs. [init] is idempotent and safe to retry
/// after a failure.
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

  /// Corrupt persisted progress is copied here before being replaced, so it
  /// can be inspected or recovered instead of being silently lost.
  static const String _corruptBackupKey = 'sudoku_progress_corrupt_backup';

  /// Current persistence schema version.
  ///
  /// Increment this when the persisted structure changes and add migration
  /// logic before changing the stored structure.
  static const int _progressVersion = 1;

  // ==========================================================================
  // CONFIGURATION COMPATIBILITY
  // ==========================================================================
  //
  // GameConfig is the actual source of truth.
  //
  // These getters preserve the existing public API used by older callers
  // while ensuring ProgressService does not own duplicate configuration.
  //
  // New code should prefer GameConfig directly.
  // ==========================================================================

  /// Number of levels contained in one world.
  ///
  /// Deprecated: use [GameConfig.levelsPerWorld].
  @Deprecated('Use GameConfig.levelsPerWorld instead.')
  static int get levelsPerWorld => GameConfig.levelsPerWorld;

  /// Number of worlds contained in the game.
  ///
  /// Deprecated: use [GameConfig.totalWorlds].
  @Deprecated('Use GameConfig.totalWorlds instead.')
  static int get totalWorlds => GameConfig.totalWorlds;

  /// Total number of playable global levels.
  ///
  /// Deprecated: use [GameConfig.totalLevels].
  @Deprecated('Use GameConfig.totalLevels instead.')
  static int get totalLevels => GameConfig.totalLevels;

  // ==========================================================================
  // STREAMS
  // ==========================================================================

  final StreamController<int> _worldCompletionController =
      StreamController<int>.broadcast();

  final StreamController<void> _progressUpdateController =
      StreamController<void>.broadcast();

  /// Emits the world number when that world is completed for the first time.
  ///
  /// This includes the final world.
  Stream<int> get onWorldCompleted => _worldCompletionController.stream;

  /// Emits after progress has been successfully persisted.
  Stream<void> get onProgressUpdate => _progressUpdateController.stream;

  void _notifyProgressUpdated() {
    if (!_progressUpdateController.isClosed) {
      _progressUpdateController.add(null);
    }
  }

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
  /// The queue itself never holds an error (failures are delivered to the
  /// caller of the failed mutation only), so one failed mutation can never
  /// block or poison later ones.
  Future<void> _mutationQueue = Future<void>.value();

  Future<T> _runMutation<T>(Future<T> Function() mutation) {
    final Future<T> result = _mutationQueue.then<T>((_) => mutation());

    _mutationQueue = result.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );

    return result;
  }

  // ==========================================================================
  // INITIALIZATION
  // ==========================================================================

  /// Initializes the service.
  ///
  /// Safe to call multiple times. Concurrent callers share the same
  /// initialization operation. If initialization fails, a later call retries.
  Future<void> init() async {
    _ensureNotDisposed();

    if (_isInitialized) {
      return;
    }

    final Future<void> inFlight = _initializationFuture ??=
        _initialize().whenComplete(() {
      _initializationFuture = null;
    });

    await inFlight;
  }

  Future<void> _initialize() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();

      final Map<String, dynamic> progress = await _loadProgressFromPreferences(
        prefs,
      );

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
      'currentLevel': GameConfig.minimumLevel,
      'completedLevels': <int>[],
      'bestTimes': <String, int>{},
      'stars': <String, int>{},
      'highestUnlockedWorld': GameConfig.minimumWorld,
    };
  }

  // ==========================================================================
  // LOAD PROGRESS
  // ==========================================================================

  /// Returns the current progress as a defensive copy.
  Future<Map<String, dynamic>> loadProgress() async {
    return _deepCopyProgress(_progress);
  }

  Future<Map<String, dynamic>> _loadProgressFromPreferences(
    SharedPreferences prefs,
  ) async {
    final Object? raw = prefs.get(_progressKey);

    if (raw == null || (raw is String && raw.trim().isEmpty)) {
      return _defaultProgress();
    }

    try {
      if (raw is! String) {
        throw const FormatException('Stored progress is not a string.');
      }

      final dynamic decoded = jsonDecode(raw);

      if (decoded is! Map) {
        throw const FormatException('Stored progress is not an object.');
      }

      return _normalizeProgress(Map<String, dynamic>.from(decoded));
    } catch (error) {
      // Corrupt local progress must never prevent the application from
      // starting. A copy is kept under a separate key so the data is not
      // irrecoverably lost when the next save overwrites the main key.
      developer.log(
        'ProgressService: stored progress is corrupt, resetting: $error',
        name: 'ProgressService',
        level: 1000,
      );

      await _backupCorruptProgress(prefs, raw);

      return _defaultProgress();
    }
  }

  Future<void> _backupCorruptProgress(
    SharedPreferences prefs,
    Object raw,
  ) async {
    try {
      await prefs.setString(_corruptBackupKey, raw.toString());
    } catch (_) {
      // Best effort only.
    }
  }

  // ==========================================================================
  // NORMALIZATION
  // ==========================================================================

  /// Converts untrusted/persisted data into the canonical progress model.
  ///
  /// IMPORTANT:
  /// [completedLevels] is authoritative.
  ///
  /// [currentLevel] and [highestUnlockedWorld] are always derived from
  /// completed levels and therefore cannot be manipulated through persisted
  /// derived values.
  Map<String, dynamic> _normalizeProgress(Map<String, dynamic> raw) {
    final Set<int> completedLevels = _normalizeCompletedLevels(
      raw['completedLevels'],
    );

    final Map<String, int> bestTimes = _normalizeBestTimes(
      raw['bestTimes'],
      completedLevels,
    );

    final Map<String, int> stars = _normalizeStars(
      raw['stars'],
      completedLevels,
    );

    return <String, dynamic>{
      'version': _progressVersion,
      'currentLevel': _deriveCurrentLevel(completedLevels),
      'completedLevels': completedLevels.toList()..sort(),
      'bestTimes': bestTimes,
      'stars': stars,
      'highestUnlockedWorld': _deriveHighestUnlockedWorld(completedLevels),
    };
  }

  Set<int> _normalizeCompletedLevels(dynamic rawCompleted) {
    final Set<int> completedLevels = <int>{};

    if (rawCompleted is! List) {
      return completedLevels;
    }

    for (final dynamic value in rawCompleted) {
      final int? level = _parseIntOrNull(value);

      if (level != null && GameConfig.isValidGlobalLevel(level)) {
        completedLevels.add(level);
      }
    }

    return completedLevels;
  }

  Map<String, int> _normalizeBestTimes(
    dynamic rawBestTimes,
    Set<int> completedLevels,
  ) {
    final Map<String, int> bestTimes = <String, int>{};

    if (rawBestTimes is! Map) {
      return bestTimes;
    }

    rawBestTimes.forEach((dynamic key, dynamic value) {
      final int? level = int.tryParse(key.toString());
      final int? time = _parseIntOrNull(value);

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

  Map<String, int> _normalizeStars(
    dynamic rawStars,
    Set<int> completedLevels,
  ) {
    final Map<String, int> stars = <String, int>{};

    if (rawStars is! Map) {
      return stars;
    }

    rawStars.forEach((dynamic key, dynamic value) {
      final int? level = int.tryParse(key.toString());
      final int? starValue = _parseIntOrNull(value);

      if (level == null ||
          !completedLevels.contains(level) ||
          starValue == null ||
          !GameConfig.isValidStars(starValue)) {
        return;
      }

      stars[level.toString()] = starValue;
    });

    return stars;
  }

  // ==========================================================================
  // DERIVED PROGRESSION
  // ==========================================================================

  /// Derives the next progression level from completed levels.
  ///
  /// Example: completed [1, 2, 3] -> current 4.
  ///
  /// When every level has been completed, the final level remains selected.
  int _deriveCurrentLevel(Set<int> completedLevels) {
    for (
      int level = GameConfig.minimumLevel;
      level <= GameConfig.totalLevels;
      level++
    ) {
      if (!completedLevels.contains(level)) {
        return level;
      }
    }

    return GameConfig.totalLevels;
  }

  /// Derives the highest unlocked world from completed world boundaries.
  ///
  /// World 1 is always unlocked. World N + 1 unlocks when the final level of
  /// World N is completed. There is no world after the final world, so
  /// completing it does not change this value.
  int _deriveHighestUnlockedWorld(Set<int> completedLevels) {
    int highestWorld = GameConfig.minimumWorld;

    for (
      int world = GameConfig.minimumWorld;
      world < GameConfig.totalWorlds;
      world++
    ) {
      final int finalLevel = GameConfig.getLastLevelForWorld(world);

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
  /// For normal gameplay, prefer [completeLevel] and [resetProgress]; this
  /// method bypasses the sequential-progression rules and exists for
  /// controlled migration/testing use.
  Future<void> saveProgress(Map<String, dynamic> progress) async {
    _ensureInitialized();

    await _runMutation<void>(() async {
      await _saveProgressInternal(progress);
      _notifyProgressUpdated();
    });
  }

  Future<void> _saveProgressInternal(Map<String, dynamic> progress) async {
    final SharedPreferences? prefs = _prefs;

    if (prefs == null) {
      throw StateError('ProgressService storage is unavailable.');
    }

    final Map<String, dynamic> normalized = _normalizeProgress(
      Map<String, dynamic>.from(progress),
    );

    final String encoded = jsonEncode(normalized);

    try {
      final bool saved = await prefs.setString(_progressKey, encoded);

      if (!saved) {
        throw StateError('SharedPreferences could not save progress.');
      }

      // The cache is only updated after a successful write.
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

    return GameConfig.getGlobalLevel(world, level);
  }

  /// Converts a global level into its world number.
  int getWorldFromGlobal(int globalLevel) {
    _validateGlobalLevel(globalLevel);

    return GameConfig.getWorldFromGlobalLevel(globalLevel);
  }

  /// Converts a global level into its local level inside the world.
  int getLevelInWorld(int globalLevel) {
    _validateGlobalLevel(globalLevel);

    return GameConfig.getLocalLevelFromGlobalLevel(globalLevel);
  }

  /// Returns the world and local level for a global level.
  Map<String, int> getWorldAndLevel(int globalLevel) {
    _validateGlobalLevel(globalLevel);

    return <String, int>{
      'world': GameConfig.getWorldFromGlobalLevel(globalLevel),
      'level': GameConfig.getLocalLevelFromGlobalLevel(globalLevel),
    };
  }

  /// Returns the first global level in [world].
  int getWorldFirstLevel(int world) {
    _validateWorld(world);

    return GameConfig.getFirstLevelForWorld(world);
  }

  /// Returns the last global level in [world].
  int getWorldLastLevel(int world) {
    _validateWorld(world);

    return GameConfig.getLastLevelForWorld(world);
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
  ///
  /// Throws (through the returned Future) an [ArgumentError] for invalid
  /// arguments and a [StateError] for out-of-order completion or storage
  /// failures.
  Future<void> completeLevel({
    required int globalLevel,
    required int timeInSeconds,
    required int stars,
  }) async {
    _ensureInitialized();

    _validateGlobalLevel(globalLevel);

    if (timeInSeconds <= 0) {
      throw ArgumentError.value(
        timeInSeconds,
        'timeInSeconds',
        'Time must be greater than 0 seconds.',
      );
    }

    if (!GameConfig.isValidStars(stars)) {
      throw ArgumentError.value(
        stars,
        'stars',
        'Stars must be between '
            '${GameConfig.minStarsPerLevel} '
            'and ${GameConfig.maxStarsPerLevel}.',
      );
    }

    await _runMutation<void>(() async {
      final Map<String, dynamic> progress = _deepCopyProgress(_progress);

      final Set<int> completed = <int>{
        ...(progress['completedLevels'] as List<int>),
      };

      final Map<String, int> bestTimes =
          progress['bestTimes'] as Map<String, int>;

      final Map<String, int> starsMap = progress['stars'] as Map<String, int>;

      final int currentLevel = _deriveCurrentLevel(completed);
      final bool wasAlreadyCompleted = completed.contains(globalLevel);

      // ----------------------------------------------------------------------
      // SEQUENTIAL PROGRESSION
      // ----------------------------------------------------------------------

      if (!wasAlreadyCompleted && globalLevel != currentLevel) {
        throw StateError(
          'Cannot complete level $globalLevel. '
          'Current progression level is $currentLevel.',
        );
      }

      final String levelKey = globalLevel.toString();

      // ----------------------------------------------------------------------
      // COMPLETION, BEST TIME, BEST STARS
      // ----------------------------------------------------------------------

      completed.add(globalLevel);

      final int? previousBestTime = bestTimes[levelKey];

      if (previousBestTime == null || timeInSeconds < previousBestTime) {
        bestTimes[levelKey] = timeInSeconds;
      }

      final int? previousStars = starsMap[levelKey];

      if (previousStars == null || stars > previousStars) {
        starsMap[levelKey] = stars;
      }

      // ----------------------------------------------------------------------
      // DERIVED PROGRESSION
      // ----------------------------------------------------------------------

      final int world = GameConfig.getWorldFromGlobalLevel(globalLevel);
      final int localLevel = GameConfig.getLocalLevelFromGlobalLevel(
        globalLevel,
      );

      // Levels are completed sequentially, so finishing a world's last level
      // for the first time means the whole world is now complete. This is
      // true for the final world as well (which unlocks no further world).
      final bool isNewWorldCompletion =
          !wasAlreadyCompleted && localLevel == GameConfig.levelsPerWorld;

      final Map<String, dynamic> updatedProgress = <String, dynamic>{
        'version': _progressVersion,
        'currentLevel': _deriveCurrentLevel(completed),
        'completedLevels': completed.toList()..sort(),
        'bestTimes': bestTimes,
        'stars': starsMap,
        'highestUnlockedWorld': _deriveHighestUnlockedWorld(completed),
      };

      // Persist first.
      await _saveProgressInternal(updatedProgress);

      // Notify only after persistence succeeds.
      if (isNewWorldCompletion && !_worldCompletionController.isClosed) {
        _worldCompletionController.add(world);
      }

      _notifyProgressUpdated();
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
    final Map<String, dynamic> progress = _progress;

    final List<int> completed = progress['completedLevels'] as List<int>;
    final Map<String, int> bestTimes =
        progress['bestTimes'] as Map<String, int>;
    final Map<String, int> starsMap = progress['stars'] as Map<String, int>;

    final int totalStars = starsMap.values.fold<int>(
      0,
      (int sum, int value) => sum + value,
    );

    final int totalTime = bestTimes.values.fold<int>(
      0,
      (int sum, int value) => sum + value,
    );

    // Average over levels that actually have a recorded time.
    final int averageTime = bestTimes.isEmpty
        ? 0
        : (totalTime / bestTimes.length).round();

    final double completionPercent = GameConfig.totalLevels == 0
        ? 0.0
        : (completed.length / GameConfig.totalLevels)
              .clamp(0.0, 1.0)
              .toDouble();

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
    return _progress['highestUnlockedWorld'] as int;
  }

  /// Returns the next progression level.
  ///
  /// Once the entire game is completed, this returns [GameConfig.totalLevels].
  Future<int> getNextUnlockedLevel() async {
    return _progress['currentLevel'] as int;
  }

  // ==========================================================================
  // WORLD STARS
  // ==========================================================================

  /// Returns total stars for each requested world.
  Future<Map<int, int>> getAllWorldStars(int requestedTotalWorlds) async {
    if (requestedTotalWorlds < GameConfig.minimumWorld) {
      throw ArgumentError.value(
        requestedTotalWorlds,
        'requestedTotalWorlds',
        'Total worlds must be at least ${GameConfig.minimumWorld}.',
      );
    }

    final Map<String, int> starsMap = _progress['stars'] as Map<String, int>;

    final int safeTotalWorlds = requestedTotalWorlds > GameConfig.totalWorlds
        ? GameConfig.totalWorlds
        : requestedTotalWorlds;

    final Map<int, int> result = <int, int>{};

    for (
      int world = GameConfig.minimumWorld;
      world <= safeTotalWorlds;
      world++
    ) {
      result[world] = _sumStarsForWorld(starsMap, world);
    }

    return result;
  }

  /// Returns total stars earned in a specific world.
  Future<int> getStarsForWorld(int world) async {
    _validateWorld(world);

    final Map<String, int> starsMap = _progress['stars'] as Map<String, int>;

    return _sumStarsForWorld(starsMap, world);
  }

  int _sumStarsForWorld(Map<String, int> starsMap, int world) {
    final int start = GameConfig.getFirstLevelForWorld(world);
    final int end = GameConfig.getLastLevelForWorld(world);

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

    final List<int> completed = _progress['completedLevels'] as List<int>;

    return completed.contains(globalLevel);
  }

  /// Returns true when [globalLevel] can currently be played.
  ///
  /// Completed levels are always replayable. New levels unlock sequentially.
  Future<bool> isLevelUnlocked(int globalLevel) async {
    _validateGlobalLevel(globalLevel);

    final Map<String, dynamic> progress = _progress;

    final int currentLevel = progress['currentLevel'] as int;
    final List<int> completed = progress['completedLevels'] as List<int>;

    return completed.contains(globalLevel) || globalLevel == currentLevel;
  }

  /// Returns true when [globalLevel] has already been completed, i.e. playing
  /// it again is a replay.
  ///
  /// Call this BEFORE [completeLevel] (for example when a level starts) and
  /// carry the result forward. After [completeLevel] runs, every finished
  /// level is "completed", so the answer can no longer distinguish a first
  /// completion from a replay.
  Future<bool> isReplayingLevel(int globalLevel) async {
    _validateGlobalLevel(globalLevel);

    final List<int> completed = _progress['completedLevels'] as List<int>;

    return completed.contains(globalLevel);
  }

  // ==========================================================================
  // RESET
  // ==========================================================================

  /// Resets gameplay progress.
  ///
  /// User identity and account information are not affected.
  Future<void> resetProgress() async {
    _ensureInitialized();

    await _runMutation<void>(() async {
      final SharedPreferences? prefs = _prefs;

      if (prefs == null) {
        throw StateError('ProgressService storage is unavailable.');
      }

      try {
        final bool removed = await prefs.remove(_progressKey);

        if (!removed && prefs.containsKey(_progressKey)) {
          throw StateError('SharedPreferences could not reset progress.');
        }

        _cachedProgress = _defaultProgress();

        _notifyProgressUpdated();
      } catch (error, stackTrace) {
        Error.throwWithStackTrace(
          StateError('Could not reset progress: $error'),
          stackTrace,
        );
      }
    });
  }

  // ==========================================================================
  // STATE
  // ==========================================================================

  /// Returns true when the service has been initialized.
  bool get isInitialized => _isInitialized;

  /// Returns true when the service has been disposed.
  bool get isDisposed => _isDisposed;

  /// Read-only view of the in-memory progress.
  ///
  /// INTERNAL: never mutate the returned map and never expose it publicly.
  /// Public APIs must return copies via [_deepCopyProgress].
  Map<String, dynamic> get _progress {
    _ensureInitialized();

    final Map<String, dynamic>? cached = _cachedProgress;

    if (cached == null) {
      throw StateError('ProgressService cache is unavailable.');
    }

    return cached;
  }

  // ==========================================================================
  // VALIDATION
  // ==========================================================================

  void _validateGlobalLevel(int globalLevel) {
    if (!GameConfig.isValidGlobalLevel(globalLevel)) {
      throw ArgumentError.value(
        globalLevel,
        'globalLevel',
        'Global level must be between '
            '${GameConfig.minimumLevel} '
            'and ${GameConfig.totalLevels}.',
      );
    }
  }

  void _validateWorld(int world) {
    if (!GameConfig.isValidWorld(world)) {
      throw ArgumentError.value(
        world,
        'world',
        'World must be between '
            '${GameConfig.minimumWorld} '
            'and ${GameConfig.totalWorlds}.',
      );
    }
  }

  void _validateLocalLevel(int level) {
    if (!GameConfig.isValidLocalLevel(level)) {
      throw ArgumentError.value(
        level,
        'level',
        'Level must be between '
            '${GameConfig.minimumLocalLevel} '
            'and ${GameConfig.levelsPerWorld}.',
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
      // NaN / Infinity would throw in toInt().
      return value.isFinite ? value.toInt() : null;
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