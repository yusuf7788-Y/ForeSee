import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_highlight/flutter_highlight.dart';
import 'package:flutter_highlight/themes/monokai-sublime.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:path_provider/path_provider.dart';
import '../models/message.dart';
import 'grey_notification.dart';

class CodeBlock extends StatelessWidget {
  final String code;
  final String language;
  final int? cbIndex;
  final VoidCallback? onOpenInPanel;
  final void Function(String)? onGenerateReference;

  final String? filename;
  const CodeBlock({
    super.key,
    required this.code,
    required this.language,
    this.cbIndex,
    this.onOpenInPanel,
    this.onGenerateReference,
    this.filename,
  });

  String _getLanguageLabel() {
    final languageMap = {
      'dart': 'Dart',
      'python': 'Python',
      'javascript': 'JavaScript',
      'js': 'JavaScript',
      'typescript': 'TypeScript',
      'ts': 'TypeScript',
      'java': 'Java',
      'kotlin': 'Kotlin',
      'kt': 'Kotlin',
      'swift': 'Swift',
      'cpp': 'C++',
      'c': 'C',
      'csharp': 'C#',
      'cs': 'C#',
      'go': 'Go',
      'rust': 'Rust',
      'php': 'PHP',
      'ruby': 'Ruby',
      'html': 'HTML',
      'css': 'CSS',
      'sql': 'SQL',
      'json': 'JSON',
      'xml': 'XML',
      'yaml': 'YAML',
      'yml': 'YAML',
      'bash': 'Bash',
      'sh': 'Shell',
      'txt': 'Text',
      'text': 'Text',
      'kt': 'Kotlin',
    };
    return languageMap[language.toLowerCase()] ?? language.toUpperCase();
  }

  void _copyToClipboard(BuildContext context) {
    Clipboard.setData(ClipboardData(text: code));

    // Animasyonlu bildirim göster (MessageBubble'daki gibi)
    _showCopyNotification(context);
  }

  void _openLineRangeSheet(BuildContext context) {
    if (cbIndex == null || onGenerateReference == null) return;

    final lines = code.split('\n');
    final int totalLines = lines.isEmpty ? 1 : lines.length;
    int start = 1;
    int end = totalLines;

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          top: false,
          child: StatefulBuilder(
            builder: (ctx, setStateSheet) {
              return Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Kod bloğu cb$cbIndex',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.close,
                            color: Colors.white70,
                            size: 18,
                          ),
                          onPressed: () => Navigator.of(sheetContext).pop(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Satır aralığı seç (1 - $totalLines)',
                      style: const TextStyle(
                        color: Colors.white60,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Başlangıç: $start',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                    Slider(
                      value: start.toDouble(),
                      min: 1,
                      max: totalLines.toDouble(),
                      divisions: totalLines > 1 ? totalLines - 1 : 1,
                      label: '$start',
                      onChanged: (v) {
                        setStateSheet(() {
                          start = v.round();
                          if (start > end) {
                            end = start;
                          }
                        });
                      },
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Bitiş: $end',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                    Slider(
                      value: end.toDouble(),
                      min: 1,
                      max: totalLines.toDouble(),
                      divisions: totalLines > 1 ? totalLines - 1 : 1,
                      label: '$end',
                      onChanged: (v) {
                        setStateSheet(() {
                          end = v.round();
                          if (end < start) {
                            start = end;
                          }
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.of(sheetContext).pop(),
                          child: const Text(
                            'İptal',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: () {
                            final s = start.clamp(1, totalLines);
                            final e = end.clamp(1, totalLines);
                            final ref = (s == e)
                                ? '@cb${cbIndex}l$s'
                                : '@cb${cbIndex}l$s-l$e';
                            onGenerateReference?.call(ref);
                            Navigator.of(sheetContext).pop();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                          ),
                          child: const Text(
                            'ForeSee\'e gönder',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _downloadCode(BuildContext context) async {
    try {
      final directory = await getExternalStorageDirectory();
      if (directory == null) {
        GreyNotification.show(context, 'İndirme klasörüne ulaşılamadı');
        return;
      }

      final downloadPath = '${directory.path}/ForeSee_Downloads';
      final downloadDir = Directory(downloadPath);
      if (!await downloadDir.exists()) {
        await downloadDir.create(recursive: true);
      }

      final ext = language.toLowerCase() == 'text'
          ? 'txt'
          : language.toLowerCase();
      final name =
          filename ?? 'snippet_${DateTime.now().millisecondsSinceEpoch}.$ext';
      final file = File('$downloadPath/$name');
      await file.writeAsString(code);

      GreyNotification.show(context, 'Dosya kaydedildi: $name');
    } catch (e) {
      GreyNotification.show(context, 'Hata: $e');
    }
  }

  void _showCopyNotification(BuildContext context) {
    final overlay = Overlay.of(context);
    final overlayEntry = OverlayEntry(
      builder: (context) => _CodeCopyNotification(),
    );

    overlay.insert(overlayEntry);

    // 2 saniye sonra kaldır
    Future.delayed(const Duration(seconds: 2), () {
      overlayEntry.remove();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF1A1A1A) : const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDarkMode ? const Color(0xFF2A2A2A) : const Color(0xFFE0E0E0), 
          width: 1
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: Color(0xFF2A2A2A),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                Text(
                  _getLanguageLabel(),
                  style: TextStyle(
                    color: isDarkMode ? Colors.white70 : Colors.black54,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (filename != null)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Text(
                      filename!,
                      style: TextStyle(
                        color: isDarkMode ? Colors.white54 : Colors.black38,
                        fontSize: 11,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                const Spacer(),
                IconButton(
                  icon: const FaIcon(
                    FontAwesomeIcons.copy,
                    size: 16,
                    color: Colors.white70,
                  ),
                  onPressed: () => _copyToClipboard(context),
                  tooltip: 'Kopyala',
                ),
                PopupMenuButton<String>(
                  icon: const Icon(
                    Icons.more_vert,
                    color: Colors.white70,
                    size: 18,
                  ),
                  color: const Color(0xFF1A1A1A),
                  onSelected: (value) {
                    if (value == 'panel') {
                      onOpenInPanel?.call();
                    } else if (value == 'download') {
                      _downloadCode(context);
                    }
                  },
                  itemBuilder: (ctx) => [
                    if (onOpenInPanel != null)
                      const PopupMenuItem(
                        value: 'panel',
                        child: Text(
                          'Kod panelinde aç',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    const PopupMenuItem(
                      value: 'download',
                      child: Text(
                        'İndir',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Code content
          Container(
            constraints: const BoxConstraints(maxHeight: 400),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: HighlightView(
                code,
                language: language.toLowerCase(),
                theme: monokaiSublimeTheme,
                padding: EdgeInsets.zero,
                textStyle: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Kod kopyalama bildirimi
class _CodeCopyNotification extends StatefulWidget {
  @override
  State<_CodeCopyNotification> createState() => _CodeCopyNotificationState();
}

class _CodeCopyNotificationState extends State<_CodeCopyNotification>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    _controller.forward();

    // 1.6 saniye sonra kaybolma animasyonu
    Future.delayed(const Duration(milliseconds: 1600), () {
      if (mounted) {
        _controller.reverse();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 80,
      left: 0,
      right: 0,
      child: Center(
        child: SlideTransition(
          position: _slideAnimation,
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Material(
              color: Colors.transparent,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF4A4A4A),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check_circle, color: Colors.white, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Kod kopyalandı',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
