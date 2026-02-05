import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:url_launcher/url_launcher.dart';
import '../screens/webview_screen.dart';

class CitationLinkBuilder extends MarkdownElementBuilder {
  final BuildContext context;
  final bool isUser;

  CitationLinkBuilder(this.context, {required this.isUser});

  @override
  Widget? visitElementAfter(md.Element element, TextStyle? preferredStyle) {
    // Kullanıcı mesajlarına veya sadece [sayı] formatında olmayanlara dokunma
    final textContent = element.textContent;
    final isCitation = RegExp(r'^\[\d+\]$').hasMatch(textContent);

    if (isUser || !isCitation) return null;

    final href = element.attributes['href'];
    if (href == null) return null;

    final uri = Uri.tryParse(href);
    if (uri == null) return null;

    // Özel dahili şemalar için varsayılan MarkDown işlemesine bırak
    const internalSchemes = [
      'wifi',
      'gamehub',
      'settings',
      'offlinegame',
      'retry',
    ];
    if (internalSchemes.contains(uri.scheme)) {
      return null;
    }

    return GestureDetector(
      onTap: () {
        // ForeWeb ile aç
        Navigator.of(context).push(
          MaterialPageRoute(builder: (context) => ForeWebScreen(url: href)),
        );
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 2),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.blue.withOpacity(0.1),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.link, size: 10, color: Colors.blue.withOpacity(0.6)),
          ],
        ),
      ),
    );
  }
}
