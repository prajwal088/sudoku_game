import 'package:flutter/material.dart';
import 'package:sudoku_game/main.dart';

import '../widgets/world_tile.dart';
import '../services/progress_service.dart';


/// ============================================================================
/// WorldMapScreen
/// ----------------------------------------------------------------------------
/// Displays all available worlds in a grid format.
///
/// Responsibilities:
/// - Show locked/unlocked worlds
/// - Display stars per world
/// - Navigate to LevelMapScreen
///
/// Architecture:
/// - ProgressService → source of truth for unlocks & stars
/// - UI reacts to progress state
/// ============================================================================

class WorldMapScreen extends StatefulWidget {
  const WorldMapScreen({super.key});

  @override
  State<WorldMapScreen> createState() => _WorldMapScreenState();
}

class _WorldMapScreenState extends State<WorldMapScreen> {
  /// Total worlds in game (can be dynamic in future)
  static const int totalWorlds = 10;

  /// Progress service (single source of truth)
  final ProgressService _progressService = ProgressService();

  /// Highest unlocked world (from storage)
  int highestUnlockedWorld = 1;

  /// Stars collected per world → {world: stars}
  Map<int, int> worldStars = {};

  /// UI state flags
  bool loading = true;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadProgress();
  }

  /// ==========================================================================
  /// LOAD PROGRESS (OPTIMIZED + SAFE)
  /// ==========================================================================
  /// ==========================================================================
  /// LOAD PROGRESS (UPDATED & FIXED)
  /// ==========================================================================
  Future<void> _loadProgress() async {
    /// Prevent duplicate calls
    if (_isLoading) return;
    _isLoading = true;

    try {
      /// 1. Fetch highest unlocked world
      final unlockedWorld = await _progressService.getHighestUnlockedWorld();

      /// 2. Fetch stars in parallel (performance optimization)
      /// Note: Using getStarsForWorld for each world as per your original logic
      final futures = List.generate(totalWorlds, (index) {
        int world = index + 1;
        return _progressService.getStarsForWorld(world);
      });

      final results = await Future.wait(futures);

      /// 3. Map results → {world: stars}
      /// FIXED: Removed the second 'final' declaration to prevent "Already Defined" error
      Map<int, int> tempStarsMap = {}; 
      for (int i = 0; i < results.length; i++) {
        tempStarsMap[i + 1] = results[i];
      }

      if (!mounted) return;

      setState(() {
        highestUnlockedWorld = unlockedWorld;
        worldStars = tempStarsMap; // Updated to match the map name above
        loading = false;
      });
    } catch (e) {
      /// Log error for debugging (important for production)
      debugPrint("WorldMapScreen Error: $e");

      if (!mounted) return;

      setState(() {
        loading = false;
      });
    } finally {
      _isLoading = false;
    }
  }

  /// ==========================================================================
  /// WORLD TAP HANDLER
  /// ==========================================================================
  Future<void> _onWorldTap(int worldNumber, bool isLocked) async {
    if (isLocked) {
      _showLockedMessage(context);
      return;
    }

    await Navigator.pushNamed(
      context,
      AppRoutes.levels,
      arguments: worldNumber,
    );

    /// Refresh progress after returning
    if (mounted) {
      _loadProgress();
    }
  }

  /// ==========================================================================
  /// UI
  /// ==========================================================================
  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Select World"),
        centerTitle: true,
      ),

      /// ================= WORLD GRID =================
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: GridView.builder(
          itemCount: totalWorlds,
          gridDelegate:
              const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            mainAxisExtent: 130,
          ),
          itemBuilder: (context, index) {
            final int worldNumber = index + 1;

            /// Determine lock state using progress
            final bool isLocked =
                worldNumber > highestUnlockedWorld;

            /// Stars earned in this world
            final int stars =
                isLocked ? 0 : (worldStars[worldNumber] ?? 0);

            return WorldTile(
              worldNumber: worldNumber,
              isLocked: isLocked,

              /// Stars earned
              starsEarned: stars,

              /// Total possible stars (derived from ProgressService)
              totalStars:
                  ProgressService.levelsPerWorld * 3,

              /// Dynamic color based on progress
              color: _getWorldColor(worldNumber, isLocked, stars),

              /// Tap handler
              onTap: () =>
                  _onWorldTap(worldNumber, isLocked),
            );
          },
        ),
      ),
    );
  }

  /// ==========================================================================
  /// WORLD COLOR LOGIC
  /// ==========================================================================
  Color _getWorldColor(
      int world, bool isLocked, int starsEarned) {
    if (isLocked) {
      return Colors.grey.shade300;
    }

    final int maxStars =
        ProgressService.levelsPerWorld * 3;

    /// Fully completed world
    if (starsEarned >= maxStars) {
      return Colors.green.shade400;
    }

    /// In-progress world
    return Colors.orange.shade400;
  }

  /// ==========================================================================
  /// LOCK MESSAGE
  /// ==========================================================================
  void _showLockedMessage(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Complete previous world to unlock"),
      ),
    );
  }
}