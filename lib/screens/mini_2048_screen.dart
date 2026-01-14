import 'dart:math';

import 'package:flutter/material.dart';
import '../services/storage_service.dart';
import '../models/player_inventory.dart';
import '../services/shop_service.dart';
import '../models/shop_item.dart';

class Mini2048Screen extends StatefulWidget {
  const Mini2048Screen({super.key});

  @override
  State<Mini2048Screen> createState() => _Mini2048ScreenState();
}

class _Mini2048ScreenState extends State<Mini2048Screen> {
  final StorageService _storageService = StorageService();
  final ShopService _shopService = ShopService();
  static const int _size = 4;

  final Random _rng = Random();
  late List<List<int>> _board;
  int _score = 0;
  bool _gameOver = false;
  Offset _dragTotal = Offset.zero;
  bool _didMoveInDrag = false;

  // Customization
  String _fontFamily = 'sans-serif';
  Map<int, Color> _colorScheme = {};

  @override
  void initState() {
    super.initState();
    _loadCustomizations().then((_) {
      _startNewGame();
    });
  }

  Future<void> _loadCustomizations() async {
    final inventory = await _storageService.loadPlayerInventory();
    final equippedFontId = inventory.equippedItems[GameId.game2048.toString()]?[ItemType.fontStyle.toString()];
    final equippedColorId = inventory.equippedItems[GameId.game2048.toString()]?[ItemType.cardColor.toString()];

    if (equippedFontId != null) {
      final shopItem = _shopService.allItems.firstWhere((item) => item.id == equippedFontId);
      if (shopItem.value is String) {
        _fontFamily = shopItem.value;
      }
    }

    if (equippedColorId != null) {
      final shopItem = _shopService.allItems.firstWhere((item) => item.id == equippedColorId);
      if (shopItem.value == 'neon') {
        _colorScheme = _getNeonColors();
      }
    } else {
      _colorScheme = _getDefaultColors();
    }

    setState(() {});
  }

  void _startNewGame() {
    _board = List.generate(_size, (_) => List.filled(_size, 0));
    _score = 0;
    _gameOver = false;
    _addRandomTile();
    _addRandomTile();
    setState(() {});
  }

  void _addRandomTile() {
    final empty = <Point<int>>[];
    for (int r = 0; r < _size; r++) {
      for (int c = 0; c < _size; c++) {
        if (_board[r][c] == 0) {
          empty.add(Point(r, c));
        }
      }
    }
    if (empty.isEmpty) return;
    final p = empty[_rng.nextInt(empty.length)];
    _board[p.x][p.y] = _rng.nextDouble() < 0.9 ? 2 : 4;
  }

  void _handlePanStart(DragStartDetails details) {
    _dragTotal = Offset.zero;
    _didMoveInDrag = false;
  }

  void _handlePanUpdate(DragUpdateDetails details) {
    _dragTotal += details.delta;
  }

  void _handlePanEnd(DragEndDetails details) {
    if (_didMoveInDrag || _gameOver) return;
    final dx = _dragTotal.dx;
    final dy = _dragTotal.dy;
    const minDistance = 24;
    if (dx.abs() < minDistance && dy.abs() < minDistance) return;

    if (dx.abs() > dy.abs()) {
      if (dx > 0) {
        _moveRight();
      } else {
        _moveLeft();
      }
    } else {
      if (dy > 0) {
        _moveDown();
      } else {
        _moveUp();
      }
    }

    _didMoveInDrag = true;
  }

  void _moveLeft() {
    bool moved = false;
    for (int r = 0; r < _size; r++) {
      final row = _board[r];
      final result = _compressAndMerge(row);
      _board[r] = result.row;
      moved = moved || result.moved;
    }
    if (moved) {
      _addRandomTile();
      _checkGameOver();
      setState(() {});
    }
  }

  void _moveRight() {
    bool moved = false;
    for (int r = 0; r < _size; r++) {
      final reversed = _board[r].reversed.toList();
      final result = _compressAndMerge(reversed);
      _board[r] = result.row.reversed.toList();
      moved = moved || result.moved;
    }
    if (moved) {
      _addRandomTile();
      _checkGameOver();
      setState(() {});
    }
  }

  void _moveUp() {
    bool moved = false;
    for (int c = 0; c < _size; c++) {
      final col = List<int>.generate(_size, (r) => _board[r][c]);
      final result = _compressAndMerge(col);
      for (int r = 0; r < _size; r++) {
        _board[r][c] = result.row[r];
      }
      moved = moved || result.moved;
    }
    if (moved) {
      _addRandomTile();
      _checkGameOver();
      setState(() {});
    }
  }

  void _moveDown() {
    bool moved = false;
    for (int c = 0; c < _size; c++) {
      final col = List<int>.generate(_size, (r) => _board[r][c]).reversed.toList();
      final result = _compressAndMerge(col);
      final newCol = result.row.reversed.toList();
      for (int r = 0; r < _size; r++) {
        _board[r][c] = newCol[r];
      }
      moved = moved || result.moved;
    }
    if (moved) {
      _addRandomTile();
      _checkGameOver();
      setState(() {});
    }
  }

