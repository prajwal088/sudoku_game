import 'package:flutter/material.dart';
import '../services/progress_service.dart';

class WinScreen extends StatefulWidget {
  final int levelNumber; // GLOBAL level (1–∞)
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

  late AnimationController trophyController;
  late Animation<double> trophyScale;

  List<bool> visibleStars = [false, false, false];

  bool _isSaved = false; // ✅ FIX: prevent duplicate execution

  @override
  void initState() {
    super.initState();

    trophyController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );

    trophyScale = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(
      CurvedAnimation(
        parent: trophyController,
        curve: Curves.elasticOut,
      ),
    );

    initialize();
  }

  // ================= TIME CONVERSION =================
  int convertTimeToSeconds(String time) {
    final parts = time.split(":");
    final minutes = int.parse(parts[0]);
    final seconds = int.parse(parts[1]);
    return minutes * 60 + seconds;
  }

  // ================= INIT =================
  Future<void> initialize() async {

    if (_isSaved) return;
    _isSaved = true;

    int timeInSeconds = convertTimeToSeconds(widget.time);

    const int levelsPerWorld = 25;

    // ✅ GLOBAL → LOCAL conversion
    int localLevel =
        widget.levelNumber - ((widget.world - 1) * levelsPerWorld);

    // ✅ SAVE PROGRESS
    await progressService.completeLevel(
      widget.world,
      localLevel,
      timeInSeconds,
      widget.stars,
    );

    // ✅ WORLD COMPLETE CHECK
    if (localLevel == levelsPerWorld) {
      Future.delayed(const Duration(milliseconds: 800), () {
        if (mounted) {
          _showWorldCompleteDialog(widget.world);
        }
      });
    }

    startAnimation();
  }

  // ================= ANIMATION =================
  Future<void> startAnimation() async {

    if (!mounted) return;

    trophyController.forward();

    await Future.delayed(const Duration(milliseconds: 400));

    int safeStars = widget.stars.clamp(0, 3); // ✅ FIX

    for (int i = 0; i < safeStars; i++) {

      await Future.delayed(const Duration(milliseconds: 350));

      if (!mounted) return;

      setState(() {
        visibleStars[i] = true;
      });
    }
  }

  // ================= WORLD COMPLETE POPUP =================
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
              if (!mounted) return;

              Navigator.pop(context);

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

  @override
  void dispose() {
    trophyController.dispose();
    super.dispose();
  }

  Widget buildStar(int index) {
    return AnimatedScale(
      scale: visibleStars[index] ? 1 : 0,
      duration: const Duration(milliseconds: 400),
      curve: Curves.elasticOut,
      child: const Icon(
        Icons.star,
        size: 50,
        color: Colors.amber,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      backgroundColor: Colors.green.shade50,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [

              /// TROPHY
              ScaleTransition(
                scale: trophyScale,
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
                  buildStar(0),
                  const SizedBox(width: 10),
                  buildStar(1),
                  const SizedBox(width: 10),
                  buildStar(2),
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

                  const int levelsPerWorld = 25;

                  int nextLevel = widget.levelNumber + 1;
                  int nextWorld =
                      ((nextLevel - 1) ~/ levelsPerWorld) + 1;

                  Navigator.pushReplacementNamed(
                    context,
                    "/game",
                    arguments: {
                      "level": nextLevel,
                      "world": nextWorld,
                    },
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

              /// REPLAY
              OutlinedButton(
                onPressed: () {
                  Navigator.pushReplacementNamed(
                    context,
                    "/game",
                    arguments: {
                      "level": widget.levelNumber,
                      "world": widget.world,
                    },
                  );
                },
                child: const Text(
                  "Replay Level",
                  style: TextStyle(fontSize: 16),
                ),
              ),

              const SizedBox(height: 15),

              /// LEVEL MAP
              TextButton(
                onPressed: () {
                  if (Navigator.canPop(context)) {
                    Navigator.pop(context);
                  }
                },
                child: const Text(
                  "Level Map",
                  style: TextStyle(fontSize: 16),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}