import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';

import 'screens/home_screen.dart';
import 'screens/game_screen.dart';
import 'screens/level_map_screen.dart';
import 'screens/settings_screen.dart';
// import 'screens/stats_screen.dart'; // 👈 add when ready

void main() {
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

      /// ✅ PRO WAY (instead of home:)
      initialRoute: "/",

      /// STATIC ROUTES
      routes: {
        "/": (context) => const HomeScreen(),
        "/levels": (context) => const LevelMapScreen(),
        "/settings": (context) => const SettingsScreen(),

        // "/stats": (context) => const StatsScreen(), // 👈 enable later
      },

      /// DYNAMIC ROUTES (WITH ARGUMENTS)
      onGenerateRoute: (settings) {
        if (settings.name == "/game") {
          final level = settings.arguments as int;

          return MaterialPageRoute(
            builder: (context) => GameScreen(levelNumber: level),
          );
        }

        return null;
      },
    );
  }
}