  _MoveResult _compressAndMerge(List<int> row) {
    final original = List<int>.from(row);
    // Sıfırları at ve sıkıştır
    final compressed = row.where((v) => v != 0).toList();
    // Merge
    for (int i = 0; i < compressed.length - 1; i++) {
      if (compressed[i] != 0 && compressed[i] == compressed[i + 1]) {
        compressed[i] *= 2;
        _score += compressed[i];
        compressed[i + 1] = 0;
      }
    }
    final merged = compressed.where((v) => v != 0).toList();
    while (merged.length < _size) {
      merged.add(0);
    }
    final moved = !_listEquals(original, merged);
    return _MoveResult(row: merged, moved: moved);
  }

  bool _listEquals(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  void _checkGameOver() {
    // Boş hücre varsa devam
    for (int r = 0; r < _size; r++) {
      for (int c = 0; c < _size; c++) {
        if (_board[r][c] == 0) {
          _gameOver = false;
          return;
        }
      }
    }
    // Komşu aynı sayı varsa devam
    for (int r = 0; r < _size; r++) {
      for (int c = 0; c < _size; c++) {
        final v = _board[r][c];
        if (r + 1 < _size && _board[r + 1][c] == v) {
          _gameOver = false;
          return;
        }
        if (c + 1 < _size && _board[r][c + 1] == v) {
          _gameOver = false;
          return;
        }
      }
    }
    if (!_gameOver) {
      _gameOver = true;
      _showGameOverDialog();
    }
  }

  void _showGameOverDialog() async {
    final int coinsEarned = (_score / 20).round();
    if (coinsEarned > 0) {
      PlayerInventory inventory = await _storageService.loadPlayerInventory();
      final updatedInventory = inventory.copyWith(fsCoinBalance: inventory.fsCoinBalance + coinsEarned);
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
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '2048 mini',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Renkli kareleri birleştir',
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
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white10,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.stars,
                          color: Colors.amberAccent,
                          size: 18,
                        ),
                        const SizedBox(width: 6),
                        const Text(
                          'Skor',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '$_score',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  if (_gameOver)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.redAccent.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'Oyun bitti',
                        style: TextStyle(
                          color: Colors.redAccent,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: Center(
                  child: GestureDetector(
                    onPanStart: _handlePanStart,
                    onPanUpdate: _handlePanUpdate,
                    onPanEnd: _handlePanEnd,
                    child: AspectRatio(
                      aspectRatio: 1,
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
                      child: GridView.builder(
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: _size,
                          mainAxisSpacing: 8,
                          crossAxisSpacing: 8,
                        ),
                        itemCount: _size * _size,
                        itemBuilder: (context, index) {
                          final r = index ~/ _size;
                          final c = index % _size;
                          final value = _board[r][c];
                          return _buildTile(value);
                        },
                      ),
                    ),
                  ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _startNewGame,
                    child: const Text('Sıfırla'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTile(int value) {
    final bg = _colorScheme[value] ?? const Color(0xFF22C55E);
    final isDarkText = value <= 4;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: bg,
        boxShadow: value == 0
            ? null
            : [
                BoxShadow(
                  color: bg.withOpacity(0.6),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: Center(
        child: Text(
          value == 0 ? '' : '$value',
          style: TextStyle(
            fontFamily: _fontFamily,
            color: isDarkText ? Colors.black : Colors.white,
            fontSize: value < 128 ? 20 : 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _MoveResult {
  final List<int> row;
  final bool moved;

  _MoveResult({required this.row, required this.moved});
}

// Color Schemes
Map<int, Color> _getDefaultColors() => {
  0: const Color(0xFF020617),
  2: const Color(0xFFEEF2FF),
  4: const Color(0xFFBFDBFE),
  8: const Color(0xFF93C5FD),
  16: const Color(0xFFA5B4FC),
  32: const Color(0xFF818CF8),
  64: const Color(0xFF6366F1),
  128: const Color(0xFFF97316),
  256: const Color(0xFFFB923C),
  512: const Color(0xFFEF4444),
  1024: const Color(0xFFE11D48),
  2048: const Color(0xFF22C55E),
};

Map<int, Color> _getNeonColors() => {
  0: const Color(0xFF020617),
  2: const Color(0xFF39FF14),
  4: const Color(0xFFF8FF01),
  8: const Color(0xFFFF00E5),
  16: const Color(0xFF00F0FF),
  32: const Color(0xFFFFA500),
  64: const Color(0xFFFF007F),
  128: const Color(0xFF7FFF00),
  256: const Color(0xFFD400FF),
  512: const Color(0xFFFF4500),
  1024: const Color(0xFF00FFFF),
  2048: const Color(0xFFFF1493),
};
