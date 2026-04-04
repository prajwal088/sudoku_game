import 'package:firebase_analytics/firebase_analytics.dart';

class AnalyticsService {
  static final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;

  // Track when a player starts a level
  static Future<void> logGameStart(int world, int level) async {
    await _analytics.logEvent(
      name: 'level_start',
      parameters: {
        'world_id': world,
        'level_number': level,
      },
    );
  }

  // Track when a player wins
  static Future<void> logLevelComplete(int world, int level, int mistakes) async {
    await _analytics.logEvent(
      name: 'level_complete',
      parameters: {
        'world_id': world,
        'level_number': level,
        'mistakes_made': mistakes,
      },
    );
  }

  // Track when a hint is used (important for balancing difficulty!)
  static Future<void> logHintUsed(int world, int level) async {
    await _analytics.logEvent(
      name: 'hint_used',
      parameters: {
        'world_id': world,
        'level_number': level,
      },
    );
  }
}