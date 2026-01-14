import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:android_intent_plus/android_intent.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/message.dart';
import '../screens/webview_screen.dart';
import '../screens/mini_games_hub_screen.dart';
import '../services/theme_service.dart';
import 'code_block.dart';
import 'fullscreen_image_viewer.dart';
import 'grey_notification.dart';
import 'phone_number_panel.dart';
import 'multi_answer_switcher.dart';

class MessageBubble extends StatefulWidget {
  final Message message;
  final Color userProfileColor;
  final bool isSelected;
  final VoidCallback? onLongPress;
  final bool showCopyButton;
  final VoidCallback? onCopy;
  final VoidCallback? onContinue;
  final int fontSizeIndex;
  final String? fontFamily;
  final bool isLastAiMessage;
  final void Function(Message message)? onRetry;
  final void Function(Uint8List bytes)? onWebCapture;
  final bool isTyping;
  final String? loadingMessage;
  final void Function(String actionId, Message message)? onQuickAction;
  final void Function(Message message)? onPin;
  final bool isPinned;
  final List<int>? codeBlockIndices;
  final void Function(String reference)? onCodeReferenceGenerated;
  final void Function(String settingKey)? onSettingsLinkTapped;
  final void Function(Message message, int index)? onAlternativeSelected;
  final String? reasoning;
  final VoidCallback? onShowReasoning;

  const MessageBubble({
    super.key,
    required this.message,
    required this.userProfileColor,
    this.isSelected = false,
    this.onLongPress,
    this.showCopyButton = false,
    this.onCopy,
    this.onContinue,
    this.fontSizeIndex = 2,
    this.fontFamily,
    this.isLastAiMessage = false,
    this.onRetry,
    this.onWebCapture,
    this.isTyping = false,
    this.loadingMessage,
    this.onQuickAction,
    this.onPin,
    this.isPinned = false,
    this.codeBlockIndices,
    this.onCodeReferenceGenerated,
    this.onSettingsLinkTapped,
    this.onAlternativeSelected,
    this.reasoning,
    this.onShowReasoning,
  });

  @override
  State<MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<MessageBubble> {
  final _themeService = ThemeService();
  bool _isLiked = false;
  bool _isDisliked = false;
  bool _sourcesExpanded = false;
  Uint8List? _inlineImageBytes;
  String? _inlineImageUrl;
  DateTime? _lastGameBoostTapTime;

  Color _getUserBubbleColor(BuildContext context) {
    // Açık modda #eae8e8, koyu modda #202020
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return isDarkMode ? const Color(0xFF202020) : const Color(0xFFeae8e8);
  }

  @override
  void initState() {
    super.initState();
    _prepareInlineImage();
  }

  @override
  void didUpdateWidget(covariant MessageBubble oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.message.imageUrl != widget.message.imageUrl) {
      _prepareInlineImage();
    }
  }

  void _prepareInlineImage() {
    final url = widget.message.imageUrl;
    if (url != null && url.startsWith('data:image')) {
      if (_inlineImageUrl == url && _inlineImageBytes != null) {
        return;
      }
      try {
        final parts = url.split(',');
        if (parts.length >= 2) {
          var base64String = parts[1].trim();
          base64String = base64String.replaceAll(RegExp(r'\s'), '');
          _inlineImageBytes = base64Decode(base64String);
          _inlineImageUrl = url;
        } else {
          _inlineImageBytes = null;
          _inlineImageUrl = url;
        }
      } catch (_) {
        _inlineImageBytes = null;
        _inlineImageUrl = url;
      }
    } else {
      _inlineImageBytes = null;
      _inlineImageUrl = url;
    }
  }

  MarkdownStyleSheet _buildMarkdownStyleSheet(Color textColor) {
    final fontSizes = [13.0, 15.0, 17.0, 19.0, 21.0];
    int index = widget.fontSizeIndex;
    if (index < 0) {
      index = 0;
    } else if (index >= fontSizes.length) {
      index = fontSizes.length - 1;
    }
    final baseSize = fontSizes[index];
    final family = widget.fontFamily;

    TextStyle applyFont(TextStyle base, String? family) {
      if (family == null || family.isEmpty) {
        return base;
      }
      switch (family) {
        case 'Roboto':
          return GoogleFonts.roboto(textStyle: base);
        case 'Montserrat':
          return GoogleFonts.montserrat(textStyle: base);
        case 'Open Sans':
          return GoogleFonts.openSans(textStyle: base);
        case 'Lato':
          return GoogleFonts.lato(textStyle: base);
        case 'PT Sans':
          return GoogleFonts.ptSans(textStyle: base);
        case 'Nunito':
          return GoogleFonts.nunito(textStyle: base);
        case 'Poppins':
          return GoogleFonts.poppins(textStyle: base);
        case 'Merriweather':
          return GoogleFonts.merriweather(textStyle: base);
        default:
          return base.copyWith(fontFamily: family);
      }
    }

    TextStyle baseStyle(
      double size, {
      FontWeight? fontWeight,
      FontStyle? fontStyle,
    }) {
      final base = TextStyle(
        color: textColor,
        fontSize: size,
        fontWeight: fontWeight,
        fontStyle: fontStyle,
      );
      return applyFont(base, family);
    }

    return MarkdownStyleSheet(
      p: baseStyle(baseSize),
      strong: baseStyle(baseSize, fontWeight: FontWeight.bold),
      em: baseStyle(baseSize, fontStyle: FontStyle.italic),
      listBullet: baseStyle(baseSize),
      h1: baseStyle(baseSize + 11, fontWeight: FontWeight.bold),
      h2: baseStyle(baseSize + 9, fontWeight: FontWeight.bold),
      h3: baseStyle(baseSize + 7, fontWeight: FontWeight.bold),
      blockquote: baseStyle(baseSize).copyWith(
        color: textColor.withOpacity(0.8),
        fontStyle: FontStyle.italic,
      ),
      code: const TextStyle(
        color: Colors.white,
        backgroundColor: Color(0xFF2A2A2A),
        fontFamily: 'monospace',
      ),
      tableColumnWidth: const FlexColumnWidth(),
    );
  }

  String _injectEasterEggLinks(String text) {
    // GameBoostW42 önce easter egg linkine dönüştürülüyordu.
    // Artık normal metin olarak kalmasını istiyoruz.
    return text;
  }

