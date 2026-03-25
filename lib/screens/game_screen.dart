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

  /// Selected cell
  int selectedRow = -1;
  int selectedCol = -1;

  /// Undo stack
  List<Map<String, int>> history = [];

  /// Timer
  Timer? timer;
  DateTime? startTime;
  Duration elapsed = Duration.zero;
  bool isRunning = false;

  /// Background timer handling
  DateTime? pausedAt;
  static const int maxBackgroundSeconds = 900;

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

  /// ==========================================================================
  /// LOAD LEVEL (SAFE)
  /// ==========================================================================
  Future<void> loadLevel() async {
    try{
      level = await levelService.getLevel(widget.levelNumber);

      board = SudokuBoard.fromPuzzle(
        level.puzzle,
        level.solution,
      );

      startTimer();

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

  /// ==========================================================================
  /// APP LIFECYCLE HANDLING
  /// ==========================================================================
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
      // Triggered whenever app changes state (foreground ↔ background)

    if (state == AppLifecycleState.paused) {
        // App moved to background (user minimized or switched apps)

      pauseTimer(); // Stop counting game time
      
      // Record the exact time when app was paused
      pausedAt = DateTime.now();

    } else if (state == AppLifecycleState.resumed) {
        // App returned to foreground

        if (pausedAt != null) {
          // Calculate how long the app stayed in background
          final difference = DateTime.now().difference(pausedAt!);

          // If user was away longer than allowed limit
          if (difference.inSeconds >= maxBackgroundSeconds) {
            handleSessionExpired(); // Expire the session
            return; // Stop further execution (do NOT resume timer)
          }
        }

        // If within allowed time → resume game normally
        resumeTimer();
      }
  }

  void handleSessionExpired() {
    // Ensure widget is still in the widget tree
    if (!mounted) return;

    // Stop any active periodic timer (if you have one)
    timer?.cancel();

    // Show a blocking dialog (user MUST respond)
    showDialog(
      context: context,
      barrierDismissible: false,  // Prevent closing by tapping outside
      builder: (_) => AlertDialog(
        title: const Text("Session Expired"),
        content: const Text(
          "You were away for too long.\n\nThe level will restart.",
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              restartLevel(); // Restart the game level
            },
            child: const Text("OK"),
          ),
        ],
      ),
    );
  }

  void restartLevel() {
    setState(() {
      // Clear move history (undo/redo stack)
      history.clear();

      // Reset selected cell
      selectedRow = -1;
      selectedCol = -1;
    });

    // Recreate the Sudoku board from original puzzle
    board = SudokuBoard.fromPuzzle(
      level.puzzle,
      level.solution,
    );

    // Restart the timer from zero
    startTimer();
  }

  /// ==========================================================================
  /// GAME LOGIC
  /// ==========================================================================
  
  /// Updates the currently selected cell in the UI
  void selectCell(int row, int col) {
    setState(() {
      selectedRow = row;
      selectedCol = col;
    });
  }

  /// Handles user input into the selected cell
  void inputNumber(int number) {
    // Ensure a cell is selected
    if (selectedRow == -1 || selectedCol == -1) return;

    // Prevent editing fixed (initial puzzle) cells
    if (!board.fixed[selectedRow][selectedCol]) {

      // Prevent adding the same number again
      if (board.board[selectedRow][selectedCol] == number) return;

      // Save current state for undo functionality
      history.add({
        "row": selectedRow,
        "col": selectedCol,
        "value": board.board[selectedRow][selectedCol]
      });

      
      setState(() {
        // Update the board with new value
        board.setNumber(selectedRow, selectedCol, number);
      });

      // Check if the game is completed after input
      checkWin();
    }
  }

  /// Clears the selected cell (if editable)
  void eraseNumber() {
    // 1. Ensure a cell is selected
    if (selectedRow == -1 || selectedCol == -1) return;

    // 2. Prevent editing fixed cells
    if (!board.fixed[selectedRow][selectedCol]) {

      // If the cell is already empty, do nothing
      if (board.board[selectedRow][selectedCol] == 0) return;

      // 3. Save current value for undo
      history.add({
        "row": selectedRow,
        "col": selectedCol,
        "value": board.board[selectedRow][selectedCol]
      });

      // 4. Clear the cell
      setState(() {
        board.clearCell(selectedRow, selectedCol);
      });
    }
  }

  /// Reverts the last move made by the player
  void undoMove() {
    if (history.isEmpty) return;

    var last = history.removeLast();

    setState(() {
      // Restore previous value
      board.board[last["row"]!][last["col"]!] = last["value"]!;
    });
  }
  
