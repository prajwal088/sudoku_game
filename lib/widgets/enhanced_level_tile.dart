import 'package:flutter/material.dart';

/// ============================================================================
/// EnhancedLevelTile
/// ----------------------------------------------------------------------------
/// Production-ready level tile widget.
///
/// Responsibilities:
/// - Display the level number.
/// - Display locked / current / completed states.
/// - Display completion stars.
/// - Provide a press animation.
/// - Prevent interaction with locked levels.
///
/// Visual states:
/// - Locked    → Grey + lock icon
/// - Completed → Green + stars
/// - Current   → Blue + glow + PLAY indicator
///
/// IMPORTANT:
/// - The tile does not determine progression.
/// - The tile does not read ProgressService.
/// - The tile does not calculate unlock state.
/// - The parent screen provides the LevelTileState.
/// - [onTap] remains non-nullable because locked-level interaction is handled
///   internally by this widget.
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

  bool get _isLocked =>
      widget.state == LevelTileState.locked;

  bool get _isActive =>
      widget.state == LevelTileState.inProgress;

  int get _safeStars =>
      widget.stars.clamp(0, 3);

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );

    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.92,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOut,
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// ========================================================================
  /// VISUALS
  /// ========================================================================

  Color _getBackgroundColor() {
    switch (widget.state) {
      case LevelTileState.locked:
        return Colors.grey.shade300;

      case LevelTileState.inProgress:
        return Colors.blue.shade500;

      case LevelTileState.completed:
        return Colors.green.shade400;
    }
  }

  /// ========================================================================
  /// PRESS ANIMATION
  /// ========================================================================

  void _handleTapDown(TapDownDetails details) {
    if (_isLocked) {
      return;
    }

    _controller.forward();
  }

  void _handleTapUp(TapUpDetails details) {
    if (_isLocked) {
      return;
    }

    _controller.reverse();
  }

  void _handleTapCancel() {
    if (_isLocked) {
      return;
    }

    _controller.reverse();
  }

  /// ========================================================================
  /// BUILD
  /// ========================================================================

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _isLocked ? null : widget.onTap,
      onTapDown: _handleTapDown,
      onTapUp: _handleTapUp,
      onTapCancel: _handleTapCancel,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          decoration: BoxDecoration(
            color: _getBackgroundColor(),
            borderRadius: BorderRadius.circular(16),
            boxShadow: _isActive
                ? <BoxShadow>[
                    BoxShadow(
                      color: Colors.blue.withAlpha(120),
                      blurRadius: 12,
                      spreadRadius: 2,
                    ),
                  ]
                : const <BoxShadow>[],
          ),
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: <Widget>[
              /// ============================================================
              /// MAIN CONTENT
              /// ============================================================

              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    '${widget.levelNumber}',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: _isLocked
                          ? Colors.black26
                          : Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  _buildStatusContent(),
                ],
              ),

              /// ============================================================
              /// ACTIVE LEVEL HIGHLIGHT
              /// ============================================================

              if (_isActive)
                Positioned(
                  top: -10,
                  right: -10,
                  child: IgnorePointer(
                    child: CircleAvatar(
                      radius: 25,
                      backgroundColor:
                          Colors.white.withAlpha(40),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// ========================================================================
  /// STATUS CONTENT
  /// ========================================================================

  Widget _buildStatusContent() {
    if (_isLocked) {
      return const Icon(
        Icons.lock,
        size: 20,
        color: Colors.black26,
      );
    }

    if (widget.state == LevelTileState.completed) {
      return _buildStars();
    }

    return const Text(
      'PLAY',
      style: TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w900,
        color: Colors.white70,
        letterSpacing: 1.1,
      ),
    );
  }

  /// ========================================================================
  /// STARS
  /// ========================================================================

  Widget _buildStars() {
    final int stars = _safeStars;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List<Widget>.generate(
        3,
        (int index) {
          return Icon(
            index < stars
                ? Icons.star
                : Icons.star_border,
            size: 14,
            color: Colors.yellowAccent,
          );
        },
      ),
    );
  }
}