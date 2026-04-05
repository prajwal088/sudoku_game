import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter/foundation.dart'; // For debugPrint
import 'analytics_service.dart';

class UserService {
  static const _keyName = "user_name";
  static const _keyId = "user_id";

  // ✅ SINGLETON INSTANCE
  static final UserService _instance = UserService._internal();
  factory UserService() => _instance;

  UserService._internal();

  final Uuid _uuid = const Uuid();
  SharedPreferences? _prefs;

  String? _cachedUserId;
  String? _cachedUserName;

  Future<void> init() async {
    try {
    _prefs = await SharedPreferences.getInstance();

    _cachedUserId = _prefs!.getString(_keyId);
    _cachedUserName = _prefs!.getString(_keyName);

    // Handle First Time User Creation
    if (_cachedUserId == null) {
      _cachedUserId = _uuid.v4();
      await _prefs!.setString(_keyId, _cachedUserId!);

      // Track: A brand new player has been created
        AnalyticsService.logUserInit(isNewUser: true);
    } else {
        // Track: An existing player has returned
        AnalyticsService.logUserInit(isNewUser: false);
      }
    } catch (e) {
      debugPrint("UserService Init Error: $e");
      AnalyticsService.logError("user_service_init_fail", e.toString());
    }
  }

  String getUserId() {
    if (_cachedUserId == null) {
      // In production, we don't want to crash. 
      // We return a fallback or log the error.
      AnalyticsService.logError("user_id_access_before_init", "ID requested before init");
      return "unknown_user";
    }
    return _cachedUserId!;
  }

  String? getUserName() {
    return _cachedUserName;
  }

  Future<void> saveUserName(String name) async {
    try {
      _cachedUserName = name;
      if (_prefs != null) {
        await _prefs!.setString(_keyName, name);
        
        // Track: User successfully updated their profile
        AnalyticsService.logNameUpdate();
      }
    } catch (e) {
      AnalyticsService.logError("save_user_name_fail", e.toString());
    }
  }
}