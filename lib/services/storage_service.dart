import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/chat.dart';
import '../models/user_profile.dart';
import '../models/player_inventory.dart';
import '../models/chat_folder.dart';
import 'home_widget_service.dart';

import 'database_service.dart';

class StorageService {
  static const String _chatsKey = 'chats';
  static const String _userProfileKey = 'user_profile';
  static const String _isSqliteMigratedKey = 'is_sqlite_migrated_v1';
  // ... existing keys ...
  static const String _currentChatIdKey = 'current_chat_id';
  static const String _userMemoryKey = 'user_memory';
  static const String _customPromptKey = 'custom_prompt';
  static const String _notificationsEnabledKey = 'notifications_enabled';
  static const String _fontSizeIndexKey = 'font_size_index';
  static const String _fontFamilyKey = 'font_family';
  static const String _themeIndexKey = 'theme_index';
  static const String _assistantIntegrationKey =
      'assistant_integration_enabled';
  static const String _isSmartContextEnabledKey = 'isSmartContextEnabled';
  static const String _isUsageTrackerEnabledKey = 'isUsageTrackerEnabled';
  static const String _usageTimeThresholdKey = 'usageTimeThreshold';
  static const String _totalCodeLinesKey = 'total_code_lines';
  static const String _languageUsageKey = 'language_usage_stats';
  static const String _weeklyUsageKey =
      'weekly_app_usage_stats'; // Map<String, int> date->minutes
  static const String _contextAppsKey = 'context_apps';
  static const String _playerInventoryKey = 'player_inventory';
  static const String _lockMemoryAiKey = 'lock_memory_ai';
  static const String _lockPromptAiKey = 'lock_prompt_ai';
  static const String _currentInputKey = 'current_input';
  static const String _currentTabKey = 'current_tab';
  static const String _currentAITitleKey = 'current_ai_title';
  static const String _aiFontFamilyKey = 'ai_font_family';
  static const String _userFontFamilyKey = 'user_font_family';
  static const String _isAutoBackupEnabledKey = 'is_auto_backup_enabled';
  static const String _hasShownRecoveryPromptKey = 'has_shown_recovery_prompt';
  static const String _lastAutoBackupTimeKey = 'last_auto_backup_time';
  static const String _chatFoldersKey = 'chat_folders'; // Klasörler için key
  static const String _isGmailAiAlwaysAllowedKey = 'is_gmail_ai_always_allowed';
  static const String _isGithubAiAlwaysAllowedKey =
      'is_github_ai_always_allowed';
  static const String _githubAccessTokenKey = 'github_access_token';
  static const String _elevenLabsVoiceIdKey = 'eleven_labs_voice_id';
  static const String _isRememberPastChatsEnabledKey =
      'is_remember_past_chats_enabled';
  static const String _isGmailConnectedKey = 'is_gmail_connected';
  static const String _localNotificationsEnabledKey =
      'local_notifications_enabled';
  static const String _fcmNotificationsEnabledKey = 'fcm_notifications_enabled';

