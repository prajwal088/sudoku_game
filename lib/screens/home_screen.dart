import 'dart:async';

import 'package:flutter/material.dart';

import '../main.dart';
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
  int _nextLevel = 1;

  bool _isLoading = true;
  bool _isNavigating = false;

  @override
  void initState() {
    super.initState();

    _continueAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _continueScaleAnimation = Tween<double>(begin: 0.96, end: 1.0).animate(
      CurvedAnimation(
        parent: _continueAnimationController,
        curve: Curves.easeInOut,
      ),
    );

    _continueAnimationController.repeat(reverse: true);

    _loadProgress();

    /// Refresh the home screen whenever progression changes elsewhere.
    _progressSubscription = _progressService.onProgressUpdate.listen((_) {
      if (!mounted) return;

      debugPrint('HomeScreen: progress update received. Refreshing...');

      _loadProgress();
    });
  }

  /// ==========================================================================
  /// LOAD PROGRESS
  /// ==========================================================================

  Future<void> _loadProgress() async {
    try {
      final int level = await _progressService.getNextUnlockedLevel();

      if (!mounted) return;

      setState(() {
        _nextLevel = level < 1 ? 1 : level;
        _isLoading = false;
      });
    } catch (error, stackTrace) {
      debugPrint('HomeScreen: failed to load progress: $error');

      debugPrintStack(stackTrace: stackTrace);

      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      _showMessage('Could not load your progress.');
    }
  }

  /// ==========================================================================
  /// CONTINUE
  /// ==========================================================================

  Future<void> _handleContinue() async {
    if (_isLoading || _isNavigating) return;

    setState(() {
      _isNavigating = true;
    });

    try {
      /// Always ask ProgressService for the current source of truth.
      final int globalLevel = await _progressService.getNextUnlockedLevel();

      if (!mounted) return;

      /// Safety validation.
      if (globalLevel < 1 || globalLevel > GameConfig.totalLevels) {
        _showMessage('No playable level is currently available.');
        return;
      }

      /// GameArguments intentionally contains ONLY the global level ID.
      await Navigator.pushNamed(
        context,
        AppRoutes.game,
        arguments: GameArguments(levelNumber: globalLevel),
      );

      if (!mounted) return;

      /// The player may have completed a level.
      /// Reload the displayed Continue level.
      await _loadProgress();
    } catch (error, stackTrace) {
      debugPrint('HomeScreen: failed to continue to level: $error');

      debugPrintStack(stackTrace: stackTrace);

      if (!mounted) return;

      _showMessage('Could not open the level.');
    } finally {
      if (!mounted) return;

      setState(() {
        _isNavigating = false;
      });
    }
  }

  /// ==========================================================================
  /// WORLD MAP
  /// ==========================================================================

  Future<void> _openWorldMap() async {
    if (_isNavigating) return;

    setState(() {
      _isNavigating = true;
    });

    try {
      await Navigator.pushNamed(context, AppRoutes.worlds);

      if (!mounted) return;

      /// Progress may have changed while the player was viewing the map.
      await _loadProgress();
    } catch (error, stackTrace) {
      debugPrint('HomeScreen: failed to open world map: $error');

      debugPrintStack(stackTrace: stackTrace);

      if (!mounted) return;

      _showMessage('Could not open the World Map.');
    } finally {
      if (!mounted) return;

      setState(() {
        _isNavigating = false;
      });
    }
  }

  /// ==========================================================================
  /// USER FEEDBACK
  /// ==========================================================================

  void _showMessage(String message) {
    if (!mounted) return;

    final messenger = ScaffoldMessenger.of(context);

    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
      );
  }

  /// ==========================================================================
  /// BUILD
  /// ==========================================================================

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  /// ==========================================================
                  /// GAME ICON
                  /// ==========================================================
                  Icon(
                    Icons.grid_on,
                    size: 120,
                    color: theme.colorScheme.primary,
                  ),

                  const SizedBox(height: 10),

                  /// ==========================================================
                  /// TITLE
                  /// ==========================================================
                  Text(
                    'Sudoku',
                    style: theme.textTheme.displaySmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
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

                  /// ==========================================================
                  /// CONTINUE BUTTON
                  /// ==========================================================
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
                                'Continue • Level $_nextLevel',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 15),

                  /// ==========================================================
                  /// WORLD MAP
                  /// ==========================================================
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

                  /// ==========================================================
                  /// SECONDARY OPTIONS
                  /// ==========================================================
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildSecondaryAction(
                        context: context,
                        icon: Icons.bar_chart,
                        label: 'Statistics',
                        onPressed: _isNavigating
                            ? null
                            : () {
                                Navigator.pushNamed(
                                  context,
                                  AppRoutes.statistics,
                                );
                              },
                      ),

                      const SizedBox(width: 32),

                      _buildSecondaryAction(
                        context: context,
                        icon: Icons.settings,
                        label: 'Settings',
                        onPressed: _isNavigating
                            ? null
                            : () {
                                Navigator.pushNamed(
                                  context,
                                  AppRoutes.settings,
                                );
                              },
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

  /// ==========================================================================
  /// SECONDARY ACTION
  /// ==========================================================================

  Widget _buildSecondaryAction({
    required BuildContext context,
    required IconData icon,
    required String label,
    required VoidCallback? onPressed,
  }) {
    final theme = Theme.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: label,
          icon: Icon(icon, size: 28),
          onPressed: onPressed,
        ),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  /// ==========================================================================
  /// DISPOSE
  /// ==========================================================================

  @override
  void dispose() {
    _progressSubscription?.cancel();
    _continueAnimationController.dispose();

    super.dispose();
  }
}
