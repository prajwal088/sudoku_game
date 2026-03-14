import 'package:flutter/material.dart';
import 'dart:async';

import '../models/sudoku_board.dart';
import '../widgets/sudoku_grid.dart';
import '../widgets/number_pad.dart';
import '../services/game_service.dart';
import '../logic/sudoku_validator.dart';
import '../logic/sudoku_solver.dart';

class GameScreen extends StatefulWidget {
final SudokuBoard board;

const GameScreen({super.key, required this.board});

@override
State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {

late SudokuBoard board;

final GameService gameService = GameService();

int selectedRow = -1;
int selectedCol = -1;

List<Map<String, int>> history = [];

Timer? timer;
int seconds = 0;

@override
void initState() {
super.initState();
board = widget.board;
startTimer();
}

void startTimer() {
timer?.cancel();
timer = Timer.periodic(const Duration(seconds: 1), (t) {
setState(() {
seconds++;
});
});
}

@override
void dispose() {
timer?.cancel();
super.dispose();
}

void selectCell(int row, int col) {
setState(() {
selectedRow = row;
selectedCol = col;
});
}

void inputNumber(int number) {

if (selectedRow == -1 || selectedCol == -1) return;

if (!board.fixed[selectedRow][selectedCol]) {

  history.add({
    "row": selectedRow,
    "col": selectedCol,
    "value": board.board[selectedRow][selectedCol]
  });

  setState(() {
    board.board[selectedRow][selectedCol] = number;
  });

  if (SudokuValidator.isBoardComplete(board.board)) {
    showWinDialog();
  }
}
}

void eraseNumber() {

if (selectedRow == -1 || selectedCol == -1) return;

if (!board.fixed[selectedRow][selectedCol]) {

  history.add({
    "row": selectedRow,
    "col": selectedCol,
    "value": board.board[selectedRow][selectedCol]
  });

  setState(() {
    board.board[selectedRow][selectedCol] = 0;
  });
}

}

void undoMove() {

if (history.isEmpty) return;

var last = history.removeLast();

setState(() {
  board.board[last["row"]!][last["col"]!] = last["value"]!;
});
}

void newGame() {

timer?.cancel();

setState(() {
  board = gameService.newGame();
  history.clear();
  seconds = 0;
  selectedRow = -1;
  selectedCol = -1;
});

startTimer();

}

/// PRO Hint System (uses solver)
void giveHint() {

var solvedBoard = SudokuSolver.getSolvedBoard(board.board);

for (int r = 0; r < 9; r++) {
  for (int c = 0; c < 9; c++) {

    if (board.board[r][c] == 0) {

      history.add({
        "row": r,
        "col": c,
        "value": 0
      });

      setState(() {
        board.board[r][c] = solvedBoard[r][c];
        selectedRow = r;
        selectedCol = c;
      });

      return;
    }
  }
}
}

void showWinDialog() {

timer?.cancel();

showDialog(
  context: context,
  builder: (_) => AlertDialog(
    title: const Text("🎉 Congratulations!"),
    content: const Text("You solved the Sudoku puzzle!"),
    actions: [
      TextButton(
        onPressed: () {
          Navigator.pop(context);
          newGame();
        },
        child: const Text("New Game"),
      )
    ],
  ),
);

}

String formatTime() {

int minutes = seconds ~/ 60;
int secs = seconds % 60;

return "${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}";
}

@override
Widget build(BuildContext context) {
return Scaffold(

  appBar: AppBar(
    title: const Text("Sudoku"),
    actions: [
      IconButton(
        icon: const Icon(Icons.refresh),
        onPressed: newGame,
      )
    ],
  ),

  body: Column(
    children: [

      const SizedBox(height: 10),

      /// TIMER
      Text(
        formatTime(),
        style: const TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.bold,
        ),
      ),

      const SizedBox(height: 10),

      /// GRID
      Expanded(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: SudokuGrid(
            board: board,
            selectedRow: selectedRow,
            selectedCol: selectedCol,
            onCellTap: selectCell,
          ),
        ),
      ),

      const SizedBox(height: 10),

      /// NUMBER PAD
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: NumberPad(
          onNumberSelected: inputNumber,
          onUndo: undoMove,
          onHint: giveHint,
          onErase: eraseNumber,
        ),
      ),

      const SizedBox(height: 20),

    ],
  ),
);
}
}
