import 'package:flutter/material.dart';

/// ============================================================================
/// StatisticsCard
/// ----------------------------------------------------------------------------
/// A card showing an icon, a title, a whole-number value and a progress bar.
///
/// - [progress] is a fraction from 0.0 to 1.0. Values outside that range (or
///   NaN) are clamped, so a bad number can never break the bar.
/// - The card is announced to screen readers as one item, for example
///   "Levels Completed: 12, 4 percent complete".
/// - It uses zero outer margin and the same elevation as the simple stat
///   tiles on StatisticsScreen, so all cards on that screen line up.
/// ============================================================================
class StatisticsCard extends StatelessWidget {
  final String title;
  final int value;

  /// Fraction from 0.0 to 1.0.
  final double progress;

  final IconData icon;

  const StatisticsCard({
    super.key,
    required this.title,
    required this.value,
    required this.progress,
    required this.icon,
  });

  static const TextStyle _titleStyle = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.bold,
  );

  static const TextStyle _valueStyle = TextStyle(fontSize: 24);

  @override
  Widget build(BuildContext context) {
    final double safeProgress = progress.isNaN
        ? 0.0
        : progress.clamp(0.0, 1.0).toDouble();

    // Truncated (not rounded) so 99.6% never reads as "100 percent".
    final int percent = (safeProgress * 100).floor();

    return Semantics(
      container: true,
      label: '$title: $value, $percent percent complete',
      // The visible text and bar are summarised by the label.
      excludeSemantics: true,
      child: Card(
        // Matches the other cards on StatisticsScreen. The default Card margin
        // (4 px) made these cards narrower than their neighbours.
        margin: EdgeInsets.zero,
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: <Widget>[
              Icon(icon, size: 40),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(title, style: _titleStyle),
                    const SizedBox(height: 4),
                    Text('$value', style: _valueStyle),
                    LinearProgressIndicator(value: safeProgress),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}