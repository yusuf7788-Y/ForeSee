import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/site_permissions_service.dart';

class ForeSettingsService {
  static const String _settingsKey = 'fore_settings';

  static Future<Map<String, dynamic>> getSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final settingsJson = prefs.getString(_settingsKey);
      
      if (settingsJson != null) {
        final parts = Uri.decodeComponent(settingsJson).split(',');
        final settings = <String, dynamic>{};
        
        for (final part in parts) {
          final keyValue = part.split('=');
          if (keyValue.length == 2) {
            settings[keyValue[0]] = keyValue[1];
          }
        }
        
        return settings;
      }
      
      return {
        'theme_mode': 'system',
        'font_size': 'medium',
        'auto_clear_cache': true,
        'data_saving': false,
        'ad_blocker': false,
        'reading_mode': false,
        'quick_access': true,
        'developer_tools': false,
        'responsive_test': false,
        'network_monitor': false,
      };
    } catch (e) {
      return {
        'theme_mode': 'system',
        'font_size': 'medium',
        'auto_clear_cache': true,
        'data_saving': false,
        'ad_blocker': false,
        'reading_mode': false,
        'quick_access': true,
        'developer_tools': false,
        'responsive_test': false,
        'network_monitor': false,
      };
    }
  }

  static Future<void> saveSettings(Map<String, dynamic> settings) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      final settingsMap = settings.entries.map((entry) {
        final map = <String, String>{entry.key: entry.value};
        return Uri.encodeComponent(
          map.entries.map((e) => '${e.key}=${e.value}').join(','),
        );
      }).toList();

      await prefs.setString(_settingsKey, settingsMap.join(','));
    } catch (e) {
      // Hata durumunda sessizce geç
    }
  }

  static Future<Map<String, bool>> loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final settingsJson = prefs.getString(_settingsKey);
      
      if (settingsJson != null) {
        final parts = Uri.decodeComponent(settingsJson).split(',');
        final map = <String, bool>{};
        for (final part in parts) {
          final keyValue = part.split('=');
          if (keyValue.length == 2) {
            map[keyValue[0]] = keyValue[1] == 'true';
          }
        }
        
        return map;
      }
      
      return {
        'javascript': true,
        'autoplay': false,
        'images': true,
        'popups': false,
        'location': false,
        'camera': false,
        'microphone': false,
      };
    } catch (e) {
      return {
        'javascript': true,
        'autoplay': false,
        'images': true,
        'popups': false,
        'location': false,
        'camera': false,
        'microphone': false,
      };
    }
  }

  static Future<void> updateSetting(String key, bool value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final settings = await loadSettings();
      settings[key] = value;
      
      final settingsMap = settings.entries.map((entry) {
        final map = <String, String>{entry.key: entry.value.toString()};
        return Uri.encodeComponent(
          map.entries.map((e) => '${e.key}=${e.value}').join(','),
        );
      }).toList();

      await prefs.setString(_settingsKey, settingsMap.join(','));
    } catch (e) {
      // Hata durumunda sessizce geç
    }
  }
}
