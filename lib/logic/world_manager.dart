class WorldManager {
  static const int LEVELS_PER_WORLD = 25;
  static const int WORLDS_PER_BATCH = 10;

  /// Convert global level index to world number (1-indexed)
  static int getLevelToWorld(int levelIndex) {
    return ((levelIndex - 1) ~/ LEVELS_PER_WORLD) + 1;
  }

  /// Convert world number to batch number (1-indexed)
  static int getWorldToBatch(int worldNumber) {
    return ((worldNumber - 1) ~/ WORLDS_PER_BATCH) + 1;
  }

  /// Get first level index of a world
  static int getWorldFirstLevelIndex(int worldNumber) {
    return ((worldNumber - 1) * LEVELS_PER_WORLD) + 1;
  }

  /// Get last level index of a world
  static int getWorldLastLevelIndex(int worldNumber) {
    return worldNumber * LEVELS_PER_WORLD;
  }

  /// Get first world number in a batch
  static int getBatchFirstWorld(int batchNumber) {
    return ((batchNumber - 1) * WORLDS_PER_BATCH) + 1;
  }

  /// Get last world number in a batch
  static int getBatchLastWorld(int batchNumber) {
    return batchNumber * WORLDS_PER_BATCH;
  }

  /// Check if level completes a world
  static bool completesWorld(int levelIndex) {
    return (levelIndex % LEVELS_PER_WORLD) == 0;
  }

  /// Check if level completes a batch
  static bool completesBatch(int levelIndex) {
    int world = getLevelToWorld(levelIndex);
    return completesWorld(levelIndex) && (world % WORLDS_PER_BATCH) == 0;
  }
}