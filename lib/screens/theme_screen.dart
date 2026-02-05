import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:foresee/services/theme_service.dart';

class ThemeScreen extends StatefulWidget {
  const ThemeScreen({super.key});

  @override
  State<ThemeScreen> createState() => _ThemeScreenState();
}

class _ThemeScreenState extends State<ThemeScreen> {
  // 'foresee' | 'light' | 'dark' | 'system'
  String _selectedTheme = 'foresee';

  @override
  void initState() {
    super.initState();
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _selectedTheme = prefs.getString('foreweb_theme_mode') ?? 'foresee';
      });
    }
  }

  Future<void> _selectTheme(String themeViewMode) async {
    setState(() {
      _selectedTheme = themeViewMode;
    });

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('foreweb_theme_mode', themeViewMode);

    // Seçim sonrası kısa bir gecikme ile ekranı kapat ve sonucu dön
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) {
        Navigator.pop(context, 'THEME_CHANGED');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Ana uygulama teması (ForeSee) rengini al
    final isMainDark = themeService.isDarkMode;

    // UI renklerini belirle (_selectedTheme henüz uygulanmadı, bu ayar ekranı olduğu için
    // uygulamanın kendi temasını kullanarak tutarlılık sağlıyoruz)
    final backgroundColor = isMainDark ? const Color(0xFF0A0A0A) : Colors.white;
    final textColor = isMainDark ? Colors.white : Colors.black87;
    final itemColor = isMainDark ? const Color(0xFF1A1A1A) : Colors.grey[100]!;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: backgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Görünüm',
          style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildThemeOption(
            id: 'foresee',
            title: 'ForeSee',
            description: 'Uygulama temasını takip eder',
            icon: Icons.sync,
            color: Colors.blue,
            isSelected: _selectedTheme == 'foresee',
            backgroundColor: itemColor,
            textColor: textColor,
          ),
          const SizedBox(height: 12),
          _buildThemeOption(
            id: 'light',
            title: 'Açık',
            description: 'Klasik aydınlık görünüm',
            icon: Icons.wb_sunny_outlined,
            color: Colors.orange,
            isSelected: _selectedTheme == 'light',
            backgroundColor: itemColor,
            textColor: textColor,
          ),
          const SizedBox(height: 12),
          _buildThemeOption(
            id: 'dark',
            title: 'Koyu',
            description: 'Göz yormayan karanlık mod',
            icon: Icons.nightlight_outlined,
            color: Colors.deepPurpleAccent,
            isSelected: _selectedTheme == 'dark',
            backgroundColor: itemColor,
            textColor: textColor,
          ),
          const SizedBox(height: 12),
          _buildThemeOption(
            id: 'system',
            title: 'Sistem',
            description: 'Cihaz ayarlarına uyum sağlar',
            icon: Icons.settings_brightness,
            color: Colors.grey,
            isSelected: _selectedTheme == 'system',
            backgroundColor: itemColor,
            textColor: textColor,
          ),
        ],
      ),
    );
  }

  Widget _buildThemeOption({
    required String id,
    required String title,
    required String description,
    required IconData icon,
    required Color color,
    required bool isSelected,
    required Color backgroundColor,
    required Color textColor,
  }) {
    return GestureDetector(
      onTap: () => _selectTheme(id),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(16),
          border: isSelected
              ? Border.all(color: Colors.blue, width: 2)
              : Border.all(color: Colors.transparent, width: 2),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: textColor,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: TextStyle(
                      color: textColor.withOpacity(0.6),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              const Icon(Icons.check_circle, color: Colors.blue, size: 24),
          ],
        ),
      ),
    );
  }
}
