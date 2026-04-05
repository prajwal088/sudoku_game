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

import '../services/analytics_service.dart';

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
  final List<Map<String, dynamic>> history = [];

  // TODO: Update hint when creating builds
  /// Hint tracking
  final Set<String> hintedCells = {};
  int hintsRemaining = 1000; // Production feature: limited hints

  /// Timer State
  Timer? _timer;
  int _secondsElapsed = 0;
  /// bool _isRunning = false;
  bool _isLoading = true;

  // For high-accuracy analytics tracking
  late DateTime _levelStartTime;

  /// Lifecycle
  DateTime? pausedAt;

  @override
  void initState() {
    super.initState();
    _levelStartTime = DateTime.now();

    // Log that the player started the level
    AnalyticsService.logGameStart(widget.world, widget.levelNumber);
    WidgetsBinding.instance.addObserver(this);
    _loadLevel();
  }

  @override
  void dispose() {

    // Track: Did they leave without finishing? 
    // This helps identify "frustration exits"
    if (_isLoading == false && !SudokuValidator.isBoardComplete(board.board)) {
      AnalyticsService.logLevelAbandoned(
        world: widget.world,
        level: widget.levelNumber,
        secondsPlayed: _secondsElapsed,
      );
    }

    _stopTimer();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Handle app background/foreground
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _stopTimer();
    } else if (state == AppLifecycleState.resumed) {
      _startTimer();
    }
  }

  /// ==========================================================================
  /// LOAD LEVEL (CORE LOGIC)
  /// ==========================================================================
  Future<void> _loadLevel() async {
    try {
      level = await levelService.getLevel(widget.levelNumber);

      board = SudokuBoard.fromPuzzle(
        level.puzzle,
        level.solution,
      );

      setState(() {
        _isLoading = false;
      });
      _startTimer();
    } catch (e) {
      debugPrint("GameScreen Load Error: $e");
      // Track: Technical failures
      AnalyticsService.logError("level_load_failure", e.toString());
      if (mounted) Navigator.pop(context);
    }
  }

  /// ==========================================================================
  /// TIMER MANAGEMENT
  /// ==========================================================================
  void _startTimer() {
    if (_timer?.isActive ?? false) return;  // Prevent multiple timers

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _secondsElapsed++;
        });
      }
    });
  }

  void _stopTimer() {
    _timer?.cancel();
  }

