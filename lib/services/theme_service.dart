import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import './storage_service.dart';

/// Basit tema modeli
class AppTheme {
  final String name;
  final Brightness brightness;
  final Color backgroundColor;
  final Color surfaceColor;
  final Color primaryColor;

  const AppTheme({
    required this.name,
    required this.brightness,
    required this.backgroundColor,
    required this.surfaceColor,
    required this.primaryColor,
  });
}

class ThemeService extends ChangeNotifier {
  Color? _customPrimaryColor;
  final StorageService _storageService = StorageService();
  int _themeIndex = 2; // Varsayılan: Sistem

  int get themeIndex => _themeIndex;
  Color? get customPrimaryColor => _customPrimaryColor;

  bool get isDarkMode {
    if (_themeIndex == 2) {
      // System theme - check current platform brightness
      return SchedulerBinding.instance.platformDispatcher.platformBrightness ==
          Brightness.dark;
    }
    return themes[_themeIndex].brightness == Brightness.dark;
  }

  // Get current theme with dynamic system brightness
  AppTheme get currentTheme {
    if (_themeIndex < 0 || _themeIndex >= themes.length) {
      _themeIndex = 2;
    }
    
    if (_themeIndex == 2) {
      // System theme - return theme with current brightness
      final platformBrightness = SchedulerBinding.instance.platformDispatcher.platformBrightness;
      return AppTheme(
        name: 'Sistem',
        brightness: platformBrightness,
        backgroundColor: platformBrightness == Brightness.dark
            ? const Color(0xFF000000)
            : const Color(0xFFFFFFFF),
        surfaceColor: platformBrightness == Brightness.dark
            ? const Color(0xFF121212)
            : const Color(0xFFFFFFFF),
        primaryColor: const Color(0xFF1976D2),
      );
    }
    
    return themes[_themeIndex];
  }

  /// Logo yolu seçici
  String getLogoPath(String original) {
    if (isDarkMode) return original;
    switch (original) {
      case 'logo.png':
        return 'logow.png';
      case 'logo2.png':
        return 'logo2w.png';
      case 'Beta.png':
        return 'Betaw.png';
      case 'logo3.png':
        return 'betaw.png';
      case 'logo4.png':
        return 'betaw.png';
      default:
        return original;
    }
  }

  /// 3 Tema: Açık, Kapalı, Sistem
  static final List<AppTheme> themes = [
    // 0. Açık tema - tamamen beyaz ve temiz
    AppTheme(
      name: 'Açık',
      brightness: Brightness.light,
      backgroundColor: const Color(0xFFFFFFFF), // Tam beyaz arka plan
      surfaceColor: const Color(0xFFFFFFFF), // Beyaz kartlar
      primaryColor: const Color(0xFF1976D2), // Mavi ana renk
    ),

    // 1. Kapalı tema
    AppTheme(
      name: 'Kapalı',
      brightness: Brightness.dark,
      backgroundColor: const Color(0xFF000000), // saf siyah zemin
      surfaceColor: const Color(
        0xFF121212,
      ), // siyahtan daha açık koyu gri kartlar
      primaryColor: const Color(0xFF2563EB),
    ),

    // 2. Sistem teması - cihazın koyu/açık moduna göre değişir
    AppTheme(
      name: 'Sistem',
      brightness:
          SchedulerBinding.instance.platformDispatcher.platformBrightness,
      backgroundColor:
          SchedulerBinding.instance.platformDispatcher.platformBrightness ==
              Brightness.dark
          ? const Color(0xFF000000) // sistem karanlıkta saf siyah
          : const Color(0xFFFFFFFF), // sistem aydınlıkta tam beyaz
      surfaceColor:
          SchedulerBinding.instance.platformDispatcher.platformBrightness ==
              Brightness.dark
          ? const Color(0xFF121212)
          : const Color(0xFFFFFFFF),
      primaryColor: const Color(0xFF1976D2),
    ),
  ];

  Future<void> loadTheme() async {
    final savedIndex = await _storageService.getThemeIndex();
    if (savedIndex >= 0 && savedIndex < themes.length) {
      _themeIndex = savedIndex;
    } else {
      // Varsayılan artık Sistem
      _themeIndex = 2;
      await _storageService.setThemeIndex(_themeIndex);
    }
    await _loadCustomColor();
  }

  Future<void> setThemeIndex(int index, {bool force = false}) async {
    if (index < 0 || index >= themes.length) {
      return;
    }
    _themeIndex = index;
    await _storageService.setThemeIndex(index);
    await _loadCustomColor();
    notifyListeners();
  }

  Future<void> setPrimaryColor(String? colorHex) async {
    if (colorHex == null) {
      await _storageService.clearPrimaryColor();
      _customPrimaryColor = null;
    } else {
      await _storageService.savePrimaryColor(colorHex);
      _customPrimaryColor = Color(
        int.parse(colorHex.substring(1, 7), radix: 16) + 0xFF000000,
      );
    }
    notifyListeners();
  }

  Future<void> _loadCustomColor() async {
    final colorHex = await _storageService.getPrimaryColor();
    if (colorHex != null) {
      _customPrimaryColor = Color(
        int.parse(colorHex.substring(1, 7), radix: 16) + 0xFF000000,
      );
    } else {
      _customPrimaryColor = null;
    }
  }

  ThemeData get currentThemeData {
    final theme = currentTheme;
    final primaryColor = _customPrimaryColor ?? theme.primaryColor;

    final colorScheme = ColorScheme.fromSeed(
      seedColor: primaryColor,
      brightness: theme.brightness,
      background: theme.backgroundColor,
      surface: theme.surfaceColor,
      onBackground: theme.brightness == Brightness.dark
          ? Colors.white
          : Colors.black87,
      onSurface: theme.brightness == Brightness.dark
          ? Colors.white
          : Colors.black87,
    );

    return ThemeData(
      brightness: theme.brightness,
      primaryColor: primaryColor,
      scaffoldBackgroundColor: theme.backgroundColor,
      colorScheme: colorScheme,
      appBarTheme: AppBarTheme(
        backgroundColor: theme.backgroundColor,
        elevation: 0,
        iconTheme: IconThemeData(
          color: theme.brightness == Brightness.dark
              ? Colors.white
              : Colors.black87,
        ),
        titleTextStyle: TextStyle(
          color: theme.brightness == Brightness.dark
              ? Colors.white
              : Colors.black87,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      ),
      cardColor: theme.surfaceColor,
      dialogBackgroundColor: theme.surfaceColor,
      textTheme: TextTheme(
        bodyLarge: TextStyle(
          color: theme.brightness == Brightness.dark
              ? Colors.white
              : Colors.black87,
        ),
        bodyMedium: TextStyle(
          color: theme.brightness == Brightness.dark
              ? Colors.white
              : Colors.black87,
        ),
        displayLarge: TextStyle(
          color: theme.brightness == Brightness.dark
              ? Colors.white
              : Colors.black87,
        ),
        titleLarge: TextStyle(
          color: theme.brightness == Brightness.dark
              ? Colors.white
              : Colors.black87,
        ),
        titleMedium: TextStyle(
          color: theme.brightness == Brightness.dark
              ? Colors.white
              : Colors.black87,
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: theme.surfaceColor,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
      ),
      fontFamily: 'Roboto',
    );
  }
}

final ThemeService themeService = ThemeService();
