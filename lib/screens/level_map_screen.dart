import 'dart:async';

import 'package:flutter/material.dart';

import '../config/game_config.dart';
import '../models/level.dart';
import '../core/navigation.dart';
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

  static const int _itemsPerRow = 5;
  static const double _itemHeight = 80.0;
  static const double _gridSpacing = 12.0;

  @override
  void initState() {
    super.initState();

    _loadData();

    /// Refresh automatically when progress changes elsewhere in the app.
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
    if (_isRefreshing) {
      return;
    }

    if (!_isValidWorldNumber(widget.world)) {
      if (mounted) {
        setState(() {
          _levels = const <Level>[];
          _isLoading = false;
          _isRefreshing = false;
        });
      }

      return;
    }

    if (mounted) {
      setState(() {
        _isRefreshing = true;

        if (!refreshOnly) {
          _isLoading = true;
        }
      });
    }

    try {
      /// Load both pieces of information concurrently.
      ///
      /// IMPORTANT:
      /// Level.levelNumber remains the canonical/global level ID.
      final Future<List<Level>> levelsFuture =
          _levelService.getLevelsByWorld(widget.world);

      final Future<int> currentLevelFuture =
          _progressService.getNextUnlockedLevel();

      final List<Level> loadedLevels = await levelsFuture;
      final int currentLevel = await currentLevelFuture;

      if (!mounted) {
        return;
      }

      setState(() {
        _levels = loadedLevels;
        _currentLevel = currentLevel;
        _isLoading = false;
        _isRefreshing = false;
      });

      /// Scroll after the grid has been laid out.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _scrollToCurrentLevel();
        }
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

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Could not load levels. Please try again.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
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
    if (!_scrollController.hasClients || _levels.isEmpty) {
      return;
    }

    final int index = _levels.indexWhere(
      (Level level) => level.levelNumber == _currentLevel,
    );

    /// Current level is not part of this world.
    if (index == -1) {
      return;
    }

    final int row = index ~/ _itemsPerRow;

    final double maxExtent =
        _scrollController.position.maxScrollExtent;

    final double targetOffset = (row * (_itemHeight + _gridSpacing))
        .clamp(0.0, maxExtent);

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
    if (!mounted) {
      return;
    }

    final int levelNumber = level.levelNumber;

    /// Do not allow future/locked levels.
    if (levelNumber > _currentLevel) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Complete previous levels first!',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );

      return;
    }

    try {
      await Navigator.pushNamed(
        context,
        AppRoutes.game,
        arguments: GameArguments(
          levelNumber: levelNumber,
        ),
      );

      /// Progress may have changed after returning from GameScreen.
      if (!mounted) {
        return;
      }

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

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Could not open this level.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
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