import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/chat.dart';
import '../services/storage_service.dart';

class MainTabScreen extends StatefulWidget {
  const MainTabScreen({super.key});

  @override
  State<MainTabScreen> createState() => _MainTabScreenState();
}

class _MainTabScreenState extends State<MainTabScreen>
    with TickerProviderStateMixin {
  int _currentTab = 0; // 0: Sohbetler, 1: Ayarlar, 2: Yeni
  bool _logoVisible = true;
  final TextEditingController _inputController = TextEditingController();
  final StorageService _storageService = StorageService();

  @override
  void initState() {
    super.initState();
    _loadSavedInput();
  }

  Future<void> _loadSavedInput() async {
    final savedInput = await _storageService.getCurrentInput();
    if (savedInput.isNotEmpty) {
      setState(() {
        _inputController.text = savedInput;
      });
    }
  }

  Future<void> _saveInput() async {
    await _storageService.saveCurrentInput(_inputController.text);
  }

  Future<void> _loadSavedTab() async {
    final savedTab = await _storageService.getCurrentTab();
    if (savedTab != 0) {
      setState(() {
        _currentTab = savedTab;
      });
    }
  }

  Future<void> _saveCurrentInput() async {
    await _storageService.saveCurrentInput(_inputController.text);
  }

  void _switchTab(int newTab) {
    if (newTab == _currentTab) return;

    setState(() {
      _currentTab = newTab;
    });

    // Sekme değiştiğinde input'u kaydet
    _saveCurrentInput();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // Üst Bar: Logo Switch + Sekmeler
            _buildTopBar(),
            
            // Orta Alan: Sekme İçeriği
            Expanded(
              child: _buildTabContent(),
            ),
            
            // Alt Bar: Sekme Bilgisi
            _buildBottomBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Container(
      height: 80,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          // Logo Switch
          Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _logoVisible = !_logoVisible;
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: _logoVisible 
                      ? Theme.of(context).primaryColor.withOpacity(0.1)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(25),
                ),
                child: Switch(
                  value: _logoVisible,
                  onChanged: (value) {
                    setState(() {
                      _logoVisible = value;
                    });
                  },
                  activeColor: Theme.of(context).primaryColor,
                ),
              ),
            ),
          ),
          
          const SizedBox(width: 20),
          
          // 3 Sekme
          ...List.generate(3, (index) {
            final isActive = _currentTab == index;
            return Expanded(
              child: GestureDetector(
                onTap: () => _switchTab(index),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeInOut,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  decoration: BoxDecoration(
                    color: isActive 
                        ? Theme.of(context).primaryColor
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        _getTabIcon(index),
                        color: isActive ? Colors.white : Colors.grey.shade600,
                        size: 20,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _getTabTitle(index),
                        style: TextStyle(
                          color: isActive ? Colors.white : Colors.grey.shade600,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildTabContent() {
    switch (_currentTab) {
      case 0: // Sohbetler
        return _buildChatsTab();
      case 1: // Ayarlar
        return _buildSettingsTab();
      case 2: // Yeni
        return _buildNewChatTab();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildChatsTab() {
    return Column(
      children: [
        // Logo (Switch kapalıysa gösterilir)
        if (!_logoVisible) ...[
          const SizedBox(height: 20),
          Image.asset(
            'assets/logo.png',
            width: 40,
            height: 40,
          ),
          const SizedBox(height: 20),
        ],
        
        // Sohbet Listesi
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(16),
            child: const Center(
              child: Text(
                'Sohbetler Listesi',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSettingsTab() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: const Center(
        child: Text(
          'Ayarlar',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
        ),
      ),
    );
  }

  Widget _buildNewChatTab() {
    return Column(
      children: [
        // Logo (Switch kapalıysa gösterilir)
        if (!_logoVisible) ...[
          const SizedBox(height: 20),
          Image.asset(
            'assets/logo.png',
            width: 40,
            height: 40,
          ),
          const SizedBox(height: 20),
        ],
        
        // Yeni Sohbet
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // "Yeni sohbet" animasyonu
                AnimatedBuilder(
                  animation: const AlwaysStoppedAnimation<double>(0),
                  builder: (context, child) {
                    return AnimatedOpacity(
                      opacity: 0.3,
                      duration: const Duration(milliseconds: 500),
                      child: Text(
                        'Yeni sohbet',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).primaryColor,
                        ),
                      ),
                    );
                  },
                ),
                
                const SizedBox(height: 40),
                
                // Yeni sohbet butonu
                ElevatedButton(
                  onPressed: () {
                    // Yeni sohbet oluştur
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).primaryColor,
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  ),
                  child: const Text(
                    'Yeni Sohbet Oluştur',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBottomBar() {
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        border: Border(
          top: BorderSide(
            color: Colors.grey.shade300,
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        children: [
          // Işık hüzmesi
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: _getTabColor(_currentTab),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(4),
                topRight: Radius.circular(4),
              ),
            ),
          ),
          
          Expanded(
            child: Center(
              child: Text(
                _getTabInfo(),
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 12,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  IconData _getTabIcon(int index) {
    switch (index) {
      case 0: return Icons.chat;
      case 1: return Icons.settings;
      case 2: return Icons.add;
      default: return Icons.help;
    }
  }

  String _getTabTitle(int index) {
    switch (index) {
      case 0: return 'Sohbetler';
      case 1: return 'Ayarlar';
      case 2: return 'Yeni';
      default: return '';
    }
  }

  Color _getTabColor(int index) {
    switch (index) {
      case 0: return Colors.blue.shade400;
      case 1: return Colors.green.shade400;
      case 2: return Colors.orange.shade400;
      default: return Colors.grey.shade400;
    }
  }

  String _getTabInfo() {
    switch (_currentTab) {
      case 0: return 'Sohbetler arasında hızlı geçiş yapın';
      case 1: return 'Ayarlar arasında hızlı geçiş yapın';
      case 2: return 'Yeni sohbet oluşturun';
      default: return '';
    }
  }
}
