import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lottie/lottie.dart';

/// ============================================================================
/// WorldTile
/// ----------------------------------------------------------------------------
/// Displays a world card in the world selection screen.
///
/// Features:
/// - Lock / Unlock state
/// - Star progress visualization
/// - Unlock animation (Lottie)
/// - Sound + haptic feedback
/// - Smooth UI transitions
/// - Screen-reader support
///
/// States:
/// 🔒 Locked       → Grey, reduced opacity
/// 🌍 Unlocked     → Gradient + progress
/// 🎉 Unlock Event → Animation + sound
///
/// Tap behaviour:
/// - Unlocked tile → [onTap] is called immediately (sound never delays it).
/// - Locked tile   → heavy haptic, then the optional [onLockedTap], so the
///   parent can explain why the world is locked. Without it, nothing else
///   happens (as before). [onTap] is never called for a locked tile.
/// ============================================================================

class WorldTile extends StatefulWidget {
  final int worldNumber;
  final bool isLocked;
  final VoidCallback onTap;

  /// Optional feedback hook for taps on a locked tile.
  final VoidCallback? onLockedTap;

  /// Stars earned in this world
  final int? starsEarned;

  /// Total stars possible (typically levelsPerWorld * 3)
  final int? totalStars;

  /// Optional theme color
  final Color? color;

  const WorldTile({
    super.key,
    required this.worldNumber,
    required this.isLocked,
    required this.onTap,
    this.onLockedTap,
    this.starsEarned,
    this.totalStars,
    this.color,
  });

  @override
  State<WorldTile> createState() => _WorldTileState();
}

class _WorldTileState extends State<WorldTile> {
  static const String _tapSound = 'sounds/tap.mp3';
  static const String _unlockSound = 'sounds/unlock.mp3';
  static const String _unlockAnimationAsset = 'assets/animations/unlock.json';

  static const Duration _unlockAnimationDuration = Duration(seconds: 2);
  static const Duration _stateDuration = Duration(milliseconds: 150);
  static const Duration _colorDuration = Duration(milliseconds: 250);

  static const double _radius = 20;

  bool _showUnlockAnim = false;

  Timer? _unlockTimer;

  // ==========================================================================
  // LIFECYCLE
  // ==========================================================================

