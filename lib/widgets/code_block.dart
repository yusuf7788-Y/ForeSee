import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_highlight/flutter_highlight.dart';
import 'package:flutter_highlight/themes/monokai-sublime.dart';
import 'package:flutter_highlight/themes/github.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'grey_notification.dart';

class CodeBlock extends StatelessWidget {
  final String code;
  final String language;
  final int? cbIndex;
  final VoidCallback? onOpenInPanel;
  final void Function(String)? onGenerateReference;
  final String? filename;
  final void Function(bool isPreview)? onOpenArtifact;

  const CodeBlock({
    super.key,
    required this.code,
    required this.language,
    this.cbIndex,
    this.onOpenInPanel,
    this.onGenerateReference,
    this.filename,
    this.onOpenArtifact,
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
    };
    return languageMap[language.toLowerCase()] ?? language.toUpperCase();
  }

  void _copyToClipboard(BuildContext context) {
    Clipboard.setData(ClipboardData(text: code));
    GreyNotification.show(context, 'Kod panoya kopyalandı');
  }

  String _getFileExtension() {
    final Map<String, String> extensionMap = {
      // Common & Modern
      'dart': 'dart',
      'python': 'py',
      'py': 'py',
      'javascript': 'js',
      'js': 'js',
      'typescript': 'ts',
      'ts': 'ts',
      'jsx': 'jsx',
      'tsx': 'tsx',
      'vue': 'vue',
      'svelte': 'svelte',

      // Backend & Systems
      'java': 'java',
      'kotlin': 'kt',
      'kt': 'kt',
      'swift': 'swift',
      'objectivec': 'm',
      'obj-c': 'm',
      'cpp': 'cpp',
      'c++': 'cpp',
      'cc': 'cc',
      'c': 'c',
      'h': 'h',
      'hpp': 'hpp',
      'csharp': 'cs',
      'cs': 'cs',
      'go': 'go',
      'golang': 'go',
      'rust': 'rs',
      'rs': 'rs',
      'php': 'php',
      'ruby': 'rb',
      'rb': 'rb',
      'perl': 'pl',
      'r': 'r',
      'lua': 'lua',
      'scala': 'scala',
      'elixir': 'ex',
      'erlang': 'erl',
      'haskell': 'hs',
      'clojure': 'clj',

      // Web & Data
      'html': 'html',
      'htm': 'html',
      'css': 'css',
      'scss': 'scss',
      'sass': 'sass',
      'less': 'less',
      'sql': 'sql',
      'json': 'json',
      'xml': 'xml',
      'yaml': 'yml',
      'yml': 'yml',
      'markdown': 'md',
      'md': 'md',
      'latex': 'tex',
      'tex': 'tex',

      // Shell & Config
      'bash': 'sh',
      'sh': 'sh',
      'powershell': 'ps1',
      'ps1': 'ps1',
      'batch': 'bat',
      'bat': 'bat',
      'dockerfile': 'dockerfile',
      'docker': 'dockerfile',
      'makefile': 'make',
      'cmake': 'cmake',
      'ini': 'ini',
      'toml': 'toml',

      // Hardware & Others
      'arduino': 'ino',
      'ino': 'ino',
      'vhdl': 'vhd',
      'verilog': 'v',
      'dart_dev': 'dart',
      'plain': 'txt',
      'text': 'txt',
      'txt': 'txt',
    };
    return extensionMap[language.toLowerCase().trim()] ?? 'txt';
  }

