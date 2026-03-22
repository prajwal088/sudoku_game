import 'package:flutter/material.dart';
import '../models/level.dart';

/// ============================================================================
/// LevelTile
/// ----------------------------------------------------------------------------
/// Production-ready level tile widget
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
/// 🎯 Current     → Blue + glow
/// ============================================================================

class LevelTile extends StatefulWidget {
  final Level level;
  final bool isLocked;
  final bool isCurrent;
  final VoidCallback onTap;

  const LevelTile({
    super.key,
    required this.level,
    required this.isLocked,
    required this.isCurrent,
    required this.onTap,
  });

  @override
  State<LevelTile> createState() => _LevelTileState();
}

class _LevelTileState extends State<LevelTile>
    with SingleTickerProviderStateMixin {

  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;

  /// ==========================================================================
  /// INIT
  /// ==========================================================================
  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
    );

    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.92, // subtle press effect
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOut,
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// ==========================================================================
  /// TOUCH HANDLERS (disabled if locked)
  /// ==========================================================================
  void _handleTapDown(TapDownDetails details) {
    if (widget.level.isLocked) return;
    _controller.forward();
  }

  void _handleTapUp(TapUpDetails details) {
    if (widget.level.isLocked) return;
    _controller.reverse();
  }

  void _handleTapCancel() {
    if (widget.level.isLocked) return;
    _controller.reverse();
  }

  /// ==========================================================================
  /// TILE COLOR LOGIC
  /// ==========================================================================
  Color getTileColor() {
    if (widget.level.isLocked) {
      return Colors.grey.shade300;
    }

    if (widget.level.isCompleted) {
      return Colors.green.shade400;
    }

    if (widget.isCurrent) {
      return Colors.blue.shade500;
    }

    return Colors.orange.shade400;
  }

  /// ==========================================================================
  /// STAR WIDGET
  /// ==========================================================================
  Widget buildStars(int stars) {
    return AnimatedOpacity(
      opacity: widget.level.isCompleted ? 1 : 0,
      duration: const Duration(milliseconds: 300),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(3, (index) {
          return Icon(
            index < stars ? Icons.star : Icons.star_border,
            size: 14,
            color: Colors.orange,
          );
        }),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      /// Prevent tap if locked
      onTap: widget.level.isLocked ? null : widget.onTap,
      onTapDown: _handleTapDown,
      onTapUp: _handleTapUp,
      onTapCancel: _handleTapCancel,

      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              decoration: BoxDecoration(
                color: getTileColor(),
                borderRadius: BorderRadius.circular(12),

                /// Glow effect for current level
                boxShadow: widget.isCurrent && !widget.isLocked
                    ? [
                        BoxShadow(
                          color: Colors.blue.withValues(alpha: 0.6),
                          blurRadius: 12,
                          spreadRadius: 1,
                        ),
                      ]
                    : [],
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [

                  /// ================= LEVEL NUMBER =================
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

                  /// ================= LOCK ICON =================
                  if (widget.level.isLocked)
                    const Positioned(
                      bottom: 12, // 👈 below number
                      child: Icon(
                        Icons.lock,
                        color: Colors.black54,
                      ),
                    ),

                  /// ================= STARS =================
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