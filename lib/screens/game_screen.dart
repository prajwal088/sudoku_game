import 'package:flutter/material.dart';
import 'dart:async';

import '../models/level.dart';
import '../models/sudoku_board.dart';

import '../services/level_service.dart';
import '../services/progress_service.dart';

import '../widgets/sudoku_grid.dart';
import '../widgets/number_pad.dart';

import '../logic/sudoku_validator.dart';

import 'win_screen.dart';

class GameScreen extends StatefulWidget {

final int levelNumber;

const GameScreen({
super.key,
required this.levelNumber,
});

@override
State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {

final LevelService levelService = LevelService();
final ProgressService progressService = ProgressService();

late SudokuBoard board;
late Level level;

int selectedRow = -1;
int selectedCol = -1;

List<Map<String, int>> history = [];

Timer? timer;
int seconds = 0;

bool isLoading = true;

@override
void initState() {
super.initState();
loadLevel();
}

Future<void> loadLevel() async {
level = await levelService.getLevel(widget.levelNumber);

board = SudokuBoard.fromPuzzle(
  level.puzzle,
  level.solution,
);

startTimer();
setState(() {
  isLoading = false;
});
}

void startTimer() {
timer?.cancel();

timer = Timer.periodic(
  const Duration(seconds: 1),
  (t) {
    setState(() {
      seconds++;
    });
  },
);
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
    board.setNumber(selectedRow, selectedCol, number);
  });

  checkWin();
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
    board.clearCell(selectedRow, selectedCol);
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

void giveHint() {

for (int r = 0; r < 9; r++) {

  for (int c = 0; c < 9; c++) {

    if (board.board[r][c] == 0) {

      history.add({
        "row": r,
        "col": c,
        "value": 0
      });

      setState(() {
        board.board[r][c] = board.solution[r][c];
        selectedRow = r;
        selectedCol = c;
      });

      checkWin();
      return;
    }
  }
}
}

void checkWin() {

if (!SudokuValidator.isBoardComplete(board.board)) return;

timer?.cancel();

int stars = calculateStars();

progressService.saveLevelProgress(
  levelNumber: widget.levelNumber,
  stars: stars,
  time: seconds,
);

// progressService.unlockNextLevel(widget.levelNumber);

showWinScreen(stars);
}

int calculateStars() {
int target = level.targetTime;

if (seconds <= target) return 3;
if (seconds <= target * 1.5) return 2;
return 1;
}

void showWinScreen(int stars) {

Navigator.pushReplacement(
  context,
  MaterialPageRoute(
    builder: (_) => WinScreen(
      levelNumber: widget.levelNumber,
      stars: stars,
      time: formatTime(),
    ),
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

if (isLoading) {
  return const Scaffold(
    body: Center(child: CircularProgressIndicator()),
  );
}

return Scaffold(

  appBar: AppBar(
    title: Text("Level ${widget.levelNumber}"),
  ),

  body: Column(
    children: [

      const SizedBox(height: 12),

      /// TIMER
      Text(
        formatTime(),
        style: const TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.bold,
        ),
      ),

      const SizedBox(height: 10),

      /// SUDOKU GRID
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
