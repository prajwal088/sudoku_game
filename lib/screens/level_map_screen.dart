import 'package:flutter/material.dart';

import '../models/level.dart';
import '../services/level_service.dart';
import 'game_screen.dart';
import '../widgets/level_tile.dart';

class LevelMapScreen extends StatefulWidget {
  const LevelMapScreen({super.key});

  @override
  State<LevelMapScreen> createState() => _LevelMapScreenState();
}

class _LevelMapScreenState extends State<LevelMapScreen> {

  final LevelService _levelService = LevelService();

  List<Level> levels = [];

  bool loading = true;

  final ScrollController _scrollController = ScrollController();

  @override
void dispose() {
  _scrollController.dispose();
  super.dispose();
}

  @override
  void initState() {
    super.initState();
    loadLevels();
  }

  Future<void> loadLevels() async {

    List<Level> loadedLevels =
        await _levelService.getVisibleLevels();

         if (!mounted) return;

    setState(() {
      levels = loadedLevels;
      loading = false;
    });
  }

  void openLevel(Level level) {

    if (level.isLocked) {

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Complete previous level to unlock"),
        ),
      );

      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => GameScreen(
          levelNumber: level.levelNumber,
        ),
      ),
    ).then((_) {
      loadLevels(); // refresh map after gameplay
    });
  }

  /// fallback stars builder (used if LevelTile doesn't render stars)
  Widget buildStars(int stars) {

    List<Widget> starWidgets = [];

    for (int i = 1; i <= 3; i++) {

      starWidgets.add(
        Icon(
          i <= stars ? Icons.star : Icons.star_border,
          size: 14,
          color: Colors.orange,
        ),
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: starWidgets,
    );
  }

  @override
  Widget build(BuildContext context) {

    if (loading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(

      appBar: AppBar(
        title: const Text("Sudoku Levels"),
        centerTitle: true,
      ),

      body: Padding(

        padding: const EdgeInsets.all(12),

        child: GridView.builder(

          controller: _scrollController,

          itemCount: levels.length,

          gridDelegate:
              const SliverGridDelegateWithFixedCrossAxisCount(

            crossAxisCount: 5,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,

          ),

          itemBuilder: (context, index) {

            Level level = levels[index];

          return LevelTile(

            level: level,
            onTap: () => openLevel(level),

          );
          },
        ),
      ),
    );
  }
}