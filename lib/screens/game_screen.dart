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

/// ============================================================================
/// GameScreen
/// ----------------------------------------------------------------------------
/// Core gameplay screen.
/// Handles:
/// - Sudoku board rendering
/// - User input
/// - Timer management
/// - Hint & undo system
/// - Win detection & navigation
/// ============================================================================

class GameScreen extends StatefulWidget {
  final int levelNumber;
  final int world;

  const GameScreen({
    super.key,
    required this.levelNumber,
    required this.world,
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

  /// Selected cell
  int selectedRow = -1;
  int selectedCol = -1;

  /// Undo stack
  final List<Map<String, int>> history = [];

  /// Timer
  Timer? timer;
  DateTime? startTime;
  Duration elapsed = Duration.zero;
  bool isRunning = false;

  /// Background handling
  DateTime? pausedAt;
  static const int maxBackgroundMinutes = 15;

  /// Hint tracking
  final Set<String> hintedCells = {};

  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadLevel();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    timer?.cancel();
    super.dispose();
  }

  /// ==========================================================================
  /// LOAD LEVEL (SAFE)
  /// ==========================================================================
  Future<void> _loadLevel() async {
    try {
      level = await levelService.getLevel(widget.levelNumber);

      board = SudokuBoard.fromPuzzle(
        level.puzzle,
        level.solution,
      );

      _startTimer();

      if (!mounted) return;

      setState(() {
        isLoading = false;
      });
    } catch (e) {
      debugPrint("GameScreen Load Error: $e");

      if (!mounted) return;

      Navigator.pop(context);
    }
  }

  /// ==========================================================================
  /// TIMER MANAGEMENT
  /// ==========================================================================
  void _startTimer() {
    startTime = DateTime.now();
    elapsed = Duration.zero;
    isRunning = true;

    timer?.cancel();

    timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || !isRunning) return;
      setState(() {});
    });
  }

  void _pauseTimer() {
    if (!isRunning) return;

    elapsed += DateTime.now().difference(startTime!);
    isRunning = false;
  }

  void _resumeTimer() {
    if (isRunning) return;

    startTime = DateTime.now();
    isRunning = true;
  }

  Duration _getCurrentTime() {
    if (!isRunning) return elapsed;
    return elapsed + DateTime.now().difference(startTime!);
  }

  /// ==========================================================================
  /// APP LIFECYCLE HANDLING
  /// ==========================================================================
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _pauseTimer();
      pausedAt = DateTime.now();
    } else if (state == AppLifecycleState.resumed) {
      if (pausedAt != null) {
        final diff = DateTime.now().difference(pausedAt!);

        if (diff.inMinutes >= maxBackgroundMinutes) {
          _handleSessionExpired();
          return;
        }
      }
      _resumeTimer();
    }
  }

  void _handleSessionExpired() {
    if (!mounted) return;

    timer?.cancel();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text("Session Expired"),
        content: const Text(
          "You were away too long. Level will restart.",
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _restartLevel();
            },
            child: const Text("OK"),
          ),
        ],
      ),
    );
  }

  void _restartLevel() {
    history.clear();
    hintedCells.clear();

    board = SudokuBoard.fromPuzzle(
      level.puzzle,
      level.solution,
    );

    _startTimer();

    setState(() {});
  }

  /// ==========================================================================
  /// GAME INPUT
  /// ==========================================================================
  void selectCell(int row, int col) {
    setState(() {
      selectedRow = row;
      selectedCol = col;
    });
  }

  void inputNumber(int number) {
    if (!_isValidSelection()) return;

    _saveHistory();

    setState(() {
      board.setNumber(selectedRow, selectedCol, number);
    });

    _checkWin();
  }

  void eraseNumber() {
    if (!_isValidSelection()) return;

    _saveHistory();

    setState(() {
      board.clearCell(selectedRow, selectedCol);
    });
  }

  void undoMove() {
    if (history.isEmpty) return;

    final last = history.removeLast();

    setState(() {
      board.setNumber(
        last["row"]!,
        last["col"]!,
        last["value"]!,
      );
    });
  }

  bool _isValidSelection() {
    return selectedRow != -1 &&
        selectedCol != -1 &&
        !board.fixed[selectedRow][selectedCol];
  }

  void _saveHistory() {
    history.add({
      "row": selectedRow,
      "col": selectedCol,
      "value": board.board[selectedRow][selectedCol],
    });
  }

  /// ==========================================================================
  /// HINT SYSTEM
  /// ==========================================================================
  void giveHint() {
    List<Map<String, int>> candidates = [];

    for (int r = 0; r < 9; r++) {
      for (int c = 0; c < 9; c++) {
        if (board.fixed[r][c]) continue;

        String key = "$r-$c";
        int current = board.board[r][c];
        int correct = board.solution[r][c];

        if (hintedCells.contains(key)) continue;

        if (current == 0 || current != correct) {
          candidates.add({"row": r, "col": c});
        }
      }
    }

    if (candidates.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No hints available")),
      );
      return;
    }

    candidates.shuffle();
    var pick = candidates.first;

    int r = pick["row"]!;
    int c = pick["col"]!;

    _saveHistory();

    setState(() {
      board.setNumber(r, c, board.solution[r][c]);
      hintedCells.add("$r-$c");
      selectedRow = r;
      selectedCol = c;
    });

    _checkWin();
  }

  /// ==========================================================================
  /// WIN LOGIC
  /// ==========================================================================
  void _checkWin() {
    if (!SudokuValidator.isBoardComplete(board.board)) return;

    timer?.cancel();

    int stars = _calculateStars();

    progressService.saveLevelProgress(
      world: widget.world,
      levelNumber: widget.levelNumber,
      stars: stars,
      time: _getCurrentTime().inSeconds,
    );

    _showWinScreen(stars);
  }

  int _calculateStars() {
    int target = level.targetTime;
    int current = _getCurrentTime().inSeconds;

    if (current <= target) return 3;
    if (current <= target * 1.5) return 2;
    return 1;
  }

  void _showWinScreen(int stars) {
    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => WinScreen(
          levelNumber: widget.levelNumber,
          stars: stars,
          time: _formatTime(),
          world: widget.world,
        ),
      ),
    );
  }

  String _formatTime() {
    final duration = _getCurrentTime();

    int minutes = duration.inMinutes;
    int secs = duration.inSeconds % 60;

    return "${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}";
  }

  /// ==========================================================================
  /// UI
  /// ==========================================================================
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

          /// TIMER DISPLAY
          Text(
            _formatTime(),
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