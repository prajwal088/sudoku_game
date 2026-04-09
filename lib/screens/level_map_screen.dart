import 'package:flutter/material.dart';

import '../models/level.dart';
import '../services/level_service.dart';
import '../services/progress_service.dart';
import '../widgets/enhanced_level_tile.dart';

import 'dart:async';
import '../services/analytics_service.dart';

/// ============================================================================
/// LevelMapScreen
/// ----------------------------------------------------------------------------
/// Displays levels inside a selected world.
/// Responsibilities:
/// - Render level grid
/// - Handle level locking/unlocking
/// - Navigate to GameScreen
/// - Highlight current playable level
///
/// Architecture:
/// - ProgressService → Source of truth (global level)
/// - LevelService → Provides level data
/// ============================================================================

class LevelMapScreen extends StatefulWidget {
  final int world;

  const LevelMapScreen({super.key, required this.world});

  @override
  State<LevelMapScreen> createState() => _LevelMapScreenState();
}

class _LevelMapScreenState extends State<LevelMapScreen> {

  StreamSubscription? _progressSubscription;

  final LevelService _levelService = LevelService();
  final ProgressService progressService = ProgressService();

  List<Level> levels = [];
  bool isLoading = true;

  int currentGlobalLevel = 1;

  final ScrollController _scrollController = ScrollController();

  static const int itemsPerRow = 5;
  static const double itemHeight = 80;

  @override
  void initState() {
    super.initState();

    // Track: Which world is the user viewing?
    AnalyticsService.logWorldView(widget.world);

    _loadProgress();

      _progressSubscription = progressService.onProgressUpdate.listen((_) {
      if (mounted) {
        debugPrint("Home Screen detected progress update! Refreshing...");
        _loadProgress();
      }
    });
  }

  /// ==========================================================================
  /// LOAD LEVELS + PROGRESS
  /// ==========================================================================
  Future<void> _loadProgress() async {
    final loadedLevels =
        await _levelService.getLevelsByWorld(widget.world);

    final globalLevel =
        await progressService.getNextUnlockedLevel();

    if (!mounted) return;

    setState(() {
      levels = loadedLevels;
      currentGlobalLevel = globalLevel;
      isLoading = false;
    });

    /// Scroll after UI is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToCurrentLevel();
    });
  }

  /// ==========================================================================
  /// LOCK LOGIC (GLOBAL SOURCE OF TRUTH)
  /// ==========================================================================
  /// Helper to determine the state for the EnhancedLevelTile
  /// Determines tile state based on Global Level ID
    LevelTileState _getTileState(Level level) {
      if (level.levelNumber > currentGlobalLevel) {
        return LevelTileState.locked;
      } else if (level.levelNumber < currentGlobalLevel) {
        return LevelTileState.completed;
      } else {
        return LevelTileState.inProgress;
      }
    }

  /// ==========================================================================
  /// AUTO SCROLL TO CURRENT LEVEL
  /// ==========================================================================
  void _scrollToCurrentLevel() {
    // Add a tiny delay to ensure GridView has calculated its layout
    Future.delayed(const Duration(milliseconds: 100), () {
      if (!mounted || !_scrollController.hasClients || levels.isEmpty) return;

      // Find the current level within the current world list
      int indexInList = levels.indexWhere((l) => l.levelNumber == currentGlobalLevel);
      if (indexInList == -1) return; // Current level is in a different world

      int row = indexInList ~/ itemsPerRow;
      // Use the actual height of your tiles + spacing
      double offset = row * (itemHeight + 12);

        _scrollController.animateTo(
        offset.clamp(0, _scrollController.position.maxScrollExtent),
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    });
  }

  /// ==========================================================================
  /// NAVIGATION
  /// ==========================================================================
  Future<void> _openLevel(Level level) async {
    final bool isLocked = level.levelNumber > currentGlobalLevel;

    if (isLocked) {
      // Track: Interaction with locked content
      AnalyticsService.logLockedLevelClick(widget.world, level.levelNumber);
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Complete previous levels first!")),
      );
      return;
    }

    // Determine if this is a replay for analytics
    bool isReplay = level.levelNumber < currentGlobalLevel;
    AnalyticsService.logLevelSelect(
      world: widget.world, 
      level: level.levelNumber, 
      isReplay: isReplay,
    );

    await Navigator.pushNamed(
      context,
      "/game",
      arguments: {
        "levelNumber": level.levelNumber,
        "world": widget.world,
      },
    );
  }
  */

  /// ==========================================================================
  /// UI
  /// ==========================================================================
  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text("World ${widget.world}"),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {

              // Track: Manual refresh (might indicate UI sync issues)
              AnalyticsService.logEvent(name: 'map_manual_refresh');
              
              _loadProgress();
            },
          )
        ],
      ),
      body: GridView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.all(16),
        itemCount: levels.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: itemsPerRow,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          mainAxisExtent: itemHeight,
        ),
        itemBuilder: (context, index) {
          final level = levels[index];
          return EnhancedLevelTile(
            // Show the LOCAL number (1-25) on the tile for the user
            levelNumber: level.levelNumber,
            state: _getTileState(level),
            stars: level.stars,
            onTap: () => _openLevel(level),
          );
        },
      ),
    );
  }
  
  @override
  void dispose() {
    _progressSubscription?.cancel();
    _scrollController.dispose();
    super.dispose();
  }
}