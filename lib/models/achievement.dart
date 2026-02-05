/// Başarım sistemi için model ve servis
/// Başarımlar profilde gözükmez, sadece popup ile bildirilir

import 'package:flutter/material.dart';

/// Başarım türleri
enum AchievementType {
  firstMessage, // İlk mesajını gönder
  coinCollector, // 100 FsCoin topla
  coinHoarder, // 500 FsCoin topla
  gamePlayer, // Herhangi bir oyun oyna
  memoryMaster, // Hafıza oyununda 10 maç kazan
  reflexHero, // Refleks oyununda 100+ skor
  puzzlePro, // 2048'de 512'ye ulaş
  simonSays, // Renk Dizisinde 10 seviye geç
  wordsmith, // Wordle'da 3 kelime bil
  chatMaster, // 50 mesaj gönder
  nightOwl, // Gece 2-5 arası mesaj at
  earlyBird, // Sabah 5-7 arası mesaj at
  weekStreak, // 7 gün üst üste uygulama aç
}

/// Tek bir başarım
class Achievement {
  final AchievementType type;
  final String title;
  final String description;
  final IconData icon;
  final int coinReward;
  final bool isUnlocked;
  final DateTime? unlockedAt;

  const Achievement({
    required this.type,
    required this.title,
    required this.description,
    required this.icon,
    required this.coinReward,
    this.isUnlocked = false,
    this.unlockedAt,
  });

  Achievement copyWith({bool? isUnlocked, DateTime? unlockedAt}) {
    return Achievement(
      type: type,
      title: title,
      description: description,
      icon: icon,
      coinReward: coinReward,
      isUnlocked: isUnlocked ?? this.isUnlocked,
      unlockedAt: unlockedAt ?? this.unlockedAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'type': type.name,
    'isUnlocked': isUnlocked,
    'unlockedAt': unlockedAt?.toIso8601String(),
  };

  static Achievement fromJson(Map<String, dynamic> json, Achievement base) {
    return base.copyWith(
      isUnlocked: json['isUnlocked'] ?? false,
      unlockedAt: json['unlockedAt'] != null
          ? DateTime.parse(json['unlockedAt'])
          : null,
    );
  }
}

/// Tüm başarımların tanımları
class AchievementDefinitions {
  static const List<Achievement> all = [
    Achievement(
      type: AchievementType.firstMessage,
      title: 'İlk Adım',
      description: 'İlk mesajını gönder',
      icon: Icons.chat_bubble_outline,
      coinReward: 10,
    ),
    Achievement(
      type: AchievementType.coinCollector,
      title: 'Coin Avcısı',
      description: '100 FsCoin topla',
      icon: Icons.monetization_on,
      coinReward: 20,
    ),
    Achievement(
      type: AchievementType.coinHoarder,
      title: 'Hazine Avcısı',
      description: '500 FsCoin topla',
      icon: Icons.diamond,
      coinReward: 50,
    ),
    Achievement(
      type: AchievementType.gamePlayer,
      title: 'Oyuncu',
      description: 'İlk oyununu oyna',
      icon: Icons.sports_esports,
      coinReward: 15,
    ),
    Achievement(
      type: AchievementType.memoryMaster,
      title: 'Hafıza Ustası',
      description: 'Hafıza oyununda 10 maç kazan',
      icon: Icons.psychology,
      coinReward: 30,
    ),
    Achievement(
      type: AchievementType.reflexHero,
      title: 'Refleks Kahramanı',
      description: 'Refleks oyununda 100+ skor',
      icon: Icons.flash_on,
      coinReward: 30,
    ),
    Achievement(
      type: AchievementType.puzzlePro,
      title: 'Bulmaca Dehası',
      description: '2048\'de 512 karesini oluştur',
      icon: Icons.extension,
      coinReward: 40,
    ),
    Achievement(
      type: AchievementType.simonSays,
      title: 'Renk Ustası',
      description: 'Renk Dizisinde 10 seviye geç',
      icon: Icons.palette,
      coinReward: 35,
    ),
    Achievement(
      type: AchievementType.wordsmith,
      title: 'Kelime Ustası',
      description: 'Wordle\'da 3 kelime bil',
      icon: Icons.spellcheck,
      coinReward: 25,
    ),
    Achievement(
      type: AchievementType.chatMaster,
      title: 'Sohbet Ustası',
      description: '50 mesaj gönder',
      icon: Icons.forum,
      coinReward: 30,
    ),
    Achievement(
      type: AchievementType.nightOwl,
      title: 'Gece Kuşu',
      description: 'Gece 2-5 arası mesaj at',
      icon: Icons.nights_stay,
      coinReward: 15,
    ),
    Achievement(
      type: AchievementType.earlyBird,
      title: 'Erken Kuş',
      description: 'Sabah 5-7 arası mesaj at',
      icon: Icons.wb_sunny,
      coinReward: 15,
    ),
    Achievement(
      type: AchievementType.weekStreak,
      title: 'Sadık Kullanıcı',
      description: '7 gün üst üste uygulama aç',
      icon: Icons.local_fire_department,
      coinReward: 50,
    ),
  ];

  static Achievement? getByType(AchievementType type) {
    try {
      return all.firstWhere((a) => a.type == type);
    } catch (_) {
      return null;
    }
  }
}
