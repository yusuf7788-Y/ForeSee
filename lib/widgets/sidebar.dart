import 'dart:io';
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

class Sidebar extends StatelessWidget {
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
  final Function(Chat)? onOpenChatSummaries;
  final VoidCallback? onImportChat;
  final Function(Chat)? onExportPdf;
  final Function(Chat)? onExportFs;

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
    this.onOpenChatSummaries,
    this.onImportChat,
    this.onExportPdf,
    this.onExportFs,
  });

  String _getUsageDuration() {
    final now = DateTime.now();
    final duration = now.difference(userProfile.createdAt);

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
    final nameController = TextEditingController(text: userProfile.name);
    String? selectedImagePath = userProfile.profileImagePath;

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
              final updatedProfile = userProfile.copyWith(
                name: nameController.text.trim(),
                profileImagePath: selectedImagePath,
              );
              onProfileUpdated(updatedProfile);
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Drawer(
      width: 340.0,
      backgroundColor: theme.brightness == Brightness.dark
          ? const Color(0xFF020202)
          : const Color(0xFFF0F2F5),
      child: SafeArea(
        child: Column(
          children: [
            _buildUserPanel(context),
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
    final theme = Theme.of(context);
    final initial = userProfile.name.isNotEmpty
        ? userProfile.name[0].toUpperCase()
        : 'U';

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.brightness == Brightness.dark
            ? const Color(0xFF080808)
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
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: Color(userProfile.colorValue),
              shape: BoxShape.circle,
            ),
            child: userProfile.profileImagePath != null
                ? ClipOval(
                    child: Image.file(
                      File(userProfile.profileImagePath!),
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Center(
                          child: Text(
                            initial,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        );
                      },
                    ),
                  )
                : Center(
                    child: Text(
                      initial,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  userProfile.name,
                  style: TextStyle(
                    color: theme.textTheme.bodyLarge?.color,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  'Kullanım: ${_getUsageDuration()}',
                  style: TextStyle(
                    color: theme.textTheme.bodySmall?.color?.withOpacity(0.6),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: FaIcon(
              FontAwesomeIcons.penToSquare,
              size: 16,
              color: theme.textTheme.bodySmall?.color?.withOpacity(0.7),
            ),
            onPressed: () => _editProfile(context),
          ),
        ],
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
              ? const Color(0xFF080808)
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
          onTap: onSettingsPressed,
        ),
      ),
    );
  }

  Widget _buildChatsSection(BuildContext context) {
    final theme = Theme.of(context);
    final visibleChats = chats.where((c) => c.deletedAt == null).toList();
    visibleChats.sort((a, b) {
      if (a.isPinned && !b.isPinned) return -1;
      if (!a.isPinned && b.isPinned) return 1;
      return b.updatedAt.compareTo(a.updatedAt);
    });

    final groupChats = visibleChats.where((c) => c.isGroup).toList();
    final normalChats = visibleChats.where((c) => !c.isGroup).toList();

    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                FaIcon(
                  FontAwesomeIcons.comments,
                  size: 18,
                  color: theme.textTheme.bodySmall?.color?.withOpacity(0.7),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Sohbetler',
                    style: TextStyle(
                      color: theme.textTheme.bodyLarge?.color,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (onSearchChats != null)
                  IconButton(
                    icon: Icon(
                      Icons.search,
                      size: 18,
                      color: theme.textTheme.bodySmall?.color?.withOpacity(0.6),
                    ),
                    onPressed: onSearchChats,
                  ),
                if (onOpenTrash != null)
                  IconButton(
                    icon: Icon(
                      Icons.delete_outline,
                      size: 18,
                      color: theme.textTheme.bodySmall?.color?.withOpacity(0.6),
                    ),
                    onPressed: onOpenTrash,
                  ),
                if (isMultiDeleteMode)
                  Row(
                    children: [
                      TextButton(
                        onPressed: onMultiDeleteCancel,
                        child: Text(
                          'İptal',
                          style: TextStyle(
                            color: theme.textTheme.bodySmall?.color
                                ?.withOpacity(0.7),
                            fontSize: 12,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: onMultiDeletePressed,
                        child: Text(
                          'Sil (${selectedChatIdsForDelete.length})',
                          style: const TextStyle(
                            color: Colors.redAccent,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  )
                else
                  IconButton(
                    icon: Icon(
                      Icons.checklist,
                      size: 18,
                      color: theme.textTheme.bodySmall?.color?.withOpacity(0.6),
                    ),
                    onPressed: onMultiDeletePressed,
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: visibleChats.isEmpty
                ? Center(
                    child: Text(
                      'Henüz sohbet yok',
                      style: TextStyle(
                        color: theme.textTheme.bodySmall?.color?.withOpacity(
                          0.38,
                        ),
                      ),
                    ),
                  )
                : ListView(
                    padding: EdgeInsets.zero,
                    children: [
                      if (groupChats.isNotEmpty) ...[
                        Padding(
                          padding: const EdgeInsets.only(
                            left: 16,
                            top: 8,
                            bottom: 4,
                          ),
                          child: Text(
                            'Grup sohbetleri',
                            style: TextStyle(
                              color: theme.textTheme.bodySmall?.color
                                  ?.withOpacity(0.5),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        ...groupChats.map(
                          (chat) => _buildChatItem(context, chat, theme),
                        ),
                        const SizedBox(height: 8),
                      ],
                      if (normalChats.isNotEmpty) ...[
                        ...normalChats.map(
                          (chat) => _buildChatItem(context, chat, theme),
                        ),
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildChatItem(BuildContext context, Chat chat, ThemeData theme) {
    final isSelected = currentChat?.id == chat.id;
    final isMultiSelected =
        isMultiDeleteMode && selectedChatIdsForDelete.contains(chat.id);

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
        onTap: () => isMultiDeleteMode
            ? onChatToggleSelection(chat)
            : onChatSelected(chat),
        leading: isMultiDeleteMode
            ? Icon(
                isMultiSelected
                    ? Icons.check_box
                    : Icons.check_box_outline_blank,
                color: isMultiSelected
                    ? Colors.redAccent
                    : theme.textTheme.bodySmall?.color?.withOpacity(0.6),
              )
            : (chat.isGroup
                  ? CircleAvatar(
                      backgroundColor: theme.colorScheme.secondaryContainer,
                      radius: 14,
                      child: Icon(
                        Icons.group,
                        size: 16,
                        color: theme.colorScheme.onSecondaryContainer,
                      ),
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
          DateFormat('dd.MM.yyyy HH:mm').format(chat.updatedAt),
          style: TextStyle(
            color: theme.textTheme.bodySmall?.color?.withOpacity(0.5),
            fontSize: 11,
          ),
        ),
        trailing: isMultiDeleteMode
            ? null
            : PopupMenuButton<String>(
                icon: Icon(
                  Icons.more_vert,
                  color: theme.textTheme.bodySmall?.color?.withOpacity(0.6),
                  size: 20,
                ),
                color: theme.cardColor,
                onSelected: (value) {
                  if (value == 'summary') {
                    onOpenChatSummaries?.call(chat);
                  } else if (value == 'edit') {
                    onChatEdit(chat);
                  } else if (value == 'delete' || value == 'leave_group') {
                    onChatDelete(chat);
                  } else if (value == 'pin') {
                    onChatTogglePin?.call(chat);
                  } else if (value == 'export_pdf') {
                    onExportPdf?.call(chat);
                  } else if (value == 'export_fs') {
                    onExportFs?.call(chat);
                  }
                },
                itemBuilder: (context) => [
                  if (onChatTogglePin != null)
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
          if (onSignOut != null)
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onSignOut,
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
                'Made in by ',
                style: TextStyle(
                  color: theme.textTheme.bodySmall?.color?.withOpacity(0.6),
                  fontSize: 12,
                ),
              ),
              const SizedBox(width: 4),
              Image.asset(
                themeService.getLogoPath('logo2.png'),
                height: 65,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
