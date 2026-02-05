import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../models/chat.dart';
import '../services/theme_service.dart';
import '../services/openrouter_service.dart';
import '../services/storage_service.dart';

class ChatSummariesScreen extends StatefulWidget {
  final Chat chat;
  const ChatSummariesScreen({super.key, required this.chat});

  @override
  State<ChatSummariesScreen> createState() => _ChatSummariesScreenState();
}

class _ChatSummariesScreenState extends State<ChatSummariesScreen> {
  late Chat _chat;
  bool _isLoading = true;
  bool _isProcessingMerge = false;
  bool _isMerged = false;
  bool _isJsonMode = false;

  List<Map<String, dynamic>> _cards = [];
  List<Map<String, dynamic>> _visibleCards = [];

  @override
  void initState() {
    super.initState();
    _chat = widget.chat;

    // Eğer kaydedilmiş özet varsa ve mesaj sayısı değişmemişse direkt göster
    if (_chat.summaryCards != null &&
        _chat.summaryCards!.isNotEmpty &&
        _chat.lastSummarizedCount == _chat.messages.length) {
      _cards = _chat.summaryCards!;
      _visibleCards = _cards;
      _isLoading = false;
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _generateCardsFromAI();
      });
    }
  }

  Future<void> _generateCardsFromAI() async {
    final ai = OpenRouterService();
    final history = _chat.messages
        .map((m) => "${m.isUser ? 'User' : 'AI'}: ${m.content}")
        .join("\n");

    String prompt = "";
    final currentMsgCount = _chat.messages.length;

    if (_chat.summaryCards != null &&
        _chat.summaryCards!.isNotEmpty &&
        _chat.lastSummarizedCount != null) {
      // Incremental Update (Merge)
      final newMessages = _chat.messages.sublist(_chat.lastSummarizedCount!);
      final newHistory = newMessages
          .map((m) => "${m.isUser ? 'User' : 'AI'}: ${m.content}")
          .join("\n");
      final existingSummary = jsonEncode(_chat.summaryCards);

      prompt =
          """
      Mevcut bir sohbet özeti (JSON formatında) ve sonradan eklenen yeni mesajlar aşağıdadır.
      Lütfen mevcut özeti yeni mesajlara göre GÜNCELLE ve GENİŞLET.
      
      Mevcut Özet (JSON):
      $existingSummary
      
      Yeni Gelen Mesajlar:
      $newHistory
      
      Kurallar:
      1. SADECE güncellenmiş JSON array'i döndür. 
      2. Eskiden gelen önemli bilgileri silme, yeni bilgileri uygun kartlara ekle veya yeni kartlar aç.
      3. "kind" (overview, tasks, decision, risk), "title", "text", "status" alanlarını koru.
      """;
    } else {
      // Full Generation
      prompt =
          """
      Aşağıdaki sohbet geçmişini analiz et ve JSON formatında yapılandırılmış bir özet çıkar.
      Çıktı SADECE geçerli bir JSON array olmalıdır.
      Her obje şu alanları içermelidir: "kind", "title", "text", "status".
      
      Örnek format:
      [
        {
          "kind": "overview",
          "title": "Proje Başlangıcı",
          "text": "Müşteri ile ilk görüşme yapıldı ve gereksinimler netleşti.",
          "status": "done"
        }
      ]

      Kurallar:
      1. "kind" şunlardan biri olmalı: "overview", "tasks", "decision", "risk".
      2. "status" şunlardan biri olmalı veya boş bırakılmalı: "open", "done", "in_progress", "blocked".
      3. Hiçbir alanı null bırakma. Eğer bilgi yoksa boş string ("") kullan.
      
      Sohbet:
      $history
      """;
    }

    try {
      final response = await ai
          .sendMessage(prompt)
          .timeout(const Duration(seconds: 25));

      String jsonStr = response.trim();
      if (jsonStr.contains('```json')) {
        jsonStr = jsonStr.split('```json')[1].split('```')[0].trim();
      } else if (jsonStr.contains('```')) {
        jsonStr = jsonStr.split('```')[1].split('```')[0].trim();
      }

      final List<dynamic> parsed = jsonDecode(jsonStr);
      final List<Map<String, dynamic>> validatedCards = [];

      for (var item in parsed) {
        if (item is Map) {
          validatedCards.add({
            'kind': (item['kind'] ?? 'note').toString(),
            'title': (item['title'] ?? item['header'] ?? 'Özet').toString(),
            'text':
                (item['text'] ??
                        item['content'] ??
                        item['description'] ??
                        'Bilgi yok')
                    .toString(),
            'status': (item['status'] ?? '').toString(),
            'json': item, // Original data for JSON mode
          });
        }
      }

      if (mounted) {
        setState(() {
          _cards = validatedCards;
          _visibleCards = _cards;
          _isLoading = false;
        });

        // Save back to storage
        final storage = StorageService();
        final chats = await storage.loadChats();
        final idx = chats.indexWhere((c) => c.id == _chat.id);
        if (idx != -1) {
          chats[idx] = chats[idx].copyWith(
            summaryCards: validatedCards,
            lastSummarizedCount: currentMsgCount,
          );
          await storage.saveChats(chats);
        }
      }
    } catch (e) {
      debugPrint("Summary parsing error: $e");
      if (mounted) {
        setState(() {
          _isLoading = false;
          _visibleCards = [
            {
              "kind": "risk",
              "title": "Hata",
              "text": "Özet oluşturulurken bir hata meydana geldi: $e",
              "status": "blocked",
            },
          ];
        });
      }
    }
  }

  void _toggleMode(bool jsonMode) {
    setState(() => _isJsonMode = jsonMode);
  }

  void _toggleMerge() {
    setState(() {
      _isMerged = !_isMerged;
      if (_isMerged) {
        final mergedText = _cards
            .map((c) => "## ${c['title']}\n${c['text']}")
            .join("\n\n");
        _visibleCards = [
          {
            "kind": "overview",
            "title": "Birleştirilmiş Özet",
            "text": mergedText,
            "json": _cards,
          },
        ];
      } else {
        _visibleCards = _cards;
      }
    });
  }

  Future<void> _copyToClipboard(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Kopyalandı'),
        duration: Duration(seconds: 1),
      ),
    );
  }

  String _formatJson(dynamic json) {
    try {
      return const JsonEncoder.withIndent('  ').convert(json);
    } catch (_) {
      return json.toString();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = themeService.isDarkMode;
    final theme = Theme.of(context);
    final bgColor = isDark
        ? theme.scaffoldBackgroundColor
        : const Color(0xFFF3F4F6);
    final textColor = isDark ? Colors.white : Colors.black87;

    return Scaffold(
      backgroundColor: bgColor,
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
                        icon: Icon(Icons.arrow_back, color: textColor),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          _chat.title,
                          style: TextStyle(
                            color: textColor,
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
                      _buildMergeButton(isDark),
                      const Spacer(),
                      _buildModeToggle(isDark),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(child: _buildBody(isDark)),
              ],
            ),
            if (_isLoading)
              Container(
                color: Colors.black54,
                child: const Center(child: CircularProgressIndicator()),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMergeButton(bool isDark) {
    final label = _isMerged ? 'Parçalara ayır' : 'Bütünleştir';
    final btnBg = isDark ? const Color(0xFF111827) : const Color(0xFFE5E7EB);
    final btnFg = isDark ? Colors.white : Colors.black87;

    return ElevatedButton.icon(
      onPressed: _cards.isEmpty || _isProcessingMerge ? null : _toggleMerge,
      style: ElevatedButton.styleFrom(
        backgroundColor: btnBg,
        foregroundColor: btnFg,
        elevation: 0,
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

  Widget _buildModeToggle(bool isDark) {
    final containerBg = isDark
        ? const Color(0xFF111111)
        : const Color(0xFFE5E7EB);
    final borderCol = isDark ? Colors.white24 : Colors.grey.shade300;

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: containerBg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: borderCol, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildModeChip(
            label: 'Metin',
            isActive: !_isJsonMode,
            onTap: () => _toggleMode(false),
            isDark: isDark,
          ),
          const SizedBox(width: 4),
          _buildModeChip(
            label: 'JSON',
            isActive: _isJsonMode,
            onTap: () => _toggleMode(true),
            isDark: isDark,
          ),
        ],
      ),
    );
  }

  Widget _buildModeChip({
    required String label,
    required bool isActive,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    final activeBg = isDark ? Colors.white : Colors.white;
    final activeFg = Colors.black; // Always black text on white chip
    final inactiveFg = isDark ? Colors.white70 : Colors.black54;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? activeBg : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
          boxShadow: isActive
              ? [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4)]
              : [],
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isActive ? activeFg : inactiveFg,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildBody(bool isDark) {
    final textColor = isDark ? Colors.white : Colors.black87;

    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(color: Colors.blue),
            const SizedBox(height: 16),
            Text(
              'AI Sohbeti özetliyor',
              style: TextStyle(
                color: textColor,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Biraz fazla uzun sürebilir....',
              style: TextStyle(
                color: isDark ? Colors.white60 : Colors.black54,
                fontSize: 12,
              ),
            ),
          ],
        ),
      );
    }

    if (_visibleCards.isEmpty) {
      return Center(
        child: Text(
          'Bu sohbette başka bir şey bulamadık...',
          style: TextStyle(
            color: isDark ? Colors.white38 : Colors.black38,
            fontSize: 13,
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      itemCount: _visibleCards.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final card = _visibleCards[index];
        return _buildSummaryCard(card, index, isDark);
      },
    );
  }

  // Kind Chip logic remains mostly same but using isDark if needed for bg opacity
  Widget _buildKindChip(String kindRaw, String? statusRaw, bool isDark) {
    // ... (same logic for colors)
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
            style: TextStyle(
              color: isDark
                  ? Colors.white
                  : Colors
                        .black87, // Adaptive text color for chip? usually chips are colored so white is ok if bg is dark. But here bg is light opacity.
              // Logic check: bg is color.withOpacity(0.18).
              // If isDark, text White is visible.
              // If Light, text White might fail?
              // Let's use darker text for Light Mode:
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ).copyWith(color: isDark ? Colors.white : Colors.black87),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(Map<String, dynamic> card, int index, bool isDark) {
    final title = (card['title'] ?? '').toString().trim().isEmpty
        ? 'Kart ${index + 1}'
        : (card['title'] ?? '').toString().trim();

    final kind = (card['kind'] ?? '').toString();
    final status = (card['status'] ?? '').toString();

    final textContent = (card['text'] ?? '').toString();
    final jsonContent = card['json'];
    final bodyText = _isJsonMode ? _formatJson(jsonContent) : textContent;

    final cardBg = isDark ? const Color(0xFF111111) : Colors.white;
    final borderColor = isDark ? Colors.white12 : Colors.grey.shade300;
    final textColor = isDark ? Colors.white : Colors.black87;
    final innerBg = isDark ? const Color(0xFF050505) : const Color(0xFFF9FAFB);

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor, width: 1),
        boxShadow: isDark
            ? []
            : [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (kind.trim().isNotEmpty)
                  _buildKindChip(kind, status.isEmpty ? null : status, isDark),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      color: textColor,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: Icon(
                    Icons.copy,
                    color: isDark ? Colors.white70 : Colors.black54,
                    size: 18,
                  ),
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
                color: innerBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: borderColor, width: 1),
              ),
              child: SingleChildScrollView(
                child: _isJsonMode
                    ? SelectableText(
                        bodyText,
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 12,
                          color: textColor,
                        ),
                      )
                    : MarkdownBody(
                        data: bodyText,
                        styleSheet:
                            MarkdownStyleSheet.fromTheme(
                              Theme.of(context),
                            ).copyWith(
                              p: TextStyle(
                                color: textColor,
                                fontSize: 13,
                                height: 1.4,
                              ),
                              code: TextStyle(
                                backgroundColor: isDark
                                    ? const Color(0xFF222222)
                                    : const Color(0xFFE5E7EB),
                                fontFamily: 'monospace',
                                fontSize: 12,
                                color: isDark
                                    ? Colors.redAccent
                                    : Colors.red[800],
                              ),
                              codeblockDecoration: BoxDecoration(
                                color: isDark
                                    ? const Color(0xFF1E1E1E)
                                    : const Color(0xFFF3F4F6),
                                borderRadius: BorderRadius.circular(8),
                              ),
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
