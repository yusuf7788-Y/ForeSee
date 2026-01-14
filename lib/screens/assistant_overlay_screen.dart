import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:android_intent_plus/android_intent.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:installed_apps/installed_apps.dart';
import 'package:installed_apps/app_info.dart';

import '../services/openrouter_service.dart';
import '../services/speech_to_text_service.dart';
import '../widgets/grey_notification.dart';

class AssistantOverlayScreen extends StatefulWidget {
  const AssistantOverlayScreen({super.key});

  @override
  State<AssistantOverlayScreen> createState() => _AssistantOverlayScreenState();
}

class _AssistantOverlayScreenState extends State<AssistantOverlayScreen> {
  final TextEditingController _controller = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  final SpeechToTextService _speechService = SpeechToTextService.instance;
  final OpenRouterService _openRouterService = OpenRouterService();
  List<AppInfo>? _installedApps;
  bool _isLoadingApps = false;

  bool _isSending = false;
  String _userMessage = '';
  String _aiMessage = '';
  String? _imageBase64;
  bool _isRecordingVoice = false;
  double _recordLevel = 0.0;

  @override
  void dispose() {
    _controller.dispose();
    _speechService.stopListening();
    super.dispose();
  }

  Future<void> _pickScreenshot() async {
    try {
      final picked = await _picker.pickImage(source: ImageSource.gallery);
      if (picked == null) return;

      final file = File(picked.path);
      if (!await file.exists()) return;

      final bytes = await file.readAsBytes();
      setState(() {
        _imageBase64 = base64Encode(bytes);
      });

      GreyNotification.show(
        context,
        'Ekran görüntüsü eklendi',
      );
    } catch (_) {
      GreyNotification.show(context, 'Görsel seçilemedi');
    }
  }

  String _stripTurkishLocationSuffixes(String token) {
    final suffixes = ['da', 'de', 'ta', 'te', 'dan', 'den'];
    for (final s in suffixes) {
      if (token.length > s.length + 2 && token.endsWith(s)) {
        return token.substring(0, token.length - s.length);
      }
    }
    return token;
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (_isSending) return;
    if (text.isEmpty) {
      GreyNotification.show(context, 'Lütfen bir komut söyleyin veya yazın');
      return;
    }

    setState(() {
      _isSending = true;
      _userMessage = text;
      _aiMessage = '';
    });

    _controller.clear();

    try {
      await _handleCommand(text);
    } finally {
      if (!mounted) return;
      setState(() {
        _isSending = false;
        _imageBase64 = null; // Bu modda görsel kullanılmıyor
      });
    }
  }

  String _normalizeCommandText(String input) {
    final lower = input.toLowerCase();
    return lower
        .replaceAll('ç', 'c')
        .replaceAll('ğ', 'g')
        .replaceAll('ı', 'i')
        .replaceAll('ö', 'o')
        .replaceAll('ş', 's')
        .replaceAll('ü', 'u');
  }

  Future<void> _handleCommand(String rawCommand) async {
    final trimmed = rawCommand.trim();
    if (trimmed.isEmpty) return;

    final normalized = _normalizeCommandText(trimmed);
    final lowerRaw = trimmed.toLowerCase();

    // Web arama komutları: "webde ara ..."
    if (lowerRaw.startsWith('webde ara')) {
      String query = trimmed.substring(lowerRaw.indexOf('webde ara') + 'webde ara'.length).trim();
      if (query.isEmpty) {
        if (!mounted) return;
        GreyNotification.show(context, 'Ne aramamı istersin? Örn: "webde ara dolar kuru"');
      } else {
        await _openWebSearch(query);
      }
      return;
    }

    // Diğer tüm komutları genel uygulama açma / web araması denemesi olarak yorumla
    await _openAppByName(trimmed, normalized);
  }

  Future<void> _ensureInstalledAppsLoaded() async {
    if (_installedApps != null || _isLoadingApps) return;
    _isLoadingApps = true;
    try {
      final apps = await InstalledApps.getInstalledApps(
        excludeSystemApps: true,
        excludeNonLaunchableApps: true,
        withIcon: false,
      );
      _installedApps = apps;
    } catch (_) {
      _installedApps = [];
    } finally {
      _isLoadingApps = false;
    }
  }

