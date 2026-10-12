import 'package:flutter/material.dart';
import 'package:sudoku_game/config/game_config.dart';

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
/// - Prevent opening locked levels.
/// - Expose the tile to screen readers as a labelled button.
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
/// - [onTap] remains non-nullable and is NEVER called for a locked tile.
/// - [onLockedTap] is optional: when provided, it is called instead when a
///   locked tile is tapped, so the parent can explain why the level is
///   locked. When omitted, tapping a locked tile does nothing (as before).
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

  /// Optional feedback hook for taps on a locked tile.
  final VoidCallback? onLockedTap;

  const EnhancedLevelTile({
    super.key,
    required this.levelNumber,
    required this.state,
    required this.onTap,
    this.stars = 0,
    this.onLockedTap,
  });

  @override
  State<EnhancedLevelTile> createState() => _EnhancedLevelTileState();
}

class _EnhancedLevelTileState extends State<EnhancedLevelTile> {
  /// The tile always draws this many star slots.
  static const int _maxStars = GameConfig.maxStarsPerLevel;

  static const Duration _pressDuration = Duration(milliseconds: 100);
  static const Duration _colorDuration = Duration(milliseconds: 250);

  static const double _pressedScale = 0.92;

  /// Press feedback is a plain flag + AnimatedScale, instead of a dedicated
  /// AnimationController/Ticker per tile (a level map shows 25 tiles).
  bool _isPressed = false;

  bool get _isLocked => widget.state == LevelTileState.locked;

  bool get _isActive => widget.state == LevelTileState.inProgress;

  int get _safeStars => widget.stars.clamp(0, _maxStars);

  // ==========================================================================
  // LIFECYCLE
  // ==========================================================================

  @override
  void didUpdateWidget(EnhancedLevelTile oldWidget) {
    super.didUpdateWidget(oldWidget);

    // A tile that becomes locked mid-press must not stay scaled down.
    if (_isLocked && _isPressed) {
      _isPressed = false;
    }
  }

  // ==========================================================================
  // VISUALS
  // ==========================================================================

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

  // ==========================================================================
  // INTERACTION
  // ==========================================================================

  void _handleTap() {
    if (_isLocked) {
      widget.onLockedTap?.call();
      return;
    }

    widget.onTap();
  }

  void _setPressed(bool pressed) {
    if (_isLocked || _isPressed == pressed) {
      return;
    }

    setState(() {
      _isPressed = pressed;
    });
  }

  void _handleTapDown(TapDownDetails details) => _setPressed(true);

  void _handleTapUp(TapUpDetails details) => _setPressed(false);

  void _handleTapCancel() => _setPressed(false);

  // ==========================================================================
  // ACCESSIBILITY
  // ==========================================================================

  String get _semanticLabel {
    final int level = widget.levelNumber;

    switch (widget.state) {
      case LevelTileState.locked:
        return 'Level $level, locked';

      case LevelTileState.inProgress:
        return 'Level $level, current level';

      case LevelTileState.completed:
        return 'Level $level, completed, $_safeStars of $_maxStars stars';
    }
  }

  // ==========================================================================
  // BUILD
  // ==========================================================================

  @override
  Widget build(BuildContext context) {
    // Respect the system "reduce motion" accessibility setting.
    final bool reduceMotion = MediaQuery.disableAnimationsOf(context);

    return Semantics(
      button: true,
      enabled: !_isLocked,
      label: _semanticLabel,
      // The visual children (number, icons) are summarised by the label.
      excludeSemantics: true,
      onTap: _handleTap,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _handleTap,
        onTapDown: _handleTapDown,
        onTapUp: _handleTapUp,
        onTapCancel: _handleTapCancel,
        child: AnimatedScale(
          scale: _isPressed ? _pressedScale : 1.0,
          duration: reduceMotion ? Duration.zero : _pressDuration,
          curve: Curves.easeInOut,
          child: AnimatedContainer(
            duration: reduceMotion ? Duration.zero : _colorDuration,
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
                // ============================================================
                // MAIN CONTENT
                // ============================================================
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    // Scales down instead of overflowing for 3-digit levels
                    // or large system text sizes.
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        '${widget.levelNumber}',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: _isLocked ? Colors.black26 : Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    _buildStatusContent(),
                  ],
                ),

                // ============================================================
                // ACTIVE LEVEL HIGHLIGHT
                // ============================================================
                if (_isActive)
                  Positioned(
                    top: -10,
                    right: -10,
                    child: IgnorePointer(
                      child: CircleAvatar(
                        radius: 25,
                        backgroundColor: Colors.white.withAlpha(40),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ==========================================================================
  // STATUS CONTENT
  // ==========================================================================

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

  // ==========================================================================
  // STARS
  // ==========================================================================

  Widget _buildStars() {
    final int stars = _safeStars;

    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List<Widget>.generate(_maxStars, (int index) {
          return Icon(
            index < stars ? Icons.star : Icons.star_border,
            size: 14,
            color: Colors.yellowAccent,
          );
        }, growable: false),
      ),
    );
  }
}