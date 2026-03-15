import 'package:flutter/material.dart';
import '../models/level.dart';

class LevelTile extends StatefulWidget {

final Level level;
final VoidCallback onTap;

const LevelTile({
super.key,
required this.level,
required this.onTap,
});

@override
State<LevelTile> createState() => _LevelTileState();
}

class _LevelTileState extends State<LevelTile>
with SingleTickerProviderStateMixin {

late AnimationController _controller;
late Animation<double> _scaleAnimation;

@override
void initState() {

super.initState();

_controller = AnimationController(
  vsync: this,
  duration: const Duration(milliseconds: 120),
  lowerBound: 0.0,
  upperBound: 0.1,
);

_scaleAnimation = Tween<double>(
  begin: 1,
  end: 0.9,
).animate(_controller);
}

@override
void dispose() {
_controller.dispose();
super.dispose();
}

void _handleTapDown(TapDownDetails details) {
_controller.forward();
}

void _handleTapUp(TapUpDetails details) {
_controller.reverse();
}

void _handleTapCancel() {
_controller.reverse();
}

Widget buildStars(int stars) {

return AnimatedOpacity(
  opacity: widget.level.isCompleted ? 1 : 0,
  duration: const Duration(milliseconds: 400),

  child: Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: List.generate(3, (index) {

      return Icon(
        index < stars
            ? Icons.star
            : Icons.star_border,
        size: 14,
        color: Colors.orange,
      );
    }),
  ),
);
}

Color getTileColor() {

if (widget.level.isLocked) {
  return Colors.grey.shade300;
}

if (widget.level.isCompleted) {
  return Colors.green.shade400;
}

return Colors.blue.shade400;
}

@override
Widget build(BuildContext context) {

bool isCurrentLevel =
    !widget.level.isLocked && !widget.level.isCompleted;

return GestureDetector(

  onTapDown: _handleTapDown,
  onTapUp: _handleTapUp,
  onTapCancel: _handleTapCancel,

  onTap: widget.onTap,

  child: AnimatedBuilder(

    animation: _controller,

    builder: (context, child) {

      return Transform.scale(
        scale: _scaleAnimation.value,

        child: Container(

          decoration: BoxDecoration(

            color: getTileColor(),

            borderRadius: BorderRadius.circular(12),

            boxShadow: isCurrentLevel
                ? [
                    BoxShadow(
                      color: Colors.blue.withValues(alpha: 0.6),
                      blurRadius: 12,
                      spreadRadius: 2,
                    )
                  ]
                : [],
          ),

          child: Stack(

            children: [

              /// LOCK ICON
              if (widget.level.isLocked)
                const Center(
                  child: Icon(
                    Icons.lock,
                    color: Colors.black54,
                  ),
                ),

              /// LEVEL NUMBER
              if (!widget.level.isLocked)
                Center(
                  child: Text(
                    "${widget.level.levelNumber}",
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),

              /// STARS
              if (widget.level.isCompleted)
                Positioned(
                  bottom: 4,
                  left: 0,
                  right: 0,
                  child: buildStars(widget.level.stars),
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