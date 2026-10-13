import '../config/game_config.dart';

/// ============================================================================
/// Level
/// ----------------------------------------------------------------------------
/// A campaign level: its identity, difficulty, puzzle/solution grids and the
/// player's saved result for it.
///
/// - [levelNumber] is the canonical global level ID.
/// - The constructor takes OWNERSHIP of the [puzzle] and [solution] lists it
///   is given (no copy is made), so pass freshly built lists.
/// - [toMap] / [fromMap] always copy grids, so a serialized map and a Level
///   never share lists.
/// - [fromMap] is tolerant of missing optional fields and wrong numeric
///   types, and reports a clear [FormatException] for missing/invalid
///   required data instead of a runtime type error.
/// ============================================================================
class Level {
  final int levelNumber;
  final String difficulty;

  final int targetTime;

  final int world;

  bool isLocked;
  bool isCompleted;

  int stars; // 0 - 3 stars
  int bestTime; // seconds

  List<List<int>> puzzle;
  List<List<int>> solution;

  Level({
    required this.levelNumber,
    required this.world,
    required this.difficulty,
    required this.puzzle,
    required this.solution,
    this.isLocked = true,
    this.isCompleted = false,
    this.stars = 0,
    this.bestTime = 0,
    required this.targetTime,
  });

  /// Convert Level → Map (for storage)
  ///
  /// Grids are deep-copied so the map is independent of this Level.
  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'levelNumber': levelNumber,
      'world': world,
      'difficulty': difficulty,
      'targetTime': targetTime,
      'isLocked': isLocked,
      'isCompleted': isCompleted,
      'stars': stars,
      'bestTime': bestTime,
      'puzzle': _copyGrid(puzzle),
      'solution': _copyGrid(solution),
    };
  }

  /// Convert Map → Level
  ///
  /// Required keys: levelNumber, difficulty, targetTime, puzzle, solution.
  /// Optional keys fall back to the same defaults as the constructor
  /// (world 1, locked, not completed, 0 stars, no best time).
  ///
  /// Throws a [FormatException] for missing or invalid required data.
  factory Level.fromMap(Map<String, dynamic> map) {
    return Level(
      levelNumber: _readInt(map, 'levelNumber'),
      world: _readInt(map, 'world', fallback: GameConfig.minimumWorld),
      difficulty: _readString(map, 'difficulty'),
      targetTime: _readInt(map, 'targetTime'),
      isLocked: _readBool(map, 'isLocked', fallback: true),
      isCompleted: _readBool(map, 'isCompleted', fallback: false),
      stars: _readInt(map, 'stars', fallback: 0).clamp(
        GameConfig.minStarsPerLevel,
        GameConfig.maxStarsPerLevel,
      ),
      bestTime: _nonNegative(_readInt(map, 'bestTime', fallback: 0)),
      puzzle: _readGrid(map, 'puzzle'),
      solution: _readGrid(map, 'solution'),
    );
  }

  /// Returns a copy with the given fields replaced.
  ///
  /// Grids are copied, so the new Level never shares lists with this one.
  Level copyWith({
    int? levelNumber,
    int? world,
    String? difficulty,
    int? targetTime,
    bool? isLocked,
    bool? isCompleted,
    int? stars,
    int? bestTime,
    List<List<int>>? puzzle,
    List<List<int>>? solution,
  }) {
    return Level(
      levelNumber: levelNumber ?? this.levelNumber,
      world: world ?? this.world,
      difficulty: difficulty ?? this.difficulty,
      targetTime: targetTime ?? this.targetTime,
      isLocked: isLocked ?? this.isLocked,
      isCompleted: isCompleted ?? this.isCompleted,
      stars: stars ?? this.stars,
      bestTime: bestTime ?? this.bestTime,
      puzzle: _copyGrid(puzzle ?? this.puzzle),
      solution: _copyGrid(solution ?? this.solution),
    );
  }

  @override
  String toString() {
    return 'Level(levelNumber: $levelNumber, world: $world, '
        'difficulty: $difficulty, isLocked: $isLocked, '
        'isCompleted: $isCompleted, stars: $stars, bestTime: $bestTime, '
        'targetTime: $targetTime)';
  }

  // ==========================================================================
  // PARSING HELPERS
  // ==========================================================================

  static List<List<int>> _copyGrid(List<List<int>> source) {
    return source
        .map((List<int> row) => List<int>.from(row))
        .toList(growable: false);
  }

  static int _nonNegative(int value) => value < 0 ? 0 : value;

  static int _readInt(
    Map<String, dynamic> map,
    String key, {
    int? fallback,
  }) {
    final Object? value = map[key];

    if (value is int) {
      return value;
    }

    // JSON round-trips and other sources can yield doubles or strings.
    if (value is num && value.isFinite) {
      return value.toInt();
    }

    if (value is String) {
      final int? parsed = int.tryParse(value.trim());

      if (parsed != null) {
        return parsed;
      }
    }

    if (fallback != null && value == null) {
      return fallback;
    }

    throw FormatException('Level.fromMap: "$key" must be an integer.', value);
  }

  static bool _readBool(
    Map<String, dynamic> map,
    String key, {
    required bool fallback,
  }) {
    final Object? value = map[key];

    if (value is bool) {
      return value;
    }

    if (value == null) {
      return fallback;
    }

    throw FormatException('Level.fromMap: "$key" must be a boolean.', value);
  }

  static String _readString(Map<String, dynamic> map, String key) {
    final Object? value = map[key];

    if (value is String && value.isNotEmpty) {
      return value;
    }

    throw FormatException(
      'Level.fromMap: "$key" must be a non-empty string.',
      value,
    );
  }

  static List<List<int>> _readGrid(Map<String, dynamic> map, String key) {
    final Object? raw = map[key];

    if (raw is! List) {
      throw FormatException('Level.fromMap: "$key" must be a list.', raw);
    }

    return raw.map((Object? row) {
      if (row is! List) {
        throw FormatException(
          'Level.fromMap: every row of "$key" must be a list.',
          row,
        );
      }

      return row.map((Object? cell) {
        if (cell is int) {
          return cell;
        }

        if (cell is num && cell.isFinite) {
          return cell.toInt();
        }

        throw FormatException(
          'Level.fromMap: "$key" cells must be integers.',
          cell,
        );
      }).toList();
    }).toList();
  }
}