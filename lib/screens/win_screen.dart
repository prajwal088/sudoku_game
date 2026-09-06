import 'package:flutter/material.dart';

import '../main.dart';
import '../services/progress_service.dart';

/// ============================================================================
/// WinScreen
/// ----------------------------------------------------------------------------
/// Displays the result after completing a Sudoku level.
///
/// Responsibilities:
/// - Display completion result.
/// - Animate trophy and earned stars.
/// - Allow the player to continue to the next level.
/// - Allow replaying the completed level.
/// - Return to the appropriate level map.
///
/// Architecture:
/// - GameScreen is responsible for saving progress.
/// - ProgressService is the source of truth for progression.
/// - WinScreen is responsible for presentation and navigation.
///
/// Level architecture:
/// - A level has ONE identity: [levelNumber].
/// - World and local level numbers are derived from [levelNumber].
///
/// IMPORTANT:
/// - Do not pass world separately when opening a GameScreen.
/// - GameArguments contains only levelNumber.
/// ============================================================================

class WinScreen extends StatefulWidget {
  /// Global level identifier.
  final int levelNumber;

  /// Stars earned for this completion.
  final int stars;

  /// Formatted completion time.
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
    with SingleTickerProviderStateMixin {
  final ProgressService _progressService = ProgressService();

  late final AnimationController _trophyController;
  late final Animation<double> _trophyScale;

  final List<bool> _visibleStars = <bool>[false, false, false];

  bool _isLoading = true;
  bool _isReplay = false;
  bool _isLastLevel = false;
  bool _worldCompleteDialogShown = false;

  /// ==========================================================================
  /// DERIVED LEVEL INFORMATION
  /// ==========================================================================

  /// Number of stars that can safely be displayed.
  int get _safeStars => widget.stars.clamp(0, 3);

  /// World containing the current global level.
  int get _world => _progressService.getWorldFromGlobal(widget.levelNumber);

  /// Local level number inside the current world.
  int get _levelInWorld => _progressService.getLevelInWorld(widget.levelNumber);

  /// ==========================================================================
  /// LIFECYCLE
  /// ==========================================================================

  @override
  void initState() {
    super.initState();

    _trophyController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );

    _trophyScale = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _trophyController, curve: Curves.elasticOut),
    );

    _initialize();
  }

  /// ==========================================================================
  /// INITIALIZATION
  /// ==========================================================================

  Future<void> _initialize() async {
    try {
      final int nextUnlockedLevel = await _progressService
          .getNextUnlockedLevel();

      if (!mounted) return;

      /// Example:
      ///
      /// Player completes level 5.
      /// nextUnlockedLevel = 6.
      ///
      /// Therefore level 5 is NOT a replay.
      ///
      /// If the player later replays level 3 while level 6 is unlocked:
      /// 3 < 6 - 1 → true.
      final bool isReplay = widget.levelNumber < nextUnlockedLevel - 1;

      final bool isLastLevelOfWorld =
          _levelInWorld == ProgressService.levelsPerWorld;

      setState(() {
        _isReplay = isReplay;
        _isLastLevel = isLastLevelOfWorld;
        _isLoading = false;
      });

      await _startAnimation();

      if (!mounted) return;

      /// Only show the world-complete dialog when:
      /// - this is the final level of the world
      /// - this was not a replay
      /// - the dialog has not already been shown
      if (_isLastLevel && !_isReplay && !_worldCompleteDialogShown) {
        await Future<void>.delayed(const Duration(milliseconds: 500));

        if (!mounted) return;

        await _showWorldCompleteDialog();
      }
    } catch (e, stackTrace) {
      debugPrint('WinScreen: failed to initialize: $e');

      debugPrintStack(stackTrace: stackTrace);

      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });
    }
  }

  /// ==========================================================================
  /// ANIMATIONS
  /// ==========================================================================

  Future<void> _startAnimation() async {
    if (!mounted) return;

    await _trophyController.forward();

    if (!mounted) return;

    await Future<void>.delayed(const Duration(milliseconds: 250));

    for (int i = 0; i < _safeStars; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 300));

      if (!mounted) return;

      setState(() {
        _visibleStars[i] = true;
      });
    }
  }

  /// ==========================================================================
  /// WORLD COMPLETE
  /// ==========================================================================

  Future<void> _showWorldCompleteDialog() async {
    if (!mounted || _worldCompleteDialogShown) return;

    _worldCompleteDialogShown = true;

    final int nextWorld = _world + 1;

    /// No next world exists when the player completes the final
    /// configured world.
    if (nextWorld > GameConfig.totalWorlds) {
      return;
    }

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('🎉 World Complete!'),
          content: Text(
            'World $_world is complete!\n\n'
            'World $nextWorld is now unlocked.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();

                if (!mounted) return;

                _openWorld(nextWorld);
              },
              child: const Text('Continue'),
            ),
          ],
        );
      },
    );
  }

  /// ==========================================================================
  /// NAVIGATION
  /// ==========================================================================

  /// Opens the next global level.
  ///
  /// The next level is identified only by its global level number.
  void _openNextLevel() {
    if (_isLoading || _isReplay || _isLastLevel) {
      return;
    }

    final int nextLevel = widget.levelNumber + 1;

    /// Safety check.
    if (nextLevel > GameConfig.totalLevels) {
      _showMessage('You have completed all available levels!');
      return;
    }

    Navigator.pushReplacementNamed(
      context,
      AppRoutes.game,
      arguments: GameArguments(levelNumber: nextLevel),
    );
  }

  /// Replays the current level.
  ///
  /// Only the global level number is required.
  void _replayLevel() {
    Navigator.pushReplacementNamed(
      context,
      AppRoutes.game,
      arguments: GameArguments(levelNumber: widget.levelNumber),
    );
  }

  /// Returns to the level map for the current level's world.
  void _backToLevelMap() {
    Navigator.pushReplacementNamed(
      context,
      AppRoutes.levels,
      arguments: _world,
    );
  }

  /// Opens a specific world.
  void _openWorld(int world) {
    if (!mounted) return;

    if (world < 1 || world > GameConfig.totalWorlds) {
      return;
    }

    Navigator.pushReplacementNamed(context, AppRoutes.levels, arguments: world);
  }

  /// ==========================================================================
  /// USER FEEDBACK
  /// ==========================================================================

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
      );
  }

  /// ==========================================================================
  /// STAR WIDGET
  /// ==========================================================================

  Widget _buildStar(int index) {
    return AnimatedScale(
      scale: _visibleStars[index] ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 400),
      curve: Curves.elasticOut,
      child: const Icon(Icons.star, size: 50, color: Colors.amber),
    );
  }

  /// ==========================================================================
  /// BUILD
  /// ==========================================================================

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.green.shade50,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                /// ============================================================
                /// TROPHY
                /// ============================================================
                ScaleTransition(
                  scale: _trophyScale,
                  child: const Icon(
                    Icons.emoji_events,
                    size: 120,
                    color: Colors.orange,
                  ),
                ),

                const SizedBox(height: 20),

                /// ============================================================
                /// TITLE
                /// ============================================================
                Text(
                  'Level Complete!',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 8),

                Text(
                  'Level ${widget.levelNumber}',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),

                const SizedBox(height: 25),

                /// ============================================================
                /// STARS
                /// ============================================================
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildStar(0),
                    const SizedBox(width: 10),
                    _buildStar(1),
                    const SizedBox(width: 10),
                    _buildStar(2),
                  ],
                ),

                const SizedBox(height: 30),

                /// ============================================================
                /// TIME
                /// ============================================================
                Text(
                  'Time: ${widget.time}',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),

                const SizedBox(height: 40),

                /// ============================================================
                /// LOADING
                /// ============================================================
                if (_isLoading)
                  const Padding(
                    padding: EdgeInsets.all(8),
                    child: CircularProgressIndicator(),
                  )
                else ...[
                  /// ========================================================
                  /// NEXT LEVEL
                  /// ========================================================
                  if (!_isReplay && !_isLastLevel)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _openNextLevel,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: const Text(
                          'Next Level',
                          style: TextStyle(fontSize: 18),
                        ),
                      ),
                    ),

                  /// ========================================================
                  /// REPLAY INFORMATION
                  /// ========================================================
                  if (_isReplay) ...[
                    Text(
                      'Replaying Level',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: Colors.blueGrey,
                        fontStyle: FontStyle.italic,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                  ],

                  /// ========================================================
                  /// WORLD COMPLETE INFORMATION
                  /// ========================================================
                  if (_isLastLevel && !_isReplay)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        'World $_world Complete!',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: Colors.green.shade700,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),

                  /// ========================================================
                  /// REPLAY
                  /// ========================================================
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: _replayLevel,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text(
                        'Replay Level',
                        style: TextStyle(fontSize: 16),
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  /// ========================================================
                  /// LEVEL MAP
                  /// ========================================================
                  TextButton(
                    onPressed: _backToLevelMap,
                    child: Text(
                      'Back to Level Map',
                      style: TextStyle(color: theme.colorScheme.primary),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// ==========================================================================
  /// DISPOSE
  /// ==========================================================================

  @override
  void dispose() {
    _trophyController.dispose();
    super.dispose();
  }
}