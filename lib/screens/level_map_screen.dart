import 'package:flutter/material.dart';

import '../models/level.dart';
import '../services/level_service.dart';
import 'game_screen.dart';
import '../widgets/level_tile.dart';

class LevelMapScreen extends StatefulWidget {
  final int world; // ✅ ADDED

  const LevelMapScreen({super.key, required this.world}); // ✅ UPDATED

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

  // ✅ UPDATED (world-based loading)
  Future<void> loadLevels() async {
    List<Level> loadedLevels =
        await _levelService.getLevelsByWorld(widget.world);

    if (!mounted) return;

    setState(() {
      levels = loadedLevels;
      loading = false;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      scrollToCurrentLevel();
    });
  }

  int getCurrentLevelIndex() {
    for (int i = 0; i < levels.length; i++) {
      if (levels[i].isLocked) {
        return i - 1 >= 0 ? i - 1 : 0;
      }
    }
    return levels.length - 1;
  }

  void scrollToCurrentLevel() {
    int index = getCurrentLevelIndex();

    const double itemHeight = 80;
    const int itemsPerRow = 5;

    int row = index ~/ itemsPerRow;
    double offset = row * itemHeight;

    _scrollController.animateTo(
      offset,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
    );
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

  /// fallback stars builder
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
        title: Text("World ${widget.world}"), // ✅ UPDATED
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
            mainAxisExtent: 70, // ✅ PERFORMANCE FIX
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