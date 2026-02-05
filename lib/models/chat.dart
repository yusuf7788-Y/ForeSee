import 'message.dart';
import 'lock_type.dart';

class Chat {
  final String id;
  final String title;
  final List<Message> messages;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int unreadCount;
  final List<String> pinnedMessageIds;

  // Proje / workspace özellikleri
  final String? projectLabel;
  final int? projectColor; // ARGB renk değeri
  final String? projectIcon; // İleride ikon anahtarı için
  final List<Map<String, dynamic>>?
  projectTasks; // Bu sohbete ait TODO görevleri
  final DateTime? deletedAt; // Yumuşak silme için tarih
  final bool isPinned; // Sohbeti üste sabitlemek için
  final List<Map<String, dynamic>>?
  summaryCards; // Sohbet özet kartları (metin + JSON)
  final bool isGroup;
  final String? groupId; // Eğer isGroup true ise, Firestore'daki grup ID
  final String? createdBy;
  final List<String>? admins;
  final List<Map<String, dynamic>>? memberDetails;
  final String? folderId; // Klasör ID
  final int usageMinutes; // Sohbet için harcanan zaman
  final int? lastSummarizedCount; // Özetlemede kullanılan son mesaj sayısı

  // Security fields
  final bool isLocked;
  final LockType lockType;
  final String? lockData;

  Chat({
    required this.id,
    required this.title,
    required this.messages,
    required this.createdAt,
    required this.updatedAt,
    this.unreadCount = 0,
    this.pinnedMessageIds = const [],
    this.projectLabel,
    this.projectColor,
    this.projectIcon,
    this.projectTasks,
    this.deletedAt,
    this.isPinned = false,
    this.summaryCards,
    this.isGroup = false,
    this.groupId,
    this.createdBy,
    this.admins,
    this.memberDetails,
    this.folderId,
    this.usageMinutes = 0,
    this.lastSummarizedCount,
    this.isLocked = false,
    this.lockType = LockType.none,
    this.lockData,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'messages': messages.map((m) => m.toJson()).toList(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'unreadCount': unreadCount,
      'pinnedMessageIds': pinnedMessageIds,
      'projectLabel': projectLabel,
      'projectColor': projectColor,
      'projectIcon': projectIcon,
      'projectTasks': projectTasks,
      'deletedAt': deletedAt?.toIso8601String(),
      'isPinned': isPinned,
      'summaryCards': summaryCards,
      'isGroup': isGroup,
      'groupId': groupId,
      'createdBy': createdBy,
      'admins': admins,
      'memberDetails': memberDetails,
      'folderId': folderId,
      'usageMinutes': usageMinutes,
      'lastSummarizedCount': lastSummarizedCount,
      'isLocked': isLocked,
      'lockType': lockType.index,
      'lockData': lockData,
    };
  }

  factory Chat.fromJson(Map<String, dynamic> json) {
    return Chat(
      id: json['id'],
      title: json['title'],
      messages: (json['messages'] as List)
          .map((m) => Message.fromJson(m))
          .toList(),
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: DateTime.parse(json['updatedAt']),
      unreadCount: json['unreadCount'] ?? 0,
      pinnedMessageIds:
          (json['pinnedMessageIds'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      projectLabel: json['projectLabel'],
      projectColor: json['projectColor'],
      projectIcon: json['projectIcon'],
      projectTasks: (json['projectTasks'] as List?)
          ?.map(
            (e) => e is Map<String, dynamic>
                ? e
                : e is Map
                ? Map<String, dynamic>.from(e)
                : <String, dynamic>{'raw': e.toString()},
          )
          .toList(),
      deletedAt: json['deletedAt'] != null
          ? DateTime.parse(json['deletedAt'] as String)
          : null,
      isPinned: json['isPinned'] ?? false,
      summaryCards: (json['summaryCards'] as List?)
          ?.map(
            (e) => e is Map<String, dynamic>
                ? e
                : e is Map
                ? Map<String, dynamic>.from(e)
                : <String, dynamic>{'raw': e.toString()},
          )
          .toList(),
      isGroup: json['isGroup'] ?? false,
      groupId: json['groupId'],
      createdBy: json['createdBy'],
      admins: (json['admins'] as List?)?.map((e) => e.toString()).toList(),
      memberDetails: (json['memberDetails'] as List?)
          ?.map(
            (e) => e is Map<String, dynamic> ? e : Map<String, dynamic>.from(e),
          )
          .toList(),
      folderId: json['folderId'],
      usageMinutes: json['usageMinutes'] ?? 0,
      lastSummarizedCount: json['lastSummarizedCount'],
      isLocked: json['isLocked'] ?? false,
      lockType: json['lockType'] != null
          ? LockType.values[json['lockType']]
          : LockType.none,
      lockData: json['lockData'],
    );
  }

  Chat copyWith({
    String? id,
    String? title,
    List<Message>? messages,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? unreadCount,
    List<String>? pinnedMessageIds,
    String? projectLabel,
    int? projectColor,
    String? projectIcon,
    List<Map<String, dynamic>>? projectTasks,
    DateTime? deletedAt,
    bool? isPinned,
    List<Map<String, dynamic>>? summaryCards,
    bool? isGroup,
    String? groupId,
    String? createdBy,
    List<String>? admins,
    List<Map<String, dynamic>>? memberDetails,
    String? folderId,
    int? usageMinutes,
    int? lastSummarizedCount,
    bool clearProjectColor = false,
    bool clearFolderId = false,
    bool clearDeletedAt = false,
    bool? isLocked,
    LockType? lockType,
    String? lockData,
    bool clearLockData = false,
  }) {
    return Chat(
      id: id ?? this.id,
      title: title ?? this.title,
      messages: messages ?? this.messages,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      unreadCount: unreadCount ?? this.unreadCount,
      pinnedMessageIds: pinnedMessageIds ?? this.pinnedMessageIds,
      projectLabel: projectLabel ?? this.projectLabel,
      projectColor: clearProjectColor
          ? null
          : (projectColor ?? this.projectColor),
      projectIcon: projectIcon ?? this.projectIcon,
      projectTasks: projectTasks ?? this.projectTasks,
      deletedAt: clearDeletedAt ? null : (deletedAt ?? this.deletedAt),
      isPinned: isPinned ?? this.isPinned,
      summaryCards: summaryCards ?? this.summaryCards,
      isGroup: isGroup ?? this.isGroup,
      groupId: groupId ?? this.groupId,
      createdBy: createdBy ?? this.createdBy,
      admins: admins ?? this.admins,
      memberDetails: memberDetails ?? this.memberDetails,
      folderId: clearFolderId ? null : (folderId ?? this.folderId),
      usageMinutes: usageMinutes ?? this.usageMinutes,
      lastSummarizedCount: lastSummarizedCount ?? this.lastSummarizedCount,
      isLocked: isLocked ?? this.isLocked,
      lockType: lockType ?? this.lockType,
      lockData: clearLockData ? null : (lockData ?? this.lockData),
    );
  }
}
