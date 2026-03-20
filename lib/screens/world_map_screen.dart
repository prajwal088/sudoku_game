import 'package:flutter/material.dart';

import '../widgets/world_tile.dart';
import '../services/progress_service.dart';
import 'level_map_screen.dart';

class WorldMapScreen extends StatefulWidget {
  const WorldMapScreen({super.key});

  @override
  State<WorldMapScreen> createState() => _WorldMapScreenState();
}

class _WorldMapScreenState extends State<WorldMapScreen> {
  // ================= CONFIGURATION =================

  final int totalWorlds = 10;
  final int levelsPerWorld = 25;

  final ProgressService progressService = ProgressService();

  int highestUnlockedWorld = 1;

  bool loading = true;
  bool _isLoadingProgress = false;

  Map<int, int> worldStars = {};

  @override
  void initState() {
    super.initState();
    loadProgress();
  }

  // ================= LOAD PROGRESS =================

  Future<void> loadProgress() async {
    if (_isLoadingProgress) return;

    _isLoadingProgress = true;

    try {
      final unlockedWorld =
          await progressService.getHighestUnlockedWorld();

      Map<int, int> tempStars = {};

      for (int world = 1; world <= totalWorlds; world++) {
        tempStars[world] =
            await progressService.getStarsForWorld(world);
      }

      if (!mounted) return;

      setState(() {
        highestUnlockedWorld = unlockedWorld;
        worldStars = tempStars;
        loading = false;
      });
    } catch (e) {
      // Optional: log error in production (Crashlytics etc.)
      if (!mounted) return;

      setState(() {
        loading = false;
      });
    } finally {
      _isLoadingProgress = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Select World"),
        centerTitle: true,
      ),

      // ================= WORLD GRID =================
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: GridView.builder(
          itemCount: totalWorlds,
          gridDelegate:
              const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            mainAxisExtent: 130,
          ),
          itemBuilder: (context, index) {
            final int worldNumber = index + 1;

            final bool isLocked =
                worldNumber > highestUnlockedWorld;

            return WorldTile(
              worldNumber: worldNumber,
              isLocked: isLocked,

              /// ✅ Real stars
              starsEarned:
                  isLocked ? 0 : (worldStars[worldNumber] ?? 0),

              /// ✅ Total stars = 25 * 3
              totalLevels: levelsPerWorld * 3,

              color: _getWorldColor(worldNumber),

              onTap: () async {
                if (isLocked) {
                  _showLockedMessage(context);
                  return;
                }

                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        LevelMapScreen(world: worldNumber),
                  ),
                );

                /// ✅ Safe refresh after return
                if (mounted) {
                  loadProgress();
                }
              },
            );
          },
        ),
      ),
    );
  }

  // ================= WORLD COLOR =================

  Color _getWorldColor(int world) {
    const colors = [
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.red,
      Colors.teal,
      Colors.indigo,
      Colors.brown,
      Colors.pink,
      Colors.cyan,
    ];

    return colors[(world - 1) % colors.length];
  }

  // ================= LOCK MESSAGE =================

  void _showLockedMessage(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Complete previous world to unlock"),
      ),
    );
  }
}