import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import 'package:pasteboard/pasteboard.dart';
import '../services/firestore_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_highlight/flutter_highlight.dart';
import 'package:flutter_highlight/themes/monokai-sublime.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import '../models/chat.dart';
import '../models/message.dart';
import '../models/user_profile.dart';
import '../services/openrouter_service.dart';
import '../services/storage_service.dart';
import '../services/search_service.dart';
import '../services/image_generation_service.dart';
import '../services/notification_service.dart';
import '../services/context_service.dart';
import '../services/auth_service.dart';
import '../services/speech_to_text_service.dart';
import '../services/chart_generation_service.dart';
import '../services/calendar_service.dart';
import 'package:device_calendar/device_calendar.dart';
import '../widgets/sidebar.dart';
import '../widgets/message_bubble.dart';
import '../widgets/grey_notification.dart';
import 'package:fl_chart/fl_chart.dart';
import '../widgets/fullscreen_image_viewer.dart';
import 'settings_screen.dart';
import 'chat_summaries_screen.dart';
import '../widgets/add_to_calendar_panel.dart';
import 'package:read_pdf_text/read_pdf_text.dart';
import '../services/import_export_service.dart';
import 'package:share_plus/share_plus.dart';
import '../services/theme_service.dart';

final GlobalKey<ChatScreenState> chatScreenKey = GlobalKey<ChatScreenState>();

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => ChatScreenState();
}

class _CodeBlockRef {
  final int index;
  final String language;
  final String code;
  final String messageId;

  _CodeBlockRef({
    required this.index,
    required this.language,
    required this.code,
    required this.messageId,
  });
}

class _LineRange {
  final int start;
  final int end;

  const _LineRange(this.start, this.end);
}

class ChatScreenState extends State<ChatScreen> with WidgetsBindingObserver {
  final TextEditingController _messageController = TextEditingController();
  final FocusNode _messageFocusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();
  final OpenRouterService _openRouterService = OpenRouterService();
  final StorageService _storageService = StorageService();
  final SearchService _searchService = SearchService();
  final ImageGenerationService _imageGenService = ImageGenerationService();
  final ContextService _contextService = ContextService();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final SpeechToTextService _speechService = SpeechToTextService.instance;
  final ChartGenerationService _chartService = ChartGenerationService();
  final CalendarService _calendarService = CalendarService();
  final ImportExportService _importExportService = ImportExportService();

  // Çift geri tuşu için
  DateTime? _lastBackPressed;

  List<Chat> _chats = [];
  Chat? _currentChat;
  UserProfile? _userProfile;
  bool _isLoading = false;
  final List<File> _selectedImages = [];
  final List<String> _selectedImagesBase64 = [];
  // Storage'a kaydedilmeyen, sadece geçici olarak ekranda gösterilen sistem mesajları
  final List<Message> _ephemeralMessages = [];
  bool _showScrollToBottom = false;
  final Set<String> _selectedMessageIds = {};
  bool _isSelectionMode = false;
  bool _isAppInBackground = false;
  bool _showActionMenu = false;
  bool _isImageGenerationMode = false;
  bool _isWebSearchMode = false;
  bool _isCanvasMode = false;
  final Set<String> _handledControlTags =
      {}; // Track handled tags for current response
  bool _isThinkingMode = false;
  String _agentThinking = ''; // AI'ın düşünme süreci
  String _agentTerminal = ''; // Agent terminal çıktıları
  String _loadingMessage = 'Düşünüyor...';
  String? _activeResponseChatId; // AI cevap verirken hangi chat'e cevap veriyor
  bool _shouldStopResponse = false; // AI cevabını durdurmak için flag
  String _currentTypingText = ''; // Şu anda yazılan metin
  String? _stoppedMessageId; // Durdurulmuş mesajın ID'si
  String _partialResponse = ''; // Yarım kalan cevap
  String _fullResponseText = ''; // Tam AI cevabı
  bool _isTyping = false; // Typing animasyonu aktif mi
  String? _typingMessageId; // Typing animasyonu yapılan mesaj ID'si
  bool _notificationsEnabled = true;
  int _fontSizeIndex = 2;
  String? _fontFamily;
  bool _showSuggestions = false;
  bool _isMultiDeleteMode = false;
  final Set<String> _selectedChatIdsForDelete = {};
  bool _isRecordingVoice = false;
  double _recordLevel = 0.0;
  String _lastVoiceText = '';
  Timer? _silenceTimer;
  StreamSubscription? _contextSubscription;
  bool _isSmartContextEnabled = false;
  File? _pickedPdfFile;
  String? _pickedPdfText;
  bool _isTodoPanelOpen = false;
  List<Map<String, dynamic>> _currentTodoTasks = [];
  bool _isExporting = false;
  String? _exportLoadingMessage;

  StreamSubscription? _intentDataStreamSubscription;
  StreamSubscription? _intentDataStreamSubscriptionMedia;
  StreamSubscription? _groupMessagesSubscription; // Grup mesajları için stream
  Timer? _groupAiDebounceTimer; // Group AI response debouncer

  // Mention Panel States
  bool _showMentionPanel = false;
  String _mentionQuery = '';
  List<Map<String, dynamic>> _filteredMembers = [];

  static const MethodChannel _processTextChannel = MethodChannel(
    'com.example.foresee/process_text',
  );

  @override
  void initState() {
    super.initState();
    _loadData();
    _scrollController.addListener(_onScroll);
    _messageController.addListener(_onMessageTextChanged);
    WidgetsBinding.instance.addObserver(this);
    _initShareIntentListener();
    _initProcessTextListener();
    _requestPermissions();
    _initContextListener();
    _loadInitialSettings();
  }

  Future<void> _openChatSummaries(Chat chat) async {
    final result = await Navigator.of(context).push<Chat>(
      MaterialPageRoute(builder: (ctx) => ChatSummariesScreen(chat: chat)),
    );

    if (!mounted || result == null) return;

    setState(() {
      final index = _chats.indexWhere((c) => c.id == result.id);
      if (index != -1) {
        _chats[index] = result;
      }
      if (_currentChat?.id == result.id) {
        _currentChat = result;
      }
    });

    await _storageService.saveChats(_chats);
  }

