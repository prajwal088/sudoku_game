import 'package:flutter/material.dart';

import '../widgets/world_tile.dart';
import '../services/progress_service.dart'; // ✅ NEW
import 'level_map_screen.dart';

class WorldMapScreen extends StatefulWidget {
  const WorldMapScreen({super.key});

  @override
  State<WorldMapScreen> createState() => _WorldMapScreenState();
}

class _WorldMapScreenState extends State<WorldMapScreen> {

  // 🔥 Configurable
  final int totalWorlds = 10;
  final int levelsPerWorld = 25;

  final ProgressService progressService = ProgressService(); // ✅ NEW

  int highestUnlockedWorld = 1;
  bool loading = true; // ✅ NEW

  @override
  void initState() {
    super.initState();
    loadProgress(); // ✅ NEW
  }

  // ================= LOAD PROGRESS =================
  Future<void> loadProgress() async {
    highestUnlockedWorld =
        await progressService.getHighestUnlockedWorld();

    if (!mounted) return;

    setState(() {
      loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {

    // ✅ LOADING STATE
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

              // 🔥 (Optional improvement later: calculate real stars)
              starsEarned: isLocked ? 0 : (worldNumber * 5),
              totalLevels: levelsPerWorld,

              color: _getWorldColor(worldNumber),

              onTap: () {
                if (isLocked) {
                  _showLockedMessage(context);
                  return;
                }

                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        LevelMapScreen(world: worldNumber),
                  ),
                ).then((_) {
                  // ✅ REFRESH AFTER RETURN
                  loadProgress();
                });
              },
            );
          },
        ),
      ),
    );
  }

  // 🎨 Different color per world
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

  void _showLockedMessage(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Complete previous world to unlock"),
      ),
    );
  }
}