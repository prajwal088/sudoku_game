import 'package:flutter/material.dart';
import 'package:sudoku_game/main.dart';
import 'package:sudoku_game/l10n/app_localizations.dart';

import '../widgets/world_tile.dart';
import '../services/progress_service.dart';
import '../services/analytics_service.dart';


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

    // Track: User entered the main world selection hub
    AnalyticsService.logEvent(name: 'world_selection_open');

    _loadProgress();
  }

  /// ==========================================================================
  /// LOAD PROGRESS (OPTIMIZED + SAFE)
  /// ==========================================================================
  /// ==========================================================================
  /// LOAD PROGRESS (UPDATED & FIXED)
  /// ==========================================================================
  Future<void> _loadProgress() async {
  // Prevent multiple simultaneous loads
  if (_isLoading) return;

  setState(() {
    _isLoading = true;
    // Only show full-screen loader if we have no data yet
    if (worldStars.isEmpty) loading = true;
  });

  try {
      // 1. Run both heavy data fetches in parallel using Future.wait
      // This performs ONE disk read and ONE JSON decode for everything.
      final results = await Future.wait([
        _progressService.getHighestUnlockedWorld(),
        _progressService.getAllWorldStars(totalWorlds),
      ]);

      // 2. Extract results with type safety
      final int unlockedWorld = results[0] as int;
      final Map<int, int> tempStarsMap = Map<int, int>.from(results[1] as Map);

    if (!mounted) return;

    setState(() {
      highestUnlockedWorld = unlockedWorld;
      worldStars = tempStarsMap;
      loading = false;
      _isLoading = false;
    });

    // Track: User progress snapshot (useful for player profiling)
      AnalyticsService.logEvent(
        name: 'player_progress_sync',
        parameters: {
          'highest_world': unlockedWorld,
          'total_stars_collected': tempStarsMap.values.fold<int>(0, (sum, val) => sum + val),
        },
      );

  } catch (e) {
    debugPrint("WorldMapScreen Error: $e");
    if (mounted) {
      setState(() {
        loading = false;
        _isLoading = false;
      });
    }
  }
}

  /// ==========================================================================
  /// WORLD TAP HANDLER
  /// ==========================================================================
  Future<void> _onWorldTap(int worldNumber, bool isLocked) async {
    if (isLocked) {

      // Track: Attempt to access locked content
      AnalyticsService.logLockedWorldClick(worldNumber);

      _showLockedMessage(context);
      return;
    }

    // Track: Successful world entry
    AnalyticsService.logWorldEntry(worldNumber);

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
        title: Text(AppLocalizations.of(context)!.worldSelectionTitle),
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
      SnackBar(
        content: Text(AppLocalizations.of(context)!.worldLockedMessage),
      ),
    );
  }
}