  /// Detect the locked -> unlocked transition.
  @override
  void didUpdateWidget(covariant WorldTile oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.isLocked && !widget.isLocked) {
      _startUnlockEffects();
    }
  }

  @override
  void dispose() {
    _unlockTimer?.cancel();
    super.dispose();
  }

  // ==========================================================================
  // UNLOCK ANIMATION + SOUND
  // ==========================================================================

  void _startUnlockEffects() {
    if (_showUnlockAnim) {
      return; // prevent duplicate trigger
    }

    // Called from didUpdateWidget, so a rebuild follows: no setState needed.
    _showUnlockAnim = true;

    unawaited(HapticFeedback.mediumImpact());
    unawaited(_TileSounds.play(_unlockSound));

    _unlockTimer?.cancel();
    _unlockTimer = Timer(_unlockAnimationDuration, () {
      if (!mounted) {
        return;
      }

      setState(() {
        _showUnlockAnim = false;
      });
    });
  }

  // ==========================================================================
  // TAP HANDLER
  // ==========================================================================

  void _handleTap() {
    if (widget.isLocked) {
      unawaited(HapticFeedback.heavyImpact());
      widget.onLockedTap?.call();
      return;
    }

    unawaited(HapticFeedback.selectionClick());

    // Fire-and-forget: audio start-up must never delay navigation.
    unawaited(_TileSounds.play(_tapSound));

    widget.onTap();
  }

  // ==========================================================================
  // ACCESSIBILITY
  // ==========================================================================

  String _semanticLabel(int? earned, int? total, double progress) {
    final int world = widget.worldNumber;

    if (widget.isLocked) {
      return 'World $world, locked';
    }

    if (earned != null && total != null) {
      return 'World $world, $earned of $total stars, '
          '${(progress * 100).floor()} percent complete';
    }

    return 'World $world';
  }

  // ==========================================================================
  // BUILD
  // ==========================================================================

  @override
  Widget build(BuildContext context) {
    final Color themeColor = widget.color ?? Colors.blueAccent;

    // Progress is only meaningful (and only shown) when both values exist.
    final int? total = widget.totalStars;
    final int? rawEarned = widget.starsEarned;
    final bool showProgress = rawEarned != null && total != null;

    final int earned = showProgress && total > 0
        ? rawEarned.clamp(0, total)
        : (rawEarned ?? 0);

    final double progress = showProgress && total > 0
        ? (earned / total).clamp(0.0, 1.0)
        : 0.0;

    // Respect the system "reduce motion" accessibility setting.
    final bool reduceMotion = MediaQuery.disableAnimationsOf(context);

    final BorderRadius borderRadius = BorderRadius.circular(_radius);

    return Semantics(
      button: true,
      enabled: !widget.isLocked,
      label: _semanticLabel(
        showProgress ? earned : null,
        total,
        progress,
      ),
      // The visual children are summarised by the label.
      excludeSemantics: true,
      onTap: _handleTap,
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          // ================= MAIN TILE =================
          AnimatedScale(
            // A rigid curve prevents "wobble" during scroll.
            curve: Curves.decelerate,
            scale: widget.isLocked ? 0.95 : 1,
            duration: reduceMotion ? Duration.zero : _stateDuration,
            child: AnimatedOpacity(
              // Same duration as the scale for a synchronized feel.
              opacity: widget.isLocked ? 0.7 : 1,
              duration: reduceMotion ? Duration.zero : _stateDuration,
              child: AnimatedContainer(
                duration: reduceMotion ? Duration.zero : _colorDuration,
                decoration: BoxDecoration(
                  gradient: widget.isLocked
                      ? LinearGradient(
                          colors: <Color>[
                            Colors.grey.shade400,
                            Colors.grey.shade300,
                          ],
                        )
                      : LinearGradient(
                          colors: <Color>[
                            themeColor.withValues(alpha: 0.85),
                            themeColor,
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                  borderRadius: borderRadius,
                  boxShadow: <BoxShadow>[
                    if (!widget.isLocked)
                      BoxShadow(
                        color: themeColor.withValues(alpha: 0.4),
                        blurRadius: 12,
                        offset: const Offset(0, 6),
                      ),
                  ],
                ),

                // The Material + InkWell sit INSIDE the decorated container,
                // so the ink splash is painted above the gradient. (With the
                // InkWell outside, the opaque gradient hid the splash.)
                child: Material(
                  color: Colors.transparent,
                  borderRadius: borderRadius,
                  child: InkWell(
                    onTap: _handleTap,
                    borderRadius: borderRadius,
                    splashColor: themeColor.withValues(alpha: 0.2),
                    highlightColor: Colors.white.withValues(alpha: 0.1),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: _buildContent(showProgress, earned, total, progress),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // ================= UNLOCK ANIMATION =================
          if (_showUnlockAnim && !reduceMotion)
            Positioned.fill(
              child: IgnorePointer(
                child: Lottie.asset(
                  _unlockAnimationAsset,
                  fit: BoxFit.cover,
                  repeat: false,
                  // A missing/invalid asset must never show an error widget
                  // on top of the tile.
                  errorBuilder: (
                    BuildContext context,
                    Object error,
                    StackTrace? stackTrace,
                  ) {
                    return const SizedBox.shrink();
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ==========================================================================
  // CONTENT
  // ==========================================================================

  Widget _buildContent(
    bool showProgress,
    int earned,
    int? total,
    double progress,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        // ================= HEADER =================
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            Flexible(
              child: Text(
                'World ${widget.worldNumber}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
            Icon(
              widget.isLocked ? Icons.lock : Icons.public,
              color: Colors.white,
            ),
          ],
        ),

        const Spacer(),

        // ================= PROGRESS =================
        if (showProgress)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                '$earned / $total',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),

              const SizedBox(height: 6),

              // Progress bar
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 8,
                  backgroundColor: Colors.white24,
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    Colors.white,
                  ),
                ),
              ),

              const SizedBox(height: 4),

              // Truncated (not rounded) so 74/75 never reads "100%".
              Text(
                '${(progress * 100).floor()}% completed',
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.white70,
                ),
              ),
            ],
          ),
      ],
    );
  }
}

// ============================================================================
// SOUND EFFECTS
// ----------------------------------------------------------------------------
// ONE shared player for every tile. The previous code created an AudioPlayer
// (a native player) per tile, so a 10-world map held 10 native players.
// The shared player is created lazily on first use and lives for the app's
// lifetime. Sound failures are never allowed to affect the UI.
// ============================================================================

abstract final class _TileSounds {
  static AudioPlayer? _player;

  static Future<void> play(String assetPath) async {
    try {
      final AudioPlayer player = _player ??= AudioPlayer();

      await player.play(AssetSource(assetPath));
    } catch (_) {
      // Fail silently (production safe).
    }
  }
}