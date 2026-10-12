import 'dart:async';

import 'package:flutter/material.dart';

import '../config/game_config.dart';
import '../core/navigation.dart';
import '../services/progress_service.dart';
import '../widgets/enhanced_level_tile.dart';

/// ============================================================================
/// LevelMapScreen
/// ----------------------------------------------------------------------------
/// Displays all levels belonging to a world.
///
/// IMPORTANT:
/// - The global level number is the single canonical level ID.
/// - There is no local-vs-global level conversion in this screen.
/// - ProgressService uses the same global level ID.
/// - GameScreen receives the same global level ID.
/// - World is only used to determine which levels are displayed.
///
/// Data:
/// - The map only needs each level's number, stars and lock state, so it
///   reads ONE snapshot from ProgressService instead of building full
///   puzzle/solution data for all levels of the world.
///
/// Navigation:
/// - Opening a level pushes GameScreen.
/// - Returning from GameScreen refreshes this map.
/// - Completion-to-map navigation is handled by WinScreen.
/// - WinScreen may replace the entire navigation stack with a fresh
///   LevelMapScreen, so this screen always loads its state from services and
///   handles being the root route (back goes to the world map).
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
  // --------------------------------------------------------------------------
  // LAYOUT
  // --------------------------------------------------------------------------

  static const int _itemsPerRow = 5;
  static const double _itemHeight = 80.0;
  static const double _gridSpacing = 12.0;
  static const double _gridPadding = 16.0;

  // --------------------------------------------------------------------------
  // DEPENDENCIES
  // --------------------------------------------------------------------------

  final ProgressService _progressService = ProgressService();
  final ScrollController _scrollController = ScrollController();

  StreamSubscription<void>? _progressSubscription;

  // --------------------------------------------------------------------------
  // STATE
  // --------------------------------------------------------------------------

  List<_LevelEntry> _levels = const <_LevelEntry>[];

  int _currentLevel = GameConfig.minimumLevel;

  /// True until the first load finishes (full-screen spinner).
  bool _isLoading = true;

  /// True while a load is running (disables the refresh button).
  bool _isRefreshing = false;

  /// True when a load failed and there is nothing to show.
  bool _hasError = false;

  /// A load was requested while another was running; run once more after.
  bool _reloadQueued = false;

  bool _isOpeningLevel = false;

  /// Current level for which auto-scroll last ran, so the map only scrolls
  /// when the current level actually changes (not on every refresh).
  int? _lastScrolledLevel;

  // ==========================================================================
  // LIFECYCLE
  // ==========================================================================

  @override
  void initState() {
    super.initState();

    // State is already "loading"; no setState needed before first build.
    unawaited(_loadData(showSpinner: true, notify: false));

    // Refresh automatically when progression changes elsewhere.
    _progressSubscription = _progressService.onProgressUpdate.listen((_) {
      if (!mounted) {
        return;
      }

      unawaited(_loadData());
    });
  }

  @override
  void didUpdateWidget(LevelMapScreen oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.world != widget.world) {
      _levels = const <_LevelEntry>[];
      _lastScrolledLevel = null;

      unawaited(_loadData(showSpinner: true, notify: false));
    }
  }

  @override
  void dispose() {
    _progressSubscription?.cancel();
    _scrollController.dispose();

    super.dispose();
  }

  // ==========================================================================
  // LOAD LEVELS + PROGRESS
  // ==========================================================================

  /// Applies [change] and rebuilds, unless [notify] is false (used during
  /// initState/didUpdateWidget, where a rebuild is already coming).
  void _update(VoidCallback change, {required bool notify}) {
    if (notify) {
      setState(change);
    } else {
      change();
    }
  }

  /// Loads the world's levels and progress.
  ///
  /// Requests that arrive while a load is running are not dropped: they are
  /// queued and one more load runs afterwards, so the map can never end up
  /// showing stale data.
  Future<void> _loadData({
    bool showSpinner = false,
    bool notify = true,
  }) async {
    if (!mounted) {
      return;
    }

    if (_isRefreshing) {
      _reloadQueued = true;
      return;
    }

    if (!GameConfig.isValidWorld(widget.world)) {
      _update(() {
        _levels = const <_LevelEntry>[];
        _isLoading = false;
        _hasError = false;
      }, notify: notify);

      return;
    }

    _update(() {
      _isRefreshing = true;
      _hasError = false;

      if (showSpinner) {
        _isLoading = true;
      }
    }, notify: notify);

    bool failed = false;

    do {
      _reloadQueued = false;

      try {
        final _MapSnapshot snapshot = await _readSnapshot();

        if (!mounted) {
          return;
        }

        setState(() {
          _levels = snapshot.levels;
          _currentLevel = snapshot.currentLevel;
          _isLoading = false;
          _hasError = false;
        });

        _scheduleScrollToCurrentLevel();
      } catch (error, stackTrace) {
        failed = true;

        debugPrint('LevelMapScreen load error: $error');
        debugPrintStack(stackTrace: stackTrace);

        if (!mounted) {
          return;
        }

        final bool hasLevels = _levels.isNotEmpty;

        setState(() {
          _isLoading = false;

          // Keep showing existing levels on a failed refresh; only show the
          // error view when there is nothing to display.
          _hasError = !hasLevels;
        });

        if (hasLevels) {
          _showMessage('Could not refresh levels. Please try again.');
        }
      }
    } while (_reloadQueued && !failed && mounted);

    if (!mounted) {
      return;
    }

    setState(() {
      _isRefreshing = false;
    });
  }

  /// Reads one consistent progress snapshot and builds the tile data.
  Future<_MapSnapshot> _readSnapshot() async {
    final Map<String, dynamic> progress = await _progressService
        .loadProgress();

    final int currentLevel = _readCurrentLevel(progress['currentLevel']);
    final Set<int> completed = _readCompletedLevels(
      progress['completedLevels'],
    );
    final Map<int, int> stars = _readStars(progress['stars']);

    final int firstLevel = GameConfig.getFirstLevelForWorld(widget.world);
    final int lastLevel = GameConfig.getLastLevelForWorld(widget.world);

    final List<_LevelEntry> levels = <_LevelEntry>[
      for (int level = firstLevel; level <= lastLevel; level++)
        _LevelEntry(
          levelNumber: level,
          stars: stars[level] ?? 0,
          state: _tileStateFor(level, currentLevel, completed),
        ),
    ];

    return _MapSnapshot(
      levels: List<_LevelEntry>.unmodifiable(levels),
      currentLevel: currentLevel,
    );
  }

  // ==========================================================================
  // PROGRESS PARSING
  // ==========================================================================

  int _readCurrentLevel(Object? raw) {
    if (raw is int && GameConfig.isValidGlobalLevel(raw)) {
      return raw;
    }

    return GameConfig.minimumLevel;
  }

  Set<int> _readCompletedLevels(Object? raw) {
    if (raw is! List) {
      return <int>{};
    }

    return raw.whereType<int>().toSet();
  }

  Map<int, int> _readStars(Object? raw) {
    if (raw is! Map) {
      return <int, int>{};
    }

    final Map<int, int> result = <int, int>{};

    raw.forEach((Object? key, Object? value) {
      final int? level = int.tryParse(key.toString());

      if (level != null && value is int) {
        result[level] = value;
      }
    });

    return result;
  }

  // ==========================================================================
  // LEVEL STATE
  // ==========================================================================

  /// Uses ONE level number everywhere.
  ///
  /// Example with currentLevel = 27:
  ///
  ///   26 -> completed
  ///   27 -> in progress
  ///   28 -> locked
  ///
  /// When the whole campaign is finished the final level is both "current"
  /// and completed, so it is shown as completed.
  LevelTileState _tileStateFor(
    int levelNumber,
    int currentLevel,
    Set<int> completed,
  ) {
    if (levelNumber > currentLevel) {
      return LevelTileState.locked;
    }

    if (levelNumber < currentLevel || completed.contains(levelNumber)) {
      return LevelTileState.completed;
    }

    return LevelTileState.inProgress;
  }

  // ==========================================================================
  // AUTO SCROLL
  // ==========================================================================

  /// Scrolls to the current level once per change of current level.
  void _scheduleScrollToCurrentLevel() {
    if (_lastScrolledLevel == _currentLevel) {
      return;
    }

    _lastScrolledLevel = _currentLevel;

    // Wait until the grid has been laid out before attempting to scroll.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      _scrollToCurrentLevel();
    });
  }

  void _scrollToCurrentLevel() {
    if (!_scrollController.hasClients || _levels.isEmpty) {
      return;
    }

    final int index = _levels.indexWhere(
      (_LevelEntry entry) => entry.levelNumber == _currentLevel,
    );

    // The current level may belong to another world.
    if (index == -1) {
      return;
    }

    final ScrollPosition position = _scrollController.position;

    final int row = index ~/ _itemsPerRow;
    final double rowTop = _gridPadding + (row * (_itemHeight + _gridSpacing));

    // Center the current row instead of pinning it to the top edge.
    final double target = (rowTop -
            ((position.viewportDimension - _itemHeight) / 2))
        .clamp(0.0, position.maxScrollExtent)
        .toDouble();

    if ((target - position.pixels).abs() < 1.0) {
      return;
    }

    // Respect the system "reduce motion" accessibility setting.
    if (MediaQuery.disableAnimationsOf(context)) {
      _scrollController.jumpTo(target);
      return;
    }

    unawaited(
      _scrollController.animateTo(
        target,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      ),
    );
  }

  // ==========================================================================
  // OPEN LEVEL
  // ==========================================================================

  Future<void> _openLevel(_LevelEntry entry) async {
    if (!mounted || _isOpeningLevel) {
      return;
    }

    final int levelNumber = entry.levelNumber;

    // Do not allow future/locked levels.
    if (levelNumber > _currentLevel) {
      _showMessage('Complete previous levels first!');
      return;
    }

    // Defensive validation before navigation.
    if (!GameConfig.isValidGlobalLevel(levelNumber)) {
      _showMessage('This level is not available.');
      return;
    }

    _isOpeningLevel = true;

    bool opened = false;

    try {
      await Navigator.pushNamed(
        context,
        AppRoutes.game,
        arguments: GameArguments(levelNumber: levelNumber),
      );

      opened = true;
    } catch (error, stackTrace) {
      debugPrint('Failed to open level $levelNumber: $error');
      debugPrintStack(stackTrace: stackTrace);

      if (mounted) {
        _showMessage('Could not open this level.');
      }
    } finally {
      // Released as soon as navigation finishes, not after the reload.
      _isOpeningLevel = false;
    }

    // Progress may have changed while playing. If a reload is already
    // running it is queued, so this can never be lost.
    if (opened && mounted) {
      unawaited(_loadData());
    }
  }

  // ==========================================================================
  // BACK NAVIGATION
  // ==========================================================================

  /// WinScreen can replace the whole stack with this screen, making it the
  /// root route. Back would then close the app, so go to the world map.
  void _goToWorldMap() {
    if (!mounted) {
      return;
    }

    unawaited(Navigator.pushReplacementNamed(context, AppRoutes.worlds));
  }

  // ==========================================================================
  // FEEDBACK
  // ==========================================================================

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  // ==========================================================================
  // UI
  // ==========================================================================

  @override
  Widget build(BuildContext context) {
    final bool isRootRoute = ModalRoute.of(context)?.isFirst ?? false;

    return PopScope(
      canPop: !isRootRoute,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (!didPop) {
          _goToWorldMap();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            tooltip: 'Back to World Map',
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              if (isRootRoute) {
                // This map was opened as a fresh root route by WinScreen.
                _goToWorldMap();
              } else {
                // A world map already exists underneath this screen.
                Navigator.maybePop(context);
              }
            },
          ),
          title: Text('World ${widget.world}'),
          centerTitle: true,
          actions: <Widget>[
            if (!_isLoading)
              IconButton(
                tooltip: 'Refresh',
                onPressed: _isRefreshing ? null : () => _loadData(),
                icon: const Icon(Icons.refresh),
              ),
          ],
        ),
        body: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_hasError) {
      return _buildErrorState();
    }

    if (_levels.isEmpty) {
      return _buildEmptyState();
    }

    return GridView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(_gridPadding),
      itemCount: _levels.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: _itemsPerRow,
        crossAxisSpacing: _gridSpacing,
        mainAxisSpacing: _gridSpacing,
        mainAxisExtent: _itemHeight,
      ),
      itemBuilder: (BuildContext context, int index) {
        final _LevelEntry entry = _levels[index];

        return EnhancedLevelTile(
          levelNumber: entry.levelNumber,
          state: entry.state,
          stars: entry.stars,

          // EnhancedLevelTile requires a non-nullable callback. Duplicate
          // navigation is prevented inside _openLevel() by _isOpeningLevel.
          onTap: () => _openLevel(entry),
          onLockedTap: () => _openLevel(entry), // shows "Complete previous levels first!"
        );
      },
    );
  }

  // ==========================================================================
  // EMPTY / ERROR STATES
  // ==========================================================================

  Widget _buildEmptyState() {
    return _buildMessageState(
      icon: Icons.grid_view_outlined,
      title: 'No levels available',
      message: 'There are currently no levels in World ${widget.world}.',
    );
  }

  Widget _buildErrorState() {
    return _buildMessageState(
      icon: Icons.error_outline,
      title: 'Could not load levels',
      message: 'Something went wrong while loading World ${widget.world}.',
    );
  }

  Widget _buildMessageState({
    required IconData icon,
    required String title,
    required String message,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(
              icon,
              size: 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _isRefreshing
                  ? null
                  : () => _loadData(showSpinner: true),
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

/// Everything a level tile needs; no puzzle data.
class _LevelEntry {
  final int levelNumber;
  final int stars;
  final LevelTileState state;

  const _LevelEntry({
    required this.levelNumber,
    required this.stars,
    required this.state,
  });
}

/// One consistent read of progress for this world.
class _MapSnapshot {
  final List<_LevelEntry> levels;
  final int currentLevel;

  const _MapSnapshot({
    required this.levels,
    required this.currentLevel,
  });
}