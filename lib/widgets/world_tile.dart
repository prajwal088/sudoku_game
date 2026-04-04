import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lottie/lottie.dart';
import 'package:audioplayers/audioplayers.dart';

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
///
/// States:
/// 🔒 Locked       → Grey, reduced opacity
/// 🌍 Unlocked     → Gradient + progress
/// 🎉 Unlock Event → Animation + sound
/// ============================================================================

class WorldTile extends StatefulWidget {
  final int worldNumber;
  final bool isLocked;
  final VoidCallback onTap;

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
    this.starsEarned,
    this.totalStars,
    this.color,
  });

  @override
  State<WorldTile> createState() => _WorldTileState();
}

class _WorldTileState extends State<WorldTile> {
  final AudioPlayer _player = AudioPlayer();

  bool _showUnlockAnim = false;

  /// ==========================================================================
  /// Detect unlock transition
  /// ==========================================================================
  @override
  void didUpdateWidget(covariant WorldTile oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.isLocked && !widget.isLocked) {
      _playUnlockAnimation();
    }
  }

  /// ==========================================================================
  /// UNLOCK ANIMATION + SOUND
  /// ==========================================================================
  Future<void> _playUnlockAnimation() async {
    if (_showUnlockAnim) return; // prevent duplicate trigger

    setState(() => _showUnlockAnim = true);

    HapticFeedback.mediumImpact();

    try {
      await _player.play(AssetSource('sounds/unlock.mp3'));
    } catch (_) {
      // Fail silently (production safe)
    }

    await Future.delayed(const Duration(seconds: 2));

    if (mounted) {
      setState(() => _showUnlockAnim = false);
    }
  }

  /// ==========================================================================
  /// TAP HANDLER
  /// ==========================================================================
  Future<void> _handleTap() async {
    if (widget.isLocked) {
      HapticFeedback.heavyImpact();
      return;
    }

    HapticFeedback.selectionClick();

    try {
      await _player.play(AssetSource('sounds/tap.mp3'));
    } catch (_) {}

    widget.onTap();
  }

  @override
  void dispose() {
    _player.dispose(); // ✅ CRITICAL FIX
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Color themeColor = widget.color ?? Colors.blueAccent;

    final int earned = widget.starsEarned ?? 0;
    final int total = widget.totalStars ?? 75;

    final double progress =
        total == 0 ? 0 : (earned / total).clamp(0.0, 1.0);

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(20),

      child: InkWell(
        onTap: _handleTap,
        borderRadius: BorderRadius.circular(20),

        splashColor: themeColor.withValues(alpha: 0.2),
        highlightColor: Colors.white.withValues(alpha: 0.1),

        child: Stack(
          children: [

            /// ================= MAIN TILE =================
            AnimatedScale(
              scale: widget.isLocked ? 0.95 : 1,
              duration: const Duration(milliseconds: 300),

              child: AnimatedOpacity(
                opacity: widget.isLocked ? 0.7 : 1,
                duration: const Duration(milliseconds: 300),

                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  padding: const EdgeInsets.all(14),

                  decoration: BoxDecoration(
                    gradient: widget.isLocked
                        ? LinearGradient(
                            colors: [
                              Colors.grey.shade400,
                              Colors.grey.shade300,
                            ],
                          )
                        : LinearGradient(
                            colors: [
                              themeColor.withValues(alpha: 0.85),
                              themeColor,
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),

                    borderRadius: BorderRadius.circular(20),

                    boxShadow: [
                      if (!widget.isLocked)
                        BoxShadow(
                          color: themeColor.withValues(alpha: 0.4),
                          blurRadius: 12,
                          offset: const Offset(0, 6),
                        ),
                    ],
                  ),

                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [

                      /// ================= HEADER =================
                      Row(
                        mainAxisAlignment:
                            MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "World ${widget.worldNumber}",
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),

                          Icon(
                            widget.isLocked
                                ? Icons.lock
                                : Icons.public,
                            color: Colors.white,
                          ),
                        ],
                      ),

                      const Spacer(),

                      /// ================= PROGRESS =================
                      if (widget.starsEarned != null &&
                          widget.totalStars != null)
                        Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            Text(
                              "$earned / $total",
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),

                            const SizedBox(height: 6),

                            /// Progress Bar
                            ClipRRect(
                              borderRadius:
                                  BorderRadius.circular(10),
                              child: LinearProgressIndicator(
                                value: progress,
                                minHeight: 8,
                                backgroundColor: Colors.white24,
                                valueColor:
                                    const AlwaysStoppedAnimation(
                                        Colors.white),
                              ),
                            ),

                            const SizedBox(height: 4),

                            Text(
                              "${(progress * 100).toInt()}% completed",
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.white70,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
            ),

            /// ================= UNLOCK ANIMATION =================
            if (_showUnlockAnim)
              Positioned.fill(
                child: IgnorePointer(
                  child: Lottie.asset(
                    'assets/animations/unlock.json',
                    fit: BoxFit.cover,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}