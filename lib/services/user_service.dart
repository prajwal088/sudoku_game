import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

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
    _prefs = await SharedPreferences.getInstance();

    _cachedUserId = _prefs!.getString(_keyId);
    _cachedUserName = _prefs!.getString(_keyName);

    if (_cachedUserId == null) {
      _cachedUserId = _uuid.v4();
      await _prefs!.setString(_keyId, _cachedUserId!);
    }
  }

  String getUserId() {
    if (_cachedUserId == null) {
      throw Exception("UserService not initialized. Call init() first.");
    }
    return _cachedUserId!;
  }

  String? getUserName() {
    return _cachedUserName;
  }

  Future<void> saveUserName(String name) async {
    _cachedUserName = name;
    await _prefs!.setString(_keyName, name);
  }
}