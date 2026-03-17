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

class _GameScreenState extends State<GameScreen>
    with WidgetsBindingObserver {

  final LevelService levelService = LevelService();
  final ProgressService progressService = ProgressService();

  late SudokuBoard board;
  late Level level;

  int selectedRow = -1;
  int selectedCol = -1;

  List<Map<String, int>> history = [];

  Timer? timer;

  DateTime? startTime;
  Duration elapsed = Duration.zero;
  bool isRunning = false;

  DateTime? pausedAt;
  static const int maxBackgroundMinutes = 15;

  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    loadLevel();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    timer?.cancel();
    super.dispose();
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

  // ================= TIMER =================

  void startTimer() {
    startTime = DateTime.now();
    elapsed = Duration.zero;
    isRunning = true;

    timer?.cancel();

    timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {});
    });
  }

  void pauseTimer() {
    if (!isRunning) return;

    elapsed += DateTime.now().difference(startTime!);
    isRunning = false;
  }

  void resumeTimer() {
    if (isRunning) return;

    startTime = DateTime.now();
    isRunning = true;
  }

  Duration getCurrentTime() {
    if (!isRunning) return elapsed;

    return elapsed + DateTime.now().difference(startTime!);
  }

  // ================= LIFECYCLE =================

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      pauseTimer();
      pausedAt = DateTime.now();
    } 
    else if (state == AppLifecycleState.resumed) {
      if (pausedAt != null) {
        final difference = DateTime.now().difference(pausedAt!);

        if (difference.inMinutes >= maxBackgroundMinutes) {
          handleSessionExpired();
          return;
        }
      }

      resumeTimer();
    }
  }

  void handleSessionExpired() {
    if (!mounted) return;

    timer?.cancel();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text("Session Expired"),
        content: const Text(
          "You were away for too long.\n\nThe level will restart.",
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              restartLevel();
            },
            child: const Text("OK"),
          ),
        ],
      ),
    );
  }

  void restartLevel() {
    setState(() {
      history.clear();
      selectedRow = -1;
      selectedCol = -1;
    });

    board = SudokuBoard.fromPuzzle(
      level.puzzle,
      level.solution,
    );

    startTimer();
  }

  // ================= GAME LOGIC =================

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
      time: getCurrentTime().inSeconds,
    );

    showWinScreen(stars);
  }

  int calculateStars() {
    int target = level.targetTime;
    int currentSeconds = getCurrentTime().inSeconds;

    if (currentSeconds <= target) return 3;
    if (currentSeconds <= target * 1.5) return 2;
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
    final duration = getCurrentTime();

    int minutes = duration.inMinutes;
    int secs = duration.inSeconds % 60;

    return "${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}";
  }

  // ================= UI =================

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