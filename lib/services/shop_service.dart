import 'package:flutter/material.dart';
import '../models/shop_item.dart';
import 'dart:math';

class ShopService {
  // In a real app, this would come from a server or a local database.
  final List<ShopItem> _allItems = [
    // Memory Game Items
    ShopItem(id: 'mem_color_1', name: 'Okyanus Mavi Kart', description: 'Hafıza kartları için mavi tema.', price: 150, gameId: GameId.memoryGame, itemType: ItemType.cardColor, value: Colors.blue[700]!, previewAsset: 'assets/ok.png'),
    ShopItem(id: 'mem_color_2', name: 'Zümrüt Yeşil Kart', description: 'Hafıza kartları için yeşil tema.', price: 150, gameId: GameId.memoryGame, itemType: ItemType.cardColor, value: Colors.green[700]!, previewAsset: 'assets/z.png'),
    ShopItem(id: 'mem_emoji_1', name: 'Hayvan Emojileri', description: 'Kartlardaki emojileri hayvanlarla değiştir.', price: 300, gameId: GameId.memoryGame, itemType: ItemType.emojiSet, value: ['🐶', '🐱', '🐭', '🐹', '🐰', '🦊', '🐻', '🐼', '🐨', '🐯', '🦁', '🐮'], previewAsset: 'assets/hy.png'),

    // Reflex Game Items
    ShopItem(id: 'ref_color_1', name: 'Ateş Kırmızısı Buton', description: 'Refleks oyunundaki butonu kırmızı yap.', price: 200, gameId: GameId.reflexGame, itemType: ItemType.buttonColor, value: Colors.red[600]!, previewAsset: 'assets/at.png'),
    ShopItem(id: 'ref_color_2', name: 'Altın Sarısı Buton', description: 'Refleks oyunundaki butonu sarı yap.', price: 200, gameId: GameId.reflexGame, itemType: ItemType.buttonColor, value: Colors.amber[600]!, previewAsset: 'assets/al.png'),

    // 2048 Game Items
    ShopItem(id: '2048_font_1', name: 'Modern Font', description: '2048 oyunu için modern bir font.', price: 250, gameId: GameId.game2048, itemType: ItemType.fontStyle, value: 'Roboto', previewAsset: 'assets/mo.png'),
    ShopItem(id: '2048_color_1', name: 'Neon Tema', description: '2048 için canlı neon renkleri.', price: 400, gameId: GameId.game2048, itemType: ItemType.cardColor, value: 'neon', previewAsset: 'assets/ne.png'), // Special value for a theme

    // Simon Game Items
    ShopItem(id: 'sim_color_1', name: 'Pastel Renkler', description: 'Simon oyunu için pastel renk paleti.', price: 350, gameId: GameId.simonGame, itemType: ItemType.cardColor, value: 'pastel', previewAsset: 'assets/ps.png'),
  ];

  List<ShopItem> get allItems => _allItems;

  List<ShopItem> getPopularItems() {
    final random = Random();
    List<ShopItem> shuffled = List.from(_allItems)..shuffle(random);
    return shuffled.take(3).toList();
  }

  List<ShopItem> getItemsByGame(GameId gameId) {
    return _allItems.where((item) => item.gameId == gameId).toList();
  }
}
