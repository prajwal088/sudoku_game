import 'package:flutter/material.dart';

import '../services/progress_service.dart';

class HomeScreen extends StatefulWidget {
const HomeScreen({super.key});

@override
State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
with SingleTickerProviderStateMixin {

final ProgressService progressService = ProgressService();

late AnimationController controller;
late Animation<double> scaleAnimation;

int nextLevel = 1;

@override
void initState() {
super.initState();

loadProgress();

controller = AnimationController(
  vsync: this,
  duration: const Duration(milliseconds: 800),
);

scaleAnimation = Tween<double>(
  begin: 0.9,
  end: 1,
).animate(
  CurvedAnimation(
    parent: controller,
    curve: Curves.easeInOut,
  ),
);

controller.repeat(reverse: true);

}

Future<void> loadProgress() async {

nextLevel = await progressService.getNextUnlockedLevel();

setState(() {});
}

@override
void dispose() {
controller.dispose();
super.dispose();
}

void startNextLevel() {

Navigator.pushNamed(
  context,
  "/game",
  arguments: nextLevel,
);
}

void openLevelMap() {

Navigator.pushNamed(
  context,
  "/levels",
);
}

@override
Widget build(BuildContext context) {

return Scaffold(

  body: SafeArea(
    child: Center(
      child: Column(

        mainAxisAlignment: MainAxisAlignment.center,

        children: [

          /// GAME ICON
          const Icon(
            Icons.grid_on,
            size: 120,
            color: Colors.blue,
          ),

          const SizedBox(height: 10),

          /// TITLE
          const Text(
            "Sudoku",
            style: TextStyle(
              fontSize: 40,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 40),

          /// CONTINUE BUTTON
          /// Issue : alway shows level 1 and does not shows next level or go to next level when user has progressed.
          ScaleTransition(
            scale: scaleAnimation,
            child: ElevatedButton(
              onPressed: startNextLevel,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 70,
                  vertical: 16,
                ),
              ),
              child: Text(
                "Continue (Level $nextLevel)",
                style: const TextStyle(fontSize: 18),
              ),
            ),
          ),

          const SizedBox(height: 15),

          /// PLAY BUTTON
          OutlinedButton(
            onPressed: openLevelMap,
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(
                horizontal: 80,
                vertical: 16,
              ),
            ),
            child: const Text(
              "Play",
              style: TextStyle(fontSize: 18),
            ),
          ),

          const SizedBox(height: 30),

          /// EXTRA OPTIONS
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
// Todo add screen to show stats of the played levels.
              IconButton(
                icon: const Icon(Icons.bar_chart, size: 28),
                onPressed: () {
                  Navigator.pushNamed(context, "/stats");
                },
              ),

              const SizedBox(width: 20),

// Todo add screen and neccessary button for settings

              IconButton(
                icon: const Icon(Icons.settings, size: 28),
                onPressed: () {
                  Navigator.pushNamed(context, "/settings");
                },
              ),

            ],
          ),

          const SizedBox(height: 20),

          /// FOOTER
          const Text(
            "Solve puzzles. Train your brain.",
            style: TextStyle(
              color: Colors.grey,
            ),
          ),

        ],
      ),
    ),
  ),
);
}
}