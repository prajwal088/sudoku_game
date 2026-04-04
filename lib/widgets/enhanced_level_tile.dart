import 'package:flutter/material.dart';

/// ============================================================================
/// EnhancedLevelTile
/// ----------------------------------------------------------------------------
/// /// Production-ready level tile widget
///
/// Handles:
/// - Tap animation (press effect)
/// - Locked / Completed / Current states
/// - Star rendering
/// - Safe interaction (no tap on locked levels)
///
/// Visual States:
/// 🔒 Locked      → Grey + lock icon
/// ✅ Completed   → Green + stars
/// 🎯 Current     → Orange + glow
/// 
/// Clean, production-ready tile for linear progression.
/// [inProgress] is treated as the "Active/Current" level.
/// ============================================================================

enum LevelTileState {
  locked,
  inProgress,
  completed,
}

class EnhancedLevelTile extends StatefulWidget {
  final int levelNumber;
  final LevelTileState state;
  final int stars;
  final VoidCallback onTap;

  const EnhancedLevelTile({
    super.key,
    required this.levelNumber,
    required this.state,
    required this.onTap,
    this.stars = 0,
  });

  @override
  State<EnhancedLevelTile> createState() => _EnhancedLevelTileState();
}

class _EnhancedLevelTileState extends State<EnhancedLevelTile>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.92).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Color _getBackgroundColor() {
    switch (widget.state) {
      case LevelTileState.locked:
        return Colors.grey.shade300;
      case LevelTileState.inProgress:
        return Colors.blue.shade500; // Standout color for the active level
      case LevelTileState.completed:
        return Colors.green.shade400;
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isLocked = widget.state == LevelTileState.locked;
    final bool isActive = widget.state == LevelTileState.inProgress;

    return GestureDetector(
      onTap: isLocked ? null : widget.onTap,
      onTapDown: (_) => isLocked ? null : _controller.forward(),
      onTapUp: (_) => isLocked ? null : _controller.reverse(),
      onTapCancel: () => isLocked ? null : _controller.reverse(),
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          decoration: BoxDecoration(
            color: _getBackgroundColor(),
            borderRadius: BorderRadius.circular(16),
            // Only glow the level that is currently "In Progress"
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: Colors.blue.withAlpha(120),
                      blurRadius: 12,
                      spreadRadius: 2,
                    )
                  ]
                : [],
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Content Column - Prevents overlap
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    "${widget.levelNumber}",
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: isLocked ? Colors.black26 : Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (isLocked)
                    const Icon(Icons.lock, size: 20, color: Colors.black26)
                  else if (widget.state == LevelTileState.completed)
                    _buildStars(widget.stars)
                  else
                    const Text(
                      "PLAY",
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        color: Colors.white70,
                        letterSpacing: 1.1,
                      ),
                    ),
                ],
              ),

              // Top-right highlight for the active level
              if (isActive)
                Positioned(
                  top: -10,
                  right: -10,
                  child: CircleAvatar(
                    radius: 25,
                    backgroundColor: Colors.white.withAlpha(40),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStars(int count) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (index) {
        return Icon(
          index < count ? Icons.star : Icons.star_border,
          size: 14,
          color: Colors.yellowAccent,
        );
      }),
    );
  }
}