import 'package:flutter/material.dart';
import '../core/constants/app_colors.dart';

class SudokuCell extends StatelessWidget {
  final int number;
  final bool fixed;
  final bool selected;
  final bool highlighted;
  final bool isWrong;
  final VoidCallback onTap;

  const SudokuCell({
    super.key,
    required this.number,
    required this.fixed,
    required this.selected,
    required this.highlighted,
    required this.isWrong,
    required this.onTap,
  });

  Color _getBackgroundColor() {
    if (isWrong) return Colors.red.shade200;
    if (selected) return Colors.blue.shade300;
    if (highlighted) return Colors.blue.shade100;
    return Colors.white;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: _getBackgroundColor(),
          border: Border.all(
            color: AppColors.gridBorder,
            width: 0.5,
          ),
        ),
        child: Center(
          child: Text(
            number == 0 ? "" : "$number",
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: fixed
                  ? AppColors.fixedNumber
                  : AppColors.userNumber,
            ),
          ),
        ),
      ),
    );
  }
}