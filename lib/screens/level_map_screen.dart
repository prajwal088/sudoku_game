import 'package:flutter/material.dart';

import '../models/level.dart';
import '../services/level_service.dart';
import '../services/progress_service.dart';

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
  bool isLevelLocked(int index) {
    int globalLevel =
        _progressService.getGlobalLevel(widget.world, index + 1);

    return globalLevel > currentGlobalLevel;
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
    if (isLevelLocked(index)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Complete previous level to unlock"),
        ),
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
  /// LEVEL COLOR LOGIC
  /// ==========================================================================
  Color getLevelColor(Level level, int index) {
    if (isLevelLocked(index)) {
      return Colors.grey.shade300;
    }

    if (level.isCompleted) {
      return Colors.green.shade400;
    }

    return Colors.orange.shade400;
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

    int currentIndex = getCurrentLevelIndex();

    return Scaffold(
      appBar: AppBar(
        title: Text("🌍 World ${widget.world}"),
        centerTitle: true,
      ),
      body: GridView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.all(16),
        itemCount: levels.length,
        gridDelegate:
            const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: itemsPerRow,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          mainAxisExtent: itemHeight,
        ),
        itemBuilder: (context, index) {
          final level = levels[index];
          final locked = isLevelLocked(index);
          final isCurrent = index == currentIndex;

          return GestureDetector(
            onTap: locked ? null : () => _openLevel(level, index),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              decoration: BoxDecoration(
                color: getLevelColor(level, index),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  if (!locked)
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: isCurrent ? 10 : 4,
                      offset: const Offset(0, 3),
                    )
                ],
              ),
              child: Stack(
                children: [
                  /// LEVEL NUMBER
                  Center(
                    child: Text(
                      "${level.levelNumber}",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color:
                            locked ? Colors.black38 : Colors.white,
                      ),
                    ),
                  ),

                  /// LOCK ICON
                  if (locked)
                    const Center(
                      child: Icon(
                        Icons.lock,
                        color: Colors.black45,
                      ),
                    ),

                  /// STARS
                  if (!locked && level.stars > 0)
                    Positioned(
                      bottom: 4,
                      left: 0,
                      right: 0,
                      child: Row(
                        mainAxisAlignment:
                            MainAxisAlignment.center,
                        children: List.generate(3, (i) {
                          return Icon(
                            i < level.stars
                                ? Icons.star
                                : Icons.star_border,
                            size: 12,
                            color: Colors.amber,
                          );
                        }),
                      ),
                    ),

                  /// CURRENT LEVEL HIGHLIGHT
                  if (isCurrent && !locked)
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius:
                              BorderRadius.circular(14),
                          border: Border.all(
                            color: Colors.white,
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}