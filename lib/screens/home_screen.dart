import 'package:flutter/material.dart';

import '../services/progress_service.dart';
import 'world_map_screen.dart';

/// ============================================================================
/// HomeScreen
/// ----------------------------------------------------------------------------
/// Entry point of the game UI.
/// Responsibilities:
/// - Show Continue button (next playable level)
/// - Navigate to GameScreen using correct world + level mapping
/// - Navigate to World Map
/// - Display basic UI & animations
/// ============================================================================

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  /// Service layer (handles all progression logic)
  final ProgressService progressService = ProgressService();

  /// Animation controller for Continue button
  late AnimationController controller;
  late Animation<double> scaleAnimation;

  /// Stores NEXT playable GLOBAL level
  int nextLevel = 1;

  @override
  void initState() {
    super.initState();

    _loadProgress();

    /// Initialize animation
    controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    scaleAnimation = Tween<double>(
      begin: 0.9,
      end: 1,
    ).animate(
      CurvedAnimation(
        parent: controller,
        curve: Curves.easeInOut,
      ),
    );

    controller.repeat(reverse: true);
  }

  /// ==========================================================================
  /// LOAD USER PROGRESS
  /// ==========================================================================
  Future<void> _loadProgress() async {
    int level = await progressService.getNextUnlockedLevel();

    if (!mounted) return;

    setState(() {
      nextLevel = level;
    });
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  /// ==========================================================================
  /// CONTINUE BUTTON HANDLER (PRODUCTION SAFE)
  /// ==========================================================================
  Future<void> _handleContinue() async {
    /// Step 1: Get next unlocked GLOBAL level
    int globalLevel = await progressService.getNextUnlockedLevel();

    /// Safety guard (prevents invalid navigation)
    if (globalLevel < 1) return;

    /// Step 2: Convert → world + level using SERVICE (single source of truth)
    final data = progressService.getWorldAndLevel(globalLevel);

    int world = data["world"]!;
    int level = data["level"]!;

    /// Debug log (remove in release if needed)
    // ignore: avoid_print
    print("Continue → Global: $globalLevel | World: $world | Level: $level");

    /// Step 3: Navigate to GameScreen
    await Navigator.pushNamed(
      context,
      "/game",
      arguments: {
        "level": level,   // LOCAL level (1–25)
        "world": world,   // World number
      },
    );

    /// Step 4: Reload progress after returning
    if (mounted) {
      await _loadProgress();
    }
  }

  /// ==========================================================================
  /// OPEN WORLD MAP
  /// ==========================================================================
  Future<void> _openLevelMap() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const WorldMapScreen(),
      ),
    );

    if (mounted) {
      await _loadProgress();
    }
  }

  /// ==========================================================================
  /// UI
  /// ==========================================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              /// GAME ICON
              const Icon(
                Icons.grid_on,
                size: 120,
                color: Colors.blue,
              ),

              const SizedBox(height: 10),

              /// TITLE
              const Text(
                "Sudoku",
                style: TextStyle(
                  fontSize: 40,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 40),

              /// CONTINUE BUTTON
              ScaleTransition(
                scale: scaleAnimation,
                child: ElevatedButton(
                  onPressed: _handleContinue,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 70,
                      vertical: 16,
                    ),
                  ),
                  child: Text(
                    "Continue (Level $nextLevel)", // shows GLOBAL level
                    style: const TextStyle(fontSize: 18),
                  ),
                ),
              ),

              const SizedBox(height: 15),

              /// PLAY BUTTON (opens world map)
              OutlinedButton(
                onPressed: _openLevelMap,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 80,
                    vertical: 16,
                  ),
                ),
                child: const Text(
                  "Play",
                  style: TextStyle(fontSize: 18),
                ),
              ),

              const SizedBox(height: 30),

              /// EXTRA OPTIONS
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.bar_chart, size: 28),
                    onPressed: () {
                      Navigator.pushNamed(context, "/stats");
                    },
                  ),

                  const SizedBox(width: 20),

                  IconButton(
                    icon: const Icon(Icons.settings, size: 28),
                    onPressed: () {
                      Navigator.pushNamed(context, "/settings");
                    },
                  ),
                ],
              ),

              const SizedBox(height: 20),

              /// FOOTER
              const Text(
                "Solve puzzles. Train your brain.",
                style: TextStyle(
                  color: Colors.grey,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}