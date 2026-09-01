import 'package:shared_preferences/shared_preferences.dart';

abstract interface class EntitlementStorage {
  Future<String?> read(String key);

  Future<void> write(String key, String value);
}

class SharedPreferencesEntitlementStorage implements EntitlementStorage {
  @override
  Future<String?> read(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(key);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> write(String key, String value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(key, value);
    } catch (_) {}
  }
}

class MemoryEntitlementStorage implements EntitlementStorage {
  final Map<String, String> _values = {};

  @override
  Future<String?> read(String key) async => _values[key];

  @override
  Future<void> write(String key, String value) async {
    _values[key] = value;
  }
}