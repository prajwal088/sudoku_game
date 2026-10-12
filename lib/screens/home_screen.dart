import 'dart:async';

import 'package:flutter/material.dart';

import '../config/game_config.dart';
import '../core/navigation.dart';
import '../services/progress_service.dart';

/// ============================================================================
/// HomeScreen
/// ----------------------------------------------------------------------------
/// Main entry point of the Sudoku application.
///
/// Responsibilities:
/// - Display the player's next playable level.
/// - Continue directly to the next unlocked global level.
/// - Open the World Map.
/// - Open Statistics and Settings.
/// - Refresh automatically when progress changes.
///
/// ARCHITECTURE
/// ----------------------------------------------------------------------------
/// A level has ONE canonical identifier:
///
///     global levelNumber
///
/// World/local level information is derived by ProgressService when required.
///
/// Navigation to GameScreen always uses:
///
///     GameArguments(levelNumber: ...)
///
/// The world is NEVER passed as a GameArguments parameter.
/// ============================================================================

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  final ProgressService _progressService = ProgressService();

  StreamSubscription<void>? _progressSubscription;

  late final AnimationController _continueAnimationController;
  late final Animation<double> _continueScaleAnimation;

  /// The next playable global level.
  int _nextLevel = GameConfig.minimumLevel;

  /// True until the first load attempt finishes.
  bool _isLoading = true;

  /// True once progress has been read successfully at least once, so the
  /// button never advertises a level number it does not actually know.
  bool _hasLoaded = false;

  /// Blocks overlapping navigation (rapid taps on any button).
  bool _isNavigating = false;

  /// The in-flight load, shared by concurrent callers.
  Future<void>? _loadFuture;

  /// A load was requested while another was running; run once more after.
  bool _reloadQueued = false;

  // ==========================================================================
  // LIFECYCLE
  // ==========================================================================

  @override
  void initState() {
    super.initState();

    _continueAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _continueScaleAnimation = Tween<double>(
      begin: 0.96,
      end: 1.0,
    ).animate(
      CurvedAnimation(
        parent: _continueAnimationController,
        curve: Curves.easeInOut,
      ),
    );

    unawaited(_loadProgress());

    // Refresh the home screen whenever progression changes elsewhere.
    _progressSubscription = _progressService.onProgressUpdate.listen((_) {
      if (!mounted) {
        return;
      }

      unawaited(_loadProgress());
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // The pulsing animation starts here (MediaQuery is unavailable in
    // initState) and respects the system "reduce motion" setting.
    if (MediaQuery.disableAnimationsOf(context)) {
      _continueAnimationController
        ..stop()
        ..value = 1.0;
    } else if (!_continueAnimationController.isAnimating) {
      _continueAnimationController.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _progressSubscription?.cancel();
    _continueAnimationController.dispose();

    super.dispose();
  }

  // ==========================================================================
  // LOAD PROGRESS
  // ==========================================================================

  /// Loads the next playable level.
  ///
  /// A request that arrives while a load is running is not dropped and cannot
  /// be applied out of order: it is queued and one more load runs after the
  /// current one, so the screen always ends on the latest data.
  Future<void> _loadProgress() {
    final Future<void>? running = _loadFuture;

    if (running != null) {
      _reloadQueued = true;

      return running;
    }

    final Future<void> future = _runLoadLoop().whenComplete(() {
      _loadFuture = null;
    });

    _loadFuture = future;

    return future;
  }

  Future<void> _runLoadLoop() async {
    bool succeeded = true;

    do {
      _reloadQueued = false;

      succeeded = await _loadOnce();
    } while (_reloadQueued && succeeded && mounted);
  }

  /// Performs one load. Never throws. Returns false when it failed.
  Future<bool> _loadOnce() async {
    try {
      final int level = await _progressService.getNextUnlockedLevel();

      if (!mounted) {
        return false;
      }

      final int safeLevel = _clampInt(
        level,
        GameConfig.minimumLevel,
        GameConfig.totalLevels,
      );

      setState(() {
        _nextLevel = safeLevel;
        _hasLoaded = true;
        _isLoading = false;
      });

      return true;
    } catch (error, stackTrace) {
      debugPrint('HomeScreen: failed to load progress: $error');
      debugPrintStack(stackTrace: stackTrace);

      if (!mounted) {
        return false;
      }

      setState(() {
        _isLoading = false;
      });

      _showMessage(
        'Could not load your progress.',
        action: SnackBarAction(
          label: 'Retry',
          onPressed: () => unawaited(_loadProgress()),
        ),
      );

      return false;
    }
  }

  static int _clampInt(int value, int minimum, int maximum) {
    if (value < minimum) {
      return minimum;
    }

    if (value > maximum) {
      return maximum;
    }

    return value;
  }

  // ==========================================================================
  // NAVIGATION
  // ==========================================================================

  /// Runs [push] while blocking every other navigation button, shows
  /// [errorMessage] on failure, and optionally refreshes progress afterwards.
  Future<void> _navigate(
    Future<void> Function() push, {
    required String errorMessage,
    bool reloadAfter = false,
  }) async {
    if (!mounted || _isNavigating) {
      return;
    }

    setState(() {
      _isNavigating = true;
    });

    bool succeeded = false;

    try {
      await push();

      succeeded = true;
    } catch (error, stackTrace) {
      debugPrint('HomeScreen: navigation failed: $error');
      debugPrintStack(stackTrace: stackTrace);

      if (mounted) {
        _showMessage(errorMessage);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isNavigating = false;
        });
      }
    }

    // The player may have completed a level or unlocked a world.
    if (succeeded && reloadAfter && mounted) {
      unawaited(_loadProgress());
    }
  }

  /// CONTINUE
  ///
  /// Always asks ProgressService for the current source of truth rather than
  /// trusting the (possibly slightly stale) value shown on the button.
  Future<void> _continueToNextLevel() async {
    final int globalLevel = await _progressService.getNextUnlockedLevel();

    if (!mounted) {
      return;
    }

    // Safety validation.
    if (!GameConfig.isValidGlobalLevel(globalLevel)) {
      _showMessage('No playable level is currently available.');
      return;
    }

    // GameArguments intentionally contains ONLY the global level ID.
    await Navigator.pushNamed(
      context,
      AppRoutes.game,
      arguments: GameArguments(levelNumber: globalLevel),
    );
  }

  void _handleContinue() {
    if (_isLoading || _isNavigating) {
      return;
    }

    unawaited(
      _navigate(
        _continueToNextLevel,
        errorMessage: 'Could not open the level.',
        reloadAfter: true,
      ),
    );
  }

  void _openWorldMap() {
    unawaited(
      _navigate(
        () => Navigator.pushNamed(context, AppRoutes.worlds),
        errorMessage: 'Could not open the World Map.',
        reloadAfter: true,
      ),
    );
  }

  void _openStatistics() {
    unawaited(
      _navigate(
        () => Navigator.pushNamed(context, AppRoutes.statistics),
        errorMessage: 'Could not open Statistics.',
      ),
    );
  }

  void _openSettings() {
    unawaited(
      _navigate(
        () => Navigator.pushNamed(context, AppRoutes.settings),
        errorMessage: 'Could not open Settings.',
      ),
    );
  }

  // ==========================================================================
  // USER FEEDBACK
  // ==========================================================================

  void _showMessage(String message, {SnackBarAction? action}) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          action: action,
        ),
      );
  }

  // ==========================================================================
  // BUILD
  // ==========================================================================

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: 24,
              vertical: 32,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  // Game icon
                  ExcludeSemantics(
                    child: Icon(
                      Icons.grid_on,
                      size: 120,
                      color: theme.colorScheme.primary,
                    ),
                  ),

                  const SizedBox(height: 10),

                  // Title
                  Semantics(
                    header: true,
                    child: Text(
                      'Sudoku',
                      style: theme.textTheme.displaySmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),

                  const SizedBox(height: 8),

                  Text(
                    'Solve puzzles. Train your brain.',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 40),

                  // Continue button
                  ScaleTransition(
                    scale: _continueScaleAnimation,
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isLoading || _isNavigating
                            ? null
                            : _handleContinue,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 17),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(
                                // Never show a guessed level number when the
                                // real one could not be loaded.
                                _hasLoaded
                                    ? 'Continue • Level $_nextLevel'
                                    : 'Continue',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 15),

                  // World map
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: _isNavigating ? null : _openWorldMap,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: const Text(
                        'World Map',
                        style: TextStyle(fontSize: 18),
                      ),
                    ),
                  ),

                  const SizedBox(height: 30),

                  // Secondary options
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      _buildSecondaryAction(
                        context: context,
                        icon: Icons.bar_chart,
                        label: 'Statistics',
                        onPressed: _isNavigating ? null : _openStatistics,
                      ),
                      const SizedBox(width: 32),
                      _buildSecondaryAction(
                        context: context,
                        icon: Icons.settings,
                        label: 'Settings',
                        onPressed: _isNavigating ? null : _openSettings,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ==========================================================================
  // SECONDARY ACTION
  // ==========================================================================

  Widget _buildSecondaryAction({
    required BuildContext context,
    required IconData icon,
    required String label,
    required VoidCallback? onPressed,
  }) {
    final ThemeData theme = Theme.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        IconButton(
          tooltip: label,
          icon: Icon(icon, size: 28),
          onPressed: onPressed,
        ),
        // The IconButton tooltip already provides the accessible name; hiding
        // the visual label avoids screen readers announcing it twice.
        ExcludeSemantics(
          child: Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}