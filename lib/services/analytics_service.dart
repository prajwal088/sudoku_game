import 'package:firebase_analytics/firebase_analytics.dart';

class AnalyticsService {
  static final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;

  /// ==========================================================================
  /// GAME SCREEN TRACKS
  /// ==========================================================================

  /// Track when a player starts a level
  static Future<void> logGameStart(int world, int level) async {
    await _analytics.logLevelStart(
      levelName: 'world_${world}_level_$level',
    );
    
    // Custom event for granular filtering
    await _analytics.logEvent(
      name: 'level_start_detail',
      parameters: {
        'world_id': world,
        'level_number': level,
      },
    );
  }

  /// Track when a player wins/completes a level
  static Future<void> logLevelComplete({
    required int world,
    required int level,
    required int stars,
    required int seconds,
  }) async {
    await _analytics.logEvent(
      name: 'level_complete',
      parameters: {
        'world_id': world,
        'level_id': level,
        'stars_earned': stars,
        'completion_time_seconds': seconds,
      },
    );
  }

  /// Track when a player exits without finishing
  static Future<void> logLevelAbandoned({
    required int world,
    required int level,
    required int secondsPlayed,
  }) async {
    await _analytics.logEvent(
      name: 'level_abandoned',
      parameters: {
        'world_id': world,
        'level_id': level,
        'seconds_played': secondsPlayed,
      },
    );
  }

  /// Track help-seeking behavior (Hints)
  static Future<void> logHintUsed(int world, int level) async {
    await _analytics.logEvent(
      name: 'use_hint',
      parameters: {
        'world_id': world,
        'level_id': level,
      },
    );
  }

/*
  /// Track Undo usage
  static Future<void> logUndoUsed(int world, int level) async {
    await _analytics.logEvent(
      name: 'use_undo',
      parameters: {
        'world_id': world,
        'level_id': level,
      },
    );
  }
  */

  /// ==========================================================================
  /// WIN SCREEN TRACKS
  /// ==========================================================================

  /// Track when a user finishes a whole world (25 levels)
  static Future<void> logWorldComplete(int worldId) async {
    await _analytics.logEvent(
      name: 'world_complete',
      parameters: {
        'world_id': worldId,
      },
    );
  }

  /// Track how players navigate away from the Win Screen
  static Future<void> logNavigation(String destination, int fromLevel) async {
    await _analytics.logEvent(
      name: 'win_screen_nav',
      parameters: {
        'destination': destination, // e.g., 'next_level', 'replay', 'back_to_map'
        'from_level': fromLevel,
      },
    );
  }

  /// ==========================================================================
  /// LEVEL MAP SCREEN TRACKS
  /// ==========================================================================

  /// Track when a user opens a specific world map
  static Future<void> logWorldView(int worldId) async {
    await _analytics.logEvent(
      name: 'world_view',
      parameters: {'world_id': worldId},
    );
  }

  /// Track which level is chosen and if it's a new challenge or a replay
  static Future<void> logLevelSelect({
    required int world, 
    required int level, 
    required bool isReplay,
  }) async {
    await _analytics.logEvent(
      name: 'level_select',
      parameters: {
        'world_id': world,
        'level_id': level,
        'is_replay': isReplay ? 1 : 0,
      },
    );
  }

  /// Track attempts to open locked levels (helps gauge player eagerness)
  static Future<void> logLockedLevelClick(int world, int level) async {
    await _analytics.logEvent(
      name: 'locked_level_click',
      parameters: {
        'world_id': world,
        'level_id': level,
      },
    );
  }

  /// Helper for custom generic events (like the refresh button)
  static Future<void> logEvent({required String name, Map<String, Object>? parameters}) async {
    await _analytics.logEvent(name: name, parameters: parameters);
  }

  /// ==========================================================================
  /// WORLD MAP SCREEN TRACKS
  /// ==========================================================================

  /// Track which world a user is entering
  static Future<void> logWorldEntry(int worldId) async {
    await _analytics.logEvent(
      name: 'world_entry',
      parameters: {'world_id': worldId},
    );
  }

