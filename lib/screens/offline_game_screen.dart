import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import '../services/storage_service.dart';
import '../models/player_inventory.dart';
import '../services/shop_service.dart';
import '../models/shop_item.dart';

class OfflineGameScreen extends StatefulWidget {
  const OfflineGameScreen({super.key});

  @override
  State<OfflineGameScreen> createState() => _OfflineGameScreenState();
}

class _OfflineGameScreenState extends State<OfflineGameScreen> {
  final StorageService _storageService = StorageService();
  final ShopService _shopService = ShopService();
  static const _gameDuration = Duration(seconds: 30);
  static const _targetSize = 56.0;

  final Random _rng = Random();
  Timer? _timer;
  int _timeLeft = _gameDuration.inSeconds;
  int _score = 0;
  int _miss = 0;
  int _combo = 0;
  int _bestCombo = 0;
  Offset _targetPos = const Offset(0.5, 0.5); // 0-1 arası oran
  bool _isRunning = false;

  // Customization
  Color _buttonColor = const Color(0xFF2563EB);

  @override
  void initState() {
    super.initState();
    _loadCustomizations().then((_) {
      _startGame();
    });
  }

  Future<void> _loadCustomizations() async {
    final inventory = await _storageService.loadPlayerInventory();
    final equippedColorId =
        inventory.equippedItems[GameId.reflexGame.toString()]?[ItemType
            .buttonColor
            .toString()];

    if (equippedColorId != null) {
      final shopItem = _shopService.allItems.firstWhere(
        (item) => item.id == equippedColorId,
      );
      if (shopItem.value is Color) {
        setState(() {
          _buttonColor = shopItem.value;
        });
      }
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startGame() {
    _timer?.cancel();
    setState(() {
      _score = 0;
      _miss = 0;
      _combo = 0;
      _timeLeft = _gameDuration.inSeconds;
      _isRunning = true;
      _moveTarget();
    });

    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_timeLeft <= 1) {
        t.cancel();
        _endGame();
      } else {
        setState(() {
          _timeLeft--;
        });
      }
    });
  }

  void _moveTarget() {
    setState(() {
      // Kenarlardan biraz boşluk bırakmak için 0.1 - 0.9 arası
      _targetPos = Offset(
        0.1 + _rng.nextDouble() * 0.8,
        0.1 + _rng.nextDouble() * 0.8,
      );
    });
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

  void _endGame() async {
    setState(() {
      _timeLeft = 0;
      _isRunning = false;
    });

    final int coinsEarned = (_score / 10).round() + _bestCombo;
    if (coinsEarned > 0) {
      PlayerInventory inventory = await _storageService.loadPlayerInventory();
      final updatedInventory = inventory.copyWith(
        fsCoinBalance: inventory.fsCoinBalance + coinsEarned,
      );
      await _storageService.savePlayerInventory(updatedInventory);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$coinsEarned FsCoin kazandın!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  void _onTapDown(TapDownDetails details, BoxConstraints constraints) {
    if (!_isRunning) return;

    final boxSize = constraints.biggest;
    final tapPos = details.localPosition;

    final targetCenter = Offset(
      _targetPos.dx * boxSize.width,
      _targetPos.dy * boxSize.height,
    );

    final dx = tapPos.dx - targetCenter.dx;
    final dy = tapPos.dy - targetCenter.dy;
    final distance = sqrt(dx * dx + dy * dy);
    final hitRadius = _targetSize / 2;

    if (distance <= hitRadius) {
      setState(() {
        _combo++;
        if (_combo > _bestCombo) {
          _bestCombo = _combo;
        }

        // Seri uzadıkça küçük bir skor çarpanı uygula
        final multiplier = 1 + (_combo - 1) ~/ 3; // her 3'lü seride +1x
        _score += 10 * multiplier;
      });
      _moveTarget();
    } else {
      setState(() {
        _miss++;
        _combo = 0;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

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
                        _timer
                            ?.cancel(); // Geri tuşuna basılınca oyunu duraklat
                        if (await _showExitConfirmation()) {
                          Navigator.of(context).pop();
                        } else {
                          // Kullanıcı iptal ederse oyun devam etsin
                          if (_isRunning && _timeLeft > 0) {
                            _timer = Timer.periodic(
                              const Duration(seconds: 1),
                              (t) {
                                if (_timeLeft <= 1) {
                                  t.cancel();
                                  _endGame();
                                } else {
                                  setState(() {
                                    _timeLeft--;
                                  });
                                }
                              },
                            );
                          }
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Mini oyun',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'İnternet yokken küçük bir mola',
                        style: TextStyle(color: Colors.white38, fontSize: 12),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF111827),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white10),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildStatChip(
                      label: 'Süre',
                      value: '$_timeLeft sn',
                      color: Colors.white70,
                    ),
                    _buildStatChip(
                      label: 'Skor',
                      value: '$_score',
                      color: Colors.greenAccent,
                    ),
                    _buildStatChip(
                      label: 'Seri',
                      value: '$_combo',
                      color: Colors.amberAccent,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTapDown: (d) => _onTapDown(d, constraints),
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(24),
                          gradient: const LinearGradient(
                            colors: [Color(0xFF020617), Color(0xFF0F172A)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          border: Border.all(color: Colors.white10),
                        ),
                        child: Stack(
                          children: [
                            Positioned(
                              left:
                                  _targetPos.dx * constraints.maxWidth -
                                  _targetSize / 2,
                              top:
                                  _targetPos.dy * constraints.maxHeight -
                                  _targetSize / 2,
                              child: Container(
                                width: _targetSize,
                                height: _targetSize,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: _buttonColor,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.blueAccent.withOpacity(0.7),
                                      blurRadius: 18,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: const Center(
                                  child: Icon(
                                    Icons.touch_app,
                                    color: Colors.white,
                                    size: 22,
                                  ),
                                ),
                              ),
                            ),
                            if (!_isRunning)
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.55),
                                  borderRadius: BorderRadius.circular(24),
                                ),
                                child: Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Text(
                                        'Oyun bitti',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 20,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        'Skorun: $_score',
                                        style: const TextStyle(
                                          color: Colors.greenAccent,
                                          fontSize: 16,
                                        ),
                                      ),
                                      // FsCoin display will be handled by a separate state variable if needed
                                      // For now, it's part of the end game logic.
                                      const SizedBox(height: 4),
                                      Text(
                                        'En iyi seri: $_bestCombo',
                                        style: const TextStyle(
                                          color: Colors.amberAccent,
                                          fontSize: 13,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Kaçırma: $_miss',
                                        style: const TextStyle(
                                          color: Colors.redAccent,
                                          fontSize: 13,
                                        ),
                                      ),
                                      const SizedBox(height: 16),
                                      ElevatedButton.icon(
                                        onPressed: _startGame,
                                        icon: const Icon(Icons.refresh),
                                        label: const Text('Tekrar oyna'),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.white,
                                          foregroundColor: Colors.black,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              999,
                                            ),
                                          ),
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 20,
                                            vertical: 10,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Halkaya dokunarak reflekslerini test edebilirsin.\nİnternet geldiğinde kaldığın yerden devam edebilirsin.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.white54,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatChip({
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.white38, fontSize: 11),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
