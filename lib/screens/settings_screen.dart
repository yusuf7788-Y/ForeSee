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
import '../services/cloud_backup_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../services/refresh_service.dart';
import '../services/gmail_service.dart';
import '../services/github_service.dart';
import '../services/outlook_service.dart';
import '../main.dart';

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
  int _fontSizeIndex = 1;
  String? _fontFamily;
  String? _aiFontFamily;
  String? _userFontFamily;
  UserProfile? _userProfile;
  int _themeIndex = 0;
  bool _isSmartContextEnabled = false;
  bool _isUsageTrackerEnabled = false;
  double _usageTimeThreshold = 90;
  bool _lockMemoryAi = false;
  bool _lockPromptAi = false;
  bool _isAutoBackupEnabled = true;
  double _backupProgress = 0.0;
  String _backupStatus = '';
  String? _loadingMessage; // Custom loading text
  bool _isAutoTitleEnabled = false;
  bool _isGmailAiAlwaysAllowed = false;
  bool _isGithubAiAlwaysAllowed = false;
  bool _isOutlookAiAlwaysAllowed = false;
  String _selectedVoiceId = 'cgSgspJ2msm6clMCkdW9'; // Default Jessica
  bool _isRememberPastChatsEnabled = false;
  // bool _localNotificationsEnabled = true; // Still in StorageService but removed from UI
  // bool _fcmNotificationsEnabled = true;

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
    'Inter',
    'Roboto',
    'Open Sans',
    'Montserrat',
    'Poppins',
    'Barlow',
    'Nunito',
    'Rubik',
    'Manrope',
    'Source Sans 3',
    'IBM Plex Sans',
    'Garet',
    'Quicksand',
    'Mulish',
    'Ubuntu',
    'Fira Sans',
    'Canva sans',
    'Exo 2',
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
      final aiFontFamily = await _storageService.getAiFontFamily();
      final userFontFamily = await _storageService.getUserFontFamily();
      final profile = await _storageService.loadUserProfile();
      final themeIndex = await _storageService.getThemeIndex();
      final isSmartContextEnabled = await _storageService
          .getIsSmartContextEnabled();
      final isUsageTrackerEnabled = await _storageService
          .getIsUsageTrackerEnabled();
      final usageTimeThreshold = await _storageService.getUsageTimeThreshold();
      final lockMemoryAi = await _storageService.getLockMemoryAi();
      final lockPromptAi = await _storageService.getLockPromptAi();
      final isAutoBackupEnabled = await _storageService.isAutoBackupEnabled();
      final isAutoTitleEnabled = await _storageService.getIsAutoTitleEnabled();
      final isGmailAiAlwaysAllowed = await _storageService
          .getIsGmailAiAlwaysAllowed();
      final isGithubAiAlwaysAllowed = await _storageService
          .getIsGithubAiAlwaysAllowed();
      final isOutlookAiAlwaysAllowed = await _storageService
          .getIsOutlookAiAlwaysAllowed();
      final voiceId = await _storageService.getElevenLabsVoiceId();
      final isRememberPastChatsEnabled = await _storageService
          .getIsRememberPastChatsEnabled();

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
        _aiFontFamily = (aiFontFamily == null || aiFontFamily.isEmpty)
            ? null
            : aiFontFamily;
        _userFontFamily = (userFontFamily == null || userFontFamily.isEmpty)
            ? null
            : userFontFamily;
        _customFontController.text = _fontFamily ?? '';
        _userProfile = profile;
        _themeIndex = themeIndex;
        _isSmartContextEnabled = isSmartContextEnabled;
        _isUsageTrackerEnabled = isUsageTrackerEnabled;
        _usageTimeThreshold = usageTimeThreshold;
        _lockMemoryAi = lockMemoryAi;
        _lockPromptAi = lockPromptAi;
        _isAutoBackupEnabled = isAutoBackupEnabled;
        _isAutoTitleEnabled = isAutoTitleEnabled;
        _isGmailAiAlwaysAllowed = isGmailAiAlwaysAllowed;
        _isGithubAiAlwaysAllowed = isGithubAiAlwaysAllowed;
        _isOutlookAiAlwaysAllowed = isOutlookAiAlwaysAllowed;
        _selectedVoiceId = voiceId ?? 'cgSgspJ2msm6clMCkdW9';
        _isRememberPastChatsEnabled = isRememberPastChatsEnabled;
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
    final bgStart = isDark
        ? const Color(0xFF0F0F13)
        : theme.colorScheme.background;
    final textColor = isDark ? Colors.white : theme.colorScheme.onBackground;
    final iconColor = isDark ? Colors.white : Colors.black87;

    return PopScope(
      canPop: !_isLoading,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldPop = await _showBackPressConfirmation();
        if (shouldPop && mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Stack(
        children: [
          Scaffold(
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
                  color: isDark
                      ? Colors.white.withOpacity(0.1)
                      : theme.colorScheme.surface.withOpacity(0.8),
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
                gradient: isDark
                    ? const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF0F0F13), Color(0xFF1A1A24)],
                      )
                    : null,
                color: isDark ? null : bgStart,
              ),
              child: SingleChildScrollView(
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
                          _buildRememberPastChatsTile(),
                          _buildDivider(),
                          _buildAutoTitleTile(),
                          _buildDivider(),
                          _buildGmailConnectionTile(),
                          _buildDivider(),
                          _buildGithubConnectionTile(),
                          _buildDivider(),
                          _buildOutlookConnectionTile(),
                          _buildDivider(),
                          _buildVoiceTile(),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    _buildSectionHeader(
                      'VERİ VE YEDEKLEME',
                      FontAwesomeIcons.database,
                    ),
                    _buildGlassCard(
                      child: Column(
                        children: [
                          _buildBackupTile(),
                          _buildDivider(),
                          _buildImportTile(),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    _buildResetButton(),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ),
          if (_isLoading)
            Positioned.fill(
              child: Material(
                color: Colors.transparent,
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                  child: Container(
                    color: isDark
                        ? Colors.black.withOpacity(0.85)
                        : Colors.white.withOpacity(0.95),
                    child: SafeArea(
                      child: Column(
                        children: [
                          // Custom Header for Loading State
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: isDark
                                          ? Colors.white.withOpacity(0.1)
                                          : Colors.black.withOpacity(0.05),
                                      shape: BoxShape.circle,
                                    ),
                                    child: IconButton(
                                      icon: FaIcon(
                                        FontAwesomeIcons.arrowLeft,
                                        color: iconColor,
                                        size: 16,
                                      ),
                                      onPressed: () async {
                                        final result =
                                            await _showBackPressConfirmation();
                                        if (result && mounted) {
                                          setState(() => _isLoading = false);
                                          Navigator.pop(context);
                                        }
                                      },
                                    ),
                                  ),
                                ),
                                Text(
                                  _loadingMessage ??
                                      (_backupStatus.contains('Geri')
                                          ? 'Geri Yükleniyor'
                                          : 'Yedekleniyor'),
                                  style: TextStyle(
                                    color: textColor,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Spacer(flex: 2),
                          Text(
                            _backupStatus,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: isDark ? Colors.white70 : Colors.black87,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 24),
                          Container(
                            width: 240,
                            height: 12,
                            decoration: BoxDecoration(
                              color: isDark
                                  ? Colors.white10
                                  : Colors.black.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: FractionallySizedBox(
                              alignment: Alignment.centerLeft,
                              widthFactor: _backupProgress.clamp(0.0, 1.0),
                              child: Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: isDark
                                        ? [Colors.white70, Colors.white]
                                        : [
                                            Colors.blue.shade300,
                                            Colors.blue.shade600,
                                          ],
                                  ),
                                  borderRadius: BorderRadius.circular(6),
                                  boxShadow: [
                                    BoxShadow(
                                      color: isDark
                                          ? Colors.white24
                                          : Colors.blue.withOpacity(0.3),
                                      blurRadius: 10,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            '${(_backupProgress * 100).toInt()}%',
                            style: TextStyle(
                              color: isDark ? Colors.white38 : Colors.black38,
                              fontSize: 12,
                            ),
                          ),
                          const Spacer(flex: 3),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // --- UI Components ---

  Widget _buildSectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      child: Row(
        children: [
          Icon(
            icon,
            color: themeService.isDarkMode
                ? Colors.blueAccent.shade100
                : Colors.blue.shade600,
            size: 16,
          ),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              color: themeService.isDarkMode
                  ? Colors.blueAccent.shade100
                  : Colors.blue.shade600,
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
            color:
                color ??
                (themeService.isDarkMode
                    ? Colors.white.withOpacity(0.04)
                    : Colors.black.withOpacity(0.02)),
            border: Border.all(
              color: themeService.isDarkMode
                  ? Colors.white.withOpacity(0.08)
                  : Colors.black.withOpacity(0.06),
            ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: themeService.isDarkMode
                    ? Colors.black.withOpacity(0.1)
                    : Colors.black.withOpacity(0.05),
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
      color: themeService.isDarkMode
          ? Colors.white.withOpacity(0.05)
          : Colors.black.withOpacity(0.08),
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
            color: themeService.isDarkMode
                ? Colors.white.withOpacity(0.04)
                : Colors.black.withOpacity(0.02),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: themeService.isDarkMode
                  ? Colors.white.withOpacity(0.08)
                  : Colors.black.withOpacity(0.06),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Favori Dil',
                    style: TextStyle(
                      color: themeService.isDarkMode
                          ? Colors.white54
                          : Colors.black54,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    topLang.toUpperCase(),
                    style: TextStyle(
                      color: themeService.isDarkMode
                          ? Colors.white
                          : Colors.black,
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
        color: themeService.isDarkMode
            ? Colors.white.withOpacity(0.04)
            : Colors.black.withOpacity(0.02),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: themeService.isDarkMode
              ? Colors.white.withOpacity(0.08)
              : Colors.black.withOpacity(0.06),
        ),
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
              color: themeService.isDarkMode
                  ? Colors.white.withOpacity(0.5)
                  : Colors.black.withOpacity(0.5),
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
        style: TextStyle(
          color: themeService.isDarkMode ? Colors.white : Colors.black87,
        ),
      ),
      subtitle: Text(
        _savedMemory.isEmpty
            ? 'Henüz bilgi yok'
            : _savedMemory.replaceAll('\n', ' '),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: themeService.isDarkMode
              ? Colors.white.withOpacity(0.5)
              : Colors.black.withOpacity(0.5),
        ),
      ),
      iconColor: themeService.isDarkMode ? Colors.white70 : Colors.black87,
      collapsedIconColor: themeService.isDarkMode
          ? Colors.white54
          : Colors.black54,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'AI\'nın seni tanıması için kendini anlat. İsim, meslek, hobiler...',
                style: TextStyle(
                  color: themeService.isDarkMode
                      ? Colors.white54
                      : Colors.black54,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _memoryController,
                maxLines: 4,
                style: TextStyle(
                  color: themeService.isDarkMode ? Colors.white : Colors.black,
                ),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: themeService.isDarkMode
                      ? Colors.black12
                      : Colors.black.withOpacity(0.05),
                  hintText: 'Kendinizden bahsedin...',
                  hintStyle: TextStyle(
                    color: themeService.isDarkMode
                        ? Colors.white30
                        : Colors.black38,
                  ),
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
                      color: themeService.isDarkMode
                          ? Colors.white
                          : Colors.black54,
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
                          backgroundColor: themeService.isDarkMode
                              ? const Color(0xFF1A1A1A)
                              : Colors.white,
                          title: Text(
                            'Temizle',
                            style: TextStyle(
                              color: themeService.isDarkMode
                                  ? Colors.white
                                  : Colors.black87,
                            ),
                          ),
                          content: Text(
                            'Bellek tamamen silinecek. Emin misiniz?',
                            style: TextStyle(
                              color: themeService.isDarkMode
                                  ? Colors.white70
                                  : Colors.black54,
                            ),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: Text(
                                'İptal',
                                style: TextStyle(
                                  color: themeService.isDarkMode
                                      ? Colors.white54
                                      : Colors.black54,
                                ),
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
                  style: TextStyle(
                    color: themeService.isDarkMode
                        ? Colors.white
                        : Colors.black,
                    fontSize: 13,
                  ),
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
      title: Text(
        'Sistem Prompt',
        style: TextStyle(
          color: themeService.isDarkMode ? Colors.white : Colors.black87,
        ),
      ),
      subtitle: Text(
        'AI davranışını özelleştir',
        style: TextStyle(
          color: themeService.isDarkMode ? Colors.white54 : Colors.black54,
        ),
      ),
      iconColor: themeService.isDarkMode ? Colors.white70 : Colors.black87,
      collapsedIconColor: themeService.isDarkMode
          ? Colors.white54
          : Colors.black54,
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
                        backgroundColor: themeService.isDarkMode
                            ? Colors.white10
                            : Colors.black.withOpacity(0.05),
                        labelStyle: TextStyle(
                          color: themeService.isDarkMode
                              ? Colors.white70
                              : Colors.black87,
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
                style: TextStyle(
                  color: themeService.isDarkMode ? Colors.white : Colors.black,
                ),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: themeService.isDarkMode
                      ? Colors.black12
                      : Colors.black.withOpacity(0.05),
                  hintText: 'Prompt yaz...',
                  hintStyle: TextStyle(
                    color: themeService.isDarkMode
                        ? Colors.white30
                        : Colors.black38,
                  ),
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
                      color: themeService.isDarkMode
                          ? Colors.white
                          : Colors.black54,
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
                          backgroundColor: themeService.isDarkMode
                              ? const Color(0xFF1A1A1A)
                              : Colors.white,
                          title: Text(
                            'Temizle',
                            style: TextStyle(
                              color: themeService.isDarkMode
                                  ? Colors.white
                                  : Colors.black87,
                            ),
                          ),
                          content: Text(
                            'Sistem promptu tamamen silinecek. Emin misiniz?',
                            style: TextStyle(
                              color: themeService.isDarkMode
                                  ? Colors.white70
                                  : Colors.black54,
                            ),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: Text(
                                'İptal',
                                style: TextStyle(
                                  color: themeService.isDarkMode
                                      ? Colors.white54
                                      : Colors.black54,
                                ),
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
                      color: themeService.isDarkMode
                          ? Colors.white
                          : Colors.black54,
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
                  style: TextStyle(
                    color: themeService.isDarkMode
                        ? Colors.white54
                        : Colors.black54,
                    fontSize: 13,
                  ),
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
    final words = currentPrompt
        .split(' ')
        .where((word) => word.trim().isNotEmpty)
        .toList();
    print('DEBUG: Words count: ${words.length}');

    if (words.isEmpty) {
      GreyNotification.show(
        context,
        'Prompt en az 1 anlaşılır kelime içermeli',
      );
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
      title: Text(
        'Renk Teması',
        style: TextStyle(
          color: themeService.isDarkMode ? Colors.white : Colors.black87,
        ),
      ),
      subtitle: Text(
        currentTheme.name == 'Sistem'
            ? 'Sistem (${MediaQuery.of(context).platformBrightness == Brightness.dark ? 'Koyu' : 'Açık'})'
            : currentTheme.name,
        style: TextStyle(
          color: themeService.isDarkMode ? Colors.white54 : Colors.black54,
        ),
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
            color: themeService.isDarkMode
                ? Colors.white24
                : (currentTheme.name == 'Sistem' &&
                          MediaQuery.of(context).platformBrightness ==
                              Brightness.light
                      ? Colors.black38
                      : Colors.black26),
            width: 2,
          ),
        ),
      ),
      onTap: _openThemePicker,
    );
  }

  Widget _buildFontTile() {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      leading: Container(
        padding: const EdgeInsets.all(8),
        child: FaIcon(
          FontAwesomeIcons.font,
          color: themeService.isDarkMode
              ? const Color.fromARGB(255, 243, 242, 243)
              : const Color.fromARGB(255, 7, 7, 7),
          size: 18,
        ),
      ),
      title: Text(
        'Yazı Tipi & Boyutu',
        style: TextStyle(
          color: themeService.isDarkMode ? Colors.white : Colors.black87,
          fontWeight: FontWeight.w400,
        ),
      ),
      subtitle: Text(
        '${_fontSizeIndex + 1}. Seviye - ${_fontFamily ?? "Sistem"}',
        style: TextStyle(
          color: themeService.isDarkMode ? Colors.white54 : Colors.black54,
          fontSize: 13,
        ),
      ),
      trailing: Icon(
        Icons.chevron_right,
        color: themeService.isDarkMode ? Colors.white24 : Colors.black38,
      ),
      onTap: _showFontCustomizationSheet,
    );
  }

  void _showFontCustomizationSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: themeService.isDarkMode
          ? const Color(0xFF1A1A1A)
          : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Handle
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: themeService.isDarkMode
                              ? Colors.white24
                              : Colors.black12,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Header
                    Text(
                      'Görünüm Ayarları',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: themeService.isDarkMode
                            ? Colors.white
                            : Colors.black87,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),

                    // Font Size Slider Section
                    Text(
                      'Yazı Boyutu',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: themeService.isDarkMode
                            ? Colors.white70
                            : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: themeService.isDarkMode
                            ? Colors.white.withOpacity(0.05)
                            : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.text_fields,
                            size: 16,
                            color: themeService.isDarkMode
                                ? Colors.white54
                                : Colors.grey,
                          ),
                          Expanded(
                            child: SliderTheme(
                              data: SliderTheme.of(context).copyWith(
                                activeTrackColor: Colors.blueAccent,
                                inactiveTrackColor: themeService.isDarkMode
                                    ? Colors.white24
                                    : Colors.black12,
                                thumbColor: Colors.white,
                                trackHeight: 4,
                              ),
                              child: Slider(
                                value: _fontSizeIndex.toDouble(),
                                min: 0,
                                max: 4,
                                divisions: 4,
                                onChanged: (val) {
                                  // Update main state
                                  setState(() => _fontSizeIndex = val.round());
                                  // Update sheet state
                                  setSheetState(() {});
                                },
                                onChangeEnd: (val) => _storageService
                                    .setFontSizeIndex(val.round()),
                              ),
                            ),
                          ),
                          Icon(
                            Icons.text_fields,
                            size: 24,
                            color: themeService.isDarkMode
                                ? Colors.white
                                : Colors.black87,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Font Family Section
                    Text(
                      'Yazı Tipi',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: themeService.isDarkMode
                            ? Colors.white70
                            : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Global Font List
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: MediaQuery.of(context).size.height * 0.3,
                      ),
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: _fontOptions.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final fontName = _fontOptions[index];
                          final isSystem = fontName.startsWith('Sistem');
                          final storageName = isSystem ? null : fontName;
                          final isSelected = _fontFamily == storageName;

                          return _buildFontOptionItem(
                            fontName: fontName,
                            isSelected: isSelected,
                            onTap: () async {
                              setState(() => _fontFamily = storageName);
                              setSheetState(() {});
                              await themeService.setFontFamily(storageName);
                            },
                          );
                        },
                      ),
                    ),

                    const SizedBox(height: 24),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSubHeader(String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: themeService.isDarkMode ? Colors.white70 : Colors.black87,
      ),
    );
  }

  Widget _buildBubbleFontSelector(
    BuildContext context,
    StateSetter setSheetState,
    String? currentValue,
    Function(String?) onSelected,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: themeService.isDarkMode
            ? Colors.white.withOpacity(0.05)
            : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(16),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: currentValue ?? 'inherit',
          isExpanded: true,
          dropdownColor: themeService.isDarkMode
              ? const Color(0xFF1A1A1A)
              : Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          borderRadius: BorderRadius.circular(16),
          items: [
            DropdownMenuItem(
              value: 'inherit',
              child: Text(
                'Uygulama temasıyla aynı',
                style: TextStyle(
                  color: themeService.isDarkMode
                      ? Colors.white70
                      : Colors.black87,
                ),
              ),
            ),
            ..._fontOptions.where((f) => !f.startsWith('Sistem')).map((f) {
              return DropdownMenuItem(
                value: f,
                child: Text(
                  f,
                  style: TextStyle(
                    fontFamily: f,
                    color: themeService.isDarkMode
                        ? Colors.white
                        : Colors.black87,
                  ),
                ),
              );
            }).toList(),
          ],
          onChanged: (val) {
            final newValue = val == 'inherit' ? null : val;
            onSelected(newValue);
            setSheetState(() {});
          },
        ),
      ),
    );
  }

  Widget _buildFontOptionItem({
    required String fontName,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final isSystem = fontName.startsWith('Sistem');
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.blueAccent.withOpacity(0.15)
              : (themeService.isDarkMode
                    ? Colors.white.withOpacity(0.05)
                    : Colors.grey.shade100),
          borderRadius: BorderRadius.circular(12),
          border: isSelected
              ? Border.all(color: Colors.blueAccent, width: 1.5)
              : Border.all(color: Colors.transparent),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                fontName,
                style: TextStyle(
                  fontFamily: isSystem ? null : fontName,
                  color: themeService.isDarkMode
                      ? Colors.white
                      : Colors.black87,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            if (isSelected)
              const Icon(
                Icons.check_circle,
                color: Colors.blueAccent,
                size: 20,
              ),
          ],
        ),
      ),
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
      title: Text(
        'Bildirimler',
        style: TextStyle(
          color: themeService.isDarkMode ? Colors.white : Colors.black87,
        ),
      ),
      subtitle: Text(
        'Arka planda cevap ve önemli duyurular',
        style: TextStyle(
          color: themeService.isDarkMode ? Colors.white54 : Colors.black54,
        ),
      ),
      value: _notificationsEnabled,
      activeColor: Colors.greenAccent,
      onChanged: (val) async {
        setState(() => _notificationsEnabled = val);
        await _storageService.setNotificationsEnabled(val);
      },
    );
  }

  Widget _buildNotificationSubTile({
    required String title,
    required String subtitle,
    required bool value,
    required Function(bool) onChanged,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
      title: Text(
        title,
        style: TextStyle(
          color: themeService.isDarkMode ? Colors.white : Colors.black87,
          fontSize: 14,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          color: themeService.isDarkMode ? Colors.white54 : Colors.black54,
          fontSize: 12,
        ),
      ),
      trailing: Transform.scale(
        scale: 0.8,
        child: Switch(
          value: value,
          activeColor: Colors.greenAccent,
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildRememberPastChatsTile() {
    return SwitchListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
      secondary: FaIcon(
        FontAwesomeIcons.clockRotateLeft,
        color: themeService.isDarkMode ? Colors.white : Colors.black87,
        size: 20,
      ),
      title: Text(
        'Geçmiş Sohbetleri Hatırla',
        style: TextStyle(
          color: themeService.isDarkMode ? Colors.white : Colors.black87,
        ),
      ),
      subtitle: Text(
        'Bağlam için son 1-3 mesajı hatırla',
        style: TextStyle(
          color: themeService.isDarkMode ? Colors.white54 : Colors.black54,
        ),
      ),
      value: _isRememberPastChatsEnabled,
      activeColor: Colors.greenAccent,
      onChanged: (val) async {
        setState(() => _isRememberPastChatsEnabled = val);
        await _storageService.setIsRememberPastChatsEnabled(val);
      },
    );
  }

  Widget _buildAutoTitleTile() {
    return SwitchListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
      secondary: FaIcon(
        FontAwesomeIcons.heading,
        color: themeService.isDarkMode ? Colors.white : Colors.black87,
        size: 20,
      ),
      title: Text(
        'Her Mesajda Başlık Değiştir',
        style: TextStyle(
          color: themeService.isDarkMode ? Colors.white : Colors.black87,
        ),
      ),
      subtitle: Text(
        'AI her cevaptan sonra başlığı günceller',
        style: TextStyle(
          color: themeService.isDarkMode ? Colors.white54 : Colors.black54,
        ),
      ),
      value: _isAutoTitleEnabled,
      activeColor: Colors.greenAccent,
      onChanged: (val) async {
        setState(() => _isAutoTitleEnabled = val);
        await _storageService.setIsAutoTitleEnabled(val);
      },
    );
  }

  Widget _buildBackupTile() {
    return ExpansionTile(
      tilePadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.orange.withOpacity(0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(
          FontAwesomeIcons.cloudArrowUp,
          color: themeService.isDarkMode ? Colors.orangeAccent : Colors.orange,
          size: 16,
        ),
      ),
      title: Text(
        'Yedekle & Geri Yükle',
        style: TextStyle(
          color: themeService.isDarkMode ? Colors.white : Colors.black87,
        ),
      ),
      subtitle: Text(
        'Verilerini buluta kaydet',
        style: TextStyle(
          color: themeService.isDarkMode ? Colors.white54 : Colors.black54,
        ),
      ),
      iconColor: themeService.isDarkMode ? Colors.white70 : Colors.black87,
      collapsedIconColor: themeService.isDarkMode
          ? Colors.white54
          : Colors.black54,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Column(
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  'Otomatik Yedekleme',
                  style: TextStyle(
                    color: themeService.isDarkMode
                        ? Colors.white
                        : Colors.black87,
                    fontSize: 14,
                  ),
                ),
                subtitle: Text(
                  'Değişiklikleri anında buluta kaydet',
                  style: TextStyle(
                    color: themeService.isDarkMode
                        ? Colors.white54
                        : Colors.black54,
                    fontSize: 12,
                  ),
                ),
                value: _isAutoBackupEnabled,
                onChanged: (val) async {
                  setState(() => _isAutoBackupEnabled = val);
                  await _storageService.setAutoBackupEnabled(val);
                },
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _handleCloudRestore,
                      icon: const Icon(Icons.cloud_download, size: 18),
                      label: const Text('Geri Yükle'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: themeService.isDarkMode
                            ? Colors.white10
                            : Colors.black.withOpacity(0.05),
                        foregroundColor: themeService.isDarkMode
                            ? Colors.white
                            : Colors.black87,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _handleCloudBackup,
                      icon: const Icon(Icons.cloud_upload, size: 18),
                      label: const Text('Yedekle'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueAccent,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _handleCloudBackup() async {
    final backupService = CloudBackupService.instance;
    try {
      setState(() {
        _isLoading = true;
        _backupProgress = 0.05;
        _backupStatus = 'Yedekleniyor...';
      });
      await backupService.backupData(
        onProgress: (p, status) {
          if (mounted) {
            setState(() {
              _backupProgress = p;
              _backupStatus = status;
            });
          }
          debugPrint(status);
        },
      );
      if (mounted) {
        GreyNotification.show(context, 'Yedekleme başarıyla tamamlandı.');
      }
    } catch (e) {
      if (mounted) {
        GreyNotification.show(context, 'Yedekleme hatası: $e');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleCloudRestore() async {
    final backupService = CloudBackupService.instance;
    try {
      setState(() => _isLoading = true);
      final backups = await backupService.listBackups();
      setState(() => _isLoading = false);

      if (!mounted) return;

      if (backups.isEmpty) {
        GreyNotification.show(context, 'Hiç yedek bulunamadı.');
        return;
      }

      final Map<String, dynamic>? selectedBackup =
          await showDialog<Map<String, dynamic>>(
            context: context,
            builder: (ctx) => AlertDialog(
              backgroundColor: themeService.isDarkMode
                  ? const Color(0xFF1A1A1A)
                  : Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: Text(
                'Yedek Seçin',
                style: TextStyle(
                  color: themeService.isDarkMode ? Colors.white : Colors.black,
                  fontWeight: FontWeight.bold,
                ),
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: backups.length,
                  separatorBuilder: (c, i) => Divider(
                    color: themeService.isDarkMode
                        ? Colors.white10
                        : Colors.black12,
                  ),
                  itemBuilder: (c, i) {
                    final b = backups[i];
                    final id = b['id'] ?? 'latest';
                    final timestamp = b['timestamp'] as Timestamp?;
                    final date = timestamp != null
                        ? timestamp.toDate()
                        : DateTime.now();
                    final dateStr = DateFormat('dd.MM.yyyy HH:mm').format(date);
                    final device = b['deviceName'] ?? 'Bilinmeyen Cihaz';
                    final chats = b['chatCount'] ?? 0;
                    final bool isAuto = b['isAuto'] == true;

                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        isAuto ? Icons.auto_mode : Icons.history,
                        color: isAuto ? Colors.greenAccent : Colors.blueAccent,
                        size: 20,
                      ),
                      title: Row(
                        children: [
                          Text(
                            dateStr,
                            style: TextStyle(
                              color: themeService.isDarkMode
                                  ? Colors.white
                                  : Colors.black87,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: isAuto
                                  ? Colors.green.withOpacity(0.1)
                                  : Colors.blue.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              isAuto ? 'OTOMATİK' : 'MANUEL',
                              style: TextStyle(
                                color: isAuto ? Colors.green : Colors.blue,
                                fontSize: 8,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      subtitle: Text(
                        '$device - $chats Sohbet',
                        style: TextStyle(
                          color: themeService.isDarkMode
                              ? Colors.white54
                              : Colors.black54,
                          fontSize: 12,
                        ),
                      ),
                      onTap: () => Navigator.pop(ctx, b),
                    );
                  },
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('İptal'),
                ),
              ],
            ),
          );

      if (selectedBackup == null) return;

      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: themeService.isDarkMode
              ? const Color(0xFF1A1A1A)
              : Colors.white,
          title: Text(
            'Verileri Geri Yükle',
            style: TextStyle(
              color: themeService.isDarkMode ? Colors.white : Colors.black,
            ),
          ),
          content: Text(
            'Bu işlem mevcut sohbetlerinizi silecek ve yerine seçtiğiniz yedeği getirecektir. Emin misiniz?',
            style: TextStyle(
              color: themeService.isDarkMode ? Colors.white70 : Colors.black87,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('İptal'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Evet, Geri Yükle'),
            ),
          ],
        ),
      );

      if (confirm != true) return;

      setState(() {
        _isLoading = true;
        _backupProgress = 0.1;
        _backupStatus = 'Geri yükleniyor...';
      });
      await backupService.restoreData(
        onProgress: (p, status) {
          if (mounted) {
            setState(() {
              _backupProgress = p;
              _backupStatus = status;
            });
          }
          debugPrint(status);
        },
        backupId: selectedBackup['id'],
      );
      if (mounted) {
        // Show persistent dialog instead of simple notification
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            backgroundColor: themeService.isDarkMode
                ? const Color(0xFF1E1E1E)
                : Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.greenAccent),
                const SizedBox(width: 10),
                const Text(
                  'Yükleme Başarılı',
                  style: TextStyle(color: Colors.white),
                ),
              ],
            ),
            content: const Text(
              'Verilerin sağlıklı çalışabilmesi için lütfen uygulamanızı tamamen kapatıp tekrar açınız.\n\n(Arka plandan da kapatmayı unutmayınız)',
              style: TextStyle(color: Colors.white70),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  // Use a small delay to ensure dialog is closed before rebuilding the whole app
                  Future.delayed(const Duration(milliseconds: 100), () {
                    if (mounted) {
                      RestartWidget.restartApp(context);
                    }
                  });
                },
                child: const Text(
                  'Yeniden Başlat',
                  style: TextStyle(color: Colors.blueAccent),
                ),
              ),
              TextButton(
                onPressed: () => SystemNavigator.pop(),
                child: const Text(
                  'Uygulamayı Kapat',
                  style: TextStyle(color: Colors.redAccent),
                ),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        GreyNotification.show(context, 'Yükleme hatası: $e');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<bool> _showBackPressConfirmation() async {
    final isDark = themeService.isDarkMode;
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1A1A1A) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'İşlem Devam Ediyor',
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'Backup işlemi sırasında çıkmak verilerinize zarar verebilir. Yine de çıkmak istiyor musunuz?',
          style: TextStyle(color: isDark ? Colors.white70 : Colors.black87),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Devam Et'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Çıkış Yap', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    return result ?? false;
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
        style: TextStyle(
          color: themeService.isDarkMode ? Colors.white : Colors.black87,
        ),
      ),
      subtitle: Text(
        '.fs yedeğinden sohbeti geri yükle',
        style: TextStyle(
          color: themeService.isDarkMode ? Colors.white54 : Colors.black54,
        ),
      ),
      trailing: Icon(
        Icons.chevron_right,
        color: themeService.isDarkMode ? Colors.white24 : Colors.black38,
      ),
      onTap: _handleChatImport,
    );
  }

  Future<void> _handleChatImport() async {
    try {
      final result = await FilePicker.platform.pickFiles(type: FileType.any);

      if (result != null && result.files.single.path != null) {
        setState(() => _isLoading = true);
        final file = File(result.files.single.path!);
        final importService = ImportExportService();
        final chat = await importService.importChatFromFs(file);

        if (chat != null) {
          final chats = await _storageService.loadChats();
          chats.insert(0, chat);
          await _storageService.saveChats(chats);
          setState(() => _isLoading = false);

          if (mounted) {
            Navigator.of(context).pop();
            GreyNotification.show(
              context,
              'Sohbet içe aktarıldı! Sidebar menüyü kapatıp açın.',
            );
          }
        } else {
          setState(() => _isLoading = false);
          GreyNotification.show(
            context,
            'Dosya çözümlenemedi. Doğru .fs dosyasını seçtiğinizden emin olun.',
          );
        }
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (e.toString().contains('pad block')) {
        GreyNotification.show(
          context,
          'Şifre çözme hatası. Dosya farklı bir cihazdan mı export edildi?',
        );
      } else {
        GreyNotification.show(
          context,
          'Aktarma hatası: ${e.toString().substring(0, 50)}...',
        );
      }
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
          style: TextStyle(
            color: themeService.isDarkMode ? Colors.redAccent : Colors.red,
          ),
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
        title: Text(
          'DİKKAT!',
          style: TextStyle(
            color: themeService.isDarkMode ? Colors.redAccent : Colors.red,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Tüm sohbet geçmişi ve ayarlar silinecek. "SIFIRLA" yazarak onaylayın.',
              style: TextStyle(
                color: themeService.isDarkMode
                    ? Colors.white70
                    : Colors.black87,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _resetConfirmController,
              style: TextStyle(
                color: themeService.isDarkMode ? Colors.white : Colors.black,
              ),
              decoration: InputDecoration(
                hintText: 'SIFIRLA',
                hintStyle: TextStyle(
                  color: themeService.isDarkMode
                      ? Colors.white24
                      : Colors.black38,
                ),
                filled: true,
                fillColor: themeService.isDarkMode
                    ? Colors.black38
                    : Colors.white10,
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
    await _storageService.resetDataExceptProfile();
    // Reset other prefs if needed
    setState(() {
      _memoryController.clear();
      _promptController.clear();
      _savedMemory = '';
      _savedPrompt = '';
      _isLoading = false;
    });
    if (mounted) _showSnack('Veriler sıfırlandı (Profil korundu)', true);
  }

  Widget _buildGmailConnectionTile() {
    final connected = GmailService.instance.isConnected();
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
      leading: FaIcon(
        FontAwesomeIcons.google,
        color: themeService.isDarkMode ? Colors.white : Colors.black87,
        size: 20,
      ),
      title: const Text('Gmail Bağlantısı'),
      subtitle: Text(
        connected ? 'Bağlı' : 'Bağlı Değil',
        style: TextStyle(
          color: themeService.isDarkMode ? Colors.white54 : Colors.black54,
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (connected)
            Switch(
              value: _isGmailAiAlwaysAllowed,
              activeColor: Colors.purpleAccent,
              onChanged: (val) async {
                setState(() => _isGmailAiAlwaysAllowed = val);
                await _storageService.setIsGmailAiAlwaysAllowed(val);
              },
            ),
          Icon(
            Icons.chevron_right,
            color: themeService.isDarkMode ? Colors.white24 : Colors.black38,
          ),
        ],
      ),
      onTap: _showGmailMenu,
    );
  }

  Widget _buildGithubConnectionTile() {
    final connected = GitHubService.instance.isConnected();
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
      leading: FaIcon(
        FontAwesomeIcons.github,
        color: themeService.isDarkMode ? Colors.white : Colors.black87,
        size: 22,
      ),
      title: const Text('GitHub Bağlantısı'),
      subtitle: Text(
        connected ? 'Bağlı' : 'Bağlı Değil',
        style: TextStyle(
          color: themeService.isDarkMode ? Colors.white54 : Colors.black54,
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (connected)
            Switch(
              value: _isGithubAiAlwaysAllowed,
              activeColor: Colors.purpleAccent,
              onChanged: (val) async {
                setState(() => _isGithubAiAlwaysAllowed = val);
                await _storageService.setIsGithubAiAlwaysAllowed(val);
              },
            ),
          Icon(
            Icons.chevron_right,
            color: themeService.isDarkMode ? Colors.white24 : Colors.black38,
          ),
        ],
      ),
      onTap: _showGithubMenu,
    );
  }

  Widget _buildOutlookConnectionTile() {
    final connected = OutlookService.instance.isConnected();
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
      leading: FaIcon(
        FontAwesomeIcons.microsoft,
        color: themeService.isDarkMode ? Colors.white : Colors.black87,
        size: 22,
      ),
      title: const Text('Outlook Bağlantısı'),
      subtitle: Text(
        connected ? 'Bağlı' : 'Bağlı Değil',
        style: TextStyle(
          color: themeService.isDarkMode ? Colors.white54 : Colors.black54,
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (connected)
            Switch(
              value: _isOutlookAiAlwaysAllowed,
              activeColor: Colors.purpleAccent,
              onChanged: (val) async {
                setState(() => _isOutlookAiAlwaysAllowed = val);
                await _storageService.setIsOutlookAiAlwaysAllowed(val);
              },
            ),
          Icon(
            Icons.chevron_right,
            color: themeService.isDarkMode ? Colors.white24 : Colors.black38,
          ),
        ],
      ),
      onTap: _showOutlookMenu,
    );
  }

  void _showOutlookMenu() {
    final connected = OutlookService.instance.isConnected();
    showModalBottomSheet(
      context: context,
      backgroundColor: themeService.isDarkMode
          ? const Color(0xFF1A1A1A)
          : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Text(
              'Outlook Entegrasyonu',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: themeService.isDarkMode ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                connected
                    ? 'Hesabınız bağlı ve kullanıma hazır'
                    : 'Maillerinizi yönetmek için hesabınızı bağlayın',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: themeService.isDarkMode
                      ? Colors.white54
                      : Colors.black54,
                  fontSize: 14,
                ),
              ),
            ),
            const SizedBox(height: 24),
            if (!connected)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 8,
                ),
                child: ElevatedButton.icon(
                  onPressed: () async {
                    Navigator.pop(ctx);
                    setState(() {
                      _isLoading = true;
                      _loadingMessage = 'Bağlanıyor...';
                    });
                    try {
                      final success = await OutlookService.instance
                          .authenticate();
                      if (success) {
                        if (mounted) _showSnack('Outlook bağlandı!', true);
                      } else {
                        if (mounted) _showSnack('Bağlantı başarısız', false);
                      }
                    } catch (e) {
                      if (mounted) _showSnack('Hata: $e', false);
                    } finally {
                      if (mounted) {
                        setState(() {
                          _isLoading = false;
                          _loadingMessage = null;
                        });
                        // Refresh state to update UI
                        _loadSettings();
                      }
                    }
                  },
                  icon: const FaIcon(FontAwesomeIcons.microsoft),
                  label: const Text('Outlook\'a Bağlan'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue[800],
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
            if (connected)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 8,
                ),
                child: ElevatedButton.icon(
                  onPressed: () async {
                    Navigator.pop(ctx);
                    await OutlookService.instance.signOut();
                    if (mounted) {
                      _showSnack('Bağlantı kesildi', true);
                      _loadSettings();
                    }
                  },
                  icon: const Icon(Icons.link_off),
                  label: const Text('Bağlantıyı Kes'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: themeService.isDarkMode
                        ? Colors.white10
                        : Colors.black12,
                    foregroundColor: themeService.isDarkMode
                        ? Colors.white
                        : Colors.black87,
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                ),
              ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                'Outlook entegrasyonu ile gelen kutunuzu okuyabilir ve e-posta gönderebilirsiniz. "Her zaman izin ver" seçeneği aktifken, AI her seferinde onay istemeden işlem yapabilir.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: themeService.isDarkMode
                      ? Colors.white54
                      : Colors.black54,
                  fontSize: 12,
                ),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  void _showGmailMenu() {
    final connected = GmailService.instance.isConnected();
    showModalBottomSheet(
      context: context,
      backgroundColor: themeService.isDarkMode
          ? const Color(0xFF1A1A1A)
          : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Text(
              'Gmail Entegrasyonu',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: themeService.isDarkMode ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                connected
                    ? 'Hesabınız bağlı ve kullanıma hazır'
                    : 'Maillerinizi yönetmek için hesabınızı bağlayın',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: themeService.isDarkMode
                      ? Colors.white54
                      : Colors.black54,
                  fontSize: 14,
                ),
              ),
            ),
            const SizedBox(height: 24),
            if (!connected)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 8,
                ),
                child: ElevatedButton.icon(
                  onPressed: () async {
                    Navigator.pop(ctx);
                    setState(() {
                      _isLoading = true;
                      _loadingMessage = 'Bağlanıyor...';
                    });
                    final success = await GmailService.instance.signIn();
                    if (success) {
                      setState(() {
                        _isLoading = false;
                        _loadingMessage = null;
                      });
                      _showSnack('Gmail başarıyla bağlandı', true);
                    } else {
                      setState(() {
                        _isLoading = false;
                        _loadingMessage = null;
                      });
                      _showSnack('Bağlantı başarısız oldu', false);
                    }
                  },
                  icon: const FaIcon(FontAwesomeIcons.google),
                  label: const Text('Gmail\'e Bağlan'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red[700],
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              )
            else ...[
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 8,
                ),
                child: ElevatedButton.icon(
                  onPressed: () async {
                    Navigator.pop(ctx);
                    await GmailService.instance.signOut();
                    setState(() {});
                    _showSnack('Gmail bağlantısı kesildi', true);
                  },
                  icon: const Icon(Icons.link_off),
                  label: const Text('Bağlantıyı Kes'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: themeService.isDarkMode
                        ? Colors.white10
                        : Colors.black12,
                    foregroundColor: themeService.isDarkMode
                        ? Colors.white
                        : Colors.black87,
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Column(
                  children: [
                    const Divider(),
                    SwitchListTile(
                      title: const Text('AI\'ın Her Zaman İzni Var'),
                      subtitle: const Text(
                        'Açık olduğunda AI Gmail araçlarını doğrudan kullanabilir',
                      ),
                      value: _isGmailAiAlwaysAllowed,
                      activeColor: Colors.redAccent,
                      onChanged: (val) async {
                        setState(() => _isGmailAiAlwaysAllowed = val);
                        await _storageService.setIsGmailAiAlwaysAllowed(val);
                        Navigator.pop(ctx);
                      },
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                'Gmail entegrasyonu ile e-postalarınızı okuyabilir ve yanıtlayabilirsiniz.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: themeService.isDarkMode
                      ? Colors.white54
                      : Colors.black54,
                  fontSize: 12,
                ),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  void _showGithubMenu() {
    final connected = GitHubService.instance.isConnected();
    showModalBottomSheet(
      context: context,
      backgroundColor: themeService.isDarkMode
          ? const Color(0xFF1A1A1A)
          : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Text(
              'GitHub Entegrasyonu',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: themeService.isDarkMode ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                connected
                    ? 'Hesabınız bağlı ve kullanıma hazır'
                    : 'GitHub repolarınızı yönetmek için bağlayın',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: themeService.isDarkMode
                      ? Colors.white54
                      : Colors.black54,
                  fontSize: 14,
                ),
              ),
            ),
            const SizedBox(height: 24),
            if (!connected)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 8,
                ),
                child: ElevatedButton.icon(
                  onPressed: () async {
                    Navigator.pop(ctx);
                    setState(() {
                      _isLoading = true;
                      _loadingMessage = 'Bağlanıyor...';
                    });
                    final success = await GitHubService.instance.authenticate();
                    if (success) {
                      setState(() {
                        _isLoading = false;
                        _loadingMessage = null;
                      });
                      _showSnack('GitHub başarıyla bağlandı', true);
                    } else {
                      setState(() {
                        _isLoading = false;
                        _loadingMessage = null;
                      });
                      _showSnack('Bağlantı başarısız oldu', false);
                    }
                  },
                  icon: const FaIcon(FontAwesomeIcons.github),
                  label: const Text('GitHub\'a Bağlan'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: themeService.isDarkMode
                        ? Colors.white
                        : Colors.black,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              )
            else ...[
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 8,
                ),
                child: ElevatedButton.icon(
                  onPressed: () async {
                    Navigator.pop(ctx);
                    await GitHubService.instance.signOut();
                    setState(() {});
                    _showSnack('GitHub bağlantısı kesildi', true);
                  },
                  icon: const Icon(Icons.link_off),
                  label: const Text('Bağlantıyı Kes'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: themeService.isDarkMode
                        ? Colors.white10
                        : Colors.black12,
                    foregroundColor: themeService.isDarkMode
                        ? Colors.white
                        : Colors.black87,
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Column(
                  children: [
                    const Divider(),
                    SwitchListTile(
                      title: const Text('AI\'ın Her Zaman İzni Var'),
                      subtitle: const Text(
                        'Açık olduğunda AI GitHub araçlarını doğrudan kullanabilir',
                      ),
                      value: _isGithubAiAlwaysAllowed,
                      activeColor: Colors.purpleAccent,
                      onChanged: (val) async {
                        setState(() => _isGithubAiAlwaysAllowed = val);
                        await _storageService.setIsGithubAiAlwaysAllowed(val);
                        Navigator.pop(ctx);
                      },
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                'GitHub entegrasyonu ile repolarınızı listeleyebilir ve kod okuyabilirsiniz.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: themeService.isDarkMode
                      ? Colors.white54
                      : Colors.black54,
                  fontSize: 12,
                ),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildVoiceTile() {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      leading: FaIcon(
        FontAwesomeIcons.microphoneLines,
        color: themeService.isDarkMode ? Colors.white : Colors.black87,
        size: 20,
      ),
      title: Text(
        'AI Sesi',
        style: TextStyle(
          color: themeService.isDarkMode ? Colors.white : Colors.black87,
          fontSize: 15,
          fontWeight: FontWeight.w400,
        ),
      ),
      trailing: DropdownButton<String>(
        value: _selectedVoiceId,
        borderRadius: BorderRadius.circular(14),
        underline: const SizedBox(),
        dropdownColor: themeService.isDarkMode
            ? const Color(0xFF1A1A1A)
            : Colors.white,
        style: TextStyle(
          color: themeService.isDarkMode
              ? const Color.fromARGB(255, 236, 236, 236)
              : const Color.fromARGB(255, 19, 19, 19),
          fontSize: 14,
          fontWeight: FontWeight.w400,
        ),
        onChanged: (String? newValue) async {
          if (newValue != null) {
            setState(() {
              _selectedVoiceId = newValue;
            });
            await _storageService.setElevenLabsVoiceId(newValue);
            GreyNotification.show(context, 'Ses değiştirildi');
          }
        },
        items: const [
          DropdownMenuItem(
            value: 'cgSgspJ2msm6clMCkdW9',
            child: Text('Jessica (Kadın)'),
          ),
          DropdownMenuItem(
            value: 'nPczCjzI2devNBz1zQrb',
            child: Text('Brian (Erkek)'),
          ),
        ],
      ),
    );
  }
}
