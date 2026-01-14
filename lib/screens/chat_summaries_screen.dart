import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/chat.dart';
import '../models/message.dart';
import '../services/openrouter_service.dart';
import '../widgets/grey_notification.dart';

class ChatSummariesScreen extends StatefulWidget {
  final Chat chat;

  const ChatSummariesScreen({super.key, required this.chat});

  @override
  State<ChatSummariesScreen> createState() => _ChatSummariesScreenState();
}

class _ChatSummariesScreenState extends State<ChatSummariesScreen> {
  final OpenRouterService _openRouterService = OpenRouterService();

  late Chat _chat;
  List<Map<String, dynamic>> _cards = [];
  bool _isLoading = false;
  bool _isJsonMode = false;
  bool _isMerged = false;
  bool _isProcessingMerge = false;

  @override
  void initState() {
    super.initState();
    _chat = widget.chat;
    _cards = List<Map<String, dynamic>>.from(_chat.summaryCards ?? const []);
    if (_cards.isEmpty) {
      _generateCardsFromAI();
    }
  }

  Future<void> _generateCardsFromAI() async {
    if (_chat.messages.isEmpty) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final buffer = StringBuffer();
      const int maxChars = 3200;
      for (final Message msg in _chat.messages) {
        final prefix = msg.isUser ? 'Kullanıcı: ' : 'ForeSee: ';
        final line = '$prefix${msg.content}\n';
        if (buffer.length + line.length > maxChars) {
          buffer.write(line.substring(0, maxChars - buffer.length));
          break;
        }
        buffer.write(line);
      }

      final convoText = buffer.toString().trim();
      if (convoText.isEmpty) {
        setState(() {
          _isLoading = false;
        });
        return;
      }

      final prompt =
          '''
Aşağıdaki sohbetten PROJE / ÇALIŞMA odaklı özet kartları çıkar.

AMAÇ:
- Her kart, sohbetin belirli bir bölümünü veya açısını temsil etsin (genel bakış, görevler, kararlar, riskler vb.).
- Kartlar daha sonra başka sohbetlere JSON olarak yapıştırıldığında, sanki o proje daha önce konuşulmuş gibi bağlam verebilsin.

ÇIKTI KURALLARI:
- YANIT SADECE GEÇERLİ BİR JSON NESNESİ OLSUN, başka metin yazma.
- Kod bloğu (```json vb.) KULLANMA, sadece düz JSON yaz.
- Boş satır, açıklama, yorum ekleme.

ŞEMA:
{
  "cards": [
    {
      "id": "1",                    // "1", "2" gibi kısa string ID
      "title": "Kısa kart başlığı", // İnsan okuyacağı başlık
      "kind": "overview|tasks|decision|risk|note", // Kart tipi
      "status": "info|open|in_progress|done|blocked", // Kartın durumu
      "text": "İnsan tarafından okunabilir, detaylı ama özlü özet.",
      "json": {
        "project_name": "Projenin veya konunun adı",
        "summary": "Bu kartın kısa özeti",
        "goals": ["hedef 1", "hedef 2"],
        "tasks": [
          {
            "title": "Görev başlığı",
            "status": "todo|doing|done",
            "priority": "low|medium|high",
            "owner": "isteğe bağlı kişi/rol",
            "due": "YYYY-MM-DD" // tarih yoksa null veya boş string kullan
          }
        ],
        "decisions": ["alınan karar 1", "alınan karar 2"],
        "risks": ["risk 1", "risk 2"],
        "next_actions": ["sonraki adım 1", "sonraki adım 2"]
      }
    }
  ]
}

NOTLAR:
- Her kart için "kind" ve "status" alanlarını DOLDUR.
- Gereksiz alanları boş bırakmak yerine hiç yazma (örneğin hiç risk yoksa "risks": [] yazabilirsin ama özel alanlar ekleme).
- Tüm metinleri TÜRKÇE yaz.

SOHBET METNİ:
$convoText
''';

      final response = await _openRouterService.sendMessageWithHistory(
        const [],
        prompt,
      );

      final trimmed = response.trim();
      if (trimmed.isEmpty) {
        setState(() {
          _isLoading = false;
        });
        return;
      }

      final decoded = jsonDecode(trimmed);
      final list = (decoded['cards'] as List?) ?? const [];
      final parsed = list
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();

      setState(() {
        _cards = parsed;
        _chat = _chat.copyWith(summaryCards: parsed, updatedAt: DateTime.now());
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        GreyNotification.show(context, 'Sohbet özetleri oluşturulamadı: $e');
      }
    }
  }

  void _toggleMerge() async {
    if (_cards.isEmpty || _isProcessingMerge) {
      return;
    }

    setState(() {
      _isProcessingMerge = true;
    });

    final duration = _isMerged
        ? const Duration(milliseconds: 400)
        : const Duration(milliseconds: 900);

    await Future.delayed(duration);

    if (!mounted) return;

    setState(() {
      _isMerged = !_isMerged;
      _isProcessingMerge = false;
    });
  }

  void _toggleMode(bool jsonMode) {
    if (_isJsonMode == jsonMode) return;
    setState(() {
      _isJsonMode = jsonMode;
    });
  }

  void _copyToClipboard(String text) {
    if (text.trim().isEmpty) {
      GreyNotification.show(context, 'Kopyalanacak içerik yok');
      return;
    }
    Clipboard.setData(ClipboardData(text: text));
    GreyNotification.show(context, 'Panoya kopyalandı');
  }

  String _formatJson(dynamic data) {
    try {
      if (data is String) {
        final decoded = jsonDecode(data);
        return const JsonEncoder.withIndent('  ').convert(decoded);
      }
      return const JsonEncoder.withIndent('  ').convert(data);
    } catch (_) {
      return data.toString();
    }
  }

