import 'package:flutter/material.dart';

class StatisticsScreen extends StatelessWidget {
  const StatisticsScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Lifetime Statistics'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[ 
            Text('Total Time: [Your Total Time] seconds', style: TextStyle(fontSize: 18)),
            SizedBox(height: 10),
            Text('Stars Earned: [Your Stars Earned]', style: TextStyle(fontSize: 18)),
            SizedBox(height: 10),
            Text('Levels Completed Without Hints: [Your Levels Without Hints]', style: TextStyle(fontSize: 18)),
            SizedBox(height: 10),
            Text('Average Completion Speed: [Your Average Completion Speed] seconds', style: TextStyle(fontSize: 18)),
          ],
        ),
      ),
    );
  }
}