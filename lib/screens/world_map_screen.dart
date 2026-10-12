import 'dart:async';

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
/// - Refresh progress when returning from a level map or when progress
///   changes elsewhere.
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
  // ==========================================================================
  // SERVICES
  // ==========================================================================

  final ProgressService _progressService = ProgressService();

  StreamSubscription<void>? _progressSubscription;

  // ==========================================================================
  // UI STATE
  // ==========================================================================

  /// Highest world currently unlocked by the player.
  int _highestUnlockedWorld = GameConfig.minimumWorld;

  /// Display data for every world (built once per load, not once per build).
  List<_WorldEntry> _worlds = const <_WorldEntry>[];

  /// Shows the full-screen loading state during the initial load.
  bool _isInitialLoading = true;

  /// True when the initial load failed and there is nothing to show.
  bool _hasError = false;

  /// A load is already running; the in-flight future is shared.
  Future<void>? _loadFuture;

  /// A load was requested while another was running; run once more after.
  bool _reloadQueued = false;

  /// Prevents several level maps being pushed by rapid taps.
  bool _isOpeningWorld = false;

  // ==========================================================================
  // LIFECYCLE
  // ==========================================================================

  @override
  void initState() {
    super.initState();

    unawaited(_loadProgress());

    // Keep the map in sync when progress changes while this screen is alive
    // (for example a progress reset or a completed world).
    _progressSubscription = _progressService.onProgressUpdate.listen((_) {
      if (!mounted) {
        return;
      }

      unawaited(_loadProgress());
    });
  }

  @override
  void dispose() {
    _progressSubscription?.cancel();

    super.dispose();
  }

  // ==========================================================================
  // LOAD PROGRESS
  // ==========================================================================

  /// Loads progress and rebuilds the world list.
  ///
  /// - Initial load: full-screen progress indicator.
  /// - Later loads: silent refresh (no loading flash when returning from a
  ///   level map).
  /// - A request that arrives while a load is running is NOT dropped: it is
  ///   queued and one more load runs afterwards, so the map can never end up
  ///   stale. The returned future completes after that extra load too, which
  ///   keeps pull-to-refresh accurate.
  Future<void> _loadProgress() {
    final Future<void>? running = _loadFuture;

    if (running != null) {
      _reloadQueued = true;

      return running;
    }

    final Future<void> future = _runLoadLoop().whenComplete(() {
      _loadFuture = null;
    });

    _loadFuture = future;

    return future;
  }

  Future<void> _runLoadLoop() async {
    bool succeeded = true;

    do {
      _reloadQueued = false;

      succeeded = await _loadOnce();
    } while (_reloadQueued && succeeded && mounted);
  }

  /// Performs one load. Never throws. Returns false when it failed.
  Future<bool> _loadOnce() async {
    try {
      // ONE snapshot: unlocked world and stars always agree with each other.
      final Map<String, dynamic> progress = await _progressService
          .loadProgress();

      if (!mounted) {
        return false;
      }

      final int highestUnlockedWorld = _clampInt(
        progress['highestUnlockedWorld'] is int
            ? progress['highestUnlockedWorld'] as int
            : GameConfig.minimumWorld,
        GameConfig.minimumWorld,
        GameConfig.totalWorlds,
      );

      final Map<int, int> starsPerWorld = _sumStarsPerWorld(progress['stars']);

      setState(() {
        _highestUnlockedWorld = highestUnlockedWorld;
        _worlds = _buildEntries(highestUnlockedWorld, starsPerWorld);
        _isInitialLoading = false;
        _hasError = false;
      });

      return true;
    } catch (error, stackTrace) {
      debugPrint('WorldMapScreen: failed to load progress: $error');
      debugPrintStack(stackTrace: stackTrace);

      if (!mounted) {
        return false;
      }

      final bool hadData = _worlds.isNotEmpty;

      setState(() {
        _isInitialLoading = false;

        // Never present default values (world 1 only, 0 stars) as if they
        // were the player's real progress: show an error view instead.
        _hasError = !hadData;
      });

      if (hadData) {
        _showMessage(
          'Could not load your world progress.',
          action: SnackBarAction(
            label: 'Retry',
            onPressed: () => unawaited(_loadProgress()),
          ),
        );
      }

      return false;
    }
  }

  // ==========================================================================
  // PROGRESS PARSING
  // ==========================================================================

  /// Sums earned stars per world from the persisted level -> stars map.
  Map<int, int> _sumStarsPerWorld(Object? rawStars) {
    final Map<int, int> totals = <int, int>{};

    if (rawStars is! Map) {
      return totals;
    }

    rawStars.forEach((Object? key, Object? value) {
      final int? level = int.tryParse(key.toString());

      if (level == null ||
          value is! int ||
          !GameConfig.isValidGlobalLevel(level)) {
        return;
      }

      final int world = GameConfig.getWorldFromGlobalLevel(level);

      totals[world] = (totals[world] ?? 0) + value;
    });

    return totals;
  }

  List<_WorldEntry> _buildEntries(
    int highestUnlockedWorld,
    Map<int, int> starsPerWorld,
  ) {
    return List<_WorldEntry>.generate(GameConfig.totalWorlds, (int index) {
      final int world = GameConfig.minimumWorld + index;
      final bool isLocked = world > highestUnlockedWorld;

      final int starsEarned = isLocked
          ? 0
          : _clampInt(
              starsPerWorld[world] ?? 0,
              0,
              GameConfig.maxStarsPerWorld,
            );

      return _WorldEntry(
        worldNumber: world,
        isLocked: isLocked,
        starsEarned: starsEarned,
        color: _getWorldColor(isLocked, starsEarned),
      );
    }, growable: false);
  }

  static int _clampInt(int value, int minimum, int maximum) {
    if (value < minimum) {
      return minimum;
    }

    if (value > maximum) {
      return maximum;
    }

    return value;
  }

  // ==========================================================================
  // WORLD COLOR
  // ==========================================================================

  Color _getWorldColor(bool isLocked, int starsEarned) {
    if (isLocked) {
      return Colors.grey.shade300;
    }

    if (starsEarned >= GameConfig.maxStarsPerWorld) {
      return Colors.green.shade400;
    }

    return Colors.orange.shade400;
  }

  // ==========================================================================
  // WORLD TAP HANDLER
  // ==========================================================================

  Future<void> _onWorldTap(int worldNumber) async {
    if (!mounted || _isOpeningWorld) {
      return;
    }

    if (!GameConfig.isValidWorld(worldNumber)) {
      _showMessage('This world is not available.');
      return;
    }

    // Uses the CURRENT state, not a value captured when the tile was built.
    if (worldNumber > _highestUnlockedWorld) {
      _showMessage('Complete the previous world to unlock this world.');
      return;
    }

    _isOpeningWorld = true;

    bool opened = false;

    try {
      await Navigator.pushNamed(
        context,
        AppRoutes.levels,
        arguments: worldNumber,
      );

      opened = true;
    } catch (error, stackTrace) {
      debugPrint('WorldMapScreen: failed to open world $worldNumber: $error');
      debugPrintStack(stackTrace: stackTrace);

      if (mounted) {
        _showMessage('Could not open this world.');
      }
    } finally {
      _isOpeningWorld = false;
    }

    // Refresh progress after returning from LevelMapScreen: the player may
    // have completed the final level of a world and unlocked the next one.
    if (opened && mounted) {
      unawaited(_loadProgress());
    }
  }

  // ==========================================================================
  // BACK NAVIGATION
  // ==========================================================================

  /// LevelMapScreen can replace the whole stack and become the root route;
  /// if the player then goes back to this screen via replacement, back would
  /// close the app. When this is the root route, back goes Home instead.
  void _goHome() {
    if (!mounted) {
      return;
    }

    unawaited(Navigator.pushReplacementNamed(context, AppRoutes.home));
  }

  // ==========================================================================
  // USER FEEDBACK
  // ==========================================================================

  void _showMessage(String message, {SnackBarAction? action}) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          action: action,
        ),
      );
  }

  // ==========================================================================
  // BUILD
  // ==========================================================================

  @override
  Widget build(BuildContext context) {
    final bool isRootRoute = ModalRoute.of(context)?.isFirst ?? false;

    return PopScope(
      canPop: !isRootRoute,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (!didPop) {
          _goHome();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            tooltip: 'Back',
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              if (isRootRoute) {
                // The world map has no previous route, so return Home.
                _goHome();
              } else {
                // Return to the existing screen underneath the world map.
                Navigator.maybePop(context);
              }
            },
          ),
          title: const Text('Select World'),
          centerTitle: true,
        ),
        body: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isInitialLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_hasError) {
      return _buildErrorState();
    }

    return RefreshIndicator(
      onRefresh: _loadProgress,
      child: GridView.builder(
        padding: const EdgeInsets.all(16),
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: _worlds.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          mainAxisExtent: 130,
        ),
        itemBuilder: (BuildContext context, int index) {
          final _WorldEntry world = _worlds[index];

          return WorldTile(
            worldNumber: world.worldNumber,
            isLocked: world.isLocked,
            starsEarned: world.starsEarned,
            totalStars: GameConfig.maxStarsPerWorld,
            color: world.color,
            onTap: () => _onWorldTap(world.worldNumber),
            onLockedTap: () => _onWorldTap(world.worldNumber), // shows the locked message
          );
        },
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            const Text(
              'Could not load worlds',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              'Your world progress could not be loaded.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () {
                setState(() {
                  _isInitialLoading = true;
                  _hasError = false;
                });

                unawaited(_loadProgress());
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// INTERNAL TYPES
// ============================================================================

/// Everything a world tile needs, computed once per load.
class _WorldEntry {
  final int worldNumber;
  final bool isLocked;
  final int starsEarned;
  final Color color;

  const _WorldEntry({
    required this.worldNumber,
    required this.isLocked,
    required this.starsEarned,
    required this.color,
  });
}