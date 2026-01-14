import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../models/user_profile.dart';
import '../services/storage_service.dart';
import '../services/theme_service.dart';
import '../services/context_service.dart';
import '../services/openrouter_service.dart';
import '../widgets/grey_notification.dart';
import '../widgets/theme_picker_panel.dart';
import '../services/import_export_service.dart';
import 'package:file_picker/file_picker.dart';

class SettingsScreen extends StatefulWidget {
  final String? highlightKey;

  const SettingsScreen({super.key, this.highlightKey});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final TextEditingController _memoryController = TextEditingController();
  final TextEditingController _promptController = TextEditingController();
  final TextEditingController _customFontController = TextEditingController();
  final TextEditingController _resetConfirmController = TextEditingController();
  final StorageService _storageService = StorageService();
  final ContextService _contextService = ContextService();
  final OpenRouterService _openRouterService = OpenRouterService();

  // Settings State
  String _savedMemory = '';
  String _savedPrompt = '';
  bool _isLoading = true;
  bool _notificationsEnabled = true;
  int _fontSizeIndex = 2;
  String? _fontFamily;
  UserProfile? _userProfile;
  int _themeIndex = 0;
  bool _isSmartContextEnabled = false;
  bool _isUsageTrackerEnabled = false;
  double _usageTimeThreshold = 90;
  bool _lockMemoryAi = false;
  bool _lockPromptAi = false;

  // Stats State
  int _totalCodeLines = 0;
  Map<String, int> _languageUsage = {};
  Map<String, int> _weeklyUsage = {};
  int _weeklyTotalMinutes = 0;

  final Map<String, GlobalKey> _settingKeys = {
    'Akıllı Bağlam': GlobalKey(),
    'Uygulama Kullanım Takibi': GlobalKey(),
  };
  bool _isHighlighting = false;

  final List<String> _fontOptions = [
    'Sistem (varsayılan)',
    'Roboto',
    'Montserrat',
    'Open Sans',
    'Lato',
    'PT Sans',
    'Nunito',
    'Poppins',
    'Source Sans Pro',
    'Merriweather',
  ];

  final Map<String, String> _promptTemplates = {
    'Komik':
        'Sen esprili ve mizah dolu bir asistansın. Cevaplarında hafif mizah kullan ama her zaman saygılı ol.',
    'Duygusal':
        'Kullanıcıya empatiyle yaklaşan, duygusal tonlu bir asistansın. Destekleyici ve anlayışlı cevaplar ver.',
    'Yazılımcı':
        'Kıdemli bir yazılım geliştiricisin. Teknik, detaylı ve örnek kodlarla açıklamalar yap.',
    'Finans Uzmanı':
        'Profesyonel bir finans ve ekonomi danışmanısın. Para yönetimi, yatırım ve bütçe konularında yardımcı ol.',
    'Öğretmen':
        'Sabırlı bir öğretmensin. Zor konuları bile adım adım ve çok anlaşılır şekilde anlat.',
    'Motivasyon Koçu':
        'Kullanıcıyı motive eden, cesaretlendiren ve pozitif bir koçsun. İlham veren cevaplar ver.',
    'Minimalist':
        'Mümkün olduğunca kısa, net ve sade cevaplar ver. Gereksiz detaylardan kaçın.',
    'Eleştirmen':
        'Yapıcı eleştiriler sunan, artıları ve eksileri net şekilde belirten bir uzmansın.',
    'Hikaye Anlatıcı':
        'Yaratıcı hikayeler ve örneklerle açıklama yapan bir anlatıcısın.',
    'Çevirmen':
        'Profesyonel bir çevirmen ve dil uzmanısın. Metinleri doğru ve doğal şekilde çevir.',
  };

  @override
  void initState() {
    super.initState();
    _loadSettings().then((_) {
      if (widget.highlightKey != null) {
        _scrollToAndHighlight(widget.highlightKey!);
      }
    });
  }

