import 'package:flutter/material.dart';

class WorldTile extends StatelessWidget {
  final int worldNumber;
  final bool isLocked;
  final VoidCallback onTap;

  // 🔥 Optional (future-ready)
  final int? starsEarned;
  final int? totalLevels;
  final Color? color;

  const WorldTile({
    super.key,
    required this.worldNumber,
    required this.isLocked,
    required this.onTap,
    this.starsEarned,
    this.totalLevels,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final themeColor = color ?? Colors.blueAccent;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
        decoration: BoxDecoration(
          gradient: isLocked
              ? LinearGradient(
                  colors: [Colors.grey.shade400, Colors.grey.shade300],
                )
              : LinearGradient(
                  colors: [
                    themeColor,
                    themeColor.withValues(alpha: 0.7),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            if (!isLocked)
              BoxShadow(
                color: themeColor.withValues(alpha: 0.4),
                blurRadius: 10,
                offset: const Offset(0, 6),
              ),
          ],
        ),
        child: Stack(
          children: [
            // 🌍 World Title
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    "World $worldNumber",
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),

                  // ⭐ Progress (optional)
                  if (starsEarned != null && totalLevels != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        "$starsEarned / $totalLevels",
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.white70,
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // 🔒 Lock Icon
            if (isLocked)
              const Positioned(
                top: 8,
                right: 8,
                child: Icon(
                  Icons.lock,
                  color: Colors.white,
                ),
              ),
          ],
        ),
      ),
    );
  }
}