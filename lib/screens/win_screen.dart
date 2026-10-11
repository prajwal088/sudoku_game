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
/// - Handle world completion.
/// - Return to the appropriate level map.
/// - Replace obsolete navigation history when returning to a map.
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
/// Navigation architecture:
/// - Normal next-level navigation replaces WinScreen with GameScreen.
/// - Replay replaces WinScreen with GameScreen.
/// - Returning to a level map creates a fresh LevelMapScreen and removes
///   previous gameplay/map routes from the navigation stack.
/// - Completing the last level of a world does not show "Next Level".
/// - Completing a world presents a dedicated world-complete state.
/// - Completing the final world presents an all-worlds-complete state.
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

  /// Prevents multiple navigation operations caused by rapid taps.
  bool _isNavigating = false;

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

  /// Whether this completion represents a genuine world completion.
  ///
  /// A replay of the final level must not trigger world-complete behavior.
  bool get _isWorldComplete => _isLastLevel && !_isReplay;

  /// Whether the completed world is the final configured world.
  bool get _isFinalWorld => _world == GameConfig.totalWorlds;

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
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
      });

      return;
    }

    try {
      final int nextUnlockedLevel =
          await _progressService.getNextUnlockedLevel();

      if (!mounted) {
        return;
      }

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

      /// Run presentation animation independently of navigation state.
      await _startAnimation();
    } catch (error, stackTrace) {
      debugPrint(
        'WinScreen: failed to initialize: $error',
      );

      debugPrintStack(
        stackTrace: stackTrace,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
      });
    }
  }

  /// ==========================================================================
  /// ANIMATIONS
  /// ==========================================================================

  Future<void> _startAnimation() async {
    if (!mounted) {
      return;
    }

    await _trophyController.forward();

    if (!mounted) {
      return;
    }

    await Future<void>.delayed(
      const Duration(milliseconds: 250),
    );

    for (int index = 0; index < _safeStars; index++) {
      await Future<void>.delayed(
        const Duration(milliseconds: 300),
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _visibleStars[index] = true;
      });
    }
  }

  /// ==========================================================================
  /// NAVIGATION
  /// ==========================================================================

  /// Opens the next global level.
  ///
  /// The next level is identified only by its global level number.
  ///
  /// This is only available when:
  /// - the level is valid,
  /// - this is not a replay,
  /// - this is not the last level of the world.
  void _openNextLevel() {
    if (!mounted ||
        _isLoading ||
        _isReplay ||
        _isLastLevel ||
        _isNavigating) {
      return;
    }

    final int nextLevel = widget.levelNumber + 1;

    if (nextLevel > GameConfig.totalLevels) {
      _showMessage(
        'You have completed all available levels!',
      );

      return;
    }

    _isNavigating = true;

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
    if (!mounted ||
        !_isValidLevel ||
        _isNavigating) {
      return;
    }

    _isNavigating = true;

    Navigator.pushReplacementNamed(
      context,
      AppRoutes.game,
      arguments: GameArguments(
        levelNumber: widget.levelNumber,
      ),
    );
  }

  /// Replaces the entire current navigation stack with a fresh level map.
  ///
  /// This is intentionally different from pushReplacementNamed().
  ///
  /// Example:
  ///
  /// Home
  ///   -> Level Map
  ///   -> Game
  ///   -> Win
  ///
  /// becomes:
  ///
  /// Level Map
  ///
  /// The previous map, GameScreen, WinScreen, and any intermediate routes
  /// are removed from the navigation stack.
  void _replaceWithLevelMap(int world) {
    if (!mounted ||
        _isNavigating ||
        !_isValidWorldNumber(world)) {
      return;
    }

    _isNavigating = true;

    Navigator.pushNamedAndRemoveUntil(
      context,
      AppRoutes.levels,
      (Route<dynamic> route) => false,
      arguments: world,
    );
  }

  /// Returns to the current world's level map.
  ///
  /// A fresh LevelMapScreen is created and all previous routes are removed.
  void _backToLevelMap() {
    if (!_isValidLevel) {
      return;
    }

    _replaceWithLevelMap(_world);
  }

  /// Continues after completing a world.
  ///
  /// For a normal world:
  ///   World 1 complete -> World 2 map
  ///
  /// For the final world:
  ///   Final world complete -> current world map
  void _continueFromWorldComplete() {
    if (!mounted ||
        !_isWorldComplete ||
        _isNavigating) {
      return;
    }

    if (_isFinalWorld) {
      _replaceWithLevelMap(_world);
      return;
    }

    _replaceWithLevelMap(_world + 1);
  }

  /// ==========================================================================
  /// VALIDATION
  /// ==========================================================================

  bool _isValidWorldNumber(int world) {
    return world >= GameConfig.minimumWorld &&
        world <= GameConfig.totalWorlds;
  }

  /// ==========================================================================
  /// USER FEEDBACK
  /// ==========================================================================

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }

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
  /// RESPONSIVE BUTTON WIDTH
  /// ==========================================================================

  double _buttonWidth(BuildContext context) {
    final double availableWidth =
        MediaQuery.sizeOf(context).width - 48;

    return availableWidth.clamp(0.0, 320.0);
  }

  /// ==========================================================================
  /// PRIMARY ACTION
  /// ==========================================================================

  Widget _buildNextLevelButton() {
    return SizedBox(
      width: _buttonWidth(context),
      child: ElevatedButton(
        onPressed: _isNavigating ? null : _openNextLevel,
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
  /// REPLAY BUTTON
  /// ==========================================================================

  Widget _buildReplayButton() {
    return SizedBox(
      width: _buttonWidth(context),
      child: OutlinedButton(
        onPressed: _isNavigating ? null : _replayLevel,
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(48),
          padding: const EdgeInsets.symmetric(
            vertical: 12,
            horizontal: 20,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
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
  /// WORLD COMPLETE BUTTON
  /// ==========================================================================

  Widget _buildWorldCompleteButton() {
    final String label =
        _isFinalWorld ? 'Back to Level Map' : 'Continue';

    return SizedBox(
      width: _buttonWidth(context),
      child: ElevatedButton(
        onPressed: _isNavigating
            ? null
            : _continueFromWorldComplete,
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
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  /// ==========================================================================
  /// LEVEL MAP BUTTON
  /// ==========================================================================

  Widget _buildLevelMapButton(ThemeData theme) {
    return TextButton(
      onPressed: _isNavigating ? null : _backToLevelMap,
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
                  _isWorldComplete
                      ? (_isFinalWorld
                          ? 'All Worlds Complete!'
                          : 'World Complete!')
                      : 'Level Complete!',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 6),

                /// ============================================================
                /// LEVEL / WORLD SUBTITLE
                /// ============================================================
                if (_isWorldComplete)
                  Text(
                    _isFinalWorld
                        ? 'World $_world completed!'
                        : 'World $_world completed!',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  )
                else
                  Text(
                    'Level ${widget.levelNumber}',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
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
                  textAlign: TextAlign.center,
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
                else if (_isWorldComplete) ...[
                  /// ========================================================
                  /// WORLD COMPLETE MESSAGE
                  /// ========================================================
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                    ),
                    child: Text(
                      _isFinalWorld
                          ? 'Congratulations! You have completed '
                              'all available worlds.'
                          : 'Congratulations! World $_world is complete '
                              'and World ${_world + 1} is now unlocked.',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: theme.colorScheme.onSurface,
                        fontWeight: FontWeight.w500,
                        height: 1.4,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),

                  const SizedBox(height: 24),

                  /// ========================================================
                  /// WORLD COMPLETE PRIMARY ACTION
                  /// ========================================================
                  _buildWorldCompleteButton(),

                  const SizedBox(height: 12),

                  /// ========================================================
                  /// REPLAY
                  /// ========================================================
                  _buildReplayButton(),
                ] else ...[
                  /// ========================================================
                  /// NEXT LEVEL
                  /// ========================================================
                  if (!_isReplay) ...[
                    _buildNextLevelButton(),
                    const SizedBox(height: 16),
                  ],

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
                  /// REPLAY
                  /// ========================================================
                  _buildReplayButton(),

                  const SizedBox(height: 12),

                  /// ========================================================
                  /// LEVEL MAP
                  /// ========================================================
                  _buildLevelMapButton(theme),
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