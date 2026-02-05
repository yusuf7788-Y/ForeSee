class Message {
  final String id;
  final String chatId;
  final String content;
  final bool isUser;
  final DateTime timestamp;
  final String? imageUrl;
  // Bir mesaj birden fazla görsel taşıyabilsin diye ek alan
  final List<String>? imageUrls;
  final bool isStopped;
  final Map<String, dynamic>? searchResult;
  final String? audioPath;
  final int? audioDurationMs;

  final bool isReasoning;
  final List<Map<String, dynamic>>? todoPanel;
  final List<Map<String, dynamic>>? actions;
  final bool isChartCandidate;
  final dynamic
  chartData; // Using dynamic for LineChartData to avoid direct dependency
  final List<String>? alternatives;
  final int displayAlternativeIndex;
  final Map<String, dynamic>? metadata;
  // Grup sohbeti için gönderen bilgileri
  final String? senderUsername;
  final String? senderPhotoUrl;

  Message({
    required this.id,
    required this.chatId,
    required this.content,
    required this.isUser,
    required this.timestamp,
    this.imageUrl,
    this.imageUrls,

    this.isReasoning = false,
    this.isStopped = false,
    this.searchResult,
    this.audioPath,
    this.audioDurationMs,
    this.todoPanel,
    this.actions,
    this.isChartCandidate = false,
    this.chartData,
    this.alternatives,
    this.displayAlternativeIndex = 0,
    this.metadata,
    this.senderUsername,
    this.senderPhotoUrl,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'chatId': chatId,
      'content': content,
      'isUser': isUser,
      'timestamp': timestamp.toIso8601String(),
      'imageUrl': imageUrl,
      'imageUrls': imageUrls,
      'isStopped': isStopped,
      'searchResult': searchResult,
      'audioPath': audioPath,
      'audioDurationMs': audioDurationMs,
      'todoPanel': todoPanel,
      'actions': actions,
      'isChartCandidate': isChartCandidate,
      // chartData is not serialized
      'alternatives': alternatives,
      'displayAlternativeIndex': displayAlternativeIndex,
      'metadata': metadata,
      'senderUsername': senderUsername,
      'senderPhotoUrl': senderPhotoUrl,
    };
  }

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      id: json['id'],
      chatId: json['chatId'] ?? '',
      content: json['content'],
      isUser: json['isUser'],
      timestamp: DateTime.parse(json['timestamp']),
      imageUrl: json['imageUrl'],
      imageUrls: (json['imageUrls'] as List?)
          ?.map((e) => e.toString())
          .toList(),
      isStopped: json['isStopped'] ?? false,
      searchResult: json['searchResult'],
      audioPath: json['audioPath'],
      audioDurationMs: json['audioDurationMs'],
      todoPanel: (json['todoPanel'] as List?)
          ?.map(
            (e) => e is Map<String, dynamic>
                ? e
                : e is Map
                ? Map<String, dynamic>.from(e)
                : <String, dynamic>{'raw': e.toString()},
          )
          .toList(),
      actions: (json['actions'] as List?)
          ?.map(
            (e) => e is Map<String, dynamic>
                ? e
                : e is Map
                ? Map<String, dynamic>.from(e)
                : <String, dynamic>{'raw': e.toString()},
          )
          .toList(),
      alternatives: (json['alternatives'] as List?)
          ?.map((e) => e.toString())
          .toList(),
      displayAlternativeIndex: json['displayAlternativeIndex'] ?? 0,
      metadata: json['metadata'],
      senderUsername: json['senderUsername'],
      senderPhotoUrl: json['senderPhotoUrl'],
    );
  }

  Message copyWith({
    String? id,
    String? chatId,
    String? content,
    bool? isUser,
    DateTime? timestamp,
    String? imageUrl,
    List<String>? imageUrls,
    bool? isStopped,
    Map<String, dynamic>? searchResult,
    String? audioPath,
    int? audioDurationMs,
    List<Map<String, dynamic>>? todoPanel,
    List<Map<String, dynamic>>? actions,
    bool? isChartCandidate,
    dynamic chartData,
    List<String>? alternatives,
    int? displayAlternativeIndex,
    Map<String, dynamic>? metadata,
    String? senderUsername,
    String? senderPhotoUrl,
  }) {
    return Message(
      id: id ?? this.id,
      chatId: chatId ?? this.chatId,
      content: content ?? this.content,
      isUser: isUser ?? this.isUser,
      timestamp: timestamp ?? this.timestamp,
      imageUrl: imageUrl ?? this.imageUrl,
      imageUrls: imageUrls ?? this.imageUrls,
      isStopped: isStopped ?? this.isStopped,
      searchResult: searchResult ?? this.searchResult,
      audioPath: audioPath ?? this.audioPath,
      audioDurationMs: audioDurationMs ?? this.audioDurationMs,
      todoPanel: todoPanel ?? this.todoPanel,
      actions: actions ?? this.actions,
      isChartCandidate: isChartCandidate ?? this.isChartCandidate,
      chartData: chartData ?? this.chartData,
      alternatives: alternatives ?? this.alternatives,
      displayAlternativeIndex:
          displayAlternativeIndex ?? this.displayAlternativeIndex,
      metadata: metadata ?? this.metadata,
      senderUsername: senderUsername ?? this.senderUsername,
      senderPhotoUrl: senderPhotoUrl ?? this.senderPhotoUrl,
    );
  }
}