  Future<void> _openAppByName(String rawCommand, String normalized) async {
    // Önce AI'dan hangi uygulamanın veya web aramasının daha mantıklı olduğunu sor
    String appHint = 'UNKNOWN';
    try {
      appHint = await _openRouterService.refineOverlayAppName(rawCommand);
    } catch (_) {
      appHint = 'UNKNOWN';
    }

    if (appHint == 'WEB_SEARCH') {
      final refined = await _openRouterService.refineWebSearchQuery(rawCommand);
      await _openWebSearch(refined);
      return;
    }

    await _ensureInstalledAppsLoaded();
    final apps = _installedApps;
    if (apps == null || apps.isEmpty) {
      if (!mounted) return;
      GreyNotification.show(context, 'Yüklü uygulamalar okunamadı');
      return;
    }

    // Komuttan muhtemel uygulama adını çıkar
    final stopWords = <String>{
      'ac', 'uygulamasini', 'uygulamayi', 'uygulama',
      'programi', 'program', 'app', 'telefon', 'bana',
      'su', 'sunu', 'bir', 'lutfen', 'lütfen',
    };

    // Eğer AI bir uygulama adı döndürdüyse, onu baz al; yoksa ham normalized metni kullan
    String baseText;
    if (appHint != 'UNKNOWN' && appHint != 'WEB_SEARCH') {
      baseText = _normalizeCommandText(appHint);
    } else {
      baseText = normalized;
    }

    final tokens = baseText
        .split(RegExp(r'\s+'))
        .map(_stripTurkishLocationSuffixes)
        .where((t) => t.isNotEmpty && !stopWords.contains(t))
        .toList();

    if (tokens.isEmpty) {
      if (!mounted) return;
      GreyNotification.show(context, 'Hangi uygulamayi acmam gerektigini anlayamadim');
      return;
    }

    final query = tokens.join(' ');

    AppInfo? bestMatch;
    int bestScore = 0;

    for (final app in apps) {
      final appNameNorm = _normalizeCommandText(app.name);
      int score = 0;
      if (appNameNorm == query) {
        score = 100;
      } else if (appNameNorm.contains(query)) {
        score = query.length * 2;
      } else if (query.contains(appNameNorm)) {
        score = appNameNorm.length * 2;
      } else if (appNameNorm.split(' ').any((p) => query.contains(p))) {
        score = appNameNorm.split(' ').where((p) => query.contains(p)).fold<int>(0, (s, p) => s + p.length);
      }

      if (score > bestScore) {
        bestScore = score;
        bestMatch = app;
      }
    }

    if (bestMatch != null && bestScore > 0) {
      try {
        await InstalledApps.startApp(bestMatch.packageName);
        return;
      } catch (_) {
        // Devam edip web aramasina dus
      }
    }

    // Uygulama bulunamazsa veya acilamazsa, adi ile web aramasi yap
    await _openWebSearch(query);
  }

  Future<void> _openWebSearch(String query) async {
    try {
      final uri = Uri.https('www.google.com', '/search', {'q': query});
      if (!await canLaunchUrl(uri) ||
          !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        if (!mounted) return;
        GreyNotification.show(context, 'Web araması açılamadı');
      }
    } catch (e) {
      if (!mounted) return;
      GreyNotification.show(context, 'Web araması açılamadı: $e');
    }
  }

  Future<void> _openYoutube() async {
    if (Platform.isAndroid) {
      try {
        const intent = AndroidIntent(
          action: 'android.intent.action.VIEW',
          data: 'https://www.youtube.com/',
          package: 'com.google.android.youtube',
        );
        await intent.launch();
        return;
      } catch (_) {
        // NOP - URL launch ile devam et
      }
    }

    // Diğer platformlar veya intent başarısız olursa, tarayıcıda açmayı dene
    try {
      final uri = Uri.parse('https://www.youtube.com/');
      if (!await canLaunchUrl(uri) ||
          !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        if (!mounted) return;
        GreyNotification.show(context, 'YouTube açılamadı');
      }
    } catch (e) {
      if (!mounted) return;
      GreyNotification.show(context, 'YouTube açılamadı: $e');
    }
  }

