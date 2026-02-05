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
import '../services/notification_service.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:markdown/markdown.dart' as md;
import '../models/message.dart';
import '../screens/webview_screen.dart';
import '../screens/mini_games_hub_screen.dart';
import '../services/theme_service.dart';
import 'code_block.dart';
import 'fullscreen_image_viewer.dart';
import 'grey_notification.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'citation_link_builder.dart';
import 'phone_number_panel.dart';
import 'tool_result_box.dart';

// LaTeX Support Classes
class LatexSyntax extends md.InlineSyntax {
  LatexSyntax() : super(r'(\$\$[\s\S]*?\$\$)|(\$[\s\S]*?\$)');

  @override
  bool onMatch(md.InlineParser parser, Match match) {
    final text = match.group(0)!;
    parser.addNode(md.Element('latex', [md.Text(text)]));
    return true;
  }
}

class LatexBuilder extends MarkdownElementBuilder {
  final BuildContext context;
  LatexBuilder(this.context);

  @override
  Widget? visitElementAfter(md.Element element, TextStyle? preferredStyle) {
    final text = element.textContent;
    final isDisplayMode = text.startsWith(r'$$');
    final formula = text.replaceAll(r'$', '').trim();

    try {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: isDisplayMode ? 12 : 0),
        child: Math.tex(
          formula,
          mathStyle: isDisplayMode ? MathStyle.display : MathStyle.text,
          textStyle: preferredStyle?.copyWith(
            fontSize:
                (preferredStyle.fontSize ?? 15) * (isDisplayMode ? 1.1 : 1.0),
          ),
          onErrorFallback: (err) => Text(
            text,
            style: preferredStyle?.copyWith(color: Colors.redAccent),
          ),
        ),
      );
    } catch (e) {
      return Text(text, style: preferredStyle);
    }
  }
}

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
  final void Function(Message message, Map<String, dynamic> toolData)?
  onToolApproval;
  // Audio Params
  final bool isPlayingAudio;
  final bool isAudioLoading;
  final VoidCallback? onPlay;
  final VoidCallback? onStop;
  final ValueNotifier<String>? streamingContent;
  final bool showAudioButton;
  final void Function(
    String code,
    String language,
    String title,
    bool isPreview,
  )?
  onOpenArtifact;

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
    this.onToolApproval,
    this.isPlayingAudio = false,
    this.isAudioLoading = false,
    this.onPlay,
    this.onStop,
    this.streamingContent,
    this.showAudioButton = true,
    this.onOpenArtifact,
  });

  @override
  State<MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<MessageBubble>
    with AutomaticKeepAliveClientMixin {
  final _themeService = ThemeService();
  bool _isLiked = false;
  bool _isDisliked = false;
  bool _sourcesExpanded = false;
  bool _isReasoningExpanded =
      true; // Varsayılan olarak açık başlar (streaming sırasında)
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
    // Initialize notifications and request permissions
    NotificationService().requestPermissions();

    _prepareInlineImage();
  }

  @override
  void didUpdateWidget(covariant MessageBubble oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.message.imageUrl != widget.message.imageUrl) {
      _prepareInlineImage();
    }

    // Streaming bittiğinde (isTyping true -> false) ve reasoning varsa, otomatik kapat
    if (oldWidget.isTyping && !widget.isTyping) {
      final reasoning =
          widget.reasoning ?? widget.message.metadata?['reasoning'];
      if (reasoning != null && reasoning.toString().isNotEmpty) {
        setState(() {
          _isReasoningExpanded = false;
        });
      }
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

  MarkdownStyleSheet _buildMarkdownStyleSheet(BuildContext context) {
    final fontSizes = [13.0, 15.0, 17.0, 19.0, 21.0];
    int index = widget.fontSizeIndex;
    if (index < 0) {
      index = 0;
    } else if (index >= fontSizes.length) {
      index = fontSizes.length - 1;
    }
    final baseSize = fontSizes[index];

    // Choose font family based on sender
    final String? effectiveFontFamily = widget.fontFamily;

    // Mesaj balonu rengine göre akıllı metin rengi (kullanıcı için balon, AI için yüzey)
    final bubbleColor = widget.message.isUser
        ? _getUserBubbleColor(context)
        : Theme.of(context).colorScheme.surface;

    Color textColor;
    if (widget.message.isUser) {
      textColor = bubbleColor.computeLuminance() > 0.5
          ? Colors.black87
          : Colors.white;
    } else {
      textColor = Theme.of(context).brightness == Brightness.dark
          ? Colors.white
          : Colors.black87;
    }

    TextStyle applyFont(TextStyle base, String? family) {
      if (family == null || family.isEmpty) {
        return base;
      }
      switch (family) {
        case 'Inter':
          return GoogleFonts.inter(textStyle: base);
        case 'Roboto':
          return GoogleFonts.roboto(textStyle: base);
        case 'Open Sans':
          return GoogleFonts.openSans(textStyle: base);
        case 'Montserrat':
          return GoogleFonts.montserrat(textStyle: base);
        case 'Poppins':
          return GoogleFonts.poppins(textStyle: base);
        case 'Barlow':
          return GoogleFonts.barlow(textStyle: base);
        case 'Nunito':
          return GoogleFonts.nunito(textStyle: base);
        case 'Rubik':
          return GoogleFonts.rubik(textStyle: base);
        case 'Manrope':
          return GoogleFonts.manrope(textStyle: base);
        case 'Source Sans 3':
        case 'Source Sans Pro':
          return GoogleFonts.sourceSans3(textStyle: base);
        case 'IBM Plex Sans':
          return GoogleFonts.ibmPlexSans(textStyle: base);
        case 'Garet':
          // Garet is not in GoogleFonts, use system fallback or custom if added to pubspec
          return base.copyWith(fontFamily: 'Garet');
        case 'Quicksand':
          return GoogleFonts.quicksand(textStyle: base);
        case 'Mulish':
          return GoogleFonts.mulish(textStyle: base);
        case 'Ubuntu':
          return GoogleFonts.ubuntu(textStyle: base);
        case 'Fira Sans':
          return GoogleFonts.firaSans(textStyle: base);
        case 'Exo 2':
          return GoogleFonts.exo2(textStyle: base);
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
      return applyFont(base, effectiveFontFamily);
    }

    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return MarkdownStyleSheet(
      p: baseStyle(baseSize).copyWith(height: 1.5),
      strong: baseStyle(baseSize, fontWeight: FontWeight.w700),
      em: baseStyle(baseSize, fontStyle: FontStyle.italic),
      listBullet: baseStyle(baseSize),
      h1: baseStyle(
        baseSize + 10,
        fontWeight: FontWeight.bold,
      ).copyWith(height: 2.0),
      h2: baseStyle(
        baseSize + 8,
        fontWeight: FontWeight.bold,
      ).copyWith(height: 1.8),
      h3: baseStyle(
        baseSize + 6,
        fontWeight: FontWeight.bold,
      ).copyWith(height: 1.6),
      blockquote: baseStyle(baseSize).copyWith(
        color: textColor.withOpacity(0.7),
        fontStyle: FontStyle.italic,
        decorationColor: textColor.withOpacity(0.2),
      ),
      blockquoteDecoration: BoxDecoration(
        border: Border(
          left: BorderSide(color: textColor.withOpacity(0.2), width: 4),
        ),
      ),
      code: TextStyle(
        color: isDarkMode ? const Color(0xFFE4E4E4) : const Color(0xFF24292E),
        backgroundColor: isDarkMode
            ? const Color(0xFF2A2A2A)
            : const Color(0xFFF6F8FA),
        fontFamily: 'monospace',
        fontSize: baseSize * 0.9,
      ),
      tableBorder: TableBorder.all(
        color: textColor.withOpacity(0.1),
        width: 1,
        borderRadius: BorderRadius.circular(4),
      ),
      tableCellsPadding: const EdgeInsets.all(8),
      tableColumnWidth: const IntrinsicColumnWidth(),
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
    final bool isDark = _themeService.isDarkMode;
    final Color itemColor = isDark ? Colors.white : Colors.black87;
    final Color iconColor = isDark ? Colors.white70 : Colors.black54;

    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF1A1A1A) : Colors.white,
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
                      color: isDark ? Colors.white24 : Colors.black12,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                ListTile(
                  leading: Icon(Icons.summarize, color: iconColor, size: 20),
                  title: Text(
                    'Kısaca özetle',
                    style: TextStyle(color: itemColor, fontSize: 14),
                  ),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    widget.onQuickAction?.call('summary', widget.message);
                  },
                ),
                if (hasCodeBlock)
                  ListTile(
                    leading: Icon(Icons.code, color: iconColor, size: 20),
                    title: Text(
                      'Kod panelinde aç',
                      style: TextStyle(color: itemColor, fontSize: 14),
                    ),
                    onTap: () {
                      Navigator.of(ctx).pop();
                      widget.onQuickAction?.call('code_panel', widget.message);
                    },
                  ),
                if (isChartCandidate)
                  ListTile(
                    leading: Icon(Icons.bar_chart, color: iconColor, size: 20),
                    title: Text(
                      'Grafiğini Çıkar',
                      style: TextStyle(color: itemColor, fontSize: 14),
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
                  leading: Icon(
                    Icons.format_list_bulleted,
                    color: iconColor,
                    size: 20,
                  ),
                  title: Text(
                    'Madde madde çıkar',
                    style: TextStyle(color: itemColor, fontSize: 14),
                  ),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    widget.onQuickAction?.call('bullets', widget.message);
                  },
                ),
                ListTile(
                  leading: Icon(
                    Icons.arrow_downward,
                    color: iconColor,
                    size: 20,
                  ),
                  title: Text(
                    'Devam et',
                    style: TextStyle(color: itemColor, fontSize: 14),
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

  /// Markdown formatlarını temizleyerek sade metin döndürür
  String _stripMarkdown(String text) {
    String result = text;

    // Kod bloklarını temizle (```lang ... ```)
    result = result.replaceAllMapped(
      RegExp(r'```[\w]*\n?([\s\S]*?)```', multiLine: true),
      (match) => match.group(1)?.trim() ?? '',
    );

    // Inline kod (`...`)
    result = result.replaceAllMapped(
      RegExp(r'`([^`]+)`'),
      (match) => match.group(1) ?? '',
    );

    // Bold (**text** veya __text__)
    result = result.replaceAllMapped(
      RegExp(r'\*\*([^*]+)\*\*'),
      (match) => match.group(1) ?? '',
    );
    result = result.replaceAllMapped(
      RegExp(r'__([^_]+)__'),
      (match) => match.group(1) ?? '',
    );

    // Italic (*text* veya _text_)
    result = result.replaceAllMapped(
      RegExp(r'\*([^*]+)\*'),
      (match) => match.group(1) ?? '',
    );
    result = result.replaceAllMapped(
      RegExp(r'_([^_]+)_'),
      (match) => match.group(1) ?? '',
    );

    // Başlıklar (# ## ### vb.)
    result = result.replaceAllMapped(
      RegExp(r'^#{1,6}\s*(.+)$', multiLine: true),
      (match) => match.group(1) ?? '',
    );

    // Bullet points (- veya *)
    result = result.replaceAllMapped(
      RegExp(r'^[\*\-]\s+', multiLine: true),
      (match) => '• ',
    );

    // Numbered lists
    result = result.replaceAllMapped(
      RegExp(r'^\d+\.\s+', multiLine: true),
      (match) => '',
    );

    // Links [text](url)
    result = result.replaceAllMapped(
      RegExp(r'\[([^\]]+)\]\([^)]+\)'),
      (match) => match.group(1) ?? '',
    );

    return result.trim();
  }

  void _handleCopy() {
    final cleanText = _stripMarkdown(widget.message.content);
    Clipboard.setData(ClipboardData(text: cleanText));
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
                heroTag: imageUrl != null
                    ? 'image_${widget.message.id}_${imageUrl.hashCode}'
                    : 'image_${widget.message.id}',
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
    // Regex explanation:
    // 1. Standard markdown code blocks: ```lang:filename\ncode```
    // 2. Custom ARTIFACT tags: [ARTIFACT title="Title" lang="lang"]\ncode\n[/ARTIFACT]
    final codeBlockRegex = RegExp(
      r'(?:```(\w+)?(?::([\w\.\-]+))?\n([\s\S]*?)```)|(?:\[ARTIFACT(?:\s+title="([^"]*)")?(?:\s+lang="([^"]*)")?\]\s*([\s\S]*?)\[/ARTIFACT\])',
      multiLine: true,
      caseSensitive: false,
      dotAll: true,
    );
    // Telefon numaralarını yakalamak için gelişmiş regex
    // Desteklenen formatlar: 444 850 1234, +90 500 123 45 67, 0555 123 45 67, 0212 555 44 33, 4448501234
    final phoneRegex = RegExp(
      r'(\+?\d{1,4}[\s\-]?)?(444[\s\-]?\d{3}[\s\-]?\d{4}|\d{3}[\s\-]?\d{3}[\s\-]?\d{2}[\s\-]?\d{2}|\d{4}[\s\-]?\d{4}|\d{10,15})',
    );
    // Mesaj balonu rengine göre akıllı metin rengi (kullanıcı için balon, AI için yüzey)
    final colorScheme = Theme.of(context).colorScheme;
    final bubbleColor = widget.message.isUser
        ? _getUserBubbleColor(context)
        : colorScheme.surface;
    // Fix for Light Mode: AI text should be dark on light background
    Color textColor;
    if (widget.message.isUser) {
      // User bubble (Colored/Grey) -> Contrast check
      textColor = bubbleColor.computeLuminance() > 0.5
          ? Colors.black87
          : Colors.white;
    } else {
      // AI bubble (Transparent) -> Use Theme brightness
      textColor = Theme.of(context).brightness == Brightness.dark
          ? Colors.white
          : Colors.black87;
    }
    final styleSheet = _buildMarkdownStyleSheet(context);

    // Telefon numaralarını tespit et ve işaretle
    String processedContent = content.replaceAllMapped(
      RegExp(r'\[SETTINGS_LINK:(.*?)\]'),
      (match) => '[${match.group(1)}](settings://${match.group(1)})',
    );
    final phoneMatches = phoneRegex.allMatches(content).toList();
    final phoneNumbers = <String>[];

    for (final match in phoneMatches.reversed) {
      final rawPhone = match.group(1);
      if (rawPhone == null) continue; // Skip if group is null
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

      if (!inCodeBlock &&
          (phone.length >= 10 && phone.length <= 15 ||
              phone.startsWith('444') && phone.length >= 7)) {
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

      // Add code block
      String rawLanguage;
      String? filename;
      String code;
      bool isArtifact = false;

      if (match.group(6) != null) {
        // Artifact match
        isArtifact = true;
        filename = match.group(4)?.trim(); // Title as filename
        rawLanguage = (match.group(5) ?? '').trim().toLowerCase();
        code = match.group(6) ?? '';
      } else {
        // Standard code block match
        rawLanguage = (match.group(1) ?? '').trim().toLowerCase();
        filename = match.group(2)?.trim();
        code = match.group(3) ?? '';
      }

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
          isArtifact ||
          (rawLanguage.isNotEmpty && codeLanguages.contains(rawLanguage));

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
            onOpenArtifact: widget.onOpenArtifact == null
                ? null
                : (isPreview) => widget.onOpenArtifact?.call(
                    code.trim(),
                    rawLanguage,
                    filename ?? 'Artifact',
                    isPreview,
                  ),
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
              builders: {
                'a': CitationLinkBuilder(
                  context,
                  isUser: widget.message.isUser,
                ),
                'retry': RetryLinkBuilder(context),
                'latex': LatexBuilder(context),
              },
              extensionSet: md.ExtensionSet(
                md.ExtensionSet.gitHubFlavored.blockSyntaxes,
                [
                  ...md.ExtensionSet.gitHubFlavored.inlineSyntaxes,
                  LatexSyntax(),
                ],
              ),
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

    // Citation regex: [1], [2], etc.
    final citationRegex = RegExp(r'\[(\d+)\]');
    // Pre-process text to extract citations and treat them as matches,
    // BUT we need to be careful not to break markdown links [text](url).
    // Simple approach: Iterate again to find standalone [N].

    // We can't easily merge regexes. Let's do a second pass integration or improve the parser.
    // Instead of complex parsing, let's just handle it in the existing loop if we add it.

    // Better strategy: Add citation matches to allMatches list.
    for (final m in citationRegex.allMatches(text)) {
      // Basic check: ensure it's not part of a markdown link like [1](http...)
      // Check if next char is '('
      if (m.end < text.length && text[m.end] == '(') {
        continue;
      }

      allMatches.add({
        'start': m.start,
        'end': m.end,
        'type': 'citation',
        'match': m,
      });
    }

    // Re-sort with new matches
    allMatches.sort((a, b) => a['start'].compareTo(b['start']));

    // Filter overlapping matches (simple strategy: keep first one)
    final filteredMatches = <Map<String, dynamic>>[];
    int currentEnd = 0;
    for (final m in allMatches) {
      if (m['start'] >= currentEnd) {
        filteredMatches.add(m);
        currentEnd = m['end'];
      }
    }

    for (final item in filteredMatches) {
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
              builders: {
                'a': CitationLinkBuilder(
                  context,
                  isUser: widget.message.isUser,
                ),
                'retry': RetryLinkBuilder(context),
                'latex': LatexBuilder(context),
              },
              extensionSet: md.ExtensionSet(
                md.ExtensionSet.gitHubFlavored.blockSyntaxes,
                [
                  ...md.ExtensionSet.gitHubFlavored.inlineSyntaxes,
                  LatexSyntax(),
                ],
              ),
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
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.phone, size: 14, color: Colors.blue),
                  const SizedBox(width: 4),
                  Text(
                    phoneNumber,
                    style: const TextStyle(
                      color: Colors.blue,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      } else if (type == 'citation') {
        final citationNumber = match.group(1)!;
        final sources = widget.message.metadata?['sources'] as List?;
        String? sourceUrl;
        if (sources != null && sources.isNotEmpty) {
          try {
            final index = int.parse(citationNumber) - 1;
            if (index >= 0 && index < sources.length) {
              final source = sources[index];
              if (source is Map)
                sourceUrl = source['url'];
              else if (source is String)
                sourceUrl = source;
            }
          } catch (_) {}
        }

        parts.add(
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Transform.translate(
              offset: const Offset(0, -4), // Superscript effect
              child: GestureDetector(
                onTap: sourceUrl != null ? () => _onLinkTap(sourceUrl!) : null,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: (styleSheet.p?.color ?? Colors.grey).withOpacity(
                      0.1,
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: FaIcon(
                    FontAwesomeIcons.link,
                    size: 9, // "baya küçük"
                    color: (styleSheet.p?.color ?? Colors.grey).withOpacity(
                      0.5,
                    ), // "opaklığı düşük"
                  ),
                ),
              ),
            ),
          ),
        );
        lastIndex = end;
      } else if (type == 'pdf') {
        final rawPdfNames = match.group(1)!;
        final pdfNames = rawPdfNames.split(', ').map((s) => s.trim()).toList();
        final isDarkMode = Theme.of(context).brightness == Brightness.dark;

        for (var pdfName in pdfNames) {
          parts.add(
            Container(
              margin: const EdgeInsets.symmetric(vertical: 6),
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isDarkMode
                      ? [
                          Colors.white.withOpacity(0.12),
                          Colors.white.withOpacity(0.04),
                        ]
                      : [
                          _getUserBubbleColor(context).withOpacity(0.2),
                          _getUserBubbleColor(context).withOpacity(0.1),
                        ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDarkMode
                      ? Colors.white.withOpacity(0.1)
                      : Colors.black.withOpacity(0.05),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
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
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.redAccent.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const FaIcon(
                            FontAwesomeIcons.filePdf,
                            color: Colors.redAccent,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                pdfName,
                                style: TextStyle(
                                  color: isDarkMode
                                      ? Colors.white
                                      : Colors.black87,
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.1,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  Text(
                                    'PDF Belgesi',
                                    style: TextStyle(
                                      color: isDarkMode
                                          ? Colors.white.withOpacity(0.5)
                                          : Colors.black54,
                                      fontSize: 10,
                                    ),
                                  ),
                                  Container(
                                    width: 3,
                                    height: 3,
                                    margin: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isDarkMode
                                          ? Colors.white24
                                          : Colors.black12,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  Text(
                                    'Görüntüle',
                                    style: TextStyle(
                                      color: isDarkMode
                                          ? Colors.blueAccent.shade100
                                          : Colors.blueAccent,
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
                          color: isDarkMode
                              ? Colors.white.withOpacity(0.2)
                              : Colors.black26,
                          size: 18,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        }
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
            builders: {
              'a': CitationLinkBuilder(context, isUser: widget.message.isUser),
              'retry': RetryLinkBuilder(context),
              'latex': LatexBuilder(context),
            },
            extensionSet: md.ExtensionSet(
              md.ExtensionSet.gitHubFlavored.blockSyntaxes,
              [...md.ExtensionSet.gitHubFlavored.inlineSyntaxes, LatexSyntax()],
            ),
            softLineBreak: true,
            onTapLink: (t, href, title) => _onLinkTap(href ?? t),
          ),
        );
      }
    }

    if (parts.isEmpty) {
      return MarkdownBody(
        data: text,
        styleSheet: styleSheet,
        builders: {
          'a': CitationLinkBuilder(context, isUser: widget.message.isUser),
          'retry': RetryLinkBuilder(context),
          'latex': LatexBuilder(context),
        },
        extensionSet: md.ExtensionSet(
          md.ExtensionSet.gitHubFlavored.blockSyntaxes,
          [...md.ExtensionSet.gitHubFlavored.inlineSyntaxes, LatexSyntax()],
        ),
        softLineBreak: true,
        onTapLink: (t, href, title) => _onLinkTap(href ?? t),
      );
    }

    return Wrap(
      alignment: widget.message.isUser
          ? WrapAlignment.end
          : WrapAlignment.start,
      crossAxisAlignment: WrapCrossAlignment.center,
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
    // Use message.imageUrls directly (populated from ChatScreen)
    // Also check metadata as fallback for older messages
    final directImageUrls = widget.message.imageUrls;
    final metadataImageUrls =
        widget.message.metadata?['imageUrls'] as List<dynamic>?;
    final singleImageUrl = widget.message.imageUrl;

    // Priority: direct imageUrls > metadata imageUrls > single imageUrl
    List<String> allImageUrls;
    if (directImageUrls != null && directImageUrls.isNotEmpty) {
      allImageUrls = directImageUrls;
    } else if (metadataImageUrls != null && metadataImageUrls.isNotEmpty) {
      allImageUrls = metadataImageUrls.map((e) => e.toString()).toList();
    } else if (singleImageUrl != null) {
      allImageUrls = [singleImageUrl];
    } else {
      allImageUrls = [];
    }

    if (allImageUrls.isEmpty) {
      return const SizedBox.shrink();
    }

    // Görsel sayısına göre layout belirle
    if (allImageUrls.length == 1) {
      // 1 görsel: normal göster
      return _buildSingleImage(allImageUrls.first);
    } else if (allImageUrls.length == 2) {
      // 2 görsel: yan yana
      return _buildTwoImages(allImageUrls.cast<String>());
    } else if (allImageUrls.length >= 3) {
      // 3+ görsel: üstte 1, altta 2
      return _buildThreeImages(allImageUrls.take(3).cast<String>().toList());
    }

    return const SizedBox.shrink();
  }

  Widget _buildToolSection() {
    final toolData =
        widget.message.metadata?['toolCall'] as Map<String, dynamic>?;
    if (toolData == null) return const SizedBox.shrink();

    final status = toolData['status'] ?? 'loading';
    final title = toolData['title'] ?? 'İşlem yürütülüyor';
    final subtitle = toolData['subtitle'];
    final added = toolData['added'] ?? 0;
    final removed = toolData['removed'] ?? 0;
    final showApprove = toolData['showApprove'] ?? false;

    return ToolResultBox(
      title: title,
      subtitle: subtitle,
      addedLines: added,
      removedLines: removed,
      isLoading: status == 'loading',
      onApprove: (showApprove && widget.onToolApproval != null)
          ? () => widget.onToolApproval!(widget.message, toolData)
          : null,
      onShare: () {
        Share.share('${widget.message.content}\n\n$title');
      },
      onTap: () {
        // AI'nın taslağına gitme/bakma işlemi
      },
    );
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
          Expanded(child: _buildImageContainer(imageUrls[0], 0)),
          const SizedBox(width: 4),
          Expanded(child: _buildImageContainer(imageUrls[1], 1)),
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
              Expanded(child: _buildImageContainer(imageUrls[1], 1)),
              const SizedBox(width: 4),
              Expanded(child: _buildImageContainer(imageUrls[2], 2)),
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
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
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
                          constraints: BoxConstraints(
                            maxWidth: MediaQuery.of(context).size.width * 0.8,
                          ),
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
                              else if ((widget.isTyping &&
                                      widget.message.content ==
                                          'Görsel oluşturuluyor...') ||
                                  (widget
                                              .message
                                              .metadata?['isGeneratingImage'] ==
                                          true &&
                                      widget.message.imageUrl == null))
                                _buildImageSkeleton()
                              else if (!widget.isTyping &&
                                  widget.message.content.isEmpty &&
                                  widget.message.imageUrl != null &&
                                  !widget.message.isUser)
                                const SizedBox(height: 4)
                              else ...[
                                // Reasoning (Inline Log Style)
                                if (!widget.message.isUser)
                                  Builder(
                                    builder: (context) {
                                      final reasoning =
                                          widget.reasoning ??
                                          widget.message.metadata?['reasoning'];
                                      if (reasoning is String &&
                                          (reasoning.isNotEmpty ||
                                              widget.isTyping)) {
                                        final isDark =
                                            Theme.of(context).brightness ==
                                            Brightness.dark;
                                        final lines = reasoning.split('\n');

                                        return AnimatedSize(
                                          duration: const Duration(
                                            milliseconds: 300,
                                          ),
                                          alignment: Alignment.topCenter,
                                          curve: Curves.easeInOut,
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              // Header / Status
                                              GestureDetector(
                                                onTap: () {
                                                  setState(() {
                                                    _isReasoningExpanded =
                                                        !_isReasoningExpanded;
                                                  });
                                                },
                                                behavior:
                                                    HitTestBehavior.opaque,
                                                child: Padding(
                                                  padding:
                                                      const EdgeInsets.only(
                                                        bottom: 8,
                                                        top: 4,
                                                      ),
                                                  child: Container(
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 10,
                                                          vertical: 6,
                                                        ),
                                                    decoration: BoxDecoration(
                                                      color: isDark
                                                          ? Colors.white
                                                                .withOpacity(
                                                                  0.03,
                                                                )
                                                          : Colors.black
                                                                .withOpacity(
                                                                  0.02,
                                                                ),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            8,
                                                          ),
                                                      border: Border.all(
                                                        color: isDark
                                                            ? Colors.white
                                                                  .withOpacity(
                                                                    0.05,
                                                                  )
                                                            : Colors.black
                                                                  .withOpacity(
                                                                    0.05,
                                                                  ),
                                                      ),
                                                    ),
                                                    child: Row(
                                                      mainAxisSize:
                                                          MainAxisSize.min,
                                                      children: [
                                                        Container(
                                                          width: 8,
                                                          height: 8,
                                                          decoration: BoxDecoration(
                                                            color:
                                                                widget.isTyping
                                                                ? Colors
                                                                      .blueAccent
                                                                : Colors.grey,
                                                            shape:
                                                                BoxShape.circle,
                                                          ),
                                                        ),
                                                        const SizedBox(
                                                          width: 8,
                                                        ),
                                                        Text(
                                                          _isReasoningExpanded
                                                              ? (widget.isTyping
                                                                    ? 'Analiz ediliyor...'
                                                                    : 'Düşünce Süreci')
                                                              : 'Düşünceyi göster',
                                                          style: TextStyle(
                                                            fontSize: 12,
                                                            fontWeight:
                                                                FontWeight.w600,
                                                            color: isDark
                                                                ? Colors.white54
                                                                : Colors
                                                                      .black54,
                                                          ),
                                                        ),
                                                        const SizedBox(
                                                          width: 4,
                                                        ),
                                                        Icon(
                                                          _isReasoningExpanded
                                                              ? Icons
                                                                    .keyboard_arrow_up
                                                              : Icons
                                                                    .keyboard_arrow_down,
                                                          size: 16,
                                                          color: isDark
                                                              ? Colors.white38
                                                              : Colors.black38,
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                              ),

                                              // Expanded Content (Log View)
                                              if (_isReasoningExpanded)
                                                Padding(
                                                  padding:
                                                      const EdgeInsets.only(
                                                        bottom: 8,
                                                      ),
                                                  child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      // Start marker
                                                      Text(
                                                        '● Düşünme süreci...',
                                                        style: TextStyle(
                                                          fontSize: 11,
                                                          color:
                                                              Colors.grey[500],
                                                          height: 1.2,
                                                        ),
                                                      ),
                                                      const SizedBox(height: 2),
                                                      // Log Lines with Vertical Bar
                                                      Container(
                                                        margin:
                                                            const EdgeInsets.only(
                                                              left: 4,
                                                            ),
                                                        padding:
                                                            const EdgeInsets.only(
                                                              left: 8,
                                                            ),
                                                        decoration: BoxDecoration(
                                                          border: Border(
                                                            left: BorderSide(
                                                              color: isDark
                                                                  ? Colors
                                                                        .grey[800]!
                                                                  : Colors
                                                                        .grey[300]!,
                                                              width: 1.5,
                                                            ),
                                                          ),
                                                        ),
                                                        child: Column(
                                                          crossAxisAlignment:
                                                              CrossAxisAlignment
                                                                  .start,
                                                          children: lines.map((
                                                            line,
                                                          ) {
                                                            if (line
                                                                .trim()
                                                                .isEmpty)
                                                              return const SizedBox.shrink();
                                                            return Padding(
                                                              padding:
                                                                  const EdgeInsets.only(
                                                                    bottom: 2,
                                                                  ),
                                                              child: Text(
                                                                line,
                                                                style: TextStyle(
                                                                  fontFamily:
                                                                      'monospace',
                                                                  fontSize: 11,
                                                                  color: isDark
                                                                      ? Colors
                                                                            .grey[500]
                                                                      : Colors
                                                                            .grey[700],
                                                                  height: 1.3,
                                                                ),
                                                              ),
                                                            );
                                                          }).toList(),
                                                        ),
                                                      ),
                                                      const SizedBox(height: 2),
                                                      // End marker (only if finished)
                                                      if (!widget.isTyping)
                                                        Text(
                                                          '● Süreç bitti',
                                                          style: TextStyle(
                                                            fontSize: 11,
                                                            color: Colors
                                                                .grey[500],
                                                            height: 1.2,
                                                          ),
                                                        ),
                                                    ],
                                                  ),
                                                ),
                                            ],
                                          ),
                                        );
                                      }
                                      return const SizedBox.shrink();
                                    },
                                  ),
                                if (widget.message.metadata?['toolCall'] !=
                                    null)
                                  _buildToolSection(),
                                ..._buildSelectableMessageContent(),
                              ],
                            ],
                          ),
                        ),
                        // Alt butonlar ve timestamp (Görsel oluşturuluyorsa gizle)
                        if (!((widget.isTyping &&
                                widget.message.content ==
                                    'Görsel oluşturuluyor...') ||
                            (widget.message.metadata?['isGeneratingImage'] ==
                                    true &&
                                widget.message.imageUrl == null))) ...[
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
                                  child: const Text(
                                    'Durduruldu',
                                    style: TextStyle(
                                      color: Color.fromARGB(255, 78, 76, 76),
                                      fontSize: 9,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                              const SizedBox(width: 8),
                              // Alternative answer switcher - Always visible if alternatives exist
                              if (!widget.message.isUser &&
                                  widget.message.alternatives != null &&
                                  widget.message.alternatives!.length > 1) ...[
                                _buildAlternativeSwitcher(),
                                const SizedBox(width: 8),
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
                                        color: themeService.isDarkMode
                                            ? Colors.white54
                                            : Colors.black54,
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
                          if (!widget.message.isUser &&
                              _hasSearchResults()) ...[
                            const SizedBox(height: 8),
                            _buildSearchSources(),
                          ],
                        ], // Closes the 'if !generating' block
                      ], // Closes the children list
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
    // Flag background should be transparent or adaptive
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return CircleAvatar(
      radius: 14,
      backgroundColor: isDark
          ? const Color(0xFF111827)
          : Colors.transparent, // Fix for light mode
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
        // AI Avatarı: Kullanıcı isteği üzerine kaldırıldı
        return const SizedBox.shrink();
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

  Widget _buildImageSkeleton() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(bottom: 8.0, left: 4),
          child: Row(
            children: [
              SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                ),
              ),
              SizedBox(width: 8),
              Text(
                'Görsel oluşturuluyor...',
                style: TextStyle(
                  color: Colors.blue,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        const ShimmerSkeleton(width: 250, height: 250, radius: 12),
      ],
    );
  }

  List<Widget> _buildSelectableMessageContent() {
    if (widget.isTyping && widget.streamingContent != null) {
      return [
        ValueListenableBuilder<String>(
          valueListenable: widget.streamingContent!,
          builder: (context, streamingMsg, _) {
            final contentToShow = streamingMsg.isEmpty ? ' ' : streamingMsg;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: _parseMessageContent(contentToShow),
            );
          },
        ),
      ];
    }
    return _parseMessageContent(widget.message.content);
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
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Kaynaklar:',
                style: TextStyle(
                  color: themeService.isDarkMode
                      ? Colors.white60
                      : Colors.black54,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 8),
              Row(
                mainAxisSize: MainAxisSize.min,
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
              const SizedBox(width: 8),
              Icon(
                _sourcesExpanded
                    ? Icons.keyboard_arrow_up
                    : Icons.keyboard_arrow_down,
                color: themeService.isDarkMode
                    ? Colors.white54
                    : Colors.black54,
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
                    itemCount: results.length > 3 ? 3 : results.length,
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
                              color: themeService.isDarkMode
                                  ? const Color(0xFF101010)
                                  : Colors.grey.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: themeService.isDarkMode
                                    ? Colors.white10
                                    : Colors.black12,
                              ),
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
                                            color: themeService.isDarkMode
                                                ? Colors.white
                                                : Colors.black87,
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
                                              color: themeService.isDarkMode
                                                  ? Colors.blueAccent
                                                  : Colors.blue,
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
                                              color: themeService.isDarkMode
                                                  ? Colors.white60
                                                  : Colors.black54,
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
    if (label == 'thinking' || label == null) {
      // "Düşünüyor..." yerine yanıp sönen/küçülüp büyüyen cursor
      return const PulseCursorIndicator();
    }
    return GestureDetector(
      onTap: widget.onShowReasoning,
      child: _ModeLoadingIndicator(label: label),
    );
  }

  String? _extractLoadingLabel(String? loadingMessage) {
    if (loadingMessage == null) return null;
    if (loadingMessage == 'thinking') return 'thinking';
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
      return 'thinking';
    }
    return null;
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
              _isLiked
                  ? FontAwesomeIcons.solidThumbsUp
                  : FontAwesomeIcons.thumbsUp,
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
              _isDisliked
                  ? FontAwesomeIcons.solidThumbsDown
                  : FontAwesomeIcons.thumbsDown,
              color: _isDisliked ? Colors.red : Colors.grey[400],
              size: 14,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAlternativeSwitcher() {
    final alternatives = widget.message.alternatives ?? [];
    final currentIndex = widget.message.displayAlternativeIndex;
    final isDark = _themeService.isDarkMode;

    return Container(
      color: Colors.transparent,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Left arrow
          GestureDetector(
            behavior: HitTestBehavior.translucent, // Hitbox improvement
            onTap: currentIndex > 0
                ? () => widget.onAlternativeSelected?.call(
                    widget.message,
                    currentIndex - 1,
                  )
                : null,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 6,
              ), // Hitbox padding
              child: Icon(
                Icons.chevron_left,
                size: 22, // Larger icon
                color: currentIndex > 0
                    ? (isDark ? Colors.white70 : Colors.black54)
                    : Colors.transparent,
              ),
            ),
          ),
          // No SizedBox needed due to padding
          // Current index display
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              '${currentIndex + 1}',
              style: TextStyle(
                fontSize: 14, // Larger text
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white70 : Colors.black54,
              ),
            ),
          ),
          // Right arrow
          GestureDetector(
            behavior: HitTestBehavior.translucent, // Hitbox improvement
            onTap: currentIndex < alternatives.length - 1
                ? () => widget.onAlternativeSelected?.call(
                    widget.message,
                    currentIndex + 1,
                  )
                : null,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 6,
              ), // Hitbox padding
              child: Icon(
                Icons.chevron_right,
                size: 22, // Larger icon
                color: currentIndex < alternatives.length - 1
                    ? (isDark ? Colors.white70 : Colors.black54)
                    : Colors.transparent,
              ),
            ),
          ),
        ],
      ),
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
              color: themeService.isDarkMode
                  ? Colors.grey[800]
                  : Colors.grey[700],
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
      backgroundColor: themeService.isDarkMode
          ? const Color(0xFF1A1A1A)
          : Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        final isImageOnly =
            widget.message.imageUrl != null &&
            widget.message.content.trim().isEmpty;
        final isGeneratingImage =
            widget.isTyping &&
            widget.message.content == 'Görsel oluşturuluyor...';
        final hideTextActions = isImageOnly || isGeneratingImage;

        return SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    leading: Icon(
                      Icons.copy,
                      color: themeService.isDarkMode
                          ? Colors.white
                          : Colors.black87,
                    ),
                    title: Text(
                      'Kopyala',
                      style: TextStyle(
                        color: themeService.isDarkMode
                            ? Colors.white
                            : Colors.black87,
                      ),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      _copyToClipboard();
                    },
                  ),
                  if (!widget.message.isUser && !hideTextActions)
                    ListTile(
                      leading: Icon(
                        Icons.volume_up,
                        color: themeService.isDarkMode
                            ? Colors.white
                            : Colors.black87,
                      ),
                      title: Text(
                        'Sesli Oku',
                        style: TextStyle(
                          color: themeService.isDarkMode
                              ? Colors.white
                              : Colors.black87,
                        ),
                      ),
                      onTap: () {
                        Navigator.pop(context);
                        widget.onPlay?.call();
                      },
                    ),
                  if (!hideTextActions)
                    ListTile(
                      leading: Icon(
                        Icons.text_fields,
                        color: themeService.isDarkMode
                            ? Colors.white
                            : Colors.black87,
                      ),
                      title: Text(
                        'Metin Seç',
                        style: TextStyle(
                          color: themeService.isDarkMode
                              ? Colors.white
                              : Colors.black87,
                        ),
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
                        color: themeService.isDarkMode
                            ? Colors.white
                            : Colors.black87,
                      ),
                      title: Text(
                        widget.isPinned ? 'Sabitten kaldır' : 'Mesajı sabitle',
                        style: TextStyle(
                          color: themeService.isDarkMode
                              ? Colors.white
                              : Colors.black87,
                        ),
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
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Text(
                          'Çevir',
                          style: TextStyle(
                            color: themeService.isDarkMode
                                ? Colors.white70
                                : Colors.black54,
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
                        style: TextStyle(
                          color: themeService.isDarkMode
                              ? Colors.white
                              : Colors.black87,
                        ),
                      ),
                      onTap: () =>
                          _runTranslateQuickAction(context, 'translate_tr'),
                    ),
                    ListTile(
                      leading: _buildLangFlag('🇬🇧'),
                      title: Text(
                        'İngilizce (EN)',
                        style: TextStyle(
                          color: themeService.isDarkMode
                              ? Colors.white
                              : Colors.black87,
                        ),
                      ),
                      onTap: () =>
                          _runTranslateQuickAction(context, 'translate_en'),
                    ),
                    ListTile(
                      leading: _buildLangFlag('🇩🇪'),
                      title: Text(
                        'Almanca (DE)',
                        style: TextStyle(
                          color: themeService.isDarkMode
                              ? Colors.white
                              : Colors.black87,
                        ),
                      ),
                      onTap: () =>
                          _runTranslateQuickAction(context, 'translate_de'),
                    ),
                    ListTile(
                      leading: _buildLangFlag('🇫🇷'),
                      title: Text(
                        'Fransızca (FR)',
                        style: TextStyle(
                          color: themeService.isDarkMode
                              ? Colors.white
                              : Colors.black87,
                        ),
                      ),
                      onTap: () =>
                          _runTranslateQuickAction(context, 'translate_fr'),
                    ),
                    ListTile(
                      leading: _buildLangFlag('🇪🇸'),
                      title: Text(
                        'İspanyolca (ES)',
                        style: TextStyle(
                          color: themeService.isDarkMode
                              ? Colors.white
                              : Colors.black87,
                        ),
                      ),
                      onTap: () =>
                          _runTranslateQuickAction(context, 'translate_es'),
                    ),
                    ListTile(
                      leading: _buildLangFlag('🇮🇹'),
                      title: Text(
                        'İtalyanca (IT)',
                        style: TextStyle(
                          color: themeService.isDarkMode
                              ? Colors.white
                              : Colors.black87,
                        ),
                      ),
                      onTap: () =>
                          _runTranslateQuickAction(context, 'translate_it'),
                    ),
                    ListTile(
                      leading: _buildLangFlag('🇷🇺'),
                      title: Text(
                        'Rusça (RU)',
                        style: TextStyle(
                          color: themeService.isDarkMode
                              ? Colors.white
                              : Colors.black87,
                        ),
                      ),
                      onTap: () =>
                          _runTranslateQuickAction(context, 'translate_ru'),
                    ),
                    ListTile(
                      leading: _buildLangFlag('🇸🇦'),
                      title: Text(
                        'Arapça (AR)',
                        style: TextStyle(
                          color: themeService.isDarkMode
                              ? Colors.white
                              : Colors.black87,
                        ),
                      ),
                      onTap: () =>
                          _runTranslateQuickAction(context, 'translate_ar'),
                    ),
                    ListTile(
                      leading: _buildLangFlag('🇯🇵'),
                      title: Text(
                        'Japonca (JA)',
                        style: TextStyle(
                          color: themeService.isDarkMode
                              ? Colors.white
                              : Colors.black87,
                        ),
                      ),
                      onTap: () =>
                          _runTranslateQuickAction(context, 'translate_ja'),
                    ),
                    ListTile(
                      leading: _buildLangFlag('🇨🇳'),
                      title: Text(
                        'Çince (ZH)',
                        style: TextStyle(
                          color: themeService.isDarkMode
                              ? Colors.white
                              : Colors.black87,
                        ),
                      ),
                      onTap: () =>
                          _runTranslateQuickAction(context, 'translate_zh'),
                    ),
                  ],
                  if (!widget.message.isUser && widget.isLastAiMessage) ...[
                    ListTile(
                      leading: Icon(
                        Icons.refresh,
                        color: themeService.isDarkMode
                            ? Colors.white
                            : Colors.black87,
                      ),
                      title: Text(
                        'Tekrar Dene',
                        style: TextStyle(
                          color: themeService.isDarkMode
                              ? Colors.white
                              : Colors.black87,
                        ),
                      ),
                      onTap: () {
                        Navigator.pop(context);
                        _retryMessage();
                      },
                    ),
                  ],
                  // Paylaş butonu TÜM AI mesajlarında görünsün
                  if (!widget.message.isUser) ...[
                    ListTile(
                      leading: Icon(
                        Icons.share,
                        color: themeService.isDarkMode
                            ? Colors.white
                            : Colors.black87,
                      ),
                      title: Text(
                        'Paylaş',
                        style: TextStyle(
                          color: themeService.isDarkMode
                              ? Colors.white
                              : Colors.black87,
                        ),
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
    final isDark = themeService.isDarkMode;
    showDialog(
      context: context,
      barrierColor: isDark ? Colors.black87 : Colors.black54,
      builder: (context) {
        return Dialog(
          backgroundColor: isDark ? const Color(0xFF1A1A1A) : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          insetPadding: const EdgeInsets.all(16),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Metni seç',
                      style: TextStyle(
                        color: isDark ? Colors.white : Colors.black87,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.close,
                        color: isDark ? Colors.white70 : Colors.black54,
                        size: 20,
                      ),
                      onPressed: () => Navigator.pop(context),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  height:
                      MediaQuery.of(context).size.height *
                      0.5, // Daha büyük yapıldı
                  constraints: const BoxConstraints(minHeight: 200),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.black26 : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(16), // Daha yuvarlak
                    border: Border.all(
                      color: isDark ? Colors.white10 : Colors.black12,
                    ),
                  ),
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: SelectionArea(
                      child: Text(
                        widget.message.content,
                        style: TextStyle(
                          color: isDark ? Colors.white : Colors.black87,
                          fontSize: 16, // Biraz daha büyük
                          height: 1.6,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton.icon(
                      onPressed: () {
                        Clipboard.setData(
                          ClipboardData(text: widget.message.content),
                        );
                        GreyNotification.show(context, 'Metin kopyalandı');
                        Navigator.pop(context);
                      },
                      icon: Icon(
                        Icons.copy,
                        size: 16,
                        color: isDark ? Colors.white70 : Colors.blue,
                      ),
                      label: Text(
                        'Kopyala',
                        style: TextStyle(
                          color: isDark ? Colors.white : Colors.blue,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: () {
                        if (widget.message.content.trim().isEmpty) {
                          GreyNotification.show(
                            context,
                            'Paylaşılacak metin yok',
                          );
                          return;
                        }
                        Share.share(widget.message.content.trim());
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueAccent,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: const Icon(Icons.share, size: 16),
                      label: const Text('Paylaş'),
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

    // Retry özelliğini tetikle
    if (normalized == 'retry://last_action') {
      _retryMessage();
      return;
    }

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
        // Tema bazlı renk seçimi
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final baseColor = isDark ? Colors.white38 : Colors.black38;
        final highlightColor = isDark ? Colors.white : Colors.black;
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

class PulseCursorIndicator extends StatefulWidget {
  const PulseCursorIndicator({super.key});

  @override
  State<PulseCursorIndicator> createState() => _PulseCursorIndicatorState();
}

class _PulseCursorIndicatorState extends State<PulseCursorIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.1,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

    _opacityAnimation = Tween<double>(
      begin: 0.4,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Opacity(
          opacity: _opacityAnimation.value,
          child: Transform.scale(
            scale: _scaleAnimation.value,
            child: Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: isDark ? Colors.white70 : Colors.black54,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: (isDark ? Colors.white : Colors.black).withOpacity(
                      0.2,
                    ),
                    blurRadius: 4,
                    spreadRadius: 1,
                  ),
                ],
              ),
            ),
          ),
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
                    color: themeService.isDarkMode
                        ? Colors.white60
                        : Colors.black54,
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

class ShimmerSkeleton extends StatefulWidget {
  final double width;
  final double height;
  final double radius;

  const ShimmerSkeleton({
    Key? key,
    required this.width,
    required this.height,
    this.radius = 12,
  }) : super(key: key);

  @override
  State<ShimmerSkeleton> createState() => _ShimmerSkeletonState();
}

class _ShimmerSkeletonState extends State<ShimmerSkeleton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Premium renk paleti
    final baseColor = isDark
        ? const Color(0xFF1F2937) // Koyu gri (Slate-800)
        : const Color(0xFFE5E7EB); // Açık gri (Gray-200)

    final highlightColor = isDark
        ? const Color(0xFF374151) // Daha açık koyu gri (Slate-700)
        : const Color(0xFFF3F4F6); // Neredeyse beyaz (Gray-100)

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.radius),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [baseColor, highlightColor, baseColor],
              stops: [
                0.0,
                // Animasyonlu geçiş
                (_controller.value - 0.2).clamp(0.0, 1.0),
                (_controller.value + 0.2).clamp(0.0, 1.0),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(widget.radius),
              border: Border.all(
                color: Colors.white.withOpacity(0.05),
                width: 1,
              ),
            ),
          ),
        );
      },
    );
  }
}

class RetryLinkBuilder extends MarkdownElementBuilder {
  final BuildContext context;

  RetryLinkBuilder(this.context);

  @override
  Widget? visitElementAfter(md.Element element, TextStyle? preferredStyle) {
    final href = element.attributes['href'];
    if (href != null && href.startsWith('retry://')) {
      return Container(
        margin: const EdgeInsets.only(top: 8),
        child: IgnorePointer(
          ignoring: true, // Let MarkdownBody handle the tap via onTapLink
          child: ElevatedButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text('Tekrar Dene'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
          ),
        ),
      );
    }
    return null;
  }
}
