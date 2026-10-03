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

  _configureFlutterErrorHandling();

  final StartupResult startupResult = await _initializeApplication();

  runApp(
    SudokuApp(
      startupResult: startupResult,
    ),
  );
}

/// ============================================================================
/// STARTUP RESULT
/// ============================================================================

/// Represents the result of application startup.
///
/// The application is still rendered when initialization fails so the user
/// receives a controlled error screen instead of a blank/crashed application.
@immutable
class StartupResult {
  final Object? error;
  final StackTrace? stackTrace;

  const StartupResult.success()
      : error = null,
        stackTrace = null;

  const StartupResult.failure({
    required this.error,
    required this.stackTrace,
  });

  bool get isSuccessful => error == null;
}

/// ============================================================================
/// APPLICATION INITIALIZATION
/// ============================================================================

Future<StartupResult> _initializeApplication() async {
  try {
    await _configureSystemUi();

    // ------------------------------------------------------------------------
    // SERVICE INITIALIZATION ORDER
    // ------------------------------------------------------------------------
    //
    // ProgressService must be initialized before any progression-dependent
    // screen/service accesses persisted progression.
    //
    // UserService is initialized afterwards because it represents user/account
    // data.
    //
    // Keep this ordering explicit.
    //

    await ProgressService().init();
    await UserService().init();

    return const StartupResult.success();
  } catch (error, stackTrace) {
    _logStartupFailure(
      error,
      stackTrace,
    );

    return StartupResult.failure(
      error: error,
      stackTrace: stackTrace,
    );
  }
}

/// ============================================================================
/// FLUTTER ERROR HANDLING
/// ============================================================================

void _configureFlutterErrorHandling() {
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);

    debugPrint(
      'Flutter framework error: ${details.exception}',
    );

    if (details.stack != null) {
      debugPrintStack(
        stackTrace: details.stack!,
      );
    }

    // ------------------------------------------------------------------------
    // PRODUCTION CRASH REPORTING
    // ------------------------------------------------------------------------
    //
    // Integrate Firebase Crashlytics, Sentry, or another crash-reporting
    // service here when the project adopts one.
    //
  };
}

/// Handles errors occurring outside the Flutter framework error pipeline.
void _logStartupFailure(
  Object error,
  StackTrace stackTrace,
) {
  debugPrint(
    'Application startup failed: $error',
  );

  debugPrintStack(
    stackTrace: stackTrace,
  );

  // Forward startup failures to the production crash-reporting service here.
}

/// ============================================================================
/// SYSTEM UI CONFIGURATION
/// ============================================================================

Future<void> _configureSystemUi() async {
  await SystemChrome.setPreferredOrientations(
    const <DeviceOrientation>[
      DeviceOrientation.portraitUp,
    ],
  );

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
    ),
  );
}

/// ============================================================================
/// ROOT APPLICATION
/// ============================================================================

class SudokuApp extends StatelessWidget {
  final StartupResult startupResult;

  const SudokuApp({
    required this.startupResult,
    super.key,
  });

  /// Global navigator key.
  ///
  /// Useful for application-level navigation where a BuildContext is not
  /// available.
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sudoku',
      debugShowCheckedModeBanner: false,

      // ----------------------------------------------------------------------
      // THEME
      // ----------------------------------------------------------------------

      theme: AppTheme.lightTheme,

      // ----------------------------------------------------------------------
      // NAVIGATION
      // ----------------------------------------------------------------------

      navigatorKey: navigatorKey,

      initialRoute: startupResult.isSuccessful
          ? AppRoutes.home
          : AppRoutes.startupError,

      routes: <String, WidgetBuilder>{
        AppRoutes.home: (_) => const HomeScreen(),
        AppRoutes.worlds: (_) => const WorldMapScreen(),
        AppRoutes.settings: (_) => const SettingsScreen(),
        AppRoutes.statistics: (_) => const StatisticsScreen(),
        AppRoutes.startupError: (_) => StartupErrorScreen(
              error: startupResult.error,
            ),
      },

      onGenerateRoute: _onGenerateRoute,

