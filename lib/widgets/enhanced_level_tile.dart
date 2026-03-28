import 'package:flutter/material.dart';

enum LevelTileState {
  locked,
  inProgress,
  completed,
}

class EnhancedLevelTile extends StatelessWidget {
  final LevelTileState state;

  EnhancedLevelTile({required this.state});

  @override
  Widget build(BuildContext context) {
    Color color;
    IconData icon;
    String starDisplay = '';

    switch (state) {
      case LevelTileState.locked:
        color = Colors.grey;
        icon = Icons.lock;
        break;
      case LevelTileState.inProgress:
        color = Colors.blue;
        icon = Icons.circle; // Example icon for in progress
        break;
      case LevelTileState.completed:
        color = Colors.green;
        icon = Icons.star;
        starDisplay = ' ★'; // Star display
        break;
    }

    return Container(
      color: color,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Icon(icon),
          Text(starDisplay),
        ],
      ),
    );
  }
}