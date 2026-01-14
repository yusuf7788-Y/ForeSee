import 'package:shared_preferences/shared_preferences.dart';

class PrivateModeService {
  static const String _privateModeKey = 'private_mode_enabled';

  static Future<bool> isPrivateModeEnabled() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_privateModeKey) ?? false;
    } catch (e) {
      return false;
    }
  }

  static Future<void> setPrivateMode(bool enabled) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_privateModeKey, enabled);
    } catch (e) {
      // Hata durumunda sessizce geç
    }
  }

  static Future<void> togglePrivateMode() async {
    final current = await isPrivateModeEnabled();
    await setPrivateMode(!current);
  }
}
