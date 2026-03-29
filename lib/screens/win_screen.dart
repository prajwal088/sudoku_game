import 'package:flutter/material.dart';
import '../services/progress_service.dart';

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
    with TickerProviderStateMixin {
  final ProgressService progressService = ProgressService();

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
    /// Check if world is completed (accurate check)
    bool isLastLevelOfWorld = 
        progressService.getLevelInWorld(widget.levelNumber) == ProgressService.levelsPerWorld;

    if (isLastLevelOfWorld) {
      Future.delayed(const Duration(milliseconds: 800), () {
        if (!mounted) return;
        _showWorldCompleteDialog(widget.world);
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
  /// WORLD COMPLETE DIALOG
  /// ==========================================================================
  void _showWorldCompleteDialog(int world) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text("🎉 World Complete!"),
        content: Text("You unlocked World ${world + 1}!"),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              // Navigate to the Level Map for the NEW world  
              Navigator.pushReplacementNamed(
                context,
                "/levels",
                arguments: world + 1,
              );
            },
            child: const Text("Continue"),
          )
        ],
      ),
    );
  }

  /// ==========================================================================
  /// NAVIGATION HELPERS
  /// ==========================================================================
  /// Converts GLOBAL level → correct world + level
  Map<String, int> _getNextLevelArgs() {
    final int globalNext = widget.levelNumber + 1;
    return {
      "world": progressService.getWorldFromGlobal(globalNext),
      "level": progressService.getLevelInWorld(globalNext),
      "levelNumber": globalNext, // Always pass the global index too!
    };
  }

  Map<String, int> _getReplayArgs() {
    return {
      "world": widget.world,
      "level": progressService.getLevelInWorld(widget.levelNumber),
      "levelNumber": widget.levelNumber,
    };
  }

  @override
  void dispose() {
    _trophyController.dispose();
    super.dispose();
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
  /// UI
  /// ==========================================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.green.shade50,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              /// TROPHY ICON
              ScaleTransition(
                scale: _trophyScale,
                child: const Icon(
                  Icons.emoji_events,
                  size: 120,
                  color: Colors.orange,
                ),
              ),

              const SizedBox(height: 20),

              const Text(
                "Level Complete!",
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 10),

              /// GLOBAL LEVEL DISPLAY
              Text(
                "Level ${widget.levelNumber}",
                style: const TextStyle(
                  fontSize: 18,
                  color: Colors.grey,
                ),
              ),

              const SizedBox(height: 25),

              /// STARS
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildStar(0),
                  const SizedBox(width: 10),
                  _buildStar(1),
                  const SizedBox(width: 10),
                  _buildStar(2),
                ],
              ),

              const SizedBox(height: 30),

              /// TIME
              Text(
                "Time: ${widget.time}",
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w500,
                ),
              ),

              const SizedBox(height: 40),

              /// NEXT LEVEL
              ElevatedButton(
                onPressed: () {
                  Navigator.pushReplacementNamed(
                    context,
                    "/game",
                    arguments: _getNextLevelArgs(),
                  );
                },
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 50,
                    vertical: 16,
                  ),
                ),
                child: const Text(
                  "Next Level",
                  style: TextStyle(fontSize: 18),
                ),
              ),

              const SizedBox(height: 15),

              /// REPLAY LEVEL
              OutlinedButton(
                onPressed: () {
                  Navigator.pushReplacementNamed(
                    context,
                    "/game",
                    arguments: _getReplayArgs(),
                  );
                },
                child: const Text("Replay Level"),
              ),

              const SizedBox(height: 15),

              /// BACK TO LEVEL MAP
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                child: const Text("Level Map"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}