  Future<void> _downloadCode(BuildContext context) async {
    try {
      Directory? directory;
      if (Platform.isAndroid) {
        directory = Directory('/storage/emulated/0/Download');
        if (!await directory.exists()) {
          directory = await getExternalStorageDirectory();
        }
      } else {
        directory = await getDownloadsDirectory();
      }

      if (directory == null) {
        GreyNotification.show(context, 'İndirme klasörüne ulaşılamadı');
        return;
      }

      final ext = _getFileExtension();
      String name =
          filename ?? 'snippet_${DateTime.now().millisecondsSinceEpoch}.$ext';

      // Ensure extension is correct if filename is provided
      if (filename != null && !filename!.contains('.')) {
        name = '$filename.$ext';
      }

      final filePath = '${directory.path}/$name';
      final file = File(filePath);
      await file.writeAsString(code);

      GreyNotification.show(context, 'Dosya kaydedildi: $name');
    } catch (e) {
      // Fallback for Android if specific download dir fails
      try {
        final directory = await getExternalStorageDirectory();
        if (directory != null) {
          final ext = _getFileExtension();
          final name =
              filename ??
              'snippet_${DateTime.now().millisecondsSinceEpoch}.$ext';
          final file = File('${directory.path}/$name');
          await file.writeAsString(code);
          GreyNotification.show(context, 'Dosya kaydedildi (External): $name');
          return;
        }
      } catch (_) {}
      GreyNotification.show(context, 'Hata: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final lineCount = '\n'.allMatches(code).length + 1;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF121212) : const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDarkMode
              ? Colors.white.withOpacity(0.08)
              : Colors.black.withOpacity(0.05),
          width: 1,
        ),
        boxShadow: [
          if (!isDarkMode)
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: isDarkMode
                  ? const Color(0xFF1E1E1E)
                  : const Color(0xFFF1F3F5),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.blueAccent.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    _getLanguageLabel(),
                    style: TextStyle(
                      color: Colors.blueAccent,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                if (filename != null) ...[
                  const SizedBox(width: 8),
                  Text(
                    filename!,
                    style: TextStyle(
                      color: isDarkMode ? Colors.white54 : Colors.black45,
                      fontSize: 11,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
                const Spacer(),
                _HeaderAction(
                  icon: FontAwesomeIcons.copy,
                  onTap: () => _copyToClipboard(context),
                  tooltip: 'Kopyala',
                ),
                const SizedBox(width: 4),
                PopupMenuButton<String>(
                  icon: Icon(
                    Icons.more_horiz,
                    color: isDarkMode ? Colors.white54 : Colors.black54,
                    size: 20,
                  ),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 150),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  color: isDarkMode ? const Color(0xFF252525) : Colors.white,
                  offset: const Offset(0, 40),
                  onSelected: (value) {
                    if (value == 'panel') {
                      onOpenInPanel?.call();
                    } else if (value == 'download') {
                      _downloadCode(context);
                    } else if (value == 'artifact') {
                      onOpenArtifact?.call(false); // Code mode
                    } else if (value == 'preview') {
                      onOpenArtifact?.call(true); // Preview mode
                    }
                  },
                  itemBuilder: (ctx) {
                    final isWebLang = [
                      'html',
                      'css',
                      'javascript',
                      'js',
                    ].contains(language.toLowerCase());
                    return [
                      if (onOpenInPanel != null)
                        PopupMenuItem(
                          value: 'panel',
                          child: _PopupItem(
                            icon: Icons.open_in_new,
                            text: 'Kod panelinde aç',
                          ),
                        ),
                      if (onOpenArtifact != null) ...[
                        PopupMenuItem(
                          value: 'artifact',
                          child: _PopupItem(
                            icon: Icons.auto_awesome_motion,
                            text: 'Artifact\'te Aç',
                          ),
                        ),
                        if (isWebLang)
                          PopupMenuItem(
                            value: 'preview',
                            child: _PopupItem(
                              icon: Icons.visibility_rounded,
                              text: 'Önizlemede aç',
                            ),
                          ),
                      ],
                      PopupMenuItem(
                        value: 'download',
                        child: _PopupItem(
                          icon: Icons.download_rounded,
                          text: 'Dosya olarak indir',
                        ),
                      ),
                    ];
                  },
                ),
              ],
            ),
          ),
          // Code with Line Numbers
          ClipRRect(
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(16),
              bottomRight: Radius.circular(16),
            ),
            child: Container(
              constraints: const BoxConstraints(maxHeight: 500),
              child: SingleChildScrollView(
                scrollDirection: Axis.vertical,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Line Numbers
                        Container(
                          width: 45,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          decoration: BoxDecoration(
                            color: isDarkMode
                                ? Colors.black.withOpacity(0.2)
                                : Colors.black.withOpacity(0.02),
                            border: Border(
                              right: BorderSide(
                                color: isDarkMode
                                    ? Colors.white.withOpacity(0.05)
                                    : Colors.black.withOpacity(0.05),
                              ),
                            ),
                          ),
                          child: Column(
                            children: List.generate(lineCount, (i) {
                              return SizedBox(
                                height: 20,
                                child: Center(
                                  child: Text(
                                    '${i + 1}',
                                    style: TextStyle(
                                      color: isDarkMode
                                          ? Colors.white24
                                          : Colors.black26,
                                      fontSize: 11,
                                      fontFamily: 'monospace',
                                    ),
                                  ),
                                ),
                              );
                            }),
                          ),
                        ),
                        // Code content
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 16,
                          ),
                          child: HighlightView(
                            code,
                            language: language.toLowerCase(),
                            theme: isDarkMode
                                ? monokaiSublimeTheme
                                : githubTheme,
                            textStyle: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 14,
                              height: 1.42, // Adjusted height for 20px match
                            ),
                          ),
                        ),
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
}

class _HeaderAction extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final String tooltip;

  const _HeaderAction({
    required this.icon,
    required this.onTap,
    required this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: FaIcon(
            icon,
            size: 14,
            color: isDarkMode ? Colors.white54 : Colors.black54,
          ),
        ),
      ),
    );
  }
}

class _PopupItem extends StatelessWidget {
  final IconData icon;
  final String text;

  const _PopupItem({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return Row(
      children: [
        Icon(
          icon,
          size: 18,
          color: isDarkMode ? Colors.white70 : Colors.black.withOpacity(0.7),
        ),
        const SizedBox(width: 12),
        Text(
          text,
          style: TextStyle(
            color: isDarkMode ? Colors.white : Colors.black87,
            fontSize: 13,
          ),
        ),
      ],
    );
  }
}