// ==========================================================================
  // HINT LOGIC (IMPROVED)
  // ==========================================================================
  void giveHint() {
    if (hintsRemaining <= 0) {
      _showToast("No hints remaining!");
      return;
    }

    int targetRow = -1;
    int targetCol = -1;

    // Strategy 1: If user has a cell selected and it's empty/wrong, hint that one.
    if (_isValidSelection() &&
        !hintedCells.contains("$selectedRow-$selectedCol") &&
        (board.board[selectedRow][selectedCol] == 0 || 
         board.board[selectedRow][selectedCol] != board.solution[selectedRow][selectedCol])) {
      targetRow = selectedRow;
      targetCol = selectedCol;
    } 
    // Strategy 2: Otherwise, find the first empty/wrong cell.
    else {
      List<Map<String, int>> candidates = [];
      for (int r = 0; r < 9; r++) {
        for (int c = 0; c < 9; c++) {
          if (board.fixed[r][c] || hintedCells.contains("$r-$c")) continue;
          if (board.board[r][c] == 0 || board.board[r][c] != board.solution[r][c]) {
            candidates.add({"r": r, "c": c});
          }
        }

      if (candidates.isEmpty) {
        _showToast("Board is already correct!");
        return;
      }
      
      candidates.shuffle();
      targetRow = candidates.first["r"]!;
      targetCol = candidates.first["c"]!;
    }

    _applyHint(targetRow, targetCol);
  }

  void _applyHint(int r, int c) {
    _saveHistory(); // Allow undoing a hint if desired, or skip this to make hints permanent
    
    setState(() {
      board.setNumber(r, c, board.solution[r][c]);
      hintedCells.add("$r-$c");
      hintsRemaining--;
      selectedRow = r;
      selectedCol = c;
    });

    // Track: Engagement with help features
    AnalyticsService.logHintUsed(widget.world, widget.levelNumber);

    _checkWin();
  }

  // ==========================================================================
  // INPUT HANDLERS
  // ==========================================================================

  /// Handles user input into the selected cell
  void inputNumber(int number) {
    if (!_isValidSelection()) return;
    
    // Don't allow changing a hinted cell (Professional touch)
    if (hintedCells.contains("$selectedRow-$selectedCol")) return;

    _saveHistory();
    setState(() => board.setNumber(selectedRow, selectedCol, number));
    _checkWin();
  }

  /// Reverts the last move made by the player
  void undoMove() {
    if (history.isEmpty) return;

    // Track: Undo usage (helps measure difficulty)
    AnalyticsService.logUndoUsed(widget.world, widget.levelNumber);

    final last = history.removeLast();
    setState(() {
      board.setNumber(last["row"], last["col"], last["value"]);
      // Optional: if hint was undone, remove from hintedCells
    });
  }

  bool _isValidSelection() => 
    selectedRow != -1 && selectedCol != -1 && !board.fixed[selectedRow][selectedCol];

  void _saveHistory() {
    history.add({
      "row": selectedRow,
      "col": selectedCol,
      "value": board.board[selectedRow][selectedCol],
    });
    if (history.length > 20) history.removeAt(0); // Limit memory usage
  }

// ==========================================================================
  // WIN CONDITION & NAVIGATION
  // ==========================================================================

  Future<void> _checkWin() async {
    if (!SudokuValidator.isBoardComplete(board.board)) return;
    if (!SudokuValidator.isValidSolution(board.board, board.solution)) {
      // Track: Attempted complete board but it's wrong
      AnalyticsService.logInvalidSubmit(widget.world, widget.levelNumber);
      return;
    }

    _timer?.cancel();

    final actualDuration = DateTime.now().difference(_levelStartTime).inSeconds;

    int stars = _calculateStars();

    // FIX: Using the correct method name from our ProgressService
    await progressService.completeLevel(
      globalLevel: widget.levelNumber, // This is our source of truth
      timeInSeconds: _secondsElapsed,
      stars: stars,
    );

    // Track: Level Success with detailed metrics
    AnalyticsService.logLevelComplete(
      world: widget.world,
      level: widget.levelNumber,
      stars: stars,
      seconds: actualDuration,  // Use the high-accuracy time for analytics
    );

    if (mounted) _showWinScreen(stars);
  }

  int _calculateStars() {
    if (_secondsElapsed <= level.targetTime) return 3;
    if (_secondsElapsed <= level.targetTime * 1.5) return 2;
    return 1;
  }

  void _showWinScreen(int stars) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => WinScreen(
          levelNumber: widget.levelNumber,
          stars: stars,
          time: _formatTime(_secondsElapsed),
          world: widget.world,
        ),
      ),
    );
  }

  String _formatTime(int totalSeconds) {
    int minutes = totalSeconds ~/ 60;
    int seconds = totalSeconds % 60;
    return "${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}";
  }

  void _showToast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), duration: const Duration(seconds: 1)));
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    /// STEP 2: Main UI Scaffold
    /// Scaffold provides the basic visual layout structure
    /// like AppBar, body, etc.
    return Scaffold(
      appBar: AppBar(
        title: Text("World ${widget.world} - Level ${widget.levelNumber}"),
        actions: [
          Center(child: Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Text("Hints: $hintsRemaining", style: const TextStyle(fontSize: 16)),
          ))
        ],
      ),
      body: SafeArea(
        child: Column(
          // 2. Set to start to pull everything toward the top
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            const SizedBox(height: 12),
            Text(
              _formatTime(_secondsElapsed), 
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)
            ),
            const SizedBox(height: 10),
            
            // 3. Removed Expanded from here to prevent the "dead space" stretching
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: SudokuGrid(
                board: board, // 2D array representing Sudoku values

                /// Currently selected cell position
                selectedRow: selectedRow,
                selectedCol: selectedCol,
                hintedCells: hintedCells,
                onCellTap: (r, c) => setState(() { 
                  selectedRow = r; 
                  selectedCol = c; 
                }),
              ),
            ),

            // 4. Tighten the gap between Grid and NumberPad
            const SizedBox(height: 20),

            NumberPad(
              onNumberSelected: inputNumber,

              /// Undo last move
              onUndo: undoMove,

              /// Provide hint to user
              onHint: giveHint,
              onErase: () {
                if (_isValidSelection()) {
                  _saveHistory();
                  setState(() {
                    board.clearCell(selectedRow, selectedCol);
                    // Remove from hintedCells so it's no longer "protected" or "marked"
                    hintedCells.remove("$selectedRow-$selectedCol"); 
                  });
                }
              },
            ),
            
            // 5. This Spacer pushes everything UP and fills the gap at the bottom
            const Spacer(),
          ],
        ),
      ),
    );
  }
}