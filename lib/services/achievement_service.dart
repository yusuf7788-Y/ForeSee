import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/achievement.dart';
import 'storage_service.dart';

/// Başarım yönetim servisi
/// Başarımları takip eder, açar ve popup bildirim gösterir
class AchievementService {
  static final AchievementService _instance = AchievementService._internal();
  factory AchievementService() => _instance;
  AchievementService._internal();

  final StorageService _storageService = StorageService();

  // Kullanıcı istatistikleri için key'ler
  static const String _achievementsKey = 'user_achievements';
  static const String _statsKey = 'achievement_stats';

  // Popup göstermek için callback
  static Function(Achievement)? onAchievementUnlocked;

  /// Başarımları yükle
  Future<Map<AchievementType, Achievement>> loadAchievements() async {
    final prefs = await SharedPreferences.getInstance();
    final String? data = prefs.getString(_achievementsKey);

    Map<AchievementType, Achievement> result = {};

    // Tüm tanımlı başarımları ekle
    for (final achievement in AchievementDefinitions.all) {
      result[achievement.type] = achievement;
    }

    // Kayıtlı durumları yükle
    if (data != null) {
      try {
        final Map<String, dynamic> saved = json.decode(data);
        for (final entry in saved.entries) {
          final type = AchievementType.values.firstWhere(
            (t) => t.name == entry.key,
            orElse: () => AchievementType.firstMessage,
          );
          final base = result[type];
          if (base != null) {
            result[type] = Achievement.fromJson(entry.value, base);
          }
        }
      } catch (_) {}
    }

    return result;
  }

  /// Başarımları kaydet
  Future<void> _saveAchievements(
    Map<AchievementType, Achievement> achievements,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final Map<String, dynamic> data = {};

    for (final entry in achievements.entries) {
      if (entry.value.isUnlocked) {
        data[entry.key.name] = entry.value.toJson();
      }
    }

    await prefs.setString(_achievementsKey, json.encode(data));
  }

  /// İstatistikleri yükle
  Future<Map<String, int>> _loadStats() async {
    final prefs = await SharedPreferences.getInstance();
    final String? data = prefs.getString(_statsKey);

    if (data != null) {
      try {
        return Map<String, int>.from(json.decode(data));
      } catch (_) {}
    }

    return {};
  }

  /// İstatistikleri kaydet
  Future<void> _saveStats(Map<String, int> stats) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_statsKey, json.encode(stats));
  }

  /// Bir başarımı aç
  Future<void> _unlock(AchievementType type) async {
    final achievements = await loadAchievements();
    final achievement = achievements[type];

    if (achievement == null || achievement.isUnlocked) return;

    // Başarımı aç
    achievements[type] = achievement.copyWith(
      isUnlocked: true,
      unlockedAt: DateTime.now(),
    );

    await _saveAchievements(achievements);

    // FsCoin ödülü ver
    final inventory = await _storageService.loadPlayerInventory();
    final updated = inventory.copyWith(
      fsCoinBalance: inventory.fsCoinBalance + achievement.coinReward,
    );
    await _storageService.savePlayerInventory(updated);

    // Popup göster
    if (onAchievementUnlocked != null) {
      onAchievementUnlocked!(achievements[type]!);
    }
  }

  /// Mesaj gönderildiğinde kontrol et
  Future<void> onMessageSent() async {
    final stats = await _loadStats();
    final count = (stats['messageCount'] ?? 0) + 1;
    stats['messageCount'] = count;
    await _saveStats(stats);

    // İlk mesaj başarımı
    if (count == 1) {
      await _unlock(AchievementType.firstMessage);
    }

    // 50 mesaj başarımı
    if (count >= 50) {
      await _unlock(AchievementType.chatMaster);
    }

    // Zaman bazlı başarımlar
    final hour = DateTime.now().hour;
    if (hour >= 2 && hour < 5) {
      await _unlock(AchievementType.nightOwl);
    }
    if (hour >= 5 && hour < 7) {
      await _unlock(AchievementType.earlyBird);
    }
  }

  /// FsCoin kazanıldığında kontrol et
  Future<void> onCoinsEarned(int totalBalance) async {
    if (totalBalance >= 100) {
      await _unlock(AchievementType.coinCollector);
    }
    if (totalBalance >= 500) {
      await _unlock(AchievementType.coinHoarder);
    }
  }

  /// Oyun oynandığında kontrol et
  Future<void> onGamePlayed(String gameType, {int? score, bool? won}) async {
    final stats = await _loadStats();

    // İlk oyun başarımı
    final totalGames = (stats['totalGames'] ?? 0) + 1;
    stats['totalGames'] = totalGames;
    if (totalGames == 1) {
      await _unlock(AchievementType.gamePlayer);
    }

    // Oyun bazlı başarımlar
    switch (gameType) {
      case 'memory':
        if (won == true) {
          final memoryWins = (stats['memoryWins'] ?? 0) + 1;
          stats['memoryWins'] = memoryWins;
          if (memoryWins >= 10) {
            await _unlock(AchievementType.memoryMaster);
          }
        }
        break;

      case 'reflex':
        if (score != null && score >= 100) {
          await _unlock(AchievementType.reflexHero);
        }
        break;

      case '2048':
        if (score != null && score >= 512) {
          await _unlock(AchievementType.puzzlePro);
        }
        break;

      case 'simon':
        if (score != null && score >= 10) {
          await _unlock(AchievementType.simonSays);
        }
        break;

      case 'wordle':
        if (won == true) {
          final wordleWins = (stats['wordleWins'] ?? 0) + 1;
          stats['wordleWins'] = wordleWins;
          if (wordleWins >= 3) {
            await _unlock(AchievementType.wordsmith);
          }
        }
        break;
    }

    await _saveStats(stats);
  }

  /// Uygulama açıldığında kontrol et (streak)
  Future<void> onAppOpened() async {
    final stats = await _loadStats();
    final lastOpen = stats['lastOpenDay'] ?? 0;
    final today = DateTime.now().millisecondsSinceEpoch ~/ 86400000;

    if (lastOpen == today - 1) {
      // Art arda gün
      final streak = (stats['streak'] ?? 0) + 1;
      stats['streak'] = streak;
      if (streak >= 7) {
        await _unlock(AchievementType.weekStreak);
      }
    } else if (lastOpen != today) {
      // Streak kırıldı
      stats['streak'] = 1;
    }

    stats['lastOpenDay'] = today;
    await _saveStats(stats);
  }
}
