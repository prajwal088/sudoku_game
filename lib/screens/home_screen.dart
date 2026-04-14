import 'package:flutter/material.dart';
import 'package:sudoku_game/l10n/app_localizations.dart';

import '../services/progress_service.dart';
import '../services/analytics_service.dart';

import 'world_map_screen.dart';
import 'dart:async';

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

  // Define the subscription variable
  StreamSubscription? _progressSubscription;

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

    // Track: App Open / Home View
    AnalyticsService.logEvent(name: 'home_screen_view');

    _loadProgress();

    // 🎧 Start listening for updates
  _progressSubscription = progressService.onProgressUpdate.listen((_) {
    if (mounted) {
      debugPrint("Home Screen detected progress update! Refreshing...");
      _loadProgress();
    }
  });

    /// Initialize animation
    controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true); // Cascaded repeat

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
    _progressSubscription?.cancel();  // Stop listening to prevent memory leaks
    controller.dispose();
    super.dispose();
  }

  /// ==========================================================================
  /// CONTINUE BUTTON HANDLER (PRODUCTION SAFE)
  /// ==========================================================================
  Future<void> _handleContinue() async {
    // Optimization: Use the variable we already have in state
    if (nextLevel < 1) return;

    final data = progressService.getWorldAndLevel(nextLevel);
    int world = data["world"]!;

    // Track: High-intent play action
    AnalyticsService.logEvent(
      name: 'home_click_continue',
      parameters: {
        'to_level': nextLevel,
        'to_world': world,
      },
    );

/*
    /// Debug log (remove in release if needed)
    // ignore: avoid_print
    print("Continue → Global: $globalLevel | World: $world | Level: $level");
*/

    /// Step 3: Navigate to GameScreen
    await Navigator.pushNamed(
      context,
      "/game",
      arguments: {
        "levelNumber": nextLevel,
        "world": world,   // World number
      },
    );

    /// Step 4: Reload progress after returning
    if (mounted) {
      debugPrint("Returned to Home. Re-loading progress...");
    }
  }

  /// ==========================================================================
  /// OPEN WORLD MAP
  /// ==========================================================================
  Future<void> _openLevelMap() async {
    if (!mounted) return;

    // Track: Navigation to world selection
    AnalyticsService.logEvent(name: 'home_click_play_manual');
    
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const WorldMapScreen(),
      ),
    );

    if (mounted) return;
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
              Text(
                AppLocalizations.of(context)!.appTitle,
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
                    "${AppLocalizations.of(context)!.continueButton} (${AppLocalizations.of(context)!.levelText} $nextLevel)", // shows GLOBAL level
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
                child: Text(
                  AppLocalizations.of(context)!.playButton,
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
                      Navigator.pushNamed(context, "/statistics");
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
              Text(
                AppLocalizations.of(context)!.footerText,
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