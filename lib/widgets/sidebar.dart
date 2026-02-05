import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import '../models/chat.dart';
import '../models/user_profile.dart';
import '../services/firestore_service.dart';
import '../services/theme_service.dart';
import 'grey_notification.dart';
import '../models/chat_folder.dart';
import '../main.dart';
import 'user_profile_panel.dart';

class Sidebar extends StatefulWidget {
  final List<Chat> chats;
  final Chat? currentChat;
  final UserProfile userProfile;
  final Function(Chat) onChatSelected;
  final VoidCallback onNewChat;
  final Function(UserProfile) onProfileUpdated;
  final Function(Chat) onChatDelete;
  final Function(Chat) onChatEdit;
  final VoidCallback? onSettingsPressed;
  final VoidCallback? onSearchChats;
  final bool isMultiDeleteMode;
  final Set<String> selectedChatIdsForDelete;
  final VoidCallback onMultiDeletePressed;
  final Function(Chat) onChatToggleSelection;
  final VoidCallback? onMultiDeleteCancel;
  final VoidCallback? onSignOut;
  final VoidCallback? onOpenTrash;
  final Function(Chat)? onChatTogglePin;
  final VoidCallback? onImportChat;
  final Function(Chat)? onExportPdf;
  final Function(Chat)? onExportFs;
  final Function(Chat)? onExportWord;
  // Folder Callbacks
  final List<ChatFolder> folders;
  final Function(Chat, String?) onChatMoveToFolder; // null = move to root
  final VoidCallback onCreateFolder;
  final Function(ChatFolder) onEditFolder;
  final Function(ChatFolder) onDeleteFolder;
  final Function(ChatFolder) onToggleFolder;
  final Function(ChatFolder)? onToggleFolderPin;
  final Function(Chat)? onOpenChatSummaries;
  final Function(Chat)? onChatLock;

  const Sidebar({
    super.key,
    required this.chats,
    required this.currentChat,
    required this.userProfile,
    required this.onChatSelected,
    required this.onNewChat,
    required this.onProfileUpdated,
    required this.onChatDelete,
    required this.onChatEdit,
    this.onSettingsPressed,
    this.onSearchChats,
    required this.isMultiDeleteMode,
    required this.selectedChatIdsForDelete,
    required this.onMultiDeletePressed,
    required this.onChatToggleSelection,
    this.onMultiDeleteCancel,
    this.onSignOut,
    this.onOpenTrash,
    this.onChatTogglePin,
    this.onImportChat,
    this.onExportPdf,
    this.onExportFs,
    this.onExportWord,
    this.folders = const [],
    required this.onChatMoveToFolder,
    required this.onCreateFolder,
    required this.onEditFolder,
    required this.onDeleteFolder,
    required this.onToggleFolder,
    this.onToggleFolderPin,
    this.onOpenChatSummaries,
    this.onChatLock,
  });

  @override
  State<Sidebar> createState() => _SidebarState();
}

class _SidebarState extends State<Sidebar> {
  final ScrollController _scrollController = ScrollController();
  Timer? _scrollTimer;

  @override
  void dispose() {
    _scrollTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  void _startAutoScroll(double speed) {
    _scrollTimer?.cancel();
    _scrollTimer = Timer.periodic(const Duration(milliseconds: 16), (timer) {
      if (!_scrollController.hasClients) return;
      // Precision scroll: Adjust speed based on how close finger is to edge if needed,
      // but here we just use the provided speed. Reducing refresh rate or increasing step.
      final double newOffset =
          _scrollController.offset +
          (speed * 1.5); // Slightly faster/more sensitive
      if (newOffset < 0) {
        _scrollController.jumpTo(0);
        _scrollTimer?.cancel();
      } else if (newOffset > _scrollController.position.maxScrollExtent) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
        _scrollTimer?.cancel();
      } else {
        _scrollController.jumpTo(newOffset);
      }
    });
  }

  void _stopAutoScroll() {
    _scrollTimer?.cancel();
    _scrollTimer = null;
  }

  String _getUsageDuration() {
    final now = DateTime.now();
    final duration = now.difference(widget.userProfile.createdAt);

    if (duration.inDays >= 365) {
      final years = (duration.inDays / 365).floor();
      return '$years Yıl';
    } else if (duration.inDays >= 30) {
      final months = (duration.inDays / 30).floor();
      return '$months Ay';
    } else if (duration.inDays > 0) {
      return '${duration.inDays} Gün';
    } else {
      return 'Bugün';
    }
  }

