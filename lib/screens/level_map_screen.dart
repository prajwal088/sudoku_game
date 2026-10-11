import 'dart:async';

import 'package:flutter/material.dart';

import '../config/game_config.dart';
import '../core/navigation.dart';
import '../models/level.dart';
import '../services/level_service.dart';
import '../services/progress_service.dart';
import '../widgets/enhanced_level_tile.dart';

/// ============================================================================
/// LevelMapScreen
/// ----------------------------------------------------------------------------
/// Displays all levels belonging to a world.
///
/// IMPORTANT:
/// - Level.levelNumber is the single canonical/global level ID.
/// - There is no local-vs-global level conversion in this screen.
/// - ProgressService uses the same global level ID.
/// - GameScreen receives the same global level ID.
/// - World is only used to determine which levels are displayed.
///
/// Navigation:
/// - Opening a level pushes GameScreen.
/// - Returning from GameScreen refreshes this map.
/// - Completion-to-map navigation is handled by WinScreen.
/// - WinScreen may replace the entire navigation stack with a fresh
///   LevelMapScreen, so this screen must always load its state from services.
/// ============================================================================

class LevelMapScreen extends StatefulWidget {
  final int world;

  const LevelMapScreen({
    super.key,
    required this.world,
  });

  @override
  State<LevelMapScreen> createState() => _LevelMapScreenState();
}

class _LevelMapScreenState extends State<LevelMapScreen> {
  final LevelService _levelService = LevelService();
  final ProgressService _progressService = ProgressService();

  final ScrollController _scrollController = ScrollController();

  StreamSubscription<void>? _progressSubscription;

  List<Level> _levels = const <Level>[];

  int _currentLevel = GameConfig.minimumLevel;

  bool _isLoading = true;
  bool _isRefreshing = false;
  bool _isOpeningLevel = false;

  static const int _itemsPerRow = 5;
  static const double _itemHeight = 80.0;
  static const double _gridSpacing = 12.0;

  @override
  void initState() {
    super.initState();

    _loadData();

    /// Refresh automatically when progression changes elsewhere.
    ///
    /// This keeps the map synchronized if another screen or service updates
    /// ProgressService while this screen is alive.
    _progressSubscription =
        _progressService.onProgressUpdate.listen((_) {
      if (!mounted) {
        return;
      }

      _loadData(refreshOnly: true);
    });
  }

  /// ========================================================================
  /// LOAD LEVELS + PROGRESS
  /// ========================================================================

