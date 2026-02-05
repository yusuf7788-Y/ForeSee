import 'package:flutter/material.dart';
import '../models/player_inventory.dart';
import '../models/shop_item.dart';
import '../services/shop_service.dart';
import '../services/storage_service.dart';
import 'offline_game_screen.dart';
import 'memory_game_screen.dart';
import 'simon_game_screen.dart';
import 'mini_2048_screen.dart';
import 'wordle_game_screen.dart';

class MiniGamesHubScreen extends StatefulWidget {
  const MiniGamesHubScreen({super.key});

  @override
  State<MiniGamesHubScreen> createState() => _MiniGamesHubScreenState();
}

class _MiniGamesHubScreenState extends State<MiniGamesHubScreen>
    with SingleTickerProviderStateMixin {
  final StorageService _storageService = StorageService();
  final ShopService _shopService = ShopService();

  late TabController _tabController;
  PlayerInventory _inventory = PlayerInventory();
  List<ShopItem> _popularItems = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });
    final inventory = await _storageService.loadPlayerInventory();
    final popularItems = _shopService.getPopularItems();
    setState(() {
      _inventory = inventory;
      _popularItems = popularItems;
      _isLoading = false;
    });
  }

  Future<void> _equipItem(ShopItem item) async {
    setState(() {
      _inventory = _inventory.equipItem(item);
    });
    await _storageService.savePlayerInventory(_inventory);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${item.name} kuşandı!'),
          backgroundColor: Colors.blue,
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }

  Future<void> _unequipItem(ShopItem item) async {
    setState(() {
      _inventory = _inventory.unequipItem(item);
    });
    await _storageService.savePlayerInventory(_inventory);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${item.name} çıkarıldı.'),
          backgroundColor: Colors.grey,
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }

  Future<void> _purchaseItem(ShopItem item) async {
    final updatedInventory = _inventory.purchaseItem(item);
    if (updatedInventory != _inventory) {
      // Satın alma başarılı olduysa
      setState(() {
        _inventory = updatedInventory;
      });
      await _storageService.savePlayerInventory(_inventory);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${item.name} satın alındı!'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 1),
          ),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Yetersiz FsCoin!'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 1),
          ),
        );
      }
    }
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
              _buildHeader(),
              const SizedBox(height: 16),
              _buildTabBar(),
              const SizedBox(height: 16),
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : TabBarView(
                        controller: _tabController,
                        children: [_buildGamesList(), _buildMarketList()],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
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
        const Text(
          'Mini Oyunlar',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white10,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.monetization_on,
                color: Colors.amberAccent,
                size: 18,
              ),
              const SizedBox(width: 6),
              Text(
                '${_inventory.fsCoinBalance}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTabBar() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFF020617),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white10),
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(999),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        labelColor: Colors.black,
        unselectedLabelColor: Colors.white70,
        labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        tabs: const [
          Tab(text: 'Oyunlar'),
          Tab(text: 'Market'),
        ],
      ),
    );
  }

  Widget _buildGamesList() {
    return ListView(
      children: [
        _MiniGameCard(
          title: 'Hafıza Kartları',
          description: 'Emoji kartlarını eşleştir, 3x4 veya 4x4 seç.',
          colors: const [Color(0xFF0EA5E9), Color(0xFF6366F1)],
          icon: Icons.grid_view,
          previewAsset: 'assets/asset1.png',
          onTap: () => _navigateToGame(const MemoryGameScreen()),
        ),
        const SizedBox(height: 12),
        _MiniGameCard(
          title: 'Refleks Oyunu',
          description: 'Mavi halkaya hızlıca dokun, reflekslerini test et.',
          colors: const [Color(0xFF22C55E), Color(0xFF16A34A)],
          icon: Icons.touch_app,
          previewAsset: 'assets/asset2.png',
          onTap: () => _navigateToGame(const OfflineGameScreen()),
        ),
        const SizedBox(height: 12),
        _MiniGameCard(
          title: '2048 Mini',
          description: 'Renkli kareleri birleştir, yüksek skoru yakala.',
          colors: const [Color(0xFFF97316), Color(0xFFEC4899)],
          icon: Icons.calculate,
          previewAsset: 'assets/asset3.png',
          onTap: () => _navigateToGame(const Mini2048Screen()),
        ),
        const SizedBox(height: 12),
        _MiniGameCard(
          title: 'Renk Dizisi',
          description: 'Yanan renkleri sırayla tekrar et, seriyi uzat.',
          colors: const [Color(0xFF22D3EE), Color(0xFFA855F7)],
          icon: Icons.bolt,
          previewAsset: 'assets/asset4.png',
          onTap: () => _navigateToGame(const SimonGameScreen()),
        ),
        const SizedBox(height: 12),
        _MiniGameCard(
          title: 'Wordle Türkçe',
          description: '5 harfli kelimeyi 6 denemede tahmin et.',
          colors: const [Color(0xFF10B981), Color(0xFF059669)],
          icon: Icons.spellcheck,
          previewAsset: 'assets/asset5.png',
          onTap: () => _navigateToGame(const WordleGameScreen()),
        ),
      ],
    );
  }

  void _navigateToGame(Widget game) {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (context) => game))
        .then((_) => _loadData());
  }

  Widget _buildMarketList() {
    return ListView(
      children: [
        _buildSectionTitle('Popüler Ögeler'),
        ..._popularItems
            .map(
              (item) => _ShopItemCard(
                item: item,
                inventory: _inventory,
                onPurchase: _purchaseItem,
                onEquip: _equipItem,
                onUnequip: _unequipItem,
              ),
            )
            .toList(),
        _buildSectionTitle('Hafıza Oyunu'),
        ..._shopService
            .getItemsByGame(GameId.memoryGame)
            .map(
              (item) => _ShopItemCard(
                item: item,
                inventory: _inventory,
                onPurchase: _purchaseItem,
                onEquip: _equipItem,
                onUnequip: _unequipItem,
              ),
            )
            .toList(),
        _buildSectionTitle('Refleks Oyunu'),
        ..._shopService
            .getItemsByGame(GameId.reflexGame)
            .map(
              (item) => _ShopItemCard(
                item: item,
                inventory: _inventory,
                onPurchase: _purchaseItem,
                onEquip: _equipItem,
                onUnequip: _unequipItem,
              ),
            )
            .toList(),
        _buildSectionTitle('2048 Oyunu'),
        ..._shopService
            .getItemsByGame(GameId.game2048)
            .map(
              (item) => _ShopItemCard(
                item: item,
                inventory: _inventory,
                onPurchase: _purchaseItem,
                onEquip: _equipItem,
                onUnequip: _unequipItem,
              ),
            )
            .toList(),
        _buildSectionTitle('Renk dizisi Oyunu'),
        ..._shopService
            .getItemsByGame(GameId.simonGame)
            .map(
              (item) => _ShopItemCard(
                item: item,
                inventory: _inventory,
                onPurchase: _purchaseItem,
                onEquip: _equipItem,
                onUnequip: _unequipItem,
              ),
            )
            .toList(),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 8, left: 4),
      child: Text(
        title,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _MiniGameCard extends StatelessWidget {
  final String title, description;
  final List<Color> colors;
  final IconData icon;
  final VoidCallback onTap;
  final String? previewAsset;
  const _MiniGameCard({
    required this.title,
    required this.description,
    required this.colors,
    required this.icon,
    required this.onTap,
    this.previewAsset,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Ink(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            colors: colors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: Colors.white, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          description,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (previewAsset != null) ...[
                const SizedBox(height: 12),
                SizedBox(
                  height: 80,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: AspectRatio(
                            aspectRatio: 16 / 9,
                            child: Image.asset(
                              previewAsset!,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ShopItemCard extends StatelessWidget {
  final ShopItem item;
  final PlayerInventory inventory;
  final Function(ShopItem) onPurchase;
  final Function(ShopItem) onEquip;
  final Function(ShopItem) onUnequip;

  const _ShopItemCard({
    required this.item,
    required this.inventory,
    required this.onPurchase,
    required this.onEquip,
    required this.onUnequip,
  });

  @override
  Widget build(BuildContext context) {
    final isPurchased = inventory.purchasedItemIds.contains(item.id);
    final isEquipped =
        inventory.equippedItems[item.gameId.toString()]?[item.itemType
            .toString()] ==
        item.id;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.asset(
              item.previewAsset,
              width: 60,
              height: 60,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  item.description,
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: isPurchased
                ? (isEquipped
                      ? OutlinedButton.icon(
                          icon: const Icon(Icons.close, size: 16),
                          label: const Text('Çıkar'),
                          onPressed: () => onUnequip(item),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white70,
                            side: const BorderSide(color: Colors.white24),
                          ),
                        )
                      : ElevatedButton.icon(
                          icon: const Icon(
                            Icons.check_circle_outline,
                            size: 16,
                          ),
                          label: const Text('Kuşan'),
                          onPressed: () => onEquip(item),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                          ),
                        ))
                : ElevatedButton.icon(
                    icon: const Icon(Icons.shopping_cart, size: 16),
                    label: Text('${item.price} FsC'),
                    onPressed: () => onPurchase(item),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.amber,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
