import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

class UserService {
  static const _keyName = "user_name";
  static const _keyId = "user_id";

  final uuid = const Uuid();

  Future<String> getUserId() async {
    final prefs = await SharedPreferences.getInstance();

    String? id = prefs.getString(_keyId);

    if (id == null) {
      id = uuid.v4();
      await prefs.setString(_keyId, id);
    }

    return id;
  }

  Future<String?> getUserName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyName);
  }

  Future<void> saveUserName(String name) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyName, name);
  }
}