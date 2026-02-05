import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '../models/chat.dart';
import '../models/lock_type.dart';
import '../models/message.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  static Database? _database;

  factory DatabaseService() {
    return _instance;
  }

  DatabaseService._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'foresee_data.db');

    return await openDatabase(
      path,
      version: 3,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Add lock columns to chats table
      await db.execute(
        'ALTER TABLE chats ADD COLUMN isLocked INTEGER DEFAULT 0',
      );
      await db.execute('ALTER TABLE chats ADD COLUMN lockType TEXT');
      await db.execute('ALTER TABLE chats ADD COLUMN lockData TEXT');
    }
    if (oldVersion < 3) {
      // Ensure specific columns exist if they were missed due to schema error
      // We can use catchError to ignore if they exist
      try {
        await db.execute(
          'ALTER TABLE chats ADD COLUMN lastSummarizedCount INTEGER',
        );
      } catch (_) {}
      try {
        await db.execute('ALTER TABLE chats ADD COLUMN summaryCards TEXT');
      } catch (_) {}
    }
  }

  Future<void> _onCreate(Database db, int version) async {
    // Chats Table
    await db.execute('''
      CREATE TABLE chats (
        id TEXT PRIMARY KEY,
        title TEXT,
        createdAt TEXT,
        updatedAt TEXT,
        unreadCount INTEGER,
        pinnedMessageIds TEXT, -- JSON List
        projectLabel TEXT,
        projectColor INTEGER,
        projectIcon TEXT,
        projectTasks TEXT, -- JSON List<Map>
        deletedAt TEXT,
        isPinned INTEGER,
        summaryCards TEXT, -- JSON List<Map>
        isGroup INTEGER,
        groupId TEXT,
        createdBy TEXT,
        admins TEXT, -- JSON List
        memberDetails TEXT, -- JSON List<Map>
        folderId TEXT,
        usageMinutes INTEGER,
        lastSummarizedCount INTEGER,
        isLocked INTEGER,
        lockType TEXT,
        lockData TEXT
      )
    ''');

    // Messages Table
    await db.execute('''
      CREATE TABLE messages (
        id TEXT PRIMARY KEY,
        chatId TEXT,
        content TEXT,
        isUser INTEGER,
        timestamp TEXT,
        imageUrl TEXT,
        imageUrls TEXT, -- JSON List
        isStopped INTEGER,
        searchResult TEXT, -- JSON Map
        audioPath TEXT,
        audioDurationMs INTEGER,
        todoPanel TEXT, -- JSON List<Map>
        actions TEXT, -- JSON List<Map>
        isChartCandidate INTEGER,
        alternatives TEXT, -- JSON List
        displayAlternativeIndex INTEGER,
        metadata TEXT, -- JSON Map
        senderUsername TEXT,
        senderPhotoUrl TEXT,
        FOREIGN KEY(chatId) REFERENCES chats(id) ON DELETE CASCADE
      )
    ''');

    // Indexes for performance
    await db.execute('CREATE INDEX idx_messages_chatId ON messages(chatId)');
  }

  // --- CRUD Operations ---

  /// Loads all chats fully populated with their messages (Matching existing behavior)
  Future<List<Chat>> getAllChats() async {
    final db = await database;

    // 1. Get all chats
    final List<Map<String, dynamic>> chatMaps = await db.query(
      'chats',
      orderBy: 'updatedAt DESC',
    );

    if (chatMaps.isEmpty) return [];

    final List<Chat> chats = [];

    for (var chatMap in chatMaps) {
      final chatId = chatMap['id'] as String;

      // 2. Get messages for this chat
      final List<Map<String, dynamic>> messageMaps = await db.query(
        'messages',
        where: 'chatId = ?',
        whereArgs: [chatId],
        orderBy: 'timestamp ASC',
      );

      final messages = messageMaps.map((m) => _messageFromMap(m)).toList();
      chats.add(_chatFromMap(chatMap, messages));
    }

    return chats;
  }

  /// Inserts or Updates a Chat and its Messages
  /// Note: This replaces all messages for the chat to ensure sync.
  /// For optimization, we should have separate methods for adding single messages vs saving entire chat.
  Future<void> saveChat(Chat chat) async {
    final db = await database;

    await db.transaction((txn) async {
      // 1. Upsert Chat
      await txn.insert(
        'chats',
        _chatToMap(chat),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      // 2. Sync Messages
      // Strategy: Delete all existing messages for this chat and re-insert.
      // This is safe but might be slow for huge chats.
      // Given the requirement to match StorageService behavior (save whole list), this is acceptable for V1.
      // Optimization: In real usage, we should only insert new messages.
      // But StorageService currently overwrites everything.

      // Checking if we really need to delete all.
      // If we are migrating or doing a full save, yes.
      // A slightly better approach is to upsert each message.
      // But if a message was deleted in memory, upserting won't remove it from DB.
      // So deleting all for this chatID is the safest "Full Sync" approach.

      await txn.delete('messages', where: 'chatId = ?', whereArgs: [chat.id]);

      final batch = txn.batch();
      for (var msg in chat.messages) {
        batch.insert(
          'messages',
          _messageToMap(msg, chat.id),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      await batch.commit(noResult: true);
    });
  }

  /// Deletes a chat and its messages (Cascade should handle messages, but we check)
  Future<void> deleteChat(String chatId) async {
    final db = await database;
    // With foreign keys enabled, deleting chat deletes messages.
    // Ensure foreign keys are enabled (SQLite defaults might vary).
    await db.execute('PRAGMA foreign_keys = ON');
    await db.delete('chats', where: 'id = ?', whereArgs: [chatId]);
  }

  /// Helper to convert Chat object to DB Map
  Map<String, dynamic> _chatToMap(Chat chat) {
    return {
      'id': chat.id,
      'title': chat.title,
      'createdAt': chat.createdAt.toIso8601String(),
      'updatedAt': chat.updatedAt.toIso8601String(),
      'unreadCount': chat.unreadCount,
      'pinnedMessageIds': jsonEncode(chat.pinnedMessageIds),
      'projectLabel': chat.projectLabel,
      'projectColor': chat.projectColor,
      'projectIcon': chat.projectIcon,
      'projectTasks': chat.projectTasks != null
          ? jsonEncode(chat.projectTasks)
          : null,
      'deletedAt': chat.deletedAt?.toIso8601String(),
      'isPinned': chat.isPinned ? 1 : 0,
      'summaryCards': chat.summaryCards != null
          ? jsonEncode(chat.summaryCards)
          : null,
      'isGroup': chat.isGroup ? 1 : 0,
      'groupId': chat.groupId,
      'createdBy': chat.createdBy,
      'admins': chat.admins != null ? jsonEncode(chat.admins) : null,
      'memberDetails': chat.memberDetails != null
          ? jsonEncode(chat.memberDetails)
          : null,
      'folderId': chat.folderId,
      'usageMinutes': chat.usageMinutes,
      'usageMinutes': chat.usageMinutes,
      'lastSummarizedCount': chat.lastSummarizedCount,
      'isLocked': chat.isLocked ? 1 : 0,
      'lockType': chat.lockType.name,
      'lockData': chat.lockData,
    };
  }

  /// Helper to convert DB Map to Chat object
  Chat _chatFromMap(Map<String, dynamic> map, List<Message> messages) {
    return Chat(
      id: map['id'],
      title: map['title'],
      messages: messages,
      createdAt: DateTime.parse(map['createdAt']),
      updatedAt: DateTime.parse(map['updatedAt']),
      unreadCount: map['unreadCount'] ?? 0,
      pinnedMessageIds: map['pinnedMessageIds'] != null
          ? List<String>.from(jsonDecode(map['pinnedMessageIds']))
          : [],
      projectLabel: map['projectLabel'],
      projectColor: map['projectColor'],
      projectIcon: map['projectIcon'],
      projectTasks: map['projectTasks'] != null
          ? List<Map<String, dynamic>>.from(jsonDecode(map['projectTasks']))
          : null,
      deletedAt: map['deletedAt'] != null
          ? DateTime.parse(map['deletedAt'])
          : null,
      isPinned: (map['isPinned'] ?? 0) == 1,
      summaryCards: map['summaryCards'] != null
          ? List<Map<String, dynamic>>.from(jsonDecode(map['summaryCards']))
          : null,
      isGroup: (map['isGroup'] ?? 0) == 1,
      groupId: map['groupId'],
      createdBy: map['createdBy'],
      admins: map['admins'] != null
          ? List<String>.from(jsonDecode(map['admins']))
          : null,
      memberDetails: map['memberDetails'] != null
          ? List<Map<String, dynamic>>.from(jsonDecode(map['memberDetails']))
          : null,
      folderId: map['folderId'],
      usageMinutes: map['usageMinutes'] ?? 0,
      lastSummarizedCount: map['lastSummarizedCount'],
      isLocked: (map['isLocked'] ?? 0) == 1,
      lockType: map['lockType'] != null
          ? LockType.values.firstWhere(
              (e) => e.name == map['lockType'],
              orElse: () => LockType.none,
            )
          : LockType.none,
      lockData: map['lockData'],
    );
  }

  /// Helper to convert Message object to DB Map
  Map<String, dynamic> _messageToMap(Message msg, String chatId) {
    return {
      'id': msg.id,
      'chatId': chatId, // Ensure we store the binding
      'content': msg.content,
      'isUser': msg.isUser ? 1 : 0,
      'timestamp': msg.timestamp.toIso8601String(),
      'imageUrl': msg.imageUrl,
      'imageUrls': msg.imageUrls != null ? jsonEncode(msg.imageUrls) : null,
      'isStopped': msg.isStopped ? 1 : 0,
      'searchResult': msg.searchResult != null
          ? jsonEncode(msg.searchResult)
          : null,
      'audioPath': msg.audioPath,
      'audioDurationMs': msg.audioDurationMs,
      'todoPanel': msg.todoPanel != null ? jsonEncode(msg.todoPanel) : null,
      'actions': msg.actions != null ? jsonEncode(msg.actions) : null,
      'isChartCandidate': msg.isChartCandidate ? 1 : 0,
      'alternatives': msg.alternatives != null
          ? jsonEncode(msg.alternatives)
          : null,
      'displayAlternativeIndex': msg.displayAlternativeIndex,
      'metadata': msg.metadata != null ? jsonEncode(msg.metadata) : null,
      'senderUsername': msg.senderUsername,
      'senderPhotoUrl': msg.senderPhotoUrl,
      // Note: chartData is dynamic and usually not serializable or runtime-only, skipping as per JSON logic
    };
  }

  /// Helper to convert DB Map to Message object
  Message _messageFromMap(Map<String, dynamic> map) {
    return Message(
      id: map['id'],
      chatId: map['chatId'],
      content: map['content'],
      isUser: (map['isUser'] ?? 0) == 1,
      timestamp: DateTime.parse(map['timestamp']),
      imageUrl: map['imageUrl'],
      imageUrls: map['imageUrls'] != null
          ? List<String>.from(jsonDecode(map['imageUrls']))
          : null,
      isStopped: (map['isStopped'] ?? 0) == 1,
      searchResult: map['searchResult'] != null
          ? Map<String, dynamic>.from(jsonDecode(map['searchResult']))
          : null,
      audioPath: map['audioPath'],
      audioDurationMs: map['audioDurationMs'],
      todoPanel: map['todoPanel'] != null
          ? List<Map<String, dynamic>>.from(jsonDecode(map['todoPanel']))
          : null,
      actions: map['actions'] != null
          ? List<Map<String, dynamic>>.from(jsonDecode(map['actions']))
          : null,
      isChartCandidate: (map['isChartCandidate'] ?? 0) == 1,
      alternatives: map['alternatives'] != null
          ? List<String>.from(jsonDecode(map['alternatives']))
          : null,
      displayAlternativeIndex: map['displayAlternativeIndex'] ?? 0,
      metadata: map['metadata'] != null
          ? Map<String, dynamic>.from(jsonDecode(map['metadata']))
          : null,
      senderUsername: map['senderUsername'],
      senderPhotoUrl: map['senderPhotoUrl'],
    );
  }
}
