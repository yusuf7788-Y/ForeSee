import 'dart:math';

import 'package:flutter/material.dart';
import '../services/storage_service.dart';
import '../models/player_inventory.dart';
import '../services/shop_service.dart';
import '../models/shop_item.dart';

class SimonGameScreen extends StatefulWidget {
  const SimonGameScreen({super.key});

  @override
  State<SimonGameScreen> createState() => _SimonGameScreenState();
}

class _SimonGameScreenState extends State<SimonGameScreen> {
  final StorageService _storageService = StorageService();
  final ShopService _shopService = ShopService();
  final Random _rng = Random();
  final List<int> _sequence = [];
  int _currentStep = 0;
  int _activePad = -1;
  bool _isShowingSequence = false;
  int _score = 0;
  int _padCount = 4;

  // Customization
  List<Color> _padColors = [];

  @override
  void initState() {
    super.initState();
    _loadCustomizations().then((_) {
      Future.microtask(_startNewGame);
    });
  }

  Future<void> _loadCustomizations() async {
    final inventory = await _storageService.loadPlayerInventory();
    final equippedColorId =
        inventory.equippedItems[GameId.simonGame.toString()]?[ItemType.cardColor
            .toString()];

    if (equippedColorId != null) {
      final shopItem = _shopService.allItems.firstWhere(
        (item) => item.id == equippedColorId,
      );
      if (shopItem.value == 'pastel') {
        _padColors = _getPastelColors();
      }
    } else {
      _padColors = _getDefaultColors();
    }
    setState(() {});
  }

  void _changePadCount(int count) {
    if (count == _padCount) return;
    setState(() {
      _padCount = count;
      _sequence.clear();
      _score = 0;
      _currentStep = 0;
      _activePad = -1;
      _isShowingSequence = false;
    });
    _nextRound();
  }

  void _startNewGame() {
    setState(() {
      _sequence.clear();
      _score = 0;
      _currentStep = 0;
    });
    _nextRound();
  }

  /// Çıkış onayı için dialog göster
  Future<bool> _showExitConfirmation() async {
    if (_score == 0) return true; // Skor yoksa direkt çık
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF020617),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Çıkmak istediğine emin misin?',
          style: TextStyle(color: Colors.white, fontSize: 16),
        ),
        content: Text(
          'Şu anki skorun: $_score\nÇıkarsan bu skoru kaybedecek ve FsCoin kazanamayacaksın.',
          style: const TextStyle(color: Colors.white70, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('İptal'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Çık', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<void> _nextRound() async {
    _sequence.add(_rng.nextInt(_padCount));
    _currentStep = 0;
    await _playSequence();
  }

  Future<void> _playSequence() async {
    setState(() {
      _isShowingSequence = true;
      _activePad = -1;
    });

    await Future.delayed(const Duration(milliseconds: 400));

    for (final idx in _sequence) {
      if (!mounted) return;
      setState(() {
        _activePad = idx;
      });
      await Future.delayed(const Duration(milliseconds: 500));
      if (!mounted) return;
      setState(() {
        _activePad = -1;
      });
      await Future.delayed(const Duration(milliseconds: 220));
    }

    if (!mounted) return;
    setState(() {
      _isShowingSequence = false;
    });
  }

  void _onPadTap(int index) {
    if (_isShowingSequence) return;
    if (index < 0 || index >= _padCount) return;
    if (_sequence.isEmpty) return;

    // Kullanıcı tıkladığında kısa bir görsel geri bildirim ver
    setState(() {
      _activePad = index;
    });
    Future.delayed(const Duration(milliseconds: 160), () {
      if (!mounted || _isShowingSequence) return;
      setState(() {
        _activePad = -1;
      });
    });

    if (index != _sequence[_currentStep]) {
      _showGameOver();
      return;
    }

    setState(() {
      _currentStep++;
      _score += 10;
    });

    if (_currentStep >= _sequence.length) {
      Future.delayed(const Duration(milliseconds: 500), () {
        if (!mounted) return;
        _nextRound();
      });
    }
  }

  void _showGameOver() async {
    final int coinsEarned = (_score / 5).round();
    if (coinsEarned > 0) {
      PlayerInventory inventory = await _storageService.loadPlayerInventory();
      final updatedInventory = inventory.copyWith(
        fsCoinBalance: inventory.fsCoinBalance + coinsEarned,
      );
      await _storageService.savePlayerInventory(updatedInventory);
    }

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
            'Oyun bitti',
            style: TextStyle(color: Colors.white),
          ),
          content: Text(
            'Skorun: $_score. $coinsEarned FsCoin kazandın!',
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _startNewGame();
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
                      onPressed: () async {
                        if (await _showExitConfirmation()) {
                          Navigator.of(context).pop();
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Renk dizisi',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Simon Says tarzı, sırayı takip et',
                        style: TextStyle(color: Colors.white38, fontSize: 12),
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
                    'Tur: ${_sequence.length}',
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                  Text(
                    'Skor: $_score',
                    style: const TextStyle(
                      color: Colors.greenAccent,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _SimonModeChip(
                    label: '4 kart',
                    selected: _padCount == 4,
                    onTap: () => _changePadCount(4),
                  ),
                  const SizedBox(width: 8),
                  _SimonModeChip(
                    label: '8 kart',
                    selected: _padCount == 8,
                    onTap: () => _changePadCount(8),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                _isShowingSequence ? 'Diziyi izle...' : 'Sırayı tekrar et',
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: Center(
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: GridView.builder(
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: _padCount == 4 ? 2 : 4,
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                      ),
                      itemCount: _padCount,
                      itemBuilder: (context, index) {
                        final baseColor = _padColors[index];
                        final isActive = _activePad == index;
                        final isHighlight = _isShowingSequence && isActive;
                        final isPressed = !_isShowingSequence && isActive;
                        final highlight = isHighlight || isPressed;
                        final color = highlight
                            ? baseColor
                            : baseColor.withOpacity(0.7);
                        return GestureDetector(
                          onTap: () => _onPadTap(index),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 120),
                            curve: Curves.easeOut,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(24),
                              color: color,
                              boxShadow: highlight
                                  ? [
                                      BoxShadow(
                                        color: baseColor.withOpacity(0.95),
                                        blurRadius: 30,
                                        spreadRadius: 2,
                                        offset: const Offset(0, 6),
                                      ),
                                    ]
                                  : [
                                      BoxShadow(
                                        color: baseColor.withOpacity(0.3),
                                        blurRadius: 12,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                              border: highlight
                                  ? Border.all(
                                      color: Colors.white.withOpacity(0.9),
                                      width: 1.3,
                                    )
                                  : null,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Color Schemes
List<Color> _getDefaultColors() => const [
  Color(0xFF22C55E),
  Color(0xFF3B82F6),
  Color(0xFFFB923C),
  Color(0xFFEC4899),
  Color(0xFF2DD4BF),
  Color(0xFF6366F1),
  Color(0xFFF97316),
  Color(0xFFE11D48),
];

List<Color> _getPastelColors() => const [
  Color(0xFFB2F2BB),
  Color(0xFFA8D8EA),
  Color(0xFFFCE38A),
  Color(0xFFF38181),
  Color(0xFF95E1D3),
  Color(0xFFB39DDB),
  Color(0xFFFFD180),
  Color(0xFFF48FB1),
];

class _SimonModeChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _SimonModeChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          color: selected ? Colors.white12 : Colors.transparent,
          border: Border.all(color: selected ? Colors.white : Colors.white24),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}
