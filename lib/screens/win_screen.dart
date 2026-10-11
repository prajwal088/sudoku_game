import 'dart:async';

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
/// - GameScreen is responsible for saving progress BEFORE opening this screen.
///   Replay detection below relies on that ordering.
/// - ProgressService is the source of truth for progression.
/// - WinScreen is responsible for presentation and navigation.
///
/// Level architecture:
/// - A level has ONE identity: [levelNumber].
/// - World and local level numbers are derived from [levelNumber].
///
/// Navigation architecture:
/// - Next level / replay replace WinScreen with GameScreen.
/// - Returning to a level map creates a fresh LevelMapScreen and removes
///   previous gameplay/map routes from the navigation stack.
/// - The system back button behaves like "Back to Level Map".
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
  // --------------------------------------------------------------------------
  // CONSTANTS
  // --------------------------------------------------------------------------

  static const int _maxStars = 3;

  // Animation timeline (milliseconds). Matches the original sequencing:
  // trophy pop -> short pause -> stars appear one by one.
  static const int _trophyMs = 700;
  static const int _pauseMs = 250;
  static const int _starDelayMs = 300;
  static const int _starMs = 400;

  static const Color _backgroundColor = Color(0xFFE8F5E9); // green.shade50

  final ProgressService _progressService = ProgressService();

  // --------------------------------------------------------------------------
  // ANIMATION
  // --------------------------------------------------------------------------

  /// One controller drives the entire celebration (trophy + stars), so no
  /// per-star setState() / whole-screen rebuilds are needed.
  late final AnimationController _celebrationController;
  late final Animation<double> _trophyScale;
  late final List<Animation<double>> _starScales;

  bool _animationStarted = false;

  // --------------------------------------------------------------------------
  // DERIVED, IMMUTABLE DATA (computed once)
  // --------------------------------------------------------------------------

  late final int _world;
  late final int _levelInWorld;
  late final bool _isLastLevel;

  // --------------------------------------------------------------------------
  // STATE
  // --------------------------------------------------------------------------

  bool _isLoading = true;
  bool _isReplay = false;

  /// Prevents multiple navigation operations caused by rapid taps and
  /// disables the action buttons while navigating.
  bool _isNavigating = false;

  // ==========================================================================
  // DERIVED DATA
  // ==========================================================================

  /// Number of stars that can safely be displayed.
  int get _safeStars => widget.stars.clamp(0, _maxStars);

  /// Whether the supplied level number is valid.
  bool get _isValidLevel =>
      widget.levelNumber >= GameConfig.minimumLevel &&
      widget.levelNumber <= GameConfig.totalLevels;

  /// Whether this completion represents a genuine world completion.
  ///
  /// A replay of the final level must not trigger world-complete behavior.
  bool get _isWorldComplete => _isLastLevel && !_isReplay;

  /// Whether the completed world is the final configured world.
  bool get _isFinalWorld => _world == GameConfig.totalWorlds;

  String get _title {
    if (!_isWorldComplete) {
      return 'Level Complete!';
    }

    return _isFinalWorld ? 'All Worlds Complete!' : 'World Complete!';
  }

  String get _subtitle =>
      _isWorldComplete ? 'World $_world completed!' : 'Level ${widget.levelNumber}';

  String get _worldCompleteMessage => _isFinalWorld
      ? 'Congratulations! You have completed all available worlds.'
      : 'Congratulations! World $_world is complete '
          'and World ${_world + 1} is now unlocked.';

  // ==========================================================================
  // LIFECYCLE
  // ==========================================================================

  @override
  void initState() {
    super.initState();

    _setUpLevelData();
    _setUpAnimations();

    if (_isValidLevel) {
      unawaited(_loadReplayState());
    } else {
      _isLoading = false;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // MediaQuery is not available in initState, so the animation starts here
    // (once). Respect the system "reduce motion" accessibility setting.
    if (_animationStarted) {
      return;
    }

    _animationStarted = true;

    if (MediaQuery.disableAnimationsOf(context)) {
      _celebrationController.value = 1.0;
    } else {
      unawaited(_celebrationController.forward());
    }
  }

  @override
  void dispose() {
    _celebrationController.dispose();
    super.dispose();
  }

  // ==========================================================================
  // SETUP
  // ==========================================================================

  /// Derives world / local level once instead of calling the service on
  /// every build. Everything here is synchronous, so the layout (title,
  /// buttons) is correct from the very first frame.
  void _setUpLevelData() {
    if (_isValidLevel) {
      _world = _progressService.getWorldFromGlobal(widget.levelNumber);
      _levelInWorld = _progressService.getLevelInWorld(widget.levelNumber);
      _isLastLevel = _levelInWorld == GameConfig.levelsPerWorld;
    } else {
      _world = 0;
      _levelInWorld = 0;
      _isLastLevel = false;
    }
  }

  void _setUpAnimations() {
    final int stars = _safeStars;

    final int starsBeginMs = _trophyMs + _pauseMs + _starDelayMs;

    final int totalMs = stars == 0
        ? _trophyMs
        : starsBeginMs + (stars - 1) * _starDelayMs + _starMs;

    _celebrationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: totalMs),
    );

    Animation<double> segment(int beginMs, int endMs) {
      return CurveTween(
        curve: Interval(
          beginMs / totalMs,
          endMs / totalMs,
          curve: Curves.elasticOut,
        ),
      ).animate(_celebrationController);
    }

    _trophyScale = segment(0, _trophyMs);

    _starScales = List<Animation<double>>.generate(stars, (int index) {
      final int begin = starsBeginMs + index * _starDelayMs;
      return segment(begin, begin + _starMs);
    });
  }

  // ==========================================================================
  // PROGRESS
  // ==========================================================================

  /// Determines whether this completion is a replay.
  ///
  /// A completed level is a replay when a later level was already unlocked
  /// before this completion.
  ///
  /// Example: current level = 3, next unlocked level = 6
  /// 3 + 1 < 6 => replay.
  Future<void> _loadReplayState() async {
    try {
      final int nextUnlockedLevel =
          await _progressService.getNextUnlockedLevel();

      if (!mounted) {
        return;
      }

      setState(() {
        _isReplay = widget.levelNumber + 1 < nextUnlockedLevel;
        _isLoading = false;
      });
    } catch (error, stackTrace) {
      debugPrint('WinScreen: failed to load progress: $error');
      debugPrintStack(stackTrace: stackTrace);

      if (!mounted) {
        return;
      }

      // Fall back to "not a replay" so the player is never stuck here.
      setState(() {
        _isLoading = false;
      });
    }
  }

  // ==========================================================================
  // NAVIGATION
  // ==========================================================================

  /// Runs [action] at most once and disables the buttons while navigating.
  void _navigate(VoidCallback action) {
    if (!mounted || _isNavigating) {
      return;
    }

    setState(() {
      _isNavigating = true;
    });

    action();
  }

  /// Opens the next global level.
  ///
  /// Only available when the level is valid, this is not a replay and this
  /// is not the last level of the world.
  void _openNextLevel() {
    if (_isLoading || _isReplay || _isLastLevel || !_isValidLevel) {
      return;
    }

    final int nextLevel = widget.levelNumber + 1;

    if (nextLevel > GameConfig.totalLevels) {
      _showMessage('You have completed all available levels!');
      return;
    }

    _navigate(() {
      unawaited(
        Navigator.pushReplacementNamed(
          context,
          AppRoutes.game,
          arguments: GameArguments(levelNumber: nextLevel),
        ),
      );
    });
  }

  /// Replays the current level.
  void _replayLevel() {
    if (!_isValidLevel) {
      return;
    }

    _navigate(() {
      unawaited(
        Navigator.pushReplacementNamed(
          context,
          AppRoutes.game,
          arguments: GameArguments(levelNumber: widget.levelNumber),
        ),
      );
    });
  }

  /// Replaces the entire navigation stack with a fresh level map.
  ///
  /// Example: Home -> Level Map -> Game -> Win  becomes  Level Map.
  void _replaceWithLevelMap(int world) {
    if (!_isValidWorldNumber(world)) {
      return;
    }

    _navigate(() {
      unawaited(
        Navigator.pushNamedAndRemoveUntil(
          context,
          AppRoutes.levels,
          (Route<dynamic> route) => false,
          arguments: world,
        ),
      );
    });
  }

  /// Returns to the current world's level map.
  void _backToLevelMap() {
    if (!_isValidLevel) {
      return;
    }

    _replaceWithLevelMap(_world);
  }

  /// Continues after completing a world.
  ///
  /// Normal world:  World N complete -> World N + 1 map.
  /// Final world:   Final world complete -> current world map.
  void _continueFromWorldComplete() {
    if (!_isWorldComplete) {
      return;
    }

    _replaceWithLevelMap(_isFinalWorld ? _world : _world + 1);
  }

  /// Fallback for an invalid level: clear the stack and go home.
  void _goHome() {
    _navigate(() {
      unawaited(
        Navigator.pushNamedAndRemoveUntil(
          context,
          AppRoutes.home,
          (Route<dynamic> route) => false,
        ),
      );
    });
  }

  // ==========================================================================
  // VALIDATION
  // ==========================================================================

  bool _isValidWorldNumber(int world) {
    return world >= GameConfig.minimumWorld &&
        world <= GameConfig.totalWorlds;
  }

  // ==========================================================================
  // USER FEEDBACK
  // ==========================================================================

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

  // ==========================================================================
  // BUILD HELPERS
  // ==========================================================================

  Widget _buildStars() {
    return Semantics(
      container: true,
      label: '$_safeStars out of $_maxStars stars',
      child: ExcludeSemantics(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            for (int index = 0; index < _maxStars; index++) ...<Widget>[
              if (index > 0) const SizedBox(width: 8),
              _StarSlot(
                scale: index < _starScales.length ? _starScales[index] : null,
              ),
            ],
          ],
        ),
      ),
    );
  }

  List<Widget> _buildActions(ThemeData theme) {
    if (_isLoading) {
      return const <Widget>[
        Padding(
          padding: EdgeInsets.all(8),
          child: CircularProgressIndicator(),
        ),
      ];
    }

    if (!_isValidLevel) {
      return <Widget>[
        Text(
          'This level is not available.',
          style: theme.textTheme.bodyLarge,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        TextButton(
          onPressed: _isNavigating ? null : _goHome,
          child: const Text('Go Home'),
        ),
      ];
    }

    final VoidCallback? onReplay = _isNavigating ? null : _replayLevel;

    if (_isWorldComplete) {
      return <Widget>[
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            _worldCompleteMessage,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurface,
              fontWeight: FontWeight.w500,
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 24),
        _ActionButton.primary(
          label: _isFinalWorld ? 'Back to Level Map' : 'Continue',
          onPressed: _isNavigating ? null : _continueFromWorldComplete,
        ),
        const SizedBox(height: 12),
        _ActionButton.secondary(
          label: 'Replay Level',
          onPressed: onReplay,
        ),
      ];
    }

    return <Widget>[
      if (_isReplay) ...<Widget>[
        Text(
          'Replaying Level',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: Colors.blueGrey,
            fontStyle: FontStyle.italic,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 14),
      ] else ...<Widget>[
        _ActionButton.primary(
          label: 'Next Level',
          onPressed: _isNavigating ? null : _openNextLevel,
        ),
        const SizedBox(height: 16),
      ],
      _ActionButton.secondary(
        label: 'Replay Level',
        onPressed: onReplay,
      ),
      const SizedBox(height: 12),
      TextButton(
        onPressed: _isNavigating ? null : _backToLevelMap,
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
    ];
  }

  // ==========================================================================
  // BUILD
  // ==========================================================================

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return PopScope(
      // For a valid level, the system back gesture goes to a fresh level map
      // (same as the on-screen button) instead of popping to a stale route.
      canPop: !_isValidLevel,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (!didPop) {
          _backToLevelMap();
        }
      },
      child: Scaffold(
        backgroundColor: _backgroundColor,
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 20,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  // Trophy
                  ExcludeSemantics(
                    child: ScaleTransition(
                      scale: _trophyScale,
                      child: const Icon(
                        Icons.emoji_events,
                        size: 112,
                        color: Colors.orange,
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Title
                  Semantics(
                    header: true,
                    child: Text(
                      _title,
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),

                  const SizedBox(height: 6),

                  // Level / world subtitle
                  Text(
                    _subtitle,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 20),

                  // Stars
                  _buildStars(),

                  const SizedBox(height: 20),

                  // Time
                  Text(
                    'Time: ${widget.time}',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 28),

                  // Actions
                  ..._buildActions(theme),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// ============================================================================
/// STAR SLOT
/// ----------------------------------------------------------------------------
/// An outlined placeholder star. When [scale] is provided (the star was
/// earned) a filled star pops in on top of it; otherwise only the outline
/// remains so the player can see how many stars were possible.
/// ============================================================================

class _StarSlot extends StatelessWidget {
  final Animation<double>? scale;

  const _StarSlot({required this.scale});

  static const double _size = 46;

  @override
  Widget build(BuildContext context) {
    final Animation<double>? animation = scale;

    return Stack(
      alignment: Alignment.center,
      children: <Widget>[
        Icon(
          Icons.star_border,
          size: _size,
          color: Colors.amber.shade200,
        ),
        if (animation != null)
          ScaleTransition(
            scale: animation,
            child: const Icon(
              Icons.star,
              size: _size,
              color: Colors.amber,
            ),
          ),
      ],
    );
  }
}

/// ============================================================================
/// ACTION BUTTON
/// ----------------------------------------------------------------------------
/// Shared full-width button (max 320 logical pixels) used for the primary and
/// secondary actions. Replaces the per-build MediaQuery width calculation and
/// the duplicated button styling.
/// ============================================================================

class _ActionButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool _isPrimary;

  const _ActionButton.primary({
    required this.label,
    required this.onPressed,
  }) : _isPrimary = true;

  const _ActionButton.secondary({
    required this.label,
    required this.onPressed,
  }) : _isPrimary = false;

  static const EdgeInsets _padding = EdgeInsets.symmetric(
    vertical: 12,
    horizontal: 20,
  );

  static final RoundedRectangleBorder _shape = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(12),
  );

  @override
  Widget build(BuildContext context) {
    final Widget button = _isPrimary
        ? ElevatedButton(
            onPressed: onPressed,
            style: ElevatedButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
              padding: _padding,
              elevation: 1,
              shape: _shape,
            ),
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          )
        : OutlinedButton(
            onPressed: onPressed,
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
              padding: _padding,
              shape: _shape,
            ),
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
          );

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 320),
      child: SizedBox(
        width: double.infinity,
        child: button,
      ),
    );
  }
}