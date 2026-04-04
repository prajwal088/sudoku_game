import 'package:flutter/material.dart';
import '../services/progress_service.dart';
import '../widgets/statistics_card.dart';

class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({super.key});

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  final ProgressService _progressService = ProgressService();
  Map<String, dynamic>? _stats;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    final data = await _progressService.getGlobalStats();
    setState(() {
      _stats = data;
    });
  }

  String _formatTime(int seconds) {
    int minutes = seconds ~/ 60;
    int remainingSeconds = seconds % 60;
    return "$minutes:${remainingSeconds.toString().padLeft(2, '0')}";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text('Lifetime Statistics'),
        elevation: 0,
      ),
      body: _stats == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16.0),
              children: [
                StatisticsCard(
                  title: "Levels Completed",
                  value: _stats!["totalLevels"],
                  progress: _stats!["completionPercent"],
                  icon: Icons.checklist_rtl,
                ),
                const SizedBox(height: 12),
                StatisticsCard(
                  title: "Total Stars Earned",
                  value: _stats!["totalStars"],
                  progress: (_stats!["totalStars"] / 375).clamp(0.0, 1.0), // 375 max stars
                  icon: Icons.star,
                ),
                const SizedBox(height: 12),
                _buildSimpleStatTile("Total Time Played", _formatTime(_stats!["totalTime"]), Icons.timer),
                const SizedBox(height: 12),
                _buildSimpleStatTile("Avg. Solve Time", _formatTime(_stats!["avgSpeed"]), Icons.speed),
              ],
            ),
    );
  }

  // A simpler tile for stats that don't need a progress bar
  Widget _buildSimpleStatTile(String title, String value, IconData icon) {
    return Card(
      elevation: 2,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.blue.shade50,
          child: Icon(icon, color: Colors.blue),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        trailing: Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500)),
      ),
    );
  }
}