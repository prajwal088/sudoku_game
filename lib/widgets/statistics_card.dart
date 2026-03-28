import 'package:flutter/material.dart';

class StatisticsCard extends StatelessWidget {
  final String title;
  final int value;
  final double progress;
  final IconData icon;

  StatisticsCard({required this.title, required this.value, required this.progress, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: <Widget>[
            Icon(icon, size: 40),
            SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  SizedBox(height: 4),
                  Text(value.toString(), style: TextStyle(fontSize: 24)),
                  LinearProgressIndicator(value: progress),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}