  Map<String, dynamic> _buildMergedCard() {
    if (_cards.isEmpty) {
      return <String, dynamic>{
        'id': 'merged',
        'title': _chat.title,
        'text': '',
        'json': <String, dynamic>{},
      };
    }

    final buffer = StringBuffer();
    for (int i = 0; i < _cards.length; i++) {
      final card = _cards[i];
      final title = (card['title'] ?? '').toString().trim();
      final text = (card['text'] ?? '').toString().trim();
      if (title.isNotEmpty) {
        buffer.writeln(title);
      }
      if (text.isNotEmpty) {
        buffer.writeln(text);
      }
      if (i != _cards.length - 1) {
        buffer.writeln();
        buffer.writeln('---');
        buffer.writeln();
      }
    }

    final mergedJson = {
      'chat_title': _chat.title,
      'card_count': _cards.length,
      'cards': _cards,
    };

    return <String, dynamic>{
      'id': 'merged',
      'title': _chat.title,
      'text': buffer.toString().trim(),
      'json': mergedJson,
    };
  }

  List<Map<String, dynamic>> get _visibleCards {
    if (_cards.isEmpty) return const [];
    if (!_isMerged) return _cards;
    return <Map<String, dynamic>>[_buildMergedCard()];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: () {
                          Navigator.of(context).pop(_chat);
                        },
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          _chat.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 4,
                  ),
                  child: Row(
                    children: [
                      _buildMergeButton(),
                      const Spacer(),
                      _buildModeToggle(),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(child: _buildBody()),
              ],
            ),
            if (_isProcessingMerge)
              Container(
                color: Colors.black54,
                child: const Center(
                  child: Text(
                    '...',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 24,
                      letterSpacing: 4,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMergeButton() {
    final label = _isMerged ? 'Parçalara ayır' : 'Bütünleştir';

    return ElevatedButton.icon(
      onPressed: _cards.isEmpty || _isProcessingMerge ? null : _toggleMerge,
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF111827),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      ),
      icon: const Icon(Icons.merge_type, size: 16),
      label: Text(
        label,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
      ),
    );
  }

  Widget _buildModeToggle() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFF111111),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white24, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildModeChip(
            label: 'Metin',
            isActive: !_isJsonMode,
            onTap: () {
              _toggleMode(false);
            },
          ),
          const SizedBox(width: 4),
          _buildModeChip(
            label: 'JSON',
            isActive: _isJsonMode,
            onTap: () {
              _toggleMode(true);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildModeChip({
    required String label,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isActive ? Colors.black : Colors.white70,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(color: Colors.blue),
            const SizedBox(height: 16),
            const Text(
              'AI Sohbeti özetliyor',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Biraz fazla uzun sürebilir....',
              style: TextStyle(color: Colors.white60, fontSize: 12),
            ),
          ],
        ),
      );
    }

    if (_visibleCards.isEmpty) {
      return const Center(
        child: Text(
          'Bu sohbette başka bir şey bulamadık...',
          style: TextStyle(color: Colors.white38, fontSize: 13),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      itemCount: _visibleCards.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final card = _visibleCards[index];
        return _buildSummaryCard(card, index);
      },
    );
  }

  Widget _buildKindChip(String kindRaw, String? statusRaw) {
    final kind = kindRaw.trim().toLowerCase();
    final status = statusRaw?.trim().toLowerCase();

    Color bg;
    String label;

    switch (kind) {
      case 'overview':
        bg = const Color(0xFF1D4ED8); // mavi
        label = 'Genel Bakış';
        break;
      case 'tasks':
        bg = const Color(0xFF22C55E); // yeşil
        label = 'Görevler';
        break;
      case 'decision':
      case 'decisions':
        bg = const Color(0xFFF97316); // turuncu
        label = 'Kararlar';
        break;
      case 'risk':
      case 'risks':
        bg = const Color(0xFFDC2626); // kırmızı
        label = 'Riskler';
        break;
      default:
        bg = const Color(0xFF6B7280); // gri
        label = 'Not';
        break;
    }

    String? statusLabel;
    if (status == 'open') statusLabel = 'Açık';
    if (status == 'in_progress') statusLabel = 'Devam';
    if (status == 'done') statusLabel = 'Bitti';
    if (status == 'blocked') statusLabel = 'Bloklu';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      margin: const EdgeInsets.only(right: 8),
      decoration: BoxDecoration(
        color: bg.withOpacity(0.18),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: bg.withOpacity(0.9), width: 0.7),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            margin: const EdgeInsets.only(right: 4),
            decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
          ),
          Text(
            statusLabel == null ? label : '$label · $statusLabel',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(Map<String, dynamic> card, int index) {
    final title = (card['title'] ?? '').toString().trim().isEmpty
        ? 'Kart ${index + 1}'
        : (card['title'] ?? '').toString().trim();

    final kind = (card['kind'] ?? '').toString();
    final status = (card['status'] ?? '').toString();

    final textContent = (card['text'] ?? '').toString();
    final jsonContent = card['json'];
    final bodyText = _isJsonMode ? _formatJson(jsonContent) : textContent;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF111111),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white12, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (kind.trim().isNotEmpty)
                  _buildKindChip(kind, status.isEmpty ? null : status),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.copy, color: Colors.white70, size: 18),
                  onPressed: () => _copyToClipboard(bodyText),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              constraints: const BoxConstraints(minHeight: 120, maxHeight: 360),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF050505),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white10, width: 1),
              ),
              child: SingleChildScrollView(
                child: SelectableText(
                  bodyText.isEmpty
                      ? 'Bu kart için içerik bulunamadı.'
                      : bodyText,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
