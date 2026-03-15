import 'package:flutter/material.dart';

class WinScreen extends StatefulWidget {

final int levelNumber;
final int stars;
final String time;

const WinScreen({
super.key,
required this.levelNumber,
required this.stars,
required this.time,
});

@override
State<WinScreen> createState() => _WinScreenState();
}

class _WinScreenState extends State<WinScreen>
with TickerProviderStateMixin {

late AnimationController trophyController;
late AnimationController starController;

late Animation<double> trophyScale;

List<bool> visibleStars = [false, false, false];

@override
void initState() {
super.initState();
trophyController = AnimationController(
  vsync: this,
  duration: const Duration(milliseconds: 700),
);

starController = AnimationController(
  vsync: this,
  duration: const Duration(milliseconds: 800),
);

trophyScale = Tween<double>(
  begin: 0,
  end: 1,
).animate(
  CurvedAnimation(
    parent: trophyController,
    curve: Curves.elasticOut,
  ),
);

startAnimation();
}

Future<void> startAnimation() async {

trophyController.forward();

await Future.delayed(const Duration(milliseconds: 400));

for (int i = 0; i < widget.stars; i++) {

  await Future.delayed(const Duration(milliseconds: 350));

  setState(() {
    visibleStars[i] = true;
  });
}
}

@override
void dispose() {
trophyController.dispose();
starController.dispose();
super.dispose();
}

Widget buildStar(int index) {

return AnimatedScale(
  scale: visibleStars[index] ? 1 : 0,
  duration: const Duration(milliseconds: 400),
  curve: Curves.elasticOut,
  child: const Icon(
    Icons.star,
    size: 50,
    color: Colors.amber,
  ),
);
}

@override
Widget build(BuildContext context) {

return Scaffold(

  backgroundColor: Colors.green.shade50,

  body: SafeArea(
    child: Center(
      child: Column(

        mainAxisAlignment: MainAxisAlignment.center,

        children: [

          /// TROPHY
          ScaleTransition(
            scale: trophyScale,
            child: const Icon(
              Icons.emoji_events,
              size: 120,
              color: Colors.orange,
            ),
          ),

          const SizedBox(height: 20),

          const Text(
            "Level Complete!",
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 10),

          Text(
            "Level ${widget.levelNumber}",
            style: const TextStyle(
              fontSize: 18,
              color: Colors.grey,
            ),
          ),

          const SizedBox(height: 25),

          /// STARS
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              buildStar(0),
              const SizedBox(width: 10),
              buildStar(1),
              const SizedBox(width: 10),
              buildStar(2),
            ],
          ),

          const SizedBox(height: 30),

          /// TIME
          Text(
            "Time: ${widget.time}",
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w500,
            ),
          ),

          const SizedBox(height: 40),

          /// NEXT LEVEL
          ElevatedButton(
            onPressed: () {

              Navigator.pushReplacementNamed(
                context,
                "/game",
                arguments: widget.levelNumber + 1,
              );
            },
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(
                horizontal: 50,
                vertical: 16,
              ),
            ),
            child: const Text(
              "Next Level",
              style: TextStyle(fontSize: 18),
            ),
          ),

          const SizedBox(height: 15),

          /// REPLAY
          OutlinedButton(
            onPressed: () {

              Navigator.pushReplacementNamed(
                context,
                "/game",
                arguments: widget.levelNumber,
              );
            },
            child: const Text(
              "Replay Level",
              style: TextStyle(fontSize: 16),
            ),
          ),

          const SizedBox(height: 15),

          /// LEVEL MAP
          TextButton(
            onPressed: () {

              Navigator.pushReplacementNamed(
                context,
                "/levels",
              );
            },
            child: const Text(
              "Level Map",
              style: TextStyle(fontSize: 16),
            ),
          )

        ],
      ),
    ),
  ),
);
}
}