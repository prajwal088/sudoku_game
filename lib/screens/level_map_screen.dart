import 'package:flutter/material.dart';

import '../models/level.dart';
import '../services/level_service.dart';

class LevelMapScreen extends StatefulWidget {
  final int world;

  const LevelMapScreen({super.key, required this.world});

  @override
  State<LevelMapScreen> createState() => _LevelMapScreenState();
}

class _LevelMapScreenState extends State<LevelMapScreen> {
  final LevelService _levelService = LevelService();

  List<Level> levels = [];
  bool loading = true;

  final ScrollController _scrollController = ScrollController();

  static const int itemsPerRow = 5;
  static const double itemHeight = 80;

  @override
  void initState() {
    super.initState();
    loadLevels();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  // ================= LOAD =================
  Future<void> loadLevels() async {
    final loadedLevels =
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

  // ================= CURRENT LEVEL =================
  int getCurrentLevelIndex() {
    if (levels.isEmpty) return 0;

    for (int i = 0; i < levels.length; i++) {
      if (levels[i].isLocked) {
        return i - 1 >= 0 ? i - 1 : 0;
      }
    }
    return levels.length - 1;
  }

  void scrollToCurrentLevel() {
    int index = getCurrentLevelIndex();

    int row = index ~/ itemsPerRow;
    double offset = row * itemHeight;

    _scrollController.animateTo(
      offset,
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOut,
    );
  }

  // ================= NAVIGATION =================
  void openLevel(Level level) {
    if (level.isLocked) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Complete previous level to unlock"),
        ),
      );
      return;
    }

    Navigator.pushNamed(
      context,
      "/game",
      arguments: {
        "level": level.levelNumber,
        "world": widget.world,
      },
    ).then((_) => loadLevels());
  }

  // ================= UI =================
  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    int currentIndex = getCurrentLevelIndex();

    return Scaffold(
      appBar: AppBar(
        title: Text("🌍 World ${widget.world}"),
        centerTitle: true,
      ),
      body: GridView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.all(16),
        itemCount: levels.length,
        gridDelegate:
            const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: itemsPerRow,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          mainAxisExtent: itemHeight,
        ),
        itemBuilder: (context, index) {
          final level = levels[index];
          final isCurrent = index == currentIndex;

          return GestureDetector(
            onTap: () => openLevel(level),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              decoration: BoxDecoration(
                color: level.isLocked
                    ? Colors.grey.shade300
                    : isCurrent
                        ? Colors.orange.shade400
                        : Colors.blue.shade400,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  if (!level.isLocked)
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: isCurrent ? 10 : 4,
                      offset: const Offset(0, 3),
                    )
                ],
              ),
              child: Stack(
                children: [
                  /// LEVEL NUMBER
                  Center(
                    child: Text(
                      "${level.levelNumber}",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: level.isLocked
                            ? Colors.black38
                            : Colors.white,
                      ),
                    ),
                  ),

                  /// LOCK ICON
                  if (level.isLocked)
                    const Center(
                      child: Icon(
                        Icons.lock,
                        color: Colors.black45,
                      ),
                    ),

                  /// STARS
                  if (!level.isLocked && level.stars > 0)
                    Positioned(
                      bottom: 4,
                      left: 0,
                      right: 0,
                      child: Row(
                        mainAxisAlignment:
                            MainAxisAlignment.center,
                        children: List.generate(3, (i) {
                          return Icon(
                            i < level.stars
                                ? Icons.star
                                : Icons.star_border,
                            size: 12,
                            color: Colors.amber,
                          );
                        }),
                      ),
                    ),

                  /// CURRENT LEVEL GLOW
                  if (isCurrent && !level.isLocked)
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: Colors.white,
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}