import 'dart:async';

import 'package:flutter/material.dart';

import '../main.dart';
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
/// ============================================================================
class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({super.key});

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  final ProgressService _progressService = ProgressService();

  StreamSubscription<void>? _progressSubscription;

  Map<String, dynamic>? _stats;

  bool _isLoading = true;
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();

    _loadStats();

    /// Refresh statistics whenever progress changes elsewhere in the app.
    _progressSubscription = _progressService.onProgressUpdate.listen((_) {
      if (!mounted) return;

      _loadStats(refreshOnly: true);
    });
  }

  /// ==========================================================================
  /// LOAD STATISTICS
  /// ==========================================================================

  Future<void> _loadStats({bool refreshOnly = false}) async {
    if (_isRefreshing) return;

    if (mounted) {
      setState(() {
        _isRefreshing = true;

        if (!refreshOnly) {
          _isLoading = true;
        }
      });
    }

    try {
      final data = await _progressService.getGlobalStats();

      if (!mounted) return;

      setState(() {
        _stats = data;
        _isLoading = false;
        _isRefreshing = false;
      });
    } catch (e, stackTrace) {
      debugPrint('StatisticsScreen: failed to load statistics: $e');
      debugPrintStack(stackTrace: stackTrace);

      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _isRefreshing = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not load statistics. Please try again.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  /// ==========================================================================
  /// SAFE STAT VALUE HELPERS
  /// ==========================================================================

  int _getIntStat(String key, {int defaultValue = 0}) {
    final value = _stats?[key];

    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    return defaultValue;
  }

  double _getDoubleStat(String key, {double defaultValue = 0.0}) {
    final value = _stats?[key];

    if (value is double) {
      return value;
    }

    if (value is num) {
      return value.toDouble();
    }

    return defaultValue;
  }

  /// ==========================================================================
  /// TIME FORMATTING
  /// ==========================================================================

  String _formatTime(int seconds) {
    if (seconds < 0) {
      seconds = 0;
    }

    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    final remainingSeconds = seconds % 60;

    if (hours > 0) {
      return '$hours:${minutes.toString().padLeft(2, '0')}:'
          '${remainingSeconds.toString().padLeft(2, '0')}';
    }

    return '$minutes:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  /// ==========================================================================
  /// BUILD
  /// ==========================================================================

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text('Lifetime Statistics'),
        centerTitle: true,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Refresh statistics',
            onPressed: _isRefreshing
                ? null
                : () => _loadStats(refreshOnly: true),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _buildBody(theme),
    );
  }

  /// ==========================================================================
  /// BODY
  /// ==========================================================================

  Widget _buildBody(ThemeData theme) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_stats == null) {
      return _buildErrorState();
    }

    final totalLevels = _getIntStat('totalLevels');
    final completionPercent = _getDoubleStat('completionPercent');

    final totalStars = _getIntStat('totalStars');
    final totalTime = _getIntStat('totalTime');
    final avgSpeed = _getIntStat('avgSpeed');

    final maxStars = GameConfig.totalLevels * 3;

    final starsProgress = maxStars > 0
        ? (totalStars / maxStars).clamp(0.0, 1.0)
        : 0.0;

    return RefreshIndicator(
      onRefresh: () => _loadStats(refreshOnly: true),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          /// ================================================================
          /// LEVELS COMPLETED
          /// ================================================================
          StatisticsCard(
            title: 'Levels Completed',
            value: totalLevels,
            progress: completionPercent.clamp(0.0, 1.0),
            icon: Icons.checklist_rtl,
          ),

          const SizedBox(height: 12),

          /// ================================================================
          /// TOTAL STARS
          /// ================================================================
          StatisticsCard(
            title: 'Total Stars Earned',
            value: totalStars,
            progress: starsProgress,
            icon: Icons.star,
          ),

          const SizedBox(height: 12),

          /// ================================================================
          /// TOTAL TIME
          /// ================================================================
          _buildSimpleStatTile(
            title: 'Total Time Played',
            value: _formatTime(totalTime),
            icon: Icons.timer,
          ),

          const SizedBox(height: 12),

          /// ================================================================
          /// AVERAGE SOLVE TIME
          /// ================================================================
          _buildSimpleStatTile(
            title: 'Avg. Solve Time',
            value: avgSpeed > 0 ? _formatTime(avgSpeed) : '--',
            icon: Icons.speed,
          ),

          const SizedBox(height: 24),

          /// ================================================================
          /// GAME PROGRESS SUMMARY
          /// ================================================================
          _buildSummaryCard(
            theme: theme,
            totalLevels: totalLevels,
            totalStars: totalStars,
            maxStars: maxStars,
          ),
        ],
      ),
    );
  }

  /// ==========================================================================
  /// SIMPLE STAT TILE
  /// ==========================================================================

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

  /// ==========================================================================
  /// SUMMARY CARD
  /// ==========================================================================

  Widget _buildSummaryCard({
    required ThemeData theme,
    required int totalLevels,
    required int totalStars,
    required int maxStars,
  }) {
    final completionPercent = GameConfig.totalLevels > 0
        ? (totalLevels / GameConfig.totalLevels).clamp(0.0, 1.0)
        : 0.0;

    final starsPercent = maxStars > 0
        ? (totalStars / maxStars).clamp(0.0, 1.0)
        : 0.0;

    return Card(
      elevation: 2,
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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

  /// ==========================================================================
  /// PROGRESS ROW
  /// ==========================================================================

  Widget _buildProgressRow({
    required String label,
    required String value,
    required double progress,
  }) {
    final safeProgress = progress.clamp(0.0, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
            Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
          ],
        ),

        const SizedBox(height: 8),

        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(value: safeProgress, minHeight: 8),
        ),
      ],
    );
  }

  /// ==========================================================================
  /// ERROR STATE
  /// ==========================================================================

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
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
                  : () => _loadStats(refreshOnly: false),
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }

  /// ==========================================================================
  /// DISPOSE
  /// ==========================================================================

  @override
  void dispose() {
    _progressSubscription?.cancel();
    super.dispose();
  }
}
