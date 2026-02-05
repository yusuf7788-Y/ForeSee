import 'lock_type.dart';

class ChatFolder {
  final String id;
  final String name;
  final int color; // ARGB
  final String? icon; // Emoji character
  final bool isExpanded;
  final bool isPinned;
  final DateTime createdAt;

  ChatFolder({
    required this.id,
    required this.name,
    required this.color,
    this.icon,
    this.isExpanded = true,
    this.isPinned = false,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'color': color,
      'icon': icon,
      'isExpanded': isExpanded, // UI state preservation
      'isPinned': isPinned,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory ChatFolder.fromJson(Map<String, dynamic> json) {
    return ChatFolder(
      id: json['id'],
      name: json['name'],
      color: json['color'] ?? 0xFF9E9E9E,
      icon: json['icon'],
      isExpanded: json['isExpanded'] ?? true,
      isPinned: json['isPinned'] ?? false,
      createdAt: DateTime.parse(
        json['createdAt'] ?? DateTime.now().toIso8601String(),
      ),
    );
  }

  ChatFolder copyWith({
    String? id,
    String? name,
    int? color,
    String? icon,
    bool? isExpanded,
    bool? isPinned,
    DateTime? createdAt,
  }) {
    return ChatFolder(
      id: id ?? this.id,
      name: name ?? this.name,
      color: color ?? this.color,
      icon: icon ?? this.icon,
      isExpanded: isExpanded ?? this.isExpanded,
      isPinned: isPinned ?? this.isPinned,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
