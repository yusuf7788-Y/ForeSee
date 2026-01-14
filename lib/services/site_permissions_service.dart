import 'package:shared_preferences/shared_preferences.dart';

class SitePermissionsManager {
  static const String _permissionsKey = 'site_permissions';

  static Future<Map<String, bool>> getPermissions() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final permissionsJson = prefs.getStringList(_permissionsKey) ?? [];
      
      final permissions = <String, bool>{};
      for (final permissionJson in permissionsJson) {
        try {
          final parts = Uri.decodeComponent(permissionJson).split(',');
          final map = <String, bool>{};
          for (final part in parts) {
            final keyValue = part.split('=');
            if (keyValue.length == 2) {
              map[keyValue[0]] = keyValue[1] == 'true';
            }
          }
          permissions.addAll(map);
        } catch (e) {
          // Hatalı izinle
        }
      }
      
      return permissions;
    } catch (e) {
      return {
        'camera': false,
        'microphone': false,
        'location': false,
        'notifications': false,
        'geolocation': false,
        'fullscreen': false,
        'clipboard': false,
        'cookies': true,
        'third_party_cookies': false,
        'trackers': false,
        'ads': false,
      };
    }
  }

  static Future<void> updatePermission(String permission, bool granted) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final permissions = await getPermissions();
      permissions[permission] = granted;
      
      final permissionsJson = permissions.entries.map((entry) {
        final map = <String, String>{entry.key: entry.value.toString()};
        return Uri.encodeComponent(
          map.entries.map((e) => '${e.key}=${e.value}').join(','),
        );
      }).toList();

      await prefs.setStringList(_permissionsKey, permissionsJson);
    } catch (e) {
      // Hata durumunda sessizce geç
    }
  }

  static Future<void> clearAllPermissions() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_permissionsKey);
    } catch (e) {
      // Hata durumunda sessizce geç
    }
  }

  static Future<bool> hasPermission(String permission) async {
    final permissions = await getPermissions();
    return permissions[permission] ?? false;
  }
}
