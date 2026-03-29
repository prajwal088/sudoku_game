import 'package:flutter/material.dart';

import '../models/level.dart';
import '../services/level_service.dart';
import '../services/progress_service.dart';
import '../widgets/enhanced_level_tile.dart';

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
  final LevelService _levelService = LevelService();
  final ProgressService _progressService = ProgressService();

  List<Level> levels = [];
  bool loading = true;

  int currentGlobalLevel = 1;

  final ScrollController _scrollController = ScrollController();

  static const int itemsPerRow = 5;
  static const double itemHeight = 80;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  /// ==========================================================================
  /// LOAD LEVELS + PROGRESS
  /// ==========================================================================
  Future<void> _loadData() async {
    final loadedLevels =
        await _levelService.getLevelsByWorld(widget.world);

    final globalLevel =
        await _progressService.getNextUnlockedLevel();

    if (!mounted) return;

    setState(() {
      levels = loadedLevels;
      currentGlobalLevel = globalLevel;
      loading = false;
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
    LevelTileState _getTileState(Level level, int index) {
      int globalLevelIdx = _progressService.getGlobalLevel(widget.world, index + 1);
      
      if (globalLevelIdx > currentGlobalLevel) {
        return LevelTileState.locked;
      } else if (globalLevelIdx < currentGlobalLevel || level.isCompleted) {
        return LevelTileState.completed;
      } else {
        return LevelTileState.inProgress;
      }
    }

  /// ==========================================================================
  /// CURRENT LEVEL INDEX (ACCURATE)
  /// ==========================================================================
  int getCurrentLevelIndex() {
    int localLevel =
        _progressService.getLevelInWorld(currentGlobalLevel);

    return (localLevel - 1).clamp(0, levels.length - 1);
  }

  /// ==========================================================================
  /// AUTO SCROLL TO CURRENT LEVEL
  /// ==========================================================================
  void _scrollToCurrentLevel() {
    if (levels.isEmpty) return;

    int index = getCurrentLevelIndex();
    int row = index ~/ itemsPerRow;

    double offset = row * itemHeight;

    /// Prevent overscroll
    if (_scrollController.hasClients) {
      offset = offset.clamp(
        0,
        _scrollController.position.maxScrollExtent,
      );

      _scrollController.animateTo(
        offset,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    }
  }

  /// ==========================================================================
  /// NAVIGATION
  /// ==========================================================================
  void _openLevel(Level level, int index) {
    int globalLevelIdx = _progressService.getGlobalLevel(widget.world, index + 1);
    
    if (globalLevelIdx > currentGlobalLevel) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Complete previous level to unlock")),
      );
      return;
    }

    Navigator.pushNamed(
      context,
      "/game",
      arguments: {
        "level": level.levelNumber, // LOCAL level
        "world": widget.world,
      },
    ).then((_) => _loadData());
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
        title: Text("🌍 World ${widget.world}"),
        centerTitle: true,
        elevation: 0,
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
          final state = _getTileState(level, index);

          return EnhancedLevelTile(
            levelNumber: level.levelNumber,
            state: state,
            stars: level.stars,
            onTap: () => _openLevel(level, index),
          );
        },
      ),
    );
  }
}