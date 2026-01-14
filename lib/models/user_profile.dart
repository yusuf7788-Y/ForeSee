import 'package:flutter/material.dart';

class UserProfile {
  final String name;
  final String username;
  final DateTime createdAt;
  final String? profileImagePath;
  final int colorValue;
  final String email;

  Color get profileColor => Color(colorValue);

  UserProfile({
    required this.name,
    required this.username,
    required this.createdAt,
    this.profileImagePath,
    int? colorValue,
    this.email = '',
  }) : colorValue = colorValue ?? _generateColorValue();

  static int _generateColorValue() {
    final colors = [
      0xFFF44336, // red
      0xFFE91E63, // pink
      0xFF9C27B0, // purple
      0xFF673AB7, // deep purple
      0xFF3F51B5, // indigo
      0xFF2196F3, // blue
      0xFF00BCD4, // cyan
      0xFF009688, // teal
      0xFF4CAF50, // green
      0xFFFF9800, // orange
      0xFFFF5722, // deep orange
    ];
    return colors[5]; // blue
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'username': username,
      'createdAt': createdAt.toIso8601String(),
      'profileImagePath': profileImagePath,
      'colorValue': colorValue,
      'email': email,
    };
  }

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      name: json['name'] ?? '',
      username: json['username'] ?? '',
      createdAt: DateTime.parse(json['createdAt']),
      profileImagePath: json['profileImagePath'],
      colorValue: json['colorValue'],
      email: json['email'] ?? '',
    );
  }

  UserProfile copyWith({
    String? name,
    String? username,
    DateTime? createdAt,
    String? profileImagePath,
    int? colorValue,
    String? email,
  }) {
    return UserProfile(
      name: name ?? this.name,
      username: username ?? this.username,
      createdAt: createdAt ?? this.createdAt,
      profileImagePath: profileImagePath ?? this.profileImagePath,
      colorValue: colorValue ?? this.colorValue,
      email: email ?? this.email,
    );
  }
}
