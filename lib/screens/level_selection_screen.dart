import 'package:flutter/material.dart';
import '../widgets/enhanced_level_tile.dart';

class LevelSelectionScreen extends StatelessWidget {
  final int worldNumber;

  const LevelSelectionScreen({
    super.key,
    required this.worldNumber,
    });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('World $worldNumber - Levels'),
        centerTitle: true,
      ),
       body: Padding(
        padding: const EdgeInsets.all(12),
          child: GridView.builder(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 5,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
            ),
            itemCount: 25,
            itemBuilder: (context, index) {
              int levelNumber = (worldNumber - 1) * 25 + index + 1;
                return EnhancedLevelTile(
                  key: ValueKey(levelNumber),
                  levelNumber: levelNumber,
                  state: LevelTileState.inProgress,
                  onTap: () {
                    Navigator.pushNamed(
                      context,
                      '/game',
                      arguments: levelNumber,
                    );
                  },
              );
            },
         ),
       )
    );
  }
}