import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';

import 'screens/home_screen.dart';
import 'screens/game_screen.dart';
import 'screens/level_map_screen.dart';

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

      /// FIRST SCREEN
      home: const HomeScreen(),

      /// APP ROUTES
      routes: {
        "/levels": (context) => const LevelMapScreen(),
      },

      /// ROUTE WITH ARGUMENTS
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