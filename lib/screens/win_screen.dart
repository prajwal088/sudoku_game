import 'package:flutter/material.dart';

import '../config/game_config.dart';
import '../core/navigation.dart';
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
/// - Route definitions belong to navigation.dart.
/// - Static game configuration belongs to GameConfig.
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
  /// DERIVED DATA
  /// ==========================================================================

  /// Number of stars that can safely be displayed.
  int get _safeStars => widget.stars.clamp(0, 3);

  /// Whether the supplied level number is valid.
  bool get _isValidLevel =>
      widget.levelNumber >= GameConfig.minimumLevel &&
      widget.levelNumber <= GameConfig.totalLevels;

  /// World containing the current global level.
  int get _world =>
      _progressService.getWorldFromGlobal(widget.levelNumber);

  /// Local level number inside the current world.
  int get _levelInWorld =>
      _progressService.getLevelInWorld(widget.levelNumber);

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

    _trophyScale = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(
      CurvedAnimation(
        parent: _trophyController,
        curve: Curves.elasticOut,
      ),
    );

    _initialize();
  }

  /// ==========================================================================
  /// INITIALIZATION
  /// ==========================================================================

  Future<void> _initialize() async {
    if (!_isValidLevel) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
      return;
    }

    try {
      final int nextUnlockedLevel =
          await _progressService.getNextUnlockedLevel();

      if (!mounted) return;

      /// A completed level is a replay when a later level was already
      /// unlocked before this completion.
      ///
      /// Example:
      ///
      /// Current level = 3
      /// Next unlocked level = 6
      ///
      /// 3 + 1 < 6 => true
      final bool isReplay =
          widget.levelNumber + 1 < nextUnlockedLevel;

      final bool isLastLevelOfWorld =
          _levelInWorld == GameConfig.levelsPerWorld;

      setState(() {
        _isReplay = isReplay;
        _isLastLevel = isLastLevelOfWorld;
        _isLoading = false;
      });

      // Run presentation animation independently of initialization state.
      await _startAnimation();

      if (!mounted) return;

      /// Show the world-complete dialog only when:
      /// - this is the final level of the world,
      /// - this is not a replay,
      /// - another world exists.
      if (_isLastLevel && !_isReplay) {
        final int nextWorld = _world + 1;

        if (nextWorld <= GameConfig.totalWorlds) {
          await Future<void>.delayed(
            const Duration(milliseconds: 500),
          );

          if (!mounted) return;

          await _showWorldCompleteDialog();
        }
      }
    } catch (error, stackTrace) {
      debugPrint(
        'WinScreen: failed to initialize: $error',
      );
      debugPrintStack(
        stackTrace: stackTrace,
      );

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

    await Future<void>.delayed(
      const Duration(milliseconds: 250),
    );

    for (int index = 0; index < _safeStars; index++) {
      await Future<void>.delayed(
        const Duration(milliseconds: 300),
      );

      if (!mounted) return;

      setState(() {
        _visibleStars[index] = true;
      });
    }
  }

  /// ==========================================================================
  /// WORLD COMPLETE
  /// ==========================================================================

  Future<void> _showWorldCompleteDialog() async {
    if (!mounted || _worldCompleteDialogShown) {
      return;
    }

    final int nextWorld = _world + 1;

    /// The final configured world has no subsequent world to unlock.
    if (nextWorld > GameConfig.totalWorlds) {
      return;
    }

    _worldCompleteDialogShown = true;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
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

    if (nextLevel > GameConfig.totalLevels) {
      _showMessage(
        'You have completed all available levels!',
      );
      return;
    }

    Navigator.pushReplacementNamed(
      context,
      AppRoutes.game,
      arguments: GameArguments(
        levelNumber: nextLevel,
      ),
    );
  }

  /// Replays the current level.
  ///
  /// Only the global level number is required.
  void _replayLevel() {
    if (!_isValidLevel) {
      return;
    }

    Navigator.pushReplacementNamed(
      context,
      AppRoutes.game,
      arguments: GameArguments(
        levelNumber: widget.levelNumber,
      ),
    );
  }

  /// Returns to the level map for the current level's world.
  void _backToLevelMap() {
    if (!_isValidLevel) {
      return;
    }

    Navigator.pushReplacementNamed(
      context,
      AppRoutes.levels,
      arguments: _world,
    );
  }

  /// Opens a specific world.
  void _openWorld(int world) {
    if (!mounted) return;

    if (world < GameConfig.minimumWorld ||
        world > GameConfig.totalWorlds) {
      return;
    }

    Navigator.pushReplacementNamed(
      context,
      AppRoutes.levels,
      arguments: world,
    );
  }

  /// ==========================================================================
  /// USER FEEDBACK
  /// ==========================================================================

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
        ),
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
      child: const Icon(
        Icons.star,
        size: 46,
        color: Colors.amber,
      ),
    );
  }

  /// ==========================================================================
  /// PRIMARY ACTION
  /// ==========================================================================

  Widget _buildNextLevelButton() {
    return SizedBox(
      width: 320,
      child: ElevatedButton(
        onPressed: _openNextLevel,
        style: ElevatedButton.styleFrom(
          minimumSize: const Size.fromHeight(48),
          padding: const EdgeInsets.symmetric(
            vertical: 12,
            horizontal: 20,
          ),
          elevation: 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: const Text(
          'Next Level',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  /// ==========================================================================
  /// SECONDARY ACTION
  /// ==========================================================================

  Widget _buildReplayButton() {
    return SizedBox(
      width: 280,
      child: OutlinedButton(
        onPressed: _replayLevel,
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(44),
          padding: const EdgeInsets.symmetric(
            vertical: 10,
            horizontal: 20,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        child: const Text(
          'Replay Level',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
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
            padding: const EdgeInsets.symmetric(
              horizontal: 24,
              vertical: 20,
            ),
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
                    size: 112,
                    color: Colors.orange,
                  ),
                ),

                const SizedBox(height: 16),

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

                const SizedBox(height: 6),

                Text(
                  'Level ${widget.levelNumber}',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),

                const SizedBox(height: 20),

                /// ============================================================
                /// STARS
                /// ============================================================
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildStar(0),
                    const SizedBox(width: 8),
                    _buildStar(1),
                    const SizedBox(width: 8),
                    _buildStar(2),
                  ],
                ),

                const SizedBox(height: 20),

                /// ============================================================
                /// TIME
                /// ============================================================
                Text(
                  'Time: ${widget.time}',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),

                const SizedBox(height: 28),

                /// ============================================================
                /// ACTIONS
                /// ============================================================
                if (_isLoading)
                  const Padding(
                    padding: EdgeInsets.all(8),
                    child: CircularProgressIndicator(),
                  )
                else if (!_isValidLevel)
                  Text(
                    'This level is not available.',
                    style: theme.textTheme.bodyLarge,
                    textAlign: TextAlign.center,
                  )
                else ...[
                  /// ========================================================
                  /// NEXT LEVEL
                  /// ========================================================
                  if (!_isReplay && !_isLastLevel)
                    _buildNextLevelButton(),

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
                    const SizedBox(height: 14),
                  ],

                  /// ========================================================
                  /// WORLD COMPLETE INFORMATION
                  /// ========================================================
                  if (_isLastLevel && !_isReplay)
                    Padding(
                      padding: const EdgeInsets.only(
                        bottom: 14,
                      ),
                      child: Text(
                        _world == GameConfig.totalWorlds
                            ? 'All Worlds Complete!'
                            : 'World $_world Complete!',
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
                  _buildReplayButton(),

                  const SizedBox(height: 4),

                  /// ========================================================
                  /// LEVEL MAP
                  /// ========================================================
                  TextButton(
                    onPressed: _backToLevelMap,
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      minimumSize: const Size(0, 40),
                    ),
                    child: Text(
                      'Back to Level Map',
                      style: TextStyle(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w500,
                      ),
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