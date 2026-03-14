import 'package:flutter/material.dart';
import '../services/game_service.dart';
import 'game_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    GameService gameService = GameService();

    return Scaffold(
      appBar: AppBar(title: const Text("Sudoku")),
      body: Center(
        child: ElevatedButton(
          child: const Text("Start Game"),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => GameScreen(
                  board: gameService.newGame(),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}