  Future<bool> getIsGmailConnected() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_isGmailConnectedKey) ?? false;
  }

  Future<void> setIsGmailConnected(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_isGmailConnectedKey, value);
  }

  Future<List<ChatFolder>> loadFolders() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_chatFoldersKey);
    if (jsonStr == null) return [];
    try {
      final List<dynamic> list = jsonDecode(jsonStr);
      return list.map((e) => ChatFolder.fromJson(e)).toList();
    } catch (e) {
      print('Klasör yükleme hatası: $e');
      return [];
    }
  }

  Future<void> saveFolders(List<ChatFolder> folders) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = jsonEncode(folders.map((f) => f.toJson()).toList());
    await prefs.setString(_chatFoldersKey, jsonStr);
  }

  Future<bool> getLockMemoryAi() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_lockMemoryAiKey) ?? false;
  }

  Future<void> setLockMemoryAi(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_lockMemoryAiKey, value);
  }

  Future<bool> getLockPromptAi() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_lockPromptAiKey) ?? false;
  }

  Future<void> setLockPromptAi(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_lockPromptAiKey, value);
  }

  /// Migrates chats from SharedPreferences to SQLite if not already done.
  Future<void> _migrateToSqliteIfNeeded() async {
    final prefs = await SharedPreferences.getInstance();
    final isMigrated = prefs.getBool(_isSqliteMigratedKey) ?? false;

    if (isMigrated) return;

    final chatsJson = prefs.getString(_chatsKey);
    if (chatsJson != null) {
      try {
        final List<dynamic> chatsList = jsonDecode(chatsJson);
        final chats = chatsList.map((json) => Chat.fromJson(json)).toList();

        final dbService = DatabaseService();
        for (var chat in chats) {
          await dbService.saveChat(chat);
        }

        // Clear legacy data only after successful migration
        await prefs.remove(_chatsKey);
        print('✅ Migration to SQLite successful. ${_chatsKey} cleaned up.');
      } catch (e) {
        print('❌ Migration failed: $e');
        // Do not verify migration if it failed, so we try again next time
        return;
      }
    }

    await prefs.setBool(_isSqliteMigratedKey, true);
  }

  Future<List<Chat>> loadChats() async {
    // Ensure migration checks run first
    await _migrateToSqliteIfNeeded();

    // Load from SQLite
    return await DatabaseService().getAllChats();
  }

  Future<void> saveChats(List<Chat> chats) async {
    final dbService = DatabaseService();
    for (var chat in chats) {
      await dbService.saveChat(chat);
    }

    HomeWidgetService().updateRecapWidget();
  }

  Future<void> saveSingleChat(Chat chat) async {
    await DatabaseService().saveChat(chat);
    HomeWidgetService().updateRecapWidget();
  }

  Future<void> deleteChat(String chatId) async {
    await DatabaseService().deleteChat(chatId);
    HomeWidgetService().updateRecapWidget();
  }

  Future<UserProfile?> loadUserProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final profileJson = prefs.getString(_userProfileKey);

    if (profileJson == null) {
      return null;
    }

    return UserProfile.fromJson(jsonDecode(profileJson));
  }

  Future<void> saveUserProfile(UserProfile profile) async {
    final prefs = await SharedPreferences.getInstance();
    final profileJson = jsonEncode(profile.toJson());
    await prefs.setString(_userProfileKey, profileJson);
  }

  Future<String?> getCurrentChatId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_currentChatIdKey);
  }

  Future<void> setCurrentChatId(String chatId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_currentChatIdKey, chatId);
  }

  Future<void> clearCurrentChatId() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_currentChatIdKey);
  }

  // Kullanıcı belleği fonksiyonları
  Future<String> getUserMemory() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_userMemoryKey) ?? '';
  }

  Future<void> saveUserMemory(String memory) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userMemoryKey, memory);
  }

  // Özel prompt fonksiyonları
  Future<String> getCustomPrompt() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_customPromptKey) ?? '';
  }

  Future<void> saveCustomPrompt(String prompt) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_customPromptKey, prompt);
  }

  Future<bool> getNotificationsEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_notificationsEnabledKey) ?? true;
  }

  Future<void> setNotificationsEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_notificationsEnabledKey, enabled);
  }

  Future<int> getFontSizeIndex() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_fontSizeIndexKey) ?? 2;
  }

  Future<void> setFontSizeIndex(int index) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_fontSizeIndexKey, index);
  }

  Future<String?> getFontFamily() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_fontFamilyKey);
  }

  Future<void> setFontFamily(String fontFamily) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_fontFamilyKey, fontFamily);
  }

  Future<String?> getAiFontFamily() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_aiFontFamilyKey);
  }

  Future<void> setAiFontFamily(String fontFamily) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_aiFontFamilyKey, fontFamily);
  }

  Future<String?> getUserFontFamily() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_userFontFamilyKey);
  }

  Future<void> setUserFontFamily(String fontFamily) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userFontFamilyKey, fontFamily);
  }

  Future<int> getThemeIndex() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_themeIndexKey) ?? 2;
  }

  Future<void> setThemeIndex(int index) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_themeIndexKey, index);
  }

  Future<void> savePrimaryColor(String colorHex) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('custom_primary_color', colorHex);
  }

  Future<String?> getPrimaryColor() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('custom_primary_color');
  }

  Future<void> clearPrimaryColor() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('custom_primary_color');
  }

  Future<bool> getIsSmartContextEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_isSmartContextEnabledKey) ?? false;
  }

  Future<void> saveIsSmartContextEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_isSmartContextEnabledKey, value);
  }

  Future<bool> getIsUsageTrackerEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_isUsageTrackerEnabledKey) ?? false;
  }

  Future<void> saveIsUsageTrackerEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_isUsageTrackerEnabledKey, value);
  }

  Future<double> getUsageTimeThreshold() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(_usageTimeThresholdKey) ?? 90.0;
  }

  Future<void> saveUsageTimeThreshold(double value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_usageTimeThresholdKey, value);
  }

  Future<bool> getAssistantIntegrationEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_assistantIntegrationKey) ?? false;
  }

  Future<void> setAssistantIntegrationEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_assistantIntegrationKey, enabled);
  }

  Future<bool> isAutoBackupEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_isAutoBackupEnabledKey) ?? true;
  }

  Future<void> setAutoBackupEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_isAutoBackupEnabledKey, enabled);
  }

  Future<bool> getHasShownRecoveryPrompt() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_hasShownRecoveryPromptKey) ?? false;
  }

  Future<void> setHasShownRecoveryPrompt(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_hasShownRecoveryPromptKey, value);
  }

  Future<DateTime?> getLastAutoBackupTime() async {
    final prefs = await SharedPreferences.getInstance();
    final iso = prefs.getString(_lastAutoBackupTimeKey);
    return iso != null ? DateTime.parse(iso) : null;
  }

  Future<void> setLastAutoBackupTime(DateTime time) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastAutoBackupTimeKey, time.toIso8601String());
  }

  Future<void> resetAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }

  Future<void> clearUserProfile() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_userProfileKey);
  }

  Future<void> resetDataExceptProfile() async {
    final userProfile = await loadUserProfile();
    await resetAll();
    if (userProfile != null) {
      await saveUserProfile(userProfile);
    }
  }

  // Player Inventory (FsCoin, Skins etc.)
  Future<PlayerInventory> loadPlayerInventory() async {
    final prefs = await SharedPreferences.getInstance();
    final inventoryJson = prefs.getString(_playerInventoryKey);
    if (inventoryJson == null) {
      return PlayerInventory(fsCoinBalance: 50); // Start with 50 coins
    }
    return PlayerInventory.fromJson(jsonDecode(inventoryJson));
  }

  Future<void> savePlayerInventory(PlayerInventory inventory) async {
    final prefs = await SharedPreferences.getInstance();
    final inventoryJson = jsonEncode(inventory.toJson());
    await prefs.setString(_playerInventoryKey, inventoryJson);
  }

  // --- İstatistikler ---

  Future<int> getTotalCodeLines() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_totalCodeLinesKey) ?? 0;
  }

  Future<void> incrementTotalCodeLines(int count) async {
    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getInt(_totalCodeLinesKey) ?? 0;
    await prefs.setInt(_totalCodeLinesKey, current + count);

    // Widget'ı güncelle
    HomeWidgetService().updateStatsWidget();
  }

  Future<Map<String, int>> getLanguageUsageStats() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_languageUsageKey);
    if (jsonStr == null) return {};
    try {
      return Map<String, int>.from(jsonDecode(jsonStr));
    } catch (_) {
      return {};
    }
  }

  Future<void> updateLanguageUsage(String language, int lines) async {
    final prefs = await SharedPreferences.getInstance();
    final stats = await getLanguageUsageStats();
    final current = stats[language] ?? 0;
    stats[language] = current + lines;
    await prefs.setString(_languageUsageKey, jsonEncode(stats));
  }

  Future<Map<String, int>> getWeeklyUsageStats() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_weeklyUsageKey);
    if (jsonStr == null) return {};
    try {
      return Map<String, int>.from(jsonDecode(jsonStr));
    } catch (_) {
      return {};
    }
  }

  Future<void> addUsageMinutes(int minutes) async {
    final prefs = await SharedPreferences.getInstance();
    final stats = await getWeeklyUsageStats();
    final now = DateTime.now();
    final key =
        "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";

    final current = stats[key] ?? 0;
    stats[key] = current + minutes;

    await prefs.setString(_weeklyUsageKey, jsonEncode(stats));

    // Widget'ı güncelle
    HomeWidgetService().updateStatsWidget();
  }

  Future<void> addChatUsageMinutes(String chatId, int minutes) async {
    final chats = await loadChats();
    final index = chats.indexWhere((c) => c.id == chatId);
    if (index != -1) {
      chats[index] = chats[index].copyWith(
        usageMinutes: chats[index].usageMinutes + minutes,
      );
      await saveChats(chats);
    }
  }

  // Input ve Tab yönetimi için yeni metotlar
  Future<String> getCurrentAITitle() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_currentAITitleKey) ?? '';
  }

  Future<void> saveCurrentAITitle(String title) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_currentAITitleKey, title);
  }

  Future<String> getCurrentInput() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_currentInputKey) ?? '';
  }

  Future<void> saveCurrentInput(String input) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_currentInputKey, input);
  }

  Future<int> getCurrentTab() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_currentTabKey) ?? 0;
  }

  Future<void> saveCurrentTab(int tab) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_currentTabKey, tab);
  }

  static const String _isAutoTitleEnabledKey = 'is_auto_title_enabled';

  Future<bool> getIsAutoTitleEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_isAutoTitleEnabledKey) ?? false;
  }

  Future<void> setIsAutoTitleEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_isAutoTitleEnabledKey, value);
  }

  Future<bool> getIsGmailAiAlwaysAllowed() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_isGmailAiAlwaysAllowedKey) ?? false;
  }

  Future<void> setIsGmailAiAlwaysAllowed(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_isGmailAiAlwaysAllowedKey, value);
  }

  Future<bool> getIsGithubAiAlwaysAllowed() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_isGithubAiAlwaysAllowedKey) ?? false;
  }

  Future<void> setIsGithubAiAlwaysAllowed(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_isGithubAiAlwaysAllowedKey, value);
  }

  Future<String?> getGithubAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_githubAccessTokenKey);
  }

  Future<void> setGithubAccessToken(String? token) async {
    final prefs = await SharedPreferences.getInstance();
    if (token == null) {
      await prefs.remove(_githubAccessTokenKey);
    } else {
      await prefs.setString(_githubAccessTokenKey, token);
    }
  }

  Future<String?> getElevenLabsVoiceId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_elevenLabsVoiceIdKey);
  }

  Future<void> setElevenLabsVoiceId(String? voiceId) async {
    final prefs = await SharedPreferences.getInstance();
    if (voiceId == null) {
      await prefs.remove(_elevenLabsVoiceIdKey);
    } else {
      await prefs.setString(_elevenLabsVoiceIdKey, voiceId);
    }
  }

  Future<bool> getIsRememberPastChatsEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_isRememberPastChatsEnabledKey) ?? false;
  }

  Future<void> setIsRememberPastChatsEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_isRememberPastChatsEnabledKey, value);
  }

  Future<bool> getLocalNotificationsEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_localNotificationsEnabledKey) ?? true;
  }

  Future<void> setLocalNotificationsEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_localNotificationsEnabledKey, enabled);
  }

  Future<bool> getFcmNotificationsEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_fcmNotificationsEnabledKey) ?? true;
  }

  Future<void> setFcmNotificationsEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_fcmNotificationsEnabledKey, enabled);
  }

  static const String _isOutlookConnectedKey = 'is_outlook_connected';
  static const String _isOutlookAiAlwaysAllowedKey =
      'is_outlook_ai_always_allowed';
  static const String _outlookAccessTokenKey = 'outlook_access_token';

  Future<bool> getIsOutlookConnected() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_isOutlookConnectedKey) ?? false;
  }

  Future<void> setIsOutlookConnected(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_isOutlookConnectedKey, value);
  }

  Future<bool> getIsOutlookAiAlwaysAllowed() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_isOutlookAiAlwaysAllowedKey) ?? false;
  }

  Future<void> setIsOutlookAiAlwaysAllowed(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_isOutlookAiAlwaysAllowedKey, value);
  }

  Future<String?> getOutlookAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_outlookAccessTokenKey);
  }

  Future<void> setOutlookAccessToken(String? token) async {
    final prefs = await SharedPreferences.getInstance();
    if (token == null) {
      await prefs.remove(_outlookAccessTokenKey);
    } else {
      await prefs.setString(_outlookAccessTokenKey, token);
    }
  }
}

// Top-level function for compute
String _encodeChats(List<Chat> chats) {
  return jsonEncode(chats.map((c) => c.toJson()).toList());
}
