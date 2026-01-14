import 'dart:math';

import 'package:flutter/material.dart';
import '../services/storage_service.dart';
import '../models/player_inventory.dart';
import '../services/shop_service.dart';
import '../models/shop_item.dart';

class MemoryGameScreen extends StatefulWidget {
  const MemoryGameScreen({super.key});

  @override
  State<MemoryGameScreen> createState() => _MemoryGameScreenState();
}

class _MemoryGameScreenState extends State<MemoryGameScreen> {
  final StorageService _storageService = StorageService();
  final ShopService _shopService = ShopService();
  final List<String> _symbols = [
    '🍀', '⭐️', '💎', '⚡️', '🎧', '🎮', '🧠', '🚀', '🌙', '🔥', '💡', '🎲'
  ];

  int _rows = 0;
  int _cols = 0;
  List<_MemoryCard> _cards = [];
  int? _firstIndex;
  bool _isChecking = false;
  int _moves = 0;
  int _matches = 0;

  // Customization
  Color _cardColor = const Color(0xFF1D4ED8);
  List<String> _emojiSet = [];

  @override
  void initState() {
    super.initState();
    _loadCustomizations().then((_) {
      Future.microtask(_askBoardSize);
    });
  }

  Future<void> _loadCustomizations() async {
    final inventory = await _storageService.loadPlayerInventory();
    final equippedColorId = inventory.equippedItems[GameId.memoryGame.toString()]?[ItemType.cardColor.toString()];
    final equippedEmojiId = inventory.equippedItems[GameId.memoryGame.toString()]?[ItemType.emojiSet.toString()];

    if (equippedColorId != null) {
      final shopItem = _shopService.allItems.firstWhere((item) => item.id == equippedColorId);
      if (shopItem.value is Color) {
        _cardColor = shopItem.value;
      }
    }

    if (equippedEmojiId != null) {
      final shopItem = _shopService.allItems.firstWhere((item) => item.id == equippedEmojiId);
      if (shopItem.value is List) {
        _emojiSet = List<String>.from(shopItem.value);
      }
    } else {
      _emojiSet = _symbols;
    }
    setState(() {});
  }