Set<String> hintedCells = {};

/// Provides a hint by filling one correct cell
void giveHint() {

  List<Map<String, int>> candidates = [];

  // Iterate over entire board
  for (int r = 0; r < 9; r++) {
    for (int c = 0; c < 9; c++) {
      
      // Skip fixed cells
      if (board.fixed[r][c]) continue;

      String key = "$r-$c";

      int current = board.board[r][c];
      int correct = board.solution[r][c];

      // 🚫 Skip already hinted cells
      if (hintedCells.contains(key)) continue;

      // Only empty or incorrect cells
      if (current == 0 || current != correct) {
        candidates.add({"row": r, "col": c});
      }
    }
  }

  // No valid hint available
  if (candidates.isEmpty) return;
  
  // Randomize selection
  candidates.shuffle();
  var pick = candidates.first;

  int r = pick["row"]!;
  int c = pick["col"]!;
  String key = "$r-$c";

  int currentValue = board.board[r][c];
  int correctValue = board.solution[r][c];

  // Save for undo
  history.add({
    "row": r,
    "col": c,
    "value": currentValue,
  });

  setState(() {
    // Apply correct value
    board.board[r][c] = correctValue;
    // Update selection
    selectedRow = r;
    selectedCol = c;

    // ✅ Mark as hinted to avoid reuse
    hintedCells.add(key);
  });

  checkWin();
}

  /// Checks if the board is fully and correctly solved
  void checkWin() {
    if (!SudokuValidator.isBoardComplete(board.board)) return;

    // Stop timer
    timer?.cancel();

    // Calculate performance rating
    int stars = calculateStars();

    // Persist progress
    progressService.saveLevelProgress(
      levelNumber: widget.levelNumber,
      stars: stars,
      time: getCurrentTime().inSeconds,
    );

    // Navigate to win screen
    showWinScreen(stars);
  }

  /// Calculates star rating based on completion time
  int calculateStars() {
    int target = level.targetTime;
    int currentSeconds = getCurrentTime().inSeconds;

    if (currentSeconds <= target) return 3;
    if (currentSeconds <= target * 1.5) return 2;
    return 1;
  }
  
  /// Navigates to the win screen and replaces current level
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

  /// Formats elapsed time into MM:SS format
  String formatTime() {
    final duration = getCurrentTime();

    int minutes = duration.inMinutes;
    int secs = duration.inSeconds % 60;

    return "${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}";
  }

  // ================= UI =================

  @override
  Widget build(BuildContext context) {
    /// STEP 1: Handle loading state
    /// If data (e.g., Sudoku board) is still loading,
    /// show a centered progress indicator.
    if (isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()), // Loading spinner
      );
    }

    /// STEP 2: Main UI Scaffold
    /// Scaffold provides the basic visual layout structure
    /// like AppBar, body, etc.
    return Scaffold(
      appBar: AppBar(
        /// Display current level dynamically
        title: Text("Level ${widget.levelNumber}"),
      ),

      /// Main Screen content
      body: Column(
        children: [
          /// Spacer at top
          const SizedBox(height: 12),

          /// STEP 3: Timer Display
          /// Shows formatted elapsed time (e.g., 00:45)
          Text(
            formatTime(),
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 10),

          /// STEP 4: Sudoku Grid
          /// Expanded makes grid take remaining vertical space
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12),

              /// Custom widget for rendering Sudoku board
              child: SudokuGrid(
                board: board, // 2D array representing Sudoku values

                /// Currently selected cell position
                selectedRow: selectedRow,
                selectedCol: selectedCol,

                /// Callback triggered when user taps a cell
                onCellTap: selectCell,
              ),
            ),
          ),

          const SizedBox(height: 10),

          /// STEP 5: Number Input Pad
          /// Provides buttons for entering numbers and actions
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: NumberPad(
              /// Called when user selects a number (1–9)
              onNumberSelected: inputNumber,

              /// Undo last move
              onUndo: undoMove,

              /// Provide hint to user
              onHint: giveHint,

              /// Erase selected cell value
              onErase: eraseNumber,
            ),
          ),

          /// Bottom spacing
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}