  /// Track when someone tries to open a locked world
  static Future<void> logLockedWorldClick(int worldId) async {
    await _analytics.logEvent(
      name: 'locked_world_attempt',
      parameters: {'world_id': worldId},
    );
  }

   /// Global error tracking for debugging production issues
  static Future<void> logError(String errorCode, String message) async {
    await _analytics.logEvent(
      name: 'app_error',
      parameters: {
        'error_code': errorCode,
        'error_message': message.substring(0, 40), // Firebase param limit is 40 chars
      },
    );
  }

  /// ==========================================================================
  /// HOME SCREEN TRACKS
  /// ==========================================================================

  /// Track when a user views the home screen
  static Future<void> logHomeView() async {
    await _analytics.logEvent(name: 'home_screen_view');
  }

  /// ==========================================================================
  /// SETTINGS & USER PROFILE TRACKS
  /// ==========================================================================

  /// Track when the user successfully updates their display name
  static Future<void> logNameUpdate() async {
    await _analytics.logEvent(name: 'user_update_name');
  }

  /// Track when a user copies their ID (often for support reasons)
  static Future<void> logUserIdCopy() async {
    await _analytics.logEvent(name: 'user_copy_id');
  }

  /// Track when a user clicks an external link (Privacy, Terms, Website)
  static Future<void> logExternalLink(String linkName) async {
    await _analytics.logEvent(
      name: 'settings_link_click',
      parameters: {'link_target': linkName},
    );
  }

  /// Track the "Nuclear Option" - when a user wipes their progress
  static Future<void> logProgressReset() async {
    await _analytics.logEvent(name: 'user_reset_all_progress');
  }

  /// ==========================================================================
  /// STATISTICS SCREEN TRACKS
  /// ==========================================================================
  
  /// Track a summary of user stats
  static Future<void> logStatsSnapshot(Map<String, Object> stats) async {
    await _analytics.logEvent(
      name: 'statistics_snapshot',
      parameters: stats,
    );
  }

  /// ==========================================================================
  /// PROGRESS Service Tracks
  /// ==========================================================================

  /// Track when a user successfully finishes a level
  static Future<void> logLevelCompleted({
    required int levelId,
    required int worldId,
    required int stars,
    required int timeSeconds,
    required bool isFirstTime,
  }) async {
    await _analytics.logEvent(
      name: 'level_completed',
      parameters: {
        'level_id': levelId,
        'world_id': worldId,
        'stars': stars,
        'time_seconds': timeSeconds,
        'is_first_completion': isFirstTime ? 1 : 0,
      },
    );
  }

  /// Track a major milestone: Unlocking a new world
  static Future<void> logWorldUnlocked(int newWorldId) async {
    await _analytics.logEvent(
      name: 'world_unlocked',
      parameters: {'unlocked_world_id': newWorldId},
    );
  }

  /// Track when the user views their statistics
  static Future<void> logStatisticsView() async {
    await _analytics.logEvent(name: 'statistics_view');
  }

  /// ==========================================================================
  /// SAVE SYSTEM TRACKS
  /// ==========================================================================

  /// Track technical storage failures (Disk Full, Corrupted JSON, Permission Denied)
  static Future<void> logStorageError({
    required String operation, // e.g., 'save_level', 'load_all', 'clear_disk'
    required String errorMessage,
    int? levelId,
  }) async {
    await _analytics.logEvent(
      name: 'system_storage_error',
      parameters: {
        'operation_type': operation,
        'level_id': levelId ?? -1, // -1 indicates a global/non-level error
        // Ensure the message fits Firebase's 100 character limit
        'error_details': errorMessage.length > 100 
            ? errorMessage.substring(0, 100) 
            : errorMessage,
      },
    );
  }

  /// ==========================================================================
  /// USER IDENTITY TRACKS (Used by UserService)
  /// ==========================================================================

  /// Track when the app initializes a user session
  static Future<void> logUserInit({required bool isNewUser}) async {
    await _analytics.logEvent(
      name: 'user_session_init',
      parameters: {
        'is_new_player': isNewUser ? 1 : 0,
      },
    );
  }
  
}