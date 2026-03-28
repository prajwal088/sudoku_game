import 'package:flutter/material.dart';

class WorldMapScreen extends StatelessWidget {
  const WorldMapScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('World Map')), 
      body: ListView(
        children: <Widget>[
          _buildWorldLevel(context, 'Level 1'),
          _buildWorldLevel(context, 'Level 2'),
          _buildWorldLevel(context, 'Level 3'),
          // Add pagination or more levels
        ],
      ),
    );
  }

  Widget _buildWorldLevel(BuildContext context, String level) {
    return ListTile(
      title: Text(level),
      onTap: () {
        // Navigate to the selected level
      },
    );
  }
}
