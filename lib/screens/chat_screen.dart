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
import 'package:flutter_highlight/themes/github.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import '../models/chat.dart';
import '../models/message.dart';
// import '../models/chat_note.dart'; // Removed as it's missing
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
import '../widgets/artifacts_panel.dart';
import '../services/import_export_service.dart';
import 'package:share_plus/share_plus.dart';
import '../services/theme_service.dart';
import '../services/otp_service.dart';
import '../services/gmail_service.dart';
import '../services/github_service.dart';
import '../services/outlook_service.dart';
import '../models/chat_folder.dart';
import 'package:audioplayers/audioplayers.dart';
import '../services/elevenlabs_service.dart';
import '../widgets/multi_answer_selection_panel.dart';
import '../models/lock_type.dart';
import 'lock_setup_screen.dart';
import 'lock_verification_screen.dart';
import '../services/security_service.dart';

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
  ThemeData get theme => Theme.of(context);
  final TextEditingController _messageController = TextEditingController();
  final FocusNode _messageFocusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();
  final OpenRouterService _openRouterService = OpenRouterService();
  final GmailService _gmailService = GmailService.instance;
  final GitHubService _githubService = GitHubService.instance;
  final FirestoreService _firestoreService = FirestoreService.instance;
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
  String? _loadingMessage;
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
  final ValueNotifier<String> _streamingContent = ValueNotifier<String>('');
  bool _showSuggestions = false;
  bool _isMultiDeleteMode = false;
  final Set<String> _selectedChatIdsForDelete = {};
  bool _isAutoTitleEnabled = false;
  bool _isRecordingVoice = false;
  bool _isManualRecording = false; // Basılı tutma modu için
  double _recordLevel = 0.0;
  String _lastVoiceText = '';
  Timer? _silenceTimer;
  StreamSubscription? _contextSubscription;
  bool _isSmartContextEnabled = false;
  final List<File> _pickedPdfFiles = [];
  final List<String> _pickedPdfBase64List = [];
  bool _isRememberPastChatsEnabled = false;
  bool _isGmailAiAlwaysAllowed = false;
  bool _isGithubAiAlwaysAllowed = false;
  bool _isOutlookAiAlwaysAllowed = false;
  bool _isArtifactsPanelOpen = false;
  String _artifactContent = '';
  String _artifactTitle = '';
  String _artifactLanguage = 'text';
  bool _isTodoPanelOpen = false;
  List<Map<String, dynamic>> _currentTodoTasks = [];
  List<ChatFolder> _folders = [];
  List<String> _currentMultiAnswers = [];
  bool _isMultiAnswerPanelOpen = false;
  String? _multiAnswerTargetMessageId;
  String? _multiAnswerTargetChatId;
  bool _isChatNotesPanelOpen =
      false; // Added as it was missing from state but used in build

  // Audio State
  final AudioPlayer _audioPlayer = AudioPlayer();
  String? _playingMessageId;
  bool _isAudioLoading = false;
  bool _isAudioBarVisible = false;
  Duration _audioDuration = Duration.zero;
  Duration _audioPosition = Duration.zero;
  bool _isExporting = false;
  String? _exportLoadingMessage;
  bool _isSecretMode = false;
  bool _isGeneratingImage = false;

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
    // Initial auto-scroll
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    _messageController.addListener(_onMessageTextChanged);
    WidgetsBinding.instance.addObserver(this);
    _initShareIntentListener();
    _initProcessTextListener();
    _requestPermissions();
    _initContextListener();
    _loadInitialSettings();

    _audioPlayer.onPlayerComplete.listen((event) {
      if (mounted) {
        setState(() {
          _playingMessageId = null;
          _isAudioBarVisible =
              false; // Close bar on complete? User said "durdurma butonu soldadir", maybe pause?
          // User said "kapatmak için sağ üstte x". So on complete we might just reset or stop.
          // Let's stop and hide for now.
          _audioPosition = Duration.zero;
        });
      }
    });

    _audioPlayer.onDurationChanged.listen((d) {
      setState(() => _audioDuration = d);
    });

    _audioPlayer.onPositionChanged.listen((p) {
      setState(() => _audioPosition = p);
    });
  }

  Future<void> _openTrash() async {
    final theme = Theme.of(context);
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
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final currentTrashed =
                _chats
                    .where(
                      (c) =>
                          c.deletedAt != null &&
                          now.difference(c.deletedAt!).inDays < 7,
                    )
                    .toList()
                  ..sort((a, b) => b.deletedAt!.compareTo(a.deletedAt!));

            if (currentTrashed.isEmpty) {
              return Container(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.delete_sweep_outlined,
                      size: 48,
                      color: theme.disabledColor,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Çöp kutusu boşaldı',
                      style: TextStyle(color: Colors.white70),
                    ),
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Kapat'),
                    ),
                  ],
                ),
              );
            }

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
                          color: themeService.isDarkMode
                              ? Colors.white24
                              : Colors.black12,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Çöp kutusu',
                          style: TextStyle(
                            color: Theme.of(context).textTheme.bodyLarge?.color,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          '${currentTrashed.length} sohbet',
                          style: TextStyle(
                            color: theme.disabledColor,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Sohbetler 7 gün sonra kalıcı olarak silinir.',
                      style: TextStyle(
                        color: Theme.of(
                          context,
                        ).textTheme.bodySmall?.color?.withOpacity(0.7),
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: MediaQuery.of(context).size.height * 0.4,
                      child: ListView.builder(
                        itemCount: currentTrashed.length,
                        itemBuilder: (context, index) {
                          final chat = currentTrashed[index];
                          final deletedAt = chat.deletedAt!;
                          final remaining =
                              const Duration(days: 7) -
                              now.difference(deletedAt);
                          final remainingDays = remaining.inDays.clamp(0, 7);
                          return Container(
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            decoration: BoxDecoration(
                              color: themeService.isDarkMode
                                  ? const Color(0xFF222222)
                                  : Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Theme.of(
                                  context,
                                ).dividerColor.withOpacity(0.1),
                              ),
                            ),
                            child: ListTile(
                              dense: true,
                              title: Text(
                                chat.title,
                                style: TextStyle(
                                  color: Theme.of(
                                    context,
                                  ).textTheme.bodyLarge?.color,
                                  fontSize: 14,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Text(
                                'Kalan: $remainingDays gün',
                                style: TextStyle(
                                  color: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.color
                                      ?.withOpacity(0.5),
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
                                      color: Colors.greenAccent,
                                      size: 20,
                                    ),
                                    onPressed: () async {
                                      setState(() {
                                        final idx = _chats.indexWhere(
                                          (c) => c.id == chat.id,
                                        );
                                        if (idx != -1) {
                                          _chats[idx] = _chats[idx].copyWith(
                                            clearDeletedAt: true,
                                          );
                                        }
                                      });
                                      setModalState(
                                        () {},
                                      ); // Modal içini güncelle
                                      await _storageService.saveChats(_chats);
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
                                        _chats.removeWhere(
                                          (c) => c.id == chat.id,
                                        );
                                        if (_currentChat?.id == chat.id)
                                          _currentChat = null;
                                      });
                                      setModalState(() {});
                                      await _storageService.saveChats(_chats);
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
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (c) => AlertDialog(
                              title: const Text('Emin misiniz?'),
                              content: const Text(
                                'Tüm sohbetler kalıcı olarak silinecek.',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(c, false),
                                  child: const Text('İptal'),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.pop(c, true),
                                  child: const Text(
                                    'Sil',
                                    style: TextStyle(color: Colors.redAccent),
                                  ),
                                ),
                              ],
                            ),
                          );
                          if (confirm != true) return;

                          setState(() {
                            _chats.removeWhere((c) => c.deletedAt != null);
                            if (_currentChat != null &&
                                _currentChat!.deletedAt != null)
                              _currentChat = null;
                          });
                          await _storageService.saveChats(_chats);
                          if (!mounted) return;
                          Navigator.of(ctx).pop();
                        },
                        child: const Text(
                          'Tümünü Temizle',
                          style: TextStyle(color: Colors.redAccent),
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

  void _openArtifactPanel(
    String code,
    String language,
    String title,
    bool isPreview,
  ) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.8),
      builder: (context) => ArtifactsPanel(
        content: code,
        title: title,
        language: language,
        initialTab: isPreview ? 1 : 0,
        onClose: () => Navigator.of(context).pop(),
      ),
    );
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

            final isDark = themeService.isDarkMode;
            final theme = Theme.of(ctx);

            return Container(
              height: size.height * 0.9,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F0F0F) : Colors.white,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 15,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: SafeArea(
                top: true,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header with Save Button
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
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
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const Spacer(),
                          Text(
                            'Kod Analizi',
                            style: TextStyle(
                              color: isDark ? Colors.white : Colors.black87,
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Spacer(),
                          IconButton(
                            icon: Icon(
                              Icons.close,
                              color: isDark ? Colors.white54 : Colors.black54,
                              size: 20,
                            ),
                            onPressed: () {
                              Navigator.of(sheetContext).pop();
                            },
                          ),
                        ],
                      ),
                    ),
                    Divider(
                      height: 1,
                      color: isDark
                          ? Colors.white10
                          : Colors.black.withOpacity(0.05),
                    ),
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
                                    Text(
                                      'Orijinal Kod',
                                      style: TextStyle(
                                        color: isDark
                                            ? Colors.white70
                                            : Colors.black54,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                                Container(
                                  width: double.infinity,
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? const Color(0xFF161616)
                                        : const Color(0xFFF8F9FA),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: isDark
                                          ? Colors.white10
                                          : Colors.black.withOpacity(0.05),
                                    ),
                                  ),
                                  padding: const EdgeInsets.all(16),
                                  child: HighlightView(
                                    code,
                                    language: language.isEmpty
                                        ? 'text'
                                        : language.toLowerCase(),
                                    theme: isDark
                                        ? monokaiSublimeTheme
                                        : githubTheme,
                                    textStyle: const TextStyle(
                                      fontFamily: 'monospace',
                                      fontSize: 12,
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
                                            'Önerilen Kod ${index + 1}',
                                            style: TextStyle(
                                              color: isDark
                                                  ? Colors.white70
                                                  : Colors.black54,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
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
                                          color: isDark
                                              ? const Color(0xFF161616)
                                              : const Color(0xFFF8F9FA),
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                          border: Border.all(
                                            color: isDark
                                                ? Colors.white10
                                                : Colors.black.withOpacity(
                                                    0.05,
                                                  ),
                                          ),
                                        ),
                                        padding: const EdgeInsets.all(16),
                                        child: sugg.isEmpty
                                            ? Text(
                                                'Analiz ediliyor...',
                                                style: TextStyle(
                                                  color: isDark
                                                      ? Colors.white38
                                                      : Colors.black38,
                                                  fontSize: 11,
                                                ),
                                              )
                                            : SelectableText(
                                                sugg,
                                                style: TextStyle(
                                                  color: isDark
                                                      ? Colors.white
                                                      : Colors.black87,
                                                  fontFamily: 'monospace',
                                                  fontSize: 12,
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
                                backgroundColor: isDark
                                    ? const Color(0xFF2A2A2A)
                                    : Colors.white,
                                elevation: 4,
                                child: Icon(
                                  Icons.keyboard_arrow_down,
                                  color: isDark ? Colors.white : Colors.black87,
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
                        height: 52,
                        child: ElevatedButton.icon(
                          onPressed: isLoading || suggestions.length >= 3
                              ? null
                              : runAnalysis,
                          icon: const Icon(Icons.auto_fix_high, size: 20),
                          label: Text(
                            isLoading
                                ? 'Analiz ediliyor...'
                                : (suggestions.length >= 3
                                      ? 'Maksimum analiz sayısına ulaşıldı'
                                      : 'Yeni Analiz Başlat'),
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2563EB),
                            disabledBackgroundColor: isDark
                                ? Colors.white10
                                : Colors.black.withOpacity(0.05),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 0,
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
                  .where(
                    (path) => path.isNotEmpty && !path.startsWith('foresee://'),
                  )
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
            .where((path) => path.isNotEmpty && !path.startsWith('foresee://'))
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
        resizeToAvoidBottomInset: true,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        drawer: _userProfile != null
            ? Sidebar(
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

                folders: _folders,
                onChatMoveToFolder: _handleChatMoveToFolder,
                onCreateFolder: _handleCreateFolder,
                onEditFolder: _handleEditFolder,
                onDeleteFolder: _handleDeleteFolder,
                onToggleFolder: _handleToggleFolder,
                onToggleFolderPin: _handleToggleFolderPin,
                onChatLock: _handleChatLock,
              )
            : null,
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final bool isWide = constraints.maxWidth >= 800;
              return Stack(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
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
                      ),
                      /* 
                      if (_isChatNotesPanelOpen && isWide)
                        SizedBox(
                          width: 400,
                          child: ChatNotesPanel(
                            chat: _currentChat!,
                            onNoteEdited: _handleNoteEdited,
                            onNoteDeleted: _handleNoteDeleted,
                            onNotePinned: _handleNotePinned,
                            onReviewRequested: _handleNotesReviewRequested,
                            onExportRequested: _handleNotesExportRequested,
                            onSaveRequested: _handleNotesSaveRequested,
                            onUndoRequested: _handleNotesUndoRequested,
                            onRedoRequested: _handleNotesRedoRequested,
                            onOptionSelected: _handleNoteOptionSelected,
                            onAiCorrectRequested: _handleNoteAiCorrectRequested,
                            onInfiniteNoteChanged: _handleInfiniteNoteChanged,
                          ),
                        ),
                      */
                      if (_isArtifactsPanelOpen && isWide)
                        SizedBox(
                          width: 400,
                          child: ArtifactsPanel(
                            content: _artifactContent,
                            title: _artifactTitle,
                            language: _artifactLanguage,
                            onClose: () =>
                                setState(() => _isArtifactsPanelOpen = false),
                          ),
                        ),
                    ],
                  ),
                  if (_isArtifactsPanelOpen && !isWide)
                    Positioned(
                      top: 0,
                      bottom: 0,
                      right: 0,
                      left: constraints.maxWidth > 600
                          ? constraints.maxWidth - 450
                          : 0,
                      child: ArtifactsPanel(
                        content: _artifactContent,
                        title: _artifactTitle,
                        language: _artifactLanguage,
                        onClose: () =>
                            setState(() => _isArtifactsPanelOpen = false),
                      ),
                    ),
                  _buildAudioOverlay(),
                  if (_isExporting) _buildExportOverlay(),
                  const SizedBox(height: 16), // Extra safe space
                  // Invisible Anchor
                  SizedBox(
                    height: 1,
                    key: ValueKey('bottom-anchor-(${_currentChat?.id})'),
                  ),
                  if (_isMultiAnswerPanelOpen)
                    Positioned.fill(
                      child: MultiAnswerSelectionPanel(
                        answers: _currentMultiAnswers,
                        onAnswerSelected: (index) {
                          final msg = Message(
                            id: _multiAnswerTargetMessageId!,
                            chatId: _multiAnswerTargetChatId!,
                            content: _currentMultiAnswers[index],
                            isUser: false,
                            timestamp: DateTime.now(),
                            alternatives: _currentMultiAnswers,
                          );
                          _handleAlternativeSelected(msg, index);
                          setState(() => _isMultiAnswerPanelOpen = false);
                        },
                        onDismiss: () =>
                            setState(() => _isMultiAnswerPanelOpen = false),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildTypingIndicator() {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: themeService.isDarkMode
                  ? const Color(0xFF1E1E1E)
                  : Colors.grey.shade200,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
                bottomRight: Radius.circular(16),
                bottomLeft: Radius.circular(4),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      theme.colorScheme.primary,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  _currentTypingText.isNotEmpty
                      ? _currentTypingText
                      : 'Yazıyor...',
                  style: TextStyle(
                    color: theme.textTheme.bodyMedium?.color?.withOpacity(0.7),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
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
      backgroundColor: Theme.of(context).colorScheme.surface,
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
                        color: Theme.of(context).dividerColor.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  TextField(
                    controller: searchController,
                    autofocus: true,
                    style: TextStyle(
                      color: Theme.of(context).textTheme.bodyLarge?.color,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Sohbet başlığında ara...',
                      hintStyle: TextStyle(
                        color: Theme.of(
                          context,
                        ).textTheme.bodySmall?.color?.withOpacity(0.5),
                      ),
                      prefixIcon: Icon(
                        Icons.search,
                        color: Theme.of(
                          context,
                        ).iconTheme.color?.withOpacity(0.5),
                        size: 20,
                      ),
                      filled: true,
                      fillColor: Theme.of(
                        context,
                      ).colorScheme.onSurface.withOpacity(0.05),
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
                    Text(
                      'Sohbet bulunamadı',
                      style: TextStyle(
                        color: Theme.of(
                          context,
                        ).textTheme.bodySmall?.color?.withOpacity(0.6),
                        fontSize: 13,
                      ),
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
                              style: TextStyle(
                                color: Theme.of(
                                  context,
                                ).textTheme.bodyLarge?.color,
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
                color: Theme.of(context).brightness == Brightness.dark
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
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.white
                        : Colors.black87,
                    onPressed: _openPinnedMessages,
                  ),
                IconButton(
                  icon: FaIcon(
                    FontAwesomeIcons.plus,
                    size: 18,
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.white
                        : Colors.black87,
                  ),
                  onPressed: _createNewChat,
                ),
                // --- Gizli Sohbet Butonu ---
                if (_currentChat == null ||
                    (_currentChat?.messages.isEmpty ?? true))
                  IconButton(
                    icon: FaIcon(
                      _isSecretMode
                          ? FontAwesomeIcons.xmark
                          : FontAwesomeIcons.userSecret,
                      size: 18,
                      color: _isSecretMode
                          ? Colors.redAccent
                          : (Theme.of(context).brightness == Brightness.dark
                                ? Colors.white
                                : Colors.black87),
                    ),
                    onPressed: () {
                      setState(() {
                        _isSecretMode = !_isSecretMode;
                        if (_isSecretMode) {
                          _currentChat =
                              null; // Gizli moda geçerken mevcut sohbeti boşalt
                        }
                      });
                    },
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays >= 1) {
      return '${difference.inDays} gn';
    } else if (difference.inHours >= 1) {
      return '${difference.inHours} sa';
    } else if (difference.inMinutes >= 1) {
      return '${difference.inMinutes} dk';
    } else {
      return 'şimdi';
    }
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
            if (!_isSecretMode) ...[
              Text(
                'Merhaba, ben ForeSee',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).brightness == Brightness.dark
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
                  color: Theme.of(context).brightness == Brightness.dark
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
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.white
                          : Colors.black87,
                      size: 18,
                    ),
                  ],
                ),
              ),
            ] else ...[
              const FaIcon(
                FontAwesomeIcons.userSecret,
                size: 64,
                color: Colors.redAccent,
              ),
              const SizedBox(height: 24),
              const Text(
                'Gizli Sohbet',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.redAccent,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Bu sohbet kaydedilmeyecek ve geçicidir.',
                style: TextStyle(
                  fontSize: 14,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.white54
                      : Colors.black54,
                ),
              ),
            ],
            const SizedBox(height: 12),
            AnimatedCrossFade(
              firstChild: _chats.isEmpty || _showSuggestions
                  ? const SizedBox.shrink()
                  : Column(
                      children: [
                        ..._chats.where((c) => c.messages.isNotEmpty).take(3).map((
                          chat,
                        ) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8.0),
                            child: InkWell(
                              onTap: () => _handleChatSelected(chat),
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: themeService.isDarkMode
                                      ? Colors.white.withOpacity(0.05)
                                      : Colors.black.withOpacity(0.03),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: themeService.isDarkMode
                                        ? Colors.white.withOpacity(0.1)
                                        : Colors.black.withOpacity(0.05),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    if (chat.projectColor != null)
                                      Container(
                                        width: 10,
                                        height: 10,
                                        margin: const EdgeInsets.only(right: 8),
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: Color(chat.projectColor!),
                                          border: Border.all(
                                            color:
                                                chat.projectColor == 0xFF000000
                                                ? (themeService.isDarkMode
                                                      ? Colors.white54
                                                      : Colors.black12)
                                                : (chat.projectColor ==
                                                          0xFFFFFFFF
                                                      ? Colors.black12
                                                      : Colors.transparent),
                                            width: 1,
                                          ),
                                        ),
                                      ),
                                    Expanded(
                                      child: Text(
                                        chat.title,
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: themeService.isDarkMode
                                              ? Colors.white
                                              : Colors.black87,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        FaIcon(
                                          FontAwesomeIcons.clockRotateLeft,
                                          size: 11,
                                          color: themeService.isDarkMode
                                              ? Colors.white38
                                              : Colors.black38,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          '${_getTimeAgo(chat.updatedAt)} önce',
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: themeService.isDarkMode
                                                ? Colors.white38
                                                : Colors.black38,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }),
                      ],
                    ),
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
          color: themeService.isDarkMode
              ? const Color(0xFF1A1A1A)
              : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: themeService.isDarkMode ? Colors.white24 : Colors.grey[300]!,
          ),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: themeService.isDarkMode ? Colors.white : Colors.black87,
            fontSize: 13,
          ),
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
            streamingContent: _isTyping && message.id == _typingMessageId
                ? _streamingContent
                : null,
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
            onToolApproval: _handleToolApproval,
            reasoning:
                _activeResponseChatId == _currentChat?.id && isTypingBubble
                ? _agentThinking
                : null,
            onShowReasoning: () => _showReasoningSheet(_agentThinking),
            isPlayingAudio: _playingMessageId == message.id,
            isAudioLoading: _isAudioLoading && _playingMessageId == message.id,
            onPlay: () => _handlePlayAudio(message.id, message.content),
            onStop: _handleStopAudio,
            showAudioButton: !message.isUser,
            onOpenArtifact: _openArtifactPanel,
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
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (bottomSheetContext) {
        final theme = Theme.of(context);
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
                      color: Theme.of(context).dividerColor.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Row(
                  children: [
                    Icon(
                      Icons.push_pin,
                      color: Theme.of(
                        context,
                      ).iconTheme.color?.withOpacity(0.7),
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Sabitlenmiş Mesajlar',
                      style: TextStyle(
                        color: Theme.of(context).textTheme.bodyLarge?.color,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '${pinnedEntries.length} sabitlenmiş mesaj var',
                  style: TextStyle(
                    color: Theme.of(
                      context,
                    ).textTheme.bodySmall?.color?.withOpacity(0.6),
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 260,
                  child: ListView.separated(
                    itemCount: pinnedEntries.length,
                    separatorBuilder: (context, index) => Divider(
                      color: Theme.of(context).dividerColor.withOpacity(0.1),
                      height: 12,
                    ),
                    itemBuilder: (context, index) {
                      final entry = pinnedEntries[index];
                      final Message msg = entry['message'] as Message;
                      final int msgIndex = entry['index'] as int;
                      final fullText = msg.content.trim();

                      final allImages = <String>[];
                      if (msg.imageUrl != null) allImages.add(msg.imageUrl!);
                      if (msg.imageUrls != null)
                        allImages.addAll(msg.imageUrls!);

                      return ListTile(
                        dense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 0,
                          vertical: 4,
                        ),
                        leading: Icon(
                          Icons.push_pin,
                          color: Theme.of(
                            context,
                          ).iconTheme.color?.withOpacity(0.7),
                          size: 18,
                        ),
                        title: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (fullText.isNotEmpty)
                              Text(
                                fullText,
                                style: TextStyle(
                                  color: Theme.of(
                                    context,
                                  ).textTheme.bodyMedium?.color,
                                  fontSize: 13,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            if (allImages.isNotEmpty) ...[
                              if (fullText.isNotEmpty)
                                const SizedBox(height: 8),
                              Wrap(
                                spacing: 4,
                                runSpacing: 4,
                                children: allImages.map((url) {
                                  return ClipRRect(
                                    borderRadius: BorderRadius.circular(4),
                                    child: Image.network(
                                      url,
                                      width: 40,
                                      height: 40,
                                      fit: BoxFit.cover,
                                      errorBuilder: (c, e, s) => Container(
                                        width: 40,
                                        height: 40,
                                        color: Colors.grey.withOpacity(0.2),
                                        child: const Icon(
                                          Icons.broken_image,
                                          size: 16,
                                        ),
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ],
                            if (fullText.isEmpty && allImages.isEmpty)
                              Text(
                                '[Boş mesaj]',
                                style: TextStyle(
                                  color: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.color
                                      ?.withOpacity(0.5),
                                  fontSize: 13,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                          ],
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            Text(
                              msg.isUser ? 'Kullanıcı' : 'ForeSee',
                              style: TextStyle(
                                color: Theme.of(
                                  context,
                                ).textTheme.bodySmall?.color?.withOpacity(0.6),
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
      _streamingContent.value = ''; // Reset for new stream
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
          _streamingContent.value = _formatQuickActionResult(actionId, cleaned);

          if (!_showScrollToBottom) {
            _scrollToBottomQuick();
          }
        },
        shouldStop: () => _shouldStopResponse,
        maxTokens: 600,
        onToolCall: (name, args, id, isFinal) => _handleIncomingToolCall(
          name,
          args,
          id,
          derivedMessage.id,
          targetChatId,
          isFinal,
        ),
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
        _streamingContent.value = ''; // Clear streaming content
      });
      await _storageService.saveChats(_chats);
    }
  }

  Future<void> _handlePlayAudio(String messageId, String text) async {
    if (_playingMessageId == messageId) {
      // If already playing this, toggle pause?
      // For now re-synthesize or resume requires more logic, let's just restart or do nothing.
      // User experience: tapping "Read Aloud" on same message might restart.
      // Let's assume standard behavior: Stop previous, start new.
      await _handleStopAudio();
    } else {
      await _handleStopAudio(); // Stop others
    }

    setState(() {
      _isAudioLoading = true;
      _playingMessageId = messageId;
      _isAudioBarVisible = true; // Show bar immediately
      _audioDuration = Duration.zero;
      _audioPosition = Duration.zero;
    });

    try {
      final preferredVoiceId =
          await _storageService.getElevenLabsVoiceId() ??
          'cgSgspJ2msm6clMCkdW9';
      final tempDir = await getTemporaryDirectory();
      final cacheFile = File(
        '${tempDir.path}/tts_${preferredVoiceId}_$messageId.mp3',
      );

      // Check if already exists in cache
      if (await cacheFile.exists()) {
        await _audioPlayer.play(DeviceFileSource(cacheFile.path));
        if (mounted) {
          setState(() {
            _isAudioLoading = false;
          });
        }
        return;
      }

      // If not in cache, synthesize
      final audioFile = await ElevenLabsService().generateSpeech(
        text,
        voiceId: preferredVoiceId,
      );

      if (audioFile != null) {
        // Copy to our cache location with a predictable name
        await audioFile.copy(cacheFile.path);

        await _audioPlayer.play(DeviceFileSource(cacheFile.path));

        if (mounted) {
          setState(() {
            _isAudioLoading = false;
          });
        }
      } else {
        throw Exception('Ses üretilemedi');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _playingMessageId = null;
          _isAudioLoading = false;
          _isAudioBarVisible = false;
        });
        GreyNotification.show(context, 'TTS Hatası: $e');
      }
    }
  }

  Future<void> _handleStopAudio() async {
    await _audioPlayer.stop();
    if (mounted) {
      setState(() {
        _playingMessageId = null;
        _isAudioLoading = false;
        _isAudioBarVisible = false;
        _audioPosition = Duration.zero;
      });
    }
  }

  Future<void> _handlePauseAudio() async {
    await _audioPlayer.pause();
    setState(
      () => _playingMessageId = null,
    ); // Mark as not "playing" (shows play icon)
    // Keep bar visible
  }

  Future<void> _handleResumeAudio() async {
    if (_playingMessageId != null) return; // Already playing
    // We need to know WHICH message was paused to resume correctly if we track that.
    // But for simple "Play/Pause" in bar, we just call resume on player.
    await _audioPlayer.resume();
    // However we need _playingMessageId to show "Pause" icon.
    // Since we cleared it on pause, we need to restore it OR use a separate _isPlaying state.
    // Let's simplify: _playingMessageId != null implies ACTIVE.
    // We need a separate variable for "ID of content loaded".
    // But simpler: just toggle player state.

    // Correct approach: _playerState can be tracked or query player.
    // Let's use player.state stream or just assume we resume current track.
    setState(() {
      // We need the ID back to highlight the message or just valid state.
      // If we don't track the paused ID, we can't restore _playingMessageId exactly.
      // Hack: Don't clear _playingMessageId on pause. Add _isPaused bool.
    });
  }

  // Revised Stop/Pause logic for Overlay:
  // The overlay controls the player directly.

  Widget _buildAudioOverlay() {
    if (!_isAudioBarVisible) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Positioned(
      top: MediaQuery.of(context).padding.top + 10,
      left: 16,
      right: 16,
      child: Material(
        elevation: 8,
        color: Colors.transparent,
        child: Container(
          height: 56,
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
            border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
          ),
          child: _isAudioLoading
              ? Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: isDark ? Colors.white70 : Colors.black87,
                    ),
                  ),
                )
              : Row(
                  children: [
                    // Play/Pause Button (Left)
                    IconButton(
                      icon: Icon(
                        _audioPlayer.state == PlayerState.playing
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                      onPressed: () async {
                        if (_audioPlayer.state == PlayerState.playing) {
                          await _audioPlayer.pause();
                          setState(() {}); // Refresh icon
                        } else {
                          await _audioPlayer.resume();
                          setState(() {});
                        }
                      },
                    ),

                    // Slider (Center)
                    Expanded(
                      child: SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          trackHeight: 2,
                          thumbShape: const RoundSliderThumbShape(
                            enabledThumbRadius: 6,
                          ),
                          overlayShape: const RoundSliderOverlayShape(
                            overlayRadius: 14,
                          ),
                          activeTrackColor: isDark
                              ? Colors.white
                              : Colors.black,
                          inactiveTrackColor: isDark
                              ? Colors.white24
                              : Colors.black12,
                          thumbColor: isDark ? Colors.white : Colors.black,
                        ),
                        child: Slider(
                          value: _audioPosition.inMilliseconds.toDouble().clamp(
                            0,
                            _audioDuration.inMilliseconds.toDouble(),
                          ),
                          max: _audioDuration.inMilliseconds.toDouble() > 0
                              ? _audioDuration.inMilliseconds.toDouble()
                              : 1.0,
                          onChanged: (val) {
                            _audioPlayer.seek(
                              Duration(milliseconds: val.toInt()),
                            );
                          },
                        ),
                      ),
                    ),

                    // Close Button (Right)
                    IconButton(
                      icon: Icon(
                        Icons.close,
                        size: 20,
                        color: isDark ? Colors.white54 : Colors.black45,
                      ),
                      onPressed: _handleStopAudio,
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  // FOLDER MANAGEMENT
  Future<void> _loadFolders() async {
    final loaded = await _storageService.loadFolders();
    if (mounted) {
      setState(() {
        _folders = loaded;
      });
    }
  }

  Future<void> _handleCreateFolder() async {
    final theme = Theme.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final nameController = TextEditingController();
    int? selectedColorValue = Colors.blue.value;
    String? selectedEmoji;
    bool isSecret = false;
    LockType lockType = LockType.none;
    String? lockData;

    final palette = [
      const Color(0xFFEF5350),
      const Color(0xFFEC407A),
      const Color(0xFFAB47BC),
      const Color(0xFF7E57C2),
      const Color(0xFF5C6BC0),
      const Color(0xFF42A5F5),
      const Color(0xFF29B6F6),
      const Color(0xFF26C6DA),
      const Color(0xFF26A69A),
      const Color(0xFF66BB6A),
      const Color(0xFF9CCC65),
      const Color(0xFFD4E157),
      const Color(0xFFFFEE58),
      const Color(0xFFFFCA28),
      const Color(0xFFFF7043),
      const Color(0xFF8D6E63),
    ];

    final emojis = [
      '📁',
      '📂',
      '💼',
      '📝',
      '📚',
      '📕',
      '💡',
      '🧠',
      '🤖',
      '💻',
      '🎮',
      '🎵',
      '🎨',
      '🎬',
      '⚽',
      '🏀',
      '🍎',
      '☕',
      '🚀',
      '⭐',
      '❤️',
      '🔥',
      '✨',
      '⚡',
      '🏠',
      '🏢',
      '✈️',
      '🌍',
      '🔒',
      '🔑',
      '🚫',
      '⚠️',
    ];

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1A1A1A) : Colors.white,
          title: Text(
            'Yeni Klasör',
            style: TextStyle(color: isDark ? Colors.white : Colors.black87),
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: nameController,
                    style: TextStyle(
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Klasör Adı',
                      labelStyle: TextStyle(
                        color: isDark ? Colors.white60 : Colors.black54,
                      ),
                    ),
                    autofocus: true,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'İkon',
                    style: TextStyle(
                      color: isDark ? Colors.white70 : Colors.black87,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 120,
                    child: SingleChildScrollView(
                      child: Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: emojis.map((e) {
                          final isSelected = selectedEmoji == e;
                          return GestureDetector(
                            onTap: () => setStateDialog(
                              () => selectedEmoji = isSelected ? null : e,
                            ),
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? (isDark ? Colors.white10 : Colors.black12)
                                    : null,
                                borderRadius: BorderRadius.circular(8),
                                border: isSelected
                                    ? Border.all(
                                        color: isDark
                                            ? Colors.white54
                                            : Colors.black54,
                                      )
                                    : null,
                              ),
                              child: Text(
                                e,
                                style: const TextStyle(fontSize: 24),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Renk',
                    style: TextStyle(
                      color: isDark ? Colors.white70 : Colors.black87,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      GestureDetector(
                        onTap: () =>
                            setStateDialog(() => selectedColorValue = null),
                        child: Container(
                          width: 32,
                          height: 32,
                          margin: const EdgeInsets.only(right: 8),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isDark ? Colors.white10 : Colors.grey[200],
                            border: Border.all(
                              color: selectedColorValue == null
                                  ? (isDark ? Colors.white : Colors.black)
                                  : Colors.transparent,
                              width: 2,
                            ),
                          ),
                          child: Icon(
                            FontAwesomeIcons.ban,
                            size: 14,
                            color: isDark ? Colors.white54 : Colors.black45,
                          ),
                        ),
                      ),
                      ...palette.map((c) {
                        final isSelected = selectedColorValue == c.value;
                        return GestureDetector(
                          onTap: () => setStateDialog(
                            () => selectedColorValue = c.value,
                          ),
                          child: Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: c,
                              border: Border.all(
                                color: isSelected
                                    ? (isDark ? Colors.white : Colors.black)
                                    : Colors.transparent,
                                width: isSelected ? 2.5 : 0,
                              ),
                              boxShadow: isSelected
                                  ? [
                                      BoxShadow(
                                        color: c.withOpacity(0.4),
                                        blurRadius: 6,
                                        spreadRadius: 1,
                                      ),
                                    ]
                                  : null,
                            ),
                            child: isSelected
                                ? Center(
                                    child: Icon(
                                      Icons.check,
                                      size: 14,
                                      color: c.computeLuminance() > 0.5
                                          ? Colors.black
                                          : Colors.white,
                                    ),
                                  )
                                : null,
                          ),
                        );
                      }).toList(),
                    ],
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'İptal',
                style: TextStyle(
                  color: isDark ? Colors.white60 : Colors.black54,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, {
                'name': nameController.text.trim(),
                'color': selectedColorValue,
                'icon': selectedEmoji,
              }),
              style: ElevatedButton.styleFrom(
                backgroundColor: isDark ? Colors.white : Colors.black,
                foregroundColor: isDark ? Colors.black : Colors.white,
              ),
              child: const Text('Oluştur'),
            ),
          ],
        ),
      ),
    );

    if (result != null && result['name'].isNotEmpty) {
      final newFolder = ChatFolder(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: result['name'],
        color: result['color'] ?? Colors.grey.value,
        icon: result['icon'],
        isExpanded: true,
        createdAt: DateTime.now(),
      );
      setState(() => _folders.add(newFolder));
      await _storageService.saveFolders(_folders);
    }
  }

  Future<void> _handleEditFolder(ChatFolder folder) async {
    final theme = Theme.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final nameController = TextEditingController(text: folder.name);
    int? selectedColorValue = folder.color;
    String? selectedEmoji = folder.icon;

    final palette = [
      const Color(0xFFEF5350),
      const Color(0xFFEC407A),
      const Color(0xFFAB47BC),
      const Color(0xFF7E57C2),
      const Color(0xFF5C6BC0),
      const Color(0xFF42A5F5),
      const Color(0xFF29B6F6),
      const Color(0xFF26C6DA),
      const Color(0xFF26A69A),
      const Color(0xFF66BB6A),
      const Color(0xFF9CCC65),
      const Color(0xFFD4E157),
      const Color(0xFFFFEE58),
      const Color(0xFFFFCA28),
      const Color(0xFFFF7043),
      const Color(0xFF8D6E63),
    ];

    final emojis = [
      '📁',
      '📂',
      '💼',
      '📝',
      '📚',
      '📕',
      '💡',
      '🧠',
      '🤖',
      '💻',
      '🎮',
      '🎵',
      '🎨',
      '🎬',
      '⚽',
      '🏀',
      '🍎',
      '☕',
      '🚀',
      '⭐',
      '❤️',
      '🔥',
      '✨',
      '⚡',
      '🏠',
      '🏢',
      '✈️',
      '🌍',
      '🔒',
      '🔑',
      '🚫',
      '⚠️',
    ];

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1A1A1A) : Colors.white,
          title: Text(
            'Klasörü Düzenle',
            style: TextStyle(color: isDark ? Colors.white : Colors.black87),
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: nameController,
                    style: TextStyle(
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Klasör Adı',
                      labelStyle: TextStyle(
                        color: isDark ? Colors.white60 : Colors.black54,
                      ),
                    ),
                    autofocus: true,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'İkon',
                    style: TextStyle(
                      color: isDark ? Colors.white70 : Colors.black87,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 120, // Limited height for emojis
                    child: SingleChildScrollView(
                      child: Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: emojis.map((e) {
                          final isSelected = selectedEmoji == e;
                          return GestureDetector(
                            onTap: () => setStateDialog(
                              () => selectedEmoji = isSelected ? null : e,
                            ),
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? (isDark ? Colors.white10 : Colors.black12)
                                    : null,
                                borderRadius: BorderRadius.circular(8),
                                border: isSelected
                                    ? Border.all(
                                        color: isDark
                                            ? Colors.white54
                                            : Colors.black54,
                                      )
                                    : null,
                              ),
                              child: Text(
                                e,
                                style: const TextStyle(fontSize: 24),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Renk',
                    style: TextStyle(
                      color: isDark ? Colors.white70 : Colors.black87,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      GestureDetector(
                        onTap: () =>
                            setStateDialog(() => selectedColorValue = null),
                        child: Container(
                          width: 32,
                          height: 32,
                          margin: const EdgeInsets.only(right: 8),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isDark ? Colors.white10 : Colors.grey[200],
                            border: Border.all(
                              color: selectedColorValue == null
                                  ? (isDark ? Colors.white : Colors.black)
                                  : Colors.transparent,
                              width: 2,
                            ),
                          ),
                          child: Icon(
                            FontAwesomeIcons.ban,
                            size: 14,
                            color: isDark ? Colors.white54 : Colors.black45,
                          ),
                        ),
                      ),
                      ...palette.map((c) {
                        final isSelected = selectedColorValue == c.value;
                        return GestureDetector(
                          onTap: () => setStateDialog(
                            () => selectedColorValue = c.value,
                          ),
                          child: Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: c,
                              border: Border.all(
                                color: isSelected
                                    ? (isDark ? Colors.white : Colors.black)
                                    : Colors.transparent,
                                width: isSelected ? 2.5 : 0,
                              ),
                              boxShadow: isSelected
                                  ? [
                                      BoxShadow(
                                        color: c.withOpacity(0.4),
                                        blurRadius: 6,
                                        spreadRadius: 1,
                                      ),
                                    ]
                                  : null,
                            ),
                            child: isSelected
                                ? Center(
                                    child: Icon(
                                      Icons.check,
                                      size: 14,
                                      color: c.computeLuminance() > 0.5
                                          ? Colors.black
                                          : Colors.white,
                                    ),
                                  )
                                : null,
                          ),
                        );
                      }).toList(),
                    ],
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),

          // -----------------------------
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'İptal',
                style: TextStyle(
                  color: isDark ? Colors.white60 : Colors.black54,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, {
                'name': nameController.text.trim(),
                'color': selectedColorValue,
                'icon': selectedEmoji,
              }),
              style: ElevatedButton.styleFrom(
                backgroundColor: isDark ? Colors.white : Colors.black,
                foregroundColor: isDark ? Colors.black : Colors.white,
              ),
              child: const Text('Kaydet'),
            ),
          ],
        ),
      ),
    );

    if (result != null && result['name'].isNotEmpty) {
      setState(() {
        final index = _folders.indexWhere((f) => f.id == folder.id);
        if (index != -1) {
          _folders[index] = folder.copyWith(
            name: result['name'],
            color: result['color'] ?? Colors.grey.value,
            icon: result['icon'],
          );
        }
      });
      await _storageService.saveFolders(_folders);
    }
  }

  Future<void> _handleDeleteFolder(ChatFolder folder) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Klasörü Sil'),
        content: const Text(
          'Bu klasör silinecek. Sohbetler silinmeyecek, sadece klasörden çıkarılacak.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Sil'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() {
        _folders.removeWhere((f) => f.id == folder.id);
        for (var i = 0; i < _chats.length; i++) {
          if (_chats[i].folderId == folder.id) {
            _chats[i] = _chats[i].copyWith(folderId: null, clearFolderId: true);
          }
        }
      });
      await _storageService.saveFolders(_folders);
      await _storageService.saveChats(_chats);
    }
  }

  Future<void> _handleToggleFolderPin(ChatFolder folder) async {
    final index = _folders.indexWhere((f) => f.id == folder.id);
    if (index != -1) {
      setState(() {
        _folders[index] = _folders[index].copyWith(
          isPinned: !_folders[index].isPinned,
        );
      });
      await _storageService.saveFolders(_folders);
    }
  }

  Future<void> _handleToggleFolder(ChatFolder folder) async {
    // Just toggle without verification
    final newExpandedState = !folder.isExpanded;

    if (!mounted) return;
    setState(() {
      final index = _folders.indexWhere((f) => f.id == folder.id);
      if (index != -1) {
        _folders[index] = folder.copyWith(isExpanded: newExpandedState);
      }
    });
    await _storageService.saveFolders(_folders);
  }

  Future<void> _handleChatMoveToFolder(Chat chat, String? folderId) async {
    setState(() {
      final index = _chats.indexWhere((c) => c.id == chat.id);
      if (index != -1) {
        _chats[index] = chat.copyWith(
          folderId: folderId,
          clearFolderId: folderId == null,
        );
        if (_currentChat?.id == chat.id) {
          _currentChat = _chats[index];
        }
      }
    });
    await _storageService.saveChats(_chats);
  }

  Future<void> _loadData() async {
    final chats = await _storageService.loadChats();
    final profile = await _storageService.loadUserProfile();
    final notificationsEnabled = await _storageService
        .getNotificationsEnabled();
    final fontSizeIndex = await _storageService.getFontSizeIndex();
    final fontFamily = await _storageService.getFontFamily();
    final folders = await _storageService.loadFolders();
    final isGmailAiAlwaysAllowed = await _storageService
        .getIsGmailAiAlwaysAllowed();
    final isGithubAiAlwaysAllowed = await _storageService
        .getIsGithubAiAlwaysAllowed();
    final isOutlookAiAlwaysAllowed = await _storageService
        .getIsOutlookAiAlwaysAllowed();

    // Servisleri sessizce başlat (otomatik bağlantı)
    await _gmailService.initialize();
    await _githubService.initialize();
    await OutlookService.instance.initialize();

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
      _folders = folders;
      _isGmailAiAlwaysAllowed = isGmailAiAlwaysAllowed;
      _isGithubAiAlwaysAllowed = isGithubAiAlwaysAllowed;
      _isOutlookAiAlwaysAllowed = isOutlookAiAlwaysAllowed;
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
    final isGmailAiAlwaysAllowed = await _storageService
        .getIsGmailAiAlwaysAllowed();
    final isGithubAiAlwaysAllowed = await _storageService
        .getIsGithubAiAlwaysAllowed();

    if (!mounted) return;
    setState(() {
      _notificationsEnabled = notificationsEnabled;
      _fontSizeIndex = fontSizeIndex;
      _fontFamily = (fontFamily == null || fontFamily.isEmpty)
          ? null
          : fontFamily;
      _isGmailAiAlwaysAllowed = isGmailAiAlwaysAllowed;
      _isGithubAiAlwaysAllowed = isGithubAiAlwaysAllowed;
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

    // --- Security Check ---
    bool isLocked = chat.isLocked;
    LockType type = chat.lockType;
    String? data = chat.lockData;
    String title = chat.title;

    // Check parent folder lock if chat itself isn't locked (or even if it is, maybe double lock?)
    // For now, let's prioritize chat lock, then folder lock.

    if (isLocked) {
      final verified = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (context) => LockVerificationScreen(
            lockType: type,
            lockData: data,
            title: '$title Kilidini Aç',
          ),
        ),
      );

      if (verified != true) return; // Authentication failed or cancelled
    }
    // ----------------------

    // Eski stream'i iptal et
    await _groupMessagesSubscription?.cancel();
    _groupMessagesSubscription = null;

    setState(() {
      _currentChat = chat;
      _currentTodoTasks = chat.projectTasks ?? [];
      _isTodoPanelOpen = false;
      _ephemeralMessages.clear(); // Sohbet değişince geçici mesajları temizle

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

  void _openChatSummaries(Chat chat) async {
    if (!mounted) return;
    if (!await _verifyLockIfNeeded(chat)) return;

    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ChatSummariesScreen(chat: chat)),
    );

    // Refresh chats to pick up any generated summaries
    // This fixes the issue where re-entering the screen would regenerate the summary
    // because the ChatScreen held stale data.
    if (!mounted) return;
    final chats = await _storageService.loadChats();
    if (!mounted) return;

    setState(() {
      _chats = chats;
      // Also update _currentChat if it matches the one we just summarized
      if (_currentChat?.id == chat.id) {
        final index = _chats.indexWhere((c) => c.id == chat.id);
        if (index != -1) {
          _currentChat = _chats[index];
        }
      }
    });
  }

  Future<bool> _verifyLockIfNeeded(Chat chat) async {
    if (!chat.isLocked) return true;

    if (!mounted) return false;
    final verified = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => LockVerificationScreen(
          lockType: chat.lockType,
          lockData: chat.lockData,
          title: '${chat.title} Kilidini Aç',
        ),
      ),
    );

    return verified == true;
  }

  Future<void> _handleChatLock(Chat chat) async {
    // If locked -> Unlock
    if (chat.isLocked) {
      final verified = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (context) => LockVerificationScreen(
            lockType: chat.lockType,
            lockData: chat.lockData,
            title: '${chat.title} Kilidini Kaldır',
          ),
        ),
      );

      if (verified != true) return;

      if (!mounted) return;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Kilidi Kaldır'),
          content: const Text('Bu sohbetin kilidi kaldırılacak.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('İptal'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Kaldır'),
            ),
          ],
        ),
      );

      if (confirmed == true && mounted) {
        setState(() {
          final index = _chats.indexWhere((c) => c.id == chat.id);
          if (index != -1) {
            _chats[index] = _chats[index].copyWith(
              isLocked: false,
              lockType: LockType.none,
              lockData: null,
            );
            if (_currentChat?.id == chat.id) {
              _currentChat = _chats[index];
            }
          }
        });
        await _storageService.saveChats(_chats);
      }
      return;
    }

    // If unlocked -> Lock
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(builder: (context) => const LockSetupScreen()),
    );

    if (result != null && mounted) {
      setState(() {
        final index = _chats.indexWhere((c) => c.id == chat.id);
        if (index != -1) {
          _chats[index] = _chats[index].copyWith(
            isLocked: true,
            lockType: result['type'],
            lockData: result['data'],
          );
          if (_currentChat?.id == chat.id) {
            _currentChat = _chats[index];
          }
        }
      });
      await _storageService.saveChats(_chats);
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
        onToolCall: (name, args, id, isFinal) async =>
            null, // Retry'da araç gerekmiyor
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
    if (!await _verifyLockIfNeeded(chat)) return;

    final titleController = TextEditingController(text: chat.title);
    final projectLabelController = TextEditingController(
      text: chat.projectLabel ?? '',
    );
    // null represent "Default" (no color) which is different from "0"
    int? selectedColorValue = chat.projectColor;

    // Helper to regenerate title
    Future<void> regenerateTitle(StateSetter setStateDialog) async {
      if (chat.messages.isEmpty) {
        GreyNotification.show(
          context,
          'Mesaj olmayan sohbette başlık üretilemez.',
        );
        return;
      }
      setStateDialog(() {
        titleController.text = 'Başlık üretiliyor...';
      });

      try {
        // Last 30 messages
        final recentMessages = chat.messages.length > 30
            ? chat.messages.sublist(chat.messages.length - 30)
            : chat.messages;

        final history = recentMessages
            .map(
              (m) => {
                'role': m.isUser ? 'user' : 'assistant',
                'content': m.content,
              },
            )
            .toList();

        // Add system instruction for title
        history.add({
          'role': 'system',
          'content':
              'GENERATE_TITLE', // OpenRouterService logic or direct prompt
        });

        // Direct call to OpenRouterService with specific prompt for title
        final prompt =
            "Bu sohbet geçmişine dayalı kısa, özetleyici, çekici bir başlık (maksimum 4-5 kelime) oluştur. Sadece başlığı yaz, tırnak işareti kullanma.";
        final newTitle = await _openRouterService.sendMessageWithHistory(
          recentMessages
              .map(
                (m) => {
                  'role': m.isUser ? 'user' : 'assistant',
                  'content': m.content,
                },
              )
              .toList(),
          prompt,
        );

        if (newTitle.isNotEmpty) {
          setStateDialog(() {
            titleController.text = newTitle.replaceAll('"', '').trim();
          });
        }
      } catch (e) {
        setStateDialog(() {
          titleController.text = chat.title; // Revert
        });
        GreyNotification.show(context, 'Başlık üretilemedi: $e');
      }
    }

    // 45 Color Palette Generation
    final List<Color> palette = [
      // Greyscale
      const Color(0xFF000000), // Black
      const Color(0xFFFFFFFF), // White
      const Color(0xFF9E9E9E), // Grey
      const Color(0xFF607D8B), // BlueGrey
      // Warm
      const Color(0xFFEF5350), const Color(0xFFB71C1C), // Red
      const Color(0xFFEC407A), const Color(0xFF880E4F), // Pink
      const Color(0xFFAB47BC), const Color(0xFF4A148C), // Purple
      const Color(0xFF7E57C2), const Color(0xFF311B92), // DeepPurple
      const Color(0xFF5C6BC0), const Color(0xFF1A237E), // Indigo
      // Cool
      const Color(0xFF42A5F5), const Color(0xFF0D47A1), // Blue
      const Color(0xFF29B6F6), const Color(0xFF01579B), // LightBlue
      const Color(0xFF26C6DA), const Color(0xFF006064), // Cyan
      const Color(0xFF26A69A), const Color(0xFF004D40), // Teal
      const Color(0xFF66BB6A), const Color(0xFF1B5E20), // Green
      const Color(0xFF9CCC65), const Color(0xFF33691E), // LightGreen
      const Color(0xFFD4E157), const Color(0xFF827717), // Lime
      // Hot
      const Color(0xFFFFEE58), const Color(0xFFF57F17), // Yellow
      const Color(0xFFFFCA28), const Color(0xFFFF6F00), // Amber
      const Color(0xFFFF7043), const Color(0xFFBF360C), // DeepOrange
      const Color(0xFF8D6E63), const Color(0xFF3E2723), // Brown
    ];
    // Fill up to ~45 if needed, but 20 pairs + 4 = 44 colors. Good enough.

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            final theme = Theme.of(context);
            final isDark = Theme.of(context).brightness == Brightness.dark;

            return AlertDialog(
              backgroundColor: isDark ? const Color(0xFF1A1A1A) : Colors.white,
              title: Text(
                'Sohbet Ayarları',
                style: TextStyle(color: isDark ? Colors.white : Colors.black87),
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title Input
                      TextField(
                        controller: titleController,
                        style: TextStyle(
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                        decoration: InputDecoration(
                          labelText: 'Sohbet Başlığı',
                          labelStyle: TextStyle(
                            color: isDark ? Colors.white60 : Colors.black54,
                          ),
                          suffixIcon: IconButton(
                            icon: const FaIcon(
                              FontAwesomeIcons.wandMagicSparkles,
                              size: 16,
                            ),
                            color: Colors.amber,
                            tooltip: 'AI ile Başlık Üret',
                            onPressed: () => regenerateTitle(setStateDialog),
                          ),
                          enabledBorder: UnderlineInputBorder(
                            borderSide: BorderSide(
                              color: isDark ? Colors.white24 : Colors.black12,
                            ),
                          ),
                          focusedBorder: UnderlineInputBorder(
                            borderSide: BorderSide(
                              color: isDark ? Colors.white : Colors.black,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Label Input
                      TextField(
                        controller: projectLabelController,
                        style: TextStyle(
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                        decoration: InputDecoration(
                          labelText: 'Etiket (Opsiyonel)',
                          labelStyle: TextStyle(
                            color: isDark ? Colors.white60 : Colors.black54,
                          ),
                          hintText: 'Örn: İş, Kişisel, Fikir',
                          hintStyle: TextStyle(
                            color: isDark ? Colors.white38 : Colors.black26,
                          ),
                          enabledBorder: UnderlineInputBorder(
                            borderSide: BorderSide(
                              color: isDark ? Colors.white24 : Colors.black12,
                            ),
                          ),
                          focusedBorder: UnderlineInputBorder(
                            borderSide: BorderSide(
                              color: isDark ? Colors.white : Colors.black,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Renk',
                        style: TextStyle(
                          color: isDark ? Colors.white70 : Colors.black87,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Special Options: Custom / Default
                      Row(
                        children: [
                          // Default (Ban Icon)
                          GestureDetector(
                            onTap: () =>
                                setStateDialog(() => selectedColorValue = null),
                            child: Container(
                              width: 32,
                              height: 32,
                              margin: const EdgeInsets.only(right: 8),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isDark
                                    ? Colors.white10
                                    : Colors.grey[200],
                                border: Border.all(
                                  color: selectedColorValue == null
                                      ? (isDark ? Colors.white : Colors.black)
                                      : Colors.transparent,
                                  width: 2,
                                ),
                              ),
                              child: Icon(
                                FontAwesomeIcons.ban,
                                size: 14,
                                color: isDark ? Colors.white54 : Colors.black45,
                              ),
                            ),
                          ),
                          // "Özel" (Custom Picker) logic could go here, but user asked for "Özel"
                          // which implies a curated picker. The grid below IS the custom picker.
                          // Let's add a label "Seç" implying choice.
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Color Grid
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: palette.map((c) {
                          final isSelected = selectedColorValue == c.value;

                          // Stroke Logic
                          Color borderColor = Colors.transparent;
                          if (isSelected) {
                            // If selected, border contrasts with background or black/white logic
                            // But user specifically asked:
                            // "beyaz rengi seçtiyse dışına stroke ekle dış çizgi o stroke siyah olsun eğer siyah seçtiyse stroke beyaz olsun"
                            if (c.value == 0xFF000000) {
                              // Black
                              borderColor = Colors.white;
                            } else if (c.value == 0xFFFFFFFF) {
                              // White
                              borderColor = Colors.black;
                            } else {
                              borderColor = isDark
                                  ? Colors.white
                                  : Colors.black;
                            }
                          } else {
                            // Unselected logic for visibility on White/Black
                            if (c.value == 0xFFFFFFFF) {
                              borderColor = Colors
                                  .grey[300]!; // Visible white on white bg
                            } else if (c.value == 0xFF000000 && isDark) {
                              borderColor =
                                  Colors.white24; // Visible black on dark bg
                            }
                          }

                          return GestureDetector(
                            onTap: () => setStateDialog(
                              () => selectedColorValue = c.value,
                            ),
                            child: Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: c,
                                border: Border.all(
                                  color: borderColor,
                                  width: isSelected
                                      ? 2.5
                                      : (borderColor == Colors.transparent
                                            ? 0
                                            : 1),
                                ),
                                boxShadow: isSelected
                                    ? [
                                        BoxShadow(
                                          color: c.withOpacity(0.4),
                                          blurRadius: 6,
                                          spreadRadius: 1,
                                        ),
                                      ]
                                    : null,
                              ),
                              child: isSelected
                                  ? Center(
                                      child: Icon(
                                        Icons.check,
                                        size: 14,
                                        color: (c.computeLuminance() > 0.5)
                                            ? Colors.black
                                            : Colors.white,
                                      ),
                                    )
                                  : null,
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    'İptal',
                    style: TextStyle(
                      color: isDark ? Colors.white60 : Colors.black54,
                    ),
                  ),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop<Map<String, dynamic>>(context, {
                      'title': titleController.text.trim(),
                      'projectLabel': projectLabelController.text.trim(),
                      'projectColor': selectedColorValue,
                    });
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isDark ? Colors.white : Colors.black,
                    foregroundColor: isDark ? Colors.black : Colors.white,
                  ),
                  child: const Text('Kaydet'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result == null) return;

    final String newTitle = (result['title'] as String?)?.trim() ?? '';
    final String newProjectLabel =
        (result['projectLabel'] as String?)?.trim() ?? '';
    final int? newProjectColor = result['projectColor'] as int?;

    if (newTitle.isEmpty) return;

    setState(() {
      final index = _chats.indexWhere((c) => c.id == chat.id);
      if (index != -1) {
        _chats[index] = _chats[index].copyWith(
          title: newTitle,
          projectLabel: newProjectLabel.isEmpty ? null : newProjectLabel,
          projectColor: newProjectColor,
          clearProjectColor: newProjectColor == null,
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
    final theme = Theme.of(context);
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
      backgroundColor: Theme.of(context).colorScheme.surface,
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
                          color: themeService.isDarkMode
                              ? Colors.white24
                              : Colors.black12,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    Text(
                      'Seçili sohbetleri silmek istiyor musun?',
                      style: TextStyle(
                        color: Theme.of(context).textTheme.bodyLarge?.color,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${selectedChats.length} sohbet seçildi. İstersen aşağıdan bazılarını kaldırabilirsin.',
                      style: TextStyle(
                        color: Theme.of(
                          context,
                        ).textTheme.bodySmall?.color?.withOpacity(0.7),
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 220,
                      child: selectedChats.isEmpty
                          ? Center(
                              child: Text(
                                'Hiç sohbet seçili değil.',
                                style: TextStyle(
                                  color: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.color
                                      ?.withOpacity(0.5),
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
                                    color: themeService.isDarkMode
                                        ? const Color(0xFF222222)
                                        : Colors.grey.shade100,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: themeService.isDarkMode
                                          ? Colors.white10
                                          : Colors.black26,
                                    ),
                                  ),
                                  child: ListTile(
                                    dense: true,
                                    title: Text(
                                      chat.title,
                                      style: TextStyle(
                                        color: themeService.isDarkMode
                                            ? Colors.white
                                            : Colors.black87,
                                        fontSize: 14,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    trailing: IconButton(
                                      icon: Icon(
                                        Icons.close,
                                        size: 18,
                                        color: themeService.isDarkMode
                                            ? Colors.white60
                                            : Colors.black54,
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
                          child: Text(
                            'İptal',
                            style: TextStyle(
                              color: Theme.of(
                                context,
                              ).textTheme.bodySmall?.color?.withOpacity(0.6),
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
      _ephemeralMessages
          .clear(); // Yeni sohbet başlayınca geçici mesajları temizle
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
      content:
          'İnternetini kontrol edebilir misin? [Ayarlar](wifi://settings)\n\nİnternetin gelene kadar belki oyun oynayabilirsin? [Oyunlar](gamehub://)',
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
    final imgenRegex = RegExp(
      r'^\s*\[İ?MGEN\]\s*:?\s*(.+)$',
      caseSensitive: false,
    );
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
          trimmed.startsWith('[IMGEN]') ||
          trimmed.startsWith('[REASON]') ||
          trimmed.startsWith('[AGENTİCMODE]') ||
          trimmed.startsWith('[AGENTICMODE]') ||
          trimmed.startsWith('[TASKS]')) {
        continue;
      }
      filtered.add(line);
    }
    String result = filtered.join('\n');
    // Multi-Answer etiketlerini global olarak temizle
    result = result.replaceAll(
      RegExp(r'\[\/?MULTI[-_]ANSWERS?\]', caseSensitive: false),
      '',
    );
    return result;
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

    String finalPrompt = prompt;

    // AI'ın kendisi prompt ürettiği için direkt üretim aşamasına geçiyoruz
    // AMA: Eğer prompt çok kısa veya Türkçe kelimeler içeriyorsa "Prompt Engineering" yapalım.
    try {
      bool needsEngineering =
          prompt.length < 50 ||
          prompt.contains(RegExp(r'[ığüşöçİĞÜŞÖÇ]')) ||
          !prompt.contains(' ') ||
          prompt.split(' ').length < 5;

      if (needsEngineering) {
        print('🪄 AI Promptu iyileştiriliyor: $prompt');
        try {
          final engineered = await _openRouterService.sendMessage(
            "You are a master Prompt Engineer for Image Generation. Transform this raw AI input into a highly detailed, professional English prompt for cinematic generation: '$prompt'.\n"
            "Return ONLY the English prompt text, no quotes or intro. Keep it under 400 characters.",
          );
          if (engineered.isNotEmpty && !engineered.contains('error')) {
            finalPrompt = engineered.trim();
          }
        } catch (e) {
          print('⚠️ Prompt iyileştirme başarısız, orijinali kullanılıyor: $e');
        }
      }

      // Eğer seçili bir görsel varsa onu referans olarak gönder
      String? refUrl;
      if (_selectedImagesBase64.isNotEmpty) {
        refUrl = 'data:image/jpeg;base64,${_selectedImagesBase64.first}';
      }

      final generatedImageBase64 = await _imageGenService
          .generateImageWithFallback(finalPrompt, referenceImageUrl: refUrl);

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
        _isGeneratingImage = false;
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
      final result = await FilePicker.platform.pickFiles(type: FileType.any);

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
            GreyNotification.show(
              context,
              'Dosya bozuk veya şifresi çözülemedi',
            );
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

    if (!await _verifyLockIfNeeded(chat)) return;

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

    if (!await _verifyLockIfNeeded(chat)) return;

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
    if (_pickedPdfFiles.length >= 3) {
      GreyNotification.show(context, 'En fazla 3 PDF ekleyebilirsiniz');
      return;
    }

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        allowMultiple: true,
      );

      if (result != null && result.files.isNotEmpty) {
        final remainingSlots = 3 - _pickedPdfFiles.length;
        final filesToAdd = result.files.take(remainingSlots).toList();

        if (result.files.length > remainingSlots) {
          GreyNotification.show(
            context,
            'Limit nedeniyle sadece $remainingSlots dosya eklendi',
          );
        }

        setState(() {
          _isLoading = true;
          _loadingMessage = 'PDF işleniyor...';
        });

        try {
          for (var selectedFile in filesToAdd) {
            if (selectedFile.path != null) {
              final file = File(selectedFile.path!);
              final bytes = await file.readAsBytes();
              final base64String = base64Encode(bytes);

              _pickedPdfFiles.add(file);
              _pickedPdfBase64List.add(base64String);
            }
          }

          setState(() {
            _isLoading = false;
          });

          GreyNotification.show(context, 'PDF(ler) eklendi');
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

  Future<void> _sendMessage({String? customMessage}) async {
    // AI cevap verirken mesaj göndermeyi engelle
    if (_activeResponseChatId != null) {
      GreyNotification.show(
        context,
        'AI henüz cevap veriyor, lütfen bekleyin...',
      );
      return;
    }

    String messageText = customMessage ?? _messageController.text.trim();

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

    // PDF varsa görselleştir
    if (_pickedPdfBase64List.isNotEmpty) {
      final pdfNames = _pickedPdfFiles
          .map((f) => f.path.split(Platform.pathSeparator).last)
          .join(', ');
      final spacing = messageText.isEmpty ? '' : '\n\n';
      messageText = '[PDF: $pdfNames]$spacing$messageText'.trim();
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
    final List<String> pdfsBase64ToSend = List<String>.from(
      _pickedPdfBase64List,
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
        if (!_isSecretMode) {
          _chats.insert(0, newChat);
        }
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
        _loadingMessage = 'thinking';
      }

      // Mesaj gönderildiği anda inputtaki dosyaları temizle
      _selectedImages.clear();
      _selectedImagesBase64.clear();
      _pickedPdfFiles.clear();
      _pickedPdfBase64List.clear();
    });

    // Input metnini temizle ve en alta kaydır
    if (customMessage == null) _messageController.clear();
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

        if (!_isSecretMode) {
          await _storageService.saveChats(_chats);
          await _maybeGenerateChatTitle(targetChatId);
        }

        // Update stats
        await _storageService.addUsageMinutes(1);
        await _storageService.addChatUsageMinutes(targetChatId, 1);
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

      if (_isRememberPastChatsEnabled) {
        // Find most recent past messages from other chats
        final otherChats = _chats
            .where((c) => c.id != targetChatId && c.messages.isNotEmpty)
            .toList();
        if (otherChats.isNotEmpty) {
          otherChats.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
          final lastChat = otherChats.first;
          final pastMsgs = lastChat.messages.length > 3
              ? lastChat.messages.sublist(lastChat.messages.length - 3)
              : lastChat.messages;

          final buffer = StringBuffer();
          buffer.writeln(
            'MEMORY: Information from the most recent previous conversation (Chat Title: "${lastChat.title}"):',
          );
          for (var m in pastMsgs) {
            buffer.writeln('${m.isUser ? "User" : "AI"}: ${m.content}');
          }

          conversationHistory.insert(0, {
            'role': 'system',
            'content': buffer.toString().trim(),
          });
        }
      }

      // --- Service Connection Context (Manus AI Style) ---
      final bool isGmailConnected = GmailService.instance.isConnected();
      final bool isGithubConnected = GitHubService.instance.isConnected();

      final serviceContext = StringBuffer();
      serviceContext.writeln('[SERVICE_CONTEXT]');
      serviceContext.writeln(
        'GMAIL_CONNECTED: $isGmailConnected (Allowed: $_isGmailAiAlwaysAllowed)',
      );
      serviceContext.writeln(
        'GITHUB_CONNECTED: $isGithubConnected (Allowed: $_isGithubAiAlwaysAllowed)',
      );
      serviceContext.writeln();
      serviceContext.writeln('INSTRUCTIONS:');
      if (isGmailConnected && _isGmailAiAlwaysAllowed) {
        serviceContext.writeln(
          '- You can access Gmail. If the user wants to check emails or create drafts, use tools like `read_gmail_inbox` or `create_gmail_draft`. Be proactive. If you get a 403 error, explain that the user might need to enable the API or add themselves to Test Users.',
        );
      }
      if (isGithubConnected && _isGithubAiAlwaysAllowed) {
        serviceContext.writeln(
          '- You can access GitHub. You can read repository files, list repositories, star/unstar repos, and view user/starred repos. Use `list_github_repos` to find repositories. Use `read_github_repo` to read files. Use `star_github_repo` to star. Be proactive like Manus AI.',
        );
      }
      final isOutlookConnected = await _storageService.getIsOutlookConnected();
      final isOutlookAllowed = await _storageService
          .getIsOutlookAiAlwaysAllowed();
      if (isOutlookConnected && isOutlookAllowed) {
        serviceContext.writeln(
          '- You can access Outlook. Use `read_outlook_inbox` to check emails and `send_outlook_email` to send emails.',
        );
      }
      serviceContext.writeln(
        '- If a service is connected but "Allowed" is false, politely ask the user to enable it from the attachment (paperclip) menu or settings if they want you to use it.',
      );

      conversationHistory.add({
        'role': 'system',
        'content': serviceContext.toString().trim(),
      });

      conversationHistory.add({
        'role': 'system',
        'content':
            'ARTIFACTS (OPSİYONEL): Eğer bir kullanıcıya HTML, CSS veya JavaScript içeren ve görsel bir önizleme gerektiren (web sayfası, UI bileşeni, animasyon vb.) bir çıktı vereceksen Artifacts panelini kullanabilirsin. '
            'Bu zorunlu değildir, sadece önizleme yapılmasının yararlı olacağı durumlarda kullan. BASİT KOD BLOKLARI İÇİN NORMAL MARKDOWN KULLAN. '
            'Bir artifact başlatmak için şu sözdizimini kullan: [ARTIFACT title="Başlık" lang="html"] KOD [/ARTIFACT]. '
            'Bu panel otomatik olarak açılacaktır. ASLA araç kullanımını (İMGEN, ARTIFACT vb.) önceden açıklama, doğrudan kullan.',
      });

      conversationHistory.add({
        'role': 'system',
        'content':
            'Perform thorough web research to answer the user\'s request accurately. Provide sources when possible. IMPORTANT: If you decide to search or look for info, make sure to use relevant tool calls or reasoning. The user needs to see that you are searching.',
      });

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

      _messageController.clear();

      await _openRouterService.sendMessageWithHistoryStream(
        conversationHistory,
        messageText,
        imagesBase64: imagesBase64ToSend,
        pdfsBase64: pdfsBase64ToSend,
        onToken: (token) {
          if (!mounted || _shouldStopResponse) return;
          if (token.isEmpty) return;

          // Hız optimizasyonu: İlk token geldiğinde "thinking" veya "Aranıyor" gibi imleçleri kaldır
          if (_loadingMessage != null && !_isGeneratingImage) {
            _loadingMessage = null;
          }

          streamedText += token;
          _fullResponseText = streamedText;

          final multiAnswerRegex = RegExp(
            r'\[\/?MULTI[-_]ANSWERS?\]',
            caseSensitive: false,
          );
          final bool hasMulti = multiAnswerRegex.hasMatch(streamedText);

          if (hasMulti) {
            _currentTypingText = 'Alternatif cevaplar hazırlanıyor...';
          } else {
            _currentTypingText = _cleanStreamingTextForDisplay(
              _stripControlTagsForDisplay(streamedText),
            );
          }

          // Initial cursors/messages are handled by derivedMessage creation in _sendMessage
          // Hız optimizasyonu: localized updates via ValueNotifier
          _streamingContent.value = _cleanStreamingTextForDisplay(
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
                _detectControlTagsStreaming(streamedText);
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
        onToolCall: (name, args, id, isFinal) => _handleIncomingToolCall(
          name,
          args,
          id,
          aiMessageId,
          targetChatId,
          isFinal,
        ),
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

        // Multi-Answer handling - Using regex for robust detection and splitting (including closing tags)
        final multiAnswerRegex = RegExp(
          r'\[\/?MULTI[-_]ANSWERS?\]',
          caseSensitive: false,
        );
        final bool hasMultiAnswer = multiAnswerRegex.hasMatch(withoutControl);

        if (hasMultiAnswer) {
          final parts = withoutControl
              .split(multiAnswerRegex)
              .where((s) => s.trim().isNotEmpty)
              .toList();

          if (parts.length >= 2) {
            alternatives = parts
                .map((p) => _cleanStreamingTextForDisplay(p))
                .toList();
            // Don't show the first answer yet, keep the 'Preparing' status in the bubble
            finalContent = 'Bir cevap seçmek için panel bekleniyor...';

            setState(() {
              _isMultiAnswerPanelOpen = true;
              _currentMultiAnswers = alternatives!;
              _multiAnswerTargetMessageId = aiMessageId;
              _multiAnswerTargetChatId = targetChatId;
            });
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

      // Streaming tamamlandıktan sonra durum bayraklarını sıfırla (eğer halen bir görsel üretilmiyorsa)
      if (!_isGeneratingImage) {
        setState(() {
          _isLoading = false;
          _isTyping = false;
          _activeResponseChatId = null;
          _typingMessageId = null;
          _currentTypingText = '';
          _fullResponseText = '';
        });
      } else {
        // Görsel üretiliyorsa metinsel kısmı temizle ama loading'i koru
        setState(() {
          _typingMessageId = null;
          _currentTypingText = 'Görsel oluşturuluyor...';
          _fullResponseText = '';
        });
      }

      // Statistics and title generation
      if (!_isSecretMode) {
        await _storageService.saveChats(_chats);
        await _maybeGenerateChatTitle(targetChatId);
      }
      await _storageService.addUsageMinutes(1);
      await _storageService.addChatUsageMinutes(targetChatId, 1);

      // Count code lines in the response
      final codeBlocks = _collectCodeBlocksFromChat(_currentChat!);
      final codeLines = codeBlocks.fold(
        0,
        (sum, block) =>
            sum +
            block.code
                .split('\n')
                .where((line) => line.trim().isNotEmpty)
                .length,
      );
      if (codeLines > 0) {
        await _storageService.incrementTotalCodeLines(codeLines);
        await _storageService.updateLanguageUsage(
          'Dart',
          codeLines,
        ); // Assuming Dart for code
      } else {
        await _storageService.incrementTotalCodeLines(
          1,
        ); // Count as 1 code line for non-code messages
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

      // --- Security Check ---
      // Do not auto-generate titles for locked chats
      if (chat.isLocked) return;
      // ----------------------

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

      if (!isAutoTitle && !_isAutoTitleEnabled) return;

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
          title: newTitle.replaceAll('"', '').trim(),
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
    return _messageController.text.trim().isNotEmpty ||
        _selectedImages.isNotEmpty ||
        _pickedPdfFiles.isNotEmpty ||
        _isRecordingVoice;
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
      backgroundColor: themeService.isDarkMode
          ? const Color(0xFF1A1A1A)
          : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setStateSheet) {
            return SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // --- GMAIL ---
                  if (!GmailService.instance.isConnected())
                    ListTile(
                      leading: FaIcon(
                        FontAwesomeIcons.google,
                        color: themeService.isDarkMode
                            ? Colors.white
                            : Colors.black87,
                        size: 20,
                      ),
                      title: Text(
                        'Gmail bağla',
                        style: TextStyle(
                          color: themeService.isDarkMode
                              ? Colors.white
                              : Colors.black87,
                        ),
                      ),
                      onTap: () async {
                        Navigator.of(ctx).pop();
                        _handleGmailLink();
                      },
                    )
                  else
                    ListTile(
                      leading: FaIcon(
                        FontAwesomeIcons.google,
                        color: Colors.greenAccent, // Bağlıyken yeşil ikon
                        size: 20,
                      ),
                      title: Text(
                        'Gmail: ${_isGmailAiAlwaysAllowed ? "Aktif" : "Pasif"}',
                        style: TextStyle(
                          color: themeService.isDarkMode
                              ? Colors.white
                              : Colors.black87,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      trailing: Switch(
                        value: _isGmailAiAlwaysAllowed,
                        activeColor: Colors.purpleAccent,
                        onChanged: (val) async {
                          setStateSheet(() {
                            _isGmailAiAlwaysAllowed = val;
                          });
                          setState(() {
                            _isGmailAiAlwaysAllowed = val;
                          });
                          await _storageService.setIsGmailAiAlwaysAllowed(val);
                        },
                      ),
                    ),

                  Divider(
                    height: 1,
                    color: themeService.isDarkMode
                        ? Colors.white12
                        : Colors.black12,
                  ),

                  // --- GITHUB ---
                  if (!GitHubService.instance.isConnected())
                    ListTile(
                      leading: FaIcon(
                        FontAwesomeIcons.github,
                        color: themeService.isDarkMode
                            ? Colors.white
                            : Colors.black87,
                        size: 20,
                      ),
                      title: Text(
                        'GitHub bağla',
                        style: TextStyle(
                          color: themeService.isDarkMode
                              ? Colors.white
                              : Colors.black87,
                        ),
                      ),
                      onTap: () async {
                        Navigator.of(ctx).pop();
                        _handleGitHubLink();
                      },
                    )
                  else
                    ListTile(
                      leading: FaIcon(
                        FontAwesomeIcons.github,
                        color: Colors.greenAccent,
                        size: 20,
                      ),
                      title: Text(
                        'GitHub: ${_isGithubAiAlwaysAllowed ? "Aktif" : "Pasif"}',
                        style: TextStyle(
                          color: themeService.isDarkMode
                              ? Colors.white
                              : Colors.black87,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      trailing: Switch(
                        value: _isGithubAiAlwaysAllowed,
                        activeColor: Colors.purpleAccent,
                        onChanged: (val) async {
                          setStateSheet(() {
                            _isGithubAiAlwaysAllowed = val;
                          });
                          setState(() {
                            _isGithubAiAlwaysAllowed = val;
                          });
                          await _storageService.setIsGithubAiAlwaysAllowed(val);
                        },
                      ),
                    ),
                  Divider(
                    height: 1,
                    color: themeService.isDarkMode
                        ? Colors.white12
                        : Colors.black12,
                  ),

                  // --- OUTLOOK ---
                  if (!OutlookService.instance.isConnected())
                    ListTile(
                      leading: FaIcon(
                        FontAwesomeIcons.microsoft,
                        color: themeService.isDarkMode
                            ? Colors.white
                            : Colors.black87,
                        size: 20,
                      ),
                      title: Text(
                        'Outlook bağla',
                        style: TextStyle(
                          color: themeService.isDarkMode
                              ? Colors.white
                              : Colors.black87,
                        ),
                      ),
                      onTap: () async {
                        Navigator.of(ctx).pop();
                        _handleOutlookLink();
                      },
                    )
                  else
                    ListTile(
                      leading: FaIcon(
                        FontAwesomeIcons.microsoft,
                        color: Colors.greenAccent,
                        size: 20,
                      ),
                      title: Text(
                        'Outlook: ${_isOutlookAiAlwaysAllowed ? "Aktif" : "Pasif"}',
                        style: TextStyle(
                          color: themeService.isDarkMode
                              ? Colors.white
                              : Colors.black87,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      trailing: Switch(
                        value: _isOutlookAiAlwaysAllowed,
                        activeColor: Colors.purpleAccent,
                        onChanged: (val) async {
                          setStateSheet(() {
                            _isOutlookAiAlwaysAllowed = val;
                          });
                          setState(() {
                            _isOutlookAiAlwaysAllowed = val;
                          });
                          await _storageService.setIsOutlookAiAlwaysAllowed(
                            val,
                          );
                        },
                      ),
                    ),
                  Divider(
                    height: 1,
                    color: themeService.isDarkMode
                        ? Colors.white12
                        : Colors.black12,
                  ),
                  ListTile(
                    leading: Icon(
                      Icons.photo_camera,
                      color: themeService.isDarkMode
                          ? Colors.white
                          : Colors.black87,
                    ),
                    title: Text(
                      'Kamera',
                      style: TextStyle(
                        color: themeService.isDarkMode
                            ? Colors.white
                            : Colors.black87,
                      ),
                    ),
                    onTap: () async {
                      Navigator.of(ctx).pop();
                      await _pickFromCamera();
                    },
                  ),
                  Divider(
                    height: 1,
                    color: themeService.isDarkMode
                        ? Colors.white12
                        : Colors.black12,
                  ),
                  ListTile(
                    leading: Icon(
                      Icons.folder,
                      color: themeService.isDarkMode
                          ? Colors.white
                          : Colors.black87,
                    ),
                    title: Text(
                      'Dosyalar',
                      style: TextStyle(
                        color: themeService.isDarkMode
                            ? Colors.white
                            : Colors.black87,
                      ),
                    ),
                    onTap: () async {
                      Navigator.of(ctx).pop();
                      await _pickFromFiles();
                    },
                  ),
                  Divider(
                    height: 1,
                    color: themeService.isDarkMode
                        ? Colors.white12
                        : Colors.black12,
                  ),
                  ListTile(
                    leading: FaIcon(
                      FontAwesomeIcons.filePdf,
                      color: themeService.isDarkMode
                          ? Colors.white
                          : Colors.black87,
                      size: 20,
                    ),
                    title: Text(
                      'PDF Seç',
                      style: TextStyle(
                        color: themeService.isDarkMode
                            ? Colors.white
                            : Colors.black87,
                      ),
                    ),
                    onTap: () async {
                      Navigator.of(ctx).pop();
                      await _handlePdfSelection();
                    },
                  ),
                  // ... (other items)
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _handleGmailLink() async {
    final success = await _gmailService.signIn();
    if (success) {
      setState(() {});
      GreyNotification.show(context, 'Gmail başarıyla bağlandı!');
    } else {
      GreyNotification.show(context, 'Gmail bağlantısı başarısız oldu.');
    }
  }

  Future<void> _handleGitHubLink() async {
    final success = await _githubService.authenticate();
    if (success) {
      setState(() {});
      GreyNotification.show(context, 'GitHub başarıyla bağlandı!');
    } else {
      GreyNotification.show(context, 'GitHub bağlantısı başarısız oldu.');
    }
  }

  Future<void> _handleOutlookLink() async {
    final success = await OutlookService.instance.authenticate();
    if (success) {
      setState(() {});
      GreyNotification.show(context, 'Outlook başarıyla bağlandı!');
    } else {
      GreyNotification.show(context, 'Outlook bağlantısı başarısız oldu.');
    }
  }

  void _showUndoToast(String title, VoidCallback onUndo) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: themeService.isDarkMode
            ? const Color(0xFF1E1E1E)
            : Colors.white,
        duration: const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        content: Row(
          children: [
            Expanded(
              child: Text(
                'Mail gönderildi: $title',
                style: TextStyle(
                  color: themeService.isDarkMode
                      ? Colors.white
                      : Colors.black87,
                  fontSize: 13,
                ),
              ),
            ),
            TextButton(
              onPressed: () {
                onUndo();
                ScaffoldMessenger.of(context).hideCurrentSnackBar();
              },
              child: const Text(
                'Geri al',
                style: TextStyle(color: Colors.blueAccent),
              ),
            ),
            IconButton(
              icon: Icon(
                Icons.close,
                size: 18,
                color: themeService.isDarkMode
                    ? Colors.white54
                    : Colors.black54,
              ),
              onPressed: () =>
                  ScaffoldMessenger.of(context).hideCurrentSnackBar(),
            ),
          ],
        ),
      ),
    );
  }

  void _handleToolApproval(
    Message message,
    Map<String, dynamic> toolData,
  ) async {
    final toolName = toolData['toolCallName']; // e.g., 'create_gmail_draft'
    final title = toolData['title'] ?? 'İşlem';

    if (toolName == 'create_gmail_draft') {
      final args = toolData['args'] ?? {};

      // 1. Önce UI'da "Onaylandı" durumuna çekelim
      setState(() {
        final chatIndex = _chats.indexWhere((c) => c.id == _currentChat?.id);
        if (chatIndex != -1) {
          final messages = [..._chats[chatIndex].messages];
          final idx = messages.indexWhere((m) => m.id == message.id);
          if (idx != -1) {
            final currentMetadata = Map<String, dynamic>.from(
              messages[idx].metadata ?? {},
            );
            final currentTool = Map<String, dynamic>.from(
              currentMetadata['toolCall'] ?? {},
            );
            currentTool['status'] = 'draft_approved';
            currentTool['showApprove'] = false;
            currentMetadata['toolCall'] = currentTool;

            messages[idx] = messages[idx].copyWith(metadata: currentMetadata);
            _chats[chatIndex] = _chats[chatIndex].copyWith(messages: messages);
            _currentChat = _chats[chatIndex];
          }
        }
      });
      await _storageService.saveChats(_chats);

      // 2. Gerçek gönderim işlemini yap (GmailService)
      try {
        await _gmailService.sendEmail(
          to: args['to'] ?? '',
          subject: args['subject'] ?? '',
          body: args['body'] ?? '',
        );
        GreyNotification.show(context, 'Mail başarıyla gönderildi');
      } catch (e) {
        GreyNotification.show(context, 'Mail gönderilemedi: $e');
      }

      _showUndoToast(title, () {
        GreyNotification.show(context, 'İşlem geri alınamaz (Mail gönderildi)');
      });
    }
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

  Future<void> _startVoiceRecording({bool isManual = false}) async {
    if (_isLoading || _activeResponseChatId != null) {
      GreyNotification.show(
        context,
        'AI cevap veriyor, lütfen bitmesini bekleyin...',
      );
      return;
    }
    if (_isRecordingVoice) return;

    _isManualRecording = isManual;
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

        // Manuel modda (basılı tutma) otomatik durdurma yok
        if (_isManualRecording) return;

        // Sessizlik tespiti: seviye çok düşükse zamanlayıcı başlat, tekrar yükselirse iptal et
        const double silenceThreshold =
            0.08; // 0-1 arası; çok küçük sesleri sessizlik say
        const Duration silenceDuration = Duration(milliseconds: 1500);

        if (level < silenceThreshold) {
          _silenceTimer?.cancel();
          _silenceTimer = Timer(silenceDuration, () {
            if (mounted && _isRecordingVoice && !_isManualRecording) {
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
        String userFriendlyMessage = 'Ses kaydı hatası';
        if (message.toLowerCase().contains('timeout')) {
          userFriendlyMessage = 'Ses algılanamadı, zaman aşımı';
        } else if (message.toLowerCase().contains('no match')) {
          userFriendlyMessage = 'Ses anlaşılamadı, lütfen tekrar deneyin';
        } else if (message.toLowerCase().contains('busy')) {
          userFriendlyMessage = 'Ses servisi meşgul, lütfen bekleyin';
        } else if (message.toLowerCase().contains('not authorized')) {
          userFriendlyMessage = 'Mikrofon izni verilmemiş';
        }
        GreyNotification.show(context, userFriendlyMessage);
        _stopVoiceRecording();
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
      _isManualRecording = false;
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
                        _buildActionMenuItem(
                          icon: FontAwesomeIcons.google,
                          label: GmailService.instance.isConnected()
                              ? 'Gmail (Bağlı)'
                              : 'Gmail\'e Bağlan',
                          onTap: _handleGmailLink,
                          isActive: GmailService.instance.isConnected(),
                        ),
                        _buildActionMenuItem(
                          icon: FontAwesomeIcons.github,
                          label: GitHubService.instance.isConnected()
                              ? 'GitHub (Bağlı)'
                              : 'GitHub\'a Bağlan',
                          onTap: _handleGitHubLink,
                          isActive: GitHubService.instance.isConnected(),
                        ),
                        _buildActionMenuItem(
                          icon: FontAwesomeIcons.microsoft,
                          label: OutlookService.instance.isConnected()
                              ? 'Outlook (Bağlı)'
                              : 'Outlook\'a Bağlan',
                          onTap: _handleOutlookLink,
                          isActive: OutlookService.instance.isConnected(),
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
                                    : (themeService.isDarkMode
                                          ? Colors.white24
                                          : Colors.black26),
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
                                      : (themeService.isDarkMode
                                            ? Colors.white54
                                            : Colors.black54),
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
                                    : (themeService.isDarkMode
                                          ? Colors.white24
                                          : Colors.black26),
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
                                      : (themeService.isDarkMode
                                            ? Colors.white54
                                            : Colors.black54),
                                ),
                              ],
                            ),
                          ),
                        ),
                        // Scroll to Bottom Arrow
                        if (_showScrollToBottom) ...[
                          const SizedBox(width: 178),
                          GestureDetector(
                            onTap: _scrollToBottom,
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: themeService.isDarkMode
                                    ? Colors.white10
                                    : Colors.black.withOpacity(0.05),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: themeService.isDarkMode
                                      ? Colors.white24
                                      : Colors.black26,
                                  width: 1,
                                ),
                              ),
                              child: FaIcon(
                                FontAwesomeIcons.arrowDown,
                                size: 14,
                                color: themeService.isDarkMode
                                    ? Colors.white70
                                    : Colors.black54,
                              ),
                            ),
                          ),
                        ],
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
                                    : (themeService.isDarkMode
                                          ? Colors.white24
                                          : Colors.black26),
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
                                      : (themeService.isDarkMode
                                            ? Colors.white54
                                            : Colors.black54),
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
                                    : (themeService.isDarkMode
                                          ? Colors.white24
                                          : Colors.black54),
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
                                      : (themeService.isDarkMode
                                            ? Colors.white54
                                            : Colors.black54),
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
                                    : (themeService.isDarkMode
                                          ? Colors.white24
                                          : Colors.black26),
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
                                      : (themeService.isDarkMode
                                            ? Colors.white54
                                            : Colors.black54),
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
                                    : (themeService.isDarkMode
                                          ? Colors.white24
                                          : Colors.black26),
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
                                      : (themeService.isDarkMode
                                            ? Colors.white54
                                            : Colors.black54),
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
                        // Scroll to Bottom Arrow
                        if (_showScrollToBottom) ...[
                          const SizedBox(width: 178),
                          GestureDetector(
                            onTap: _scrollToBottom,
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: themeService.isDarkMode
                                    ? Colors.white10
                                    : Colors.black.withOpacity(0.05),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: themeService.isDarkMode
                                      ? Colors.white24
                                      : Colors.black26,
                                  width: 1,
                                ),
                              ),
                              child: FaIcon(
                                FontAwesomeIcons.arrowDown,
                                size: 14,
                                color: themeService.isDarkMode
                                    ? Colors.white70
                                    : Colors.black54,
                              ),
                            ),
                          ),
                        ],
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
                                        color: themeService.isDarkMode
                                            ? Colors.white
                                            : Colors.black87,
                                        // Aktif modlar için özel renk
                                        decorationColor:
                                            _isImageGenerationMode ||
                                                _isWebSearchMode ||
                                                _isCanvasMode ||
                                                _isThinkingMode
                                            ? Colors.blue
                                            : (themeService.isDarkMode
                                                  ? Colors.white
                                                  : Colors.black87),
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
                                                      _currentChat!
                                                          .messages
                                                          .isEmpty
                                                  ? 'ForeSee\'e bir şey sor...'
                                                  : 'Mesajınızı yazın...'),
                                        hintStyle: TextStyle(
                                          color: themeService.isDarkMode
                                              ? Colors.white54
                                              : Colors.black87,
                                        ),
                                        border: InputBorder.none,
                                        contentPadding:
                                            const EdgeInsets.symmetric(
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
                                          color: themeService.isDarkMode
                                              ? Colors.white70
                                              : Colors.black87,
                                          onPressed: _pickImage,
                                        ),
                                      Expanded(
                                        child: SizedBox(
                                          height: 40,
                                          child: ListView(
                                            scrollDirection: Axis.horizontal,
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 4,
                                            ),
                                            children: [
                                              // PDF Chips
                                              ...List.generate(_pickedPdfFiles.length, (
                                                index,
                                              ) {
                                                final pdfFile =
                                                    _pickedPdfFiles[index];
                                                final pdfName = pdfFile.path
                                                    .split(
                                                      Platform.pathSeparator,
                                                    )
                                                    .last;
                                                return Padding(
                                                  padding:
                                                      const EdgeInsets.only(
                                                        right: 8.0,
                                                      ),
                                                  child: Container(
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 10,
                                                          vertical: 6,
                                                        ),
                                                    decoration: BoxDecoration(
                                                      color:
                                                          themeService
                                                              .isDarkMode
                                                          ? Colors.red
                                                                .withOpacity(
                                                                  0.1,
                                                                )
                                                          : Colors.red
                                                                .withOpacity(
                                                                  0.05,
                                                                ),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            20,
                                                          ),
                                                      border: Border.all(
                                                        color:
                                                            themeService
                                                                .isDarkMode
                                                            ? Colors.red
                                                                  .withOpacity(
                                                                    0.3,
                                                                  )
                                                            : Colors.red
                                                                  .withOpacity(
                                                                    0.2,
                                                                  ),
                                                      ),
                                                    ),
                                                    child: Row(
                                                      mainAxisSize:
                                                          MainAxisSize.min,
                                                      children: [
                                                        const Icon(
                                                          Icons.picture_as_pdf,
                                                          color: Colors.red,
                                                          size: 14,
                                                        ),
                                                        const SizedBox(
                                                          width: 6,
                                                        ),
                                                        ConstrainedBox(
                                                          constraints:
                                                              const BoxConstraints(
                                                                maxWidth: 400,
                                                              ),
                                                          child: Text(
                                                            pdfName,
                                                            style: TextStyle(
                                                              color:
                                                                  themeService
                                                                      .isDarkMode
                                                                  ? Colors.white
                                                                  : Colors
                                                                        .black87,
                                                              fontSize: 12,
                                                            ),
                                                            maxLines: 1,
                                                            overflow:
                                                                TextOverflow
                                                                    .ellipsis,
                                                          ),
                                                        ),
                                                        const SizedBox(
                                                          width: 4,
                                                        ),
                                                        GestureDetector(
                                                          onTap: () {
                                                            setState(() {
                                                              _pickedPdfFiles
                                                                  .removeAt(
                                                                    index,
                                                                  );
                                                              _pickedPdfBase64List
                                                                  .removeAt(
                                                                    index,
                                                                  );
                                                            });
                                                          },
                                                          child: Icon(
                                                            Icons.close,
                                                            color:
                                                                themeService
                                                                    .isDarkMode
                                                                ? Colors.white54
                                                                : Colors
                                                                      .black54,
                                                            size: 14,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                );
                                              }),

                                              // Image Chips
                                              ...List.generate(_selectedImages.length, (
                                                index,
                                              ) {
                                                final file =
                                                    _selectedImages[index];
                                                return Padding(
                                                  padding:
                                                      const EdgeInsets.only(
                                                        right: 7.0,
                                                      ),
                                                  child: GestureDetector(
                                                    onTap: () =>
                                                        _previewSelectedImage(
                                                          index,
                                                        ),
                                                    child: Stack(
                                                      children: [
                                                        Hero(
                                                          tag:
                                                              'selected_input_image_$index',
                                                          child: ClipRRect(
                                                            borderRadius:
                                                                BorderRadius.circular(
                                                                  8,
                                                                ),
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
                                                                    .removeAt(
                                                                      index,
                                                                    );
                                                              });
                                                            },
                                                            child: Container(
                                                              width: 16,
                                                              height: 16,
                                                              decoration: BoxDecoration(
                                                                color:
                                                                    themeService
                                                                        .isDarkMode
                                                                    ? Colors
                                                                          .black54
                                                                    : Colors
                                                                          .black26,
                                                                shape: BoxShape
                                                                    .circle,
                                                              ),
                                                              child: Icon(
                                                                Icons.close,
                                                                color:
                                                                    themeService
                                                                        .isDarkMode
                                                                    ? Colors
                                                                          .white
                                                                    : Colors
                                                                          .black87,
                                                                size: 12,
                                                              ),
                                                            ),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                );
                                              }),
                                            ],
                                          ),
                                        ),
                                      ),
                                      // Hybrid Mic button
                                      GestureDetector(
                                        onTap: () {
                                          if (_isRecordingVoice) {
                                            _stopVoiceRecording();
                                          } else {
                                            _startVoiceRecording(
                                              isManual: false,
                                            ); // Auto mode
                                          }
                                        },
                                        onLongPressStart: (_) {
                                          if (!_isRecordingVoice) {
                                            _startVoiceRecording(
                                              isManual: true,
                                            ); // Manual mode
                                          }
                                        },
                                        onLongPressEnd: (_) {
                                          if (_isRecordingVoice &&
                                              _isManualRecording) {
                                            _stopVoiceRecording();
                                          }
                                        },
                                        child: Padding(
                                          padding: const EdgeInsets.only(
                                            left: 8,
                                            right: 12,
                                            top: 8,
                                            bottom: 8,
                                          ),
                                          child: FaIcon(
                                            FontAwesomeIcons.microphone,
                                            size: 16,
                                            color: _isRecordingVoice
                                                ? Colors.redAccent
                                                : (themeService.isDarkMode
                                                      ? Colors.white70
                                                      : Colors.black87),
                                          ),
                                        ),
                                      ),
                                      // Send button
                                      Container(
                                        width: 40,
                                        height: 40,
                                        decoration: BoxDecoration(
                                          color: _isLoading
                                              ? Colors.red
                                              : (_canSendMessage()
                                                    ? (themeService.isDarkMode
                                                          ? Colors.white
                                                          : Colors.black)
                                                    : (themeService.isDarkMode
                                                          ? Colors.white
                                                                .withOpacity(
                                                                  0.3,
                                                                )
                                                          : Colors.black
                                                                .withOpacity(
                                                                  0.3,
                                                                ))),
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
                                                      ? (themeService.isDarkMode
                                                            ? Colors.black
                                                            : Colors.white)
                                                      : (themeService.isDarkMode
                                                            ? Colors.black
                                                                  .withOpacity(
                                                                    0.5,
                                                                  )
                                                            : Colors.white
                                                                  .withOpacity(
                                                                    0.5,
                                                                  )),
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
                color: isActive
                    ? Colors.blue
                    : (themeService.isDarkMode
                          ? const Color(0xFF2A2A2A)
                          : Colors.grey.shade300),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: FaIcon(
                  icon,
                  color: isActive
                      ? Colors.white
                      : (themeService.isDarkMode
                            ? Colors.white
                            : Colors.black87),
                  size: 16,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                color: isActive
                    ? Colors.blue
                    : (themeService.isDarkMode ? Colors.white : Colors.black87),
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
    _isRememberPastChatsEnabled = await _storageService
        .getIsRememberPastChatsEnabled();
    _isAutoTitleEnabled = await _storageService.getIsAutoTitleEnabled();
    _notificationsEnabled = await _storageService.getNotificationsEnabled();
    _fontSizeIndex = await _storageService.getFontSizeIndex();
    _fontFamily = await _storageService.getFontFamily();
    _isGmailAiAlwaysAllowed = await _storageService.getIsGmailAiAlwaysAllowed();
    _isGithubAiAlwaysAllowed = await _storageService
        .getIsGithubAiAlwaysAllowed();
    _isOutlookAiAlwaysAllowed = await _storageService
        .getIsOutlookAiAlwaysAllowed();
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
        // Seçim yapıldıktan sonra alternatifleri silmiyoruz ki oklarla değiştirilebilsin
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
                      : (isAI
                                ? AssetImage(
                                    themeService.getLogoPath('logo3.png'),
                                  )
                                : null)
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
                  backgroundColor: Theme.of(context).dialogBackgroundColor,
                  title: Text(
                    'ForeSee Online',
                    style: TextStyle(
                      color: Theme.of(context).textTheme.titleLarge?.color,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Her grupta gözükcek olan sana özel kullanıcı adını belirle',
                        style: TextStyle(
                          color: Theme.of(
                            context,
                          ).textTheme.bodyMedium?.color?.withOpacity(0.7),
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: controller,
                        style: TextStyle(
                          color: Theme.of(context).textTheme.bodyMedium?.color,
                          fontWeight: FontWeight.w500,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Kullanıcı Adı',
                          hintStyle: TextStyle(
                            color: Theme.of(
                              context,
                            ).textTheme.bodySmall?.color?.withOpacity(0.4),
                          ),
                          errorText: errorText,
                          enabledBorder: UnderlineInputBorder(
                            borderSide: BorderSide(
                              color: Theme.of(context).dividerColor,
                            ),
                          ),
                          focusedBorder: UnderlineInputBorder(
                            borderSide: BorderSide(
                              color: Theme.of(context).primaryColor,
                            ),
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
                          color: Theme.of(
                            context,
                          ).textTheme.bodySmall?.color?.withOpacity(0.7),
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
        backgroundColor: themeService.isDarkMode
            ? const Color(0xFF1A1A1A)
            : Theme.of(context).colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Grup Adı Belirle',
          style: TextStyle(
            color: themeService.isDarkMode ? Colors.white : Colors.black87,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Harika bir grup adı ile başla.',
              style: TextStyle(
                color: themeService.isDarkMode
                    ? Colors.white70
                    : Colors.black54,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: nameController,
              autofocus: true,
              style: TextStyle(
                color: themeService.isDarkMode ? Colors.white : Colors.black87,
              ),
              decoration: InputDecoration(
                hintText: 'Örn: Gelecek Planları',
                hintStyle: TextStyle(
                  color: themeService.isDarkMode
                      ? Colors.white24
                      : Colors.black38,
                ),
                filled: true,
                fillColor: themeService.isDarkMode
                    ? Colors.white.withOpacity(0.05)
                    : Colors.grey[100],
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
              style: TextStyle(
                color: themeService.isDarkMode
                    ? Colors.white54
                    : Colors.black54,
              ),
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
        backgroundColor: themeService.isDarkMode
            ? const Color(0xFF1E1E1E)
            : Theme.of(context).colorScheme.surface,
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
          style: TextStyle(
            color: themeService.isDarkMode ? Colors.white70 : Colors.black54,
            fontSize: 13,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'İptal',
              style: TextStyle(
                color: themeService.isDarkMode
                    ? Colors.white54
                    : Colors.black54,
              ),
            ),
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
        backgroundColor: themeService.isDarkMode
            ? const Color(0xFF1E1E1E)
            : Theme.of(context).colorScheme.surface,
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
                color: themeService.isDarkMode
                    ? Colors.black38
                    : Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: themeService.isDarkMode
                      ? Colors.white10
                      : Colors.grey[300]!,
                ),
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
                      color: themeService.isDarkMode
                          ? Colors.white70
                          : Colors.black54,
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
                      color: themeService.isDarkMode
                          ? Colors.white70
                          : Colors.black54,
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
              style: TextStyle(
                color: themeService.isDarkMode ? Colors.white : Colors.black87,
              ),
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

  void openChatFromDeepLink(String chatId) {
    if (!mounted) return;
    final chatIndex = _chats.indexWhere((c) => c.id == chatId);
    if (chatIndex != -1) {
      _handleChatSelected(_chats[chatIndex]);
    } else {
      GreyNotification.show(context, 'Sohbet bulunamadı veya silinmiş');
    }
  }

  void focusInputFromQuickAction() {
    if (!mounted) return;
    _messageFocusNode.requestFocus();
  }

  void _showAttachmentOptions() {
    if (!mounted) return;
    _pickImage();
  }

  void openCameraFromQuickAction() {
    if (!mounted) return;
    _pickFromCamera();
  }

  void handleQuickAiAction(String action) {
    if (!mounted) return;
    // Inputa odaklan ve klavyeyi aç
    focusInputFromQuickAction();

    if (action == 'attach') {
      // Bir gecikme ekle ki input odağı ve klavye çakışmasın
      Future.delayed(const Duration(milliseconds: 300), () {
        _showAttachmentOptions();
      });
    }
  }

  void openStatsFromDeepLink() {
    if (!mounted) return;
    _openSettings();
  }

  // Check if user has sent at least one message in the chat
  bool _hasUserSentMessage(Chat chat) {
    return chat.messages.any((message) => message.isUser);
  }

  Future<Map<String, dynamic>?> _handleIncomingToolCall(
    String name,
    Map<String, dynamic> args,
    String toolCallId,
    String? aiMessageId,
    String chatId,
    bool isFinal,
  ) async {
    if (!mounted) return null;

    // 1. Durum güncellemesi: "Loading" göster (Sadece isFinal false ise UI için)
    if (!isFinal) {
      _loadingMessage = 'Aranıyor...';
      String loadingTitle = 'Hazırlanıyor...';
      if (name == 'create_gmail_draft') {
        final to = args['to'] ?? 'birine';
        loadingTitle = 'Mail taslağı hazırlanıyor ($to)...';
      } else if (name == 'read_gmail_inbox') {
        final q = args['query'] ?? 'tümü';
        loadingTitle = 'E-postalar taranıyor ($q)...';
      } else if (name == 'list_github_repos') {
        loadingTitle = 'GitHub depoları listeleniyor...';
      } else if (name == 'read_github_repo') {
        final repo = args['repo'] ?? 'repo';
        final path = args['path'] ?? '';
        loadingTitle =
            '$repo analiz ediliyor${path.isNotEmpty ? ' / $path' : ''}...';
      }

      _updateMessageToolState(aiMessageId, chatId, {
        'toolCallId': toolCallId,
        'toolCallName': name,
        'status': 'loading',
        'title': loadingTitle,
        'showApprove': false,
      });
      return null;
    }

    // 2. Aracı çalıştır
    try {
      Map<String, dynamic> result = {};
      Map<String, dynamic> toolOutput = {}; // AI'a gidecek ham sonuç

      if (name == 'create_gmail_draft') {
        final to = args['to'] ?? '';
        final subject = args['subject'] ?? 'Konu Yok';
        result = await _gmailService.createDraft(
          to: to,
          subject: subject,
          body: args['body'] ?? '',
        );
        toolOutput = result;
        result['toolCallName'] = name;
        result['args'] = args;
        result['showApprove'] = true;
        result['status'] = 'done';
        result['title'] = 'Taslak: $subject';
        result['subtitle'] = 'Alıcı: $to';
      } else if (name == 'read_github_repo') {
        final owner = args['owner'] ?? '';
        final repo = args['repo'] ?? '';
        final path = args['path'] ?? '';
        result = await _githubService.getRepoContent(
          owner: owner,
          repo: repo,
          path: path,
        );
        toolOutput = result;
        result['toolCallName'] = name;
        result['showApprove'] = false; // GitHub okuma için onaya gerek yok
        result['status'] = 'done';
        result['title'] = '$owner/$repo Analiz Edildi';
        if (path.isNotEmpty) {
          result['subtitle'] = 'Dosya: $path';
        }
      } else if (name == 'read_gmail_inbox') {
        final query = args['query'] as String?; // Optional now
        final pageToken = args['pageToken'] as String?;
        final inboxResult = await _gmailService.readInbox(
          query: query,
          maxResults: args['maxResults'] ?? 5,
          pageToken: pageToken,
        );
        final messages = inboxResult['messages'] as List<Map<String, dynamic>>;
        final nextPageToken = inboxResult['nextPageToken'];

        toolOutput = {'messages': messages, 'nextPageToken': nextPageToken};
        result = {
          'toolCallName': name,
          'status': 'done',
          'title': query != null && query.isNotEmpty
              ? 'Gmail: "$query"'
              : 'Gmail Gelen Kutusu',
          'subtitle':
              '${messages.length} mail bulundu${nextPageToken != null ? ' (Devamı var)' : ''}',
          'showApprove': false,
        };
      } else if (name == 'search_gmail') {
        final query = args['query'] as String;
        final pageToken = args['pageToken'] as String?;
        final searchResult = await _gmailService.searchEmails(
          query: query,
          maxResults: args['maxResults'] ?? 5,
          pageToken: pageToken,
        );
        final messages = searchResult['messages'] as List<Map<String, dynamic>>;
        final nextPageToken = searchResult['nextPageToken'];

        toolOutput = {'messages': messages, 'nextPageToken': nextPageToken};
        result = {
          'toolCallName': name,
          'status': 'done',
          'title': 'Gmail Arama: "$query"',
          'subtitle':
              '${messages.length} sonuç${nextPageToken != null ? ' (Devamı var)' : ''}',
          'showApprove': false,
        };
      } else if (name == 'list_github_repos' ||
          name == 'get_github_user_repos') {
        final username = args['username'] as String?;
        final page = args['page'] as int? ?? 1;
        final perPage = args['perPage'] as int? ?? 10;

        final repos = await _githubService.getUserRepos(
          username: username,
          page: page,
          perPage: perPage,
        );
        toolOutput = {'repositories': repos};
        result = {
          'toolCallName': name,
          'status': 'done',
          'title': username != null
              ? '$username Repoları'
              : 'Sizin Repolarınız',
          'subtitle': '${repos.length} repo listelendi',
          'showApprove': false,
        };
      } else if (name == 'get_github_starred_repos') {
        final username = args['username'] as String?;
        final page = args['page'] as int? ?? 1;

        final repos = await _githubService.getStarredRepos(
          username: username,
          page: page,
        );
        toolOutput = {'repositories': repos};
        result = {
          'toolCallName': name,
          'status': 'done',
          'title': username != null
              ? '$username Yıldızladıkları'
              : 'Yıldızlı Repolarınız',
          'subtitle': '${repos.length} repo listelendi',
          'showApprove': false,
        };
      } else if (name == 'star_github_repo') {
        final owner = args['owner'] as String;
        final repo = args['repo'] as String;
        await _githubService.starRepo(owner, repo);

        toolOutput = {'status': 'success', 'message': 'Repo starred'};
        result = {
          'toolCallName': name,
          'status': 'done',
          'title': 'Repo Yıldızlandı',
          'subtitle': '$owner/$repo',
          'showApprove': false,
        };
      } else if (name == 'unstar_github_repo') {
        final owner = args['owner'] as String;
        final repo = args['repo'] as String;
        await _githubService.unstarRepo(owner, repo);

        toolOutput = {'status': 'success', 'message': 'Repo unstarred'};
        result = {
          'toolCallName': name,
          'status': 'done',
          'title': 'Yıldız Kaldırıldı',
          'subtitle': '$owner/$repo',
          'showApprove': false,
        };
      } else if (name == 'read_outlook_inbox') {
        final query = args['query'] as String?;
        final maxResults = args['maxResults'] as int? ?? 5;

        final resultData = await OutlookService.instance.readInbox(
          query: query,
          maxResults: maxResults,
        );
        final messages = resultData['messages'] as List;

        toolOutput = {'messages': messages};
        result = {
          'toolCallName': name,
          'status': 'done',
          'title': query != null ? 'Outlook: "$query"' : 'Outlook Gelen Kutusu',
          'subtitle': '${messages.length} mail bulundu',
          'showApprove': false,
        };
      } else if (name == 'send_outlook_email') {
        final to = args['to'] as String;
        final subject = args['subject'] as String;
        final body = args['body'] as String;

        await OutlookService.instance.sendEmail(
          to: to,
          subject: subject,
          body: body,
        );

        toolOutput = {'status': 'success', 'message': 'Email sent'};
        result = {
          'toolCallName': name,
          'status': 'done',
          'title': 'Outlook E-posta Gönderildi',
          'subtitle': 'Kime: $to',
          'showApprove': false,
        };
      }

      if (aiMessageId != null) {
        _updateMessageToolState(aiMessageId, chatId, result);
      }
      return toolOutput;
    } catch (e) {
      if (aiMessageId != null) {
        _updateMessageToolState(aiMessageId, chatId, {
          'status': 'error',
          'title': 'Hata oluştu',
          'subtitle': e.toString(),
        });
      }
      return {'error': e.toString()};
    }
  }

  void _updateMessageToolState(
    String? msgId,
    String chatId,
    Map<String, dynamic> toolData,
  ) {
    if (msgId == null) return;
    setState(() {
      final chatIndex = _chats.indexWhere((c) => c.id == chatId);
      if (chatIndex != -1) {
        final messages = [..._chats[chatIndex].messages];
        final idx = messages.indexWhere((m) => m.id == msgId);
        if (idx != -1) {
          final currentMetadata = Map<String, dynamic>.from(
            messages[idx].metadata ?? {},
          );
          currentMetadata['toolCall'] = toolData;
          messages[idx] = messages[idx].copyWith(metadata: currentMetadata);
          _chats[chatIndex] = _chats[chatIndex].copyWith(messages: messages);
          if (_currentChat?.id == chatId) _currentChat = _chats[chatIndex];
        }
      }
    });
    _storageService.saveChats(_chats);
  }

  void _detectControlTagsStreaming(String text) {
    // 1. Artifact Detection
    if (text.contains('[ARTIFACT')) {
      // Find the latest artifact block
      final lastTagIndex = text.lastIndexOf('[ARTIFACT');
      final closingTagIndex = text.lastIndexOf('[/ARTIFACT]');

      if (lastTagIndex != -1) {
        final tagEndBracket = text.indexOf(']', lastTagIndex);
        if (tagEndBracket != -1) {
          final tagContent = text.substring(lastTagIndex, tagEndBracket + 1);
          final contentStart = tagEndBracket + 1;

          String content;
          bool isComplete = false;
          if (closingTagIndex != -1 && closingTagIndex > lastTagIndex) {
            content = text.substring(contentStart, closingTagIndex).trim();
            isComplete = true;
          } else {
            // Still streaming, take everything after tag
            content = text.substring(contentStart).trim();
          }

          // Extract title and lang from tagContent
          final titleMatch = RegExp(r'title="([^"]*)"').firstMatch(tagContent);
          final langMatch = RegExp(r'lang="([^"]*)"').firstMatch(tagContent);

          final title = titleMatch?.group(1) ?? 'Artifact';
          final lang = langMatch?.group(1) ?? 'text';

          if (content != _artifactContent ||
              !_isArtifactsPanelOpen ||
              isComplete) {
            setState(() {
              _artifactContent = content;
              _artifactTitle = title;
              _artifactLanguage = lang;
              _isArtifactsPanelOpen = true;
            });
          }
        }
      }
    }

    final imgenRegex = RegExp(
      r'\[İ?MGEN\]\s*:?\s*([^\]\n]+)',
      caseSensitive: false,
    );

    // 3. Manual Reasoning Detection (New)
    final reasonRegex = RegExp(
      r'\[REASON\]\s*:?\s*([^\]\n]+)',
      caseSensitive: false,
    );

    final reasonMatch = reasonRegex.firstMatch(text);
    if (reasonMatch != null) {
      final content = reasonMatch.group(1)?.trim() ?? '';
      if (content.isNotEmpty) {
        final tagId = 'reason_$content';
        if (!_handledControlTags.contains(tagId)) {
          _handledControlTags.add(tagId);
          setState(() {
            _agentThinking += (_agentThinking.isEmpty ? '' : '\n') + content;
            if (_loadingMessage == 'Düşünüyor...') {
              _loadingMessage = 'Derin düşünüyor...';
            }
          });
        }
      }
    }

    final imgenMatch = imgenRegex.firstMatch(text);
    if (imgenMatch != null) {
      final prompt = imgenMatch.group(1)?.trim() ?? '';
      if (prompt.isNotEmpty) {
        final tagId = 'imgen_$prompt';
        if (!_handledControlTags.contains(tagId)) {
          _handledControlTags.add(tagId);
          if (mounted) {
            setState(() {
              _isGeneratingImage = true;
              _loadingMessage = 'Görsel oluşturuluyor...';
              // Metin olarak da göster ki skeleton tetiklensin
              _currentTypingText = 'Görsel oluşturuluyor...';
            });
          }
          _handleImgenTrigger(prompt);
        }
      }
    }
  }

  Future<void> _sendBackgroundToolRequest({required String instruction}) async {
    if (_currentChat == null) return;
    final targetChatId = _currentChat!.id;

    final history = _currentChat!.messages
        .map(
          (m) => {
            'role': m.isUser ? 'user' : 'assistant',
            'content': m.content,
          },
        )
        .toList();

    try {
      await _openRouterService.sendMessageWithHistoryStream(
        history, // Position 1: History
        instruction, // Position 2: New instruction
        onToken: (text) {
          // Do nothing, we don't want to show this in UI
        },
        shouldStop: () => false,
        onToolCall: (name, args, id, isFinal) async {
          // Pass null for aiMessageId to signal background mode
          return await _handleIncomingToolCall(
            name,
            args,
            id,
            null, // This is the key: null aiMessageId
            targetChatId,
            isFinal,
          );
        },
      );
    } catch (e) {
      debugPrint("Background tool request error: $e");
    }
  }
}
