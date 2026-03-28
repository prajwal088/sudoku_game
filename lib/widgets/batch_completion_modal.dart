import 'package:flutter/material.dart';

class BatchCompletionModal extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        padding: EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              'Congratulations!',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 20),
            Text(
              'Next batch unlocked! Get ready for more challenges.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16),
            ),
            SizedBox(height: 20),
            // Placeholder for celebration animation
            Icon(Icons.star, size: 50, color: Colors.yellow),
            // Additional code for actual animation would go here
          ],
        ),
      ),
    );
  }
}