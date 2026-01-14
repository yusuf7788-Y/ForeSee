import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/chat.dart';
import '../models/user_profile.dart';
import '../models/player_inventory.dart';

class StorageService {
  static const String _chatsKey = 'chats';
  static const String _userProfileKey = 'user_profile';
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

  Future<List<Chat>> loadChats() async {
    final prefs = await SharedPreferences.getInstance();
    final chatsJson = prefs.getString(_chatsKey);

    if (chatsJson == null) {
      return [];
    }

    final List<dynamic> chatsList = jsonDecode(chatsJson);
    return chatsList.map((json) => Chat.fromJson(json)).toList();
  }

  Future<void> saveChats(List<Chat> chats) async {
    final prefs = await SharedPreferences.getInstance();
    final chatsJson = jsonEncode(chats.map((c) => c.toJson()).toList());
    await prefs.setString(_chatsKey, chatsJson);
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

  Future<int> getThemeIndex() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_themeIndexKey) ?? 0;
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

  Future<void> resetAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
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
    // Key format: YYYY-MM-DD
    final now = DateTime.now();
    final key =
        "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";

    final current = stats[key] ?? 0;
    stats[key] = current + minutes;

    // 7 günden eski verileri temizle
    final keysToRemove = <String>[];
    stats.forEach((k, v) {
      try {
        final date = DateTime.parse(k);
        if (now.difference(date).inDays > 7) {
          keysToRemove.add(k);
        }
      } catch (_) {}
    });
    for (final k in keysToRemove) stats.remove(k);

    await prefs.setString(_weeklyUsageKey, jsonEncode(stats));
  }

  // Input ve Tab yönetimi için yeni metotlar
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
}
