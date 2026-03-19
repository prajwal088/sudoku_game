import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';

import 'screens/home_screen.dart';
import 'screens/game_screen.dart';
import 'screens/level_map_screen.dart';
import 'screens/world_map_screen.dart';
import 'screens/settings_screen.dart';
// import 'screens/stats_screen.dart';

import 'services/user_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await UserService().init();

  runApp(const SudokuApp());
}

class SudokuApp extends StatelessWidget {
  const SudokuApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "Sudoku",
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,

      initialRoute: "/",

      routes: {
        "/": (context) => const HomeScreen(),

        "/worlds": (context) => const WorldMapScreen(),

        "/settings": (context) => const SettingsScreen(),

        // "/stats": (context) => const StatsScreen(),
      },

      onGenerateRoute: (settings) {
        /// ✅ GAME SCREEN
        if (settings.name == "/game") {
          final args = settings.arguments as Map<String, dynamic>;

          final level = args["level"] as int;
          final world = args["world"] as int;

          return MaterialPageRoute(
            builder: (context) => GameScreen(
              levelNumber: level,
              world: world,
            ),
          );
        }

        /// ✅ LEVEL MAP SCREEN (FIXED)
        if (settings.name == "/levels") {
          final world = settings.arguments as int;

          return MaterialPageRoute(
            builder: (context) => LevelMapScreen(world: world),
          );
        }

        return null;
      },
    );
  }
}