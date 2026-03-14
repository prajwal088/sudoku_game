import 'package:flutter/material.dart';
import '../models/sudoku_board.dart';
import 'sudoku_cell.dart';
import '../logic/sudoku_validator.dart';

class SudokuGrid extends StatelessWidget {
  final SudokuBoard board;
  final int selectedRow;
  final int selectedCol;
  final Function(int, int) onCellTap;

  const SudokuGrid({
    super.key,
    required this.board,
    required this.selectedRow,
    required this.selectedCol,
    required this.onCellTap,
  });

  bool isHighlighted(int row, int col) {
    if (selectedRow == -1 || selectedCol == -1) return false;

    return row == selectedRow ||
        col == selectedCol ||
        (row ~/ 3 == selectedRow ~/ 3 &&
            col ~/ 3 == selectedCol ~/ 3);
  }

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1,
      child: GridView.builder(
        physics: const NeverScrollableScrollPhysics(),
        itemCount: 81,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 9,
        ),
        itemBuilder: (context, index) {
          int row = index ~/ 9;
          int col = index % 9;

          int value = board.board[row][col];

          bool wrong = false;

          if (value != 0) {
            wrong =
                !SudokuValidator.isValidMove(board.board, row, col, value);
          }

          bool highlighted = isHighlighted(row, col);
          bool selected = row == selectedRow && col == selectedCol;

          return Container(
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(
                  width: row % 3 == 0 ? 2 : 0.5,
                  color: Colors.black,
                ),
                left: BorderSide(
                  width: col % 3 == 0 ? 2 : 0.5,
                  color: Colors.black,
                ),
                right: BorderSide(
                  width: (col + 1) % 3 == 0 ? 2 : 0.5,
                  color: Colors.black,
                ),
                bottom: BorderSide(
                  width: (row + 1) % 3 == 0 ? 2 : 0.5,
                  color: Colors.black,
                ),
              ),
            ),
            child: SudokuCell(
              number: value,
              fixed: board.fixed[row][col],
              selected: selected,
              highlighted: highlighted,
              isWrong: wrong,
              onTap: () => onCellTap(row, col),
            ),
          );
        },
      ),
    );
  }
}