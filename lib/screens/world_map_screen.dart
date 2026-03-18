import 'package:flutter/material.dart';

import '../widgets/world_tile.dart';
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

  // TODO: Replace with real progress data
  int highestUnlockedWorld = 1;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Select World"),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: GridView.builder(
          itemCount: totalWorlds,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            mainAxisExtent: 130,
          ),
          itemBuilder: (context, index) {
            final int worldNumber = index + 1;

            final bool isLocked = worldNumber > highestUnlockedWorld;

            return WorldTile(
              worldNumber: worldNumber,
              isLocked: isLocked,

              // 🔥 Optional progress (mock for now)
              starsEarned: isLocked ? 0 : (worldNumber * 5),
              totalLevels: levelsPerWorld,

              // 🎨 Optional color per world
              color: _getWorldColor(worldNumber),

              onTap: () {
                if (isLocked) {
                  _showLockedMessage(context);
                  return;
                }

                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => LevelMapScreen(world: worldNumber),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  // 🎨 Different color per world (simple theme system)
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