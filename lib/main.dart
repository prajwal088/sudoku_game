import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'config/game_config.dart';
import 'core/theme/app_theme.dart';
import 'core/navigation.dart';
import 'screens/game_screen.dart';
import 'screens/home_screen.dart';
import 'screens/level_map_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/statistics_screen.dart';
import 'screens/world_map_screen.dart';
import 'services/progress_service.dart';
import 'services/user_service.dart';

/// ============================================================================
/// APPLICATION ENTRY POINT
/// ============================================================================

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  _configureErrorHandling();

  final StartupResult startupResult = await initializeApplication();

  runApp(
    SudokuApp(
      initialStartupResult: startupResult,
    ),
  );
}

/// ============================================================================
/// ERROR REPORTING
/// ============================================================================

/// Single place to forward errors to a crash-reporting backend.
///
/// Wire Firebase Crashlytics, Sentry, etc. into [report] when adopted.
/// Every error path in this file funnels through here.
abstract final class AppErrorReporter {
  static void report(
    Object error,
    StackTrace? stackTrace, {
    String? context,
    bool fatal = false,
  }) {
    debugPrint(
      '[${fatal ? 'FATAL' : 'ERROR'}]'
      '${context != null ? ' $context:' : ''} $error',
    );

    if (stackTrace != null) {
      debugPrintStack(stackTrace: stackTrace);
    }

    // TODO(production): forward to crash reporting, e.g.
    // FirebaseCrashlytics.instance.recordError(error, stackTrace, fatal: fatal);
  }
}

void _configureErrorHandling() {
  // Errors thrown inside the Flutter framework (build/layout/paint).
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);

    AppErrorReporter.report(
      details.exception,
      details.stack,
      context: 'Flutter framework',
    );
  };

  // Uncaught asynchronous / platform errors (futures, timers, isolates,
  // platform channels). FlutterError.onError does NOT see these.
  PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
    AppErrorReporter.report(
      error,
      stack,
      context: 'Uncaught async error',
      fatal: true,
    );

    // Returning true marks the error as handled.
    return true;
  };
}

/// ============================================================================
/// STARTUP
/// ============================================================================

/// Upper bound for startup. Prevents an indefinite hang on the native splash
/// if a service (e.g. storage) never completes.
const Duration _startupTimeout = Duration(seconds: 15);

/// Result of application startup.
///
/// The app is still rendered when initialization fails so the user sees a
/// controlled error screen with a retry option instead of a blank screen.
@immutable
class StartupResult {
  final Object? error;
  final StackTrace? stackTrace;

  const StartupResult.success()
      : error = null,
        stackTrace = null;

  const StartupResult.failure({
    required Object this.error,
    required this.stackTrace,
  });

  bool get isSuccessful => error == null;
}

/// Initializes system UI and all mandatory services.
///
/// NOTE: this may be called again from the "Try again" button. It assumes
/// `ProgressService.init()` and `UserService.init()` are idempotent (safe to
/// call twice). If they are not, guard them with an `_initialized` flag.
Future<StartupResult> initializeApplication() async {
  try {
    await _configureSystemUi();

    // Order matters:
    //  1. ProgressService - persisted progression must exist before any
    //     progression-dependent screen/service reads it.
    //  2. UserService - account/user data.
    await _initializeServices().timeout(_startupTimeout);

    return const StartupResult.success();
  } catch (error, stackTrace) {
    AppErrorReporter.report(
      error,
      stackTrace,
      context: 'Application startup',
      fatal: true,
    );

    return StartupResult.failure(
      error: error,
      stackTrace: stackTrace,
    );
  }
}

Future<void> _initializeServices() async {
  await ProgressService().init();
  await UserService().init();
}

Future<void> _configureSystemUi() async {
  await SystemChrome.setPreferredOrientations(
    const <DeviceOrientation>[
      DeviceOrientation.portraitUp,
    ],
  );

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark, // Android
      statusBarBrightness: Brightness.light, // iOS
    ),
  );
}

/// ============================================================================
/// ROOT APPLICATION
/// ============================================================================

class SudokuApp extends StatefulWidget {
  final StartupResult initialStartupResult;

  const SudokuApp({
    required this.initialStartupResult,
    super.key,
  });

  /// Global navigator key for navigation without a BuildContext.
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  @override
  State<SudokuApp> createState() => _SudokuAppState();
}

class _SudokuAppState extends State<SudokuApp> {
  late StartupResult _startupResult = widget.initialStartupResult;

