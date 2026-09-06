import 'dart:async';

import 'package:flutter/material.dart';

import '../logic/sudoku_validator.dart';
import '../models/level.dart';
import '../models/sudoku_board.dart';
import '../services/level_service.dart';
import '../services/progress_service.dart';
import '../widgets/number_pad.dart';
import '../widgets/sudoku_grid.dart';
import 'win_screen.dart';

/// ============================================================================
/// GameScreen
/// ============================================================================
///
/// Core Sudoku gameplay screen.
///
/// A level has ONE identity:
///
///     levelNumber
///
/// The world is derived from the global level number when required.
///
/// Responsibilities:
/// - Load the selected Sudoku level.
/// - Render the Sudoku board.
/// - Handle player input.
/// - Handle hints and undo.
/// - Track gameplay time.
/// - Detect successful completion.
/// - Save progress.
/// - Navigate to WinScreen.
///
/// Progression identity is intentionally based only on [levelNumber].
class GameScreen extends StatefulWidget {
  final int levelNumber;

  const GameScreen({super.key, required this.levelNumber});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

/// Represents one reversible board change.
class _Move {
  final int row;
  final int col;
  final int previousValue;

  const _Move({
    required this.row,
    required this.col,
    required this.previousValue,
  });
}

class _GameScreenState extends State<GameScreen> with WidgetsBindingObserver {
  /// ==========================================================================
  /// SERVICES
  /// ==========================================================================

  final LevelService _levelService = LevelService();
  final ProgressService _progressService = ProgressService();

  /// ==========================================================================
  /// GAME STATE
  /// ==========================================================================

  late SudokuBoard _board;
  late Level _level;

  /// Derived world number.
  ///
  /// This is NOT passed into GameScreen navigation.
  int get _world => _progressService.getWorldFromGlobal(widget.levelNumber);

  /// ==========================================================================
  /// SELECTION
  /// ==========================================================================

  int _selectedRow = -1;
  int _selectedCol = -1;

  /// ==========================================================================
  /// UNDO
  /// ==========================================================================

  static const int _maxHistorySize = 20;

  final List<_Move> _history = <_Move>[];

  /// ==========================================================================
  /// HINTS
  /// ==========================================================================

  /// Cells that were filled by a hint.
  ///
  /// Hinted cells cannot be manually changed afterward.
  final Set<String> _hintedCells = <String>{};

  /// TODO:
  /// Move this value to a centralized game configuration or player inventory
  /// service once the hint economy is implemented.
  int _hintsRemaining = 1000;

  /// ==========================================================================
  /// TIMER
  /// ==========================================================================

  Timer? _timer;

  int _secondsElapsed = 0;

  /// ==========================================================================
  /// SCREEN STATE
  /// ==========================================================================

  bool _isLoading = true;
  bool _isCompleting = false;

  String? _errorMessage;

  /// Prevents lifecycle events from restarting the timer after completion.
  bool _isGameFinished = false;

  /// ==========================================================================
  /// LIFECYCLE
  /// ==========================================================================

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);

