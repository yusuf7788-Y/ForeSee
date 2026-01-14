import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CookieManager {
  static const String _cookiesKey = 'browser_cookies';
  static const String _cookieSettingsKey = 'cookie_settings';

  static Future<Map<String, String>> getCookies() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cookiesJson = prefs.getStringList(_cookiesKey) ?? [];
      
      final cookies = <String, String>{};
      for (final cookieJson in cookiesJson) {
        try {
          final parts = Uri.decodeComponent(cookieJson).split('=');
          if (parts.length == 2) {
            cookies[parts[0]] = parts[1];
          }
        } catch (e) {
          // Hatalı cookie'leri atla
        }
      }
      
      return cookies;
    } catch (e) {
      return {};
    }
  }

  static Future<void> saveCookies(Map<String, String> cookies) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      final cookiesJson = cookies.entries.map((entry) {
        final map = <String, String>{entry.key: entry.value};
        return Uri.encodeComponent(
          map.entries.map((e) => '${e.key}=${e.value}').join(','),
        );
      }).toList();

      await prefs.setStringList(_cookiesKey, cookiesJson);
    } catch (e) {
      // Hata durumunda sessizce geç
    }
  }

  static Future<void> clearCookies() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_cookiesKey);
    } catch (e) {
      // Hata durumunda sessizce geç
    }
  }

  static Future<void> deleteCookie(String name) async {
    final cookies = await getCookies();
    cookies.remove(name);
    await saveCookies(cookies);
  }

  static Future<CookieSettings> getCookieSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final settingsJson = prefs.getString(_cookieSettingsKey);
      
      if (settingsJson != null) {
        final parts = Uri.decodeComponent(settingsJson).split(',');
        final settings = <String, String>{};
        
        for (final part in parts) {
          final keyValue = part.split('=');
          if (keyValue.length == 2) {
            settings[keyValue[0]] = keyValue[1];
          }
        }
        
        return CookieSettings(
          allowCookies: settings['allow_cookies'] == 'true',
          allowThirdParty: settings['allow_third_party'] == 'true',
          blockTrackers: settings['block_trackers'] == 'true',
          blockAds: settings['block_ads'] == 'true',
          autoClear: settings['auto_clear'] == 'true',
        );
      }
      
      return const CookieSettings(
        allowCookies: true,
        allowThirdParty: false,
        blockTrackers: true,
        blockAds: true,
        autoClear: false,
      );
    } catch (e) {
      return const CookieSettings(
        allowCookies: true,
        allowThirdParty: false,
        blockTrackers: true,
        blockAds: true,
        autoClear: false,
      );
    }
  }

  static Future<void> saveCookieSettings(CookieSettings settings) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      final settingsMap = {
        'allow_cookies': settings.allowCookies.toString(),
        'allow_third_party': settings.allowThirdParty.toString(),
        'block_trackers': settings.blockTrackers.toString(),
        'block_ads': settings.blockAds.toString(),
        'auto_clear': settings.autoClear.toString(),
      };
      
      final settingsJson = settingsMap.entries.map((entry) {
        final map = <String, String>{entry.key: entry.value};
        return Uri.encodeComponent(
          map.entries.map((e) => '${e.key}=${e.value}').join(','),
        );
      }).toList();

      await prefs.setString(_cookieSettingsKey, settingsJson.join(','));
    } catch (e) {
      // Hata durumunda sessizce geç
    }
  }

  static Future<void> clearAllCookies() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_cookiesKey);
      await prefs.remove(_cookieSettingsKey);
    } catch (e) {
      // Hata durumunda sessizce geç
    }
  }

  static Future<CookieSettings> getSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final settingsJson = prefs.getString(_cookieSettingsKey);
      
      if (settingsJson != null) {
        final parts = Uri.decodeComponent(settingsJson).split(',');
        final map = <String, bool>{};
        for (final part in parts) {
          final keyValue = part.split('=');
          if (keyValue.length == 2) {
            map[keyValue[0]] = keyValue[1] == 'true';
          }
        }
        
        return CookieSettings(
          allowCookies: map['allow_cookies'] ?? true,
          allowThirdParty: map['allow_third_party'] ?? false,
          blockTrackers: map['block_trackers'] ?? false,
          blockAds: map['block_ads'] ?? false,
          autoClear: map['auto_clear'] ?? false,
        );
      }
      
      return const CookieSettings(
        allowCookies: true,
        allowThirdParty: false,
        blockTrackers: false,
        blockAds: false,
        autoClear: false,
      );
    } catch (e) {
      return const CookieSettings(
        allowCookies: true,
        allowThirdParty: false,
        blockTrackers: false,
        blockAds: false,
        autoClear: false,
      );
    }
  }

  static Future<void> saveSettings(CookieSettings settings) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      final settingsMap = {
        'allow_cookies': settings.allowCookies.toString(),
        'allow_third_party': settings.allowThirdParty.toString(),
        'block_trackers': settings.blockTrackers.toString(),
        'block_ads': settings.blockAds.toString(),
        'auto_clear': settings.autoClear.toString(),
      };
      
      final settingsJson = settingsMap.entries.map((entry) {
        final map = <String, String>{entry.key: entry.value};
        return Uri.encodeComponent(
          map.entries.map((e) => '${e.key}=${e.value}').join(','),
        );
      }).toList();

      await prefs.setString(_cookieSettingsKey, settingsJson.join(','));
    } catch (e) {
      // Hata durumunda sessizce geç
    }
  }
}

class CookieSettings {
  final bool allowCookies;
  final bool allowThirdParty;
  final bool blockTrackers;
  final bool blockAds;
  final bool autoClear;

  const CookieSettings({
    required this.allowCookies,
    required this.allowThirdParty,
    required this.blockTrackers,
    required this.blockAds,
    required this.autoClear,
  });

  Map<String, dynamic> toJson() {
    return {
      'allowCookies': allowCookies,
      'allowThirdParty': allowThirdParty,
      'blockTrackers': blockTrackers,
      'blockAds': blockAds,
      'autoClear': autoClear,
    };
  }

  factory CookieSettings.fromJson(Map<String, dynamic> json) {
    return CookieSettings(
      allowCookies: json['allowCookies'] == 'true',
      allowThirdParty: json['allow_third_party'] == 'true',
      blockTrackers: json['block_trackers'] == 'true',
      blockAds: json['block_ads'] == 'true',
      autoClear: json['auto_clear'] == 'true',
    );
  }
}
