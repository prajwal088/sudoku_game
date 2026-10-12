import 'dart:async';

import 'package:flutter/material.dart';
import 'package:sudoku_game/config/game_config.dart';

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
/// - Confirm before abandoning a level in progress.
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
  // ==========================================================================
  // SERVICES
  // ==========================================================================

  final LevelService _levelService = LevelService();
  final ProgressService _progressService = ProgressService();

  // ==========================================================================
  // GAME STATE
  // ==========================================================================

  late SudokuBoard _board;
  late Level _level;

  // ==========================================================================
  // SELECTION
  // ==========================================================================

  int _selectedRow = -1;
  int _selectedCol = -1;

  // ==========================================================================
  // UNDO
  // ==========================================================================

  static const int _maxHistorySize = 20;

  final List<_Move> _history = <_Move>[];

  // ==========================================================================
  // HINTS
  // ==========================================================================

  /// Cells that were filled by a hint (keys are `'row-col'`, the format
  /// SudokuGrid expects).
  ///
  /// Hinted cells cannot be manually changed afterward.
  final Set<String> _hintedCells = <String>{};

  /// the hint economy is decided. Unlimited hints make the stars trivial.
  static const int _initialHints = GameConfig.maximumHintsPerLevel;

  int _hintsRemaining = _initialHints;

  // ==========================================================================
  // TIMER
  // ==========================================================================

  Timer? _timer;

  /// Elapsed play time.
  ///
  /// A ValueNotifier drives ONLY the timer text, so the once-per-second tick
  /// does not rebuild the whole screen (board, grid and number pad).
  final ValueNotifier<int> _elapsed = ValueNotifier<int>(0);

  int get _secondsElapsed => _elapsed.value;

  // ==========================================================================
  // SCREEN STATE
  // ==========================================================================

  bool _isLoading = true;
  bool _isCompleting = false;

  String? _errorMessage;

  /// Prevents lifecycle events from restarting the timer after completion.
  bool _isGameFinished = false;

  /// The puzzle is solved but saving the result failed; the player can retry.
  bool _saveFailed = false;

  /// Result captured at the moment of completion, so a retry saves exactly
  /// what was achieved (the timer is stopped).
  int _pendingSeconds = 0;
  int _pendingStars = 0;

  /// True once the player has changed the board (used for exit confirmation).
  bool _hasMadeMoves = false;

  bool _isConfirmingExit = false;
  bool _allowExit = false;

  /// The level is loaded and the board can be used.
  bool get _isPlayable => !_isLoading && _errorMessage == null;

  /// Whether leaving right now would lose something the player cares about.
  bool get _needsExitConfirmation {
    if (_allowExit || !_isPlayable) {
      return false;
    }

    if (_saveFailed) {
      return true;
    }

    return !_isGameFinished && _hasMadeMoves;
  }

  // ==========================================================================
  // LIFECYCLE
  // ==========================================================================

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);

    unawaited(_loadLevel());
  }

  @override
  void dispose() {
    _stopTimer();

    WidgetsBinding.instance.removeObserver(this);

    _elapsed.dispose();

    super.dispose();
  }

  // ==========================================================================
  // APP LIFECYCLE
  // ==========================================================================

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_isGameFinished || !_isPlayable) {
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

  bool get _isAppActive {
    final AppLifecycleState? state = WidgetsBinding.instance.lifecycleState;

    return state == null || state == AppLifecycleState.resumed;
  }

  // ==========================================================================
  // LOAD LEVEL
  // ==========================================================================

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

      // Do not start counting while the app is in the background.
      if (_isAppActive) {
        _startTimer();
      }
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

  // ==========================================================================
  // TIMER
  // ==========================================================================

  void _startTimer() {
    if (_isGameFinished || !_isPlayable) {
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

      // Updates only the timer text (ValueListenableBuilder).
      _elapsed.value++;
    });
  }

  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
  }

  // ==========================================================================
  // CELL SELECTION
  // ==========================================================================

  void _selectCell(int row, int col) {
    if (!_isValidCell(row, col) || !mounted) {
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

  // ==========================================================================
  // INPUT
  // ==========================================================================

  /// Handles a number selected from the number pad.
  void _inputNumber(int number) {
    if (_isGameFinished || _isCompleting) {
      return;
    }

    if (!_hasValidSelection()) {
      return;
    }

    final String key = _cellKey(_selectedRow, _selectedCol);

    // Hinted cells are protected from manual modification.
    if (_hintedCells.contains(key)) {
      _showMessage('This cell was filled by a hint.');
      return;
    }

    _saveHistory();

    setState(() {
      _board.setNumber(_selectedRow, _selectedCol, number);
      _hasMadeMoves = true;
    });

    unawaited(_checkWin());
  }

  // ==========================================================================
  // ERASE
  // ==========================================================================

  void _eraseSelectedCell() {
    if (_isGameFinished || _isCompleting) {
      return;
    }

    if (!_hasValidSelection()) {
      return;
    }

    final String key = _cellKey(_selectedRow, _selectedCol);

    // Hints are intentionally protected.
    if (_hintedCells.contains(key)) {
      _showMessage('Hinted cells cannot be erased.');
      return;
    }

    final int currentValue = _board.board[_selectedRow][_selectedCol];

    // Nothing to erase.
    if (currentValue == 0) {
      return;
    }

    _saveHistory();

    setState(() {
      _board.clearCell(_selectedRow, _selectedCol);
      _hasMadeMoves = true;
    });
  }

  // ==========================================================================
  // UNDO
  // ==========================================================================

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

      // If the undone move was a hint, the cell becomes editable again.
      _hintedCells.remove(key);

      _selectedRow = move.row;
      _selectedCol = move.col;
    });
  }

  void _saveHistory() {
    if (!_hasValidSelection()) {
      return;
    }

    _pushHistory(
      _Move(
        row: _selectedRow,
        col: _selectedCol,
        previousValue: _board.board[_selectedRow][_selectedCol],
      ),
    );
  }

  void _pushHistory(_Move move) {
    _history.add(move);

    if (_history.length > _maxHistorySize) {
      _history.removeAt(0);
    }
  }

  // ==========================================================================
  // HINT SYSTEM
  // ==========================================================================

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

    // ------------------------------------------------------------------------
    // Strategy 1:
    // Use the currently selected cell if it is editable and incorrect/empty.
    // ------------------------------------------------------------------------

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

    // ------------------------------------------------------------------------
    // Strategy 2:
    // Find an available incorrect/empty cell.
    // ------------------------------------------------------------------------

    if (targetRow == -1) {
      final List<_CellPosition> candidates = <_CellPosition>[];

      for (int row = 0; row < 9; row++) {
        for (int col = 0; col < 9; col++) {
          if (_board.fixed[row][col]) {
            continue;
          }

          if (_hintedCells.contains(_cellKey(row, col))) {
            continue;
          }

          if (_board.board[row][col] != _board.solution[row][col]) {
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

    if (_board.fixed[row][col] || _hintedCells.contains(key)) {
      return;
    }

    // Save the previous value so the action remains undoable.
    _pushHistory(
      _Move(row: row, col: col, previousValue: _board.board[row][col]),
    );

    setState(() {
      _board.setNumber(row, col, _board.solution[row][col]);

      _hintedCells.add(key);

      _hintsRemaining--;
      _hasMadeMoves = true;

      _selectedRow = row;
      _selectedCol = col;
    });

    unawaited(_checkWin());
  }

  // ==========================================================================
  // WIN DETECTION
  // ==========================================================================

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

    // ProgressService rejects a time of 0 seconds, which a very fast finish
    // (for example, filling the board with hints) could otherwise produce and
    // then fail to save forever. Store at least 1 second.
    _pendingSeconds = _secondsElapsed < 1 ? 1 : _secondsElapsed;
    _pendingStars = _calculateStars(_pendingSeconds);

    await _saveCompletion();
  }

  /// Saves the captured result. Used for the first attempt and for retries.
  Future<void> _saveCompletion() async {
    try {
      await _progressService.completeLevel(
        globalLevel: widget.levelNumber,
        timeInSeconds: _pendingSeconds,
        stars: _pendingStars,
      );

      if (!mounted) {
        return;
      }

      _showWinScreen(_pendingStars, _pendingSeconds);
    } catch (e, stackTrace) {
      debugPrint('GameScreen: failed to save level ${widget.levelNumber}: $e');

      debugPrintStack(stackTrace: stackTrace);

      _isCompleting = false;

      if (!mounted) {
        return;
      }

      // The board stays solved and the timer stays stopped; the player gets a
      // visible Retry instead of having to modify the solved board.
      setState(() {
        _saveFailed = true;
      });
    }
  }

  void _retrySave() {
    if (_isCompleting || !_saveFailed) {
      return;
    }

    setState(() {
      _saveFailed = false;
      _isCompleting = true;
    });

    unawaited(_saveCompletion());
  }

  // ==========================================================================
  // STAR CALCULATION
  // ==========================================================================

  int _calculateStars(int seconds) {
    final int targetTime = _level.targetTime;

    if (seconds <= targetTime) {
      return 3;
    }

    if (seconds <= targetTime * 1.5) {
      return 2;
    }

    return 1;
  }

  // ==========================================================================
  // WIN SCREEN
  // ==========================================================================

  void _showWinScreen(int stars, int seconds) {
    if (!mounted) {
      return;
    }

    unawaited(
      Navigator.pushReplacement(
        context,
        MaterialPageRoute<void>(
          builder: (_) {
            return WinScreen(
              levelNumber: widget.levelNumber,
              stars: stars,
              time: _formatTime(seconds),
            );
          },
        ),
      ),
    );
  }

  // ==========================================================================
  // EXIT CONFIRMATION
  // ==========================================================================

  /// Called when back is pressed while leaving would lose progress.
  Future<void> _handleBlockedPop() async {
    if (_isConfirmingExit || !mounted) {
      return;
    }

    _isConfirmingExit = true;

    // Fair to the player: the clock does not run while the dialog is open.
    _stopTimer();

    final bool leave = await _confirmLeave();

    _isConfirmingExit = false;

    if (!mounted) {
      return;
    }

    if (!leave) {
      _startTimer();
      return;
    }

    // canPop is evaluated when the widget builds, so allow the exit, let the
    // frame rebuild, then pop.
    setState(() {
      _allowExit = true;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        Navigator.of(context).pop();
      }
    });
  }

  Future<bool> _confirmLeave() async {
    final bool? leave = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text(_saveFailed ? 'Leave without saving?' : 'Leave level?'),
          content: Text(
            _saveFailed
                ? 'You solved this puzzle, but your result has not been '
                    'saved yet.'
                : 'Your progress on this level will be lost.',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Stay'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Leave'),
            ),
          ],
        );
      },
    );

    return leave ?? false;
  }

  // ==========================================================================
  // FORMATTING
  // ==========================================================================

  String _formatTime(int totalSeconds) {
    final int minutes = totalSeconds ~/ 60;
    final int seconds = totalSeconds % 60;

    return '${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}';
  }

  // ==========================================================================
  // MESSAGES
  // ==========================================================================

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

  // ==========================================================================
  // ERROR UI
  // ==========================================================================

  Widget _buildErrorState() {
    final ThemeData theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Sudoku')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
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

                  unawaited(_loadLevel());
                },
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==========================================================================
  // SAVE FAILED BANNER
  // ==========================================================================

  Widget _buildSaveFailedBanner() {
    final ThemeData theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 10, 12, 0),
      padding: const EdgeInsets.fromLTRB(16, 4, 8, 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              'Puzzle solved, but your result could not be saved.',
              style: TextStyle(color: theme.colorScheme.onErrorContainer),
            ),
          ),
          TextButton(
            onPressed: _isCompleting ? null : _retrySave,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // BUILD
  // ==========================================================================

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_needsExitConfirmation,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (!didPop) {
          unawaited(_handleBlockedPop());
        }
      },
      child: _buildScreen(),
    );
  }

  Widget _buildScreen() {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_errorMessage != null) {
      return _buildErrorState();
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('World ${_level.world} • Level ${widget.levelNumber}'),
        actions: <Widget>[
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
        // Scrolls only when the content does not fit (small screens or large
        // text scale) instead of overflowing.
        child: SingleChildScrollView(
          child: Column(
            children: <Widget>[
              const SizedBox(height: 12),

              // TIMER (rebuilds alone every second)
              ValueListenableBuilder<int>(
                valueListenable: _elapsed,
                builder: (BuildContext context, int seconds, Widget? child) {
                  return Semantics(
                    label: 'Elapsed time ${_formatTime(seconds)}',
                    excludeSemantics: true,
                    child: Text(
                      _formatTime(seconds),
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  );
                },
              ),

              if (_saveFailed) _buildSaveFailedBanner(),

              const SizedBox(height: 10),

              // SUDOKU GRID
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

              // NUMBER PAD
              NumberPad(
                enabled: !_isGameFinished,
                onNumberSelected: _inputNumber,
                onUndo: _undoMove,
                onHint: _giveHint,
                onErase: _eraseSelectedCell,
              ),

              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// INTERNAL CELL POSITION MODEL
// ============================================================================

class _CellPosition {
  final int row;
  final int col;

  const _CellPosition({required this.row, required this.col});
}