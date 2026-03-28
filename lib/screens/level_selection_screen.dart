import 'package:flutter/material.dart';
import 'enhanced_level_tile.dart';

class LevelSelectionScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Level Selection'),
      ),
      body: GridView.builder(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 5,
          childAspectRatio: 1.0,
        ),
        itemCount: 25,
        itemBuilder: (context, index) {
          return GestureDetector(
            onTap: () {
              // Navigate to game screen
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => GameScreen(level: index + 1),
                ),
              );
            },
            child: EnhancedLevelTile(level: index + 1),
          );
        },
      ),
    );
  }
}