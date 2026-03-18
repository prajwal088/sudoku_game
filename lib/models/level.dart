class Level {
  final int levelNumber;
  final String difficulty;

  final int targetTime;

  final int world;

  bool isLocked;
  bool isCompleted;

  int stars;        // 0 - 3 stars
  int bestTime;     // seconds

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
  Map<String, dynamic> toMap() {
    return {
      'levelNumber': levelNumber,
      'world': world, // ✅ FIXED
      'difficulty': difficulty,
      'targetTime': targetTime,
      'isLocked': isLocked,
      'isCompleted': isCompleted,
      'stars': stars,
      'bestTime': bestTime,
      'puzzle': puzzle,
      'solution': solution,
    };
  }

  /// Convert Map → Level
  factory Level.fromMap(Map<String, dynamic> map) {
    return Level(
      levelNumber: map['levelNumber'],
      world: map['world'] ?? 1, // ✅ FIXED (fallback for old data)
      difficulty: map['difficulty'],
      targetTime: map['targetTime'],
      isLocked: map['isLocked'],
      isCompleted: map['isCompleted'],
      stars: map['stars'],
      bestTime: map['bestTime'],
      puzzle: List<List<int>>.from(
        map['puzzle'].map((row) => List<int>.from(row)),
      ),
      solution: List<List<int>>.from(
        map['solution'].map((row) => List<int>.from(row)),
      ),
    );
  }
}