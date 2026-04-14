import 'package:flutter/material.dart';
import 'package:sudoku_game/l10n/app_localizations.dart';

import '../services/progress_service.dart';
import '../services/analytics_service.dart';

/// ============================================================================
/// WinScreen
/// ----------------------------------------------------------------------------
/// Purpose:
/// - Display level completion UI
/// - Show stars animation
/// - Handle navigation (Next / Replay / Map)
///
/// IMPORTANT:
/// - Progress saving is handled in GameScreen (NOT here)
/// - This screen is purely UI + navigation
/// ============================================================================

class WinScreen extends StatefulWidget {
  final int levelNumber; // GLOBAL level
  final int stars;
  final String time;
  final int world;

  const WinScreen({
    super.key,
    required this.levelNumber,
    required this.stars,
    required this.time,
    required this.world,
  });

  @override
  State<WinScreen> createState() => _WinScreenState();
}

class _WinScreenState extends State<WinScreen>
    with SingleTickerProviderStateMixin {
  final ProgressService progressService = ProgressService();

  bool _isReplay = false;
  bool _isLoading = true;
  bool _isLastLevelOfWorld = false;

  // New variables to hold pre-calculated navigation data
  Map<String, int>? _nextLevelArgs;
  Map<String, int>? _replayArgs;

  late AnimationController _trophyController;
  late Animation<double> _trophyScale;

  /// Controls star animation visibility
  final List<bool> _visibleStars = [false, false, false];

  @override
  void initState() {
    super.initState();

    _trophyController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );

    _trophyScale = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(
      CurvedAnimation(
        parent: _trophyController,
        curve: Curves.elasticOut,
      ),
    );

    _initialize();
  }

  /// ==========================================================================
  /// INITIALIZATION
  /// ==========================================================================
  Future<void> _initialize() async {

    // Check if this is a replay
    final int nextUnlockedLevel = await progressService.getNextUnlockedLevel();
    final int highestWorld = await progressService.getHighestUnlockedWorld();

    final bool isReplay = widget.levelNumber < nextUnlockedLevel - 1;
    final int levelInWorld = progressService.getLevelInWorld(widget.levelNumber);
    final bool isLastLevel = levelInWorld == ProgressService.levelsPerWorld;

    // --- PRE-CALCULATE NAVIGATION ARGS HERE ---
    final int globalNext = widget.levelNumber + 1;
    final nextArgs = {
      "world": progressService.getWorldFromGlobal(globalNext),
      "level": progressService.getLevelInWorld(globalNext),
      "levelNumber": globalNext,
    };

    final replayArgs = {
      "world": widget.world,
      "level": progressService.getLevelInWorld(widget.levelNumber),
      "levelNumber": widget.levelNumber,
    };
    
    if (!mounted) return;

    setState(() {
      _isReplay = isReplay;
      _isLastLevelOfWorld = isLastLevel;
      _nextLevelArgs = nextArgs;
      _replayArgs = replayArgs;
      _isLoading = false;
    });
    
    // 3. Handle World Completion
    if (isLastLevel && !_isReplay && highestWorld <= widget.world) {
      AnalyticsService.logWorldComplete(widget.world);
      
      // Slight delay for the dialog so it doesn't pop up instantly
      Future.delayed(const Duration(milliseconds: 800), () {
        if (mounted) _showWorldCompleteDialog(widget.world);
      });
    }

    _startAnimation();
  }

  /// ==========================================================================
  /// STAR + TROPHY ANIMATION
  /// ==========================================================================
  Future<void> _startAnimation() async {
    if (!mounted) return;

    _trophyController.forward();

    await Future.delayed(const Duration(milliseconds: 400));

    int safeStars = widget.stars.clamp(0, 3);

    for (int i = 0; i < safeStars; i++) {
      await Future.delayed(const Duration(milliseconds: 350));

      if (!mounted) return;

      setState(() {
        _visibleStars[i] = true;
      });
    }
  }

  /// ==========================================================================
  /// NAVIGATION HELPERS
  /// ==========================================================================
  void _navigateToGame(Map<String, int> args, String type) {
    AnalyticsService.logNavigation(type, widget.levelNumber);

    // We use pushReplacementNamed so the WinScreen is removed from the stack,
    // preventing the user from "back-buttoning" into a completed level UI.
    Navigator.pushReplacementNamed(context, "/game", arguments: args);
  }

  void _goToMap({int? worldOverride}) {

    // Use the override if it exists, otherwise use the current world
    final targetWorld = worldOverride ?? widget.world;

    AnalyticsService.logNavigation('back_to_map', widget.levelNumber);
    // Safer than pop: ensures we return to the specific world map
    // This removes ALL previous screens and starts fresh with the level map
    Navigator.pushNamedAndRemoveUntil(
      context, "/levels",
      (route) => false, // This 'false' means "remove everything else"
      arguments: targetWorld);
  }

  @override
  void dispose() {
    _trophyController.dispose();
    super.dispose();
  }

  /// ==========================================================================
  /// UI
  /// ==========================================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.green.shade50,
      body: SafeArea(
        child: Center(
          child: _isLoading 
            ? const CircularProgressIndicator() 
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  /// --- Header Section ---
                  ScaleTransition(
                    scale: _trophyScale,
                    child: const Icon(Icons.emoji_events, size: 120, color: Colors.orange),
                  ),
                  const SizedBox(height: 20),
                  Text(AppLocalizations.of(context)!.gameWonTitle, style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
                  Text("Level ${widget.levelNumber}", style: const TextStyle(fontSize: 18, color: Colors.grey)),
                  
                  const SizedBox(height: 25),

                  /// --- Stars Section ---
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(3, (i) => Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 5),
                      child: _buildStar(i),
                    )),
                  ),

                  const SizedBox(height: 30),
                  Text("Time: ${widget.time}", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w500)),
                  
                  const SizedBox(height: 40),

                  /// --- Navigation Buttons ---
                  /// Using a ConstrainedBox ensures all buttons have a consistent look
                  ConstrainedBox(
                    constraints: const BoxConstraints(minWidth: 220),
                    child: Column(
                      children: [
                        /// --- Primary Action: Next Level / Next World ---
                        if (_isReplay)
                          const Padding(
                            padding: EdgeInsets.only(bottom: 15),
                            child: Text(
                              "Replaying Level - Progress Saved", 
                              style: TextStyle(color: Colors.blueGrey, fontStyle: FontStyle.italic),
                            ),
                          )
                        else
                          SizedBox(
                            width: double.infinity, // Fills the ConstrainedBox
                            child: ElevatedButton(
                              onPressed: () {
                                if (_isLastLevelOfWorld) {
                                  _goToMap(worldOverride: widget.world + 1);
                                } else if (_nextLevelArgs != null) {
                                  _navigateToGame(_nextLevelArgs!, 'next_level');
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _isLastLevelOfWorld ? Colors.orange : Colors.blue,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                elevation: 4,
                              ),
                              child: Text(_isLastLevelOfWorld ? "Continue to Next World" : "Next Level"),
                            ),
                          ),

                        const SizedBox(height: 15),
                  
                        /// --- Secondary Action: Replay ---
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton(
                            onPressed: _replayArgs != null 
                                ? () => _navigateToGame(_replayArgs!, 'replay_level') 
                                : null,
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              side: BorderSide(color: Colors.blue.shade300, width: 2),
                            ),
                            child: Text(AppLocalizations.of(context)!.replaynButton, style: TextStyle(fontSize: 16)),
                          ),
                        ),

                        const SizedBox(height: 10),

                        /// --- Tertiary Action: Map ---
                        TextButton(
                          onPressed: () => _goToMap(),
                          child: Text(AppLocalizations.of(context)!.backToLevelMapButton, style: TextStyle(fontSize: 16)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
        ),
      ),
    );
  }

  /// ==========================================================================
  /// STAR WIDGET
  /// ==========================================================================
  Widget _buildStar(int index) {
    return AnimatedScale(
      scale: _visibleStars[index] ? 1 : 0,
      duration: const Duration(milliseconds: 400),
      curve: Curves.elasticOut,
      child: const Icon(
        Icons.star,
        size: 50,
        color: Colors.amber,
      ),
    );
  }

  /// ==========================================================================
  /// WORLD COMPLETE DIALOG
  /// ==========================================================================
  void _showWorldCompleteDialog(int world) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.worldComplete),
        content: Text("You unlocked World ${world + 1}!"),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              // Navigate to the Level Map for the NEW world  
              Navigator.pushNamedAndRemoveUntil(
                context,
                "/levels",
                (route) => false,
                arguments: world + 1,
              );
            },
            child: Text(AppLocalizations.of(context)!.continueButton),
          )
        ],
      ),
    );
  }
}