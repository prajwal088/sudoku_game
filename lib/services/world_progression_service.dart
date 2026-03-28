import 'package:sudoku_game/logic/world_manager.dart';
import 'dart:async';

class WorldProgressionService {
  static final WorldProgressionService _instance = WorldProgressionService._internal();
  
factory WorldProgressionService() {
    return _instance;
  }
  
  WorldProgressionService._internal();

  final StreamController<int> _batchCompletionController = StreamController<int>.broadcast();
  final StreamController<int> _worldCompletionController = StreamController<int>.broadcast();

  Stream<int> get onBatchCompleted => _batchCompletionController.stream;
  Stream<int> get onWorldCompleted => _worldCompletionController.stream;

  /// Check if world N+1 should be unlocked
  bool canUnlockNextWorld(int completedWorldNumber) {
    return completedWorldNumber >= 1;
  }

  /// Handle level completion and check for world/batch completion
  void handleLevelCompletion(int levelIndex, List<int> completedLevels) {
    int currentWorld = WorldManager.getLevelToWorld(levelIndex);

    // Check if this level completes the world
    if (WorldManager.completesWorld(levelIndex)) {
      _worldCompletionController.add(currentWorld);

      // Check if this level completes the batch
      if (WorldManager.completesBatch(levelIndex)) {
        int batch = WorldManager.getWorldToBatch(currentWorld);
        _batchCompletionController.add(batch);
      }
    }
  }

  /// Get next world to unlock
  int getNextWorldToUnlock(int completedWorldNumber) {
    return completedWorldNumber + 1;
  }

  /// Get next batch to unlock
  int getNextBatchToUnlock(int completedBatchNumber) {
    return completedBatchNumber + 1;
  }

  void dispose() {
    _batchCompletionController.close();
    _worldCompletionController.close();
  }
}