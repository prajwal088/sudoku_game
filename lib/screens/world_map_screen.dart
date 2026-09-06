import 'package:flutter/material.dart';

import 'package:sudoku_game/main.dart';

import '../services/progress_service.dart';
import '../widgets/world_tile.dart';

/// ============================================================================
/// WorldMapScreen
/// ----------------------------------------------------------------------------
/// Displays all available worlds in a grid.
///
/// Responsibilities:
/// - Display locked and unlocked worlds.
/// - Display stars earned in each world.
/// - Navigate to the selected world's level map.
/// - Refresh progress when returning from a level map.
/// - Handle loading and storage errors safely.
///
/// Architecture:
/// - ProgressService is the source of truth for progression.
/// - WorldMapScreen owns only UI state.
/// - WorldTile is responsible for rendering an individual world.
///
/// IMPORTANT:
/// - WorldMapScreen works with WORLD numbers only.
/// - LevelMapScreen/GameScreen should handle LEVEL numbers.
/// - There is no local/global level conversion in this screen.
/// ============================================================================
class WorldMapScreen extends StatefulWidget {
  const WorldMapScreen({super.key});

  @override
  State<WorldMapScreen> createState() => _WorldMapScreenState();
}

class _WorldMapScreenState extends State<WorldMapScreen> {
  /// ==========================================================================
  /// CONFIGURATION
  /// ==========================================================================

  /// Total number of worlds currently available in the game.
  ///
  /// Keep this here for now to avoid changing other files unexpectedly.
  ///
  /// Later, this can be moved to a central game configuration if the number of
  /// worlds becomes dynamic.
  static const int _totalWorlds = 10;

  /// ==========================================================================
  /// SERVICES
  /// ==========================================================================

  final ProgressService _progressService = ProgressService();

  /// ==========================================================================
  /// UI STATE
  /// ==========================================================================

  /// Highest world currently unlocked by the player.
  int _highestUnlockedWorld = 1;

  /// Total stars earned in each world.
  ///
  /// Example:
  /// {
  ///   1: 42,
  ///   2: 18,
  ///   3: 0,
  /// }
  Map<int, int> _worldStars = <int, int>{};

  /// Shows the full-screen loading state during the initial load.
  bool _isInitialLoading = true;

  /// Prevents multiple simultaneous progress loads.
  bool _isLoading = false;

  /// ==========================================================================
  /// LIFECYCLE
  /// ==========================================================================

  @override
  void initState() {
    super.initState();

    _loadProgress();
  }

  /// ==========================================================================
  /// LOAD PROGRESS
  /// ==========================================================================

  /// Loads:
  /// - highest unlocked world
  /// - stars earned in each world
  ///
  /// Both operations are independent, so they are executed in parallel.
  ///
  /// Initial load:
  /// - Displays a full-screen progress indicator.
  ///
  /// Subsequent loads:
  /// - Refresh data silently.
  /// - Prevents the world map from flashing a loading screen when the player
  ///   returns from LevelMapScreen.
  Future<void> _loadProgress() async {
    if (_isLoading) return;

    _isLoading = true;

    try {
      final results = await Future.wait<dynamic>([
        _progressService.getHighestUnlockedWorld(),
        _progressService.getAllWorldStars(_totalWorlds),
      ]);

      final int unlockedWorld = results[0] as int;

      final Map<int, int> stars = Map<int, int>.from(
        results[1] as Map<int, int>,
      );

      if (!mounted) return;

      setState(() {
        _highestUnlockedWorld = unlockedWorld.clamp(1, _totalWorlds);

        _worldStars = stars;

        _isInitialLoading = false;
      });
    } catch (e, stackTrace) {
      debugPrint('WorldMapScreen: failed to load progress: $e');

      debugPrintStack(stackTrace: stackTrace);

      if (!mounted) return;

      setState(() {
        _isInitialLoading = false;
      });

      _showErrorMessage();
    } finally {
      _isLoading = false;
    }
  }

  /// ==========================================================================
  /// WORLD TAP HANDLER
  /// ==========================================================================

  Future<void> _onWorldTap(int worldNumber, bool isLocked) async {
    if (!mounted) return;

    if (isLocked) {
      _showLockedMessage();
      return;
    }

    try {
      await Navigator.pushNamed(
        context,
        AppRoutes.levels,
        arguments: worldNumber,
      );
    } catch (e, stackTrace) {
      debugPrint('WorldMapScreen: failed to open world $worldNumber: $e');

      debugPrintStack(stackTrace: stackTrace);

      if (!mounted) return;

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Could not open this world.'),
            behavior: SnackBarBehavior.floating,
          ),
        );

      return;
    }

    if (!mounted) return;

    /// Refresh progress after returning from LevelMapScreen.
    ///
    /// The player may have completed the final level of a world and unlocked
    /// the next world while inside the level map/game.
    await _loadProgress();
  }

  /// ==========================================================================
  /// WORLD STATE HELPERS
  /// ==========================================================================

  bool _isWorldLocked(int worldNumber) {
    return worldNumber > _highestUnlockedWorld;
  }

  int _getWorldStars(int worldNumber) {
    if (_isWorldLocked(worldNumber)) {
      return 0;
    }

    final stars = _worldStars[worldNumber] ?? 0;

    return stars.clamp(0, _maxStarsPerWorld);
  }

  /// Maximum possible stars for one world.
  int get _maxStarsPerWorld {
    return ProgressService.levelsPerWorld * 3;
  }

  /// ==========================================================================
  /// WORLD COLOR
  /// ==========================================================================

  Color _getWorldColor(bool isLocked, int starsEarned) {
    if (isLocked) {
      return Colors.grey.shade300;
    }

    if (starsEarned >= _maxStarsPerWorld) {
      return Colors.green.shade400;
    }

    return Colors.orange.shade400;
  }

  /// ==========================================================================
  /// USER FEEDBACK
  /// ==========================================================================

  void _showLockedMessage() {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text('Complete the previous world to unlock this world.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  void _showErrorMessage() {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: const Text('Could not load your world progress.'),
          behavior: SnackBarBehavior.floating,
          action: SnackBarAction(label: 'Retry', onPressed: _loadProgress),
        ),
      );
  }

  /// ==========================================================================
  /// BUILD
  /// ==========================================================================

  @override
  Widget build(BuildContext context) {
    if (_isInitialLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Select World'), centerTitle: true),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Select World'), centerTitle: true),
      body: RefreshIndicator(
        onRefresh: _loadProgress,
        child: GridView.builder(
          padding: const EdgeInsets.all(16),
          physics: const AlwaysScrollableScrollPhysics(),
          itemCount: _totalWorlds,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            mainAxisExtent: 130,
          ),
          itemBuilder: (context, index) {
            final int worldNumber = index + 1;

            final bool isLocked = _isWorldLocked(worldNumber);

            final int starsEarned = _getWorldStars(worldNumber);

            return WorldTile(
              worldNumber: worldNumber,
              isLocked: isLocked,
              starsEarned: starsEarned,
              totalStars: _maxStarsPerWorld,
              color: _getWorldColor(isLocked, starsEarned),
              onTap: () => _onWorldTap(worldNumber, isLocked),
            );
          },
        ),
      ),
    );
  }
}
