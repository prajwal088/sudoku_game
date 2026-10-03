import 'package:flutter/material.dart';

import '../config/game_config.dart';
import '../core/navigation.dart';
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
/// - ProgressService is the source of truth for player progression.
/// - GameConfig is the source of truth for static game configuration.
/// - WorldMapScreen owns only UI state.
/// - WorldTile is responsible for rendering an individual world.
///
/// IMPORTANT:
/// - WorldMapScreen works with WORLD numbers only.
/// - LevelMapScreen/GameScreen work with LEVEL numbers.
/// - There is no local/global level conversion in this screen.
/// - Route definitions belong to navigation.dart.
/// - Game configuration belongs to GameConfig.
/// ============================================================================

class WorldMapScreen extends StatefulWidget {
  const WorldMapScreen({super.key});

  @override
  State<WorldMapScreen> createState() => _WorldMapScreenState();
}

class _WorldMapScreenState extends State<WorldMapScreen> {
  /// ==========================================================================
  /// SERVICES
  /// ==========================================================================

  final ProgressService _progressService = ProgressService();

  /// ==========================================================================
  /// UI STATE
  /// ==========================================================================

  /// Highest world currently unlocked by the player.
  int _highestUnlockedWorld = GameConfig.minimumWorld;

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
  /// Both operations are independent and are executed in parallel.
  ///
  /// Initial load:
  /// - Displays a full-screen progress indicator.
  ///
  /// Subsequent loads:
  /// - Refreshes data silently.
  /// - Prevents the world map from flashing a loading screen when the player
  ///   returns from LevelMapScreen.
  Future<void> _loadProgress() async {
    if (_isLoading) return;

    _isLoading = true;

    try {
      final Future<int> highestUnlockedWorldFuture =
          _progressService.getHighestUnlockedWorld();

      final Future<Map<int, int>> worldStarsFuture =
          _progressService.getAllWorldStars(
        GameConfig.totalWorlds,
      );

      final int unlockedWorld = await highestUnlockedWorldFuture;
      final Map<int, int> stars = await worldStarsFuture;

      if (!mounted) return;

      setState(() {
        _highestUnlockedWorld = unlockedWorld.clamp(
          GameConfig.minimumWorld,
          GameConfig.totalWorlds,
        );

        _worldStars = Map<int, int>.from(stars);

        _isInitialLoading = false;
      });
    } catch (error, stackTrace) {
      debugPrint(
        'WorldMapScreen: failed to load progress: $error',
      );

      debugPrintStack(
        stackTrace: stackTrace,
      );

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

  Future<void> _onWorldTap(
    int worldNumber,
    bool isLocked,
  ) async {
    if (!mounted) return;

    if (worldNumber < GameConfig.minimumWorld ||
        worldNumber > GameConfig.totalWorlds) {
      _showMessage('This world is not available.');
      return;
    }

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
    } catch (error, stackTrace) {
      debugPrint(
        'WorldMapScreen: failed to open world '
        '$worldNumber: $error',
      );

      debugPrintStack(
        stackTrace: stackTrace,
      );

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

    final int stars = _worldStars[worldNumber] ?? 0;

    return stars.clamp(0, _maxStarsPerWorld);
  }

  /// Maximum possible stars for one world.
  int get _maxStarsPerWorld =>
      GameConfig.levelsPerWorld * GameConfig.maxStarsPerLevel;

  /// ==========================================================================
  /// WORLD COLOR
  /// ==========================================================================

  Color _getWorldColor(
    bool isLocked,
    int starsEarned,
  ) {
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
          content: Text(
            'Complete the previous world to unlock this world.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
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
          content: const Text(
            'Could not load your world progress.',
          ),
          behavior: SnackBarBehavior.floating,
          action: SnackBarAction(
            label: 'Retry',
            onPressed: _loadProgress,
          ),
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
        appBar: AppBar(
          title: const Text('Select World'),
          centerTitle: true,
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Select World'),
        centerTitle: true,
      ),
      body: RefreshIndicator(
        onRefresh: _loadProgress,
        child: GridView.builder(
          padding: const EdgeInsets.all(16),
          physics: const AlwaysScrollableScrollPhysics(),
          itemCount: GameConfig.totalWorlds,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            mainAxisExtent: 130,
          ),
          itemBuilder: (
            BuildContext context,
            int index,
          ) {
            final int worldNumber =
                GameConfig.minimumWorld + index;

            final bool isLocked =
                _isWorldLocked(worldNumber);

            final int starsEarned =
                _getWorldStars(worldNumber);

            return WorldTile(
              worldNumber: worldNumber,
              isLocked: isLocked,
              starsEarned: starsEarned,
              totalStars: _maxStarsPerWorld,
              color: _getWorldColor(
                isLocked,
                starsEarned,
              ),
              onTap: () => _onWorldTap(
                worldNumber,
                isLocked,
              ),
            );
          },
        ),
      ),
    );
  }
}