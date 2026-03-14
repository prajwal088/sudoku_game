import 'package:flutter/material.dart';

class NumberPad extends StatelessWidget {
  final Function(int) onNumberSelected;
  final VoidCallback onUndo;
  final VoidCallback onHint;
  final VoidCallback onErase;

  const NumberPad({
    super.key,
    required this.onNumberSelected,
    required this.onUndo,
    required this.onHint,
    required this.onErase,
  });

  Widget buildNumberButton(int number) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: ElevatedButton(
          onPressed: () => onNumberSelected(number),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
            backgroundColor: Colors.blue.shade500,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: Text(
            number.toString(),
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  Widget buildActionButton(
      IconData icon, VoidCallback onPressed, Color color) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
            backgroundColor: color,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: Icon(icon, size: 24),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [

        /// Row 1
        Row(
          children: [
            buildNumberButton(1),
            buildNumberButton(2),
            buildNumberButton(3),
          ],
        ),

        /// Row 2
        Row(
          children: [
            buildNumberButton(4),
            buildNumberButton(5),
            buildNumberButton(6),
          ],
        ),

        /// Row 3
        Row(
          children: [
            buildNumberButton(7),
            buildNumberButton(8),
            buildNumberButton(9),
          ],
        ),

        const SizedBox(height: 8),

        /// Action Buttons
        Row(
          children: [
            buildActionButton(Icons.undo, onUndo, Colors.orange),
            buildActionButton(Icons.lightbulb, onHint, Colors.green),
            buildActionButton(Icons.backspace, onErase, Colors.red),
          ],
        ),
      ],
    );
  }
}