  /// Re-runs startup. On success, replaces the error screen with home.
  Future<void> _retryStartup() async {
    final StartupResult result = await initializeApplication();

    if (!mounted) {
      return;
    }

    setState(() {
      _startupResult = result;
    });

    if (result.isSuccessful) {
      SudokuApp.navigatorKey.currentState?.pushNamedAndRemoveUntil(
        AppRoutes.home,
        (Route<dynamic> route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sudoku',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      navigatorKey: SudokuApp.navigatorKey,

      // Keep the board and controls usable with very large/small system font
      // sizes while still honouring accessibility settings within a range.
      builder: (BuildContext context, Widget? child) {
        final MediaQueryData mediaQuery = MediaQuery.of(context);

        return MediaQuery(
          data: mediaQuery.copyWith(
            textScaler: mediaQuery.textScaler.clamp(
              minScaleFactor: 0.85,
              maxScaleFactor: 1.3,
            ),
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },

      initialRoute: _startupResult.isSuccessful
          ? AppRoutes.home
          : AppRoutes.startupError,

      routes: <String, WidgetBuilder>{
        AppRoutes.home: (_) => const HomeScreen(),
        AppRoutes.worlds: (_) => const WorldMapScreen(),
        AppRoutes.settings: (_) => const SettingsScreen(),
        AppRoutes.statistics: (_) => const StatisticsScreen(),
        AppRoutes.startupError: (_) => StartupErrorScreen(
              error: _startupResult.error,
              onRetry: _retryStartup,
            ),
      },

      onGenerateRoute: _AppRouter.onGenerateRoute,
      onUnknownRoute: _AppRouter.onUnknownRoute,
    );
  }
}

/// ============================================================================
/// ROUTER
/// ============================================================================

abstract final class _AppRouter {
  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case AppRoutes.game:
        return _buildGameRoute(settings);

      case AppRoutes.levels:
        return _buildLevelMapRoute(settings);

      default:
        return _errorRoute(
          'Route "${settings.name ?? 'null'}" is not implemented.',
          settings: settings,
        );
    }
  }

  static Route<dynamic> onUnknownRoute(RouteSettings settings) {
    return _errorRoute(
      'Unknown route:\n${settings.name ?? 'null'}',
      settings: settings,
    );
  }

  /// Builds the GameScreen route using the global level number.
  static Route<dynamic> _buildGameRoute(RouteSettings settings) {
    final Object? arguments = settings.arguments;

    if (arguments is! GameArguments) {
      return _errorRoute(
        'Invalid game navigation arguments.\n\nExpected GameArguments.',
        settings: settings,
      );
    }

    final int levelNumber = arguments.levelNumber;

    if (!_isValidLevelNumber(levelNumber)) {
      return _errorRoute(
        'Invalid level number: $levelNumber.',
        settings: settings,
      );
    }

    return MaterialPageRoute<void>(
      settings: settings,
      builder: (_) => GameScreen(levelNumber: levelNumber),
    );
  }

  /// Builds the level map for a specific world.
  static Route<dynamic> _buildLevelMapRoute(RouteSettings settings) {
    final Object? arguments = settings.arguments;

    if (arguments is! int) {
      return _errorRoute(
        'Invalid world navigation arguments.',
        settings: settings,
      );
    }

    final int world = arguments;

    if (!_isValidWorldNumber(world)) {
      return _errorRoute(
        'Invalid world number: $world.',
        settings: settings,
      );
    }

    return MaterialPageRoute<void>(
      settings: settings,
      builder: (_) => LevelMapScreen(world: world),
    );
  }

  static bool _isValidLevelNumber(int levelNumber) {
    return levelNumber >= GameConfig.minimumLevel &&
        levelNumber <= GameConfig.totalLevels;
  }

  static bool _isValidWorldNumber(int world) {
    return world >= GameConfig.minimumWorld &&
        world <= GameConfig.totalWorlds;
  }

  static Route<dynamic> _errorRoute(
    String message, {
    RouteSettings? settings,
  }) {
    AppErrorReporter.report(
      message,
      null,
      context: 'Navigation',
    );

    return MaterialPageRoute<void>(
      settings: settings,
      builder: (BuildContext context) => _NavigationErrorScreen(
        message: message,
      ),
    );
  }
}

/// ============================================================================
/// NAVIGATION ERROR SCREEN
/// ============================================================================

class _NavigationErrorScreen extends StatelessWidget {
  final String message;

  const _NavigationErrorScreen({required this.message});

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Something went wrong'),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Icon(
                  Icons.error_outline,
                  color: theme.colorScheme.error,
                  size: 64,
                ),
                const SizedBox(height: 20),
                const Text(
                  'Unable to open this screen',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                // Raw route/argument details are only useful to developers.
                Text(
                  kDebugMode
                      ? message
                      : 'Please return to the home screen and try again.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 28),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(context).pushNamedAndRemoveUntil(
                      AppRoutes.home,
                      (Route<dynamic> route) => false,
                    );
                  },
                  icon: const Icon(Icons.home),
                  label: const Text('Return Home'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// ============================================================================
/// STARTUP ERROR SCREEN
/// ============================================================================

/// Shown when mandatory initialization fails, so the app never presents a
/// partially initialized game state.
class StartupErrorScreen extends StatefulWidget {
  final Object? error;

  /// Re-runs startup. The screen shows a progress state while it runs.
  final Future<void> Function() onRetry;

  const StartupErrorScreen({
    required this.error,
    required this.onRetry,
    super.key,
  });

  @override
  State<StartupErrorScreen> createState() => _StartupErrorScreenState();
}

class _StartupErrorScreenState extends State<StartupErrorScreen> {
  bool _isRetrying = false;

  Future<void> _handleRetry() async {
    if (_isRetrying) {
      return;
    }

    setState(() => _isRetrying = true);

    try {
      await widget.onRetry();
    } finally {
      // The screen is replaced on success; only reset if still on screen.
      if (mounted) {
        setState(() => _isRetrying = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return PopScope(
      // Nothing valid to go back to from a failed startup.
      canPop: false,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Sudoku'),
          automaticallyImplyLeading: false,
        ),
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Icon(
                    Icons.warning_amber_rounded,
                    size: 72,
                    color: theme.colorScheme.error,
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Unable to start Sudoku',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'The application could not load its required data. '
                    'Please try again. If the problem continues, restart '
                    'the app or free up some device storage.',
                    textAlign: TextAlign.center,
                  ),

                  // Development-only diagnostics.
                  if (kDebugMode && widget.error != null) ...<Widget>[
                    const SizedBox(height: 24),
                    ExpansionTile(
                      title: const Text('Technical details'),
                      children: <Widget>[
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: SelectableText(
                            widget.error.toString(),
                          ),
                        ),
                      ],
                    ),
                  ],

                  const SizedBox(height: 28),

                  ElevatedButton.icon(
                    onPressed: _isRetrying ? null : _handleRetry,
                    icon: _isRetrying
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.refresh),
                    label: Text(
                      _isRetrying ? 'Trying again…' : 'Try again',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}