  Future<void> _openTrash() async {
    final now = DateTime.now();
    final trashedChats =
        _chats
            .where(
              (c) =>
                  c.deletedAt != null &&
                  now.difference(c.deletedAt!).inDays < 7,
            )
            .toList()
          ..sort((a, b) => b.deletedAt!.compareTo(a.deletedAt!));

    if (trashedChats.isEmpty) {
      GreyNotification.show(context, 'Çöp kutusu boş');
      return;
    }

    await showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      isScrollControlled: true,
      builder: (ctx) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
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
                const Text(
                  'Çöp kutusu',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Sohbetler burada 7 gün boyunca tutulur. İstersen kalıcı olarak silebilir veya geri yükleyebilirsin.',
                  style: TextStyle(color: Colors.white60, fontSize: 13),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 260,
                  child: ListView.builder(
                    itemCount: trashedChats.length,
                    itemBuilder: (context, index) {
                      final chat = trashedChats[index];
                      final deletedAt = chat.deletedAt!;
                      final remaining =
                          const Duration(days: 7) - now.difference(deletedAt);
                      final remainingDays = remaining.inDays.clamp(0, 7);
                      return Container(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF222222),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white10),
                        ),
                        child: ListTile(
                          dense: true,
                          title: Text(
                            chat.title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            'Silinme: ${DateFormat('dd.MM.yyyy HH:mm').format(deletedAt)}  ·  Kalan: ${remainingDays}gün',
                            style: const TextStyle(
                              color: Colors.white54,
                              fontSize: 11,
                            ),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                tooltip: 'Geri yükle',
                                icon: const Icon(
                                  Icons.restore,
                                  color: Colors.white70,
                                  size: 20,
                                ),
                                onPressed: () async {
                                  setState(() {
                                    final index = _chats.indexWhere(
                                      (c) => c.id == chat.id,
                                    );
                                    if (index != -1) {
                                      _chats[index] = _chats[index].copyWith(
                                        deletedAt: null,
                                      );
                                    }
                                  });
                                  await _storageService.saveChats(_chats);
                                  if (!mounted) return;
                                  Navigator.of(ctx).pop();
                                },
                              ),
                              IconButton(
                                tooltip: 'Kalıcı sil',
                                icon: const Icon(
                                  Icons.delete_forever,
                                  color: Colors.redAccent,
                                  size: 20,
                                ),
                                onPressed: () async {
                                  setState(() {
                                    _chats.removeWhere((c) => c.id == chat.id);
                                    if (_currentChat?.id == chat.id) {
                                      _currentChat = null;
                                    }
                                  });
                                  await _storageService.saveChats(_chats);
                                  if (!mounted) return;
                                  Navigator.of(ctx).pop();
                                },
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () async {
                      setState(() {
                        _chats.removeWhere(
                          (c) =>
                              c.deletedAt != null &&
                              now.difference(c.deletedAt!).inDays < 7,
                        );
                        if (_currentChat != null &&
                            _currentChat!.deletedAt != null) {
                          _currentChat = null;
                        }
                      });
                      await _storageService.saveChats(_chats);
                      if (!mounted) return;
                      Navigator.of(ctx).pop();
                    },
                    child: const Text(
                      'Tümünü kalıcı sil',
                      style: TextStyle(
                        color: Colors.redAccent,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _insertPlainSelectedCode(String selected) {
    if (selected.trim().isEmpty) return;

    setState(() {
      final current = _messageController.text;
      final needsSpace = current.isNotEmpty && !current.endsWith(' ');
      final newText = needsSpace ? '$current $selected' : '$current$selected';
      _messageController.text = newText;
      _messageController.selection = TextSelection.fromPosition(
        TextPosition(offset: _messageController.text.length),
      );
    });

    _messageFocusNode.requestFocus();
  }

  Future<void> _startCanvasCodeAction(
    String mode,
    String language,
    String code,
  ) async {
    if (!mounted) return;

    final langLabel = language.isEmpty ? 'kod' : language;
    final fenceLang = language.isEmpty ? '' : language;

    String instruction;
    if (mode == 'shorten') {
      instruction =
          'Hiç konuşma, sadece aşağıdaki $langLabel bloğunu bozmadan, aynı davranışı koruyarak KISALT. '
          'Sadece TAM kod bloğunu döndür, açıklama veya yorum yazma.';
    } else if (mode == 'bug') {
      instruction =
          'Hiç konuşma, sadece aşağıdaki $langLabel bloğunda HATA ARA ve hataları düzelt. '
          'Davranışını bozma, sadece düzeltilmiş TAM kod bloğunu döndür, açıklama yazma.';
    } else {
      instruction =
          'Hiç konuşma, sadece aşağıdaki $langLabel bloğunu bozmadan OPTİMİZE ET. '
          'Okunabilirliği ve gerekirse performansı iyileştir, sadece TAM kod bloğunu döndür.';
    }

    final buffer = StringBuffer();
    buffer.writeln(instruction);
    buffer.writeln();
    buffer.writeln('```$fenceLang');
    buffer.writeln(code.trim());
    buffer.writeln('```');

    final payload = buffer.toString().trim();

    setState(() {
      _isCanvasMode = true;
      _isImageGenerationMode = false;
      _isWebSearchMode = false;
      _isThinkingMode = false;

      _messageController.text = payload;
      _messageController.selection = TextSelection.fromPosition(
        TextPosition(offset: _messageController.text.length),
      );
    });

    _messageFocusNode.requestFocus();
    await _sendMessage();
  }

  _LineRange _computeLineRangeFromSelection(
    String text,
    int startOffset,
    int endOffset,
  ) {
    if (text.isEmpty) {
      return const _LineRange(1, 1);
    }

    final lines = text.split('\n');
    int runningIndex = 0;
    int startLine = 1;
    int endLine = 1;

    // endOffset Flutter seçiminde genellikle son karakterden bir sonraki index
    final int effectiveEnd = (endOffset > 0) ? endOffset - 1 : 0;

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      final lineStart = runningIndex;
      final lineEnd = runningIndex + line.length; // '\n' hariç

      if (startOffset >= lineStart && startOffset <= lineEnd) {
        startLine = i + 1;
      }
      if (effectiveEnd >= lineStart && effectiveEnd <= lineEnd) {
        endLine = i + 1;
      }

      runningIndex = lineEnd + 1; // '\n'
    }

    if (endLine < startLine) {
      endLine = startLine;
    }

    return _LineRange(startLine, endLine);
  }

  void _handleCodeReferenceGenerated(String reference) {
    if (reference.isEmpty) return;

    setState(() {
      final current = _messageController.text;
      final needsSpace = current.isNotEmpty && !current.endsWith(' ');
      final newText = needsSpace
          ? '$current $reference '
          : '$current$reference ';
      _messageController.text = newText;
      _messageController.selection = TextSelection.fromPosition(
        TextPosition(offset: _messageController.text.length),
      );
    });

    _messageFocusNode.requestFocus();
  }

  void _openCodePanel(Message aiMessage) {
    final fullText = aiMessage.content;
    final codeBlockRegex = RegExp(r'```(\w+)?\n([\s\S]*?)```', multiLine: true);

    String language = 'text';
    String code = fullText;

    final match = codeBlockRegex.firstMatch(fullText);
    if (match != null) {
      final langGroup = (match.group(1) ?? '').trim();
      if (langGroup.isNotEmpty) {
        language = langGroup;
      }
      final body = match.group(2);
      if (body != null && body.trim().isNotEmpty) {
        code = body.trim();
      }
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final size = MediaQuery.of(sheetContext).size;
        bool isLoading = false;
        List<String> suggestions = [];
        int selectedVersionIndex = -1; // -1 for original
        final ScrollController panelScrollController = ScrollController();

        return StatefulBuilder(
          builder: (ctx, setStateDialog) {
            Future<void> runAnalysis() async {
              if (isLoading || suggestions.length >= 3) return;

              setStateDialog(() {
                isLoading = true;
                suggestions.add('');
                selectedVersionIndex = suggestions.length - 1;
              });

              String streamed = '';
              try {
                await _openRouterService.analyzeCode(
                  language: language,
                  code: code,
                  onToken: (token) {
                    if (token.isEmpty) return;
                    streamed += token;
                    setStateDialog(() {
                      suggestions[selectedVersionIndex] = streamed;
                    });
                  },
                  shouldStop: () => false,
                );
              } catch (e) {
                GreyNotification.show(context, 'Kod analiz edilemedi: $e');
              } finally {
                setStateDialog(() {
                  isLoading = false;
                });
              }
            }

            void saveSelectedVersion() async {
              String finalCode = selectedVersionIndex == -1
                  ? code
                  : suggestions[selectedVersionIndex];

              if (finalCode.trim().isEmpty) return;

              // Update main ChatScreen state
              setState(() {
                final chatIndex = _chats.indexWhere(
                  (c) => c.id == _currentChat!.id,
                );
                if (chatIndex == -1) return;
                final messages = [..._chats[chatIndex].messages];
                final idx = messages.indexWhere((m) => m.id == aiMessage.id);
                if (idx == -1) return;

                final original = messages[idx];
                final fenceLang = language.isEmpty || language == 'text'
                    ? ''
                    : language.toLowerCase();
                final updatedContent =
                    '```$fenceLang\n${finalCode.trim()}\n```';

                messages[idx] = original.copyWith(
                  content: updatedContent,
                  isChartCandidate: true,
                );
                _chats[chatIndex] = _chats[chatIndex].copyWith(
                  messages: messages,
                  updatedAt: DateTime.now(),
                );
                _currentChat = _chats[chatIndex];
              });

              // Update local state in the dialog/panel
              setStateDialog(() {
                code = finalCode;
                suggestions = [];
                selectedVersionIndex = -1;
              });

              await _storageService.saveChats(_chats);
              // Navigator.of(sheetContext).pop(); // REMOVED: keep panel open
              GreyNotification.show(
                context,
                'Kod başarıyla güncellendi ve kaydedildi',
              );
            }

            final theme = Theme.of(ctx);

            return Container(
              height: size.height * 0.9,
              decoration: const BoxDecoration(
                color: Color(0xFF0F0F0F),
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: SafeArea(
                top: true,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header with Save Button
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      child: Row(
                        children: [
                          TextButton.icon(
                            onPressed: saveSelectedVersion,
                            icon: const Icon(
                              Icons.save_outlined,
                              size: 18,
                              color: Colors.blueAccent,
                            ),
                            label: const Text(
                              'Kaydet',
                              style: TextStyle(
                                color: Colors.blueAccent,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          const Spacer(),
                          const Text(
                            'Kod analizi',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const Spacer(),
                          IconButton(
                            icon: const Icon(
                              Icons.close,
                              color: Colors.white54,
                            ),
                            onPressed: () {
                              Navigator.of(sheetContext).pop();
                            },
                          ),
                        ],
                      ),
                    ),
                    Divider(height: 1, color: themeService.isDarkMode ? Colors.white12 : Colors.black12),
                    Expanded(
                      child: Stack(
                        children: [
                          SingleChildScrollView(
                            controller: panelScrollController,
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Original Code Section
                                Row(
                                  children: [
                                    Radio<int>(
                                      value: -1,
                                      groupValue: selectedVersionIndex,
                                      activeColor: Colors.blueAccent,
                                      onChanged: (val) {
                                        setStateDialog(() {
                                          selectedVersionIndex = val!;
                                        });
                                      },
                                    ),
                                    const Text(
                                      'Orijinal kod',
                                      style: TextStyle(
                                        color: Colors.white70,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                                Container(
                                  width: double.infinity,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF161616),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: Colors.white10),
                                  ),
                                  padding: const EdgeInsets.all(12),
                                  child: HighlightView(
                                    code,
                                    language: language.isEmpty
                                        ? 'text'
                                        : language.toLowerCase(),
                                    theme: monokaiSublimeTheme,
                                    textStyle: const TextStyle(
                                      fontFamily: 'monospace',
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 24),

                                // Suggestions
                                ...List.generate(suggestions.length, (index) {
                                  final sugg = suggestions[index];
                                  return Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Radio<int>(
                                            value: index,
                                            groupValue: selectedVersionIndex,
                                            activeColor: Colors.blueAccent,
                                            onChanged: (val) {
                                              setStateDialog(() {
                                                selectedVersionIndex = val!;
                                              });
                                            },
                                          ),
                                          Text(
                                            'Önerilen kod ${index + 1}',
                                            style: const TextStyle(
                                              color: Colors.white70,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                      Container(
                                        width: double.infinity,
                                        margin: const EdgeInsets.only(
                                          bottom: 16,
                                        ),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF161616),
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          border: Border.all(
                                            color: Colors.white10,
                                          ),
                                        ),
                                        padding: const EdgeInsets.all(12),
                                        child: sugg.isEmpty
                                            ? const Text(
                                                'Analiz ediliyor...',
                                                style: TextStyle(
                                                  color: Colors.white38,
                                                  fontSize: 11,
                                                ),
                                              )
                                            : SelectableText(
                                                sugg,
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontFamily: 'monospace',
                                                  fontSize: 11,
                                                ),
                                              ),
                                      ),
                                    ],
                                  );
                                }),
                                const SizedBox(height: 100), // Bottom space
                              ],
                            ),
                          ),

                          // Scroll to suggestions button
                          if (suggestions.isNotEmpty && !isLoading)
                            Positioned(
                              bottom: 80,
                              right: 20,
                              child: FloatingActionButton.small(
                                heroTag: 'scroll_down_code',
                                backgroundColor: const Color(0xFF2A2A2A),
                                child: const Icon(
                                  Icons.keyboard_arrow_down,
                                  color: Colors.white,
                                ),
                                onPressed: () {
                                  panelScrollController.animateTo(
                                    panelScrollController
                                            .position
                                            .maxScrollExtent -
                                        100,
                                    duration: const Duration(milliseconds: 400),
                                    curve: Curves.easeOut,
                                  );
                                },
                              ),
                            ),
                        ],
                      ),
                    ),

                    // Analysis Action Button
                    Container(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                      child: SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton.icon(
                          onPressed: isLoading || suggestions.length >= 3
                              ? null
                              : runAnalysis,
                          icon: const Icon(Icons.auto_fix_high, size: 18),
                          label: Text(
                            isLoading
                                ? 'Analiz ediliyor...'
                                : (suggestions.length >= 3
                                      ? 'Maksimum analiz sayısına ulaşıldı'
                                      : 'Yeni analiz başlat'),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2563EB),
                            disabledBackgroundColor: Colors.white10,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _requestPermissions() async {
    // İzinleri kontrol et ve iste
    final permissions = await _contextService.checkPermissions();

    // Takvim izni
    if (!permissions['calendar']!) {
      await _contextService.requestCalendarPermission();
    }

    // Konum izni
    if (!permissions['location']!) {
      await _contextService.requestLocationPermission();
    }

    // Kişiler izni
    if (!permissions['contacts']!) {
      await _contextService.requestContactsPermission();
    }
  }

  void _togglePinChat(Chat chat) async {
    final index = _chats.indexWhere((c) => c.id == chat.id);
    if (index == -1) return;

    final current = _chats[index];
    final updated = current.copyWith(
      isPinned: !current.isPinned,
      updatedAt: DateTime.now(),
    );

    setState(() {
      _chats[index] = updated;
      if (_currentChat?.id == chat.id) {
        _currentChat = updated;
      }
    });

    await _storageService.saveChats(_chats);
  }

  void _initProcessTextListener() {
    // Process Text intent'ini dinle
    _processTextChannel.setMethodCallHandler((call) async {
      if (call.method == "processText") {
        final text = call.arguments as String?;
        if (text != null && text.isNotEmpty) {
          _handleProcessedText(text);
        }
      }
    });
  }

  void _handleProcessedText(String text) {
    if (!mounted) return;

    // Yeni chat oluştur veya mevcut chat'e ekle
    if (_currentChat == null) {
      _createNewChat();
    }

    // Metni input alanına ekle
    setState(() {
      _messageController.text = text;
    });

    // Kullanıcıya bilgi ver
    GreyNotification.show(context, 'Seçilen metin eklendi');
  }

  void _initShareIntentListener() {
    // Metin paylaşımını dinle (SEND intent)
    // Görsel paylaşımını dinle (SEND intent)
    _intentDataStreamSubscription = ReceiveSharingIntent.instance
        .getMediaStream()
        .listen(
          (List<SharedMediaFile> sharedMedia) {
            if (!mounted) return;
            if (sharedMedia.isEmpty) return;

            final textItems = sharedMedia
                .where(
                  (m) =>
                      m.type == SharedMediaType.text ||
                      m.type == SharedMediaType.url,
                )
                .toList();

            final mediaItems = sharedMedia
                .where(
                  (m) =>
                      m.type == SharedMediaType.image ||
                      m.type == SharedMediaType.video ||
                      m.type == SharedMediaType.file,
                )
                .toList();

            if (textItems.isNotEmpty) {
              final combinedText = textItems
                  .map((m) => m.path)
                  .where((path) => path.isNotEmpty)
                  .join('\n');
              if (combinedText.isNotEmpty) {
                _handleSharedText(combinedText);
              }
            }

            if (mediaItems.isNotEmpty) {
              _handleSharedMedia(mediaItems);
            }
          },
          onError: (err) {
            print('Paylaşım hatası (metin/görsel): $err');
          },
        );

    // İlk paylaşılan metni al (uygulama zaten açıksa)
    // İlk paylaşılan görseli al (uygulama zaten açıksa)
    ReceiveSharingIntent.instance.getInitialMedia().then((
      List<SharedMediaFile> sharedMedia,
    ) {
      if (!mounted) return;
      if (sharedMedia.isEmpty) return;

      final textItems = sharedMedia
          .where(
            (m) =>
                m.type == SharedMediaType.text || m.type == SharedMediaType.url,
          )
          .toList();

      final mediaItems = sharedMedia
          .where(
            (m) =>
                m.type == SharedMediaType.image ||
                m.type == SharedMediaType.video ||
                m.type == SharedMediaType.file,
          )
          .toList();

      if (textItems.isNotEmpty) {
        final combinedText = textItems
            .map((m) => m.path)
            .where((path) => path.isNotEmpty)
            .join('\n');
        if (combinedText.isNotEmpty) {
          _handleSharedText(combinedText);
        }
      }

      if (mediaItems.isNotEmpty) {
        _handleSharedMedia(mediaItems);
      }

      ReceiveSharingIntent.instance.reset();
    });
  }

  void _handleSharedText(String sharedText) {
    if (!mounted) return;

    // Yeni chat oluştur veya mevcut chat'e ekle
    if (_currentChat == null) {
      _createNewChat();
    }

    // Metni input alanına ekle
    setState(() {
      _messageController.text = sharedText;
    });

    // Kullanıcıya bilgi ver
    GreyNotification.show(context, 'Paylaşılan metin eklendi');
  }

  Future<void> _handleSharedMedia(List<SharedMediaFile> sharedMedia) async {
    if (!mounted) return;

    // Yeni chat oluştur veya mevcut chat'e ekle
    if (_currentChat == null) {
      _createNewChat();
    }

    // Dosyaları ve görselleri işle
    int importedCount = 0;
    int imageCount = 0;

    for (final media in sharedMedia) {
      if (media.path.isNotEmpty) {
        if (media.path.endsWith('.fs')) {
          final success = await _handleIncomingFsFile(media.path);
          if (success) importedCount++;
          continue;
        }

        try {
          final file = File(media.path);
          if (await file.exists()) {
            await _processSelectedFile(file);
            imageCount++;
          }
        } catch (e) {
          print('Paylaşılan öğe işleme hatası: $e');
        }
      }
    }

    // Kullanıcıya bilgi ver
    if (importedCount > 0) {
      // Mesaj zaten _handleIncomingFsFile içinde veriliyor veya topluca verilebilir
    } else if (imageCount > 0) {
      if (imageCount == 1) {
        GreyNotification.show(context, 'Paylaşılan görsel eklendi');
      } else {
        GreyNotification.show(context, '$imageCount görsel eklendi');
      }
    }
  }

  Future<bool> _handleIncomingFsFile(String path) async {
    try {
      setState(() {
        _isLoading = true;
        _loadingMessage = 'Sohbet içe aktarılıyor...';
      });

      final file = File(path);
      final chat = await _importExportService.importChatFromFs(file);

      setState(() => _isLoading = false);

      if (chat != null) {
        setState(() {
          _chats.insert(0, chat);
          _currentChat = chat;
        });
        await _storageService.saveChats(_chats);
        GreyNotification.show(context, 'Sohbet başarıyla içe aktarıldı');
        return true;
      } else {
        GreyNotification.show(
          context,
          'Sohbet dosyası okunamadı veya geçersiz',
        );
        return false;
      }
    } catch (e) {
      setState(() => _isLoading = false);
      GreyNotification.show(context, 'İçe aktarma hatası: $e');
      return false;
    }
  }

  Future<void> _handleSignOut() async {
    try {
      await AuthService.instance.signOut();
      if (!mounted) return;
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (!mounted) return;
      GreyNotification.show(context, 'Çıkış yapılamadı: $e');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    _isAppInBackground = state != AppLifecycleState.resumed;
  }

  @override
  void didChangeMetrics() {
    super.didChangeMetrics();
    // Klavye yüksekliği değiştiğinde (açıldığında/kapandığında)
    final bottomInset = WidgetsBinding.instance.window.viewInsets.bottom;
    if (bottomInset > 0) {
      // Klavye açıldı, en alta kaydır
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted && !_showScrollToBottom) {
          _scrollToBottomQuick();
        }
      });
    }
  }

  void _onScroll() {
    if (_scrollController.hasClients) {
      // Daha uzun mesaj listelerinde butonu daha erken göster
      final isAtBottom =
          _scrollController.offset >=
          _scrollController.position.maxScrollExtent - 200; // 200px threshold

      if (_showScrollToBottom == isAtBottom) {
        setState(() {
          _showScrollToBottom = !isAtBottom;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bool showEmptyState =
        (_currentChat == null ||
            ((_currentChat?.messages.isEmpty ?? true) &&
                _ephemeralMessages.isEmpty)) &&
        !_showMentionPanel;
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        key: _scaffoldKey,
        resizeToAvoidBottomInset: true, // Klavye açılınca otomatik küçült
        backgroundColor: theme.scaffoldBackgroundColor,
        drawer: _userProfile != null ? Sidebar(
          chats: _chats,
          currentChat: _currentChat,
          userProfile: _userProfile!,
          onChatSelected: _handleChatSelected,
          onNewChat: _createNewChat,
          onProfileUpdated: _handleProfileUpdated,
          onChatDelete: _handleChatDelete,
          onChatEdit: _handleChatEdit,
          onSettingsPressed: _openSettings,
          onSearchChats: _openChatSearch,
          isMultiDeleteMode: _isMultiDeleteMode,
          selectedChatIdsForDelete: _selectedChatIdsForDelete,
          onMultiDeletePressed: _handleMultiDeletePressed,
          onChatToggleSelection: _handleChatToggleSelection,
          onMultiDeleteCancel: _handleMultiDeleteCancel,
          onSignOut: _handleSignOut,
          onOpenTrash: _openTrash,
          onChatTogglePin: _togglePinChat,
          onOpenChatSummaries: _openChatSummaries,
          onImportChat: _handleFsImport,
          onExportPdf: _handlePdfExport,
          onExportFs: _handleFsExport,
        ) : null,
        body: SafeArea(
          child: Stack(
            children: [
              Column(
                children: [
                  _buildHeader(),
                  Expanded(
                    child: showEmptyState
                        ? _buildEmptyState()
                        : _buildMessageList(),
                  ),
                  if (_showMentionPanel) _buildMentionPanel(),
                  _buildInputArea(),
                ],
              ),
              if (_isExporting) _buildExportOverlay(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildExportOverlay() {
    return Container(
      color: Colors.black.withOpacity(0.85),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(
              color: Colors.white,
              strokeWidth: 3,
            ),
            const SizedBox(height: 24),
            Text(
              _exportLoadingMessage ?? 'Lütfen bekleyin...',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCodeReferenceChips() {
    final refs = _extractCodeReferencesFromText(_messageController.text);
    if (refs.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 6),
      child: Wrap(
        spacing: 6,
        runSpacing: 4,
        children: refs.map((ref) {
          final block = ref['block'] ?? 0;
          final line = ref['line'] ?? 0;
          final label = 'cb$block · satır $line';
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.16),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.blue.withOpacity(0.5),
                width: 0.8,
              ),
            ),
            child: Text(
              label,
              style: TextStyle(
                color: Colors.blue.shade300,
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  List<Widget> _buildTodoTaskList() {
    return _currentTodoTasks.asMap().entries.map((entry) {
      final index = entry.key;
      final task = entry.value;
      final title = (task['title'] ?? 'Görev ${index + 1}').toString();
      final description = (task['description'] ?? '').toString();
      final bool isCompleted = (task['completed'] ?? false) == true;

      return Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isCompleted ? Colors.green.withOpacity(0.3) : Colors.white10,
          ),
        ),
        child: ListTile(
          dense: true,
          onTap: () => _toggleTodoTask(index),
          leading: Icon(
            isCompleted ? Icons.check_circle : Icons.radio_button_unchecked,
            color: isCompleted ? Colors.green : Colors.white30,
            size: 18,
          ),
          title: Text(
            title,
            style: TextStyle(
              color: isCompleted ? Colors.white54 : Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w500,
              decoration: isCompleted ? TextDecoration.lineThrough : null,
            ),
          ),
          subtitle: description.isNotEmpty
              ? Text(
                  description,
                  style: const TextStyle(color: Colors.white38, fontSize: 11),
                )
              : null,
        ),
      );
    }).toList();
  }

  Widget _buildAgentTerminalSection() {
    return Container(
      margin: const EdgeInsets.only(top: 16),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: const BoxDecoration(
              color: Color(0xFF1A1A1A),
              borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
            ),
            child: Row(
              children: [
                const Icon(Icons.terminal, size: 14, color: Colors.white54),
                const SizedBox(width: 8),
                const Text(
                  'TERMINAL',
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () => setState(() => _agentTerminal = ''),
                  child: const Icon(
                    Icons.delete_sweep,
                    size: 14,
                    color: Colors.white38,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(10),
            width: double.infinity,
            constraints: const BoxConstraints(maxHeight: 200),
            child: SingleChildScrollView(
              child: Text(
                _agentTerminal,
                style: const TextStyle(
                  color: Colors.greenAccent,
                  fontFamily: 'monospace',
                  fontSize: 11,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAgentPanelFooter() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: const BoxDecoration(
        color: Color(0xFF1A1A1A),
        border: Border(top: BorderSide(color: Colors.white12)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              _buildAgentActionBtn(Icons.file_open, 'Dosyalar', () {}),
              const SizedBox(width: 8),
              _buildAgentActionBtn(Icons.play_arrow, 'Çalıştır', () {}),
              const SizedBox(width: 8),
              _buildAgentActionBtn(Icons.download, 'İndir', () {
                _handleFsExport();
              }),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAgentActionBtn(IconData icon, String label, VoidCallback onTap) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: Colors.white12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: Colors.white70),
              const SizedBox(height: 2),
              Text(
                label,
                style: const TextStyle(color: Colors.white54, fontSize: 10),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _toggleTodoTask(int index) {
    if (index < 0 || index >= _currentTodoTasks.length) return;

    setState(() {
      final List<Map<String, dynamic>> updated = _currentTodoTasks
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
      final current = updated[index]['completed'] == true;
      updated[index]['completed'] = !current;
      _currentTodoTasks = updated;

      if (_currentChat != null) {
        final chatIndex = _chats.indexWhere((c) => c.id == _currentChat!.id);
        if (chatIndex != -1) {
          final updatedChat = _chats[chatIndex].copyWith(
            projectTasks: updated,
            updatedAt: DateTime.now(),
          );
          _chats[chatIndex] = updatedChat;
          if (_currentChat!.id == updatedChat.id) {
            _currentChat = updatedChat;
          }
        }
      }
    });

    _storageService.saveChats(_chats);
  }

  void _openChatSearch() {
    if (_chats.isEmpty) {
      GreyNotification.show(context, 'Henüz sohbet yok');
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (bottomSheetContext) {
        final TextEditingController searchController = TextEditingController();
        List<Chat> filteredChats = List<Chat>.from(_chats);

        void runSearch(
          String query,
          void Function(void Function()) setModalState,
        ) {
          final q = query.trim();
          if (q.isEmpty) {
            setModalState(() {
              filteredChats = List<Chat>.from(_chats);
            });
            return;
          }

          final List<Chat> newList = [];
          for (final chat in _chats) {
            final title = chat.title;
            if (title.isEmpty) continue;
            final score = _fuzzyScore(q, title);
            if (score >= 0.35) {
              newList.add(chat);
            }
          }

          newList.sort((a, b) {
            final aScore = _fuzzyScore(q, a.title);
            final bScore = _fuzzyScore(q, b.title);
            return bScore.compareTo(aScore);
          });

          setModalState(() {
            filteredChats = newList;
          });
        }

        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 12,
            bottom: MediaQuery.of(bottomSheetContext).viewInsets.bottom + 16,
          ),
          child: StatefulBuilder(
            builder: (context, setModalState) {
              return Column(
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
                  TextField(
                    controller: searchController,
                    autofocus: true,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Sohbet başlığında ara...',
                      hintStyle: const TextStyle(color: Colors.white54),
                      prefixIcon: const Icon(
                        Icons.search,
                        color: Colors.white54,
                        size: 18,
                      ),
                      filled: true,
                      fillColor: const Color(0xFF2A2A2A),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onChanged: (value) => runSearch(value, setModalState),
                  ),
                  const SizedBox(height: 12),
                  if (filteredChats.isEmpty &&
                      searchController.text.trim().isNotEmpty)
                    const Text(
                      'Sohbet bulunamadı',
                      style: TextStyle(color: Colors.white60, fontSize: 13),
                    )
                  else
                    SizedBox(
                      height: 320,
                      child: ListView.builder(
                        itemCount: filteredChats.length,
                        itemBuilder: (context, index) {
                          final chat = filteredChats[index];
                          return ListTile(
                            dense: true,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 0,
                              vertical: 4,
                            ),
                            title: Text(
                              chat.title.isEmpty
                                  ? 'İsimsiz sohbet'
                                  : chat.title,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            onTap: () {
                              Navigator.of(bottomSheetContext).pop();
                              setState(() {
                                _currentChat = chat;
                              });
                            },
                          );
                        },
                      ),
                    ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  String _normalizeText(String input) {
    final lower = input.toLowerCase();
    return lower
        .replaceAll('ç', 'c')
        .replaceAll('ğ', 'g')
        .replaceAll('ı', 'i')
        .replaceAll('ö', 'o')
        .replaceAll('ş', 's')
        .replaceAll('ü', 'u');
  }

  double _fuzzyScore(String query, String text) {
    final q = _normalizeText(query).trim();
    final t = _normalizeText(text);
    if (q.isEmpty || t.isEmpty) return 0.0;
    if (t.contains(q)) {
      return 1.0;
    }

    int qi = 0;
    int matches = 0;
    for (int i = 0; i < t.length && qi < q.length; i++) {
      if (t.codeUnitAt(i) == q.codeUnitAt(qi)) {
        matches++;
        qi++;
      }
    }

    return matches / q.length;
  }

  void _jumpToMessage(String chatId, int messageIndex) {
    if (!mounted) return;

    if (_currentChat == null || _currentChat!.id != chatId) {
      final chatIndex = _chats.indexWhere((c) => c.id == chatId);
      if (chatIndex == -1) return;
      setState(() {
        _currentChat = _chats[chatIndex];
      });
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      final approxOffset = (messageIndex * 72.0).toDouble();
      final maxExtent = _scrollController.position.maxScrollExtent;
      final target = approxOffset.clamp(0.0, maxExtent);
      _scrollController.animateTo(
        target,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      );
    });
  }

  Widget _buildHeader() {
    final theme = Theme.of(context);
    final hasPinnedMessages =
        _currentChat != null && _currentChat!.pinnedMessageIds.isNotEmpty;

    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Stack(
        children: [
          // Sol: Menu Butonu
          Align(
            alignment: Alignment.centerLeft,
            child: IconButton(
              icon: Icon(
                Icons.menu,
                color: theme.brightness == Brightness.dark
                    ? Colors.white
                    : Colors.black87,
              ),
              onPressed: () => _scaffoldKey.currentState?.openDrawer(),
            ),
          ),
          // Orta: Logo
          Center(
            child: Image.asset(
              themeService.getLogoPath('logo.png'),
              height: 48, // Logo büyütüldü
              fit: BoxFit.contain,
            ),
          ),
          // Sağ: Aksiyon Butonları
          Align(
            alignment: Alignment.centerRight,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (hasPinnedMessages)
                  IconButton(
                    icon: const Icon(Icons.push_pin, size: 18),
                    color: Colors.white,
                    onPressed: _openPinnedMessages,
                  ),
                IconButton(
                  icon: FaIcon(
                    FontAwesomeIcons.plus,
                    size: 18,
                    color: theme.brightness == Brightness.dark
                        ? Colors.white
                        : Colors.black87,
                  ),
                  onPressed: _createNewChat,
                ),
                if (_currentChat != null) ...[
                  if (!_currentChat!.isGroup)
                    IconButton(
                      icon: FaIcon(
                        FontAwesomeIcons.userPlus,
                        size: 18,
                        color: _hasUserSentMessage(_currentChat!)
                            ? (theme.brightness == Brightness.dark
                                ? Colors.white
                                : Colors.black87)
                            : Colors.grey,
                      ),
                      tooltip: 'Grup Oluştur',
                      onPressed: _hasUserSentMessage(_currentChat!)
                          ? _handleCreateGroupChat
                          : null,
                    )
                  else
                    IconButton(
                      icon: FaIcon(
                        FontAwesomeIcons.gear,
                        size: 18,
                        color: theme.brightness == Brightness.dark
                            ? Colors.white
                            : Colors.black87,
                      ),
                      tooltip: 'Grup Ayarları',
                      onPressed: _showGroupSettingsPanel,
                    ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    final theme = Theme.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Merhaba, ben ForeSee',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: theme.brightness == Brightness.dark
                    ? Colors.white
                    : Colors.black87,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Sana nasıl yardımcı olabilirim?',
              style: TextStyle(
                fontSize: 16,
                color: theme.brightness == Brightness.dark
                    ? Colors.white70
                    : Colors.black54,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            GestureDetector(
              onTap: () {
                setState(() {
                  _showSuggestions = !_showSuggestions;
                });
              },
              child: Column(
                children: [
                  Text(
                    'Öneriler',
                    style: TextStyle(
                      color: Colors.blueAccent,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Icon(
                    _showSuggestions
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    color: theme.brightness == Brightness.dark ? Colors.white : Colors.black87,
                    size: 18,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            AnimatedCrossFade(
              firstChild: const SizedBox.shrink(),
              secondChild: Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  _buildPromptTemplateButton('Günlük planımı çıkar'),
                  _buildPromptTemplateButton(
                    'Profesyonel bir e-posta taslağı yaz',
                  ),
                  _buildPromptTemplateButton(
                    'CV\'mi gözden geçir ve iyileştir',
                  ),
                  _buildPromptTemplateButton('Instagram post metni yaz: '),
                  _buildPromptTemplateButton(
                    'Bugünün önemli haberlerini özetle',
                  ),
                  _buildPromptTemplateButton(
                    'İş görüşmesi için soru listesi hazırla',
                  ),
                ],
              ),
              crossFadeState: _showSuggestions
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              duration: const Duration(milliseconds: 200),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPromptTemplateButton(String text) {
    return InkWell(
      onTap: () {
        setState(() {
          _messageController.text = text;
          _messageController.selection = TextSelection.fromPosition(
            TextPosition(offset: _messageController.text.length),
          );
        });
        FocusScope.of(context).requestFocus(_messageFocusNode);
      },
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: themeService.isDarkMode ? const Color(0xFF1A1A1A) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: themeService.isDarkMode ? Colors.white24 : Colors.grey[300]!),
        ),
        child: Text(
          text,
          style: TextStyle(color: themeService.isDarkMode ? Colors.white : Colors.black87, fontSize: 13),
        ),
      ),
    );
  }

  Widget _buildMessageList() {
    final baseMessages = _currentChat?.messages ?? [];
    final ephemeral = _ephemeralMessages;
    final allMessages = [...baseMessages, ...ephemeral];

    // Global kod bloğu indekslerini mesaj bazında grupla
    final Map<String, List<int>> cbIndicesByMessageId = {};
    if (_currentChat != null) {
      final blocks = _collectCodeBlocksFromChat(_currentChat!);
      for (final block in blocks) {
        cbIndicesByMessageId
            .putIfAbsent(block.messageId, () => <int>[])
            .add(block.index);
      }
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      itemCount: allMessages.length,
      itemBuilder: (context, index) {
        final message = allMessages[index];

        final isLastAiMessage =
            !message.isUser && index == allMessages.length - 1;

        final isTypingBubble =
            !message.isUser && _isTyping && message.id == _typingMessageId;

        final baseMsgCount = baseMessages.length;
        final isFromBase = index < baseMsgCount;
        final isPinned =
            isFromBase &&
            (_currentChat?.pinnedMessageIds.contains(message.id) ?? false);

        final codeBlockIndices =
            (!message.isUser && cbIndicesByMessageId.isNotEmpty)
            ? cbIndicesByMessageId[message.id]
            : null;

        return RepaintBoundary(
          child: MessageBubble(
            key: ValueKey(message.id),
            message: message,
            userProfileColor: _userProfile?.profileColor ?? Colors.blue,
            isSelected: _selectedMessageIds.contains(message.id),
            onLongPress: _isSelectionMode
                ? () {
                    setState(() {
                      if (_selectedMessageIds.contains(message.id)) {
                        _selectedMessageIds.remove(message.id);
                        if (_selectedMessageIds.isEmpty) {
                          _isSelectionMode = false;
                        }
                      } else {
                        _selectedMessageIds.add(message.id);
                      }
                    });
                  }
                : null,
            onContinue: message.isStopped && message.id == _stoppedMessageId
                ? _continueResponse
                : null,
            fontSizeIndex: _fontSizeIndex,
            fontFamily: _fontFamily,
            isLastAiMessage: isLastAiMessage,
            onRetry: isLastAiMessage ? _retryAiMessage : null,
            onWebCapture: _handleWebCapture,
            isTyping: isTypingBubble,
            loadingMessage: isTypingBubble
                ? (_currentChat?.isGroup == true ? '...' : _loadingMessage)
                : null,
            onQuickAction: (actionId, msg) => _handleQuickAction(actionId, msg),
            onPin: isFromBase ? _togglePinMessage : null,
            isPinned: isPinned,
            codeBlockIndices: codeBlockIndices,
            onCodeReferenceGenerated: _handleCodeReferenceGenerated,
            onSettingsLinkTapped: _navigateToSetting,
            onAlternativeSelected: _handleAlternativeSelected,
            reasoning:
                _activeResponseChatId == _currentChat?.id && isTypingBubble
                ? _agentThinking
                : null,
            onShowReasoning: () => _showReasoningSheet(_agentThinking),
          ),
        );
      },
    );
  }

  void _togglePinMessage(Message message) {
    if (_currentChat == null) return;

    final chat = _currentChat!;
    final isPinned = chat.pinnedMessageIds.contains(message.id);
    final updatedPinned = List<String>.from(chat.pinnedMessageIds);

    if (isPinned) {
      updatedPinned.remove(message.id);
    } else {
      updatedPinned.add(message.id);
    }

    final updatedChat = chat.copyWith(
      pinnedMessageIds: updatedPinned,
      updatedAt: DateTime.now(),
    );

    setState(() {
      final index = _chats.indexWhere((c) => c.id == chat.id);
      if (index != -1) {
        _chats[index] = updatedChat;
      }
      _currentChat = updatedChat;
    });

    _storageService.saveChats(_chats);

    GreyNotification.show(
      context,
      isPinned ? 'Mesaj sabitlemeden kaldırıldı' : 'Mesaj sabitlendi',
    );
  }

  void _openPinnedMessages() {
    if (_currentChat == null) {
      GreyNotification.show(context, 'Önce bir sohbet seçin');
      return;
    }

    final chat = _currentChat!;
    if (chat.pinnedMessageIds.isEmpty) {
      GreyNotification.show(context, 'Bu sohbette sabitlenmiş mesaj yok');
      return;
    }

    final messages = chat.messages;
    final pinnedEntries = <Map<String, dynamic>>[];

    for (int i = 0; i < messages.length; i++) {
      final msg = messages[i];
      if (chat.pinnedMessageIds.contains(msg.id)) {
        pinnedEntries.add({'index': i, 'message': msg});
      }
    }

    if (pinnedEntries.isEmpty) {
      GreyNotification.show(context, 'Bu sohbette sabitlenmiş mesaj yok');
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (bottomSheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
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
                Row(
                  children: const [
                    Icon(Icons.push_pin, color: Colors.white70, size: 18),
                    SizedBox(width: 8),
                    Text(
                      'Sabitlenmiş Mesajlar',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '${pinnedEntries.length} sabitlenmiş mesaj var',
                  style: const TextStyle(color: Colors.white60, fontSize: 13),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 260,
                  child: ListView.separated(
                    itemCount: pinnedEntries.length,
                    separatorBuilder: (context, index) =>
                        const Divider(color: Colors.white24, height: 12),
                    itemBuilder: (context, index) {
                      final entry = pinnedEntries[index];
                      final Message msg = entry['message'] as Message;
                      final int msgIndex = entry['index'] as int;
                      final fullText = msg.content.trim();
                      final displayText = fullText.isEmpty
                          ? '[Boş mesaj]'
                          : fullText;

                      return ListTile(
                        dense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 0,
                          vertical: 4,
                        ),
                        leading: const Icon(
                          Icons.push_pin,
                          color: Colors.white70,
                          size: 18,
                        ),
                        title: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              '•',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 18,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                displayText,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 2),
                            const Text(
                              'devamını göster...',
                              style: TextStyle(
                                color: Colors.white38,
                                fontSize: 11,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              msg.isUser ? 'Kullanıcı' : 'ForeSee',
                              style: const TextStyle(
                                color: Colors.white54,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                        onTap: () {
                          Navigator.of(bottomSheetContext).pop();
                          Future.microtask(() {
                            _jumpToMessage(chat.id, msgIndex);
                          });
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // WebView'den alınan ekran görüntüsünü doğrudan AI sohbetine gönder
  Future<void> _handleWebCapture(Uint8List bytes) async {
    if (_activeResponseChatId != null) {
      GreyNotification.show(
        context,
        'AI cevap veriyor, lütfen bitmesini bekleyin',
      );
      return;
    }

    try {
      final tempDir = await getTemporaryDirectory();
      final filePath =
          '${tempDir.path}/web_capture_${DateTime.now().millisecondsSinceEpoch}.png';
      final file = File(filePath);
      await file.writeAsBytes(bytes);

      setState(() {
        _selectedImages.clear();
        _selectedImagesBase64.clear();
      });

      await _processSelectedFile(file);

      // Sadece görsel içeren bir mesaj olarak gönder
      _messageController.clear();
      await _sendMessage();
    } catch (_) {
      if (!mounted) return;
      GreyNotification.show(context, 'Görsel gönderilemedi');
    }
  }

  String _formatQuickActionResult(String actionId, String rawText) {
    final trimmed = rawText.trim();
    if (trimmed.isEmpty) return trimmed;

    String title;
    if (actionId == 'summary') {
      title = 'Özetlenmiş hali';
    } else if (actionId == 'bullets') {
      title = 'Maddeler halinde';
    } else if (actionId == 'continue') {
      title = 'Devamı';
    } else if (actionId == 'translate_tr') {
      title = 'Türkçe çeviri';
    } else if (actionId == 'translate_en') {
      title = 'İngilizce çeviri';
    } else if (actionId == 'translate_de') {
      title = 'Almanca çeviri';
    } else if (actionId == 'translate_fr') {
      title = 'Fransızca çeviri';
    } else if (actionId == 'translate_es') {
      title = 'İspanyolca çeviri';
    } else if (actionId == 'translate_it') {
      title = 'İtalyanca çeviri';
    } else if (actionId == 'translate_ru') {
      title = 'Rusça çeviri';
    } else if (actionId == 'translate_ar') {
      title = 'Arapça çeviri';
    } else if (actionId == 'translate_ja') {
      title = 'Japonca çeviri';
    } else if (actionId == 'translate_zh') {
      title = 'Çince çeviri';
    } else {
      return trimmed;
    }

    return '**$title**\n\n$trimmed';
  }

  void _handleQuickAction(String actionId, Message aiMessage) async {
    if (actionId == 'code_panel') {
      _openCodePanel(aiMessage);
      return;
    } else if (actionId == 'generate_chart') {
      _generateChartForMessage(aiMessage);
      return;
    }

    if (_activeResponseChatId != null) {
      GreyNotification.show(context, 'AI cevap veriyor, lütfen bekleyin...');
      return;
    }

    if (_currentChat == null) {
      GreyNotification.show(context, 'Aktif sohbet bulunamadı');
      return;
    }

    final chat = _currentChat!;
    final targetChatId = chat.id;

    final messages = chat.messages;
    final aiIndex = messages.indexWhere((m) => m.id == aiMessage.id);
    if (aiIndex == -1) {
      GreyNotification.show(context, 'Hedef AI mesajı bulunamadı');
      return;
    }

    String instruction;
    List<Map<String, dynamic>> conversationHistory;

    // ÇEVİRİ AKSİYONLARI: Mesajı yerinde yeniden yaz
    if (actionId.startsWith('translate_')) {
      final content = aiMessage.content.trim();
      if (content.isEmpty) {
        GreyNotification.show(context, 'Çevrilecek metin yok');
        return;
      }

      String targetLabel;
      switch (actionId) {
        case 'translate_tr':
          targetLabel = 'TÜRKÇE';
          break;
        case 'translate_en':
          targetLabel = 'İNGİLİZCE';
          break;
        case 'translate_de':
          targetLabel = 'ALMANCA';
          break;
        case 'translate_fr':
          targetLabel = 'FRANSIZCA';
          break;
        case 'translate_es':
          targetLabel = 'İSPANYOLCA';
          break;
        case 'translate_it':
          targetLabel = 'İTALYANCA';
          break;
        case 'translate_ru':
          targetLabel = 'RUSÇA';
          break;
        case 'translate_ar':
          targetLabel = 'ARAPÇA';
          break;
        case 'translate_ja':
          targetLabel = 'JAPONCA';
          break;
        case 'translate_zh':
          targetLabel = 'ÇİNCE';
          break;
        default:
          return;
      }

      final translatePrompt =
          'Aşağıdaki metni sadece $targetLabel DİLİNE ÇEVİR. Ek açıklama, yorum veya başka dilde cümle yazma, sadece çeviriyi ver.\n\n$content';

      setState(() {
        _isLoading = true;
      });

      try {
        final translated = await _openRouterService.sendMessageWithHistory(
          const [],
          translatePrompt,
        );
        final newText = translated.trim();
        if (newText.isEmpty) {
          GreyNotification.show(context, 'Çeviri sonucu boş geldi');
        } else {
          setState(() {
            final chatIndex = _chats.indexWhere((c) => c.id == targetChatId);
            if (chatIndex != -1) {
              final msgs = [..._chats[chatIndex].messages];
              final msgIndex = msgs.indexWhere((m) => m.id == aiMessage.id);
              if (msgIndex != -1) {
                msgs[msgIndex] = msgs[msgIndex].copyWith(content: newText);
                _chats[chatIndex] = _chats[chatIndex].copyWith(
                  messages: msgs,
                  updatedAt: DateTime.now(),
                );
                if (_currentChat?.id == targetChatId) {
                  _currentChat = _chats[chatIndex];
                }
              }
            }
          });
          GreyNotification.show(context, 'Mesaj çevirildi');
        }

        await _storageService.saveChats(_chats);
      } catch (e) {
        GreyNotification.show(context, 'Çeviri tamamlanamadı: $e');
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }

      return;
    }

    if (actionId == 'summary') {
      instruction =
          'Bir önceki cevabını kullanıcının göreceği şekilde kısaca özetle. '
          'Sadece yeni özeti döndür, başka açıklama yazma.';
      conversationHistory = messages
          .sublist(0, aiIndex + 1)
          .map(
            (msg) => {
              'role': msg.isUser ? 'user' : 'assistant',
              'content': msg.content,
            },
          )
          .toList();
    } else if (actionId == 'bullets') {
      instruction =
          'Bir önceki cevabını önemli noktalar halinde madde madde yaz. '
          'Sadece madde madde listeyi döndür, başka açıklama yazma.';
      conversationHistory = messages
          .sublist(0, aiIndex + 1)
          .map(
            (msg) => {
              'role': msg.isUser ? 'user' : 'assistant',
              'content': msg.content,
            },
          )
          .toList();
    } else if (actionId == 'continue') {
      instruction =
          'Bir önceki cevabını aynı üslup ve bağlamı koruyarak detaylandır ve devam et. '
          'Sadece devam metnini döndür.';
      conversationHistory = messages
          .sublist(0, aiIndex + 1)
          .map(
            (msg) => {
              'role': msg.isUser ? 'user' : 'assistant',
              'content': msg.content,
            },
          )
          .toList();
    } else {
      return;
    }

    // Orijinal AI mesajını bozmadan, hemen altına yeni bir AI mesajı ekle
    final derivedMessage = Message(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      chatId: targetChatId,
      content: '',
      isUser: false,
      timestamp: DateTime.now(),
    );

    setState(() {
      final chatIndex = _chats.indexWhere((c) => c.id == targetChatId);
      if (chatIndex != -1) {
        final existing = _chats[chatIndex];
        final msgList = [...existing.messages];
        final insertIndex = msgList.indexWhere((m) => m.id == aiMessage.id);
        if (insertIndex == -1) {
          msgList.add(derivedMessage);
        } else {
          msgList.insert(insertIndex + 1, derivedMessage);
        }
        _chats[chatIndex] = existing.copyWith(
          messages: msgList,
          updatedAt: DateTime.now(),
        );
        if (_currentChat?.id == targetChatId) {
          _currentChat = _chats[chatIndex];
        }
      }

      _isLoading = true;
      _shouldStopResponse = false;
      _activeResponseChatId = targetChatId;
      _isTyping = true;
      _typingMessageId = derivedMessage.id;
      _currentTypingText = '';
      _fullResponseText = '';
      _loadingMessage = 'Düşünüyor...';
    });

    _scrollToBottomQuick();

    String streamedText = '';

    try {
      await _openRouterService.sendMessageWithHistoryStream(
        conversationHistory,
        instruction,
        imagesBase64: const [],
        onToken: (token) {
          if (!mounted || _shouldStopResponse) return;
          if (token.isEmpty) return;

          streamedText += token;
          _fullResponseText = streamedText;
          // Kullanıcıya gösterilen metinden KAYNAKLAR_JSON ve inline data:image bloklarını canlı olarak gizle
          final cleaned = _cleanStreamingTextForDisplay(streamedText);
          _currentTypingText = _formatQuickActionResult(actionId, cleaned);

          setState(() {
            final chatIndex = _chats.indexWhere((c) => c.id == targetChatId);
            if (chatIndex == -1) return;
            final msgs = [..._chats[chatIndex].messages];
            final msgIndex = msgs.indexWhere((m) => m.id == derivedMessage.id);
            if (msgIndex == -1) return;
            msgs[msgIndex] = msgs[msgIndex].copyWith(
              content: _currentTypingText,
              isStopped: false,
            );
            _chats[chatIndex] = _chats[chatIndex].copyWith(
              messages: msgs,
              updatedAt: DateTime.now(),
            );
            if (_currentChat?.id == targetChatId) {
              _currentChat = _chats[chatIndex];
            }
          });

          if (!_showScrollToBottom) {
            _scrollToBottomQuick();
          }
        },
        shouldStop: () => _shouldStopResponse,
        maxTokens: 600,
      );
      // Streaming tamamlandı, cevabı temizle ve kaynakları ayıkla
      if (streamedText.isNotEmpty) {
        final cleanText = _cleanStreamingTextForDisplay(streamedText);
        final formatted = _formatQuickActionResult(actionId, cleanText);
        final searchResult = _extractSearchResultFromResponse(
          streamedText,
          instruction,
        );

        setState(() {
          final chatIndex = _chats.indexWhere((c) => c.id == targetChatId);
          if (chatIndex != -1) {
            final msgs = [..._chats[chatIndex].messages];
            final msgIndex = msgs.indexWhere((m) => m.id == derivedMessage.id);
            if (msgIndex != -1) {
              msgs[msgIndex] = msgs[msgIndex].copyWith(
                content: formatted,
                searchResult: searchResult ?? msgs[msgIndex].searchResult,
              );
              _chats[chatIndex] = _chats[chatIndex].copyWith(
                messages: msgs,
                updatedAt: DateTime.now(),
              );
              if (_currentChat?.id == targetChatId) {
                _currentChat = _chats[chatIndex];
              }
            }
          }
        });
      }
    } catch (e) {
      if (!mounted) return;
      GreyNotification.show(context, 'İşlem tamamlanamadı: $e');
    } finally {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _isTyping = false;
        _activeResponseChatId = null;
        _typingMessageId = null;
        _shouldStopResponse = false;
        _stoppedMessageId = null;
      });
      await _storageService.saveChats(_chats);
    }
  }

  Future<void> _loadData() async {
    final chats = await _storageService.loadChats();
    final profile = await _storageService.loadUserProfile();
    final notificationsEnabled = await _storageService
        .getNotificationsEnabled();
    final fontSizeIndex = await _storageService.getFontSizeIndex();
    final fontFamily = await _storageService.getFontFamily();

    final now = DateTime.now();
    // 1 haftadan eski çöp kutusu kayıtlarını kalıcı olarak temizle
    final filteredChats = chats.where((c) {
      if (c.deletedAt == null) return true;
      final diff = now.difference(c.deletedAt!);
      return diff.inDays < 7;
    }).toList();

    if (filteredChats.length != chats.length) {
      await _storageService.saveChats(filteredChats);
    }

    setState(() {
      _chats = filteredChats;
      _userProfile =
          profile ??
          UserProfile(
            name: 'Kullanıcı',
            username: 'Kullanıcı',
            createdAt: DateTime.now(),
            email: '',
          );

      // Her zaman merhaba ekranında başla
      _currentChat = null;
      _notificationsEnabled = notificationsEnabled;
      _fontSizeIndex = fontSizeIndex;
      _fontFamily = (fontFamily == null || fontFamily.isEmpty)
          ? null
          : fontFamily;
    });

    // CurrentChatId'yi temizle
    await _storageService.clearCurrentChatId();

    if (_userProfile!.name == 'Kullanıcı' && profile == null) {
      await _storageService.saveUserProfile(_userProfile!);
    }
  }

  Future<void> _openSettings() async {
    if (!mounted) return;
    Navigator.of(context).pop();

    final result = await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (context) => const SettingsScreen()));

    if (!mounted) return;

    if (result == 'reset') {
      await _loadData();
      return;
    }

    final notificationsEnabled = await _storageService
        .getNotificationsEnabled();
    final fontSizeIndex = await _storageService.getFontSizeIndex();
    final fontFamily = await _storageService.getFontFamily();

    if (!mounted) return;
    setState(() {
      _notificationsEnabled = notificationsEnabled;
      _fontSizeIndex = fontSizeIndex;
      _fontFamily = (fontFamily == null || fontFamily.isEmpty)
          ? null
          : fontFamily;
    });
  }

  void _handleProfileUpdated(UserProfile updatedProfile) async {
    setState(() {
      _userProfile = updatedProfile;
    });
    await _storageService.saveUserProfile(updatedProfile);
  }

  void _handleChatSelected(Chat chat) async {
    if (_activeResponseChatId != null && _activeResponseChatId != chat.id) {
      GreyNotification.show(
        context,
        'AI cevap veriyor, sohbet değiştiremezsiniz',
      );
      return;
    }

    // Eski stream'i iptal et
    await _groupMessagesSubscription?.cancel();
    _groupMessagesSubscription = null;

    setState(() {
      _currentChat = chat;
      _currentTodoTasks = chat.projectTasks ?? [];
      _isTodoPanelOpen = false;

      final index = _chats.indexWhere((c) => c.id == chat.id);
      if (index != -1) {
        _chats[index] = _chats[index].copyWith(unreadCount: 0);
      }
    });

    await _storageService.setCurrentChatId(chat.id);

    // Eğer grup sohbeti ise dinlemeye başla
    if (chat.isGroup && chat.groupId != null) {
      _subscribeToGroupMessages(chat.groupId!);
    }

    if (mounted && Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  // Grup AI Cevabı (Gelişmiş - Görsel & Metin)
  // Grup AI Cevabı (Gelişmiş - Görsel & Metin)
  Future<void> _triggerGroupAIResponse(String groupId, String prompt) async {
    try {
      // Konuşma geçmişini hazırla (Son 20 mesaj)
      List<Map<String, dynamic>> history = [];
      if (_currentChat != null && _currentChat!.messages.isNotEmpty) {
        final messages = _currentChat!.messages;
        final recentMessages = messages.length > 20
            ? messages.sublist(messages.length - 20)
            : messages;
        for (var msg in recentMessages) {
          if (msg.content.isEmpty) continue;
          history.add({
            'role': msg.isUser ? 'user' : 'assistant',
            'content': msg.content,
          });
        }
      }

      String fullResponse = '';

      await _openRouterService.sendMessageWithHistoryStream(
        history,
        prompt,
        onToken: (token) {
          fullResponse += token;
        },
        shouldStop: () => false,
      );

      // --- [IMGEN] GÜÇLÜ Kontrolü ---
      // Regex ile [IMGEN] etiketini ara (büyük/küçük harf duyarsız, boşluk esnek)
      final imgenRegex = RegExp(r'\[IMGEN\]\s*:?', caseSensitive: false);

      if (imgenRegex.hasMatch(fullResponse)) {
        try {
          // Prompt'u ayıkla: Etiketten sonraki her şeyi al
          final match = imgenRegex.firstMatch(fullResponse);
          String rawPrompt = fullResponse.substring(match!.end).trim();

          // Varsa NEGATIVE_PROMPT vs. ayıkla
          String finalPrompt = rawPrompt;
          String? negativePrompt;
          bool isTransparent = false;

          if (finalPrompt.contains('TRANSPARENT: TRUE')) {
            isTransparent = true;
            finalPrompt = finalPrompt
                .replaceAll('TRANSPARENT: TRUE', '')
                .trim();
          }
          if (finalPrompt.contains('NEGATIVE_PROMPT:')) {
            final parts = finalPrompt.split('NEGATIVE_PROMPT:');
            finalPrompt = parts[0].trim();
            if (parts.length > 1) {
              negativePrompt = parts[1].trim();
            }
          }

          final generatedImageBase64 = await _imageGenService
              .generateImageWithFallback(
                finalPrompt,
                negativePrompt: negativePrompt,
                isTransparent: isTransparent,
              );

          if (generatedImageBase64 != null) {
            await FirestoreService.instance.sendGroupMessage(
              groupId: groupId,
              senderUid: 'ai_foresee',
              senderUsername: 'ForeSee',
              senderPhoto: 'logo3.png',
              content: '', // Sadece görsel
              imageUrl: generatedImageBase64,
            );
          } else {
            // Görsel null döndüyse hata mesajı
            throw Exception('Görsel servisi boş yanıt döndürdü');
          }
        } catch (e) {
          // Görsel oluşturma hatası durumunda kullanıcıya bilgi ver
          await FirestoreService.instance.sendGroupMessage(
            groupId: groupId,
            senderUid: 'ai_foresee',
            senderUsername: 'ForeSee',
            senderPhoto: 'logo3.png',
            content:
                '⚠️ Görsel oluşturulurken bir sorun oluştu. Lütfen tekrar deneyin.',
          );
          print('Group Image Gen Error: $e');
        }
        return; // İşlem tamam (başarılı veya hatalı), metin akışına devam ETME
      }

      // --- Normal Metin Cevabı ---
      String cleanContent = fullResponse;

      // [REASON] temizliği
      if (cleanContent.contains('[REASON]')) {
        cleanContent = cleanContent
            .replaceAll(RegExp(r'\[REASON\]:?[\s\S]*?(\n\n|$)'), '')
            .trim();
      }

      // Güvenlik: Hala [IMGEN] kalıntısı varsa temizle
      cleanContent = cleanContent
          .replaceAll(RegExp(r'\[IMGEN\]:?.*', caseSensitive: false), '')
          .trim();

      if (cleanContent.isNotEmpty) {
        await FirestoreService.instance.sendGroupMessage(
          groupId: groupId,
          senderUid: 'ai_foresee',
          senderUsername: 'ForeSee',
          senderPhoto: 'logo3.png',
          content: cleanContent,
        );
      }
    } catch (e) {
      print('Group AI Error: $e');
    }
  }

  void _subscribeToGroupMessages(String groupId) {
    _groupMessagesSubscription = FirestoreService.instance
        .getGroupMessages(groupId)
        .listen((snapshot) {
          final messages = snapshot.docs
              .map((doc) {
                final data = doc.data() as Map<String, dynamic>;
                // Message modeline map'le
                // Not: Firestore ID'sini mesaj ID olarak kullanıyoruz
                return Message(
                  id: doc.id,
                  chatId:
                      _currentChat?.id ?? '', // Use local Chat ID or Group ID
                  content: data['content'] ?? '',
                  isUser:
                      data['senderId'] ==
                      FirebaseAuth.instance.currentUser?.uid,
                  timestamp:
                      (data['timestamp'] as Timestamp?)?.toDate() ??
                      DateTime.now(),
                  imageUrl: data['imageUrl'],
                  senderUsername: data['senderUsername'],
                  senderPhotoUrl:
                      data['senderPhoto'], // Firestore sends 'senderPhoto'
                  metadata: {
                    'senderId': data['senderId'],
                  }, // Store senderId in metadata
                );
              })
              .toList()
              .reversed
              .toList();

          if (mounted) {
            setState(() {
              if (_currentChat != null && _currentChat!.groupId == groupId) {
                _currentChat = _currentChat!.copyWith(messages: messages);
                // Scroll to bottom logic if needed
              }
            });
          }
        });
  }

  void _handleChatDelete(Chat chat) async {
    if (_activeResponseChatId != null && _activeResponseChatId == chat.id) {
      GreyNotification.show(
        context,
        'AI cevap veriyorken bu sohbeti silemezsiniz',
      );
      return;
    }

    final now = DateTime.now();
    setState(() {
      final index = _chats.indexWhere((c) => c.id == chat.id);
      if (index != -1) {
        _chats[index] = _chats[index].copyWith(deletedAt: now, unreadCount: 0);
      }
      _selectedChatIdsForDelete.remove(chat.id);
      if (_currentChat?.id == chat.id) {
        _currentChat = null;
      }
    });

    await _storageService.saveChats(_chats);
    if (_currentChat == null) {
      await _storageService.clearCurrentChatId();
    } else {
      await _storageService.setCurrentChatId(_currentChat!.id);
    }
  }

  void _handleChatEdit(Chat chat) async {
    final titleController = TextEditingController(text: chat.title);
    final projectLabelController = TextEditingController(
      text: chat.projectLabel ?? '',
    );
    final int initialColorValue = chat.projectColor ?? 0xFF2563EB;
    Color selectedColor = Color(initialColorValue);

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1A1A1A),
          title: const Text(
            'Sohbet / Proje Ayarları',
            style: TextStyle(color: Colors.white),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: titleController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Sohbet başlığı',
                  labelStyle: TextStyle(color: Colors.white60),
                  hintText: 'Yeni başlık',
                  hintStyle: TextStyle(color: Colors.white38),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.white24),
                  ),
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.white),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: projectLabelController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Proje etiketi (isteğe bağlı)',
                  labelStyle: TextStyle(color: Colors.white60),
                  hintText: 'Örneğin: Alışveriş Listesi, Portfolio App',
                  hintStyle: TextStyle(color: Colors.white38),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.white24),
                  ),
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.white),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'Proje rengi',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              StatefulBuilder(
                builder: (ctx, setStateDialog) {
                  final colors = <Color>[
                    const Color(0xFF2563EB), // Mavi
                    const Color(0xFF22C55E), // Yeşil
                    const Color(0xFFF97316), // Turuncu
                    const Color(0xFFE11D48), // Kırmızı
                    const Color(0xFFA855F7), // Mor
                  ];
                  return Row(
                    children: [
                      for (final c in colors)
                        GestureDetector(
                          onTap: () {
                            setStateDialog(() {
                              selectedColor = c;
                            });
                          },
                          child: Container(
                            width: 22,
                            height: 22,
                            margin: const EdgeInsets.only(right: 8),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: c,
                              border: Border.all(
                                color: selectedColor.value == c.value
                                    ? Colors.white
                                    : Colors.black.withOpacity(0.6),
                                width: selectedColor.value == c.value ? 2 : 1,
                              ),
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'İptal',
                style: TextStyle(color: Colors.white60),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop<Map<String, dynamic>>(context, {
                  'title': titleController.text.trim(),
                  'projectLabel': projectLabelController.text.trim(),
                  'projectColor': selectedColor.value,
                });
              },
              child: const Text('Kaydet'),
            ),
          ],
        );
      },
    );

    if (result == null) return;

    final String newTitle = (result['title'] as String?)?.trim() ?? '';
    final String newProjectLabel =
        (result['projectLabel'] as String?)?.trim() ?? '';
    final int newProjectColor =
        (result['projectColor'] as int?) ?? initialColorValue;

    if (newTitle.isEmpty) return;

    setState(() {
      final index = _chats.indexWhere((c) => c.id == chat.id);
      if (index != -1) {
        _chats[index] = _chats[index].copyWith(
          title: newTitle,
          projectLabel: newProjectLabel.isEmpty ? null : newProjectLabel,
          projectColor: newProjectColor,
          updatedAt: DateTime.now(),
        );
        if (_currentChat?.id == chat.id) {
          _currentChat = _chats[index];
        }
      }
    });

    await _storageService.saveChats(_chats);
  }

  void _handleMultiDeletePressed() async {
    if (!_isMultiDeleteMode) {
      setState(() {
        _isMultiDeleteMode = true;
        _selectedChatIdsForDelete.clear();
      });
      return;
    }

    if (_selectedChatIdsForDelete.isEmpty) {
      setState(() {
        _isMultiDeleteMode = false;
      });
      return;
    }

    // Seçili sohbetleri gösteren ve onay isteyen bottom sheet aç
    await showModalBottomSheet(
      context: context,
      backgroundColor: themeService.isDarkMode ? const Color(0xFF1A1A1A) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            final selectedChats = _chats
                .where((c) => _selectedChatIdsForDelete.contains(c.id))
                .toList();

            return SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
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
                    const Text(
                      'Seçili sohbetleri silmek istiyor musun?',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${selectedChats.length} sohbet seçildi. İstersen aşağıdan bazılarını kaldırabilirsin.',
                      style: const TextStyle(
                        color: Colors.white60,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 220,
                      child: selectedChats.isEmpty
                          ? const Center(
                              child: Text(
                                'Hiç sohbet seçili değil.',
                                style: TextStyle(
                                  color: Colors.white54,
                                  fontSize: 13,
                                ),
                              ),
                            )
                          : ListView.builder(
                              itemCount: selectedChats.length,
                              itemBuilder: (context, index) {
                                final chat = selectedChats[index];
                                return Container(
                                  margin: const EdgeInsets.symmetric(
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: themeService.isDarkMode ? const Color(0xFF222222) : Colors.grey.shade100,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: themeService.isDarkMode ? Colors.white10 : Colors.black26),
                                  ),
                                  child: ListTile(
                                    dense: true,
                                    title: Text(
                                      chat.title,
                                      style: TextStyle(
                                        color: themeService.isDarkMode ? Colors.white : Colors.black87,
                                        fontSize: 14,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    trailing: IconButton(
                                      icon: Icon(
                                        Icons.close,
                                        size: 18,
                                        color: themeService.isDarkMode ? Colors.white60 : Colors.black54,
                                      ),
                                      onPressed: () {
                                        setState(() {
                                          _selectedChatIdsForDelete.remove(
                                            chat.id,
                                          );
                                        });
                                        setModalState(() {});
                                      },
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () {
                            Navigator.of(ctx).pop();
                          },
                          child: const Text(
                            'İptal',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        TextButton(
                          onPressed: selectedChats.isEmpty
                              ? null
                              : () async {
                                  final idsToDelete = Set<String>.from(
                                    _selectedChatIdsForDelete,
                                  );
                                  final now = DateTime.now();

                                  setState(() {
                                    for (int i = 0; i < _chats.length; i++) {
                                      final c = _chats[i];
                                      if (idsToDelete.contains(c.id)) {
                                        _chats[i] = c.copyWith(
                                          deletedAt: now,
                                          unreadCount: 0,
                                        );
                                      }
                                    }
                                    if (_currentChat != null &&
                                        idsToDelete.contains(
                                          _currentChat!.id,
                                        )) {
                                      _currentChat = null;
                                    }
                                    _selectedChatIdsForDelete.clear();
                                    _isMultiDeleteMode = false;
                                  });

                                  Navigator.of(ctx).pop();

                                  await _storageService.saveChats(_chats);
                                  if (_currentChat == null) {
                                    await _storageService.clearCurrentChatId();
                                  } else {
                                    await _storageService.setCurrentChatId(
                                      _currentChat!.id,
                                    );
                                  }
                                },
                          child: Text(
                            'Sil (${selectedChats.length})',
                            style: const TextStyle(
                              color: Colors.redAccent,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
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
      },
    );
  }

  void _handleMultiDeleteCancel() {
    setState(() {
      _isMultiDeleteMode = false;
      _selectedChatIdsForDelete.clear();
    });
  }

  void _handleChatToggleSelection(Chat chat) {
    setState(() {
      if (_selectedChatIdsForDelete.contains(chat.id)) {
        _selectedChatIdsForDelete.remove(chat.id);
      } else {
        _selectedChatIdsForDelete.add(chat.id);
      }
    });
  }

  Chat _createNewChat() {
    // AI cevap verirken yeni chat oluşturmayı engelle
    if (_activeResponseChatId != null) {
      GreyNotification.show(
        context,
        'AI henüz cevap veriyor, bekleyin. AI cevap verirken sohbet değiştiremezsiniz',
      );
      return _currentChat!; // Mevcut chat'i döndür
    }

    final newChat = Chat(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: 'Yeni Sohbet',
      messages: [],
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    setState(() {
      _currentChat = newChat;
    });

    return newChat;
  }

  // AI cevabını durdur
  void _stopAIResponse() {
    setState(() {
      _shouldStopResponse = true;
      _isLoading = false;
      _isTyping = false;
      _partialResponse = _currentTypingText;

      // Düşünüyor mesajını kaldır ve yarım mesajı kaydet
      if (_activeResponseChatId != null) {
        final chatIndex = _chats.indexWhere(
          (c) => c.id == _activeResponseChatId,
        );
        if (chatIndex != -1) {
          final messages = [..._chats[chatIndex].messages];

          // Son mesajı kontrol et
          if (messages.isNotEmpty) {
            final lastMessage = messages.last;
            if (lastMessage.content == 'Düşünüyor...' ||
                lastMessage.content.isEmpty) {
              // Düşünüyor mesajını kaldır
              messages.removeLast();
            } else {
              // Typing mesajını durdurulmuş olarak işaretle
              _stoppedMessageId = lastMessage.id;
              messages[messages.length - 1] = lastMessage.copyWith(
                isStopped: true,
                content: _currentTypingText, // Mevcut typing text'i kaydet
              );
            }

            _chats[chatIndex] = _chats[chatIndex].copyWith(messages: messages);
            if (_currentChat?.id == _activeResponseChatId) {
              _currentChat = _chats[chatIndex];
            }
          }
        }
      }

      _activeResponseChatId = null;
      _typingMessageId = null;
    });
  }

  // Devam ettir - durdurulan AI cevabını kaldığı yerden mantıksal olarak devam ettir
  void _continueResponse() async {
    if (_stoppedMessageId == null || _currentChat == null) return;

    final targetChatId = _currentChat!.id;
    final chatIndex = _chats.indexWhere((c) => c.id == targetChatId);
    if (chatIndex == -1) return;

    final messages = [..._chats[chatIndex].messages];
    final idx = messages.indexWhere((m) => m.id == _stoppedMessageId);
    if (idx == -1) return;

    final stoppedMessage = messages[idx];
    final baseText = stoppedMessage.content;

    setState(() {
      _isLoading = true;
      _shouldStopResponse = false;
      _activeResponseChatId = targetChatId;
      _isTyping = true;
      _typingMessageId = _stoppedMessageId;
      _currentTypingText = baseText;
      _fullResponseText = '';

      messages[idx] = stoppedMessage.copyWith(isStopped: false);
      _chats[chatIndex] = _chats[chatIndex].copyWith(
        messages: messages,
        updatedAt: DateTime.now(),
      );
      if (_currentChat?.id == targetChatId) {
        _currentChat = _chats[chatIndex];
      }
    });

    // Mevcut sohbet geçmişini AI'ye ver ve "kaldığın yerden devam et" iste
    final conversationHistory = _currentChat!.messages
        .map(
          (msg) => {
            'role': msg.isUser ? 'user' : 'assistant',
            'content': msg.content,
          },
        )
        .toList();

    String streamedText = '';
    const continuePrompt =
        'Az önceki ForeSee cevabının KALDIĞIN yerden, hiçbir kısmı tekrar etmeden devamını yaz. Yeni bir cevap başlatma, sadece mevcut cevabının devamını yaz.';

    try {
      await _openRouterService.sendMessageWithHistoryStream(
        conversationHistory,
        continuePrompt,
        imagesBase64: const [],
        onToken: (token) {
          if (!mounted || _shouldStopResponse) return;
          if (token.isEmpty) return;

          streamedText += token;
          _fullResponseText = streamedText;

          final combinedRaw = baseText + streamedText;
          final combinedClean = _cleanStreamingTextForDisplay(
            _stripControlTagsForDisplay(combinedRaw),
          );
          _currentTypingText = combinedClean;

          setState(() {
            final chatIndex = _chats.indexWhere((c) => c.id == targetChatId);
            if (chatIndex == -1) return;
            final msgs = [..._chats[chatIndex].messages];
            final idx = msgs.indexWhere((m) => m.id == _stoppedMessageId);
            if (idx == -1) return;
            msgs[idx] = msgs[idx].copyWith(
              content: combinedClean,
              isStopped: false,
            );
            _chats[chatIndex] = _chats[chatIndex].copyWith(
              messages: msgs,
              updatedAt: DateTime.now(),
            );
            if (_currentChat?.id == targetChatId) {
              _currentChat = _chats[chatIndex];
            }
          });

          if (!_showScrollToBottom) {
            _scrollToBottomQuick();
          }
        },
        shouldStop: () => _shouldStopResponse,
      );

      if (streamedText.isNotEmpty) {
        // Yeni gelen kısımda kontrol etiketlerini işle
        final processedNewPart = await _processControlTagsFromResponse(
          streamedText,
        );
        final cleanNewPart = _cleanStreamingTextForDisplay(processedNewPart);
        final finalCombined =
            baseText + (cleanNewPart.isNotEmpty ? cleanNewPart : '');

        setState(() {
          final chatIndex = _chats.indexWhere((c) => c.id == targetChatId);
          if (chatIndex == -1) return;
          final msgs = [..._chats[chatIndex].messages];
          final idx = msgs.indexWhere((m) => m.id == _stoppedMessageId);
          if (idx == -1) return;
          msgs[idx] = msgs[idx].copyWith(content: finalCombined);
          _chats[chatIndex] = _chats[chatIndex].copyWith(
            messages: msgs,
            updatedAt: DateTime.now(),
          );
          if (_currentChat?.id == targetChatId) {
            _currentChat = _chats[chatIndex];
          }
        });
      }
    } catch (e) {
      if (!mounted) return;
      GreyNotification.show(context, 'Devam ettirilemedi: $e');
    } finally {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _isTyping = false;
        _activeResponseChatId = null;
        _typingMessageId = null;
        _shouldStopResponse = false;
        _stoppedMessageId = null;
      });

      await _storageService.saveChats(_chats);
    }
  }

  // İnternet bağlantı sorunu olduğunda sohbetin içine bilgilendirme bot mesajı ekle
  Future<void> _addConnectionIssueBotMessage(String targetChatId) async {
    // Sadece o an açık olan sohbet için, storage'a kaydetmeden göster
    if (_currentChat == null || _currentChat!.id != targetChatId) {
      return;
    }

    final botMessage = Message(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      chatId: targetChatId,
      content: 'İnternetini kontrol edebilir misin? [Ayarlar](wifi://settings)\n\nİnternetin gelene kadar belki oyun oynayabilirsin? [Oyunlar](gamehub://)',
      isUser: false,
      timestamp: DateTime.now(),
    );

    setState(() {
      _ephemeralMessages
        ..clear() // Aynı anda tek bir bağlantı uyarısı göster
        ..add(botMessage);
    });

    // Kullanıcı büyük ihtimalle son mesajı görmek isteyecek
    _scrollToBottomQuick();
  }

  // Son AI mesajını tekrar dene
  void _retryAiMessage(Message aiMessage) async {
    if (_activeResponseChatId != null) {
      GreyNotification.show(context, 'AI cevap veriyor, lütfen bekleyin...');
      return;
    }

    if (_currentChat == null) {
      GreyNotification.show(context, 'Aktif sohbet bulunamadı');
      return;
    }

    final messages = _currentChat!.messages;
    final index = messages.indexWhere((m) => m.id == aiMessage.id);
    if (index <= 0) {
      GreyNotification.show(
        context,
        'Tekrar deneme için önceki mesaj bulunamadı',
      );
      return;
    }

    Message? lastUserMessage;
    for (int i = index - 1; i >= 0; i--) {
      if (messages[i].isUser) {
        lastUserMessage = messages[i];
        break;
      }
    }

    if (lastUserMessage == null) {
      GreyNotification.show(
        context,
        'Tekrar deneme için kullanıcı mesajı bulunamadı',
      );
      return;
    }

    // Mevcut inputu temizle ve önceki kullanıcı mesajını geri yükle
    _messageController.text = lastUserMessage.content;
    setState(() {
      _selectedImages.clear();
      _selectedImagesBase64.clear();
    });

    // Eğer önceki mesajda görsel varsa tekrar eklemeye çalış
    if (lastUserMessage.imageUrl != null &&
        !lastUserMessage.imageUrl!.startsWith('data:image')) {
      try {
        final file = File(lastUserMessage.imageUrl!);
        if (await file.exists()) {
          await _processSelectedFile(file);
        }
      } catch (_) {
        // Görsel yüklenemezse sadece metinle devam et
      }
    }

    await _sendMessage();
  }

  Future<String> _processControlTagsFromResponse(String fullText) async {
    final lines = fullText.split('\n');
    final filteredLines = <String>[];
    final memorySnippets = <String>[];
    String? newPrompt;
    bool memoryReset = false;
    bool promptReset = false;
    List<Map<String, dynamic>>? tasks;

    final memoryRegex = RegExp(r'^\s*\[BELLEK\]\s*:?\s*(.+)$');
    final promptRegex = RegExp(r'^\s*\[PROMPTS?\]\s*:?\s*(.+)$');
    final reminderRegex = RegExp(r'^\s*\[REMINDER\]\s*:?\s*(.+)$');
    final imgenRegex = RegExp(r'^\s*\[İMGEN\]\s*:?\s*(.+)$');
    final reasonRegex = RegExp(r'^\s*\[REASON\]\s*:?\s*(.+)$');
    final calendarRegex = RegExp(r'^\[CALENDAR_EVENT\]: (.*)');

    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) {
        filteredLines.add(line);
        continue;
      }

      if (trimmed.startsWith('[BELLEK_SIFIRLA]')) {
        memoryReset = true;
        continue; // Kullanıcıya gösterme
      }

      if (trimmed.startsWith('[PROMPT_SIFIRLA]')) {
        promptReset = true;
        continue;
      }

      final memoryMatch = memoryRegex.firstMatch(trimmed);
      if (memoryMatch != null) {
        final content = memoryMatch.group(1)?.trim();
        if (content != null && content.isNotEmpty) {
          memorySnippets.add(content);
        }
        continue; // Etiket satırını kullanıcıya gösterme
      }

      final promptMatch = promptRegex.firstMatch(trimmed);
      if (promptMatch != null) {
        final content = promptMatch.group(1)?.trim();
        if (content != null && content.isNotEmpty) {
          newPrompt = content;
        }
        continue;
      }

      final imgenMatch = imgenRegex.firstMatch(trimmed);
      if (imgenMatch != null) {
        final content = imgenMatch.group(1)?.trim();
        if (content != null && content.isNotEmpty) {
          final tagId = 'imgen_$content';
          if (!_handledControlTags.contains(tagId)) {
            _handledControlTags.add(tagId);
            _handleImgenTrigger(content);
          }
        }
        continue;
      }

      final reasonMatch = reasonRegex.firstMatch(trimmed);
      if (reasonMatch != null) {
        final content = reasonMatch.group(1)?.trim();
        if (content != null && content.isNotEmpty && mounted) {
          setState(() {
            _agentThinking += (_agentThinking.isEmpty ? '' : '\n') + content;
            if (_loadingMessage == 'Düşünüyor...') {
              _loadingMessage = 'Derin düşünüyor...';
            }
          });
        }
        continue;
      }

      if (trimmed.startsWith('KAYNAKLAR_JSON:')) {
        if (mounted) {
          setState(() {
            _loadingMessage = 'Aranıyor...';
          });
        }
        continue;
      }

      if (trimmed.startsWith('[AGENTİCMODE]') ||
          trimmed.startsWith('[TASKS]')) {
        continue;
      }

      final calendarMatch = calendarRegex.firstMatch(trimmed);
      if (calendarMatch != null) {
        continue;
      }

      filteredLines.add(line);
    }

    // Bellek işlemleri
    final lockMemory = await _storageService.getLockMemoryAi();
    if (!lockMemory) {
      if (memoryReset) {
        await _storageService.saveUserMemory('');
      }

      if (memorySnippets.isNotEmpty) {
        String existing = '';
        if (!memoryReset) {
          existing = await _storageService.getUserMemory();
        }

        final buffer = StringBuffer();
        if (existing.trim().isNotEmpty) {
          buffer.writeln(existing.trim());
        }
        for (final snippet in memorySnippets) {
          buffer.writeln(snippet);
        }

        await _storageService.saveUserMemory(buffer.toString().trim());
      }
    }

    // Prompt işlemleri
    final lockPrompt = await _storageService.getLockPromptAi();
    if (!lockPrompt) {
      if (promptReset && (newPrompt == null || newPrompt.isEmpty)) {
        await _storageService.saveCustomPrompt('');
      } else if (newPrompt != null && newPrompt.isNotEmpty) {
        await _storageService.saveCustomPrompt(newPrompt.trim());
      }
    }

    if (tasks != null && tasks!.isNotEmpty && mounted) {
      setState(() {
        _currentTodoTasks = tasks!;
        _isTodoPanelOpen = false;

        if (_currentChat != null) {
          final chatIndex = _chats.indexWhere((c) => c.id == _currentChat!.id);
          if (chatIndex != -1) {
            final updatedChat = _chats[chatIndex].copyWith(
              projectTasks: tasks,
              updatedAt: DateTime.now(),
            );
            _chats[chatIndex] = updatedChat;
            if (_currentChat!.id == updatedChat.id) {
              _currentChat = updatedChat;
            }
          }
        }
      });

      // Görevler güncellendiğinde sohbetleri kaydet
      await _storageService.saveChats(_chats);
    }

    return filteredLines.join('\n').trimRight();
  }

  String _stripControlTagsForDisplay(String text) {
    final lines = text.split('\n');
    final filtered = <String>[];
    for (final line in lines) {
      final trimmed = line.trimLeft();
      if (trimmed.startsWith('[BELLEK]') ||
          trimmed.startsWith('[BELLEK_SIFIRLA]') ||
          trimmed.startsWith('[PROMPT]') ||
          trimmed.startsWith('[PROMPTS]') ||
          trimmed.startsWith('[PROMPT_SIFIRLA]') ||
          trimmed.startsWith('[REMINDER]') ||
          trimmed.startsWith('[THINKING]') ||
          trimmed.startsWith('[TERMINAL]') ||
          trimmed.startsWith('[STATUS]') ||
          trimmed.startsWith('[İMGEN]') ||
          trimmed.startsWith('[REASON]') ||
          trimmed.startsWith('[AGENTİCMODE]') ||
          trimmed.startsWith('[TASKS]')) {
        continue;
      }
      filtered.add(line);
    }
    return filtered.join('\n');
  }

  String _stripDataImageMarkdown(String text) {
    // AI cevabında dönebilen \n![...](data:image...) tabanlı inline görsel bloklarını gizle
    final pattern = RegExp(
      r'!\[[^\]]*\]\(data:image[^)]*\)',
      caseSensitive: false,
    );
    return text.replaceAll(pattern, '').trim();
  }

  Future<void> _handleImgenTrigger(String prompt) async {
    if (_currentChat == null) return;
    final targetChatId = _currentChat!.id;

    // AI'ın kendisi prompt ürettiği için direkt üretim aşamasına geçiyoruz
    try {
      // Eğer seçili bir görsel varsa onu referans olarak gönder
      String? refUrl;
      if (_selectedImagesBase64.isNotEmpty) {
        refUrl = 'data:image/jpeg;base64,${_selectedImagesBase64.first}';
      }

      final generatedImageBase64 = await _imageGenService
          .generateImageWithFallback(prompt, referenceImageUrl: refUrl);

      if (!mounted) return;

      setState(() {
        final chatIndex = _chats.indexWhere((c) => c.id == targetChatId);
        if (chatIndex != -1) {
          final messages = [..._chats[chatIndex].messages];
          // En son AI mesajına görseli ekle
          for (int i = messages.length - 1; i >= 0; i--) {
            if (!messages[i].isUser) {
              messages[i] = messages[i].copyWith(
                imageUrl: generatedImageBase64,
                metadata: {
                  ...messages[i].metadata ?? {},
                  'imagePrompt': prompt,
                },
              );
              break;
            }
          }
          _chats[chatIndex] = _chats[chatIndex].copyWith(messages: messages);
          if (_currentChat?.id == targetChatId) {
            _currentChat = _chats[chatIndex];
          }
        }
        _isTyping = false;
        _isLoading = false;
        _activeResponseChatId = null;
      });

      await _storageService.saveChats(_chats);
    } catch (e) {
      print('❌ AI tetiklemeli görsel üretim hatası: $e');
    }
  }

  String _cleanStreamingTextForDisplay(String text) {
    // Inline data:image markdown görsellerini temizle
    final withoutImages = _stripDataImageMarkdown(text);

    // KAYNAKLAR_JSON'dan sonrasını tamamen gizle (JSON dahil)
    final markerIndex = withoutImages.indexOf('KAYNAKLAR_JSON:');
    if (markerIndex != -1) {
      return withoutImages.substring(0, markerIndex).trimRight();
    }
    return withoutImages;
  }

  Map<String, dynamic>? _extractSearchResultFromResponse(
    String fullText,
    String queryText,
  ) {
    final markerIndex = fullText.indexOf('KAYNAKLAR_JSON:');
    if (markerIndex == -1) return null;

    final jsonPart = fullText
        .substring(markerIndex + 'KAYNAKLAR_JSON:'.length)
        .trim();
    if (jsonPart.isEmpty) return null;

    try {
      final decoded = jsonDecode(jsonPart);
      if (decoded is List) {
        return {'query': queryText, 'results': decoded};
      }
    } catch (_) {
      // JSON parse hatası durumunda kaynak paneli göstermeyelim
    }

    return null;
  }

  Future<void> _handleFsImport() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
      );

      if (result != null && result.files.single.path != null) {
        final file = File(result.files.single.path!);
        
        // Sadece .fs dosyalarını kabul et
        if (!file.path.toLowerCase().endsWith('.fs')) {
          GreyNotification.show(context, 'Sadece .fs dosyaları kabul edilir');
          return;
        }
        
        setState(() {
          _isLoading = true;
          _loadingMessage = 'Sohbet içe aktarılıyor...';
        });

        try {
          final chat = await _importExportService.importChatFromFs(file);

          setState(() {
            _isLoading = false;
          });

          if (chat != null) {
            setState(() {
              _chats.insert(0, chat);
              _currentChat = chat;
            });
            await _storageService.saveChats(_chats);
            GreyNotification.show(context, 'Sohbet başarıyla içe aktarıldı');
          } else {
            GreyNotification.show(context, 'Dosya bozuk veya şifresi çözülemedi');
          }
        } catch (e) {
          setState(() {
            _isLoading = false;
          });
          GreyNotification.show(context, 'İçe aktarma hatası: $e');
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        GreyNotification.show(context, 'Dosya seçme hatası: $e');
      }
    }
  }

  Future<void> _handlePdfExport([Chat? targetChat]) async {
    final chat = targetChat ?? _currentChat;
    if (chat == null || chat.messages.isEmpty) {
      GreyNotification.show(context, 'Dışa aktarılacak sohbet yok');
      return;
    }

    setState(() {
      _isExporting = true;
      _exportLoadingMessage =
          'Sohbet PDF\'e çeviriliyor...\nBu işlem birkaç dakika sürebilir';
    });

    try {
      final file = await _importExportService.exportChatAsPdf(chat);
      setState(() => _isExporting = false);

      final savedFile = await _importExportService.saveToDownloads(
        file,
        'foresee_chat_${chat.id}.pdf',
      );
      setState(() => _isExporting = false);

      if (savedFile != null) {
        GreyNotification.show(
          context,
          'Sohbat PDF olarak İndirilenler klasörüne kaydedildi',
        );
      } else {
        // Fallback to share
        await Share.shareXFiles([
          XFile(file.path),
        ], text: 'ForeSee Sohbet Geçmişi: ${chat.title}');
      }
    } catch (e) {
      setState(() => _isExporting = false);
      GreyNotification.show(context, 'PDF oluşturulamadı: $e');
    }
  }

  Future<void> _handleFsExport([Chat? targetChat]) async {
    final chat = targetChat ?? _currentChat;
    if (chat == null || chat.messages.isEmpty) {
      GreyNotification.show(context, 'Dışa aktarılacak sohbet yok');
      return;
    }

    setState(() {
      _isLoading = true;
      _loadingMessage = '.fs dosyası oluşturuluyor...';
    });

    try {
      final file = await _importExportService.exportChatAsFs(chat);
      setState(() => _isLoading = false);

      final savedFile = await _importExportService.saveToDownloads(
        file,
        'sohbet_${chat.id}.fs',
      );
      setState(() => _isLoading = false);

      if (savedFile != null) {
        GreyNotification.show(
          context,
          'Sohbet yedeği (.fs) İndirilenler klasörüne kaydedildi',
        );
      } else {
        // Share file
        await Share.shareXFiles([
          XFile(file.path),
        ], text: 'ForeSee Sohbet Yedeği (.fs)');
      }
    } catch (e) {
      setState(() => _isLoading = false);
      GreyNotification.show(context, 'Dışa aktarma başarısız: $e');
    }
  }

  Future<void> _handlePdfSelection() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );

      if (result != null && result.files.single.path != null) {
        final file = File(result.files.single.path!);

        setState(() {
          _isLoading = true;
          _loadingMessage = 'PDF işleniyor...';
        });

        // Extract text using read_pdf_text
        try {
          final text = await ReadPdfText.getPDFtext(file.path);

          setState(() {
            _pickedPdfFile = file;
            _pickedPdfText = text;
            _isLoading = false;
          });

          GreyNotification.show(
            context,
            'PDF eklendi: ${result.files.single.name}',
          );
        } catch (e) {
          setState(() {
            _isLoading = false;
          });
          GreyNotification.show(context, 'PDF okunamadı: $e');
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        GreyNotification.show(context, 'Dosya seçilemedi: $e');
      }
    }
  }

  bool _hasImageGenerationIntent(String text) {
    final lower = text.toLowerCase();
    const imageWords = [
      'görsel',
      'gorsel',
      'resim',
      'foto',
      'fotoğraf',
      'fotograf',
      'logo',
      'ikon',
      'icon',
      'kapak',
      'afiş',
      'afis',
    ];
    const actionWords = [
      'üret',
      'uret',
      'oluştur',
      'olustur',
      'çiz',
      'ciz',
      'tasarla',
      'hazırla',
      'hazirla',
      'yap',
    ];

    final hasImageWord = imageWords.any((w) => lower.contains(w));
    if (!hasImageWord) return false;
    final hasActionWord = actionWords.any((w) => lower.contains(w));
    return hasActionWord;
  }

  List<Map<String, int>> _extractCodeReferencesFromText(String text) {
    final regex = RegExp(r'@cb(\d+)l(\d+)', caseSensitive: false);
    final matches = regex.allMatches(text).toList();
    final refs = <Map<String, int>>[];
    for (final match in matches) {
      final blockStr = match.group(1);
      final lineStr = match.group(2);
      if (blockStr == null || lineStr == null) continue;
      final block = int.tryParse(blockStr);
      final line = int.tryParse(lineStr);
      if (block == null || line == null) continue;
      refs.add({'block': block, 'line': line});
    }
    return refs;
  }

  List<_CodeBlockRef> _collectCodeBlocksFromChat(Chat chat) {
    final codeBlockRegex = RegExp(r'```(\w+)?\n([\s\S]*?)```', multiLine: true);
    final blocks = <_CodeBlockRef>[];
    int globalIndex = 0;

    for (final msg in chat.messages) {
      if (msg.isUser) continue;
      final content = msg.content;
      for (final match in codeBlockRegex.allMatches(content)) {
        final lang = (match.group(1) ?? '').trim();
        final body = match.group(2) ?? '';
        globalIndex += 1;
        blocks.add(
          _CodeBlockRef(
            index: globalIndex,
            language: lang.isEmpty ? 'text' : lang,
            code: body,
            messageId: msg.id,
          ),
        );
      }
    }

    return blocks;
  }

  void _onMessageTextChanged() {
    if (!mounted) return;
    final text = _messageController.text;
    final selection = _messageController.selection;

    // Mention Panel Check (@)
    if (_currentChat != null && _currentChat!.isGroup) {
      if (selection.isValid && selection.baseOffset >= 0) {
        final textBeforeCursor = text.substring(0, selection.baseOffset);
        final match = RegExp(r'@(\w*)$').firstMatch(textBeforeCursor);

        if (match != null) {
          final newQuery = match.group(1) ?? '';
          setState(() {
            _mentionQuery = newQuery;
            _showMentionPanel = true;

            // Filter members
            final allMembers = List<Map<String, dynamic>>.from(
              _currentChat!.memberDetails ?? [],
            );
            // Add AI if not present
            if (!allMembers.any((m) => m['isAI'] == true)) {
              allMembers.add({
                'username': 'ForeSee',
                'uid': 'ai_foresee',
                'isAI': true,
              });
            }

            _filteredMembers = allMembers.where((m) {
              final username = m['username'] as String?;
              if (username == null) return false;
              return username.toLowerCase().contains(
                _mentionQuery.toLowerCase(),
              );
            }).toList();

            if (_filteredMembers.isEmpty) _showMentionPanel = false;
          });
        } else {
          if (_showMentionPanel) {
            setState(() {
              _showMentionPanel = false;
              _mentionQuery = '';
            });
          }
        }
      } else {
        if (_showMentionPanel) {
          setState(() {
            _showMentionPanel = false;
            _mentionQuery = '';
          });
        }
      }
    } else {
      if (_showMentionPanel) {
        setState(() {
          _showMentionPanel = false;
          _mentionQuery = '';
        });
      }
    }
  }

  Future<void> _sendMessage() async {
    // AI cevap verirken mesaj göndermeyi engelle
    if (_activeResponseChatId != null) {
      GreyNotification.show(
        context,
        'AI henüz cevap veriyor, lütfen bekleyin...',
      );
      return;
    }

    String messageText = _messageController.text.trim();

    // --- GRUP SOHBETİ KONTROLÜ ---
    if (_currentChat != null &&
        _currentChat!.isGroup &&
        _currentChat!.groupId != null) {
      if (messageText.isEmpty && _selectedImages.isEmpty) {
        GreyNotification.show(context, 'Boş mesaj gönderilemez');
        return;
      }

      final senderUser = FirebaseAuth.instance.currentUser;
      if (senderUser == null) return;

      // Profil bilgisini çek (username için)
      // Cache kullanılabilir ama şimdilik Firestore'dan hızlıca alalım veya modelden
      // Sidebar'da _userProfile var ama buraya taşımadık, AuthService'den alalım
      // Pratik çözüm: UserProfile'ı ChatScreen'e de pass edebiliriz veya Firestore'dan bakarız
      // Şimdilik FirestoreService'den getUserProfile
      final userDoc = await FirestoreService.instance.getUserProfile(
        senderUser.uid,
      );
      final username = userDoc?['username'] ?? 'Kullanıcı';
      final photo = userDoc?['profilePhotoUrl'] ?? 'assets/Beta2.png';

      // Mesajı gönder
      await FirestoreService.instance.sendGroupMessage(
        groupId: _currentChat!.groupId!,
        senderUid: senderUser.uid,
        senderUsername: username,
        senderPhoto: photo,
        content: messageText,
        mentionedUids: [], // TODO: Parse @mentions
      );

      _messageController.clear();
      _selectedImages.clear();

      // Reset mention panel state
      setState(() {
        _showMentionPanel = false;
        _mentionQuery = '';
        _filteredMembers = [];
      });

      // ----------------------------
      // OPTİMİZASYONLU AI TETİKLEMESİ (Debounce)
      // "Her şeyi üstüne alınsın" + "O cevap vermeden yazılanları da okusun"
      _groupAiDebounceTimer?.cancel();
      _groupAiDebounceTimer = Timer(const Duration(seconds: 2), () {
        if (_currentChat?.groupId != null) {
          _triggerGroupAIResponse(
            _currentChat!.groupId!,
            messageText, // Prompt as last message, but AI will fetch history
          );
        }
      });
      // ----------------------------

      return;
    }
    // ----------------------------

    // PDF metni varsa ekle
    if (_pickedPdfText != null && _pickedPdfText!.isNotEmpty) {
      final pdfName =
          _pickedPdfFile?.path.split(Platform.pathSeparator).last ??
          'belge.pdf';
      final spacing = messageText.isEmpty ? '' : '\n\n';
      messageText =
          '[PDF: $pdfName]\n\n$messageText\n\n[PDF_CONTENT_START]\n$_pickedPdfText\n[PDF_CONTENT_END]'
              .trim();
    }

    setState(() {
      _handledControlTags.clear();
    });

    final codeReferences = _extractCodeReferencesFromText(messageText);
    final hasText = messageText.isNotEmpty;
    final hasImages = _selectedImages.isNotEmpty;
    // Gönderilecek görsellerin base64 kopyasını, state'i temizlemeden önce al
    final List<String> imagesBase64ToSend = List<String>.from(
      _selectedImagesBase64,
    );

    // Görsel referansı yakala (Image Generation modu için)
    String? referenceImageUrl;
    if (_isImageGenerationMode && imagesBase64ToSend.isNotEmpty) {
      referenceImageUrl = 'data:image/jpeg;base64,${imagesBase64ToSend.first}';
    }

    if (!hasText && !hasImages) {
      GreyNotification.show(
        context,
        'Lütfen bir mesaj yazın veya görsel ekleyin',
      );
      return;
    }

    // Aktif sohbet yoksa oluştur
    if (_currentChat == null) {
      _createNewChat();
    }
    final chat = _currentChat!;
    final targetChatId = chat.id;
    final chatIndex = _chats.indexWhere((c) => c.id == targetChatId);

    // Kullanıcı mesajını oluştur (tüm görsellerin path'lerini sakla)
    String? userImagePath;
    List<String>? userImagePaths;
    if (_selectedImages.isNotEmpty) {
      userImagePaths = _selectedImages.map((f) => f.path).toList();
      userImagePath = userImagePaths.first;
    }

    final userMessage = Message(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      chatId: targetChatId,
      content: messageText,
      isUser: true,
      timestamp: DateTime.now(),
      imageUrl: userImagePath,
      imageUrls: userImagePaths,
    );

    // AI placeholder mesajı
    String aiMessageId = '${DateTime.now().millisecondsSinceEpoch}_ai';

    // Canvas modu için: Eğer son mesaj bir kod bloğu ise ve Canvas modu aktifse onu güncelle
    String? targetUpdateMessageId;
    if (_isCanvasMode) {
      final lastAiMessage = _currentChat?.messages.lastWhere(
        (m) => !m.isUser && m.content.contains('```'),
        orElse: () => Message(
          id: '',
          chatId: '',
          content: '',
          isUser: false,
          timestamp: DateTime.now(),
        ),
      );
      if (lastAiMessage != null && lastAiMessage.id.isNotEmpty) {
        targetUpdateMessageId = lastAiMessage.id;
        aiMessageId = targetUpdateMessageId;
      }
    }

    final aiMessage = Message(
      id: aiMessageId,
      chatId: targetChatId,
      content: '',
      isUser: false,
      timestamp: DateTime.now(),
    );

    setState(() {
      final now = DateTime.now();
      if (chatIndex != -1) {
        final current = _chats[chatIndex];
        String newTitle = current.title;
        if (current.messages.isEmpty) {
          newTitle = messageText.length > 30
              ? '${messageText.substring(0, 30)}...'
              : messageText;
        }
        final isCurrent = _currentChat?.id == targetChatId;
        final newUnread = isCurrent ? 0 : current.unreadCount + 1;

        // Mesajları hazırla
        List<Message> newMessages;
        if (targetUpdateMessageId != null) {
          // Var olan mesajı güncelleyeceğiz, sadece kullanıcı mesajını ekle
          newMessages = [...current.messages, userMessage];
          // Hedef mesaj zaten listede var
        } else {
          // Yeni AI mesajı ekle
          newMessages = [...current.messages, userMessage, aiMessage];
        }

        _chats[chatIndex] = current.copyWith(
          messages: newMessages,
          updatedAt: now,
          title: newTitle,
          unreadCount: newUnread,
        );
        if (isCurrent) {
          _currentChat = _chats[chatIndex];
        }
      } else {
        // Henüz listede olmayan yeni bir sohbet için ilk mesaj
        String newTitle;
        if (messageText.isEmpty) {
          newTitle = 'Yeni Sohbet';
        } else {
          newTitle = messageText.length > 30
              ? '${messageText.substring(0, 30)}...'
              : messageText;
        }
        final newChat = chat.copyWith(
          messages: [userMessage, aiMessage],
          title: newTitle,
          updatedAt: now,
          unreadCount: 0,
        );
        _chats.insert(0, newChat);
        _currentChat = newChat;
      }

      _isLoading = true;
      _shouldStopResponse = false;
      _activeResponseChatId = targetChatId;
      _isTyping = true;
      _typingMessageId = aiMessageId;
      _currentTypingText = '';
      _fullResponseText = '';
      if (_isThinkingMode) {
        _loadingMessage = 'Derin düşünüyor...';
      } else if (_isWebSearchMode) {
        _loadingMessage = 'Aranıyor...';
      } else {
        _loadingMessage = 'Düşünüyor...';
      }

      // Mesaj gönderildiği anda inputtaki görselleri temizle
      _selectedImages.clear();
      _selectedImagesBase64.clear();
      _pickedPdfFile = null;
      _pickedPdfText = null;
    });

    // Input metnini temizle ve en alta kaydır
    _messageController.clear();
    _scrollToBottomQuick();

    try {
      if (_isImageGenerationMode) {
        // 1) Türkçe prompt'u görsel üretim için İngilizce'ye çevir
        setState(() {
          _loadingMessage = 'Prompt çevriliyor...';
        });

        final turkishPrompt = messageText.isEmpty
            ? 'görsel oluşturma'
            : messageText;
        String englishPrompt = turkishPrompt;
        String? detectedNegativePrompt;
        bool isTransparent = false;

        // --- Contextual Image Logic Start ---
        // Check previous message for image metadata
        String? previousPrompt;
        final List<Message> msgs = chatIndex != -1
            ? _chats[chatIndex].messages
            : chat.messages;
        if (msgs.length >= 3) {
          // User, AI(placeholder), User(current), AI(new) structure is tricky
          // Logic: Find the LAST assistant message before this new user message exchange.
          // Since we just added User+AI placeholder, we look back from end-2
          final lastAiIndex = msgs.length - 3;
          if (lastAiIndex >= 0 && !msgs[lastAiIndex].isUser) {
            previousPrompt = msgs[lastAiIndex].metadata?['imagePrompt'];
          }
        }

        if (previousPrompt != null) {
          // Refine prompt using AI
          try {
            final refinedResponse = await _openRouterService.sendMessage(
              "Previous prompt context exists. User input: '$turkishPrompt'.\n"
              "Rules:\n"
              "1. If user says 'Olur', 'Evet', 'Tamam' etc. and previous AI suggested drawing, generate a complete, detailed English prompt for drawing that code/subject.\n"
              "2. If user provides a direct simple command (e.g. 'Portakal çiz'), return ONLY 'An orange'.\n"
              "3. If user describes, clean and translate only.\n"
              "Context was: '$previousPrompt'. Return ONLY the prompt text.",
            );

            String tempPrompt = refinedResponse;
            if (tempPrompt.contains('TRANSPARENT: TRUE')) {
              isTransparent = true;
              tempPrompt = tempPrompt
                  .replaceAll('TRANSPARENT: TRUE', '')
                  .trim();
            }

            if (tempPrompt.contains('NEGATIVE_PROMPT:')) {
              final parts = tempPrompt.split('NEGATIVE_PROMPT:');
              englishPrompt = parts[0].trim();
              if (parts.length > 1) {
                detectedNegativePrompt = parts[1].trim();
              }
            } else {
              englishPrompt = tempPrompt.trim();
            }
          } catch (_) {
            // Fallback to standard translation
            try {
              final transResponse = await _openRouterService.sendMessage(
                "Translate this to an English image generation prompt: '$turkishPrompt'. If it implies transparency/no background, add 'TRANSPARENT: TRUE'. If it implies avoiding something, add 'NEGATIVE_PROMPT: ...' at the end.",
              );
              String tempPrompt = transResponse;
              if (tempPrompt.contains('TRANSPARENT: TRUE')) {
                isTransparent = true;
                tempPrompt = tempPrompt
                    .replaceAll('TRANSPARENT: TRUE', '')
                    .trim();
              }
              if (tempPrompt.contains('NEGATIVE_PROMPT:')) {
                final parts = tempPrompt.split('NEGATIVE_PROMPT:');
                englishPrompt = parts[0].trim();
                if (parts.length > 1) {
                  detectedNegativePrompt = parts[1].trim();
                }
              } else {
                englishPrompt = tempPrompt.trim();
              }
            } catch (e) {
              print('Translation error: $e');
            }
          }
        } else {
          // Standard translation
          try {
            final transResponse = await _openRouterService.sendMessage(
              "You are a master Prompt Engineer for Image Generation. Transform this input into a highly detailed, professional English prompt for Nanobanana model: '$turkishPrompt'.\n"
              "1. EXPAND the prompt with cinematic lighting, textures, and artistic details (e.g. '8k, hyper-realistic, masterpiece, professional design, elegant aesthetics').\n"
              "2. If it's a logo or UI, describe it as 'sleek, modern, premium interface'.\n"
              "3. Return ONLY the English prompt text, no quotes or intro.\n"
              "4. If transparent background is implied, add 'TRANSPARENT: TRUE'. If things to avoid are implied, add 'NEGATIVE_PROMPT: ...'.",
            );

            String tempPrompt = transResponse;
            if (tempPrompt.contains('TRANSPARENT: TRUE')) {
              isTransparent = true;
              tempPrompt = tempPrompt
                  .replaceAll('TRANSPARENT: TRUE', '')
                  .trim();
            }

            if (tempPrompt.contains('NEGATIVE_PROMPT:')) {
              final parts = tempPrompt.split('NEGATIVE_PROMPT:');
              englishPrompt = parts[0].trim();
              if (parts.length > 1) {
                detectedNegativePrompt = parts[1].trim();
              }
            } else {
              englishPrompt = tempPrompt.trim();
            }
          } catch (e) {
            print('❌ Görsel prompt çeviri hatası: $e');
            // Fallback
            englishPrompt = turkishPrompt;
          }
        }
        // --- Contextual Image Logic End ---

        // 2) İngilizce prompt ile Pollinations üzerinden görsel oluştur
        setState(() {
          _loadingMessage = 'Görsel oluşturuluyor...';
        });

        final generatedImageBase64 = await _imageGenService
            .generateImageWithFallback(
              englishPrompt,
              negativePrompt: detectedNegativePrompt,
              isTransparent: isTransparent,
              referenceImageUrl: referenceImageUrl,
            );

        // 3) Görsel oluşturuldu, AI sessiz kalsın
        String description = '';
        final cleanDescription = '';

        // Store prompt in metadata for future contextual edits
        final metadata = {'imagePrompt': englishPrompt};

        setState(() {
          _isLoading = false;
          _isTyping = false;
          _activeResponseChatId = null;
          _typingMessageId = null;
          _currentTypingText = '';
          _fullResponseText = '';
          _isImageGenerationMode = false;

          final chatIndex = _chats.indexWhere((c) => c.id == targetChatId);
          if (chatIndex != -1) {
            final messages = [..._chats[chatIndex].messages];
            final idx = messages.indexWhere((m) => m.id == aiMessageId);
            if (idx != -1) {
              messages[idx] = messages[idx].copyWith(
                content: cleanDescription,
                imageUrl: generatedImageBase64,
                metadata: metadata,
              );
              _chats[chatIndex] = _chats[chatIndex].copyWith(
                messages: messages,
              );
              if (_currentChat?.id == targetChatId) {
                _currentChat = _chats[chatIndex];
              }
            }
          }
        });

        await _storageService.saveChats(_chats);
        await _maybeGenerateChatTitle(targetChatId);

        // Update stats
        await _storageService.addUsageMinutes(1); // Add 1 minute for image generation
        await _storageService.incrementTotalCodeLines(
          1,
        ); // Count image gen as 1 unit

        return;
      }

      final currentChatMessages = chatIndex != -1
          ? _chats[chatIndex].messages
          : chat.messages;

      final conversationHistory = currentChatMessages
          .where((msg) => msg.id != userMessage.id && msg.id != aiMessageId)
          .map(
            (msg) => {
              'role': msg.isUser ? 'user' : 'assistant',
              'content': msg.content,
            },
          )
          .toList();

      if (_isWebSearchMode) {
        conversationHistory.add({
          'role': 'system',
          'content':
              'Perform thorough web research to answer the user\'s request accurately. Provide sources when possible.',
        });
      }

      // Kullanıcının mesajındaki @cbXlY referanslarına göre önceki kod bloklarını bağlam olarak ekle
      if (codeReferences.isNotEmpty) {
        final blocks = _collectCodeBlocksFromChat(chat);
        if (blocks.isNotEmpty) {
          final buffer = StringBuffer();
          for (final ref in codeReferences) {
            final blockNo = ref['block'] ?? 0;
            final lineNo = ref['line'] ?? 0;
            if (blockNo <= 0) continue;
            final candidates = blocks.where((b) => b.index == blockNo).toList();
            if (candidates.isEmpty) continue;
            final block = candidates.first;

            buffer.writeln(
              'Kod bloğu $blockNo, satır $lineNo (tam blok bağlamı):',
            );
            buffer.writeln('```${block.language}\n${block.code.trim()}\n```');
            buffer.writeln();
          }

          final contextText = buffer.toString().trim();
          if (contextText.isNotEmpty) {
            conversationHistory.add({
              'role': 'assistant',
              'content':
                  'Kullanıcının son mesajında referans verdiği önceki kod blokları:\n\n$contextText',
            });
          }
        }
      }

      String streamedText = '';

      // Canvas Modu için katı kural: Sadece kod döndür
      if (_isCanvasMode) {
        conversationHistory.add({
          'role': 'system',
          'content':
              'CRITICAL: You are in CANVAS mode. ONLY output the final code inside ONE markdown code block. Do NOT include ANY explanation, introductory text, OR closing remarks. ONLY the code itself. If you need to explain, do it via comments inside the code.',
        });
      }

      await _openRouterService.sendMessageWithHistoryStream(
        conversationHistory,
        messageText,
        imagesBase64: imagesBase64ToSend,
        onToken: (token) {
          if (!mounted || _shouldStopResponse) return;
          if (token.isEmpty) return;

          streamedText += token;
          _fullResponseText = streamedText;
          _currentTypingText = _cleanStreamingTextForDisplay(
            _stripControlTagsForDisplay(streamedText),
          );

          setState(() {
            final chatIndex = _chats.indexWhere((c) => c.id == targetChatId);
            if (chatIndex != -1) {
              final messages = [..._chats[chatIndex].messages];
              final idx = messages.indexWhere((m) => m.id == aiMessageId);
              if (idx != -1) {
                messages[idx] = messages[idx].copyWith(
                  content: _currentTypingText,
                );
                _chats[chatIndex] = _chats[chatIndex].copyWith(
                  messages: messages,
                  updatedAt: DateTime.now(),
                );
                if (_currentChat?.id == targetChatId) {
                  _currentChat = _chats[chatIndex];
                }
              }
            }
          });

          if (!_showScrollToBottom) {
            _scrollToBottomQuick();
          }
        },
        shouldStop: () => _shouldStopResponse,
        maxTokens: 4096,
        useReasoning: _isThinkingMode || _isWebSearchMode,
        reasoningEffort: 'low',
      );
      // Streaming tamamlandıktan sonra cevabı temizle, kaynakları bağla ve
      // arka plandaysa bildirim gönder
      if (streamedText.isNotEmpty) {
        final withoutControl = await _processControlTagsFromResponse(
          streamedText,
        );
        final cleanText = _cleanStreamingTextForDisplay(withoutControl);
        final searchResult = _extractSearchResultFromResponse(
          streamedText,
          messageText,
        );

        List<String>? alternatives;
        String finalContent = cleanText;

        if (cleanText.contains('[MULTI_ANSWER]')) {
          alternatives = cleanText
              .split('[MULTI_ANSWER]')
              .where((s) => s.trim().isNotEmpty)
              .toList();
          if (alternatives.isNotEmpty) {
            finalContent = alternatives.first;
          }
        }

        _handleCalendarEventFromResponse(streamedText);
        final isChartCandidate = streamedText.contains('CHART_CANDIDATE: true');

        setState(() {
          final chatIndex = _chats.indexWhere((c) => c.id == targetChatId);
          if (chatIndex != -1) {
            final messages = [..._chats[chatIndex].messages];
            final idx = messages.indexWhere((m) => m.id == aiMessageId);
            if (idx != -1) {
              messages[idx] = messages[idx].copyWith(
                content: finalContent,
                searchResult: searchResult ?? messages[idx].searchResult,
                isChartCandidate: isChartCandidate,
                alternatives: alternatives,
              );
              _chats[chatIndex] = _chats[chatIndex].copyWith(
                messages: messages,
                updatedAt: DateTime.now(),
              );
              if (_currentChat?.id == targetChatId) {
                _currentChat = _chats[chatIndex];
              }
            }
          }
        });

        // Uygulama arka planda ise kullanıcıya yerel bildirim göster
        if (_isAppInBackground &&
            _notificationsEnabled &&
            cleanText.isNotEmpty) {
          try {
            await NotificationService().showAIResponseNotification(cleanText);
          } catch (_) {
            // Bildirim hatası kullanıcı deneyimini bozmasın
          }
        }
      }

      // Streaming tamamlandıktan sonra durum bayraklarını sıfırla
      setState(() {
        _isLoading = false;
        _isTyping = false;
        _activeResponseChatId = null;
        _typingMessageId = null;
        _currentTypingText = '';
        _fullResponseText = '';
      });

      await _storageService.saveChats(_chats);
      await _maybeGenerateChatTitle(targetChatId);

      // Update statistics
      await _storageService.addUsageMinutes(1); // Add 1 minute for each message
      
      // Count code lines in the response
      final codeBlocks = _collectCodeBlocksFromChat(_currentChat!);
      final codeLines = codeBlocks.fold(0, (sum, block) => sum + block.code.split('\n').where((line) => line.trim().isNotEmpty).length);
      if (codeLines > 0) {
        await _storageService.incrementTotalCodeLines(codeLines);
        await _storageService.updateLanguageUsage('Dart', codeLines); // Assuming Dart for code
      } else {
        await _storageService.incrementTotalCodeLines(1); // Count as 1 code line for non-code messages
      }
    } catch (e) {
      print('❌ Mesaj gönderme hatası: $e');
      if (!mounted) return;

      GreyNotification.show(context, 'Mesaj gönderilemedi.');

      setState(() {
        _isLoading = false;
        _isTyping = false;
        _activeResponseChatId = null;
        _typingMessageId = null;
        _currentTypingText = '';
        _fullResponseText = '';

        _selectedImages.clear();
        _selectedImagesBase64.clear();

        // Hata durumunda içeriği boş AI placeholder mesajını listeden kaldır
        final chatIndex = _chats.indexWhere((c) => c.id == targetChatId);
        if (chatIndex != -1) {
          final current = _chats[chatIndex];
          final filtered = current.messages
              .where((m) => m.id != aiMessageId)
              .toList();
          _chats[chatIndex] = current.copyWith(messages: filtered);
          if (_currentChat?.id == targetChatId) {
            _currentChat = _chats[chatIndex];
          }
        }
      });

      // İnternet bağlantı hatalarında kullanıcıya sohbet içinde bilgilendirme bot mesajı göster
      final errorText = e.toString();
      final bool isConnectionError =
          e is SocketException ||
          errorText.contains('SocketException') ||
          errorText.contains('HandshakeException') ||
          errorText.contains('Failed host lookup') ||
          errorText.contains('Network is unreachable');

      if (isConnectionError) {
        await _addConnectionIssueBotMessage(targetChatId);
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients && mounted) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  // Hızlı scroll için ayrı metod - anında ışınlama
  void _scrollToBottomQuick() {
    if (!mounted || !_scrollController.hasClients) return;

    final isKeyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;
    if (isKeyboardOpen) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
      );
    } else {
      _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
    }
  }

  Future<void> _maybeGenerateChatTitle(String chatId) async {
    try {
      final chatIndex = _chats.indexWhere((c) => c.id == chatId);
      if (chatIndex == -1) return;
      final chat = _chats[chatIndex];

      if (chat.messages.length < 2) return;

      final firstUser = chat.messages.firstWhere(
        (m) => m.isUser,
        orElse: () => chat.messages.first,
      );
      final autoSnippet = firstUser.content.length > 30
          ? '${firstUser.content.substring(0, 30)}...'
          : firstUser.content;

      final currentTitle = chat.title.trim();
      final isAutoTitle =
          currentTitle == 'Yeni Sohbet' || currentTitle == autoSnippet.trim();

      if (!isAutoTitle) return;

      final buffer = StringBuffer();
      const int maxChars = 600;
      for (final msg in chat.messages) {
        final prefix = msg.isUser ? 'Kullanıcı: ' : 'ForeSee: ';
        final line = '$prefix${msg.content}\n';
        if (buffer.length + line.length > maxChars) {
          buffer.write(line.substring(0, maxChars - buffer.length));
          break;
        }
        buffer.write(line);
      }

      final preview = buffer.toString().trim();
      if (preview.isEmpty) return;

      final newTitle = await _openRouterService.generateChatTitle(preview);
      if (newTitle.isEmpty) return;

      setState(() {
        final idx = _chats.indexWhere((c) => c.id == chatId);
        if (idx == -1) return;
        _chats[idx] = _chats[idx].copyWith(
          title: newTitle,
          updatedAt: DateTime.now(),
        );
        if (_currentChat?.id == chatId) {
          _currentChat = _chats[idx];
        }
      });

      await _storageService.saveChats(_chats);
    } catch (_) {}
  }

  // Mesaj gönderilip gönderilemeyeceğini kontrol et
  bool _canSendMessage() {
    final hasText = _messageController.text.trim().isNotEmpty;
    final hasImages = _selectedImages.isNotEmpty;
    return hasText || hasImages;
  }

  void _removeImage(int index) {
    setState(() {
      _selectedImages.removeAt(index);
      _selectedImagesBase64.removeAt(index);
    });
  }

  void _previewSelectedImage(int index) {
    if (index < 0 || index >= _selectedImages.length) return;
    final file = _selectedImages[index];
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => FullscreenImageViewer(
          imageData: file.path,
          heroTag: 'selected_input_image_$index',
        ),
      ),
    );
  }

  Future<void> _processSelectedFile(File file) async {
    if (!await file.exists()) return;

    Uint8List bytes;
    File displayFile = file;

    try {
      final lowerPath = file.path.toLowerCase();
      final isGif = lowerPath.endsWith('.gif');

      if (isGif) {
        // GIF için ilk kareyi alıp PNG olarak kullan
        final rawBytes = await file.readAsBytes();
        try {
          final codec = await ui.instantiateImageCodec(rawBytes);
          final frame = await codec.getNextFrame();
          final ui.Image firstFrame = frame.image;
          final byteData = await firstFrame.toByteData(
            format: ui.ImageByteFormat.png,
          );
          if (byteData != null) {
            bytes = byteData.buffer.asUint8List();

            // UI'da da donuk görsel olsun diye geçici PNG dosyası oluştur
            final tempDir = await getTemporaryDirectory();
            final ts = DateTime.now().millisecondsSinceEpoch;
            final pngPath = '${tempDir.path}/foresee_gif_frame_$ts.png';
            displayFile = await File(pngPath).writeAsBytes(bytes, flush: true);
          } else {
            // Fallback: orijinal GIF byte'larını kullan
            bytes = rawBytes;
          }
        } catch (_) {
          // GIF çözümlenemiyorsa, olduğu gibi kullan
          bytes = await file.readAsBytes();
        }
      } else {
        bytes = await file.readAsBytes();
      }
    } catch (_) {
      // Her ihtimale karşı son çare: dosyayı olduğu gibi oku
      bytes = await file.readAsBytes();
    }

    final base64Image = base64Encode(bytes);

    setState(() {
      _selectedImages.add(displayFile);
      _selectedImagesBase64.add(base64Image);
    });
  }

  Future<void> _pickImage() async {
    if (_selectedImages.length >= 3) {
      GreyNotification.show(context, 'En fazla 3 dosya ekleyebilirsiniz');
      return;
    }

    if (!mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: themeService.isDarkMode ? const Color(0xFF1A1A1A) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(Icons.photo_camera, color: themeService.isDarkMode ? Colors.white : Colors.black87),
                title: Text(
                  'Kamera',
                  style: TextStyle(color: themeService.isDarkMode ? Colors.white : Colors.black87),
                ),
                onTap: () async {
                  Navigator.of(ctx).pop();
                  await _pickFromCamera();
                },
              ),
              Divider(height: 1, color: themeService.isDarkMode ? Colors.white12 : Colors.black12),
              ListTile(
                leading: Icon(Icons.folder, color: themeService.isDarkMode ? Colors.white : Colors.black87),
                title: Text(
                  'Dosyalar',
                  style: TextStyle(color: themeService.isDarkMode ? Colors.white : Colors.black87),
                ),
                onTap: () async {
                  Navigator.of(ctx).pop();
                  await _pickFromFiles();
                },
              ),
              Divider(height: 1, color: themeService.isDarkMode ? Colors.white12 : Colors.black12),
              ListTile(
                leading: FaIcon(
                  FontAwesomeIcons.filePdf,
                  color: themeService.isDarkMode ? Colors.white : Colors.black87,
                  size: 20,
                ),
                title: Text(
                  'PDF Seç',
                  style: TextStyle(color: themeService.isDarkMode ? Colors.white : Colors.black87),
                ),
                onTap: () async {
                  Navigator.of(ctx).pop();
                  await _handlePdfSelection();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _pickFromFiles() async {
    if (_selectedImages.length >= 3) {
      GreyNotification.show(context, 'En fazla 3 dosya ekleyebilirsiniz');
      return;
    }

    try {
      final remaining = 3 - _selectedImages.length;
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: true,
      );

      if (result == null || result.files.isEmpty) return;

      final files = result.files
          .where((f) => f.path != null && f.path!.isNotEmpty)
          .take(remaining)
          .toList();

      for (final f in files) {
        final path = f.path!;
        await _processSelectedFile(File(path));
      }

      if (result.files.length > remaining) {
        GreyNotification.show(context, 'En fazla 3 dosya seçebilirsiniz');
      }
    } catch (_) {
      if (!mounted) return;
      GreyNotification.show(context, 'Görsel eklenemedi');
    }
  }

  Future<void> _handleClipboardPaste() async {
    try {
      final bytes = await Pasteboard.image;
      if (bytes != null) {
        if (_selectedImages.length >= 3) {
          GreyNotification.show(context, 'En fazla 3 dosya ekleyebilirsiniz');
          return;
        }

        final tempDir = await getTemporaryDirectory();
        final file = File(
          '${tempDir.path}/clipboard_${DateTime.now().millisecondsSinceEpoch}.jpg',
        );
        await file.writeAsBytes(bytes);

        await _processSelectedFile(file);
      }
    } catch (e) {
      print('❌ Panodan görsel yapıştırma hatası: $e');
    }
  }

  Future<void> _pickFromCamera() async {
    if (_selectedImages.length >= 3) {
      GreyNotification.show(context, 'En fazla 3 dosya ekleyebilirsiniz');
      return;
    }

    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(source: ImageSource.camera);
      if (picked == null) return;
      final file = File(picked.path);
      await _processSelectedFile(file);
    } catch (_) {
      if (!mounted) return;
      GreyNotification.show(context, 'Kamera açılamadı veya görsel eklenemedi');
    }
  }

  Future<void> _startVoiceRecording() async {
    if (_isLoading || _activeResponseChatId != null) {
      GreyNotification.show(
        context,
        'AI cevap veriyor, lütfen bitmesini bekleyin...',
      );
      return;
    }
    if (_isRecordingVoice) return;

    final initialText = _messageController.text;
    final success = await _speechService.startListening(
      onText: (text) {
        _lastVoiceText = text;
        if (!mounted) return;
        setState(() {
          final separator = initialText.isEmpty || initialText.endsWith(' ')
              ? ''
              : ' ';
          _messageController.text = '$initialText$separator$text';
          _messageController.selection = TextSelection.fromPosition(
            TextPosition(offset: _messageController.text.length),
          );
        });
      },
      onLevelChanged: (level) {
        if (!mounted) return;

        setState(() {
          _recordLevel = level;
        });

        // Sessizlik tespiti: seviye çok düşükse zamanlayıcı başlat, tekrar yükselirse iptal et
        const double silenceThreshold =
            0.08; // 0-1 arası; çok küçük sesleri sessizlik say
        const Duration silenceDuration = Duration(milliseconds: 1200);

        if (level < silenceThreshold) {
          _silenceTimer?.cancel();
          _silenceTimer = Timer(silenceDuration, () {
            if (mounted && _isRecordingVoice) {
              _stopVoiceRecording();
            }
          });
        } else {
          // Ses tekrar yükseldi; otomatik durdurma zamanlayıcısını iptal et
          _silenceTimer?.cancel();
        }
      },
      onError: (message) {
        if (!mounted) return;
        GreyNotification.show(context, 'STT hatası: $message');
      },
    );

    if (!mounted) return;

    if (success) {
      setState(() {
        _isRecordingVoice = true;
      });
    } else {
      setState(() {
        _isRecordingVoice = false;
        _recordLevel = 0.0;
      });
    }
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

  void _toggleImageGenerationMode() {
    setState(() {
      _isImageGenerationMode = !_isImageGenerationMode;
      if (_isImageGenerationMode) {
        _isWebSearchMode = false;
        _isCanvasMode = false;
        _isThinkingMode = false;
      }
      _showActionMenu = false;
    });
  }

  void _toggleWebSearchMode() {
    setState(() {
      _isWebSearchMode = !_isWebSearchMode;
      if (_isWebSearchMode) {
        _isImageGenerationMode = false;
        _isCanvasMode = false;
        _isThinkingMode = false;
      }
      _showActionMenu = false;
    });
  }

  void _toggleCanvasMode() {
    setState(() {
      _isCanvasMode = !_isCanvasMode;
      if (_isCanvasMode) {
        _isImageGenerationMode = false;
        _isWebSearchMode = false;
        _isThinkingMode = false;
      }
      _showActionMenu = false;
    });
  }

  void _toggleThinkingMode() {
    setState(() {
      _isThinkingMode = !_isThinkingMode;
      if (_isThinkingMode) {
        _isImageGenerationMode = false;
        _isWebSearchMode = false;
        _isCanvasMode = false;
      }
      _showActionMenu = false;
    });
  }

  Widget _buildInputArea() {
    return Stack(
      alignment: Alignment.bottomCenter,
      clipBehavior: Clip.none,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Action Menu
                if (_showActionMenu)
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: themeService.isDarkMode 
                          ? const Color(0xFF1A1A1A)
                          : Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildActionMenuItem(
                          icon: FontAwesomeIcons.paperclip,
                          label: 'Dosya ekle',
                          onTap: () => _pickImage(),
                          isActive: _selectedImages.isNotEmpty,
                        ),
                        _buildActionMenuItem(
                          icon: FontAwesomeIcons.globe,
                          label: 'Web\'de arama',
                          onTap: _toggleWebSearchMode,
                          isActive: _isWebSearchMode,
                        ),
                        _buildActionMenuItem(
                          icon: FontAwesomeIcons.images,
                          label: 'Görsel oluştur',
                          onTap: _toggleImageGenerationMode,
                          isActive: _isImageGenerationMode,
                        ),
                      ],
                    ),
                  ),

                // Mode buttons above input
                Container(
                  margin: const EdgeInsets.only(bottom: 4),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      // Grup sohbetinde kısıtlı araçlar
                      if (_currentChat?.isGroup == true) ...[
                        // Sadece Görsel ve Web Arama (kısıtlı)
                        GestureDetector(
                          onTap: _toggleImageGenerationMode,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: _isImageGenerationMode
                                  ? Colors.blue
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: _isImageGenerationMode
                                    ? Colors.blue
                                    : (themeService.isDarkMode ? Colors.white24 : Colors.black26),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                FaIcon(
                                  FontAwesomeIcons.images,
                                  size: 16,
                                  color: _isImageGenerationMode
                                      ? Colors.white
                                      : (themeService.isDarkMode ? Colors.white54 : Colors.black54),
                                ),
                                if (_isImageGenerationMode) ...[
                                  const SizedBox(width: 6),
                                  const Text(
                                    'Görsel oluştur',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Web Search Button (Reused logic but simplified for group if needed)
                        GestureDetector(
                          onTap: _toggleWebSearchMode,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: _isWebSearchMode
                                  ? Colors.green
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: _isWebSearchMode
                                    ? Colors.green
                                    : (themeService.isDarkMode ? Colors.white24 : Colors.black26),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                FaIcon(
                                  FontAwesomeIcons.globe,
                                  size: 16,
                                  color: _isWebSearchMode
                                      ? Colors.white
                                      : (themeService.isDarkMode ? Colors.white54 : Colors.black54),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ] else ...[
                        // Normal Chat Tools (Existing)
                        // Görsel oluştur
                        GestureDetector(
                          onTap: _toggleImageGenerationMode,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: _isImageGenerationMode
                                  ? Colors.blue
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: _isImageGenerationMode
                                    ? Colors.blue
                                    : (themeService.isDarkMode ? Colors.white24 : Colors.black26),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                FaIcon(
                                  FontAwesomeIcons.images,
                                  size: 16,
                                  color: _isImageGenerationMode
                                      ? Colors.white
                                      : (themeService.isDarkMode ? Colors.white54 : Colors.black54),
                                ),
                                if (_isImageGenerationMode) ...[
                                  const SizedBox(width: 6),
                                  const Text(
                                    'Görsel oluştur',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Web arama
                        GestureDetector(
                          onTap: _toggleWebSearchMode,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: _isWebSearchMode
                                  ? Colors.blue
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: _isWebSearchMode
                                    ? Colors.blue
                                    : (themeService.isDarkMode ? Colors.white24 : Colors.black54),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                FaIcon(
                                  FontAwesomeIcons.globe,
                                  size: 16,
                                  color: _isWebSearchMode
                                      ? Colors.white
                                      : (themeService.isDarkMode ? Colors.white54 : Colors.black54),
                                ),
                                if (_isWebSearchMode) ...[
                                  const SizedBox(width: 6),
                                  const Text(
                                    'Web arama',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Canvas modu
                        GestureDetector(
                          onTap: _toggleCanvasMode,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: _isCanvasMode
                                  ? Colors.blue
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: _isCanvasMode
                                    ? Colors.blue
                                    : (themeService.isDarkMode ? Colors.white24 : Colors.black26),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                FaIcon(
                                  FontAwesomeIcons.pen,
                                  size: 16,
                                  color: _isCanvasMode
                                      ? Colors.white
                                      : (themeService.isDarkMode ? Colors.white54 : Colors.black54),
                                ),
                                if (_isCanvasMode) ...[
                                  const SizedBox(width: 6),
                                  const Text(
                                    'Canvas',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Düşünme modu
                        GestureDetector(
                          onTap: _toggleThinkingMode,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: _isThinkingMode
                                  ? Colors.blue
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: _isThinkingMode
                                    ? Colors.blue
                                    : (themeService.isDarkMode ? Colors.white24 : Colors.black26),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                FaIcon(
                                  FontAwesomeIcons.brain,
                                  size: 16,
                                  color: _isThinkingMode
                                      ? Colors.white
                                      : (themeService.isDarkMode ? Colors.white54 : Colors.black54),
                                ),
                                if (_isThinkingMode) ...[
                                  const SizedBox(width: 6),
                                  const Text(
                                    'Düşünme',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                Container(
                  decoration: BoxDecoration(
                    color: themeService.isDarkMode
                        ? const Color(0xFF181818)
                        : const Color(0xFFDFDFDF),
                    borderRadius: BorderRadius.circular(25),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Top row: Text field + send button
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Left side: Paperclip + text field
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Text input field (üstte)
                                  Container(
                                    decoration: BoxDecoration(
                                      color: themeService.isDarkMode
                                          ? const Color(0xFF181818)
                                          : const Color(0xFFDFDFDF),
                                      borderRadius: BorderRadius.circular(25),
                                    ),
                                    child: TextField(
                                      controller: _messageController,
                                      focusNode: _messageFocusNode,
                                      style: TextStyle(
                                        color: themeService.isDarkMode ? Colors.white : Colors.black87,
                                        // Aktif modlar için özel renk
                                        decorationColor:
                                            _isImageGenerationMode ||
                                                _isWebSearchMode ||
                                                _isCanvasMode ||
                                                _isThinkingMode
                                            ? Colors.blue
                                            : (themeService.isDarkMode ? Colors.white : Colors.black87),
                                      ),
                                      decoration: InputDecoration(
                                        hintText: _isImageGenerationMode
                                            ? 'Görsel tarifi veriniz...'
                                            : _isWebSearchMode
                                            ? 'Web\'de arama yapın...'
                                            : _isCanvasMode
                                            ? 'Kod yazmak için talimat verin...'
                                            : _isThinkingMode
                                            ? 'Daha derin bir cevap isteyin...'
                                            : (_currentChat == null ||
                                                      _currentChat!.messages.isEmpty
                                                  ? 'ForeSee\'e bir şey sor...'
                                                  : 'Mesajınızı yazın...'),
                                        hintStyle: TextStyle(
                                          color: themeService.isDarkMode ? Colors.white54 : Colors.black87,
                                        ),
                                        border: InputBorder.none,
                                        contentPadding: const EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: 4,
                                        ),
                                      ),
                                      minLines: 1,
                                      maxLines: 5,
                                      keyboardType: TextInputType.multiline,
                                      textInputAction: TextInputAction.newline,
                                      onChanged: (text) {
                                        setState(() {});
                                      },
                                    ),
                                  ),
                                  const SizedBox(height: 1),
                                  // Bottom row: Paperclip + mic + send
                                  Row(
                                    children: [
                                      if (_currentChat?.isGroup != true)
                                        IconButton(
                                          icon: Transform.rotate(
                                            angle: -0.785398,
                                            child: const FaIcon(
                                              FontAwesomeIcons.paperclip,
                                              size: 16,
                                            ),
                                          ),
                                          color: themeService.isDarkMode ? Colors.white70 : Colors.black87,
                                          onPressed: _pickImage,
                                        ),
                                      if (_pickedPdfFile != null) ...[
                                        Container(
                                          margin: const EdgeInsets.only(right: 8),
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 8,
                                          ),
                                          decoration: BoxDecoration(
                                            color: themeService.isDarkMode ? Colors.red.withOpacity(0.1) : Colors.red.withOpacity(0.05),
                                            borderRadius: BorderRadius.circular(8),
                                            border: Border.all(color: themeService.isDarkMode ? Colors.red.withOpacity(0.3) : Colors.red.withOpacity(0.2)),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Icon(
                                                Icons.picture_as_pdf,
                                                color: Colors.red,
                                                size: 16,
                                              ),
                                              const SizedBox(width: 8),
                                              Flexible(
                                                child: Text(
                                                  _pickedPdfFile!.path
                                                      .split(Platform.pathSeparator)
                                                      .last,
                                                  style: TextStyle(
                                                    color: themeService.isDarkMode ? Colors.white : Colors.black87,
                                                    fontSize: 13,
                                                  ),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              GestureDetector(
                                                onTap: () {
                                                  setState(() {
                                                    _pickedPdfFile = null;
                                                    _pickedPdfText = null;
                                                  });
                                                },
                                                child: Icon(
                                                  Icons.close,
                                                  color: themeService.isDarkMode ? Colors.white54 : Colors.black54,
                                                  size: 18,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                      if (_selectedImages.isNotEmpty) ...[
                                        SizedBox(
                                          height: 40,
                                          child: ListView.separated(
                                            scrollDirection: Axis.horizontal,
                                            itemCount: _selectedImages.length,
                                            separatorBuilder: (_, __) =>
                                                const SizedBox(width: 7),
                                            itemBuilder: (context, index) {
                                              final file = _selectedImages[index];
                                              return GestureDetector(
                                                onTap: () =>
                                                    _previewSelectedImage(index),
                                                child: Stack(
                                                  children: [
                                                    Hero(
                                                      tag:
                                                          'selected_input_image_$index',
                                                      child: ClipRRect(
                                                        borderRadius:
                                                            BorderRadius.circular(8),
                                                        child: Image.file(
                                                          File(file.path),
                                                          width: 40,
                                                          height: 40,
                                                          fit: BoxFit.cover,
                                                        ),
                                                      ),
                                                    ),
                                                    Positioned(
                                                      top: 2,
                                                      right: 2,
                                                      child: GestureDetector(
                                                        onTap: () {
                                                          setState(() {
                                                            _selectedImages
                                                                .removeAt(index);
                                                          });
                                                        },
                                                        child: Container(
                                                          width: 16,
                                                          height: 16,
                                                          decoration: BoxDecoration(
                                                            color: themeService.isDarkMode ? Colors.black54 : Colors.black26,
                                                            shape: BoxShape.circle,
                                                          ),
                                                          child: Icon(
                                                            Icons.close,
                                                            color: themeService.isDarkMode ? Colors.white : Colors.black87,
                                                            size: 12,
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              );
                                            },
                                          ),
                                        ),
                                      ],
                                      const Spacer(),
                                      // Mic button
                                      if (_isRecordingVoice)
                                        IconButton(
                                          onPressed: _stopVoiceRecording,
                                          icon: const FaIcon(
                                            FontAwesomeIcons.microphone,
                                            size: 16,
                                            color: Colors.redAccent,
                                          ),
                                          constraints: const BoxConstraints(),
                                          padding: const EdgeInsets.all(8),
                                        ),
                                      if (!_isRecordingVoice)
                                        IconButton(
                                          onPressed: _startVoiceRecording,
                                          icon: FaIcon(
                                            FontAwesomeIcons.microphone,
                                            size: 16,
                                            color: themeService.isDarkMode ? Colors.white70 : Colors.black87,
                                          ),
                                          constraints: const BoxConstraints(),
                                          padding: const EdgeInsets.all(8),
                                        ),
                                      // Send button
                                      Container(
                                        width: 40,
                                        height: 40,
                                        decoration: BoxDecoration(
                                          color: _isLoading
                                              ? Colors.red
                                              : (_canSendMessage()
                                                    ? (themeService.isDarkMode ? Colors.white : Colors.black)
                                                    : (themeService.isDarkMode
                                                          ? Colors.white.withOpacity(0.3)
                                                          : Colors.black.withOpacity(0.3))),
                                          shape: BoxShape.circle,
                                        ),
                                        child: IconButton(
                                          onPressed: () async {
                                            if (_isLoading) {
                                              _stopAIResponse();
                                            } else if (_canSendMessage()) {
                                              await _sendMessage();
                                            } else {
                                              GreyNotification.show(
                                                context,
                                                'Boş mesaj gönderilemez',
                                              );
                                            }
                                          },
                                          icon: _isLoading
                                              ? const FaIcon(
                                                  FontAwesomeIcons.stop,
                                                  size: 16,
                                                  color: Colors.white,
                                                )
                                              : FaIcon(
                                                  FontAwesomeIcons.arrowUp,
                                                  size: 16,
                                                  color: _canSendMessage()
                                                      ? (themeService.isDarkMode ? Colors.black : Colors.white)
                                                      : (themeService.isDarkMode ? Colors.black.withOpacity(0.5) : Colors.white.withOpacity(0.5)),
                                                ),
                                          constraints: const BoxConstraints(),
                                          padding: EdgeInsets.zero,
                                        ),
                                      ),
                                    ],
                                  ),
                                  _buildCodeReferenceChips(),
                                ],
                              ),
                            ),
                          ],
                        ),
                        _buildMentionPanel(),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
}

  Widget _buildActionMenuItem({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isActive = false,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: isActive ? Colors.blue : (themeService.isDarkMode ? const Color(0xFF2A2A2A) : Colors.grey.shade300),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: FaIcon(
                  icon,
                  color: isActive ? Colors.white : (themeService.isDarkMode ? Colors.white : Colors.black87),
                  size: 16,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                color: isActive ? Colors.blue : (themeService.isDarkMode ? Colors.white : Colors.black87),
                fontSize: 15,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _loadInitialSettings() async {
    _isSmartContextEnabled = await _storageService.getIsSmartContextEnabled();
    setState(() {});
  }

  void _initContextListener() {
    _contextSubscription = _contextService.onScreenContentChanged.listen((
      content,
    ) async {
      if (!_isSmartContextEnabled) return;

      // AI'a gönderip bir öneri iste
      final suggestion = await _openRouterService.getSuggestionForContext(
        content,
      );
      if (suggestion.isNotEmpty && suggestion != 'NULL') {
        NotificationService().showContextualSuggestion(suggestion, content);
      }
    });
  }

  void _handleAlternativeSelected(Message message, int index) {
    setState(() {
      final chatIndex = _chats.indexWhere((c) => c.id == message.chatId);
      if (chatIndex == -1) return;

      final messages = [..._chats[chatIndex].messages];
      final msgIndex = messages.indexWhere((m) => m.id == message.id);
      if (msgIndex == -1) return;

      messages[msgIndex] = messages[msgIndex].copyWith(
        content: message.alternatives![index],
        displayAlternativeIndex: index,
        alternatives: null, // Seçim yapıldıktan sonra alternatifleri temizle
      );

      _chats[chatIndex] = _chats[chatIndex].copyWith(messages: messages);
      if (_currentChat?.id == message.chatId) {
        _currentChat = _chats[chatIndex];
      }
    });
    _storageService.saveChats(_chats);
  }

  void _generateChartForMessage(Message message) {
    final lineChartData = _chartService.generateLineChartFromExpression(
      message.content,
    );
    if (lineChartData == null) {
      GreyNotification.show(context, 'Grafik oluşturulamadı.');
      return;
    }

    setState(() {
      final chatIndex = _chats.indexWhere((c) => c.id == message.chatId);
      if (chatIndex == -1) return;

      final messages = [..._chats[chatIndex].messages];
      final msgIndex = messages.indexWhere((m) => m.id == message.id);
      if (msgIndex == -1) return;

      messages[msgIndex] = messages[msgIndex].copyWith(
        chartData: lineChartData,
      );

      _chats[chatIndex] = _chats[chatIndex].copyWith(messages: messages);
      if (_currentChat?.id == message.chatId) {
        _currentChat = _chats[chatIndex];
      }
    });
  }

  void _handleCalendarEventFromResponse(String fullText) async {
    final eventRegex = RegExp(r'\[CALENDAR_EVENT\]: (.*)');
    final match = eventRegex.firstMatch(fullText);
    if (match == null) return;

    final jsonString = match.group(1);
    if (jsonString == null) return;

    try {
      final eventData = jsonDecode(jsonString);
      final title = eventData['title'] as String?;
      final startTimeStr = eventData['startTime'] as String?;
      final endTimeStr = eventData['endTime'] as String?;

      if (title == null || startTimeStr == null || endTimeStr == null) return;

      final startTime = DateTime.tryParse(startTimeStr);
      final endTime = DateTime.tryParse(endTimeStr);

      if (startTime == null || endTime == null) return;

      // Paneli gösteden doğrudan ekle
      final calendars = await _calendarService.getCalendars();
      if (calendars.isEmpty || !mounted) {
        GreyNotification.show(context, 'Kullanılabilir takvim bulunamadı.');
        return;
      }

      final writableCalendar = calendars.firstWhere(
        (cal) => cal.isReadOnly == false,
        orElse: () => calendars.first,
      );

      final eventId = await _calendarService.addEvent(
        calendarId: writableCalendar.id!,
        title: title,
        startTime: startTime,
        endTime: endTime,
      );

      if (mounted) {
        if (eventId != null) {
          GreyNotification.show(context, 'Takvim etkinliği eklendi!');
        } else {
          GreyNotification.show(context, 'Etkinlik eklenemedi.');
        }
      }
    } catch (e) {
      print('Error parsing calendar event JSON: $e');
    }
  }

  void _showAddCalendarEventPanel(
    String title,
    DateTime startTime,
    DateTime endTime,
  ) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => AddToCalendarPanel(
        title: title,
        startTime: startTime,
        endTime: endTime,
        calendarService: _calendarService,
      ),
    );
  }

  void _navigateToSetting(String settingKey) {
    _scaffoldKey.currentState?.openDrawer();
    // Sidebar animasyonunun bitmesi için küçük bir gecikme
    Future.delayed(const Duration(milliseconds: 300), () {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => SettingsScreen(highlightKey: settingKey),
        ),
      );
    });
  }

  @override
  void dispose() {
    _contextSubscription?.cancel();
    _intentDataStreamSubscription?.cancel();
    _intentDataStreamSubscriptionMedia?.cancel();
    _messageController.dispose();
    _messageFocusNode.dispose();
    _scrollController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    _speechService.stopListening();
    _silenceTimer?.cancel();
    super.dispose();
  }

  // Çift geri tuşu kontrolü
  Future<bool> _onWillPop() async {
    final now = DateTime.now();

    // İlk geri tuşu veya 2 saniyeden fazla geçmişse
    if (_lastBackPressed == null ||
        now.difference(_lastBackPressed!) > const Duration(seconds: 2)) {
      _lastBackPressed = now;

      // Kullanıcıya bilgi ver
      GreyNotification.show(
        context,
        'Çıkmak için tekrar geri tuşuna 2 kez basın',
      );

      return false; // Çıkışı engelle
    }

    // 2 saniye içinde ikinci kez basıldı, çık
    return true;
  }

  void _showReasoningSheet(String reasoning) {
    if (reasoning.isEmpty) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          expand: false,
          builder: (_, controller) {
            return Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Row(
                    children: [
                      Icon(
                        Icons.psychology,
                        color: Colors.blue.shade300,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Düşünme Süreci',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: ListView(
                      controller: controller,
                      children: [
                        Text(
                          reasoning,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showGroupSettings() {
    if (_currentChat == null || !_currentChat!.isGroup) return;

    final members = _currentChat!.memberDetails ?? [];

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      isScrollControlled: true,
      builder: (context) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 24),
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Center(
                  child: CircleAvatar(
                    radius: 40,
                    backgroundColor: Colors.blueGrey,
                    child: const Icon(
                      Icons.group,
                      size: 40,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Center(
                  child: Text(
                    _currentChat!.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Center(
                  child: Text(
                    '${members.length} üye',
                    style: const TextStyle(color: Colors.white54, fontSize: 14),
                  ),
                ),
                const SizedBox(height: 32),
                const Text(
                  'Üyeler',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                if (members.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8.0),
                    child: Text(
                      'Üye bilgisi yüklenemedi',
                      style: TextStyle(color: Colors.white38),
                    ),
                  )
                else
                  ...members
                      .take(5)
                      .map(
                        (m) => ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: CircleAvatar(
                            backgroundColor: Colors.grey[800],
                            backgroundImage: m['profilePhotoUrl'] != null
                                ? NetworkImage(m['profilePhotoUrl'])
                                : null,
                            child: m['profilePhotoUrl'] == null
                                ? Text(
                                    (m['username'] as String? ?? '?')[0]
                                        .toUpperCase(),
                                    style: const TextStyle(color: Colors.white),
                                  )
                                : null,
                          ),
                          title: Text(
                            m['username'] ?? 'Bilinmeyen Kullanıcı',
                            style: const TextStyle(color: Colors.white),
                          ),
                          trailing: (m['uid'] == _currentChat!.createdBy)
                              ? Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.blueAccent.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text(
                                    'Admin',
                                    style: TextStyle(
                                      color: Colors.blueAccent,
                                      fontSize: 10,
                                    ),
                                  ),
                                )
                              : null,
                        ),
                      ),
                if (members.length > 5)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Center(
                      child: Text(
                        '+${members.length - 5} diğer üye',
                        style: const TextStyle(color: Colors.white38),
                      ),
                    ),
                  ),

                const Divider(color: Colors.white12, height: 32),

                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(
                    Icons.notifications_off_outlined,
                    color: Colors.white,
                  ),
                  title: const Text(
                    'Bildirimleri Sessize Al',
                    style: TextStyle(color: Colors.white),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    GreyNotification.show(
                      context,
                      'Bildirimler 1 hafta süreyle kapatıldı (Mock)',
                    );
                  },
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.share, color: Colors.white),
                  title: const Text(
                    'Davet Bağlantısını Paylaş',
                    style: TextStyle(color: Colors.white),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    if (_currentChat!.groupId != null) {
                      final link = 'foresee://group/${_currentChat!.groupId}';
                      Clipboard.setData(ClipboardData(text: link));
                      GreyNotification.show(
                        context,
                        'Davet bağlantısı kopyalandı',
                      );
                    }
                  },
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(
                    Icons.exit_to_app,
                    color: Colors.redAccent,
                  ),
                  title: const Text(
                    'Gruptan Ayrıl',
                    style: TextStyle(color: Colors.redAccent),
                  ),
                  onTap: () async {
                    Navigator.pop(context);
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        backgroundColor: const Color(0xFF2A2A2A),
                        title: const Text(
                          'Gruptan Ayrıl?',
                          style: TextStyle(color: Colors.white),
                        ),
                        content: const Text(
                          'Bu gruptan çıkmak istediğinize emin misiniz? Sohbet listesinden kaldırılacak.',
                          style: TextStyle(color: Colors.white70),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: const Text(
                              'İptal',
                              style: TextStyle(color: Colors.white60),
                            ),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            child: const Text(
                              'Ayrıl',
                              style: TextStyle(color: Colors.redAccent),
                            ),
                          ),
                        ],
                      ),
                    );

                    if (confirm == true) {
                      try {
                        await FirestoreService.instance.leaveGroup(
                          _currentChat!.groupId!,
                          FirebaseAuth.instance.currentUser!.uid,
                        );
                        _handleChatDelete(_currentChat!);
                      } catch (e) {
                        GreyNotification.show(context, 'Hata: $e');
                      }
                    }
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMentionPanel() {
    if (_filteredMembers.isEmpty) return const SizedBox.shrink();

    return Positioned(
      bottom: 90, // Input'un üstüne sabitle
      left: 16,
      right: 16,
      child: Material(
        elevation: 8,
        borderRadius: BorderRadius.circular(12),
        color: const Color(0xFF1E1E1E),
        child: Container(
          constraints: const BoxConstraints(maxHeight: 200),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E1E),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: ListView.builder(
            itemCount: _filteredMembers.length,
            shrinkWrap: true,
            padding: EdgeInsets.zero,
            itemBuilder: (context, index) {
              final member = _filteredMembers[index];
              final username = member['username'] as String;
              final isAI = member['isAI'] == true;

              return ListTile(
                leading: CircleAvatar(
                  radius: 14,
                  backgroundColor: isAI ? Colors.white : Colors.blueGrey,
                  backgroundImage: member['profilePhotoUrl'] != null
                      ? NetworkImage(member['profilePhotoUrl'])
                      : (isAI ? AssetImage(themeService.getLogoPath('logo3.png')) : null)
                            as ImageProvider?,
                  child: (member['profilePhotoUrl'] == null && !isAI)
                      ? Text(
                          username[0].toUpperCase(),
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.white,
                          ),
                        )
                      : null,
                ),
                title: Text(
                  username,
                  style: const TextStyle(color: Colors.white),
                ),
                onTap: () {
                  _handleMentionSelection(username);
                },
              );
            },
          ),
        ),
      ),
    );
  }

  void _handleMentionSelection(String username) {
    // Get text and selection
    final text = _messageController.text;
    final selection = _messageController.selection;

    // Find the range to replace. We assume the cursor is at the end of the mention.
    // Simple approach: Replace the last occurrence of @query with @username
    // BUT checking around cursor is better.

    // For now, simple implementation assuming typing at end:
    final match = RegExp(
      r'@(\w*)$',
    ).firstMatch(text.substring(0, selection.baseOffset));
    if (match != null) {
      final start = match.start;
      final end = selection.baseOffset;

      final newText = text.replaceRange(start, end, '@$username ');
      _messageController.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(
          offset: start + username.length + 2,
        ), // +2 for @ and space
      );
    }

    setState(() {
      _showMentionPanel = false;
      _mentionQuery = '';
    });
  }

  Future<void> _handleCreateGroupChat() async {
    User? fbUser = FirebaseAuth.instance.currentUser;

    // Eğer oturum yoksa anonim giriş yap ki Firestore çalışsın
    if (fbUser == null) {
      try {
        final cred = await AuthService.instance.signInAnonymously();
        fbUser = cred.user;
      } catch (e) {
        debugPrint('Firestore Anon Auth Error: $e');
        if (mounted) {
          GreyNotification.show(
            context,
            'Hata: Firestore oturumu açılamadı ($e).',
          );
        }
        return;
      }
    }

    if (fbUser == null) return;

    final firestore = FirestoreService.instance;
    final userDoc = await firestore.getUserProfile(fbUser.uid);
    String? username = userDoc?['username'];

    if (username == null) {
      // Local UserProfile'dan ismi almayı dene
      if (_userProfile != null && _userProfile!.name.isNotEmpty) {
        username = _userProfile!.name;
        // Firestore'a kaydet
        await firestore.createUserProfile(
          uid: fbUser.uid,
          username: username,
          displayName: username,
          email: fbUser.email ?? 'anon@foresee.app',
        );
      } else {
        final created = await _showUsernameDialogForGroup(
          context,
          fbUser.uid,
          fbUser.email ?? 'anon@foresee.app',
        );
        if (!created) return;
        final updatedDoc = await firestore.getUserProfile(fbUser.uid);
        username = updatedDoc?['username'];
      }
    }

    if (username == null) return;

    if (mounted) {
      _showGroupNameEntryDialog(context, fbUser.uid, username);
    }
  }

  Future<bool> _showUsernameDialogForGroup(
    BuildContext context,
    String uid,
    String email,
  ) async {
    return await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (context) {
            final theme = Theme.of(context);
            String? errorText;
            bool isChecking = false;
            bool isAvailable = false;
            final controller = TextEditingController();
            Timer? debounceTimer;

            return StatefulBuilder(
              builder: (context, setState) {
                return AlertDialog(
                  backgroundColor: theme.dialogBackgroundColor,
                  title: Text(
                    'ForeSee Online',
                    style: TextStyle(
                      color: theme.textTheme.titleLarge?.color,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Her grupta gözükcek olan sana özel kullanıcı adını belirle',
                        style: TextStyle(
                          color: theme.textTheme.bodyMedium?.color?.withOpacity(
                            0.7,
                          ),
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: controller,
                        style: TextStyle(
                          color: theme.textTheme.bodyMedium?.color,
                          fontWeight: FontWeight.w500,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Kullanıcı Adı',
                          hintStyle: TextStyle(
                            color: theme.textTheme.bodySmall?.color
                                ?.withOpacity(0.4),
                          ),
                          errorText: errorText,
                          enabledBorder: UnderlineInputBorder(
                            borderSide: BorderSide(color: theme.dividerColor),
                          ),
                          focusedBorder: UnderlineInputBorder(
                            borderSide: BorderSide(color: theme.primaryColor),
                          ),
                          suffixIcon: isChecking
                              ? const Padding(
                                  padding: EdgeInsets.all(12),
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : (controller.text.isNotEmpty
                                    ? (isAvailable
                                          ? const Icon(
                                              Icons.check_circle,
                                              color: Colors.green,
                                            )
                                          : (errorText != null
                                                ? const Icon(
                                                    Icons.cancel,
                                                    color: Colors.redAccent,
                                                  )
                                                : null))
                                    : null),
                        ),
                        onChanged: (val) {
                          debounceTimer?.cancel();
                          setState(() {
                            isAvailable = false;
                            errorText = null;
                            isChecking = false;
                          });

                          if (val.trim().length < 3) return;

                          debounceTimer = Timer(
                            const Duration(milliseconds: 500),
                            () async {
                              setState(() => isChecking = true);
                              try {
                                final available = await FirestoreService
                                    .instance
                                    .isUsernameAvailable(val.trim());
                                if (context.mounted) {
                                  setState(() {
                                    isChecking = false;
                                    isAvailable = available;
                                    if (!available) {
                                      errorText =
                                          'Bu kullanıcı adı zaten alınmış';
                                    }
                                  });
                                }
                              } catch (_) {
                                if (context.mounted) {
                                  setState(() => isChecking = false);
                                }
                              }
                            },
                          );
                        },
                      ),
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: Text(
                        'İptal',
                        style: TextStyle(
                          color: theme.textTheme.bodySmall?.color?.withOpacity(
                            0.7,
                          ),
                        ),
                      ),
                    ),
                    ElevatedButton(
                      onPressed: isAvailable && !isChecking
                          ? () async {
                              final username = controller.text.trim();
                              // Save to Firestore
                              await FirestoreService.instance.createUserProfile(
                                uid: uid,
                                email: email,
                                displayName: username,
                                username: username,
                              );
                              Navigator.pop(context, true);
                            }
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                      ),
                      child: const Text(
                        'Kaydet',
                        style: TextStyle(color: Colors.black),
                      ),
                    ),
                  ],
                );
              },
            );
          },
        ) ??
        false;
  }

  void _showGroupNameEntryDialog(
    BuildContext context,
    String uid,
    String username,
  ) {
    final nameController = TextEditingController();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: themeService.isDarkMode ? const Color(0xFF1A1A1A) : Theme.of(context).colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Grup Adı Belirle',
          style: TextStyle(color: themeService.isDarkMode ? Colors.white : Colors.black87, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Harika bir grup adı ile başla.',
              style: TextStyle(color: themeService.isDarkMode ? Colors.white70 : Colors.black54, fontSize: 13),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: nameController,
              autofocus: true,
              style: TextStyle(color: themeService.isDarkMode ? Colors.white : Colors.black87),
              decoration: InputDecoration(
                hintText: 'Örn: Gelecek Planları',
                hintStyle: TextStyle(color: themeService.isDarkMode ? Colors.white24 : Colors.black38),
                filled: true,
                fillColor: themeService.isDarkMode ? Colors.white.withOpacity(0.05) : Colors.grey[100],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Vazgeç',
              style: TextStyle(color: themeService.isDarkMode ? Colors.white54 : Colors.black54),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              final name = nameController.text.trim();
              if (name.isEmpty) {
                GreyNotification.show(context, 'Lütfen bir isim girin');
                return;
              }
              Navigator.pop(context);
              _showCreateGroupDialog(context, uid, username, name);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Devam Et'),
          ),
        ],
      ),
    );
  }

  void _showCreateGroupDialog(
    BuildContext context,
    String uid,
    String username,
    String groupName,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: themeService.isDarkMode ? const Color(0xFF1E1E1E) : Theme.of(context).colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          '$groupName Oluşturuluyor',
          style: TextStyle(
            color: themeService.isDarkMode ? Colors.white : Colors.black87,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        content: Text(
          'Bu şuanki sohbetinizi grup sohbeti yapar. Bellekleriniz ve promptlarınız grup sohbetlerinde kesinlikle kullanılmaz.',
          style: TextStyle(color: themeService.isDarkMode ? Colors.white70 : Colors.black54, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('İptal', style: TextStyle(color: themeService.isDarkMode ? Colors.white54 : Colors.black54)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              _processGroupCreation(uid, username, groupName);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blueAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Grubu Tamamla'),
          ),
        ],
      ),
    );
  }

  Future<void> _processGroupCreation(
    String uid,
    String username,
    String groupName,
  ) async {
    try {
      final groupId = await FirestoreService.instance.createGroup(
        name: groupName,
        creatorUid: uid,
        creatorUsername: username,
      );

      if (mounted) {
        // Preserve existing messages if converting current chat to group
        final existingMessages = _currentChat?.messages ?? [];

        // Upload existing messages to Firestore for the new group
        await FirestoreService.instance.migrateMessagesToGroup(
          groupId,
          existingMessages,
        );

        final newGroupChat = Chat(
          id: groupId,
          title: groupName,
          messages: existingMessages,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          isGroup: true,
          groupId: groupId,
          createdBy: uid,
        );

        // Add to _chats list and save
        setState(() {
          _chats.add(newGroupChat);
          _currentChat = newGroupChat;
        });
        await _storageService.saveChats(_chats);

        _showGroupCreatedLink(context, groupId);
      }
    } catch (e) {
      if (mounted) GreyNotification.show(context, 'Hata: $e');
    }
  }

  void _showGroupCreatedLink(BuildContext context, String groupId) {
    final link =
        'https://foresee.vercel.app/join/$groupId'; // Gerçek link formatı
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: themeService.isDarkMode ? const Color(0xFF1E1E1E) : Theme.of(context).colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Grup linkiniz',
          style: TextStyle(
            color: themeService.isDarkMode ? Colors.white : Colors.black87,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              decoration: BoxDecoration(
                color: themeService.isDarkMode ? Colors.black38 : Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: themeService.isDarkMode ? Colors.white10 : Colors.grey[300]!),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      link,
                      style: TextStyle(
                        color: Colors.blueAccent,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: link));
                      GreyNotification.show(context, 'Link kopyalandı');
                    },
                    child: Icon(
                      Icons.copy,
                      color: themeService.isDarkMode ? Colors.white70 : Colors.black54,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  GestureDetector(
                    onTap: () {
                      Share.share('ForeSee Grup Sohbetine Katıl: $link');
                    },
                    child: Icon(
                      Icons.share,
                      color: themeService.isDarkMode ? Colors.white70 : Colors.black54,
                      size: 20,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Kapat', 
              style: TextStyle(color: themeService.isDarkMode ? Colors.white : Colors.black87),
            ),
          ),
        ],
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

  void _showGroupSettingsPanel() {
    if (_currentChat == null || !_currentChat!.isGroup) return;

    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    final isAdmin = _currentChat!.admins?.contains(currentUid) ?? false;
    final isCreator = _currentChat!.createdBy == currentUid;

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF121212),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.85,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (context, scrollController) {
            return Column(
              children: [
                // Tutamaç
                const SizedBox(height: 12),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 20),

                // Grup Başlığı ve Link
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 32,
                        backgroundColor: Colors.blueAccent.withOpacity(0.2),
                        child: Text(
                          _currentChat!.title.isNotEmpty
                              ? _currentChat!.title[0].toUpperCase()
                              : 'G',
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Colors.blueAccent,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _currentChat!.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      // Grup Linki Kopyala
                      InkWell(
                        onTap: () {
                          final link =
                              'https://foresee.kesug.com/join/${_currentChat!.groupId}';
                          Clipboard.setData(ClipboardData(text: link));
                          GreyNotification.show(
                            context,
                            'Grup linki kopyalandı',
                          );
                        },
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white10,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.white12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              Icon(
                                Icons.link,
                                size: 16,
                                color: Colors.blueAccent,
                              ),
                              SizedBox(width: 8),
                              Text(
                                'Davet Bağlantısı',
                                style: TextStyle(
                                  color: Colors.blueAccent,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const Divider(color: Colors.white10, height: 40),

                // Ayarlar Listesi
                Expanded(
                  child: ListView(
                    controller: scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: [
                      // Üyeler Bölümü
                      const Padding(
                        padding: EdgeInsets.fromLTRB(16, 0, 16, 12),
                        child: Text(
                          'Kişiler',
                          style: TextStyle(
                            color: Colors.white54,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                      ...(_currentChat!.memberDetails ?? []).map((member) {
                        final uid = member['uid'] ?? '';
                        final username = member['username'] ?? 'İsimsiz';
                        final role = member['role'] ?? 'member';
                        final isMe = uid == currentUid;
                        final isMemberAdmin = role == 'admin';
                        final isMemberCreator = uid == _currentChat!.createdBy;

                        // ForeSee (AI) Özel Gösterim
                        final isAI =
                            username == 'ForeSee' ||
                            username.toLowerCase().contains('ai_foresee');
                        if (isAI) {
                          return ListTile(
                            leading: Container(
                              width: 40,
                              height: 40,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.black,
                              ),
                              padding: const EdgeInsets.all(2),
                              child: ClipOval(
                                child: Image.asset(
                                  themeService.getLogoPath('logo3.png'),
                                  fit: BoxFit.contain,
                                ),
                              ),
                            ),
                            title: const Text(
                              '@ForeSee',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Container(
                              margin: const EdgeInsets.only(top: 2),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.blueAccent.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(4),
                              ),
                             child: const Text(
                                'AI Asistan',
                                style: TextStyle(
                                  color: Colors.blueAccent,
                                  fontSize: 10,
                                ),
                              ),
                            ),
                          );
                        }

                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: _generateAvatarColor(username),
                            radius: 20,
                            child: Text(
                              username.isNotEmpty
                                  ? username
                                        .substring(0, min(2, username.length))
                                        .toUpperCase()
                                  : '?',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          title: Row(
                            children: [
                              Text(
                                '@$username',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              if (isMe)
                                const Text(
                                  ' (Sen)',
                                  style: TextStyle(
                                    color: Colors.white54,
                                    fontSize: 12,
                                  ),
                                ),
                            ],
                          ),
                          subtitle: Row(
                            children: [
                              if (isMemberCreator)
                                Container(
                                  margin: const EdgeInsets.only(
                                    right: 6,
                                    top: 4,
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.amber.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(
                                      color: Colors.amber.withOpacity(0.3),
                                    ),
                                  ),
                                  child: const Text(
                                    'Kurucu',
                                    style: TextStyle(
                                      color: Colors.amber,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                )
                              else if (isMemberAdmin)
                                Container(
                                  margin: const EdgeInsets.only(
                                    right: 6,
                                    top: 4,
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.blueAccent.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text(
                                    'Yönetici',
                                    style: TextStyle(
                                      color: Colors.blueAccent,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                )
                              else
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: const Text(
                                    'Üye',
                                    style: TextStyle(
                                      color: Colors.white38,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          trailing: (isAdmin && !isMe && !isMemberCreator)
                              ? PopupMenuButton<String>(
                                  icon: const Icon(
                                    Icons.more_vert,
                                    color: Colors.white54,
                                  ),
                                  color: const Color(0xFF1E1E1E),
                                  onSelected: (value) async {
                                    if (value == 'kick') {
                                      // Gruptan At
                                      await FirestoreService.instance
                                          .kickMember(
                                            _currentChat!.groupId!,
                                            uid,
                                          );
                                      Navigator.pop(
                                        context,
                                      ); // Paneli kapatıp yenilemek için
                                      GreyNotification.show(
                                        context,
                                        '$username gruptan atıldı',
                                      );
                                    } else if (value == 'toggle_admin') {
                                      // Yönetici Yap/Al
                                      final newRole = isMemberAdmin
                                          ? 'member'
                                          : 'admin';
                                      await FirestoreService.instance
                                          .updateMemberRole(
                                            _currentChat!.groupId!,
                                            uid,
                                            newRole,
                                          );
                                      Navigator.pop(context);
                                      GreyNotification.show(
                                        context,
                                        isMemberAdmin
                                            ? '$username yöneticilikten alındı'
                                            : '$username yönetici yapıldı',
                                      );
                                    }
                                  },
                                  itemBuilder: (context) => [
                                    const PopupMenuItem(
                                      value: 'kick',
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.remove_circle_outline,
                                            color: Colors.redAccent,
                                            size: 20,
                                          ),
                                          SizedBox(width: 8),
                                          Text(
                                            'Gruptan At',
                                            style: TextStyle(
                                              color: Colors.redAccent,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    PopupMenuItem(
                                      value: 'toggle_admin',
                                      child: Row(
                                        children: [
                                          Icon(
                                            isMemberAdmin
                                                ? Icons.shield_outlined
                                                : Icons.shield,
                                            color: Colors.white,
                                            size: 20,
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            isMemberAdmin
                                                ? 'Yöneticiliği Al'
                                                : 'Yönetici Yap',
                                            style: const TextStyle(
                                              color: Colors.white,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                )
                              : null,
                        );
                      }).toList(),

                      const Divider(color: Colors.white10, height: 32),

                      // Aksiyonlar
                      _buildSettingsActionTile(
                        icon: Icons.notifications_off_outlined,
                        title: 'Sustur',
                        subtitle: 'Bildirimleri yönet',
                        onTap: () => _showMuteSubMenu(context),
                      ),

                      // Şikayet Et (Sadece üyelere görünür, yöneticilere değil - İstenilen mantık)
                      if (!isAdmin)
                        _buildSettingsActionTile(
                          icon: Icons.report_gmailerrorred_outlined,
                          title: 'Şikayetçi Ol',
                          subtitle: 'Grubu bildir',
                          isDestructive: true,
                          onTap: () {
                            GreyNotification.show(
                              context,
                              'Şikayetiniz iletildi.',
                            );
                          },
                        ),

                      _buildSettingsActionTile(
                        icon: Icons.exit_to_app,
                        title: 'Gruptan Çık',
                        subtitle: 'Sohbetten ayrıl',
                        isDestructive: true,
                        onTap: () => _handleLeaveGroup(),
                      ),

                      // Yönetici Paneli
                      if (isAdmin) ...[
                        const Padding(
                          padding: EdgeInsets.fromLTRB(16, 24, 16, 8),
                          child: Text(
                            'YÖNETİCİ ARAÇLARI',
                            style: TextStyle(
                              color: Colors.white38,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ),
                        _buildSettingsActionTile(
                          icon: Icons.feedback_outlined,
                          title: 'Şikayetler',
                          subtitle: 'Grup içi bildirimler',
                          onTap: () {
                            GreyNotification.show(
                              context,
                              'Henüz şikayet yok.',
                            );
                          },
                        ),
                        _buildSettingsActionTile(
                          icon: Icons.delete_forever,
                          title: 'Grubu Sil',
                          subtitle: 'Kalıcı olarak kapat',
                          isDestructive: true,
                          onTap: () => _handleDeleteGroup(),
                        ),
                        const SizedBox(height: 20),
                      ],
                    ],
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showMuteSubMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text(
                'Sustur',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            ListTile(
              leading: const Icon(
                Icons.notifications_off,
                color: Colors.white70,
              ),
              title: const Text('Tümü', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                GreyNotification.show(context, 'Tüm bildirimler susturuldu');
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.smart_toy_outlined,
                color: Colors.blueAccent,
              ),
              title: const Text(
                'ForeSee (AI)',
                style: TextStyle(color: Colors.white),
              ),
              onTap: () {
                Navigator.pop(context);
                GreyNotification.show(context, 'ForeSee susturuldu');
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.person_off_outlined,
                color: Colors.white70,
              ),
              title: const Text(
                'Bir Kullanıcı',
                style: TextStyle(color: Colors.white),
              ),
              onTap: () {
                Navigator.pop(context);
                // Kullanıcı seçimi eklenebilir
                GreyNotification.show(context, 'Özellik yakında...');
              },
            ),
            const SizedBox(height: 24),
          ],
        );
      },
    );
  }

  Widget _buildSettingsActionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool isDestructive = false,
    bool isVisible = true,
  }) {
    if (!isVisible) return const SizedBox.shrink();
    return ListTile(
      leading: Icon(
        icon,
        color: isDestructive ? Colors.redAccent : Colors.white70,
        size: 22,
      ),
      title: Text(
        title,
        style: TextStyle(
          color: isDestructive ? Colors.redAccent : Colors.white,
          fontSize: 15,
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(color: Colors.white38, fontSize: 12),
      ),
      onTap: onTap,
    );
  }

  void _showMuteOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Padding(
              padding: EdgeInsets.all(20),
              child: Text(
                'Susturma Seçenekleri',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            _buildMuteTile(context, 'Tümü', 'Tüm bildirimleri kapat'),
            _buildMuteTile(context, 'ForeSee', 'Sadece AI cevaplarını sustur'),
            _buildMuteTile(
              context,
              'Kullanıcılar',
              'Sadece üyelerin mesajlarını sustur',
            ),
            const SizedBox(height: 24),
          ],
        );
      },
    );
  }

  Widget _buildMuteTile(BuildContext context, String title, String subtitle) {
    return ListTile(
      title: Text(title, style: const TextStyle(color: Colors.white)),
      subtitle: Text(
        subtitle,
        style: const TextStyle(color: Colors.white38, fontSize: 12),
      ),
      onTap: () {
        Navigator.pop(context);
        GreyNotification.show(context, '$title susturuldu');
      },
    );
  }

  Future<void> _handleLeaveGroup() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('Gruptan Çık', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Bu gruptan ayrılmak istediğinizden emin misiniz?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('İptal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Ayrıl',
              style: TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );

    if (confirm == true && _currentChat != null && _currentChat!.isGroup) {
      try {
        await FirestoreService.instance.leaveGroup(
          _currentChat!.groupId!,
          FirebaseAuth.instance.currentUser!.uid,
        );
        if (mounted) {
          Navigator.pop(context); // Settings panelini kapat
          _handleChatDelete(
            _currentChat!,
          ); // Local listeden kaldır ve boş ekrana dön
          GreyNotification.show(context, 'Gruptan ayrıldınız');
        }
      } catch (e) {
        if (mounted) GreyNotification.show(context, 'Hata: $e');
      }
    }
  }

  Future<void> _handleDeleteGroup() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('Grubu Sil', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Bu grubu kalıcı olarak silmek istediğinizden emin misiniz? Tüm mesajlar silinecektir.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('İptal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'SİL',
              style: TextStyle(
                color: Colors.redAccent,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirm == true && _currentChat != null && _currentChat!.isGroup) {
      try {
        await FirestoreService.instance.deleteGroup(_currentChat!.groupId!);
        if (mounted) {
          Navigator.pop(context); // Settings panelini kapat
          _handleChatDelete(
            _currentChat!,
          ); // Local listeden kaldır ve boş ekrana dön
          GreyNotification.show(context, 'Grup silindi');
        }
      } catch (e) {
        if (mounted) GreyNotification.show(context, 'Hata: $e');
      }
    }
  }

  Future<void> joinGroupFromDeepLink(String groupId) async {
    // 1. Check if user is logged in
    User? fbUser = FirebaseAuth.instance.currentUser;
    if (fbUser == null) {
      try {
        final cred = await AuthService.instance.signInAnonymously();
        fbUser = cred.user;
      } catch (e) {
        if (mounted) GreyNotification.show(context, 'Oturum açılamadı: $e');
        return;
      }
    }
    if (fbUser == null) return;

    // 2. Check if username exists
    final firestore = FirestoreService.instance;
    final userDoc = await firestore.getUserProfile(fbUser.uid);
    String? username = userDoc?['username'];

    if (username == null) {
      if (!mounted) return;
      final created = await _showUsernameDialogForGroup(
        context,
        fbUser.uid,
        fbUser.email ?? 'anon@foresee.app',
      );
      if (!created) return;
      final updatedDoc = await firestore.getUserProfile(fbUser.uid);
      username = updatedDoc?['username'];
    }
    if (username == null) return;

    // 3. Join the group
    try {
      await firestore.joinGroup(groupId, fbUser.uid, username);

      // 4. Fetch group details to open it
      final groupDoc = await FirebaseFirestore.instance
          .collection('groups')
          .doc(groupId)
          .get();
      if (groupDoc.exists && mounted) {
        final data = groupDoc.data()!;
        final chat = Chat(
          id: groupId,
          title: data['name'] ?? 'Grup',
          messages: [],
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          isGroup: true,
          groupId: groupId,
          createdBy: data['createdBy'],
        );
        _handleChatSelected(chat);
        GreyNotification.show(context, 'Gruba katıldınız!');
      }
    } catch (e) {
      if (mounted) GreyNotification.show(context, 'Grup katılım hatası: $e');
    }
  }

  // Check if user has sent at least one message in the chat
  bool _hasUserSentMessage(Chat chat) {
    return chat.messages.any((message) => message.isUser);
  }
}
