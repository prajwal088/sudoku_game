import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';

import 'screens/home_screen.dart';
import 'screens/game_screen.dart';
import 'screens/level_map_screen.dart';
import 'screens/world_map_screen.dart';
import 'screens/settings_screen.dart';

import 'services/user_service.dart';

/// ============================================================================
/// APPLICATION ENTRY POINT
/// ============================================================================

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  /// Initialize user-related services (ID, preferences, etc.)
  await UserService().init();

  runApp(const SudokuApp());
}

/// ============================================================================
/// ROUTE CONSTANTS (PREVENTS STRING ERRORS)
/// ============================================================================
class AppRoutes {
  static const home = "/";
  static const worlds = "/worlds";
  static const settings = "/settings";
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
        AppRoutes.home: (context) => const HomeScreen(),
        AppRoutes.worlds: (context) => const WorldMapScreen(),
        AppRoutes.settings: (context) => const SettingsScreen(),
      },

      /// Dynamic routes (require arguments)
      onGenerateRoute: _onGenerateRoute,
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
          {
            final args = settings.arguments;

            if (args is! Map<String, dynamic>) {
              return _errorRoute("Invalid arguments for GameScreen");
            }

            final int? level = args["level"];
            final int? world = args["world"];

            /// Strict validation
            if (level == null || world == null) {
              return _errorRoute("Missing level/world");
            }

            if (level <= 0 || world <= 0) {
              return _errorRoute("Invalid level/world values");
            }

            return MaterialPageRoute(
              builder: (_) => GameScreen(
                levelNumber: level,
                world: world,
              ),
            );
          }

        /// =========================
        /// 🗺 LEVEL MAP SCREEN
        /// =========================
        case AppRoutes.levels:
          {
            final args = settings.arguments;

            if (args is! int || args <= 0) {
              return _errorRoute("Invalid world argument");
            }

            return MaterialPageRoute(
              builder: (_) => LevelMapScreen(world: args),
            );
          }

        /// =========================
        /// ❌ UNKNOWN ROUTE
        /// =========================
        default:
          return _errorRoute("Route not found: ${settings.name}");
      }
    } catch (e) {
      /// Log error for debugging
      debugPrint("Routing Error: $e");

      return _errorRoute("Something went wrong");
    }
  }

  /// ==========================================================================
  /// ERROR SCREEN (FAIL-SAFE)
  /// ==========================================================================
  static Route<dynamic> _errorRoute(String message) {
    return MaterialPageRoute(
      builder: (_) => Scaffold(
        appBar: AppBar(title: const Text("Error")),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              message,
              style: const TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
}