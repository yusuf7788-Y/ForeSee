import 'dart:convert';

import './shop_item.dart';

class PlayerInventory {
  final int fsCoinBalance;
  final List<String> purchasedItemIds;
  final Map<String, Map<String, String>> equippedItems; // { gameId: { itemType: itemId } }

  const PlayerInventory({
    this.fsCoinBalance = 0,
    this.purchasedItemIds = const [],
    this.equippedItems = const {},
  });

  PlayerInventory copyWith({
    int? fsCoinBalance,
    List<String>? purchasedItemIds,
    Map<String, Map<String, String>>? equippedItems,
  }) {
    return PlayerInventory(
      fsCoinBalance: fsCoinBalance ?? this.fsCoinBalance,
      purchasedItemIds: purchasedItemIds ?? this.purchasedItemIds,
      equippedItems: equippedItems ?? this.equippedItems,
    );
  }

  PlayerInventory purchaseItem(ShopItem item) {
    // Yetersiz bakiye kontrolü
    if (fsCoinBalance < item.price) return this;
    
    // Negatif bakiye güvenlik kontrolü
    final newBalance = fsCoinBalance - item.price;
    if (newBalance < 0) return this;
    
    return copyWith(
      fsCoinBalance: newBalance,
      purchasedItemIds: [...purchasedItemIds, item.id],
    );
  }

  PlayerInventory equipItem(ShopItem item) {
    final newEquipped = Map<String, Map<String, String>>.from(equippedItems.map(
      (key, value) => MapEntry(key, Map<String, String>.from(value)),
    ));
    if (newEquipped[item.gameId.toString()] == null) {
      newEquipped[item.gameId.toString()] = {};
    }
    newEquipped[item.gameId.toString()]![item.itemType.toString()] = item.id;
    return copyWith(equippedItems: newEquipped);
  }

  PlayerInventory unequipItem(ShopItem item) {
    final newEquipped = Map<String, Map<String, String>>.from(equippedItems.map(
      (key, value) => MapEntry(key, Map<String, String>.from(value)),
    ));
    if (newEquipped[item.gameId.toString()] != null) {
      newEquipped[item.gameId.toString()]!.remove(item.itemType.toString());
      if (newEquipped[item.gameId.toString()]!.isEmpty) {
        newEquipped.remove(item.gameId.toString());
      }
    }
    return copyWith(equippedItems: newEquipped);
  }

  Map<String, dynamic> toJson() {
    return {
      'fsCoinBalance': fsCoinBalance,
      'purchasedItemIds': purchasedItemIds,
      'equippedItems': equippedItems,
    };
  }

  factory PlayerInventory.fromJson(Map<String, dynamic> json) {
    return PlayerInventory(
      fsCoinBalance: json['fsCoinBalance'] ?? 0,
      purchasedItemIds: List<String>.from(json['purchasedItemIds'] ?? []),
      equippedItems: Map<String, Map<String, String>>.from(
        (json['equippedItems'] as Map<String, dynamic>?)?.map(
              (key, value) => MapEntry(
                key,
                Map<String, String>.from(value),
              ),
            ) ??
            {},
      ),
    );
  }
}