      onUnknownRoute: (RouteSettings settings) {
        return _errorRoute(
          'Unknown route:\n${settings.name ?? 'null'}',
        );
      },
    );
  }

  /// ========================================================================
  /// ROUTE GENERATOR
  /// ========================================================================

  static Route<dynamic> _onGenerateRoute(
    RouteSettings settings,
  ) {
    try {
      switch (settings.name) {
        case AppRoutes.game:
          return _buildGameRoute(settings);

        case AppRoutes.levels:
          return _buildLevelMapRoute(settings);

        default:
          return _errorRoute(
            'Route "${settings.name ?? 'null'}" is not implemented.',
          );
      }
    } catch (error, stackTrace) {
      debugPrint(
        'Navigation error for "${settings.name}": $error',
      );

      debugPrintStack(
        stackTrace: stackTrace,
      );

      return _errorRoute(
        'An error occurred while opening this screen.',
      );
    }
  }

  /// ========================================================================
  /// GAME ROUTE
  /// ========================================================================

  /// Builds the GameScreen route using the global level number.
  ///
  /// No world or local-level argument is accepted here.
  static Route<dynamic> _buildGameRoute(
    RouteSettings settings,
  ) {
    final Object? arguments = settings.arguments;

    if (arguments is! GameArguments) {
      return _errorRoute(
        'Invalid game navigation arguments.\n\n'
        'Expected GameArguments.',
      );
    }

    final int levelNumber = arguments.levelNumber;

    if (!_isValidLevelNumber(levelNumber)) {
      return _errorRoute(
        'Invalid level number: $levelNumber.',
      );
    }

    return MaterialPageRoute<void>(
      settings: settings,
      builder: (_) => GameScreen(
        levelNumber: levelNumber,
      ),
    );
  }

  /// ========================================================================
  /// LEVEL MAP ROUTE
  /// ========================================================================

  /// Builds the level map for a specific world.
  ///
  /// A world is intentionally used here because this screen represents a
  /// collection of levels.
  static Route<dynamic> _buildLevelMapRoute(
    RouteSettings settings,
  ) {
    final Object? arguments = settings.arguments;

    if (arguments is! int) {
      return _errorRoute(
        'Invalid world navigation arguments.',
      );
    }

    final int world = arguments;

    if (!_isValidWorldNumber(world)) {
      return _errorRoute(
        'Invalid world number: $world.',
      );
    }

    return MaterialPageRoute<void>(
      settings: settings,
      builder: (_) => LevelMapScreen(
        world: world,
      ),
    );
  }

  /// ========================================================================
  /// VALIDATION
  /// ========================================================================

  static bool _isValidLevelNumber(int levelNumber) {
    return levelNumber >= GameConfig.minimumLevel &&
        levelNumber <= GameConfig.totalLevels;
  }

  static bool _isValidWorldNumber(int world) {
    return world >= GameConfig.minimumWorld &&
        world <= GameConfig.totalWorlds;
  }

  /// ========================================================================
  /// ERROR ROUTE
  /// ========================================================================

  /// Displays a controlled error screen when navigation fails.
  static Route<dynamic> _errorRoute(
    String message,
  ) {
    return MaterialPageRoute<void>(
      builder: (BuildContext context) {
        return Scaffold(
          appBar: AppBar(
            title: const Text(
              'Something went wrong',
            ),
          ),
          body: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Icon(
                    Icons.error_outline,
                    color: Theme.of(context).colorScheme.error,
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
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 28),
                  ElevatedButton.icon(
                    onPressed: () {
                      navigatorKey.currentState
                          ?.pushNamedAndRemoveUntil(
                        AppRoutes.home,
                        (Route<dynamic> route) => false,
                      );
                    },
                    icon: const Icon(Icons.home),
                    label: const Text(
                      'Return Home',
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// ============================================================================
/// STARTUP ERROR SCREEN
/// ============================================================================

/// Controlled screen displayed when mandatory application initialization
/// fails.
///
/// This prevents the application from presenting a partially initialized
/// game state.
class StartupErrorScreen extends StatelessWidget {
  final Object? error;

  const StartupErrorScreen({
    required this.error,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final bool isDebugBuild =
        !const bool.fromEnvironment('dart.vm.product');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sudoku'),
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
                  color: Theme.of(context).colorScheme.error,
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
                  'The application could not initialize its required '
                  'services. Please restart the application and try again.',
                  textAlign: TextAlign.center,
                ),

                // ----------------------------------------------------------------
                // DEVELOPMENT DIAGNOSTIC
                // ----------------------------------------------------------------

                if (isDebugBuild && error != null) ...[
                  const SizedBox(height: 24),
                  ExpansionTile(
                    title: const Text(
                      'Technical details',
                    ),
                    children: <Widget>[
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: SelectableText(
                          error.toString(),
                        ),
                      ),
                    ],
                  ),
                ],

                const SizedBox(height: 28),

                ElevatedButton.icon(
                  onPressed: () {
                    // A full process restart is platform-specific and should
                    // not be attempted from Flutter application code.
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text(
                    'Restart App',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}