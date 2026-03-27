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

  void scrollToLastUnlocked() {
  int index = levels.lastIndexWhere((l) => !l.isLocked);

  final row = index ~/ 5;

  _scrollController.animateTo(
    row * 80.0, // adjust based on tile height + spacing
    duration: const Duration(milliseconds: 500),
    curve: Curves.easeOut,
  );
}

  @override
void dispose() {
  _scrollController.dispose();
  super.dispose();
}

  @override
  void initState() {
    super.initState();
    _fetchLevels();
  }

  bool _isRefreshing = false;

  Future<void> _fetchLevels() async {
    if (_isRefreshing) return;
    _isRefreshing = true;

      try{
        final loadedLevels =
            await _levelService.getVisibleLevels();

          if (!mounted) {
          _isRefreshing = false;
          return;
        }

        setState(() {
          levels = loadedLevels;
          loading = false;
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          scrollToLastUnlocked();
        });
      } catch (e) {
        if (!mounted) {
          _isRefreshing = false;
          return;
        }

        setState(() => loading = false);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to load levels")),
        );
      }
      
        _isRefreshing = false;
  }

  /// Handles level tap
  Future<void> _openLevel(Level level) async {

    if (level.isLocked) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Finish Level ${level.levelNumber - 1} to unlock"),
        ),
      );
      return;
    }

    await Navigator.push(
      context,
       MaterialPageRoute(
         builder: (_) => GameScreen(levelNumber: level.levelNumber),
       ),
     );

     _fetchLevels();
  }

  /*
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
  */

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
            onTap: () => _openLevel(level),

          );
          },
        ),
      ),
    );
  }
}