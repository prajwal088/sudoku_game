import 'dart:async';

import 'package:flutter/material.dart';

import '../config/game_config.dart';
import '../services/progress_service.dart';
import '../widgets/statistics_card.dart';

/// ============================================================================
/// StatisticsScreen
/// ----------------------------------------------------------------------------
/// Displays lifetime Sudoku statistics.
///
/// Responsibilities:
/// - Load global player statistics.
/// - Display completion progress.
/// - Display total stars earned.
/// - Display total time played.
/// - Display average solve time.
/// - Refresh automatically when progress changes.
/// - Handle loading and error states safely.
///
/// Architecture:
/// - ProgressService is the single source of truth for progression data.
/// - GameConfig provides global game configuration.
/// - This screen is presentation-focused and does not modify progress.
/// - Statistics are parsed ONCE per load into an immutable snapshot, not on
///   every build.
/// ============================================================================
class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({super.key});

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  final ProgressService _progressService = ProgressService();

  StreamSubscription<void>? _progressSubscription;

  _StatsSnapshot? _stats;

  /// Full-screen spinner (first load, or retry from the error view).
  bool _isLoading = true;

  /// A load is running (disables the refresh button).
  bool _isRefreshing = false;

  /// The in-flight load, shared by concurrent callers.
  Future<void>? _loadFuture;

  /// A load was requested while another was running; run once more after.
  bool _reloadQueued = false;

  // ==========================================================================
  // LIFECYCLE
  // ==========================================================================

  @override
  void initState() {
    super.initState();

    // No setState needed before the first build (state is already loading).
    unawaited(_loadStats(notify: false));

    // Refresh statistics whenever progress changes elsewhere in the app.
    _progressSubscription = _progressService.onProgressUpdate.listen((_) {
      if (!mounted) return;

      unawaited(_loadStats());
    });
  }

  @override
  void dispose() {
    _progressSubscription?.cancel();
    super.dispose();
  }

  // ==========================================================================
  // LOAD STATISTICS
  // ==========================================================================

  /// Loads statistics.
  ///
  /// A request that arrives while a load is running is NOT dropped: it is
  /// queued and one more load runs afterwards, so the screen cannot end up
  /// stale. The returned future completes after that extra load too, which
  /// keeps pull-to-refresh accurate.
  Future<void> _loadStats({bool notify = true}) {
    final Future<void>? running = _loadFuture;

    if (running != null) {
      _reloadQueued = true;

      return running;
    }

    if (notify && mounted) {
      setState(() {
        _isRefreshing = true;
      });
    } else {
      _isRefreshing = true;
    }

    final Future<void> future = _runLoadLoop().whenComplete(() {
      _loadFuture = null;

      if (mounted) {
        setState(() {
          _isRefreshing = false;
        });
      } else {
        _isRefreshing = false;
      }
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
      final Map<String, dynamic> data = await _progressService
          .getGlobalStats();

      if (!mounted) return false;

      final _StatsSnapshot snapshot = _StatsSnapshot.fromMap(data);

      setState(() {
        _stats = snapshot;
        _isLoading = false;
      });

      return true;
    } catch (e, stackTrace) {
      debugPrint('StatisticsScreen: failed to load statistics: $e');
      debugPrintStack(stackTrace: stackTrace);

      if (!mounted) return false;

      final bool hadData = _stats != null;

      setState(() {
        _isLoading = false;
      });

      // With nothing to show, the error view explains it. The snackbar is
      // only needed when a refresh fails while data is on screen.
      if (hadData) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(
              content: Text('Could not load statistics. Please try again.'),
              behavior: SnackBarBehavior.floating,
            ),
          );
      }

      return false;
    }
  }

  // ==========================================================================
  // TIME FORMATTING
  // ==========================================================================

  String _formatTime(int seconds) {
    if (seconds < 0) {
      seconds = 0;
    }

    final int hours = seconds ~/ 3600;
    final int minutes = (seconds % 3600) ~/ 60;
    final int remainingSeconds = seconds % 60;

    if (hours > 0) {
      return '$hours:${minutes.toString().padLeft(2, '0')}:'
          '${remainingSeconds.toString().padLeft(2, '0')}';
    }

    return '$minutes:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  // ==========================================================================
  // BUILD
  // ==========================================================================

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text('Lifetime Statistics'),
        centerTitle: true,
        elevation: 0,
        actions: <Widget>[
          IconButton(
            tooltip: 'Refresh statistics',
            onPressed: _isRefreshing ? null : () => unawaited(_loadStats()),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _buildBody(theme),
    );
  }

  // ==========================================================================
  // BODY
  // ==========================================================================

  Widget _buildBody(ThemeData theme) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final _StatsSnapshot? stats = _stats;

    if (stats == null) {
      return _buildErrorState();
    }

    final int maxStars = GameConfig.maxStarsTotal;

    final double starsProgress = maxStars > 0
        ? (stats.totalStars / maxStars).clamp(0.0, 1.0).toDouble()
        : 0.0;

    return RefreshIndicator(
      onRefresh: _loadStats,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          // LEVELS COMPLETED
          StatisticsCard(
            title: 'Levels Completed',
            value: stats.levelsCompleted,
            progress: stats.completionPercent.clamp(0.0, 1.0).toDouble(),
            icon: Icons.checklist_rtl,
          ),

          const SizedBox(height: 12),

          // TOTAL STARS
          StatisticsCard(
            title: 'Total Stars Earned',
            value: stats.totalStars,
            progress: starsProgress,
            icon: Icons.star,
          ),

          const SizedBox(height: 12),

          // TOTAL TIME
          _buildSimpleStatTile(
            title: 'Total Time Played',
            value: _formatTime(stats.totalTimeSeconds),
            icon: Icons.timer,
          ),

          const SizedBox(height: 12),

          // AVERAGE SOLVE TIME
          _buildSimpleStatTile(
            title: 'Avg. Solve Time',
            value: stats.averageSeconds > 0
                ? _formatTime(stats.averageSeconds)
                : '--',
            icon: Icons.speed,
          ),

          const SizedBox(height: 24),

          // GAME PROGRESS SUMMARY
          _buildSummaryCard(
            theme: theme,
            totalLevels: stats.levelsCompleted,
            totalStars: stats.totalStars,
            maxStars: maxStars,
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // SIMPLE STAT TILE
  // ==========================================================================

  Widget _buildSimpleStatTile({
    required String title,
    required String value,
    required IconData icon,
  }) {
    return Card(
      elevation: 2,
      margin: EdgeInsets.zero,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        leading: CircleAvatar(
          backgroundColor: Colors.blue.shade50,
          child: Icon(icon, color: Colors.blue),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        trailing: Text(
          value,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
        ),
      ),
    );
  }

  // ==========================================================================
  // SUMMARY CARD
  // ==========================================================================

  Widget _buildSummaryCard({
    required ThemeData theme,
    required int totalLevels,
    required int totalStars,
    required int maxStars,
  }) {
    final double completionPercent = GameConfig.totalLevels > 0
        ? (totalLevels / GameConfig.totalLevels).clamp(0.0, 1.0).toDouble()
        : 0.0;

    final double starsPercent = maxStars > 0
        ? (totalStars / maxStars).clamp(0.0, 1.0).toDouble()
        : 0.0;

    return Card(
      elevation: 2,
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Overall Progress',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 16),

            _buildProgressRow(
              label: 'Levels',
              value: '$totalLevels / ${GameConfig.totalLevels}',
              progress: completionPercent,
            ),

            const SizedBox(height: 16),

            _buildProgressRow(
              label: 'Stars',
              value: '$totalStars / $maxStars',
              progress: starsPercent,
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================================================
  // PROGRESS ROW
  // ==========================================================================

  Widget _buildProgressRow({
    required String label,
    required String value,
    required double progress,
  }) {
    final double safeProgress = progress.clamp(0.0, 1.0).toDouble();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
            Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
          ],
        ),

        const SizedBox(height: 8),

        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: safeProgress,
            minHeight: 8,
            // Lets screen readers announce the bar, e.g. "Levels progress,
            // 40%".
            semanticsLabel: '$label progress',
            semanticsValue: '${(safeProgress * 100).round()}%',
          ),
        ),
      ],
    );
  }

  // ==========================================================================
  // ERROR STATE
  // ==========================================================================

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(
              Icons.bar_chart_outlined,
              size: 64,
              color: Colors.grey.shade400,
            ),

            const SizedBox(height: 16),

            const Text(
              'Statistics unavailable',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 8),

            Text(
              'We could not load your statistics.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600),
            ),

            const SizedBox(height: 20),

            ElevatedButton.icon(
              onPressed: _isRefreshing
                  ? null
                  : () {
                      setState(() {
                        _isLoading = true;
                      });

                      unawaited(_loadStats());
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
// STATISTICS SNAPSHOT
// ----------------------------------------------------------------------------
// Immutable, already-parsed view of ProgressService.getGlobalStats().
// ============================================================================

class _StatsSnapshot {
  final int levelsCompleted;
  final int totalStars;
  final int totalTimeSeconds;
  final int averageSeconds;
  final double completionPercent;

  const _StatsSnapshot({
    required this.levelsCompleted,
    required this.totalStars,
    required this.totalTimeSeconds,
    required this.averageSeconds,
    required this.completionPercent,
  });

  factory _StatsSnapshot.fromMap(Map<String, dynamic> map) {
    return _StatsSnapshot(
      levelsCompleted: _readInt(map['totalLevels']),
      totalStars: _readInt(map['totalStars']),
      totalTimeSeconds: _readInt(map['totalTime']),
      averageSeconds: _readInt(map['avgSpeed']),
      completionPercent: _readDouble(map['completionPercent']),
    );
  }

  static int _readInt(Object? value) {
    if (value is int) {
      return value;
    }

    // NaN / Infinity would throw in toInt().
    if (value is num && value.isFinite) {
      return value.toInt();
    }

    return 0;
  }

  static double _readDouble(Object? value) {
    if (value is num && value.isFinite) {
      return value.toDouble();
    }

    return 0.0;
  }
}