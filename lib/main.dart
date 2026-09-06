import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'core/theme/app_theme.dart';
import 'screens/game_screen.dart';
import 'screens/home_screen.dart';
import 'screens/level_map_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/statistics_screen.dart';
import 'screens/world_map_screen.dart';
import 'services/progress_service.dart';
import 'services/user_service.dart';

/// ============================================================================
/// ROUTE ARGUMENT MODELS
/// ============================================================================

/// Arguments required to open a Sudoku game.
///
/// A level has ONE identity throughout the application:
///
///     levelNumber
///
/// The world and local level number are derived from this value when needed.
///
/// Example:
///
/// Navigator.pushNamed(
///   context,
///   AppRoutes.game,
///   arguments: GameArguments(levelNumber: 26),
/// );
class GameArguments {
  final int levelNumber;

  const GameArguments({required this.levelNumber});
}

/// ============================================================================
/// APPLICATION CONFIGURATION
/// ============================================================================

/// Central game configuration.
///
/// Keep values that define the structure of the game here rather than
/// scattering magic numbers across individual screens.
class GameConfig {
  const GameConfig._();

  static const int levelsPerWorld = ProgressService.levelsPerWorld;
  static const int totalWorlds = 10;

  static const int totalLevels = levelsPerWorld * totalWorlds;
}

/// ============================================================================
/// APPLICATION ENTRY POINT
/// ============================================================================

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  _configureFlutterErrorHandling();
  await _configureSystemUi();
  await _initializeServices();

  runApp(const SudokuApp());
}

/// ============================================================================
/// STARTUP CONFIGURATION
/// ============================================================================

/// Configures framework-level Flutter error handling.
///
/// In production, this is the appropriate place to forward errors to a
/// crash-reporting service such as Firebase Crashlytics or Sentry.
void _configureFlutterErrorHandling() {
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);

    debugPrint('Flutter error: ${details.exception}');

    if (details.stack != null) {
      debugPrintStack(stackTrace: details.stack!);
    }

    // TODO:
    // Forward [details.exception] and [details.stack] to your crash
    // reporting service in production.
  };
}

/// Configures orientation and system UI.
///
/// The game currently supports portrait orientation only.
Future<void> _configureSystemUi() async {
  try {
    await SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.portraitUp,
    ]);

    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
    );
  } catch (e, stackTrace) {
    debugPrint('System UI initialization failed: $e');

    debugPrintStack(stackTrace: stackTrace);
  }
}

/// Initializes application services required before the UI starts.
///
/// UserService currently needs initialization before screens access user data.
Future<void> _initializeServices() async {
  try {
    await UserService().init();
  } catch (e, stackTrace) {
    debugPrint('UserService initialization failed: $e');

    debugPrintStack(stackTrace: stackTrace);

    // The application is allowed to start.
    //
    // Individual screens/services should handle unavailable user data safely.
  }
}

/// ============================================================================
/// ROUTES
/// ============================================================================

/// Centralized application route names.
///
/// Avoid hard-coded route strings throughout the application.
class AppRoutes {
  const AppRoutes._();

  static const String home = '/';
  static const String worlds = '/worlds';
  static const String levels = '/levels';
  static const String game = '/game';
  static const String settings = '/settings';
  static const String statistics = '/statistics';
}

/// ============================================================================
/// ROOT APPLICATION
/// ============================================================================

class SudokuApp extends StatelessWidget {
  const SudokuApp({super.key});

  /// Global navigator key.
  ///
  /// Useful when navigation is required from application-level code where a
  /// BuildContext is not available.
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sudoku',
      debugShowCheckedModeBanner: false,

      /// ----------------------------------------------------------------------
      /// THEME
      /// ----------------------------------------------------------------------
      theme: AppTheme.lightTheme,

      /// ----------------------------------------------------------------------
      /// NAVIGATION
      /// ----------------------------------------------------------------------
      navigatorKey: navigatorKey,

      initialRoute: AppRoutes.home,

      routes: {
        AppRoutes.home: (_) => const HomeScreen(),
        AppRoutes.worlds: (_) => const WorldMapScreen(),
        AppRoutes.settings: (_) => const SettingsScreen(),
        AppRoutes.statistics: (_) => const StatisticsScreen(),
      },

      onGenerateRoute: _onGenerateRoute,

      onUnknownRoute: (settings) {
        return _errorRoute('Unknown route:\n${settings.name ?? 'null'}');
      },
    );
  }

  /// ==========================================================================
  /// ROUTE GENERATOR
  /// ==========================================================================

  static Route<dynamic> _onGenerateRoute(RouteSettings settings) {
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
    } catch (e, stackTrace) {
      debugPrint('Navigation error for "${settings.name}": $e');

      debugPrintStack(stackTrace: stackTrace);

      return _errorRoute('An error occurred while opening this screen.');
    }
  }

  /// ==========================================================================
  /// GAME ROUTE
  /// ==========================================================================

  /// Builds the GameScreen route using ONE level identifier.
  ///
  /// The world is deliberately not passed through navigation arguments.
  /// GameScreen can derive it from [levelNumber].
  static Route<dynamic> _buildGameRoute(RouteSettings settings) {
    final arguments = settings.arguments;

    if (arguments is! GameArguments) {
      return _errorRoute(
        'Invalid game navigation arguments.\n\n'
        'Expected GameArguments.',
      );
    }

    final int levelNumber = arguments.levelNumber;

    if (levelNumber < 1 || levelNumber > GameConfig.totalLevels) {
      return _errorRoute('Invalid level number: $levelNumber.');
    }

    return MaterialPageRoute(
      settings: settings,
      builder: (_) {
        return GameScreen(levelNumber: levelNumber);
      },
    );
  }

  /// ==========================================================================
  /// LEVEL MAP ROUTE
  /// ==========================================================================

  /// Builds the level map for a specific world.
  ///
  /// The LevelMapScreen still works with a world because it represents a
  /// collection of levels. Individual levels themselves use only global
  /// levelNumber.
  static Route<dynamic> _buildLevelMapRoute(RouteSettings settings) {
    final arguments = settings.arguments;

    if (arguments is! int) {
      return _errorRoute('Invalid world navigation arguments.');
    }

    final int world = arguments;

    if (world < 1 || world > GameConfig.totalWorlds) {
      return _errorRoute('Invalid world number: $world.');
    }

    return MaterialPageRoute(
      settings: settings,
      builder: (_) {
        return LevelMapScreen(world: world);
      },
    );
  }

  /// ==========================================================================
  /// ERROR ROUTE
  /// ==========================================================================

  /// Displays a controlled error screen when navigation arguments are invalid
  /// or an unknown route is requested.
  static Route<dynamic> _errorRoute(String message) {
    return MaterialPageRoute(
      builder: (context) {
        return Scaffold(
          appBar: AppBar(title: const Text('Something went wrong')),
          body: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    color: Theme.of(context).colorScheme.error,
                    size: 64,
                  ),

                  const SizedBox(height: 20),

                  const Text(
                    'Unable to open this screen',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),

                  const SizedBox(height: 12),

                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 14),
                  ),

                  const SizedBox(height: 28),

                  ElevatedButton.icon(
                    onPressed: () {
                      navigatorKey.currentState?.pushNamedAndRemoveUntil(
                        AppRoutes.home,
                        (route) => false,
                      );
                    },
                    icon: const Icon(Icons.home),
                    label: const Text('Return Home'),
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
