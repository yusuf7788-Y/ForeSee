import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/browser_history_service.dart';
import '../services/private_mode_service.dart';
import '../services/theme_service.dart';
import 'package:foresee/screens/search_screen.dart';
import 'package:foresee/screens/theme_screen.dart';
import 'package:foresee/screens/bookmarks_screen.dart'; // Import kept but unused in menu
import 'package:foresee/screens/browser_history_screen.dart';
import 'package:foresee/screens/tabs_screen.dart'; // Import kept but unused in menu
import 'package:foresee/screens/site_permissions_screen.dart';
import 'package:foresee/screens/fore_settings_screen.dart';
import '../widgets/webview_error_screen.dart';

class ForeWebScreen extends StatefulWidget {
  final String url;
  final String? title;

  const ForeWebScreen({super.key, required this.url, this.title});

  @override
  State<ForeWebScreen> createState() => _ForeWebScreenState();
}

class _ForeWebScreenState extends State<ForeWebScreen>
    with WidgetsBindingObserver {
  late final WebViewController _controller;
  bool _isLoading = true;
  bool _isPrivateMode = false;
  String _currentTitle = '';
  double _progress = 0.0;
  String _currentUrl = '';
  WebResourceError? _lastError;
  final ThemeService themeService = ThemeService();

  // 'foresee' | 'light' | 'dark' | 'system'
  String _browserThemeMode = 'foresee';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadPrivateMode();
    _loadBrowserTheme();
    _currentTitle = widget.title ?? 'ForWeb';
    _currentUrl = widget.url;
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (int progress) {
            setState(() {
              _progress = progress / 100.0;
            });
          },
          onPageFinished: (String url) {
            _controller.getTitle().then((title) {
              if (title != null && mounted) {
                // Gizli mod değilse geçmişe ekle
                if (!_isPrivateMode) {
                  BrowserHistoryService.addToHistory(url, title);
                }

                setState(() {
                  _currentTitle = title;
                  _currentUrl = url;
                  _isLoading = false;
                  _lastError = null;
                });
              }
            });
          },
          onWebResourceError: (WebResourceError error) {
            if (mounted) {
              setState(() {
                _isLoading = false;
                _lastError = error;
              });
            }
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.url));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangePlatformBrightness() {
    if (_browserThemeMode == 'system') {
      setState(() {}); // Sistem teması değişirse güncelle
    }
  }

  Future<void> _loadBrowserTheme() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _browserThemeMode = prefs.getString('foreweb_theme_mode') ?? 'foresee';
      });
    }
  }

  // Aktif browser temasının karanlık mod olup olmadığını belirle
  bool get _isBrowserDarkMode {
    switch (_browserThemeMode) {
      case 'light':
        return false;
      case 'dark':
        return true;
      case 'system':
        return WidgetsBinding.instance.platformDispatcher.platformBrightness ==
            Brightness.dark;
      case 'foresee':
      default:
        // ForeSee: Uygulama temasını takip et
        return themeService.isDarkMode;
    }
  }

  Future<void> _loadPrivateMode() async {
    final isPrivate = await PrivateModeService.isPrivateModeEnabled();
    if (mounted) {
      setState(() => _isPrivateMode = isPrivate);
    }
  }

  Future<void> _shareCurrentPage() async {
    try {
      final url = await _controller.currentUrl();
      final title = await _controller.getTitle();
      if (url != null && mounted) {
        await Share.share('$title\n$url', subject: title);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Paylaşım hatası: $e')));
      }
    }
  }

  Future<void> _copyLink() async {
    try {
      final url = await _controller.currentUrl();
      if (url != null && mounted) {
        await Clipboard.setData(ClipboardData(text: url));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Link kopyalandı'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Kopyalama hatası: $e')));
      }
    }
  }

  Future<void> _openInNewTab() async {
    try {
      final url = await _controller.currentUrl();
      if (url != null && mounted) {
        await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Yeni sekme açma hatası: $e')));
      }
    }
  }

  Future<void> _showTheme() async {
    final result = await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (context) => const ThemeScreen()));

    // Tema ekranından dönüldüğünde her zaman temayı güncelle
    // 'THEME_CHANGED' dönebilir veya null (eğer back tuşuyla çıkılırsa)
    // Ama her durumda ayarları yeniden okuyalım
    await _loadBrowserTheme();
  }

  Future<void> _showHistory() async {
    final result = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (context) => BrowserHistoryScreen()),
    );

    if (result != null && result.isNotEmpty) {
      await _controller.loadRequest(Uri.parse(result));
    }
  }

  Future<void> _refreshPage() async {
    setState(() {
      _isLoading = true;
      _progress = 0.0;
    });
    await _controller.reload();
  }

  // Site bilgisi popup'ında da browser temasını kullanacağız
  void _showSiteInfo() {
    final uri = Uri.tryParse(_currentUrl);
    if (uri == null) return;

    final isDark = _isBrowserDarkMode;
    final bgColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subtitleColor = isDark ? Colors.white70 : Colors.black54;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: bgColor,
        title: Row(
          children: [
            Image.asset(
              'assets/logo3.png', // Logo path düzeltme (gerekirse dynamic yapılabilir)
              width: 24,
              height: 24,
              errorBuilder: (context, error, stackTrace) =>
                  Icon(Icons.public, color: Colors.blue, size: 24),
            ),
            const SizedBox(width: 12),
            Text('Site Bilgileri', style: TextStyle(color: textColor)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoRow('Başlık:', _currentTitle, textColor, subtitleColor),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _buildInfoRow(
                    'URL:',
                    _currentUrl,
                    textColor,
                    subtitleColor,
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.copy, color: subtitleColor, size: 20),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: _currentUrl));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('URL kopyalandı'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
            _buildInfoRow('Domain:', uri.host, textColor, subtitleColor),
            const SizedBox(height: 8),
            _buildInfoRow(
              'Protokol:',
              uri.scheme.toUpperCase(),
              textColor,
              subtitleColor,
            ),
            const SizedBox(height: 8),
            _buildInfoRow(
              'Güvenlik:',
              uri.scheme == 'https' ? 'Güvenli 🔒' : 'Güvenli Değil ⚠️',
              textColor,
              subtitleColor,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Icon(Icons.security, color: subtitleColor, size: 16),
                const SizedBox(width: 8),
                Text(
                  'Site İzinleri',
                  style: TextStyle(color: subtitleColor, fontSize: 12),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () async {
                    Navigator.pop(context);
                    final result = await Navigator.of(context).push<String>(
                      MaterialPageRoute(
                        builder: (context) => const SitePermissionsScreen(),
                      ),
                    );
                    if (result != null && result.isNotEmpty) {
                      await _controller.loadRequest(Uri.parse(result));
                    }
                  },
                  child: Text(
                    'Yönet',
                    style: TextStyle(color: Colors.blue, fontSize: 12),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Kapat', style: TextStyle(color: Colors.blue)),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(
    String label,
    String value,
    Color textColor,
    Color subtitleColor,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: subtitleColor, fontSize: 12)),
        const SizedBox(height: 2),
        Text(value, style: TextStyle(color: textColor, fontSize: 14)),
      ],
    );
  }

  Future<void> _showForeSettings() async {
    final result = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (context) => const ForeSettingsScreen()),
    );

    if (result != null && result.isNotEmpty) {
      await _controller.loadRequest(Uri.parse(result));
    }
  }

  @override
  Widget build(BuildContext context) {
    // Error screen removed per user request

    final isDark = _isBrowserDarkMode;
    final backgroundColor = isDark ? const Color(0xFF0A0A0A) : Colors.white;
    final iconColor = isDark ? Colors.white : Colors.black87;
    final textColor = isDark ? Colors.white : Colors.black87;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: backgroundColor,
        elevation: 0,
        // Geri butonu siyah temada beyaz, beyaz temada siyah olmalı
        leading: IconButton(
          icon: Icon(Icons.close, color: iconColor), // Çarpı veya geri ikonu
          onPressed: () => Navigator.pop(context),
        ),
        title: GestureDetector(
          onLongPress: _showSiteInfo,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_isPrivateMode) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.orange,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text(
                    'GİZLİ',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 8,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
              Text(
                _currentTitle,
                style: TextStyle(color: textColor, fontSize: 14),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        iconTheme: IconThemeData(color: iconColor),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: iconColor),
            onPressed: _refreshPage,
            tooltip: 'Yenile',
          ),
          IconButton(
            icon: Icon(Icons.share, color: iconColor),
            onPressed: _shareCurrentPage,
            tooltip: 'Paylaş',
          ),
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert, color: iconColor),
            color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
            onSelected: (value) async {
              switch (value) {
                case 'back':
                  await _controller.goBack();
                  break;
                case 'forward':
                  await _controller.goForward();
                  break;
                case 'copy':
                  await _copyLink();
                  break;
                case 'newtab':
                  await _openInNewTab();
                  break;
                case 'info':
                  _showSiteInfo();
                  break;
                case 'history':
                  _showHistory();
                  break;
                case 'theme':
                  _showTheme();
                  break;
                case 'foreSettings':
                  _showForeSettings();
                  break;
              }
            },
            itemBuilder: (context) {
              final popupTextColor = isDark ? Colors.white : Colors.black87;
              return [
                PopupMenuItem(
                  value: 'back',
                  child: Row(
                    children: [
                      Icon(Icons.arrow_back, color: popupTextColor),
                      const SizedBox(width: 8),
                      Text('Geri', style: TextStyle(color: popupTextColor)),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'forward',
                  child: Row(
                    children: [
                      Icon(Icons.arrow_forward, color: popupTextColor),
                      const SizedBox(width: 8),
                      Text('İleri', style: TextStyle(color: popupTextColor)),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'copy',
                  child: Row(
                    children: [
                      Icon(Icons.copy, color: popupTextColor),
                      const SizedBox(width: 8),
                      Text(
                        'Link Kopyala',
                        style: TextStyle(color: popupTextColor),
                      ),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'newtab',
                  child: Row(
                    children: [
                      Icon(Icons.open_in_new, color: popupTextColor),
                      const SizedBox(width: 8),
                      Text(
                        'Chrome\'da Aç',
                        style: TextStyle(color: popupTextColor),
                      ),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'history',
                  child: Row(
                    children: [
                      Icon(Icons.history, color: popupTextColor),
                      const SizedBox(width: 8),
                      Text('Geçmiş', style: TextStyle(color: popupTextColor)),
                    ],
                  ),
                ),

                // Kaldırılanlar: Yer İmleri, Sekmeler, Arama, Ana Sayfa, Gizli Mod
                PopupMenuItem(
                  value: 'theme',
                  child: Row(
                    children: [
                      Icon(Icons.palette, color: popupTextColor),
                      const SizedBox(width: 8),
                      Text('Temalar', style: TextStyle(color: popupTextColor)),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'info',
                  child: Row(
                    children: [
                      Icon(Icons.info, color: popupTextColor),
                      const SizedBox(width: 8),
                      Text(
                        'Site Bilgisi',
                        style: TextStyle(color: popupTextColor),
                      ),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'foreSettings',
                  child: Row(
                    children: [
                      Icon(Icons.settings, color: popupTextColor),
                      const SizedBox(width: 8),
                      Text(
                        'ForWeb Ayarları',
                        style: TextStyle(color: popupTextColor),
                      ),
                    ],
                  ),
                ),
              ];
            },
          ),
        ],
        bottom: _isLoading
            ? PreferredSize(
                preferredSize: const Size.fromHeight(2),
                child: LinearProgressIndicator(
                  value: _progress,
                  backgroundColor: isDark ? Colors.white24 : Colors.black12,
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.blue),
                ),
              )
            : null,
      ),
      body: WebViewWidget(controller: _controller),
    );
  }
}
