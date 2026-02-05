import 'dart:math';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
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

  // Render Objects
  final List<Particle> _particles = [];
  bool _particlesEnabled = false;

  // Customization
  String _fontKey = 'default'; // 'default'
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
    final equippedFontId =
        inventory.equippedItems[GameId.game2048.toString()]?[ItemType.fontStyle
            .toString()];
    final equippedEffectId = inventory
        .equippedItems[GameId.game2048.toString()]?[ItemType.effect.toString()];

    final equippedColorId =
        inventory.equippedItems[GameId.game2048.toString()]?[ItemType.cardColor
            .toString()];

    if (equippedFontId != null) {
      final shopItem = _shopService.allItems.firstWhere(
        (item) => item.id == equippedFontId,
      );
      if (shopItem.value is String) {
        _fontKey = shopItem.value;
      }
    }

    if (equippedEffectId != null) {
      final shopItem = _shopService.allItems.firstWhere(
        (item) => item.id == equippedEffectId,
      );
      if (shopItem.value == 'explosion') {
        _particlesEnabled = true;
      }
    }

    if (equippedColorId != null) {
      final shopItem = _shopService.allItems.firstWhere(
        (item) => item.id == equippedColorId,
      );
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
    // Start animation loop for particles
    if (_particlesEnabled) {
      _tickParticles();
    }
    setState(() {});
  }

  void _tickParticles() {
    if (!mounted) return;
    if (_particles.isNotEmpty) {
      setState(() {
        _particles.removeWhere((p) => p.isDead);
        for (var p in _particles) {
          p.update();
        }
      });
      Future.delayed(const Duration(milliseconds: 16), _tickParticles);
    } else {
      Future.delayed(
        const Duration(milliseconds: 100),
        _tickParticles,
      ); // Idle check
    }
  }

  void _spawnExplosion(int r, int c, Color color) {
    if (!_particlesEnabled) return;
    for (int i = 0; i < 20; i++) {
      _particles.add(Particle(r: r, c: c, color: color));
    }
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

  /// Sıfırlama onayı için dialog göster
  Future<void> _showResetConfirmation() async {
    if (_score == 0) {
      _startNewGame();
      return;
    }
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF020617),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Oyunu sıfırlamak istediğine emin misin?',
          style: TextStyle(color: Colors.white, fontSize: 16),
        ),
        content: Text(
          'Şu anki skorun: $_score\nSıfırlarsan bu skoru kaybedecek ve FsCoin kazanamayacaksın.',
          style: const TextStyle(color: Colors.white70, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('İptal'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text(
              'Sıfırla',
              style: TextStyle(color: Colors.orangeAccent),
            ),
          ),
        ],
      ),
    );
    if (result == true) {
      _startNewGame();
    }
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
      final result = _compressAndMerge(row, r, true); // true for isRow
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
      final result = _compressAndMerge(reversed, r, true, revert: true);
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
      final result = _compressAndMerge(col, c, false); // false for isRow
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
      final col = List<int>.generate(
        _size,
        (r) => _board[r][c],
      ).reversed.toList();
      final result = _compressAndMerge(col, c, false, revert: true);
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

  _MoveResult _compressAndMerge(
    List<int> line,
    int index,
    bool isRow, {
    bool revert = false,
  }) {
    // 1. Remove zeros
    List<int> newLine = line.where((e) => e != 0).toList();

    // 2. Merge adjacent
    bool moved = false;
    for (int i = 0; i < newLine.length - 1; i++) {
      if (newLine[i] == newLine[i + 1]) {
        newLine[i] *= 2;
        _score += newLine[i];

        // Spawn explosion
        if (_particlesEnabled) {
          int displayIndex = i;
          if (revert) {
            displayIndex = _size - 1 - i;
          }

          int r = 0, c = 0;
          if (isRow) {
            r = index;
            c = displayIndex;
          } else {
            r = displayIndex;
            c = index;
          }
          _spawnExplosion(r, c, _getTileColor(newLine[i]));
        }

        newLine.removeAt(i + 1);
        moved = true;
      }
    }

    // 3. Fill zeros
    while (newLine.length < _size) {
      newLine.add(0);
    }

    // Check if distinct from original (ignoring trailing zeros if only shift happened)
    // Because we just reconstructed newLine, let's compare with input 'line' carefully.
    // Actually, simple list comparison is fine if we ensure 'line' is full size logic.
    if (!moved) {
      if (line.length == newLine.length) {
        for (int i = 0; i < _size; i++) {
          if (line[i] != newLine[i]) {
            moved = true;
            break;
          }
        }
      } else {
        moved = true; // Should not happen if well formed
      }
    }

    return _MoveResult(row: newLine, moved: moved);
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
                        style: TextStyle(color: Colors.white38, fontSize: 12),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
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
                          style: TextStyle(color: Colors.white70, fontSize: 12),
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
                        horizontal: 10,
                        vertical: 4,
                      ),
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
                            colors: [Color(0xFF020617), Color(0xFF111827)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          border: Border.all(color: Colors.white10),
                        ),
                        padding: const EdgeInsets.all(12),
                        child: Stack(
                          children: [
                            GridView.builder(
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
                            if (_particlesEnabled && _particles.isNotEmpty)
                              IgnorePointer(
                                child: CustomPaint(
                                  size: Size.infinite,
                                  painter: _ParticlePainter(_particles, _size),
                                ),
                              ),
                          ],
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
                    onPressed: _showResetConfirmation,
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

  Color _getTileColor(int value) {
    return _colorScheme[value] ?? const Color(0xFF22C55E);
  }

  Widget _buildTile(int value) {
    final bg = _getTileColor(value);
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
          style: _getTileTextStyle(value, isDarkText),
        ),
      ),
    );
  }

  /// Font key'e göre GoogleFonts ile TextStyle döndür
  TextStyle _getTileTextStyle(int value, bool isDarkText) {
    final color = isDarkText ? Colors.black : Colors.white;
    final fontSize = value < 128 ? 20.0 : 16.0;
    const fontWeight = FontWeight.w700;

    switch (_fontKey) {
      case 'roboto':
        return GoogleFonts.roboto(
          color: color,
          fontSize: fontSize,
          fontWeight: fontWeight,
        );
      case 'poppins':
        return GoogleFonts.poppins(
          color: color,
          fontSize: fontSize,
          fontWeight: fontWeight,
        );
      case 'orbitron':
        return GoogleFonts.orbitron(
          color: color,
          fontSize: fontSize,
          fontWeight: fontWeight,
        );
      default:
        return TextStyle(
          color: color,
          fontSize: fontSize,
          fontWeight: fontWeight,
        );
    }
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

class Particle {
  double x; // Relative to tile (0.0 to 1.0)
  double y;
  final int r; // Grid Row
  final int c; // Grid Col
  double vx;
  double vy;
  double life = 1.0;
  final Color color;

  Particle({required this.r, required this.c, required this.color})
    : x = 0.5,
      y = 0.5,
      vx = (Random().nextDouble() - 0.5) * 0.1,
      vy = (Random().nextDouble() - 0.5) * 0.1;

  bool get isDead => life <= 0;

  void update() {
    x += vx;
    y += vy;
    life -= 0.05;
  }
}

class _ParticlePainter extends CustomPainter {
  final List<Particle> particles;
  final int gridSize;

  _ParticlePainter(this.particles, this.gridSize);

  @override
  void paint(Canvas canvas, Size size) {
    if (particles.isEmpty) return;

    final cellWidth = size.width / gridSize;
    final cellHeight = size.height / gridSize;

    for (var p in particles) {
      final paint = Paint()
        ..color = p.color.withOpacity(p.life)
        ..style = PaintingStyle.fill;

      final double absX = (p.c * cellWidth) + (p.x * cellWidth);
      final double absY = (p.r * cellHeight) + (p.y * cellHeight);

      canvas.drawCircle(Offset(absX, absY), 3 + (4 * p.life), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
