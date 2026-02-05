import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter_highlight/flutter_highlight.dart';
import 'package:flutter_highlight/themes/monokai-sublime.dart';
import 'package:flutter_highlight/themes/github.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'grey_notification.dart';
import 'dart:convert';

class ArtifactsPanel extends StatefulWidget {
  final String content;
  final String title;
  final String language;
  final int initialTab;
  final VoidCallback onClose;

  const ArtifactsPanel({
    super.key,
    required this.content,
    required this.title,
    this.language = 'text',
    required this.onClose,
    this.initialTab = 0,
  });

  @override
  State<ArtifactsPanel> createState() => _ArtifactsPanelState();
}

class _ArtifactsPanelState extends State<ArtifactsPanel>
    with SingleTickerProviderStateMixin {
  bool _isFullScreen = false;
  late TabController _tabController;
  late WebViewController _webViewController;
  bool _webViewInitialized = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTab,
    );
    _initWebView();
  }

  void _initWebView() {
    _webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white);
    _updateWebViewContent();
    _webViewInitialized = true;
  }

  @override
  void didUpdateWidget(ArtifactsPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.content != widget.content ||
        oldWidget.language != widget.language) {
      _updateWebViewContent();
    }
  }

  void _updateWebViewContent() {
    if (![
      'html',
      'css',
      'javascript',
      'js',
    ].contains(widget.language.toLowerCase())) {
      return;
    }

    String htmlContent;
    final lang = widget.language.toLowerCase();

    if (lang == 'html') {
      htmlContent = widget.content;
    } else if (lang == 'css') {
      htmlContent =
          '<html><head><style>${widget.content}</style></head><body><h1>CSS Preview</h1><p>Uygulanan stiller burada görünür.</p></body></html>';
    } else if (lang == 'javascript' || lang == 'js') {
      htmlContent =
          '<html><body><script>${widget.content}</script><div id="preview-root"></div><p>JS Preview (Console çıktılarını görmek için geliştirici modunu kullanın veya DOM manipülasyonu yapın)</p></body></html>';
    } else {
      htmlContent = widget.content;
    }

    _webViewController.loadHtmlString(htmlContent);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _copyToClipboard(BuildContext context) {
    Clipboard.setData(ClipboardData(text: widget.content));
    GreyNotification.show(context, 'Pano\'ya kopyalandı');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    Widget panel = Material(
      color: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF161616) : Colors.white,
          border: Border(
            left: BorderSide(
              color: isDark ? Colors.white10 : Colors.black.withOpacity(0.1),
              width: 1,
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 30,
              offset: const Offset(-5, 0),
            ),
          ],
        ),
        child: Column(
          children: [
            // Elegant Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                border: Border(
                  bottom: BorderSide(
                    color: isDark
                        ? Colors.white.withOpacity(0.05)
                        : Colors.black.withOpacity(0.05),
                  ),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.blueAccent.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.auto_awesome_motion_rounded,
                      size: 18,
                      color: Colors.blueAccent,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'ARTIFACT',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.5,
                            color: Colors.blueAccent.withOpacity(0.8),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.title.isEmpty
                              ? 'Untitled Document'
                              : widget.title,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  _HeaderAction(
                    icon: _isFullScreen
                        ? Icons.fullscreen_exit
                        : Icons.fullscreen,
                    onPressed: () =>
                        setState(() => _isFullScreen = !_isFullScreen),
                    tooltip: _isFullScreen ? 'Exit Fullscreen' : 'Fullscreen',
                    isDark: isDark,
                  ),
                  const SizedBox(width: 8),
                  _HeaderAction(
                    icon: Icons.close,
                    onPressed: widget.onClose,
                    tooltip: 'Close',
                    isDark: isDark,
                  ),
                ],
              ),
            ),

            // Tabs and secondary actions
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 0),
              color: isDark ? const Color(0xFF1A1A1A) : Colors.grey.shade50,
              child: Row(
                children: [
                  Expanded(
                    child: TabBar(
                      controller: _tabController,
                      isScrollable: true,
                      indicatorColor: Colors.blueAccent,
                      labelColor: Colors.blueAccent,
                      unselectedLabelColor: isDark
                          ? Colors.white54
                          : Colors.black54,
                      labelStyle: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                      tabs: const [
                        Tab(text: 'KOD'),
                        Tab(text: 'ÖNİZLEME'),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withOpacity(0.05)
                          : Colors.black.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      widget.language.toUpperCase(),
                      style: TextStyle(
                        color: isDark ? Colors.white54 : Colors.black54,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  GestureDetector(
                    onTap: () => _copyToClipboard(context),
                    child: Icon(
                      Icons.copy_rounded,
                      size: 16,
                      color: Colors.blueAccent.withOpacity(0.8),
                    ),
                  ),
                ],
              ),
            ),

            // Content View (Tabs)
            Expanded(
              child: TabBarView(
                physics: const NeverScrollableScrollPhysics(),
                controller: _tabController,
                children: [
                  // Code View
                  Container(
                    width: double.infinity,
                    color: isDark
                        ? const Color(0xFF101010)
                        : const Color(0xFFF9F9F9),
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.all(16),
                      child: HighlightView(
                        widget.content,
                        language: widget.language.toLowerCase(),
                        theme: isDark ? monokaiSublimeTheme : githubTheme,
                        padding: const EdgeInsets.all(0),
                        textStyle: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 14,
                          height: 1.6,
                          letterSpacing: 0,
                        ),
                      ),
                    ),
                  ),
                  // Preview View
                  Container(
                    color: Colors.white,
                    child:
                        ([
                          'html',
                          'css',
                          'javascript',
                          'js',
                        ].contains(widget.language.toLowerCase()))
                        ? WebViewWidget(controller: _webViewController)
                        : Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.visibility_off_rounded,
                                  size: 48,
                                  color: Colors.grey,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  '${widget.language} için önizleme desteklenmiyor',
                                  style: const TextStyle(color: Colors.grey),
                                ),
                              ],
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    if (_isFullScreen) {
      return Material(
        color: Colors.transparent,
        child: Container(
          width: double.infinity,
          height: double.infinity,
          color: Colors.black.withOpacity(0.8),
          padding: const EdgeInsets.all(32),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: panel,
          ),
        ),
      );
    }

    return panel;
  }
}

class _HeaderAction extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final String tooltip;
  final bool isDark;

  const _HeaderAction({
    required this.icon,
    required this.onPressed,
    required this.tooltip,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onPressed,
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withOpacity(0.05)
                : Colors.black.withOpacity(0.03),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            size: 18,
            color: isDark ? Colors.white60 : Colors.black54,
          ),
        ),
      ),
    );
  }
}