  void _askBoardSize() async {
    if (!mounted) return;

    final choice = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF020617),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            'Kart boyutu seç',
            style: TextStyle(color: Colors.white),
          ),
          content: const Text(
            'Kaç kartla oynamak istersin?\n3x4 hızlı, 4x4 biraz daha uzun.',
            style: TextStyle(color: Colors.white70, fontSize: 13),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop('3x4'),
              child: const Text('3 x 4'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop('4x4'),
              child: const Text('4 x 4'),
            ),
          ],
        );
      },
    );

    if (!mounted) return;

    if (choice == '4x4') {
      _startNewGame(4, 4);
    } else {
      _startNewGame(3, 4);
    }
  }

  void _startNewGame(int rows, int cols) {
    final total = rows * cols;
    final pairCount = total ~/ 2;
    final rng = Random();

    final pool = List<String>.from(_emojiSet)..shuffle(rng);
    final selected = pool.take(pairCount).toList();

    final cardSymbols = <String>[];
    for (final s in selected) {
      cardSymbols..add(s)..add(s);
    }
    cardSymbols.shuffle(rng);

    setState(() {
      _rows = rows;
      _cols = cols;
      _moves = 0;
      _matches = 0;
      _firstIndex = null;
      _isChecking = false;
      _cards = List.generate(total, (i) => _MemoryCard(symbol: cardSymbols[i]));
    });
  }

  void _onCardTap(int index) {
    if (_isChecking) return;
    if (index < 0 || index >= _cards.length) return;
    final card = _cards[index];
    if (card.isMatched || card.isRevealed) return;

    setState(() {
      _cards[index] = card.copyWith(isRevealed: true);
    });

    if (_firstIndex == null) {
      _firstIndex = index;
      return;
    }

    final first = _firstIndex!;
    if (first == index) {
      return;
    }

    _isChecking = true;
    _moves++;

    Future.delayed(const Duration(milliseconds: 700), () {
      if (!mounted) return;

      final firstCard = _cards[first];
      final secondCard = _cards[index];

      if (firstCard.symbol == secondCard.symbol) {
        setState(() {
          _cards[first] = firstCard.copyWith(isMatched: true);
          _cards[index] = secondCard.copyWith(isMatched: true);
          _matches++;
        });
      } else {
        setState(() {
          _cards[first] = firstCard.copyWith(isRevealed: false);
          _cards[index] = secondCard.copyWith(isRevealed: false);
        });
      }

      _firstIndex = null;
      _isChecking = false;

      final allMatched = _cards.every((c) => c.isMatched);
      if (allMatched) {
        _showWinDialog();
      }
    });
  }

  void _showWinDialog() async {
    final pairs = (_rows * _cols) / 2;
    int score = (pairs * 25 - _moves * 2).toInt();
    if (score < 10) score = 10; // Minimum reward
    final int coinsEarned = score;

    PlayerInventory inventory = await _storageService.loadPlayerInventory();
    final updatedInventory = inventory.copyWith(fsCoinBalance: inventory.fsCoinBalance + coinsEarned);
    await _storageService.savePlayerInventory(updatedInventory);
    await _storageService.savePlayerInventory(inventory);

    if (!mounted) return;

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF020617),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            'Tebrikler! 🎉',
            style: TextStyle(color: Colors.white),
          ),
          content: Text(
            'Oyunu $_moves hamlede tamamladın ve $coinsEarned FsCoin kazandın!',
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _askBoardSize();
              },
              child: const Text('Tekrar oyna'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Kapat'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF020617),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white10,
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      iconSize: 20,
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Hafıza kartları',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Masa üzerinde kart eşleştir',
                        style: TextStyle(
                          color: Colors.white38,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Hamle: $_moves',
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                  Text(
                    'Eşleşme: $_matches',
                    style: const TextStyle(color: Colors.greenAccent, fontSize: 13),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xFF020617),
                        Color(0xFF111827),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    border: Border.all(color: Colors.white10),
                  ),
                  padding: const EdgeInsets.all(12),
                  child: _rows == 0 || _cols == 0
                      ? const Center(
                          child: CircularProgressIndicator(color: Colors.white70),
                        )
                      : GridView.builder(
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: _cols,
                            mainAxisSpacing: 8,
                            crossAxisSpacing: 8,
                            childAspectRatio: 0.7,
                          ),
                          itemCount: _cards.length,
                          itemBuilder: (context, index) {
                            return _buildCard(index);
                          },
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCard(int index) {
    final card = _cards[index];
    final bool isFaceUp = card.isRevealed || card.isMatched;

    return GestureDetector(
      onTap: () => _onCardTap(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: isFaceUp ? _cardColor : const Color(0xFF020617),
          border: Border.all(
            color: isFaceUp ? Colors.white : Colors.white24,
            width: 1.2,
          ),
          boxShadow: isFaceUp
              ? [
                  BoxShadow(
                    color: Colors.blueAccent.withOpacity(0.5),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [],
        ),
        child: Center(
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 150),
            opacity: isFaceUp ? 1.0 : 0.0,
            child: Text(
              isFaceUp ? card.symbol : '',
              style: const TextStyle(
                fontSize: 28,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MemoryCard {
  final String symbol;
  final bool isRevealed;
  final bool isMatched;

  const _MemoryCard({
    required this.symbol,
    this.isRevealed = false,
    this.isMatched = false,
  });

  _MemoryCard copyWith({
    String? symbol,
    bool? isRevealed,
    bool? isMatched,
  }) {
    return _MemoryCard(
      symbol: symbol ?? this.symbol,
      isRevealed: isRevealed ?? this.isRevealed,
      isMatched: isMatched ?? this.isMatched,
    );
  }
}
