class Level {
final int levelNumber;
final String difficulty;
final int targetTime;

bool isLocked;
bool isUnlocked;
bool isCompleted;

int stars;        // 0 - 3 stars
int bestTime;     // seconds

List<List<int>> puzzle;
List<List<int>> solution;

Level({
required this.levelNumber,
required this.difficulty,
required this.puzzle,
required this.solution,
this.isLocked = true,
this.isUnlocked = false,
this.isCompleted = false,
this.stars = 0,
this.bestTime = 0,
required this.targetTime,
});

/// Convert Level → Map (for storage)
Map<String, dynamic> toMap() {
return {
'levelNumber': levelNumber,
'difficulty': difficulty,
'targetTime': targetTime,
'isLocked': isLocked,
'isUnlocked': isUnlocked,
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
difficulty: map['difficulty'],
targetTime: map['targetTime'],
isLocked: map['isLocked'],
isUnlocked: map['isUnlocked'],
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

/// ============================================================================
/// Level
/// ----------------------------------------------------------------------------
/// Responsibility:
/// Pure data representation of a level.
/// Stores the state of a single level:
/// Level number, world
/// Puzzle & solution
/// Completion status, stars, times, locked/unlocked state
/// ============================================================================