  Future<void> _editProfile(BuildContext context) async {
    final theme = Theme.of(context);
    final nameController = TextEditingController(text: widget.userProfile.name);
    String? selectedImagePath = widget.userProfile.profileImagePath;

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: theme.dialogBackgroundColor,
        title: Text(
          'Profili Düzenle',
          style: TextStyle(color: theme.textTheme.titleLarge?.color),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              style: TextStyle(color: theme.textTheme.bodyMedium?.color),
              decoration: InputDecoration(
                labelText: 'İsim',
                labelStyle: TextStyle(
                  color: theme.textTheme.bodySmall?.color?.withOpacity(0.6),
                ),
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: theme.dividerColor),
                ),
                focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: theme.primaryColor),
                ),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () async {
                final picker = ImagePicker();
                final pickedFile = await picker.pickImage(
                  source: ImageSource.gallery,
                );
                if (pickedFile != null) {
                  selectedImagePath = pickedFile.path;
                }
              },
              icon: const FaIcon(FontAwesomeIcons.image, size: 16),
              label: const Text('Profil Fotoğrafı Seç'),
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.surfaceVariant,
                foregroundColor: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'İptal',
              style: TextStyle(
                color: theme.textTheme.bodySmall?.color?.withOpacity(0.6),
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              final updatedProfile = widget.userProfile.copyWith(
                name: nameController.text.trim(),
                profileImagePath: selectedImagePath,
              );
              widget.onProfileUpdated(updatedProfile);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.brightness == Brightness.dark
                  ? Colors.white
                  : Colors.black,
              foregroundColor: theme.brightness == Brightness.dark
                  ? Colors.black
                  : Colors.white,
            ),
            child: const Text('Kaydet'),
          ),
        ],
      ),
    );
  }

  Future<void> _showLogoutConfirmation(BuildContext context) async {
    final theme = Theme.of(context);

    final isDark = theme.brightness == Brightness.dark;

    // First Dialog: Confirmation
    final proceed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: theme.dialogBackgroundColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text(
          'Çıkış Yap',
          style: TextStyle(color: Colors.redAccent),
        ),
        content: Text(
          'Çıkış yapmak istediğinize emin misiniz? Oturumunuz kapatılacak.',
          style: TextStyle(color: isDark ? Colors.white70 : Colors.black87),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'İptal',
              style: TextStyle(color: isDark ? Colors.white60 : Colors.black54),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Devam Et'),
          ),
        ],
      ),
    );

    if (proceed != true) return;

    // Second Dialog: Options
    if (!context.mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: theme.dialogBackgroundColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(
          'Uygulama Kontrolü',
          style: TextStyle(color: isDark ? Colors.white : Colors.black87),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Oturum kapatıldı. Ne yapmak istersiniz?',
              style: TextStyle(color: isDark ? Colors.white70 : Colors.black87),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => SystemNavigator.pop(),
                icon: const Icon(Icons.close),
                label: const Text('Uygulamayı Kapat'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey[800],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  // Re-sign out to trigger main app state change
                  widget.onSignOut?.call();
                  Navigator.pop(context); // Close dialog
                  RestartWidget.restartApp(context); // Trigger full app restart
                },
                icon: const Icon(Icons.refresh),
                label: const Text('Yeniden Başlat'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Drawer(
      width: 340.0,
      backgroundColor: theme.brightness == Brightness.dark
          ? const Color(0xFF020202)
          : Colors.white,
      child: SafeArea(
        child: Column(
          children: [
            _buildUserPanel(context),
            const SizedBox(height: 8),
            _buildActionButtons(context),
            const SizedBox(height: 16),
            _buildSettingsSection(context),
            const SizedBox(height: 16),
            _buildChatsSection(context),
            const SizedBox(height: 8),
            _buildFooter(context),
          ],
        ),
      ),
    );
  }

  Widget _buildUserPanel(BuildContext context) {
    return UserProfilePanel(
      userProfile: widget.userProfile,
      onEditPressed: () => _editProfile(context),
      showEditButton: true,
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    final theme = Theme.of(context);
    if (widget.isMultiDeleteMode) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: widget.onMultiDeletePressed,
                icon: const Icon(
                  Icons.delete_forever,
                  color: Colors.white,
                  size: 18,
                ),
                label: Text(
                  'Sil (${widget.selectedChatIdsForDelete.length})',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
              ),
            ),
            const SizedBox(width: 8),
            TextButton(
              onPressed: widget.onMultiDeleteCancel,
              child: Text(
                'İptal',
                style: TextStyle(
                  color: theme.textTheme.bodySmall?.color?.withOpacity(0.6),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: widget.onNewChat,
              icon: const Icon(Icons.add, size: 20),
              label: const Text(
                'Yeni Sohbet',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.brightness == Brightness.dark
                    ? Colors.white
                    : Colors.black,
                foregroundColor: theme.brightness == Brightness.dark
                    ? Colors.black
                    : Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              if (widget.onSearchChats != null)
                Expanded(
                  child: _buildHeaderIconButton(
                    context,
                    icon: Icons.search,
                    label: 'Ara',
                    onTap: widget.onSearchChats!,
                  ),
                ),
              if (widget.onSearchChats != null && widget.onImportChat != null)
                const SizedBox(width: 8),
              if (widget.onImportChat != null)
                Expanded(
                  child: _buildHeaderIconButton(
                    context,
                    icon: Icons.upload_file,
                    label: 'İçe Aktar',
                    onTap: widget.onImportChat!,
                  ),
                ),
              if (widget.onOpenTrash != null) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: GestureDetector(
                    onLongPress: () {
                      if (widget.onMultiDeletePressed != null) {
                        widget.onMultiDeletePressed();
                        GreyNotification.show(
                          context,
                          'Çoklu silme modu aktif',
                        );
                      }
                    },
                    child: _buildHeaderIconButton(
                      context,
                      icon: widget.isMultiDeleteMode
                          ? Icons.close
                          : Icons.checklist_rtl,
                      label: widget.isMultiDeleteMode ? 'İptal' : 'Çoklu Silme',
                      onTap: () {
                        if (widget.isMultiDeleteMode) {
                          widget.onMultiDeletePressed?.call();
                        } else {
                          widget.onMultiDeletePressed?.call();
                        }
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _buildHeaderIconButton(
                  context,
                  icon: Icons.delete_outline,
                  label: '',
                  onTap: widget.onOpenTrash!,
                  isCompact: true,
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderIconButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isCompact = false,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (isCompact) {
      return Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF151515) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: theme.dividerColor.withOpacity(0.1)),
        ),
        child: IconButton(
          onPressed: onTap,
          icon: Icon(icon, size: 18),
          color: theme.textTheme.bodySmall?.color?.withOpacity(0.7),
          constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
        ),
      );
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF151515) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: theme.dividerColor.withOpacity(0.1)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: theme.textTheme.bodySmall?.color?.withOpacity(0.7),
            ),
            if (label.isNotEmpty) ...[
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(
                    color: theme.textTheme.bodySmall?.color?.withOpacity(0.8),
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsSection(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: theme.brightness == Brightness.dark
              ? const Color(0xFF1A1A1A)
              : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: theme.dividerColor.withOpacity(0.1)),
          boxShadow: theme.brightness == Brightness.light
              ? [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [],
        ),
        child: ListTile(
          leading: FaIcon(
            FontAwesomeIcons.gear,
            size: 18,
            color: theme.textTheme.bodySmall?.color?.withOpacity(0.7),
          ),
          title: Text(
            'Ayarlar',
            style: TextStyle(
              color: theme.textTheme.bodyLarge?.color,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          subtitle: Text(
            'Bellek ve Prompt Ayarları',
            style: TextStyle(
              color: theme.textTheme.bodySmall?.color?.withOpacity(0.6),
              fontSize: 12,
            ),
          ),
          trailing: FaIcon(
            FontAwesomeIcons.chevronRight,
            size: 14,
            color: theme.textTheme.bodySmall?.color?.withOpacity(0.6),
          ),
          onTap: widget.onSettingsPressed,
        ),
      ),
    );
  }

  Widget _buildChatsSection(BuildContext context) {
    final theme = Theme.of(context);
    // 1. Filter deleted
    final visibleChats = widget.chats
        .where((c) => c.deletedAt == null)
        .toList();

    // 2. Sort by updated at (Global descending sort for consistent ordering inside buckets)
    visibleChats.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

    // 3. Separate Pinned
    final pinnedChats = visibleChats.where((c) => c.isPinned).toList();
    final nonPinnedChats = visibleChats.where((c) => !c.isPinned).toList();

    // 4. Bucketize Non-Pinned by Folder
    final Map<String, List<Chat>> folderChats = {};
    final List<Chat> groupChats = [];
    final List<Chat> uncategorizedChats = [];

    for (var chat in nonPinnedChats) {
      if (chat.isGroup) {
        groupChats.add(chat);
      } else if (chat.folderId != null) {
        // Verify folder exists
        if (widget.folders.any((f) => f.id == chat.folderId)) {
          folderChats.putIfAbsent(chat.folderId!, () => []).add(chat);
        } else {
          uncategorizedChats.add(chat); // Orphaned -> Uncategorized
        }
      } else {
        uncategorizedChats.add(chat);
      }
    }

    return Expanded(
      child: ListView(
        controller: _scrollController,
        padding: EdgeInsets.zero,
        children: [
          // --- PINNED CHATS ---
          if (pinnedChats.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Text(
                'Sabitlenenler',
                style: TextStyle(
                  color: theme.textTheme.bodySmall?.color?.withOpacity(0.5),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            ...pinnedChats.map(
              (c) => _buildDraggableChatItem(context, c, theme),
            ),
            const SizedBox(height: 8),
          ],

          // --- FOLDERS HEADER & LIST ---
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Klasörler',
                  style: TextStyle(
                    color: theme.textTheme.bodySmall?.color?.withOpacity(0.5),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  icon: const Icon(Icons.create_new_folder_outlined, size: 16),
                  color: theme.textTheme.bodySmall?.color?.withOpacity(0.5),
                  tooltip: 'Yeni Klasör',
                  onPressed: widget.onCreateFolder,
                ),
              ],
            ),
          ),

          if (widget.folders.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: Text(
                'Henüz klasör yok',
                style: TextStyle(fontSize: 11, color: theme.disabledColor),
              ),
            ),

          ...() {
            final sortedFolders = List<ChatFolder>.from(widget.folders);
            sortedFolders.sort((a, b) {
              if (a.isPinned != b.isPinned) {
                return a.isPinned ? -1 : 1;
              }
              return a.name.compareTo(b.name);
            });
            return sortedFolders;
          }().map(
            (folder) => _buildFolderItem(
              context,
              folder,
              folderChats[folder.id] ?? [],
              theme,
            ),
          ),

          const SizedBox(height: 8),

          // --- GROUP CHATS ---
          if (groupChats.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Text(
                'Grup Sohbetleri',
                style: TextStyle(
                  color: theme.textTheme.bodySmall?.color?.withOpacity(0.5),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            ...groupChats.map((c) => _buildChatItem(context, c, theme)),
          ],

          // --- UNCATEGORIZED CHATS ---
          // Always show header as drop target for uncategorizing
          DragTarget<String>(
            onWillAccept: (chatId) {
              if (chatId == null) return false;
              return true;
            },
            onAccept: (chatId) {
              final chat = visibleChats.firstWhere((c) => c.id == chatId);
              widget.onChatMoveToFolder(chat, null); // Move to root
            },
            builder: (ctx, candidate, rejected) {
              final isHovered = candidate.isNotEmpty;
              return Container(
                decoration: BoxDecoration(
                  color: isHovered
                      ? theme.primaryColor.withOpacity(0.15)
                      : Colors.transparent,
                  borderRadius: isHovered ? BorderRadius.circular(8) : null,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                      child: Row(
                        children: [
                          Text(
                            'Sohbetler',
                            style: TextStyle(
                              color: theme.textTheme.bodySmall?.color
                                  ?.withOpacity(0.5),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (isHovered) ...[
                            const SizedBox(width: 8),
                            Icon(
                              Icons.arrow_downward,
                              size: 12,
                              color: theme.primaryColor,
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (uncategorizedChats.isNotEmpty)
                      ...uncategorizedChats
                          .map(
                            (c) => _buildDraggableChatItem(context, c, theme),
                          )
                          .toList()
                    else if (!isHovered)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 8,
                        ),
                        child: Text(
                          'Buraya sürükle',
                          style: TextStyle(
                            fontSize: 11,
                            color: theme.disabledColor,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),

          // Large empty drop zone for easier uncategorizing
          DragTarget<String>(
            onWillAccept: (chatId) => chatId != null,
            onAccept: (chatId) {
              final chat = visibleChats.firstWhere((c) => c.id == chatId);
              widget.onChatMoveToFolder(chat, null);
            },
            builder: (ctx, candidate, rejected) {
              return Container(
                height: 80,
                decoration: BoxDecoration(
                  color: candidate.isNotEmpty
                      ? theme.primaryColor.withOpacity(0.15)
                      : Colors.transparent,
                  borderRadius: candidate.isNotEmpty
                      ? BorderRadius.circular(12)
                      : null,
                ),
                child: candidate.isNotEmpty
                    ? Center(
                        child: Text(
                          'Klasörden çıkarmak için bırak',
                          style: TextStyle(
                            color: theme.primaryColor,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      )
                    : null,
              );
            },
          ),

          const SizedBox(height: 20), // Bottom padding
        ],
      ),
    );
  }

  Widget _buildFolderItem(
    BuildContext context,
    ChatFolder folder,
    List<Chat> chatsInFolder,
    ThemeData theme,
  ) {
    return DragTarget<String>(
      onWillAccept: (chatId) {
        if (chatId == null) return false;
        // Don't accept if already in this folder
        final isInFolder = chatsInFolder.any((c) => c.id == chatId);
        return !isInFolder;
      },
      onAccept: (chatId) {
        // Find chat anywhere in visible list
        final allChats = widget.chats; // Use full list
        try {
          final chat = allChats.firstWhere((c) => c.id == chatId);
          widget.onChatMoveToFolder(chat, folder.id);
        } catch (_) {}
      },
      builder: (context, candidateData, rejectedData) {
        final isHovered = candidateData.isNotEmpty;

        return Container(
          decoration: BoxDecoration(
            color: isHovered
                ? theme.primaryColor.withOpacity(0.1)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Folder Header
              InkWell(
                onTap: () => widget.onToggleFolder(folder),
                onLongPress: () => widget.onEditFolder(folder),
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      // Chevron
                      FaIcon(
                        folder.isExpanded
                            ? FontAwesomeIcons.chevronDown
                            : FontAwesomeIcons.chevronRight,
                        size: 12,
                        color: theme.textTheme.bodySmall?.color,
                      ),
                      const SizedBox(width: 8),
                      // Emoji Icon (New)
                      if (folder.icon != null && folder.icon!.isNotEmpty) ...[
                        Text(
                          folder.icon!,
                          style: const TextStyle(fontSize: 14),
                        ),
                        const SizedBox(width: 8),
                      ],
                      // Color Dot
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: Color(folder.color),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Folder Name
                      Expanded(
                        child: Text(
                          folder.name,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: theme.textTheme.bodyLarge?.color,
                          ),
                        ),
                      ),
                      // Options
                      SizedBox(
                        width: 24,
                        height: 24,
                        child: PopupMenuButton<String>(
                          padding: EdgeInsets.zero,
                          icon: Icon(
                            Icons.more_horiz,
                            size: 16,
                            color: theme.disabledColor,
                          ),
                          onSelected: (value) {
                            if (value == 'edit') widget.onEditFolder(folder);
                            if (value == 'delete')
                              widget.onDeleteFolder(folder);
                            if (value == 'pin' &&
                                widget.onToggleFolderPin != null) {
                              widget.onToggleFolderPin!(folder);
                            }
                          },
                          itemBuilder: (ctx) => [
                            PopupMenuItem(
                              value: 'pin',
                              child: Row(
                                children: [
                                  Icon(
                                    folder.isPinned
                                        ? Icons.push_pin_outlined
                                        : Icons.push_pin,
                                    size: 16,
                                    color: theme.textTheme.bodyMedium?.color,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    folder.isPinned
                                        ? 'Sabitlemeyi Kaldır'
                                        : 'Sabitle',
                                  ),
                                ],
                              ),
                            ),
                            const PopupMenuItem(
                              value: 'edit',
                              child: Text('Düzenle'),
                            ),
                            const PopupMenuItem(
                              value: 'delete',
                              child: Text(
                                'Sil',
                                style: TextStyle(color: Colors.red),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Folder Content
              if (folder.isExpanded)
                Padding(
                  padding: const EdgeInsets.only(left: 12), // Indent content
                  child: Column(
                    children: chatsInFolder
                        .map((c) => _buildDraggableChatItem(context, c, theme))
                        .toList(),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDraggableChatItem(
    BuildContext context,
    Chat chat,
    ThemeData theme,
  ) {
    if (widget.isMultiDeleteMode) {
      // No dragging in multi-delete mode
      return _buildChatItem(context, chat, theme);
    }

    return LongPressDraggable<String>(
      data: chat.id,
      onDragUpdate: (details) {
        final double screenHeight = MediaQuery.of(context).size.height;
        final double y = details.globalPosition.dy;
        // User requested wider area near settings button (top)
        // Increased threshold to capture zone near Settings button
        const double topThreshold = 250.0;
        const double bottomThreshold = 80.0;

        if (y < topThreshold) {
          // Near top - Expanded zone
          final speed = -((topThreshold - y) / 5.0).clamp(1.0, 15.0);
          _startAutoScroll(speed);
        } else if (y > screenHeight - bottomThreshold) {
          // Near bottom
          final speed = ((y - (screenHeight - bottomThreshold)) / 5.0).clamp(
            1.0,
            15.0,
          );
          _startAutoScroll(speed);
        } else {
          _stopAutoScroll();
        }
      },
      onDragEnd: (_) => _stopAutoScroll(),
      feedback: Material(
        color: Colors.transparent,
        child: Container(
          width: 250,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: theme.brightness == Brightness.dark
                ? const Color(0xFF1E1E1E)
                : Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Text(
            chat.title,
            style: TextStyle(
              color: theme.textTheme.bodyLarge?.color,
              decoration: TextDecoration.none,
              fontSize: 14,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
      child: _buildChatItem(context, chat, theme),
    );
  }

  Widget _buildChatItem(BuildContext context, Chat chat, ThemeData theme) {
    final isSelected = widget.currentChat?.id == chat.id;
    final isMultiSelected =
        widget.isMultiDeleteMode &&
        widget.selectedChatIdsForDelete.contains(chat.id);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: isSelected
            ? theme.colorScheme.surface.withOpacity(
                theme.brightness == Brightness.dark ? 0.98 : 0.5,
              )
            : Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        border: isSelected
            ? Border.all(color: theme.dividerColor.withOpacity(0.1))
            : null,
      ),
      child: ListTile(
        onTap: () => widget.isMultiDeleteMode
            ? widget.onChatToggleSelection(chat)
            : widget.onChatSelected(chat),
        leading: chat.isGroup
            ? CircleAvatar(
                backgroundColor: theme.colorScheme.secondaryContainer,
                radius: 14,
                child: Icon(
                  Icons.group,
                  size: 16,
                  color: theme.colorScheme.onSecondaryContainer,
                ),
              )
            : (chat.projectColor != null
                  ? Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(chat.projectColor!),
                        border: Border.all(
                          color: chat.projectColor == 0xFF000000
                              ? Colors.white
                              : (chat.projectColor == 0xFFFFFFFF
                                    ? Colors.black
                                    : theme.dividerColor.withOpacity(0.1)),
                          width:
                              (chat.projectColor == 0xFF000000 ||
                                  chat.projectColor == 0xFFFFFFFF)
                              ? 1.5
                              : 1,
                        ),
                      ),
                      child: chat.isPinned
                          ? Icon(
                              Icons.push_pin,
                              size: 14,
                              color: chat.projectColor == 0xFFFFFFFF
                                  ? Colors.black
                                  : Colors.white,
                            )
                          : null,
                    )
                  : (chat.isPinned
                        ? Icon(
                            Icons.push_pin,
                            color: theme.textTheme.bodySmall?.color
                                ?.withOpacity(0.7),
                            size: 18,
                          )
                        : null)),
        title: Text(
          chat.title,
          style: TextStyle(
            color: theme.textTheme.bodyLarge?.color,
            fontSize: 14,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          '${DateFormat('dd.MM.yyyy HH:mm').format(chat.updatedAt)}${chat.projectLabel != null && chat.projectLabel!.isNotEmpty ? ' • ${chat.projectLabel}' : ''}',
          style: TextStyle(
            color: theme.textTheme.bodySmall?.color?.withOpacity(0.5),
            fontSize: 11,
          ),
        ),
        trailing: widget.isMultiDeleteMode
            ? Checkbox(
                value: isMultiSelected,
                onChanged: (val) {
                  widget.onChatToggleSelection.call(chat);
                },
                activeColor: Colors.redAccent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
              )
            : PopupMenuButton<String>(
                icon: Icon(
                  Icons.more_vert,
                  color: theme.textTheme.bodySmall?.color?.withOpacity(0.6),
                  size: 20,
                ),
                color: theme.cardColor,
                onSelected: (value) {
                  if (value == 'summary') {
                    widget.onOpenChatSummaries?.call(chat);
                  } else if (value == 'edit') {
                    widget.onChatEdit(chat);
                  } else if (value == 'delete' || value == 'leave_group') {
                    widget.onChatDelete(chat);
                  } else if (value == 'pin') {
                    widget.onChatTogglePin?.call(chat);
                  } else if (value == 'export_pdf') {
                    widget.onExportPdf?.call(chat);
                  } else if (value == 'export_fs') {
                    widget.onExportFs?.call(chat);
                  } else if (value == 'lock') {
                    widget.onChatLock?.call(chat);
                  }
                },
                itemBuilder: (context) => [
                  if (widget.onChatLock != null)
                    PopupMenuItem(
                      value: 'lock',
                      child: Row(
                        children: [
                          Icon(
                            chat.isLocked ? Icons.lock_open : Icons.lock,
                            size: 16,
                            color: theme.textTheme.bodyMedium?.color
                                ?.withOpacity(0.8),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            chat.isLocked ? 'Kilidi Kaldır' : 'Sohbeti Kilitle',
                            style: TextStyle(
                              color: theme.textTheme.bodyMedium?.color,
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (widget.onChatTogglePin != null)
                    PopupMenuItem(
                      value: 'pin',
                      child: Row(
                        children: [
                          Icon(
                            chat.isPinned
                                ? Icons.push_pin
                                : Icons.push_pin_outlined,
                            size: 16,
                            color: theme.textTheme.bodyMedium?.color
                                ?.withOpacity(0.8),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            chat.isPinned ? 'Sabitten kaldır' : 'Sabitle',
                            style: TextStyle(
                              color: theme.textTheme.bodyMedium?.color,
                            ),
                          ),
                        ],
                      ),
                    ),
                  PopupMenuItem(
                    value: 'summary',
                    child: Row(
                      children: [
                        Icon(
                          Icons.summarize,
                          size: 16,
                          color: theme.textTheme.bodyMedium?.color?.withOpacity(
                            0.8,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Sohbet Özetleri',
                          style: TextStyle(
                            color: theme.textTheme.bodyMedium?.color,
                          ),
                        ),
                      ],
                    ),
                  ),

                  PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        FaIcon(
                          FontAwesomeIcons.penToSquare,
                          size: 14,
                          color: theme.textTheme.bodyMedium?.color?.withOpacity(
                            0.8,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Düzenle',
                          style: TextStyle(
                            color: theme.textTheme.bodyMedium?.color,
                          ),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'export_pdf',
                    child: Row(
                      children: [
                        Icon(
                          Icons.picture_as_pdf_outlined,
                          size: 16,
                          color: theme.textTheme.bodyMedium?.color?.withOpacity(
                            0.8,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'PDF Olarak İndir',
                          style: TextStyle(
                            color: theme.textTheme.bodyMedium?.color,
                          ),
                        ),
                      ],
                    ),
                  ),

                  PopupMenuItem(
                    value: 'export_fs',
                    child: Row(
                      children: [
                        Icon(
                          Icons.download,
                          size: 16,
                          color: theme.textTheme.bodyMedium?.color?.withOpacity(
                            0.8,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Sohbeti İndir',
                          style: TextStyle(
                            color: theme.textTheme.bodyMedium?.color,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        FaIcon(
                          FontAwesomeIcons.trash,
                          size: 14,
                          color: Colors.redAccent,
                        ),
                        const SizedBox(width: 12),
                        Text('Sil', style: TextStyle(color: Colors.redAccent)),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildFooter(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.onSignOut != null)
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _showLogoutConfirmation(context),
                icon: const Icon(
                  Icons.logout,
                  color: Colors.redAccent,
                  size: 16,
                ),
                label: const Text(
                  'Çıkış yap',
                  style: TextStyle(color: Colors.redAccent),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.redAccent),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
              ),
            ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Made by ',
                style: TextStyle(
                  color: theme.textTheme.bodySmall?.color?.withOpacity(0.6),
                  fontSize: 12,
                ),
              ),
              const SizedBox(width: 5),
              Image.asset(themeService.getLogoPath('logo2.png'), height: 20),
            ],
          ),
        ],
      ),
    );
  }
}
