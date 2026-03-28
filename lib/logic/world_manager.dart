class WorldManager {
  static const int levelperworld = 25;
  static const int worldsperbatch = 10;

  /// Convert global level index to world number (1-indexed)
  static int getLevelToWorld(int levelIndex) {
    return ((levelIndex - 1) ~/ levelperworld) + 1;
  }

  /// Convert world number to batch number (1-indexed)
  static int getWorldToBatch(int worldNumber) {
    return ((worldNumber - 1) ~/ worldsperbatch) + 1;
  }

  /// Get first level index of a world
  static int getWorldFirstLevelIndex(int worldNumber) {
    return ((worldNumber - 1) * levelperworld) + 1;
  }

  /// Get last level index of a world
  static int getWorldLastLevelIndex(int worldNumber) {
    return worldNumber * levelperworld;
  }

  /// Get first world number in a batch
  static int getBatchFirstWorld(int batchNumber) {
    return ((batchNumber - 1) * worldsperbatch) + 1;
  }

  /// Get last world number in a batch
  static int getBatchLastWorld(int batchNumber) {
    return batchNumber * worldsperbatch;
  }

  /// Check if level completes a world
  static bool completesWorld(int levelIndex) {
    return (levelIndex % levelperworld) == 0;
  }

  /// Check if level completes a batch
  static bool completesBatch(int levelIndex) {
    int world = getLevelToWorld(levelIndex);
    return completesWorld(levelIndex) && (world % worldsperbatch) == 0;
  }
}