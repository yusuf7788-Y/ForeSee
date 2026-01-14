import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/browser_history_service.dart';
import '../services/private_mode_service.dart';
import '../services/theme_service.dart';
import 'package:foresee/screens/search_screen.dart';
import 'package:foresee/screens/theme_screen.dart';
import 'package:foresee/screens/bookmarks_screen.dart';
import 'package:foresee/screens/browser_history_screen.dart';
import 'package:foresee/screens/tabs_screen.dart';
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

class _ForeWebScreenState extends State<ForeWebScreen> {
  late final WebViewController _controller;
  bool _isLoading = true;
  bool _isPrivateMode = false;
  String _currentTitle = '';
  double _progress = 0.0;
  String _currentUrl = '';
  WebResourceError? _lastError;
  final ThemeService themeService = ThemeService();

  @override
  void initState() {
    super.initState();
    _loadPrivateMode();
    _currentTitle = widget.title ?? 'ForeWeb';
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

  Future<void> _loadPrivateMode() async {
    final isPrivate = await PrivateModeService.isPrivateModeEnabled();
    if (mounted) {
      setState(() => _isPrivateMode = isPrivate);
    }
  }

  Future<void> _togglePrivateMode() async {
    await PrivateModeService.togglePrivateMode();
    _loadPrivateMode();
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Paylaşım hatası: $e')),
        );
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Kopyalama hatası: $e')),
        );
      }
    }
  }

  Future<void> _openInNewTab() async {
    try {
      final url = await _controller.currentUrl();
      if (url != null && mounted) {
        await launchUrl(
          Uri.parse(url),
          mode: LaunchMode.externalApplication,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Yeni sekme açma hatası: $e')),
        );
      }
    }
  }

  Future<void> _showSearch() async {
    final result = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (context) => SearchScreen(),
      ),
    );
    
    if (result != null && result.isNotEmpty) {
      await _controller.loadRequest(Uri.parse(result));
    }
  }

  Future<void> _showTheme() async {
    final result = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (context) => ThemeScreen(),
      ),
    );
    
    if (result != null && result.isNotEmpty) {
      await _controller.loadRequest(Uri.parse(result));
    }
  }

  Future<void> _showBookmarks() async {
    final result = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (context) => BookmarksScreen(),
      ),
    );
    
    if (result != null && result.isNotEmpty) {
      await _controller.loadRequest(Uri.parse(result));
    }
  }

  Future<void> _showHistory() async {
    final result = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (context) => BrowserHistoryScreen(),
      ),
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

  void _showSiteInfo() {
    final uri = Uri.tryParse(_currentUrl);
    if (uri == null) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: themeService.isDarkMode ? const Color(0xFF1A1A1A) : Theme.of(context).colorScheme.surface,
        title: Row(
          children: [
            Image.asset(
              'foreweb.png',
              width: 24,
              height: 24,
              errorBuilder: (context, error, stackTrace) => 
                Icon(Icons.public, color: Colors.blue, size: 24),
            ),
            const SizedBox(width: 12),
            Text(
              'Site Bilgileri',
              style: TextStyle(
                color: themeService.isDarkMode ? Colors.white : Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoRow('Başlık:', _currentTitle),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _buildInfoRow('URL:', _currentUrl),
                ),
                IconButton(
                  icon: Icon(
                    Icons.copy,
                    color: themeService.isDarkMode ? Colors.white70 : Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                    size: 20,
                  ),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: _currentUrl));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('URL kopyalandı'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
            _buildInfoRow('Domain:', uri.host),
            const SizedBox(height: 8),
            _buildInfoRow('Protokol:', uri.scheme.toUpperCase()),
            const SizedBox(height: 8),
            _buildInfoRow('Güvenlik:', uri.scheme == 'https' ? 'Güvenli 🔒' : 'Güvenli Değil ⚠️'),
            const SizedBox(height: 16),
            Row(
              children: [
                Icon(
                  Icons.security,
                  color: themeService.isDarkMode ? Colors.white70 : Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                  size: 16,
                ),
                const SizedBox(width: 8),
                Text(
                  'Site İzinleri',
                  style: TextStyle(
                    color: themeService.isDarkMode ? Colors.white70 : Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                    fontSize: 12,
                  ),
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
                    style: TextStyle(
                      color: themeService.isDarkMode ? Colors.blue : Theme.of(context).colorScheme.primary,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Kapat', 
              style: TextStyle(
                color: themeService.isDarkMode ? Colors.white : Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: themeService.isDarkMode ? Colors.white70 : Theme.of(context).colorScheme.onSurface.withOpacity(0.7), 
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            color: themeService.isDarkMode ? Colors.white : Theme.of(context).colorScheme.onSurface,
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    // Show error screen if there's an error
    if (_lastError != null) {
      return WebViewErrorScreen(
        error: _lastError!,
        url: _currentUrl,
        onRetry: _refreshPage,
        onOpenInChrome: _openInNewTab,
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0A0A),
        elevation: 0,
        title: GestureDetector(
          onLongPress: _showSiteInfo,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_isPrivateMode) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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
                style: const TextStyle(color: Colors.white, fontSize: 14),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _refreshPage,
            tooltip: 'Yenile',
          ),
          IconButton(
            icon: const Icon(Icons.share, color: Colors.white),
            onPressed: _shareCurrentPage,
            tooltip: 'Paylaş',
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            onSelected: (value) async {
              switch (value) {
                case 'back':
                  await _controller.goBack();
                  break;
                case 'forward':
                  await _controller.goForward();
                  break;
                case 'home':
                  await _controller.loadRequest(Uri.parse(widget.url));
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
                case 'bookmarks':
                  _showBookmarks();
                  break;
                case 'tabs':
                  _showTabs();
                  break;
                case 'search':
                  _showSearch();
                  break;
                case 'theme':
                  _showTheme();
                  break;
                case 'foreSettings':
                  _showForeSettings();
                  break;
                case 'private':
                  _togglePrivateMode();
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'back',
                child: Row(
                  children: [
                    Icon(Icons.arrow_back, color: Colors.white),
                    SizedBox(width: 8),
                    Text('Geri', style: TextStyle(color: Colors.white)),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'forward',
                child: Row(
                  children: [
                    Icon(Icons.arrow_forward, color: Colors.white),
                    SizedBox(width: 8),
                    Text('İleri', style: TextStyle(color: Colors.white)),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'home',
                child: Row(
                  children: [
                    Icon(Icons.home, color: Colors.white),
                    SizedBox(width: 8),
                    Text('Ana Sayfa', style: TextStyle(color: Colors.white)),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'copy',
                child: Row(
                  children: [
                    Icon(Icons.copy, color: Colors.white),
                    SizedBox(width: 8),
                    Text('Link Kopyala', style: TextStyle(color: Colors.white)),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'newtab',
                child: Row(
                  children: [
                    Icon(Icons.open_in_new, color: Colors.white),
                    SizedBox(width: 8),
                    Text('Chrome\'da Aç', style: TextStyle(color: Colors.white)),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'history',
                child: Row(
                  children: [
                    Icon(Icons.history, color: Colors.white),
                    SizedBox(width: 8),
                    Text('Geçmiş', style: TextStyle(color: Colors.white)),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'bookmarks',
                child: Row(
                  children: [
                    Icon(Icons.bookmark, color: Colors.white),
                    SizedBox(width: 8),
                    Text('Yer İmleri', style: TextStyle(color: Colors.white)),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'tabs',
                child: Row(
                  children: [
                    Icon(Icons.tab, color: Colors.white),
                    SizedBox(width: 8),
                    Text('Sekmeler', style: TextStyle(color: Colors.white)),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'search',
                child: Row(
                  children: [
                    Icon(Icons.search, color: Colors.white),
                    SizedBox(width: 8),
                    Text('Arama', style: TextStyle(color: Colors.white)),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'theme',
                child: Row(
                  children: [
                    Icon(Icons.palette, color: Colors.white),
                    SizedBox(width: 8),
                    Text('Temalar', style: TextStyle(color: Colors.white)),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'info',
                child: Row(
                  children: [
                    Icon(Icons.info, color: Colors.white),
                    SizedBox(width: 8),
                    Text('Site Bilgisi', style: TextStyle(color: Colors.white)),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'foreSettings',
                child: Row(
                  children: [
                    Icon(Icons.settings, color: Colors.white),
                    SizedBox(width: 8),
                    Text('ForeWeb Ayarları', style: TextStyle(color: Colors.white)),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'private',
                child: Row(
                  children: [
                    Icon(
                      _isPrivateMode ? Icons.privacy_tip : Icons.public,
                      color: _isPrivateMode ? Colors.orange : Colors.white,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _isPrivateMode ? 'Gizli Mod Kapat' : 'Gizli Mod Aç',
                      style: TextStyle(
                        color: _isPrivateMode ? Colors.orange : Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
        bottom: _isLoading
            ? PreferredSize(
                preferredSize: const Size.fromHeight(2),
                child: LinearProgressIndicator(
                  value: _progress,
                  backgroundColor: Colors.white24,
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.blue),
                ),
              )
            : null,
      ),
      body: WebViewWidget(controller: _controller),
    );
  }

  Future<void> _showTabs() async {
    final result = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (context) => const TabsScreen(),
      ),
    );
    
    if (result != null && result.isNotEmpty) {
      await _controller.loadRequest(Uri.parse(result));
    }
  }

  Future<void> _showForeSettings() async {
    final result = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (context) => const ForeSettingsScreen(),
      ),
    );
    
    if (result != null && result.isNotEmpty) {
      await _controller.loadRequest(Uri.parse(result));
    }
  }
}