  Future<void> _startVoiceRecording() async {
    if (_isSending) {
      GreyNotification.show(context, 'AI cevap veriyor, lütfen bitmesini bekleyin...');
      return;
    }
    if (_isRecordingVoice) return;

    final success = await _speechService.startListening(
      onText: (text) {
        if (!mounted) return;
        setState(() {
          _controller.text = text;
          _controller.selection = TextSelection.fromPosition(
            TextPosition(offset: _controller.text.length),
          );
        });
      },
      onLevelChanged: (level) {
        if (!mounted) return;
        setState(() {
          _recordLevel = level;
        });
      },
      onError: (message) {
        if (!mounted) return;
        GreyNotification.show(context, 'STT hatası: $message');
      },
    );

    if (!mounted) return;

    setState(() {
      _isRecordingVoice = success;
      if (!success) {
        _recordLevel = 0.0;
      }
    });
  }

  Future<void> _stopVoiceRecording() async {
    try {
      if (_isRecordingVoice) {
        await _speechService.stopListening();
      }
    } catch (_) {}

    if (!mounted) return;
    setState(() {
      _isRecordingVoice = false;
      _recordLevel = 0.0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          // Saydam gri arka plan - tıklanınca asistanı kapat
          Positioned.fill(
            child: GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: Container(
                color: Colors.black.withOpacity(0.6),
              ),
            ),
          ),
          SafeArea(
            top: false,
            bottom: true,
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildScreenControlPill(),
                  const SizedBox(height: 12),
                  _buildInputBar(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConversation() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_aiMessage.isNotEmpty)
          Align(
            alignment: Alignment.centerLeft,
            child: _buildBubble(_aiMessage, isUser: false),
          ),
        if (_userMessage.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Align(
              alignment: Alignment.centerRight,
              child: _buildBubble(_userMessage, isUser: true),
            ),
          ),
      ],
    );
  }

  Widget _buildBubble(String text, {required bool isUser}) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 320),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: Colors.white,
            width: 1.4,
          ),
        ),
        child: Text(
          text,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  Widget _buildInputBar() {
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + bottomPadding),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(24),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(
                Icons.screenshot_monitor,
                color: Colors.white70,
                size: 20,
              ),
              onPressed: _isSending ? null : _pickScreenshot,
            ),
            Expanded(
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxHeight: 120,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: _controller,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      minLines: 1,
                      maxLines: 5,
                      keyboardType: TextInputType.multiline,
                      textInputAction: TextInputAction.newline,
                      decoration: const InputDecoration(
                        hintText: "ForeSee'e birşey sor...",
                        hintStyle: TextStyle(color: Colors.white38, fontSize: 14),
                        border: InputBorder.none,
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 4, vertical: 12),
                      ),
                    ),
                    if (_isRecordingVoice) ...[
                      const SizedBox(height: 4),
                      Container(
                        height: 6,
                        decoration: BoxDecoration(
                          color: Colors.white10,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        alignment: Alignment.centerLeft,
                        child: FractionallySizedBox(
                          widthFactor: _recordLevel.clamp(0.05, 1.0),
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.greenAccent,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(width: 4),
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFF2A2A2A),
                shape: BoxShape.circle,
              ),
              child: IconButton(
                onPressed: _isRecordingVoice ? _stopVoiceRecording : _startVoiceRecording,
                icon: Icon(
                  _isRecordingVoice ? Icons.stop : Icons.mic,
                  size: 18,
                  color: _isRecordingVoice ? Colors.red : Colors.white54,
                ),
              ),
            ),
            const SizedBox(width: 4),
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: _isSending ? Colors.red : Colors.white,
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: Icon(
                  _isSending ? Icons.stop : Icons.arrow_upward,
                  size: 18,
                  color: _isSending ? Colors.white : Colors.black,
                ),
                onPressed: _isSending ? null : _send,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScreenControlPill() {
    return GestureDetector(
      onTap: () {
        GreyNotification.show(
          context,
          'Ekran izleme kontrolü yakında eklenecek',
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Colors.white24),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(
              Icons.cast,
              color: Colors.white,
              size: 18,
            ),
            SizedBox(width: 8),
            Text(
              'Ekran izleme Kontrol',
              style: TextStyle(
                color: Colors.white,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
