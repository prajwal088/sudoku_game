import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
// Double check that 'sudoku_game' matches the name in your pubspec.yaml
import 'package:sudoku_game/services/progress_service.dart';

void main() {
  // This is the "main" function the error is looking for!
  
  late ProgressService progressService;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    progressService = ProgressService();
  });

  group('ProgressService - Conversion Logic', () {
    test('getGlobalLevel should correctly map World/Level to Global ID', () {
      expect(progressService.getGlobalLevel(1, 1), 1);
      expect(progressService.getGlobalLevel(1, 25), 25);
      expect(progressService.getGlobalLevel(2, 1), 26);
    });

    test('getWorldFromGlobal should correctly map Global ID to World', () {
      expect(progressService.getWorldFromGlobal(1), 1);
      expect(progressService.getWorldFromGlobal(25), 1);
      expect(progressService.getWorldFromGlobal(26), 2);
    });
  });

  group('ProgressService - Data Persistence', () {
    test('completeLevel should update progress and unlock next level', () async {
      await progressService.completeLevel(
        globalLevel: 1,
        timeInSeconds: 120,
        stars: 3,
      );

      final progress = await progressService.loadProgress();
      
      expect(progress["currentLevel"], 2);
      expect(progress["completedLevels"], contains(1));
    });

    test('Completing last level of world should unlock next world', () async {
      await progressService.completeLevel(
        globalLevel: 25, // End of World 1
        timeInSeconds: 300,
        stars: 2,
      );

      final unlockedWorld = await progressService.getHighestUnlockedWorld();
      expect(unlockedWorld, 2);
    });
  });
} // This closing brace for main() is critical!