  Future<void> _loadSettings() async {
    try {
      final memory = await _storageService.getUserMemory();
      final prompt = await _storageService.getCustomPrompt();
      final notificationsEnabled = await _storageService
          .getNotificationsEnabled();
      final fontSizeIndex = await _storageService.getFontSizeIndex();
      final fontFamily = await _storageService.getFontFamily();
      final profile = await _storageService.loadUserProfile();
      final themeIndex = await _storageService.getThemeIndex();
      final isSmartContextEnabled = await _storageService
          .getIsSmartContextEnabled();
      final isUsageTrackerEnabled = await _storageService
          .getIsUsageTrackerEnabled();
      final usageTimeThreshold = await _storageService.getUsageTimeThreshold();
      final lockMemoryAi = await _storageService.getLockMemoryAi();
      final lockPromptAi = await _storageService.getLockPromptAi();

      // Stats fetching
      final totalCodeLines = await _storageService.getTotalCodeLines();
      final languageUsage = await _storageService.getLanguageUsageStats();
      final weeklyUsageRaw = await _storageService.getWeeklyUsageStats();

      int weeklyMins = 0;
      final now = DateTime.now();
      weeklyUsageRaw.forEach((key, val) {
        try {
          final date = DateTime.parse(key);
          if (now.difference(date).inDays <= 7) {
            weeklyMins += val;
          }
        } catch (_) {}
      });

      setState(() {
        _savedMemory = memory;
        _savedPrompt = prompt;
        _memoryController.text = memory;
        _promptController.text = prompt;
        _notificationsEnabled = notificationsEnabled;
        _fontSizeIndex = fontSizeIndex;
        _fontFamily = (fontFamily == null || fontFamily.isEmpty)
            ? null
            : fontFamily;
        _customFontController.text = _fontFamily ?? '';
        _userProfile = profile;
        _themeIndex = themeIndex;
        _isSmartContextEnabled = isSmartContextEnabled;
        _isUsageTrackerEnabled = isUsageTrackerEnabled;
        _usageTimeThreshold = usageTimeThreshold;
        _lockMemoryAi = lockMemoryAi;
        _lockPromptAi = lockPromptAi;
        _lockMemoryAi = lockMemoryAi;
        _lockPromptAi = lockPromptAi;

        _totalCodeLines = totalCodeLines;
        _languageUsage = languageUsage;
        _weeklyUsage = weeklyUsageRaw;
        _weeklyTotalMinutes = weeklyMins;

        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _scrollToAndHighlight(String key) {
    final globalKey = _settingKeys[key];
    if (globalKey != null && globalKey.currentContext != null) {
      Future.delayed(const Duration(milliseconds: 300), () {
        Scrollable.ensureVisible(
          globalKey.currentContext!,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        ).then((_) {
          setState(() => _isHighlighting = true);
          Future.delayed(const Duration(milliseconds: 1500), () {
            setState(() => _isHighlighting = false);
          });
        });
      });
    }
  }

  @override
  void dispose() {
    _memoryController.dispose();
    _promptController.dispose();
    _customFontController.dispose();
    _resetConfirmController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = themeService.isDarkMode;
    
    // Theme Colors
    final bgStart = isDark ? const Color(0xFF0F0F13) : theme.colorScheme.background;
    final textColor = isDark ? Colors.white : theme.colorScheme.onBackground;
    final iconColor = isDark ? Colors.white : Colors.black87;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(color: Colors.black.withOpacity(0.2)),
          ),
        ),
        title: Text(
          'Ayarlar',
          style: TextStyle(
            color: textColor,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
        centerTitle: true,
        leading: Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withOpacity(0.1) : theme.colorScheme.surface.withOpacity(0.8),
            shape: BoxShape.circle,
          ),
          child: IconButton(
            icon: FaIcon(
              FontAwesomeIcons.arrowLeft,
              color: iconColor,
              size: 14,
            ),
            onPressed: () => Navigator.pop(context),
            padding: EdgeInsets.zero,
          ),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: isDark ? const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0F0F13), Color(0xFF1A1A24)],
          ) : null,
          color: isDark ? null : bgStart,
        ),
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: Colors.white),
              )
            : SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 100, 20, 20),
                child: Column(
                  children: [
                    _buildStatisticsSection(),
                    const SizedBox(height: 24),
                    _buildSectionHeader('YAPAY ZEKA', FontAwesomeIcons.brain),
                    _buildGlassCard(
                      child: Column(
                        children: [
                          _buildMemoryTile(),
                          _buildDivider(),
                          _buildPromptTile(),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    _buildSectionHeader('GÖRÜNÜM', FontAwesomeIcons.palette),
                    _buildGlassCard(
                      child: Column(
                        children: [
                          _buildThemeTile(),
                          _buildDivider(),
                          _buildFontTile(),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    _buildSectionHeader('DENEYİM', FontAwesomeIcons.sliders),
                    _buildGlassCard(
                      child: Column(
                        children: [
                          _buildNotificationTile(),
                          _buildDivider(),
                          // _buildSmartContextTile(), // Removed from previous simple UI if unused, kept if needed
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    _buildSectionHeader(
                      'VERİ VE YEDEKLEME',
                      FontAwesomeIcons.database,
                    ),
                    _buildGlassCard(
                      child: Column(children: [_buildImportTile()]),
                    ),
                    const SizedBox(height: 24),
                    _buildResetButton(),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
      ),
    );
  }

  // --- UI Components ---

  Widget _buildSectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      child: Row(
        children: [
          Icon(icon, color: themeService.isDarkMode ? Colors.blueAccent.shade100 : Colors.blue.shade600, size: 16),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              color: themeService.isDarkMode ? Colors.blueAccent.shade100 : Colors.blue.shade600,
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGlassCard({required Widget child, Color? color}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          decoration: BoxDecoration(
            color: color ?? (themeService.isDarkMode ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.02)),
            border: Border.all(color: themeService.isDarkMode ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.06)),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: themeService.isDarkMode ? Colors.black.withOpacity(0.1) : Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Divider(
      height: 1,
      thickness: 1,
      color: themeService.isDarkMode ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.08),
      indent: 16,
      endIndent: 16,
    );
  }

  // --- Statistics Section ---

  Widget _buildStatisticsSection() {
    // Find most used language
    String topLang = "Yok";
    int maxLines = 0;
    _languageUsage.forEach((lang, lines) {
      if (lines > maxLines) {
        maxLines = lines;
        topLang = lang;
      }
    });

    return Column(
      children: [
        _buildSectionHeader('HAFTALIK ÖZET', FontAwesomeIcons.chartPie),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                'Kod Satırı',
                '$_totalCodeLines',
                FontAwesomeIcons.code,
                Colors.purpleAccent.shade100,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                'ForeSee Süresi',
                '${(_weeklyTotalMinutes / 60).toStringAsFixed(1)}s',
                FontAwesomeIcons.clock,
                Colors.orangeAccent.shade100,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: themeService.isDarkMode ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.02),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: themeService.isDarkMode ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.06)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Favori Dil',
                    style: TextStyle(color: themeService.isDarkMode ? Colors.white54 : Colors.black54, fontSize: 13),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    topLang.toUpperCase(),
                    style: TextStyle(
                      color: themeService.isDarkMode ? Colors.white : Colors.black,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const FaIcon(
                  FontAwesomeIcons.trophy,
                  color: Colors.blue,
                  size: 20,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: themeService.isDarkMode ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.02),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: themeService.isDarkMode ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 16),
          Text(
            value,
            style: TextStyle(
              color: themeService.isDarkMode ? Colors.white : Colors.black,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              color: themeService.isDarkMode ? Colors.white.withOpacity(0.5) : Colors.black.withOpacity(0.5),
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  // --- Content Tiles ---

  Widget _buildMemoryTile() {
    return ExpansionTile(
      tilePadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      leading: FaIcon(
        FontAwesomeIcons.userAstronaut,
        color: themeService.isDarkMode ? Colors.white : Colors.black87,
        size: 22,
      ),
      title: Text(
        'Kullanıcı Belleği',
        style: TextStyle(color: themeService.isDarkMode ? Colors.white : Colors.black87),
      ),
      subtitle: Text(
        _savedMemory.isEmpty
            ? 'Henüz bilgi yok'
            : _savedMemory.replaceAll('\n', ' '),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: themeService.isDarkMode ? Colors.white.withOpacity(0.5) : Colors.black.withOpacity(0.5)),
      ),
      iconColor: Colors.white70,
      collapsedIconColor: Colors.white54,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'AI\'nın seni tanıması için kendini anlat. İsim, meslek, hobiler...',
                style: TextStyle(color: themeService.isDarkMode ? Colors.white54 : Colors.black54, fontSize: 13),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _memoryController,
                maxLines: 4,
                style: TextStyle(color: themeService.isDarkMode ? Colors.white : Colors.black),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: themeService.isDarkMode ? Colors.black12 : Colors.black.withOpacity(0.05),
                  hintText: 'Kendinizden bahsedin...',
                  hintStyle: TextStyle(color: themeService.isDarkMode ? Colors.white30 : Colors.black38),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  // Trash can button
                  IconButton(
                    icon: FaIcon(
                      FontAwesomeIcons.trashCan,
                      color: Colors.white,
                      size: 16,
                    ),
                    iconSize: 16,
                    padding: const EdgeInsets.all(4),
                    constraints: const BoxConstraints(
                      minWidth: 24,
                      minHeight: 24,
                    ),
                    onPressed: () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          backgroundColor: themeService.isDarkMode ? const Color(0xFF1A1A1A) : Colors.white,
                          title: Text(
                            'Temizle',
                            style: TextStyle(color: themeService.isDarkMode ? Colors.white : Colors.black87),
                          ),
                          content: Text(
                            'Bellek tamamen silinecek. Emin misiniz?',
                            style: TextStyle(color: themeService.isDarkMode ? Colors.white70 : Colors.black54),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: Text(
                                'İptal',
                                style: TextStyle(color: themeService.isDarkMode ? Colors.white54 : Colors.black54),
                              ),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, true),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.redAccent,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: const Text(
                                'Sil',
                                style: TextStyle(color: Colors.white),
                              ),
                            ),
                          ],
                        ),
                      );
                      if (confirm == true) {
                        setState(() {
                          _memoryController.clear();
                        });
                        await _storageService.saveUserMemory('');
                      }
                    },
                  ),
                  const SizedBox(width: 4),
                  // Sparkles button - Sadece sistem prompt'ta olsun
                ],
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: _saveMemory,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: const Text(
                  'Kaydet',
                  style: TextStyle(color: Colors.white),
                ),
              ),
              const SizedBox(height: 16),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                activeColor: Colors.redAccent,
                title: Text(
                  'AI\'ın belleğe karışmasına izin verme',
                  style: TextStyle(color: themeService.isDarkMode ? Colors.white : Colors.black, fontSize: 13),
                ),
                value: _lockMemoryAi,
                onChanged: (val) async {
                  setState(() => _lockMemoryAi = val);
                  await _storageService.setLockMemoryAi(val);
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPromptTile() {
    return ExpansionTile(
      tilePadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      leading: FaIcon(
        FontAwesomeIcons.terminal,
        color: themeService.isDarkMode ? Colors.white : Colors.black87,
        size: 20,
      ),
      title: Text('Sistem Prompt', style: TextStyle(color: themeService.isDarkMode ? Colors.white : Colors.black87)),
      subtitle: Text(
        'AI davranışını özelleştir',
        style: TextStyle(color: themeService.isDarkMode ? Colors.white54 : Colors.black54),
      ),
      iconColor: themeService.isDarkMode ? Colors.white70 : Colors.black54,
      collapsedIconColor: themeService.isDarkMode ? Colors.white54 : Colors.black38,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Horizontal scrollable templates
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _promptTemplates.keys.map((key) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ActionChip(
                        label: Text(key),
                        backgroundColor: themeService.isDarkMode ? Colors.white10 : Colors.black.withOpacity(0.05),
                        labelStyle: TextStyle(
                          color: themeService.isDarkMode ? Colors.white70 : Colors.black87,
                          fontSize: 12,
                        ),
                        onPressed: () {
                          _promptController.text = _promptTemplates[key]!;
                        },
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _promptController,
                maxLines: 4,
                style: TextStyle(color: themeService.isDarkMode ? Colors.white : Colors.black),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: themeService.isDarkMode ? Colors.black12 : Colors.black.withOpacity(0.05),
                  hintText: 'Prompt yaz...',
                  hintStyle: TextStyle(color: themeService.isDarkMode ? Colors.white30 : Colors.black38),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  // Trash can button
                  IconButton(
                    icon: FaIcon(
                      FontAwesomeIcons.trashCan,
                      color: Colors.white,
                      size: 16,
                    ),
                    iconSize: 16,
                    padding: const EdgeInsets.all(4),
                    constraints: const BoxConstraints(
                      minWidth: 24,
                      minHeight: 24,
                    ),
                    onPressed: () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          backgroundColor: themeService.isDarkMode ? const Color(0xFF1A1A1A) : Colors.white,
                          title: Text(
                            'Temizle',
                            style: TextStyle(color: themeService.isDarkMode ? Colors.white : Colors.black87),
                          ),
                          content: Text(
                            'Sistem promptu tamamen silinecek. Emin misiniz?',
                            style: TextStyle(color: themeService.isDarkMode ? Colors.white70 : Colors.black54),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: Text(
                                'İptal',
                                style: TextStyle(color: themeService.isDarkMode ? Colors.white54 : Colors.black54),
                              ),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, true),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.redAccent,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: const Text(
                                'Sil',
                                style: TextStyle(color: Colors.white),
                              ),
                            ),
                          ],
                        ),
                      );
                      if (confirm == true) {
                        setState(() {
                          _promptController.clear();
                        });
                        await _storageService.saveCustomPrompt('');
                      }
                    },
                  ),
                  const SizedBox(width: 4),
                  // Sparkles button
                  IconButton(
                    icon: FaIcon(
                      FontAwesomeIcons.wandMagicSparkles,
                      color: Colors.white,
                      size: 16,
                    ),
                    iconSize: 16,
                    padding: const EdgeInsets.all(4),
                    constraints: const BoxConstraints(
                      minWidth: 24,
                      minHeight: 24,
                    ),
                    onPressed: () async {
                      await _enhancePromptWithAI();
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: _savePrompt,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: const Text(
                  'Kaydet',
                  style: TextStyle(color: Colors.white),
                ),
              ),
              const SizedBox(height: 16),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                activeColor: Colors.redAccent,
                title: Text(
                  'AI\'ın prompta karışmasına izin verme',
                  style: TextStyle(color: themeService.isDarkMode ? Colors.white54 : Colors.black54, fontSize: 13),
                ),
                value: _lockPromptAi,
                onChanged: (val) async {
                  setState(() => _lockPromptAi = val);
                  await _storageService.setLockPromptAi(val);
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _enhancePromptWithAI() async {
    final currentPrompt = _promptController.text.trim();
    print('DEBUG: Current prompt: "$currentPrompt"');
    
    if (currentPrompt.isEmpty) {
      GreyNotification.show(context, 'Önce bir prompt yazın');
      return;
    }

    // Check if prompt has at least 1 meaningful word
    final words = currentPrompt.split(' ').where((word) => word.trim().isNotEmpty).toList();
    print('DEBUG: Words count: ${words.length}');
    
    if (words.isEmpty) {
      GreyNotification.show(context, 'Prompt en az 1 anlaşılır kelime içermeli');
      return;
    }

    setState(() => _isLoading = true);

    // Loading overlay göster
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Container(
        color: Colors.black.withOpacity(0.3),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
          child: const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              strokeWidth: 3,
            ),
          ),
        ),
      ),
    );

    try {
      final enhancedPrompt = await _openRouterService.sendMessageWithHistory(
        [],
        '''Sen profesyonel bir Prompt Enhancer AI'sın. Görevin, kullanıcının verdiği promptu ($currentPrompt) anlamını, amacını ve niyetini %100 koruyarak; onu daha detaylı, daha net, daha etkili, daha profesyonel ve daha güçlü hale getirmektir.

  Bunu yaparken:

  Orijinal promptun hedefini asla değiştirme.

  Anlamı genişlet, derinleştir ve yapay zekânın daha kaliteli cevap üretmesini sağlayacak şekilde yapılandır.

  Gerekirse rol tanımları ekle (örnek: "Sen deneyimli bir …'sın", "Uzman bakış açısıyla yaklaş").

  Gerekirse ton, stil, kişilik, davranış ve iletişim biçimi ekle.

  Belirsiz ifadeleri netleştir.

  Kapsamı genişlet ama dağınık hale getirme.

  Profesyonel, akıcı ve sistem promptu kalitesinde yaz.

  Eğer kullanıcı kısa veya tek kelimelik bir ifade girdiyse (örnek: "Dost"), bunu bir sistem davranışı tanımı olarak yorumla ve:

  Yapay zekânın karakterini, konuşma tarzını, tavrını ve kullanıcıyla kuracağı ilişkiyi tanımlayan güçlü bir sistem promptuna dönüştür.

  Örnek: "Dost" → samimi, güven veren, destekleyici, içten, motive edici, yargılamayan bir kişilik profili oluştur.

  Çıktı kuralları:

  Sadece geliştirilmiş promptu ver.

  Açıklama yapma, yorum ekleme.

  Başlık kullanma.

  Kod bloğu içine alma.

  Direkt çalıştırılabilir bir sistem promptu formatında yaz.

  Geliştirilecek prompt:
  $currentPrompt''',
        model: 'meta-llama/llama-3.3-70b-instruct:free',
      );
      
      print('DEBUG: Enhanced prompt: "$enhancedPrompt"');

      if (enhancedPrompt.trim().isNotEmpty) {
        setState(() {
          _promptController.text = enhancedPrompt.trim();
        });
        GreyNotification.show(context, 'Prompt başarıyla geliştirildi!');
      } else {
        GreyNotification.show(context, 'Prompt geliştirilemedi');
      }
    } catch (e) {
      print('DEBUG: Error: $e');
      GreyNotification.show(context, 'Hata: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
        // Loading overlay'ı kapat
        Navigator.of(context).pop();
      }
    }
  }

  Widget _buildThemeTile() {
    final themes = ThemeService.themes;
    final index = (_themeIndex >= 0 && _themeIndex < themes.length)
        ? _themeIndex
        : 0;
    final currentTheme = themes[index];

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      leading: FaIcon(
        FontAwesomeIcons.brush,
        color: themeService.isDarkMode ? Colors.white : Colors.black87,
        size: 20,
      ),
      title: Text('Renk Teması', style: TextStyle(color: themeService.isDarkMode ? Colors.white : Colors.black87)),
      subtitle: Text(
        currentTheme.name == 'Sistem' 
            ? 'Sistem (${MediaQuery.of(context).platformBrightness == Brightness.dark ? 'Koyu' : 'Açık'})'
            : currentTheme.name,
        style: TextStyle(color: themeService.isDarkMode ? Colors.white54 : Colors.black54),
      ),
      trailing: Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          color: currentTheme.name == 'Sistem'
              ? (MediaQuery.of(context).platformBrightness == Brightness.dark
                  ? const Color(0xFF000000)
                  : const Color(0xFFFFFFFF))
              : currentTheme.backgroundColor,
          shape: BoxShape.circle,
          border: Border.all(
            color: currentTheme.name == 'Sistem' && MediaQuery.of(context).platformBrightness == Brightness.light
                ? Colors.black54
                : Colors.white24, 
            width: 2,
          ),
        ),
      ),
      onTap: _openThemePicker,
    );
  }

  Widget _buildFontTile() {
    return ExpansionTile(
      tilePadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      leading: FaIcon(
        FontAwesomeIcons.font,
        color: themeService.isDarkMode ? Colors.white : Colors.black87,
        size: 20,
      ),
      title: Text(
        'Yazı Tipi & Boyutu',
        style: TextStyle(color: themeService.isDarkMode ? Colors.white : Colors.black87),
      ),
      subtitle: Text(
        '${_fontSizeIndex + 1}/5 - ${_fontFamily ?? "Sistem"}',
        style: TextStyle(color: themeService.isDarkMode ? Colors.white54 : Colors.black54),
      ),
      iconColor: Colors.white70,
      collapsedIconColor: Colors.white54,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Boyut',
                style: TextStyle(color: themeService.isDarkMode ? Colors.white70 : Colors.black87, fontSize: 13),
              ),
              Slider(
                value: _fontSizeIndex.toDouble(),
                min: 0,
                max: 4,
                divisions: 4,
                activeColor: Colors.blueAccent,
                onChanged: (val) =>
                    setState(() => _fontSizeIndex = val.round()),
                onChangeEnd: (val) =>
                    _storageService.setFontSizeIndex(val.round()),
              ),
              const SizedBox(height: 12),
              Text(
                'Font Ailesi',
                style: TextStyle(color: themeService.isDarkMode ? Colors.white70 : Colors.black87, fontSize: 13),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: Colors.black12,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    dropdownColor: const Color(0xFF2A2A2A),
                    value:
                        _fontFamily != null &&
                            _fontOptions.contains(_fontFamily)
                        ? _fontFamily
                        : _fontOptions.first,
                    icon: Icon(
                      Icons.keyboard_arrow_down,
                      color: themeService.isDarkMode ? Colors.white54 : Colors.black87,
                    ),
                    isExpanded: true,
                    style: TextStyle(color: themeService.isDarkMode ? Colors.white : Colors.black),
                    onChanged: (String? newVal) async {
                      setState(() {
                        _fontFamily = newVal == _fontOptions.first
                            ? null
                            : newVal;
                      });
                      if (_fontFamily != null) {
                        await _storageService.setFontFamily(_fontFamily!);
                      }
                    },
                    items: _fontOptions.map<DropdownMenuItem<String>>((
                      String value,
                    ) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Text(value),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildNotificationTile() {
    return SwitchListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
      secondary: FaIcon(
        FontAwesomeIcons.bell,
        color: themeService.isDarkMode ? Colors.white : Colors.black87,
        size: 20,
      ),
      title: Text('Bildirimler', style: TextStyle(color: themeService.isDarkMode ? Colors.white : Colors.black87)),
      subtitle: Text(
        'Arka planda cevap',
        style: TextStyle(color: themeService.isDarkMode ? Colors.white54 : Colors.black54),
      ),
      value: _notificationsEnabled,
      activeColor: Colors.greenAccent,
      onChanged: (val) async {
        setState(() => _notificationsEnabled = val);
        await _storageService.setNotificationsEnabled(val);
      },
    );
  }


  Widget _buildImportTile() {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.blue.withOpacity(0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(
          FontAwesomeIcons.fileImport,
          color: themeService.isDarkMode ? Colors.white : Colors.black87,
          size: 16,
        ),
      ),
      title: Text(
        'Sohbet İçe Aktar',
        style: TextStyle(color: themeService.isDarkMode ? Colors.white : Colors.black87),
      ),
      subtitle: Text(
        '.fs yedeğinden sohbeti geri yükle',
        style: TextStyle(color: themeService.isDarkMode ? Colors.white54 : Colors.black54),
      ),
      trailing: Icon(Icons.chevron_right, color: themeService.isDarkMode ? Colors.white24 : Colors.black38),
      onTap: _handleChatImport,
    );
  }

  Future<void> _handleChatImport() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['fs'],
      );

      if (result != null && result.files.single.path != null) {
        setState(() => _isLoading = true);
        final file = File(result.files.single.path!);

        // Note: In real app, we might need ImportExportService here.
        // For now, we'll tell the user to go to chat screen or handle it here if we have instance.
        // Actually, SettingsScreen doesn't have ImportExportService easily accessible unless injected.
        // I'll show a message or try to use a local instance.
        final importService = ImportExportService();
        final chat = await importService.importChatFromFs(file);

        if (chat != null) {
          final chats = await _storageService.loadChats();
          chats.insert(0, chat);
          await _storageService.saveChats(chats);
          setState(() => _isLoading = false);
          GreyNotification.show(context, 'Sohbet başarıyla içe aktarıldı');
        } else {
          setState(() => _isLoading = false);
          GreyNotification.show(context, 'Dosya okunamadı veya geçersiz');
        }
      }
    } catch (e) {
      setState(() => _isLoading = false);
      GreyNotification.show(context, 'Hata: $e');
    }
  }

  Widget _buildResetButton() {
    return Center(
      child: TextButton.icon(
        onPressed: _showResetDialog,
        icon: Icon(
          Icons.delete_forever,
          color: themeService.isDarkMode ? Colors.redAccent : Colors.red,
          size: 20,
        ),
        label: Text(
          'Tüm Verileri Sıfırla',
          style: TextStyle(color: themeService.isDarkMode ? Colors.redAccent : Colors.red),
        ),
      ),
    );
  }

  // --- Logic Helpers ---

  Future<void> _saveMemory() async {
    try {
      await _storageService.saveUserMemory(_memoryController.text.trim());
      setState(() => _savedMemory = _memoryController.text.trim());
      if (mounted) _showSnack('Bellek kaydedildi!', true);
    } catch (_) {
      if (mounted) _showSnack('Hata oluştu', false);
    }
  }

  Future<void> _savePrompt() async {
    try {
      await _storageService.saveCustomPrompt(_promptController.text.trim());
      setState(() => _savedPrompt = _promptController.text.trim());
      if (mounted) _showSnack('Prompt kaydedildi!', true);
    } catch (_) {
      if (mounted) _showSnack('Hata oluştu', false);
    }
  }

  void _copyMemory() {
    Clipboard.setData(ClipboardData(text: _savedMemory));
    _showSnack('Kopyalandı', true);
  }

  void _copyPrompt() {
    Clipboard.setData(ClipboardData(text: _savedPrompt));
    _showSnack('Kopyalandı', true);
  }

  void _showSnack(String msg, bool success) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: success ? Colors.green : Colors.red,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Future<void> _openThemePicker() async {
    final themes = ThemeService.themes;
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) =>
          ThemePickerPanel(themes: themes, initialThemeIndex: _themeIndex),
    );
    if (result != null) {
      final idx = result['themeIndex'] as int?;
      final hex = result['primaryColor'] as String?;
      if (idx != null) {
        setState(() => _themeIndex = idx);
        await themeService.setThemeIndex(idx);
      }
      await themeService.setPrimaryColor(hex);
      if (idx != null) await themeService.setThemeIndex(idx, force: true);
    }
  }

  void _showResetDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: Text('DİKKAT!', style: TextStyle(color: themeService.isDarkMode ? Colors.redAccent : Colors.red)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Tüm sohbet geçmişi ve ayarlar silinecek. "SIFIRLA" yazarak onaylayın.',
              style: TextStyle(color: themeService.isDarkMode ? Colors.white70 : Colors.black87),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _resetConfirmController,
              style: TextStyle(color: themeService.isDarkMode ? Colors.white : Colors.black),
              decoration: InputDecoration(
                hintText: 'SIFIRLA',
                hintStyle: TextStyle(color: themeService.isDarkMode ? Colors.white24 : Colors.black38),
                filled: true,
                fillColor: themeService.isDarkMode ? Colors.black38 : Colors.white10,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('İptal', style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () async {
              if (_resetConfirmController.text == 'SIFIRLA') {
                Navigator.pop(ctx);
                await _performReset();
              }
            },
            child: const Text('SİL', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Future<void> _performReset() async {
    setState(() => _isLoading = true);
    await _storageService.resetAll();
    // Reset other prefs if needed
    setState(() {
      _memoryController.clear();
      _promptController.clear();
      _savedMemory = '';
      _savedPrompt = '';
      _isLoading = false;
    });
    if (mounted) _showSnack('Tüm veriler sıfırlandı.', true);
  }
}