  void _showQuickActionsSheet() {
    if (widget.onQuickAction == null || widget.message.isUser) {
      return;
    }
    final bool hasCodeBlock = widget.message.content.contains('```');
    final bool isChartCandidate = widget.message.isChartCandidate;
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                ListTile(
                  leading: const Icon(
                    Icons.summarize,
                    color: Colors.white,
                    size: 20,
                  ),
                  title: const Text(
                    'Kısaca özetle',
                    style: TextStyle(color: Colors.white, fontSize: 14),
                  ),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    widget.onQuickAction?.call('summary', widget.message);
                  },
                ),
                if (hasCodeBlock)
                  ListTile(
                    leading: const Icon(
                      Icons.code,
                      color: Colors.white,
                      size: 20,
                    ),
                    title: const Text(
                      'Kod panelinde aç',
                      style: TextStyle(color: Colors.white, fontSize: 14),
                    ),
                    onTap: () {
                      Navigator.of(ctx).pop();
                      widget.onQuickAction?.call('code_panel', widget.message);
                    },
                  ),
                if (isChartCandidate)
                  ListTile(
                    leading: const Icon(
                      Icons.bar_chart,
                      color: Colors.white,
                      size: 20,
                    ),
                    title: const Text(
                      'Grafiğini Çıkar',
                      style: TextStyle(color: Colors.white, fontSize: 14),
                    ),
                    onTap: () {
                      Navigator.of(ctx).pop();
                      widget.onQuickAction?.call(
                        'generate_chart',
                        widget.message,
                      );
                    },
                  ),
                ListTile(
                  leading: const Icon(
                    Icons.format_list_bulleted,
                    color: Colors.white,
                    size: 20,
                  ),
                  title: const Text(
                    'Madde madde çıkar',
                    style: TextStyle(color: Colors.white, fontSize: 14),
                  ),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    widget.onQuickAction?.call('bullets', widget.message);
                  },
                ),
                ListTile(
                  leading: const Icon(
                    Icons.arrow_downward,
                    color: Colors.white,
                    size: 20,
                  ),
                  title: const Text(
                    'Devam et',
                    style: TextStyle(color: Colors.white, fontSize: 14),
                  ),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    widget.onQuickAction?.call('continue', widget.message);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _handleCopy() {
    Clipboard.setData(ClipboardData(text: widget.message.content));
    _showCopyNotification();
    if (widget.onCopy != null) {
      widget.onCopy!();
    }
  }

  void _showCopyNotification() {
    // Artık GreyNotification kullanıyoruz, bu fonksiyon gereksiz
  }

  void _openFullscreenImage([String? imageUrl]) {
    final targetImageUrl = imageUrl ?? widget.message.imageUrl;
    if (targetImageUrl != null) {
      Navigator.of(context).push(
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) =>
              FullscreenImageViewer(
                imageData: targetImageUrl,
                heroTag: imageUrl != null ? 'image_${widget.message.id}_${imageUrl.hashCode}' : 'image_${widget.message.id}',
              ),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
          transitionDuration: const Duration(milliseconds: 300),
        ),
      );
    }
  }

  List<Widget> _parseMessageContent(String content) {
    final widgets = <Widget>[];
    final codeBlockRegex = RegExp(
      r'```(\w+)?(?::([\w\.\-]+))?\n([\s\S]*?)```',
      multiLine: true,
    );
    // Telefon numaralarını yakalamak için gelişmiş regex
    // Desteklenen formatlar: 444 850 1234, +90 500 123 45 67, 0555 123 45 67, 0212 555 44 33, 4448501234
    final phoneRegex = RegExp(r'(\+?\d{1,4}[\s\-]?)?(444[\s\-]?\d{3}[\s\-]?\d{4}|\d{3}[\s\-]?\d{3}[\s\-]?\d{2}[\s\-]?\d{2}|\d{4}[\s\-]?\d{4}|\d{10,15})');
    // Mesaj balonu rengine göre akıllı metin rengi (kullanıcı için balon, AI için yüzey)
    final colorScheme = Theme.of(context).colorScheme;
    final bubbleColor = widget.message.isUser
        ? _getUserBubbleColor(context)
        : colorScheme.surface;
    final textColor = bubbleColor.computeLuminance() > 0.5
        ? Colors.black87
        : Colors.white;
    final styleSheet = _buildMarkdownStyleSheet(textColor);

    // Telefon numaralarını tespit et ve işaretle
    String processedContent = content.replaceAllMapped(
      RegExp(r'\[SETTINGS_LINK:(.*?)\]'),
      (match) => '[${match.group(1)}](settings://${match.group(1)})',
    );
    final phoneMatches = phoneRegex.allMatches(content).toList();
    final phoneNumbers = <String>[];

    for (final match in phoneMatches.reversed) {
      final rawPhone = match.group(1)!;
      // Sadece rakamları alarak normalize et
      final phone = rawPhone.replaceAll(RegExp(r'\D'), '');

      // Kod bloğu içinde mi kontrol et
      bool inCodeBlock = false;
      for (final codeMatch in codeBlockRegex.allMatches(content)) {
        if (match.start >= codeMatch.start && match.end <= codeMatch.end) {
          inCodeBlock = true;
          break;
        }
      }

      if (!inCodeBlock && (phone.length >= 10 && phone.length <= 15 || phone.startsWith('444') && phone.length >= 7)) {
        phoneNumbers.add(phone);
        // Telefon numarasını özel işaretle
        processedContent =
            processedContent.substring(0, match.start) +
            ' [PHONE:$phone] ' +
            processedContent.substring(match.end);
      }
    }

    int lastIndex = 0;
    final cbIndices = widget.codeBlockIndices ?? const <int>[];
    int cbPtr = 0;
    for (final match in codeBlockRegex.allMatches(processedContent)) {
      // Add text before code block with markdown
      if (match.start > lastIndex) {
        final textBefore = processedContent
            .substring(lastIndex, match.start)
            .trim();
        if (textBefore.isNotEmpty) {
          widgets.add(
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: _buildContentWithTables(
                  _injectEasterEggLinks(textBefore),
                  styleSheet,
                ),
              ),
            ),
          );
        }
      }

      // Add code block, but sadece gerçek kod dilleri için; 'text' veya boş dilde normal metin göster
      final rawLanguage = (match.group(1) ?? '').trim().toLowerCase();
      final filename = match.group(2)?.trim();
      final code = match.group(3) ?? '';
      const codeLanguages = {
        'dart',
        'javascript',
        'js',
        'ts',
        'typescript',
        'python',
        'py',
        'java',
        'kotlin',
        'swift',
        'go',
        'php',
        'c',
        'cpp',
        'c++',
        'c#',
        'cs',
        'html',
        'css',
        'json',
        'yaml',
        'yml',
        'bash',
        'sh',
        'shell',
        'sql',
        'xml',
        'rust',
        'ruby',
      };
      final isCodeLanguage =
          rawLanguage.isNotEmpty && codeLanguages.contains(rawLanguage);

      if (isCodeLanguage) {
        int? cbIndex;
        if (cbPtr < cbIndices.length) {
          cbIndex = cbIndices[cbPtr];
          cbPtr++;
        }

        widgets.add(
          CodeBlock(
            code: code.trim(),
            language: rawLanguage,
            cbIndex: cbIndex,
            filename: filename,
            onOpenInPanel: widget.onQuickAction == null || widget.message.isUser
                ? null
                : () =>
                      widget.onQuickAction?.call('code_panel', widget.message),
            onGenerateReference:
                cbIndex == null || widget.onCodeReferenceGenerated == null
                ? null
                : (ref) => widget.onCodeReferenceGenerated?.call(ref),
          ),
        );
      } else {
        final plainText = code.trim();
        if (plainText.isNotEmpty) {
          widgets.add(
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: _buildContentWithTables(
                  _injectEasterEggLinks(plainText),
                  styleSheet,
                ),
              ),
            ),
          );
        }
      }

      lastIndex = match.end;
    }

    // Add remaining text with markdown
    if (lastIndex < processedContent.length) {
      final remainingText = processedContent.substring(lastIndex).trim();
      if (remainingText.isNotEmpty) {
        widgets.addAll(
          _buildContentWithTables(
            _injectEasterEggLinks(remainingText),
            styleSheet,
          ),
        );
      }
    }

    // If no code blocks found, return original text with markdown
    if (widgets.isEmpty) {
      widgets.addAll(
        _buildContentWithTables(
          _injectEasterEggLinks(processedContent),
          styleSheet,
        ),
      );
    }

    return widgets;
  }

  List<Widget> _buildContentWithTables(
    String text,
    MarkdownStyleSheet styleSheet,
  ) {
    final widgets = <Widget>[];
    // Regex logic to find tables
    // Matches a block starting with | ... |, followed by |---|, followed by optional body
    final tableRegex = RegExp(
      r'(^|\n)(\|.*\|(?:\n\|[-:| ]+\|)(?:\n\|.*\|)*)',
      multiLine: true,
    );

    int lastIndex = 0;
    for (final match in tableRegex.allMatches(text)) {
      if (match.start > lastIndex) {
        final textBefore = text.substring(lastIndex, match.start).trim();
        if (textBefore.isNotEmpty) {
          widgets.add(_buildTextWithPhoneNumbers(textBefore, styleSheet));
        }
      }

      final tableText = match.group(2) ?? '';
      if (tableText.isNotEmpty) {
        // Wrap table in horizontal scroll with IntrinsicColumnWidth
        widgets.add(
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: MarkdownBody(
              data: tableText,
              styleSheet: styleSheet.copyWith(
                tableColumnWidth: const IntrinsicColumnWidth(),
              ),
            ),
          ),
        );
      }

      lastIndex = match.end;
    }

    if (lastIndex < text.length) {
      final remaining = text.substring(lastIndex).trim();
      if (remaining.isNotEmpty) {
        widgets.add(_buildTextWithPhoneNumbers(remaining, styleSheet));
      }
    }

    // Fallback: If no tables/split logic works or empty, just return standard
    if (widgets.isEmpty && text.isNotEmpty) {
      widgets.add(_buildTextWithPhoneNumbers(text, styleSheet));
    }

    return widgets;
  }

  Widget _buildTextWithPhoneNumbers(
    String text,
    MarkdownStyleSheet styleSheet,
  ) {
    // Hide raw PDF content
    if (text.contains('[PDF_CONTENT_START]')) {
      final startIndex = text.indexOf('[PDF_CONTENT_START]');
      final endIndex = text.indexOf('[PDF_CONTENT_END]');
      if (endIndex != -1) {
        text = text
            .replaceRange(startIndex, endIndex + '[PDF_CONTENT_END]'.length, '')
            .trim();
      } else {
        text = text.substring(0, startIndex).trim();
      }
    }

    final pdfMarkerRegex = RegExp(r'\[PDF: ([^\]]+)\]');
    final phoneMarkerRegex = RegExp(r'\[PHONE:(\d{7,15})\]');

    final parts = <Widget>[];
    int lastIndex = 0;

    // Use a combined approach or sequential. Since they won't overlap usually.
    // Let's do a simple approach: find both and sort by start index.
    final allMatches = <Map<String, dynamic>>[];
    for (final m in phoneMarkerRegex.allMatches(text)) {
      allMatches.add({
        'start': m.start,
        'end': m.end,
        'type': 'phone',
        'match': m,
      });
    }
    for (final m in pdfMarkerRegex.allMatches(text)) {
      allMatches.add({
        'start': m.start,
        'end': m.end,
        'type': 'pdf',
        'match': m,
      });
    }
    allMatches.sort((a, b) => a['start'].compareTo(b['start']));

    for (final item in allMatches) {
      final start = item['start'] as int;
      final end = item['end'] as int;
      final type = item['type'] as String;
      final match = item['match'] as Match;

      // Add text before
      if (start > lastIndex) {
        final textBefore = text.substring(lastIndex, start);
        if (textBefore.trim().isNotEmpty) {
          parts.add(
            MarkdownBody(
              data: textBefore,
              styleSheet: styleSheet,
              softLineBreak: true,
              onTapLink: (t, href, title) => _onLinkTap(href ?? t),
            ),
          );
        }
      }

      if (type == 'phone') {
        final phoneNumber = match.group(1)!;
        parts.add(
          GestureDetector(
            onTap: () => showModalBottomSheet(
              context: context,
              backgroundColor: Colors.transparent,
              isScrollControlled: true,
              builder: (ctx) => PhoneNumberPanel(phoneNumber: phoneNumber),
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              margin: const EdgeInsets.symmetric(vertical: 2),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.2),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Colors.blue.withOpacity(0.5)),
              ),
              child: Text(
                phoneNumber,
                style: TextStyle(
                  color: Colors.blue.shade300,
                  decoration: TextDecoration.underline,
                  fontSize: 15,
                ),
              ),
            ),
          ),
        );
      } else if (type == 'pdf') {
        final pdfName = match.group(1)!;
        parts.add(
          Container(
            margin: const EdgeInsets.symmetric(vertical: 10),
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.white.withOpacity(0.12),
                  Colors.white.withOpacity(0.04),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  GreyNotification.show(context, 'PDF dosyası açılıyor...');
                },
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.redAccent.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: FaIcon(
                          FontAwesomeIcons.filePdf,
                          color: Colors.redAccent,
                          size: 26,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              pdfName,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.2,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Text(
                                  'PDF Belgesi',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.5),
                                    fontSize: 11,
                                  ),
                                ),
                                Container(
                                  width: 3,
                                  height: 3,
                                  margin: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                  ),
                                  decoration: const BoxDecoration(
                                    color: Colors.white24,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const Text(
                                  'İncelemek için tıklayın',
                                  style: TextStyle(
                                    color: Colors.blueAccent,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.chevron_right,
                        color: Colors.white.withOpacity(0.2),
                        size: 20,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      }

      lastIndex = end;
    }

    // Add remaining
    if (lastIndex < text.length) {
      final remaining = text.substring(lastIndex);
      if (remaining.trim().isNotEmpty) {
        // If it's a huge extracted text, maybe hide it or show as "İçerik okundu"
        // The user says "AI a göre o Yazıllı gözüksün ama bizde Dosya göndermiş gibi"
        // This means we should probably hide the raw text if it follows a PDF marker.
        // But for now let's show it in a subtle way or just show it if it's small.
        parts.add(
          MarkdownBody(
            data: remaining,
            styleSheet: styleSheet,
            softLineBreak: true,
            onTapLink: (t, href, title) => _onLinkTap(href ?? t),
          ),
        );
      }
    }

    if (parts.isEmpty) {
      return MarkdownBody(data: text, styleSheet: styleSheet);
    }

    return Column(
      crossAxisAlignment: widget.message.isUser
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: parts,
    );
  }

  bool _containsMarkdownTable(String text) {
    // Sadece gerçek markdown tablolarını tespit et:
    // Bir satırda en az bir '|' ve hemen altında --- | --- benzeri ayırıcı satır olmalı.
    final lines = text.split('\n').map((l) => l.trimRight()).toList();
    if (lines.length < 2) return false;

    for (int i = 0; i < lines.length - 1; i++) {
      final header = lines[i];
      final separator = lines[i + 1];
      if (!header.contains('|') || !separator.contains('|')) continue;

      // Ayırıcı satır: en az üç '-' veya '=' içeren ve pipelerle ayrılmış kısımlar
      final sepTrimmed = separator.replaceAll(' ', '');
      final hasDashes = RegExp(
        r'^\|?[:\-=]+(\|[:\-=]+)+\|?$',
      ).hasMatch(sepTrimmed);
      if (hasDashes) {
        return true;
      }
    }
    return false;
  }

  Widget _buildImageSection() {
    final imageUrls = widget.message.imageUrls ?? [];
    final singleImageUrl = widget.message.imageUrl;
    
    // Eğer tek bir imageUrl varsa, onu listeye ekle
    final allImageUrls = singleImageUrl != null 
        ? [singleImageUrl, ...imageUrls] 
        : imageUrls;
    
    if (allImageUrls.isEmpty) {
      return const SizedBox.shrink();
    }

    // Görsel sayısına göre layout belirle
    if (allImageUrls.length == 1) {
      // 1 görsel: normal göster
      return _buildSingleImage(allImageUrls.first);
    } else if (allImageUrls.length == 2) {
      // 2 görsel: yan yana
      return _buildTwoImages(allImageUrls);
    } else if (allImageUrls.length >= 3) {
      // 3+ görsel: üstte 1, altta 2
      return _buildThreeImages(allImageUrls.take(3).toList());
    }
    
    return const SizedBox.shrink();
  }

  Widget _buildSingleImage(String imageUrl) {
    return GestureDetector(
      onTap: () => _openFullscreenImage(imageUrl),
      child: Hero(
        tag: 'image_${widget.message.id}_0',
        child: SizedBox(
          width: 240,
          height: 240,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: imageUrl.startsWith('data:image')
                ? (_inlineImageBytes != null
                      ? Image.memory(
                          _inlineImageBytes!,
                          fit: BoxFit.cover,
                          cacheWidth: 800,
                          filterQuality: FilterQuality.medium,
                          gaplessPlayback: true,
                        )
                      : const SizedBox.shrink())
                : Image.file(
                    File(imageUrl),
                    fit: BoxFit.cover,
                    cacheWidth: 800,
                    filterQuality: FilterQuality.medium,
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildTwoImages(List<String> imageUrls) {
    return SizedBox(
      width: 240,
      height: 240,
      child: Row(
        children: [
          Expanded(
            child: _buildImageContainer(imageUrls[0], 0),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: _buildImageContainer(imageUrls[1], 1),
          ),
        ],
      ),
    );
  }

  Widget _buildThreeImages(List<String> imageUrls) {
    return Column(
      children: [
        // Üstte: 1 görsel (tam genişlik)
        SizedBox(
          width: 240,
          height: 118,
          child: _buildImageContainer(imageUrls[0], 0),
        ),
        const SizedBox(height: 4),
        // Altta: 2 görsel (yan yana)
        SizedBox(
          width: 240,
          height: 118,
          child: Row(
            children: [
              Expanded(
                child: _buildImageContainer(imageUrls[1], 1),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: _buildImageContainer(imageUrls[2], 2),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildImageContainer(String imageUrl, int index) {
    return GestureDetector(
      onTap: () => _openFullscreenImage(imageUrl),
      child: Hero(
        tag: 'image_${widget.message.id}_$index',
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: imageUrl.startsWith('data:image')
              ? Image.memory(
                  _getInlineImageBytes(imageUrl)!,
                  fit: BoxFit.cover,
                  cacheWidth: 400,
                  filterQuality: FilterQuality.medium,
                  gaplessPlayback: true,
                )
              : Image.file(
                  File(imageUrl),
                  fit: BoxFit.cover,
                  cacheWidth: 400,
                  filterQuality: FilterQuality.medium,
                ),
        ),
      ),
    );
  }

  Uint8List? _getInlineImageBytes(String imageUrl) {
    if (imageUrl.startsWith('data:image')) {
      try {
        final parts = imageUrl.split(',');
        if (parts.length < 2) return null;
        String base64String = parts[1].trim();
        base64String = base64String.replaceAll(RegExp(r'\s'), '');
        return base64Decode(base64String);
      } catch (e) {
        return null;
      }
    }
    return null;
  }

  
  @override
  Widget build(BuildContext context) {
    // Performans için gereksiz kontroller kaldırıldı

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: GestureDetector(
        onLongPress: () {
          _showMessageContextMenu();
        },
        onTap: () {
          // Tap işlevi kaldırıldı - kopyalama sadece long press menüsünde
        },
        child: Container(
          decoration: BoxDecoration(
            color: widget.isSelected
                ? Colors.blue.withValues(alpha: 0.1)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: widget.message.isUser
                    ? MainAxisAlignment.end
                    : MainAxisAlignment.start,
                children: [
                  // AI mesajı için: Avatar - Mesaj - Kopyala butonu (sağda)
                  if (!widget.message.isUser) _buildAvatar(),
                  if (!widget.message.isUser) const SizedBox(width: 8),
                  // Kullanıcı mesajı için: Mesaj - Avatar (kopyala butonu kaldırıldı)
                  Flexible(
                    child: Column(
                      crossAxisAlignment: widget.message.isUser
                          ? CrossAxisAlignment.end
                          : CrossAxisAlignment.start,
                      children: [
                        if (!widget.message.isUser &&
                            widget.message.senderUsername != null)
                          Padding(
                            padding: const EdgeInsets.only(
                              bottom: 4.0,
                              left: 4.0,
                            ),
                            child: Text(
                              widget.message.senderUsername!,
                              style: TextStyle(
                                // AI ise Beyaz, değilse Mavi
                                color:
                                    (widget.message.senderUsername ==
                                            'ForeSee' ||
                                        widget.message.senderUsername ==
                                            'ai_foresee')
                                    ? Colors.white
                                    : Colors.blueAccent.shade100,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: widget.message.isUser ? 16 : 0,
                            vertical: widget.message.isUser ? 12 : 0,
                          ),
                          decoration: widget.message.isUser
                              ? BoxDecoration(
                                  color: _getUserBubbleColor(context),
                                  borderRadius: BorderRadius.circular(20),
                                  border: widget.isSelected
                                      ? Border.all(
                                          color: Colors.white.withOpacity(0.5),
                                          width: 2,
                                        )
                                      : null,
                                )
                              : BoxDecoration(
                                  // AI mesajları için tamamen düz, şeffaf
                                  color: Colors.transparent,
                                  border: widget.isSelected
                                      ? Border.all(
                                          color: Theme.of(
                                            context,
                                          ).primaryColor.withOpacity(0.3),
                                          width: 1.5,
                                        )
                                      : null,
                                  borderRadius: widget.isSelected
                                      ? BorderRadius.circular(8)
                                      : null,
                                ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (widget.message.imageUrl != null)
                                _buildImageSection(),
                              // Mesaj içeriği
                              if (widget.message.chartData != null &&
                                  widget.message.chartData is LineChartData)
                                _buildChart(widget.message.chartData)
                              else if (widget.isTyping &&
                                  widget.message.content.isEmpty &&
                                  !widget.message.isUser)
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 4,
                                  ),
                                  child: _buildTypingIndicator(),
                                )
                              else if (!widget.isTyping &&
                                  widget.message.content.isEmpty &&
                                  widget.message.imageUrl != null &&
                                  !widget.message.isUser)
                                const SizedBox(height: 4)
                              else
                                ..._buildSelectableMessageContent(),

                              if (widget.message.alternatives != null &&
                                  widget.message.alternatives!.length > 1)
                                Padding(
                                  padding: const EdgeInsets.only(top: 8.0),
                                  child: MultiAnswerSwitcher(
                                    alternatives: widget.message.alternatives!,
                                    currentIndex:
                                        widget.message.displayAlternativeIndex,
                                    onAlternativeSelected: (index) {
                                      widget.onAlternativeSelected?.call(
                                        widget.message,
                                        index,
                                      );
                                    },
                                    onDismiss: () {
                                      final randomIndex = Random().nextInt(
                                        widget.message.alternatives!.length,
                                      );
                                      widget.onAlternativeSelected?.call(
                                        widget.message,
                                        randomIndex,
                                      );
                                    },
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          mainAxisAlignment: widget.message.isUser
                              ? MainAxisAlignment.end
                              : MainAxisAlignment.start,
                          children: [
                            SelectableText(
                              DateFormat(
                                'HH:mm',
                              ).format(widget.message.timestamp),
                              style: Theme.of(context).textTheme.bodyMedium!
                                  .copyWith(
                                    fontSize: 11, // Saat metni kucult
                                    color: widget.message.isUser
                                        ? (_getUserBubbleColor(
                                                    context,
                                                  ).computeLuminance() >
                                                  0.5
                                              ? Colors.black54
                                              : Colors.white60)
                                        : (Theme.of(context).brightness ==
                                                  Brightness.dark
                                              ? Colors.white54
                                              : Colors.black54),
                                  ),
                            ),
                            // Durdurulmuş mesaj göstergesi
                            if (widget.message.isStopped) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF2B1A1A),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: Colors.redAccent.withOpacity(0.7),
                                    width: 0.8,
                                  ),
                                ),
                                child: const Text(
                                  'Durduruldu',
                                  style: TextStyle(
                                    color: Colors.redAccent,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                            // Son AI mesajı için üç nokta menüsü ve ikonlar
                            if (!widget.message.isUser &&
                                widget.isLastAiMessage &&
                                !widget.isTyping &&
                                widget.onQuickAction != null) ...[
                              const SizedBox(width: 6),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // 3 nokta
                                  GestureDetector(
                                    onTap: _showQuickActionsSheet,
                                    child: Icon(
                                      Icons.more_horiz,
                                      color: themeService.isDarkMode ? Colors.white54 : Colors.black54,
                                      size: 16,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  // Kopyala butonu
                                  _buildCopyButton(),
                                  const SizedBox(width: 8),
                                  // Beğeni/beğenme butonları
                                  _buildLikeDislikeButtons(),
                                ],
                              ),
                            ],
                            // Akıllı hızlı aksiyon butonları (son AI mesajı için)
                            // Web arama kaynakları
                            if (!widget.message.isUser && _hasSearchResults()) ...[
                              const SizedBox(height: 8),
                              _buildSearchSources(),
                            ],
                          ],
                        ),
                        // Devam ettir butonu
                        if (widget.message.isStopped &&
                            !widget.message.isUser) ...[
                          const SizedBox(height: 8),
                          GestureDetector(
                            onTap: widget.onContinue,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 7,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF2563EB),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: const [
                                  Icon(
                                    Icons.play_arrow,
                                    color: Colors.white,
                                    size: 14,
                                  ),
                                  SizedBox(width: 6),
                                  Text(
                                    'Devam ettir',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                        // Akıllı hızlı aksiyon butonları (son AI mesajı için)
                        // Web arama kaynakları
                        if (!widget.message.isUser && _hasSearchResults()) ...[
                          const SizedBox(height: 8),
                          _buildSearchSources(),
                        ],
                      ],
                    ),
                  ),
                  // AI mesajı için: Kopyala butonu kaldırıldı
                  const SizedBox(width: 8),
                  if (widget.message.isUser) _buildAvatar(),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _runTranslateQuickAction(BuildContext sheetContext, String actionId) {
    final content = widget.message.content.trim();
    if (content.isEmpty) {
      Navigator.pop(sheetContext);
      GreyNotification.show(context, 'Çevrilecek metin yok');
      return;
    }

    Navigator.pop(sheetContext);
    if (widget.onQuickAction != null) {
      widget.onQuickAction!(actionId, widget.message);
    } else {
      GreyNotification.show(context, 'Çeviri şu anda kullanılamıyor');
    }
  }

  Widget _buildLangFlag(String emoji) {
    return CircleAvatar(
      radius: 14,
      backgroundColor: const Color(0xFF111827),
      child: Text(emoji, style: const TextStyle(fontSize: 14)),
    );
  }

  Widget _buildQuickActionChip({
    required String label,
    required String actionId,
  }) {
    return InkWell(
      onTap: () {
        if (widget.onQuickAction != null) {
          widget.onQuickAction!(actionId, widget.message);
        }
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white24),
        ),
        child: Text(
          label,
          style: const TextStyle(color: Colors.white, fontSize: 11),
        ),
      ),
    );
  }

  Widget _buildInlineCopyButton() {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      child: IconButton(
        icon: const Icon(Icons.copy, size: 18),
        color: Colors.white60,
        onPressed: _handleCopy,
        padding: const EdgeInsets.all(8),
        constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
        style: IconButton.styleFrom(
          backgroundColor: const Color(0xFF2A2A2A),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
    );
  }

  Color _generateAvatarColor(String username) {
    final colors = [
      Colors.blue,
      Colors.red,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.teal,
      Colors.pink,
      Colors.indigo,
      Colors.brown,
      Colors.cyan,
    ];
    final index = username.hashCode.abs() % colors.length;
    return colors[index];
  }

  Widget _buildAvatar() {
    if (widget.message.isUser) {
      return const SizedBox.shrink();
    } else {
      // AI KONTROLÜ
      final bool isAI =
          widget.message.senderUsername == 'ForeSee' ||
          widget.message.senderUsername == 'ai_foresee' ||
          widget.message.senderUsername == null;

      if (isAI) {
        // AI Avatarı: logo3.png, siyah zemin
        return Container(
          width: 36,
          height: 36,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.black, // AI için siyah zemin
          ),
          padding: const EdgeInsets.all(2), // Biraz padding
          child: ClipOval(
            child: Image.asset(
              themeService.getLogoPath('logo3.png'),
              fit: BoxFit.contain, // Logo tam sığsın
              filterQuality: FilterQuality.high,
              errorBuilder: (context, error, stackTrace) =>
                  const Icon(Icons.smart_toy, color: Colors.white, size: 20),
            ),
          ),
        );
      }

      // KULLANICI AVATARI (Grup üyesi)
      // Eğer senderPhotoUrl varsa onu kullan, yoksa harfli avatar oluştur
      if (widget.message.senderPhotoUrl != null &&
          widget.message.senderPhotoUrl!.isNotEmpty &&
          !widget.message.senderPhotoUrl!.startsWith('assets/')) {
        return CircleAvatar(
          radius: 18,
          backgroundColor: Colors.grey[800],
          backgroundImage: NetworkImage(widget.message.senderPhotoUrl!),
        );
      }

      // FOTOĞRAF YOKSA -> İSİM BAŞ HARFLERİ + RENKLİ ZEMİN
      final username = widget.message.senderUsername ?? '?';
      // İlk 2 harf (veya tek harf)
      String initials = username.length >= 2
          ? username.substring(0, 2).toUpperCase()
          : username.substring(0, 1).toUpperCase();

      return CircleAvatar(
        radius: 18,
        backgroundColor: _generateAvatarColor(username), // Rastgele renk
        child: Text(
          initials,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }
  }

  List<Widget> _buildSelectableMessageContent() {
    final content = widget.message.content;
    return _parseMessageContent(content);
  }

  Widget _buildChart(LineChartData data) {
    return Container(
      height: 200,
      padding: const EdgeInsets.only(top: 16, right: 16),
      child: LineChart(data),
    );
  }

  bool _hasSearchResults() {
    final data = widget.message.searchResult;
    if (data == null) return false;
    final results = data['results'];
    if (results is List && results.isNotEmpty) {
      return true;
    }
    return false;
  }

  Widget _buildSearchSources() {
    final data = widget.message.searchResult;
    final results = (data?['results'] as List?) ?? [];
    if (results.isEmpty) {
      return const SizedBox.shrink();
    }
    final query = (data?['query'] ?? '').toString();
    final logosToShow = results.length > 3 ? 3 : results.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () {
            setState(() {
              _sourcesExpanded = !_sourcesExpanded;
            });
          },
          child: Row(
            children: [
              Text(
                'Kaynaklar:',
                style: TextStyle(
                  color: themeService.isDarkMode ? Colors.white60 : Colors.black54,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 8),
              Row(
                children: List.generate(logosToShow, (index) {
                  final raw = results[index];
                  final item = raw is Map<String, dynamic>
                      ? raw
                      : <String, dynamic>{};
                  final link = (item['link'] ?? '').toString();
                  return Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: _buildSiteLogo(link, radius: 10),
                  );
                }),
              ),
              const Spacer(),
              Icon(
                _sourcesExpanded
                    ? Icons.keyboard_arrow_up
                    : Icons.keyboard_arrow_down,
                color: themeService.isDarkMode ? Colors.white54 : Colors.black54,
                size: 18,
              ),
            ],
          ),
        ),
        AnimatedCrossFade(
          firstChild: const SizedBox.shrink(),
          secondChild: Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (query.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      'Soru: $query',
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 11,
                      ),
                    ),
                  ),
                SizedBox(
                  height: 160,
                  child: ListView.builder(
                    shrinkWrap: true,
                    physics: const BouncingScrollPhysics(),
                    itemCount: results.length,
                    itemBuilder: (context, index) {
                      final raw = results[index];
                      final item = raw is Map<String, dynamic>
                          ? raw
                          : <String, dynamic>{};
                      final title = (item['title'] ?? '').toString();
                      final link = (item['link'] ?? '').toString();
                      final snippet = (item['snippet'] ?? '').toString();

                      return Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: InkWell(
                          onTap: () {
                            if (link.isNotEmpty) {
                              _onLinkTap(link);
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: themeService.isDarkMode ? const Color(0xFF101010) : Colors.grey.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: themeService.isDarkMode ? Colors.white10 : Colors.black12),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildSiteLogo(link, radius: 12),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      if (title.isNotEmpty)
                                        Text(
                                          title,
                                          style: TextStyle(
                                            color: themeService.isDarkMode ? Colors.white : Colors.black87,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      if (link.isNotEmpty)
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            top: 2,
                                          ),
                                          child: Text(
                                            _extractDomain(link),
                                            style: TextStyle(
                                              color: themeService.isDarkMode ? Colors.blueAccent : Colors.blue,
                                              fontSize: 11,
                                            ),
                                          ),
                                        ),
                                      if (snippet.isNotEmpty)
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            top: 2,
                                          ),
                                          child: Text(
                                            snippet,
                                            style: TextStyle(
                                              color: themeService.isDarkMode ? Colors.white60 : Colors.black54,
                                              fontSize: 11,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          crossFadeState: _sourcesExpanded
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 200),
        ),
      ],
    );
  }

  String _extractDomain(String url) {
    try {
      final uri = Uri.parse(url);
      if (uri.host.isNotEmpty) {
        return uri.host;
      }
      return url;
    } catch (_) {
      return url;
    }
  }

  String _getLogoLetter(String url) {
    final domain = _extractDomain(url);
    if (domain.isEmpty) return '?';
    final first = domain[0];
    return first.toUpperCase();
  }

  Widget _buildSiteLogo(String link, {double radius = 12}) {
    final domain = _extractDomain(link);
    final letter = _getLogoLetter(link);

    if (domain.isEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: const Color(0xFF2A2A2A),
        child: Text(
          letter,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    final faviconUrl =
        'https://www.google.com/s2/favicons?domain=$domain&sz=64';

    return CircleAvatar(
      radius: radius,
      backgroundColor: const Color(0xFF2A2A2A),
      child: ClipOval(
        child: Image.network(
          faviconUrl,
          width: radius * 2,
          height: radius * 2,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return Center(
              child: Text(
                letter,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // Mod'a göre typing göstergesi (etiket + 3 nokta veya sadece 3 nokta)
  Widget _buildTypingIndicator() {
    final label = _extractLoadingLabel(widget.loadingMessage);
    if (label == null) {
      // Normal/görsel analiz veya bilinmeyen durumlarda sadece 3 nokta
      return _ThinkingDots();
    }
    return GestureDetector(
      onTap: widget.onShowReasoning,
      child: _ModeLoadingIndicator(label: label),
    );
  }

  String? _extractLoadingLabel(String? loadingMessage) {
    if (loadingMessage == null) return null;
    if (loadingMessage.startsWith('Görsel oluşturuluyor')) {
      return 'Görsel oluşturuluyor';
    }
    if (loadingMessage.startsWith('Aranıyor')) {
      return 'Aranıyor';
    }
    if (loadingMessage.startsWith('Derin düşünüyor')) {
      return 'Derin düşünüyor';
    }
    if (loadingMessage.startsWith('Düşünüyor')) {
      return 'Düşünüyor';
    }
    return null; // Diğer durumlarda sade 3 nokta
  }

  // Like/dislike butonları
  Widget _buildLikeDislikeButtons() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Like button
        GestureDetector(
          onTap: () {
            setState(() {
              _isLiked = !_isLiked;
              _isDisliked = false;
            });
            // Like functionality here - save to backend
            GreyNotification.show(context, 'Beğenildi');
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.all(4),
            child: FaIcon(
              _isLiked ? FontAwesomeIcons.solidThumbsUp : FontAwesomeIcons.thumbsUp,
              color: _isLiked ? Colors.blue : Colors.grey[400],
              size: 14,
            ),
          ),
        ),
        const SizedBox(width: 4),
        // Dislike button
        GestureDetector(
          onTap: () {
            setState(() {
              _isDisliked = !_isDisliked;
              _isLiked = false;
            });
            // Dislike functionality here - save to backend
            GreyNotification.show(context, 'Beğenilmedi');
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.all(4),
            child: FaIcon(
              _isDisliked ? FontAwesomeIcons.solidThumbsDown : FontAwesomeIcons.thumbsDown,
              color: _isDisliked ? Colors.red : Colors.grey[400],
              size: 14,
            ),
          ),
        ),
      ],
    );
  }

  // Kopyalama tuşu
  Widget _buildCopyButton() {
    return GestureDetector(
      onTap: () async {
        setState(() {
          _isCopying = true;
        });
        
        await Clipboard.setData(ClipboardData(text: widget.message.content));
        
        // Toast bildirim göster
        _showCopyToast();
        
        // Animasyonu geri al
        Future.delayed(const Duration(seconds: 1), () {
          if (mounted) {
            setState(() {
              _isCopying = false;
            });
          }
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(4),
        child: FaIcon(
          _isCopying ? FontAwesomeIcons.check : FontAwesomeIcons.copy,
          color: _isCopying ? Colors.green : Colors.grey[400],
          size: 14,
        ),
      ),
    );
  }

  // Toast bildirim göster
  void _showCopyToast() {
    final overlay = Overlay.of(context);
    late OverlayEntry entry;
    
    entry = OverlayEntry(
      builder: (context) => Positioned(
        top: MediaQuery.of(context).padding.top + 50,
        left: 20,
        right: 20,
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: themeService.isDarkMode ? Colors.grey[800] : Colors.grey[700],
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                FaIcon(
                  FontAwesomeIcons.circleCheck,
                  color: Colors.green,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Text(
                  'Mesaj kopyalandı',
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
    );
    
    overlay.insert(entry);
    
    // 2 saniye sonra kaldır
    Future.delayed(const Duration(seconds: 2), () {
      entry.remove();
    });
  }

  // Mesajı panoya kopyala
  bool _isCopying = false;

  void _copyToClipboard() {
    setState(() => _isCopying = true);
    Clipboard.setData(ClipboardData(text: widget.message.content));
    
    // Simulate copy animation
    Future.delayed(const Duration(milliseconds: 500), () {
      setState(() => _isCopying = false);
    });
    
    GreyNotification.show(context, 'Mesaj kopyalandı');
  }

  // Mesaj context menu göster
  void _showMessageContextMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: themeService.isDarkMode ? const Color(0xFF1A1A1A) : Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    leading: Icon(Icons.copy, color: themeService.isDarkMode ? Colors.white : Colors.black87),
                    title: Text(
                      'Kopyala',
                      style: TextStyle(color: themeService.isDarkMode ? Colors.white : Colors.black87),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      _copyToClipboard();
                    },
                  ),
                  ListTile(
                    leading: Icon(Icons.text_fields, color: themeService.isDarkMode ? Colors.white : Colors.black87),
                    title: Text(
                      'Metin Seç',
                      style: TextStyle(color: themeService.isDarkMode ? Colors.white : Colors.black87),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      _selectText();
                    },
                  ),
                  if (widget.onPin != null)
                    ListTile(
                      leading: Icon(
                        widget.isPinned
                            ? Icons.push_pin
                            : Icons.push_pin_outlined,
                        color: themeService.isDarkMode ? Colors.white : Colors.black87,
                      ),
                      title: Text(
                        widget.isPinned ? 'Sabitten kaldır' : 'Mesajı sabitle',
                        style: TextStyle(color: themeService.isDarkMode ? Colors.white : Colors.black87),
                      ),
                      onTap: () {
                        Navigator.pop(context);
                        widget.onPin?.call(widget.message);
                      },
                    ),
                  if (!widget.message.isUser &&
                      widget.onQuickAction != null &&
                      widget.message.content.trim().isNotEmpty) ...[
                    const Divider(color: Colors.white24),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 4),
                        child: Text(
                          'Çevir',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                    ListTile(
                      leading: _buildLangFlag('🇹🇷'),
                      title: Text(
                        'Türkçe',
                        style: TextStyle(color: themeService.isDarkMode ? Colors.white : Colors.black87),
                      ),
                      onTap: () =>
                          _runTranslateQuickAction(context, 'translate_tr'),
                    ),
                    ListTile(
                      leading: _buildLangFlag('🇬🇧'),
                      title: Text(
                        'İngilizce (EN)',
                        style: TextStyle(color: themeService.isDarkMode ? Colors.white : Colors.black87),
                      ),
                      onTap: () =>
                          _runTranslateQuickAction(context, 'translate_en'),
                    ),
                    ListTile(
                      leading: _buildLangFlag('🇩🇪'),
                      title: Text(
                        'Almanca (DE)',
                        style: TextStyle(color: themeService.isDarkMode ? Colors.white : Colors.black87),
                      ),
                      onTap: () =>
                          _runTranslateQuickAction(context, 'translate_de'),
                    ),
                    ListTile(
                      leading: _buildLangFlag('🇫🇷'),
                      title: Text(
                        'Fransızca (FR)',
                        style: TextStyle(color: themeService.isDarkMode ? Colors.white : Colors.black87),
                      ),
                      onTap: () =>
                          _runTranslateQuickAction(context, 'translate_fr'),
                    ),
                    ListTile(
                      leading: _buildLangFlag('🇪🇸'),
                      title: Text(
                        'İspanyolca (ES)',
                        style: TextStyle(color: themeService.isDarkMode ? Colors.white : Colors.black87),
                      ),
                      onTap: () =>
                          _runTranslateQuickAction(context, 'translate_es'),
                    ),
                    ListTile(
                      leading: _buildLangFlag('🇮🇹'),
                      title: Text(
                        'İtalyanca (IT)',
                        style: TextStyle(color: themeService.isDarkMode ? Colors.white : Colors.black87),
                      ),
                      onTap: () =>
                          _runTranslateQuickAction(context, 'translate_it'),
                    ),
                    ListTile(
                      leading: _buildLangFlag('🇷🇺'),
                      title: Text(
                        'Rusça (RU)',
                        style: TextStyle(color: themeService.isDarkMode ? Colors.white : Colors.black87),
                      ),
                      onTap: () =>
                          _runTranslateQuickAction(context, 'translate_ru'),
                    ),
                    ListTile(
                      leading: _buildLangFlag('🇸🇦'),
                      title: Text(
                        'Arapça (AR)',
                        style: TextStyle(color: themeService.isDarkMode ? Colors.white : Colors.black87),
                      ),
                      onTap: () =>
                          _runTranslateQuickAction(context, 'translate_ar'),
                    ),
                    ListTile(
                      leading: _buildLangFlag('🇯🇵'),
                      title: Text(
                        'Japonca (JA)',
                        style: TextStyle(color: themeService.isDarkMode ? Colors.white : Colors.black87),
                      ),
                      onTap: () =>
                          _runTranslateQuickAction(context, 'translate_ja'),
                    ),
                    ListTile(
                      leading: _buildLangFlag('🇨🇳'),
                      title: Text(
                        'Çince (ZH)',
                        style: TextStyle(color: themeService.isDarkMode ? Colors.white : Colors.black87),
                      ),
                      onTap: () =>
                          _runTranslateQuickAction(context, 'translate_zh'),
                    ),
                  ],
                  if (!widget.message.isUser && widget.isLastAiMessage) ...[
                    ListTile(
                      leading: Icon(Icons.refresh, color: themeService.isDarkMode ? Colors.white : Colors.black87),
                      title: Text(
                        'Tekrar Dene',
                        style: TextStyle(color: themeService.isDarkMode ? Colors.white : Colors.black87),
                      ),
                      onTap: () {
                        Navigator.pop(context);
                        _retryMessage();
                      },
                    ),
                    ListTile(
                      leading: Icon(Icons.share, color: themeService.isDarkMode ? Colors.white : Colors.black87),
                      title: Text(
                        'Paylaş',
                        style: TextStyle(color: themeService.isDarkMode ? Colors.white : Colors.black87),
                      ),
                      onTap: () {
                        Navigator.pop(context);
                        _shareMessage();
                      },
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // Metin seçme
  void _selectText() {
    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (context) {
        final bubbleColor = widget.message.isUser
            ? const Color(0xFF2A2A2A)
            : Theme.of(context).primaryColor;
        final textColor = bubbleColor.computeLuminance() > 0.5
            ? Colors.black87
            : Colors.white;
        return Dialog(
          backgroundColor: const Color(0xFF1A1A1A),
          insetPadding: const EdgeInsets.all(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Metni seç',
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.close,
                        color: Colors.white70,
                        size: 18,
                      ),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 260,
                  child: SingleChildScrollView(
                    child: SelectionArea(
                      child: Text(
                        widget.message.content,
                        style: TextStyle(
                          color: textColor,
                          fontSize: 15,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () {
                        Clipboard.setData(
                          ClipboardData(text: widget.message.content),
                        );
                        GreyNotification.show(context, 'Metin kopyalandı');
                      },
                      child: const Text(
                        'Kopyala',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: () {
                        if (widget.message.content.trim().isEmpty) {
                          GreyNotification.show(
                            context,
                            'Paylaşılacak metin yok',
                          );
                          return;
                        }
                        Share.share(widget.message.content.trim());
                      },
                      child: const Text(
                        'Paylaş',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Mesajı tekrar deneme
  void _retryMessage() {
    if (widget.onRetry != null) {
      widget.onRetry!(widget.message);
    } else {
      GreyNotification.show(
        context,
        'Tekrar deneme özelliği yakında desteklenmiyor',
      );
    }
  }

  // Mesajı paylaşma
  void _shareMessage() {
    if (widget.message.content.trim().isEmpty) {
      GreyNotification.show(context, 'Paylaşılacak metin yok');
      return;
    }
    Share.share(widget.message.content.trim());
  }

  void _onLinkTap(String url) async {
    if (url.startsWith('settings://')) {
      final key = url.substring('settings://'.length);
      widget.onSettingsLinkTapped?.call(key);
      return;
    }
    final normalized = url.trim();
    if (normalized.isEmpty) return;

    // Offline mini oyun: internet yokken can sıkılmasın diye
    if (normalized == 'offlinegame://start' || normalized == 'gamehub://') {
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (context) => const MiniGamesHubScreen()),
      );
      return;
    }

    // Özel Wi-Fi ayar linki: sohbet içi "Ayarlar" butonu
    if (normalized == 'wifi://settings') {
      if (Platform.isAndroid) {
        const intent = AndroidIntent(action: 'android.settings.WIFI_SETTINGS');
        await intent.launch();
      } else {
        GreyNotification.show(
          context,
          'Wi-Fi ayarlarına yalnızca Android cihazlarda yönlendirebiliyorum',
        );
      }
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.link, color: Colors.white70),
                title: const Text(
                  'Bağlantıyı kopyala',
                  style: TextStyle(color: Colors.white),
                ),
                subtitle: Text(
                  normalized,
                  style: const TextStyle(color: Colors.white38, fontSize: 11),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                onTap: () {
                  Navigator.pop(context);
                  Clipboard.setData(ClipboardData(text: normalized));
                  GreyNotification.show(context, 'Bağlantı kopyalandı');
                },
              ),
              ListTile(
                leading: const Icon(Icons.open_in_new, color: Colors.white70),
                title: const Text(
                  'Bağlantıya git',
                  style: TextStyle(color: Colors.white),
                ),
                onTap: () async {
                  Navigator.pop(context);
                  final uri = Uri.tryParse(normalized);
                  if (uri == null || !uri.hasScheme) {
                    GreyNotification.show(context, 'Geçersiz bağlantı');
                    return;
                  }
                  final captured = await Navigator.of(context).push<Uint8List?>(
                    MaterialPageRoute(
                      builder: (context) => ForeWebScreen(url: normalized),
                    ),
                  );
                  if (captured != null && widget.onWebCapture != null) {
                    widget.onWebCapture!(captured);
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

// Mod bazlı yükleme göstergesi: gri yazı + hafif parlayan animasyon + 3 nokta
class _ModeLoadingIndicator extends StatefulWidget {
  final String label;

  const _ModeLoadingIndicator({required this.label});

  @override
  State<_ModeLoadingIndicator> createState() => _ModeLoadingIndicatorState();
}

class _ModeLoadingIndicatorState extends State<_ModeLoadingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 900),
      vsync: this,
    )..repeat(reverse: true);

    _animation = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        final baseColor = Colors.white38;
        final highlightColor = Colors.white;
        final color =
            Color.lerp(baseColor, highlightColor, _animation.value) ??
            baseColor;

        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(widget.label, style: TextStyle(color: color, fontSize: 13)),
            const SizedBox(width: 8),
            _ThinkingDots(),
          ],
        );
      },
    );
  }
}

// Animasyonlu 3 nokta widget'ı
class _ThinkingDots extends StatefulWidget {
  @override
  State<_ThinkingDots> createState() => _ThinkingDotsState();
}

class _ThinkingDotsState extends State<_ThinkingDots>
    with TickerProviderStateMixin {
  late List<AnimationController> _controllers;
  late List<Animation<double>> _animations;

  @override
  void initState() {
    super.initState();

    _controllers = List.generate(3, (index) {
      return AnimationController(
        duration: const Duration(milliseconds: 600),
        vsync: this,
      );
    });

    _animations = _controllers.map((controller) {
      return Tween<double>(
        begin: 0.4,
        end: 1.0,
      ).animate(CurvedAnimation(parent: controller, curve: Curves.easeInOut));
    }).toList();

    // Sıralı animasyon başlat
    _startAnimations();
  }

  void _startAnimations() async {
    while (mounted) {
      for (int i = 0; i < _controllers.length; i++) {
        if (!mounted) break;
        _controllers[i].forward();
        await Future.delayed(const Duration(milliseconds: 150));
      }

      await Future.delayed(const Duration(milliseconds: 200));

      for (int i = 0; i < _controllers.length; i++) {
        if (!mounted) break;
        _controllers[i].reverse();
      }

      await Future.delayed(const Duration(milliseconds: 400));
    }
  }

  @override
  void dispose() {
    for (var controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (index) {
        return AnimatedBuilder(
          animation: _animations[index],
          builder: (context, child) {
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 2),
              child: Opacity(
                opacity: _animations[index].value,
                child: Container(
                  width: 4,
                  height: 4,
                  decoration: BoxDecoration(
                    color: themeService.isDarkMode ? Colors.white60 : Colors.black54,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            );
          },
        );
      }),
    );
  }
}
