import 'package:flutter/material.dart';

enum LevelTileState {
  locked,
  inProgress,
  completed,
}

class EnhancedLevelTile extends StatelessWidget {
  final int levelNumber;
  final LevelTileState state;
  final int stars;
  final VoidCallback onTap;

  const EnhancedLevelTile({
    super.key,
    required this.levelNumber,
    required this.state,
    this.stars = 0,
    required this.onTap,
  });

      Color _getBackgroundColor() {
    switch (state) {
      case LevelTileState.completed:
        return Colors.green;
      case LevelTileState.inProgress:
        return Colors.orange;
      case LevelTileState.locked:
        return Colors.grey;
    }
  }

 @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: state != LevelTileState.locked ? onTap : null,
      child: Card(
        color: _getBackgroundColor(),
        child: Stack(
          children: [
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(levelNumber.toString(), style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Colors.white)),
                  if (state == LevelTileState.completed)
                    Row(mainAxisAlignment: MainAxisAlignment.center, children: List.generate(stars, (index) => Icon(Icons.star, color: Colors.yellow, size: 16))),
                ],
              ),
            ),
            if (state == LevelTileState.locked)
              Center(child: Icon(Icons.lock, color: Colors.white, size: 32)),
          ],
        ),
      ),
    );
  }
}