    _loadLevel();
  }

  @override
  void dispose() {
    _stopTimer();

    WidgetsBinding.instance.removeObserver(this);

    super.dispose();
  }

  /// ==========================================================================
  /// APP LIFECYCLE
  /// ==========================================================================

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_isGameFinished || _isLoading) {
      return;
    }

    switch (state) {
      case AppLifecycleState.resumed:
        _startTimer();
        break;

      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        _stopTimer();
        break;
    }
  }

  /// ==========================================================================
  /// LOAD LEVEL
  /// ==========================================================================

  Future<void> _loadLevel() async {
    try {
      final Level loadedLevel = await _levelService.getLevel(
        widget.levelNumber,
      );

      final SudokuBoard loadedBoard = SudokuBoard.fromPuzzle(
        loadedLevel.puzzle,
        loadedLevel.solution,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _level = loadedLevel;
        _board = loadedBoard;
        _isLoading = false;
        _errorMessage = null;
      });

      _startTimer();
    } catch (e, stackTrace) {
      debugPrint('GameScreen: failed to load level ${widget.levelNumber}: $e');

      debugPrintStack(stackTrace: stackTrace);

      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
        _errorMessage = 'Could not load this level.';
      });
    }
  }

  /// ==========================================================================
  /// TIMER
  /// ==========================================================================

  void _startTimer() {
    if (_isGameFinished || _isLoading) {
      return;
    }

    if (_timer?.isActive ?? false) {
      return;
    }

    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || _isGameFinished) {
        _stopTimer();
        return;
      }

      setState(() {
        _secondsElapsed++;
      });
    });
  }

  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
  }

  /// ==========================================================================
  /// CELL SELECTION
  /// ==========================================================================

  void _selectCell(int row, int col) {
    if (!_isValidCell(row, col)) {
      return;
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _selectedRow = row;
      _selectedCol = col;
    });
  }

  bool _isValidCell(int row, int col) {
    return row >= 0 && row < 9 && col >= 0 && col < 9;
  }

  bool _hasValidSelection() {
    if (!_isValidCell(_selectedRow, _selectedCol)) {
      return false;
    }

    return !_board.fixed[_selectedRow][_selectedCol];
  }

  String _cellKey(int row, int col) {
    return '$row-$col';
  }

  /// ==========================================================================
  /// INPUT
  /// ==========================================================================

  /// Handles a number selected from the number pad.
  void _inputNumber(int number) {
    if (_isGameFinished || _isCompleting) {
      return;
    }

    if (!_hasValidSelection()) {
      return;
    }

    final String key = _cellKey(_selectedRow, _selectedCol);

    /// Hinted cells are protected from manual modification.
    if (_hintedCells.contains(key)) {
      _showMessage('This cell was filled by a hint.');
      return;
    }

    _saveHistory();

    setState(() {
      _board.setNumber(_selectedRow, _selectedCol, number);
    });

    _checkWin();
  }

  /// ==========================================================================
  /// ERASE
  /// ==========================================================================

  void _eraseSelectedCell() {
    if (_isGameFinished || _isCompleting) {
      return;
    }

    if (!_hasValidSelection()) {
      return;
    }

    final String key = _cellKey(_selectedRow, _selectedCol);

    /// Hints are intentionally protected.
    if (_hintedCells.contains(key)) {
      _showMessage('Hinted cells cannot be erased.');
      return;
    }

    final int currentValue = _board.board[_selectedRow][_selectedCol];

    /// Nothing to erase.
    if (currentValue == 0) {
      return;
    }

    _saveHistory();

    setState(() {
      _board.clearCell(_selectedRow, _selectedCol);
    });
  }

  /// ==========================================================================
  /// UNDO
  /// ==========================================================================

  void _undoMove() {
    if (_isGameFinished || _isCompleting) {
      return;
    }

    if (_history.isEmpty) {
      _showMessage('Nothing to undo.');
      return;
    }

    final _Move move = _history.removeLast();

    final String key = _cellKey(move.row, move.col);

    setState(() {
      _board.setNumber(move.row, move.col, move.previousValue);

      /// If the cell had somehow been marked as hinted, restore its normal
      /// editable state when undoing the move.
      _hintedCells.remove(key);

      _selectedRow = move.row;
      _selectedCol = move.col;
    });
  }

  void _saveHistory() {
    if (!_hasValidSelection()) {
      return;
    }

    _history.add(
      _Move(
        row: _selectedRow,
        col: _selectedCol,
        previousValue: _board.board[_selectedRow][_selectedCol],
      ),
    );

    if (_history.length > _maxHistorySize) {
      _history.removeAt(0);
    }
  }

  /// ==========================================================================
  /// HINT SYSTEM
  /// ==========================================================================

  void _giveHint() {
    if (_isGameFinished || _isCompleting) {
      return;
    }

    if (_hintsRemaining <= 0) {
      _showMessage('No hints remaining.');
      return;
    }

    int targetRow = -1;
    int targetCol = -1;

    /// ------------------------------------------------------------------------
    /// Strategy 1:
    /// Use the currently selected cell if it is editable and incorrect/empty.
    /// ------------------------------------------------------------------------

    if (_hasValidSelection()) {
      final String selectedKey = _cellKey(_selectedRow, _selectedCol);

      final int currentValue = _board.board[_selectedRow][_selectedCol];

      final int solutionValue = _board.solution[_selectedRow][_selectedCol];

      if (!_hintedCells.contains(selectedKey) &&
          currentValue != solutionValue) {
        targetRow = _selectedRow;
        targetCol = _selectedCol;
      }
    }

    /// ------------------------------------------------------------------------
    /// Strategy 2:
    /// Find an available incorrect/empty cell.
    /// ------------------------------------------------------------------------

    if (targetRow == -1) {
      final List<_CellPosition> candidates = <_CellPosition>[];

      for (int row = 0; row < 9; row++) {
        for (int col = 0; col < 9; col++) {
          final String key = _cellKey(row, col);

          if (_board.fixed[row][col]) {
            continue;
          }

          if (_hintedCells.contains(key)) {
            continue;
          }

          final int currentValue = _board.board[row][col];

          final int solutionValue = _board.solution[row][col];

          if (currentValue != solutionValue) {
            candidates.add(_CellPosition(row: row, col: col));
          }
        }
      }

      if (candidates.isEmpty) {
        _showMessage('The board is already correct.');
        return;
      }

      candidates.shuffle();

      targetRow = candidates.first.row;
      targetCol = candidates.first.col;
    }

    _applyHint(targetRow, targetCol);
  }

  void _applyHint(int row, int col) {
    if (!_isValidCell(row, col)) {
      return;
    }

    final String key = _cellKey(row, col);

    if (_board.fixed[row][col]) {
      return;
    }

    if (_hintedCells.contains(key)) {
      return;
    }

    /// Save the previous value so the action remains undoable.
    _history.add(
      _Move(row: row, col: col, previousValue: _board.board[row][col]),
    );

    if (_history.length > _maxHistorySize) {
      _history.removeAt(0);
    }

    setState(() {
      _board.setNumber(row, col, _board.solution[row][col]);

      _hintedCells.add(key);

      _hintsRemaining--;

      _selectedRow = row;
      _selectedCol = col;
    });

    _checkWin();
  }

  /// ==========================================================================
  /// WIN DETECTION
  /// ==========================================================================

  Future<void> _checkWin() async {
    if (_isGameFinished || _isCompleting) {
      return;
    }

    if (!SudokuValidator.isBoardComplete(_board.board)) {
      return;
    }

    if (!SudokuValidator.isValidSolution(_board.board, _board.solution)) {
      return;
    }

    _isCompleting = true;
    _isGameFinished = true;

    _stopTimer();

    final int stars = _calculateStars();

    try {
      await _progressService.completeLevel(
        globalLevel: widget.levelNumber,
        timeInSeconds: _secondsElapsed,
        stars: stars,
      );

      if (!mounted) {
        return;
      }

      _showWinScreen(stars);
    } catch (e, stackTrace) {
      debugPrint('GameScreen: failed to save level ${widget.levelNumber}: $e');

      debugPrintStack(stackTrace: stackTrace);

      _isCompleting = false;
      _isGameFinished = false;

      _startTimer();

      if (!mounted) {
        return;
      }

      _showMessage('Could not save your progress. Please try again.');
    }
  }

  /// ==========================================================================
  /// STAR CALCULATION
  /// ==========================================================================

  int _calculateStars() {
    final int targetTime = _level.targetTime;

    if (_secondsElapsed <= targetTime) {
      return 3;
    }

    if (_secondsElapsed <= targetTime * 1.5) {
      return 2;
    }

    return 1;
  }

  /// ==========================================================================
  /// WIN SCREEN
  /// ==========================================================================

  void _showWinScreen(int stars) {
    if (!mounted) {
      return;
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) {
          return WinScreen(
            levelNumber: widget.levelNumber,
            stars: stars,
            time: _formatTime(_secondsElapsed),
          );
        },
      ),
    );
  }

  /// ==========================================================================
  /// FORMATTING
  /// ==========================================================================

  String _formatTime(int totalSeconds) {
    final int minutes = totalSeconds ~/ 60;
    final int seconds = totalSeconds % 60;

    return '${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}';
  }

  /// ==========================================================================
  /// MESSAGES
  /// ==========================================================================

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          duration: const Duration(seconds: 1),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  /// ==========================================================================
  /// ERROR UI
  /// ==========================================================================

  Widget _buildErrorState() {
    final ThemeData theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Sudoku')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 64,
                color: theme.colorScheme.error,
              ),
              const SizedBox(height: 20),
              Text(
                _errorMessage ?? 'Could not load this level.',
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                },
                icon: const Icon(Icons.arrow_back),
                label: const Text('Back'),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () {
                  setState(() {
                    _isLoading = true;
                    _errorMessage = null;
                  });

                  _loadLevel();
                },
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// ==========================================================================
  /// BUILD
  /// ==========================================================================

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_errorMessage != null) {
      return _buildErrorState();
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('World $_world • Level ${widget.levelNumber}'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Text(
                'Hints: $_hintsRemaining',
                style: const TextStyle(fontSize: 16),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 12),

            /// TIMER
            Text(
              _formatTime(_secondsElapsed),
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 10),

            /// SUDOKU GRID
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: SudokuGrid(
                board: _board,
                selectedRow: _selectedRow,
                selectedCol: _selectedCol,
                hintedCells: _hintedCells,
                onCellTap: _selectCell,
              ),
            ),

            const SizedBox(height: 20),

            /// NUMBER PAD
            NumberPad(
              onNumberSelected: _inputNumber,
              onUndo: _undoMove,
              onHint: _giveHint,
              onErase: _eraseSelectedCell,
            ),

            const Spacer(),
          ],
        ),
      ),
    );
  }
}

/// ============================================================================
/// INTERNAL CELL POSITION MODEL
/// ============================================================================

class _CellPosition {
  final int row;
  final int col;

  const _CellPosition({required this.row, required this.col});
}
