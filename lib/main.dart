import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'core/theme/app_theme.dart';
import 'screens/home_screen.dart';
import 'screens/game_screen.dart';
import 'screens/level_map_screen.dart';
import 'screens/world_map_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/statistics_screen.dart';
import 'services/user_service.dart';

/// ============================================================================
/// ROUTE ARGUMENT MODELS (TYPE SAFETY)
/// ============================================================================
class GameArguments {
  final int level;
  final int world;
  GameArguments({required this.level, required this.world});
}

/// ============================================================================
/// APPLICATION ENTRY POINT
/// ============================================================================

Future<void> main() async {
  // Ensure Flutter engine is ready for platform calls
  WidgetsFlutterBinding.ensureInitialized();

  // Professional Touch: Lock orientation to Portrait
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  // Set Status Bar transparency or color
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
  ));

  /// Initialize user-related services (ID, preferences, etc.)
  try {
    await UserService().init();
  } catch (e) {
    debugPrint("Failed to initialize UserService: $e");
  }
  
  // Global Flutter Error Catching
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    // Here you would typically send the error to a service like Sentry or Firebase Crashlytics
    debugPrint("Caught Flutter Error: ${details.exception}");
  };

  runApp(const SudokuApp());
}

/// ============================================================================
/// ROUTE CONSTANTS (PREVENTS STRING ERRORS)
/// ============================================================================
class AppRoutes {
  static const home = "/";
  static const worlds = "/worlds";
  static const settings = "/settings";
  static const statistics = "/statistics";
  static const game = "/game";
  static const levels = "/levels";
}

/// ============================================================================
/// ROOT APPLICATION
/// ============================================================================
class SudokuApp extends StatelessWidget {
  const SudokuApp({super.key});

  /// Optional: Global navigator key (useful for advanced cases)
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "Sudoku",
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,

      /// Global navigation access
      navigatorKey: navigatorKey,

      /// Initial route
      initialRoute: AppRoutes.home,

      /// Static routes (no arguments required)
      routes: {
        AppRoutes.home: (_) => const HomeScreen(),
        AppRoutes.worlds: (_) => const WorldMapScreen(),
        AppRoutes.settings: (_) => const SettingsScreen(),
        AppRoutes.statistics: (_) => const StatisticsScreen(),
      },

      /// Dynamic routes (Data-driven)
      onGenerateRoute: _onGenerateRoute,

      // Fallback for unknown routes pushed via code
      onUnknownRoute: (settings) => _errorRoute("Unknown Path: ${settings.name}"),
    );
  }

  /// ==========================================================================
  /// ROUTE GENERATOR (SAFE + VALIDATED)
  /// ==========================================================================
  static Route<dynamic> _onGenerateRoute(RouteSettings settings) {
    try {
      switch (settings.name) {
        /// =========================
        /// 🎮 GAME SCREEN
        /// =========================
        case AppRoutes.game:
            final args = settings.arguments;

                // Support both Map and GameArguments class for transition period
              if (args is GameArguments) {
                return MaterialPageRoute(
                  builder: (_) => GameScreen(levelNumber: args.level, world: args.world),
                );
              } else if (args is Map<String, dynamic>) {
                return MaterialPageRoute(
                  builder: (_) => GameScreen(
                    levelNumber: args["levelNumber"] ?? 1,
                    world: args["world"] ?? 1,
                  ),
                );
              }
              return _errorRoute("Game requires GameArguments or Map info");

            /// =========================
            /// 🗺 LEVEL MAP SCREEN
            /// =========================
            case AppRoutes.levels:
              final worldId = settings.arguments;
              if (worldId is int && worldId > 0) {
                return MaterialPageRoute(
                  builder: (_) => LevelMapScreen(world: worldId),
                );
              }
              return _errorRoute("Invalid World ID for Level Map");

            default:
              return _errorRoute("Route ${settings.name} not implemented");
          }
        } catch (e) {
          return _errorRoute("Navigation Error: $e");
        }
  }

  /// ==========================================================================
  /// GLOBAL ERROR ROUTE
  /// ==========================================================================
  static Route<dynamic> _errorRoute(String message) {
      return MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(title: const Text("Navigation Error")),
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 64),
                  const SizedBox(height: 16),
                  Text(message, textAlign: TextAlign.center),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () => navigatorKey.currentState?.pushReplacementNamed(AppRoutes.home),
                    child: const Text("Return Home"),
                  )
                ],
              ),
            ),
          ),
        ),
      );
    }
}