import 'package:flutter/material.dart';

enum GameId { memoryGame, reflexGame, game2048, simonGame, wordleGame }

enum ItemType { cardColor, buttonColor, fontStyle, emojiSet, effect }

class ShopItem {
  final String id;
  final String name;
  final String description;
  final int price;
  final GameId gameId;
  final ItemType itemType;
  final dynamic
  value; // Can be a Color, a font name (String), a list of emojis etc.
  final String previewAsset;

  ShopItem({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.gameId,
    required this.itemType,
    required this.value,
    required this.previewAsset,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'price': price,
      'gameId': gameId.toString(),
      'itemType': itemType.toString(),
      'value': value is Color ? value.value : value,
      'previewAsset': previewAsset,
    };
  }

  factory ShopItem.fromJson(Map<String, dynamic> json) {
    dynamic parsedValue;
    ItemType type = ItemType.values.firstWhere(
      (e) => e.toString() == json['itemType'],
    );
    if (type == ItemType.cardColor || type == ItemType.buttonColor) {
      parsedValue = Color(json['value']);
    } else {
      parsedValue = json['value'];
    }

    return ShopItem(
      id: json['id'],
      name: json['name'],
      description: json['description'],
      price: json['price'],
      gameId: GameId.values.firstWhere((e) => e.toString() == json['gameId']),
      itemType: type,
      value: parsedValue,
      previewAsset: json['previewAsset'],
    );
  }
}