  Future<void> _loadData({
    bool refreshOnly = false,
  }) async {
    if (!mounted || _isRefreshing) {
      return;
    }

    if (!_isValidWorldNumber(widget.world)) {
      setState(() {
        _levels = const <Level>[];
        _isLoading = false;
        _isRefreshing = false;
      });

      return;
    }

    setState(() {
      _isRefreshing = true;

      if (!refreshOnly) {
        _isLoading = true;
      }
    });

    try {
      /// Load levels and progression independently.
      ///
      /// Both operations use the same canonical global level numbering.
      final Future<List<Level>> levelsFuture =
          _levelService.getLevelsByWorld(widget.world);

      final Future<int> currentLevelFuture =
          _progressService.getNextUnlockedLevel();

      final List<Level> loadedLevels = await levelsFuture;
      final int currentLevel = await currentLevelFuture;

      if (!mounted) {
        return;
      }

      /// Defensive validation:
      /// LevelService should already return only levels belonging to this
      /// world, but filtering here prevents malformed repository data from
      /// leaking into the UI.
      final List<Level> validLevels = loadedLevels
          .where(
            (Level level) => _isLevelInWorld(
              level.levelNumber,
              widget.world,
            ),
          )
          .toList(growable: false);

      setState(() {
        _levels = validLevels;
        _currentLevel = currentLevel;
        _isLoading = false;
        _isRefreshing = false;
      });

      /// Wait until the grid has been laid out before attempting to scroll.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }

        _scrollToCurrentLevel();
      });
    } catch (error, stackTrace) {
      debugPrint(
        'LevelMapScreen load error: $error',
      );

      debugPrintStack(
        stackTrace: stackTrace,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
        _isRefreshing = false;
      });

      _showMessage(
        'Could not load levels. Please try again.',
      );
    }
  }

  /// ========================================================================
  /// VALIDATION
  /// ========================================================================

  bool _isValidWorldNumber(int world) {
    return world >= GameConfig.minimumWorld &&
        world <= GameConfig.totalWorlds;
  }

  bool _isLevelInWorld(
    int levelNumber,
    int world,
  ) {
    if (levelNumber < GameConfig.minimumLevel ||
        levelNumber > GameConfig.totalLevels) {
      return false;
    }

    final int calculatedWorld =
        ((levelNumber - GameConfig.minimumLevel) ~/
                GameConfig.levelsPerWorld) +
            GameConfig.minimumWorld;

    return calculatedWorld == world;
  }

  /// ========================================================================
  /// LEVEL STATE
  /// ========================================================================
  ///
  /// Uses ONE level number everywhere.
  ///
  /// Example:
  ///
  ///   currentLevel = 27
  ///
  ///   26 -> completed
  ///   27 -> in progress
  ///   28 -> locked
  ///
  LevelTileState _getTileState(Level level) {
    if (level.levelNumber > _currentLevel) {
      return LevelTileState.locked;
    }

    if (level.levelNumber < _currentLevel) {
      return LevelTileState.completed;
    }

    return LevelTileState.inProgress;
  }

  /// ========================================================================
  /// AUTO SCROLL
  /// ========================================================================

  void _scrollToCurrentLevel() {
    if (!mounted ||
        !_scrollController.hasClients ||
        _levels.isEmpty) {
      return;
    }

    final int index = _levels.indexWhere(
      (Level level) => level.levelNumber == _currentLevel,
    );

    /// The current level may belong to another world.
    if (index == -1) {
      return;
    }

    final int row = index ~/ _itemsPerRow;

    final double maxExtent =
        _scrollController.position.maxScrollExtent;

    final double targetOffset =
        (row * (_itemHeight + _gridSpacing))
            .clamp(0.0, maxExtent);

    if ((targetOffset -
                _scrollController.position.pixels)
            .abs() <
        1.0) {
      return;
    }

    _scrollController.animateTo(
      targetOffset,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
    );
  }

  /// ========================================================================
  /// OPEN LEVEL
  /// ========================================================================

  Future<void> _openLevel(Level level) async {
    if (!mounted || _isOpeningLevel) {
      return;
    }

    final int levelNumber = level.levelNumber;

    /// Do not allow future/locked levels.
    if (levelNumber > _currentLevel) {
      _showMessage(
        'Complete previous levels first!',
      );

      return;
    }

    /// Defensive validation before navigation.
    if (levelNumber < GameConfig.minimumLevel ||
        levelNumber > GameConfig.totalLevels) {
      _showMessage(
        'This level is not available.',
      );

      return;
    }

    _isOpeningLevel = true;

    try {
      await Navigator.pushNamed(
        context,
        AppRoutes.game,
        arguments: GameArguments(
          levelNumber: levelNumber,
        ),
      );

      if (!mounted) {
        return;
      }

      /// Progress may have changed after returning from GameScreen.
      ///
      /// This is intentionally retained even though ProgressService also
      /// emits progress updates. It gives this screen an explicit refresh
      /// after the navigation operation completes.
      await _loadData(refreshOnly: true);
    } catch (error, stackTrace) {
      debugPrint(
        'Failed to open level $levelNumber: $error',
      );

      debugPrintStack(
        stackTrace: stackTrace,
      );

      if (!mounted) {
        return;
      }

      _showMessage(
        'Could not open this level.',
      );
    } finally {
      if (mounted) {
        _isOpeningLevel = false;
      }
    }
  }

  /// ========================================================================
  /// FEEDBACK
  /// ========================================================================

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }

    final ScaffoldMessengerState messenger =
        ScaffoldMessenger.of(context);

    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  /// ========================================================================
  /// UI
  /// ========================================================================

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: Text('World ${widget.world}'),
          centerTitle: true,
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('World ${widget.world}'),
        centerTitle: true,
        actions: <Widget>[
          IconButton(
            tooltip: 'Refresh',
            onPressed: _isRefreshing
                ? null
                : () => _loadData(refreshOnly: true),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _levels.isEmpty
          ? _buildEmptyState()
          : GridView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: _levels.length,
              gridDelegate:
                  const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: _itemsPerRow,
                crossAxisSpacing: _gridSpacing,
                mainAxisSpacing: _gridSpacing,
                mainAxisExtent: _itemHeight,
              ),
              itemBuilder: (
                BuildContext context,
                int index,
              ) {
                final Level level = _levels[index];

                return EnhancedLevelTile(
                  levelNumber: level.levelNumber,
                  state: _getTileState(level),
                  stars: level.stars,

                  /// EnhancedLevelTile requires a non-nullable callback.
                  ///
                  /// Duplicate navigation is prevented inside _openLevel()
                  /// by the _isOpeningLevel guard.
                  onTap: () => _openLevel(level),
                );
              },
            ),
    );
  }

  /// ========================================================================
  /// EMPTY STATE
  /// ========================================================================

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(
              Icons.grid_view_outlined,
              size: 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            const Text(
              'No levels available',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'There are currently no levels in World ${widget.world}.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _isRefreshing
                  ? null
                  : () => _loadData(refreshOnly: true),
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }

  /// ========================================================================
  /// DISPOSE
  /// ========================================================================

  @override
  void dispose() {
    _progressSubscription?.cancel();
    _scrollController.dispose();

    super.dispose();
  }
}