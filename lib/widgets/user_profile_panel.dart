import 'dart:io';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../models/user_profile.dart';

class UserProfilePanel extends StatelessWidget {
  final UserProfile userProfile;
  final VoidCallback? onEditPressed;
  final bool showEditButton;

  const UserProfilePanel({
    super.key,
    required this.userProfile,
    this.onEditPressed,
    this.showEditButton = true,
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final initial = userProfile.name.isNotEmpty
        ? userProfile.name[0].toUpperCase()
        : 'U';

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: theme.dividerColor.withOpacity(0.1)),
        boxShadow: !isDark
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
                    color: isDark ? Colors.white : Colors.black87,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  'Kullanım: ${_getUsageDuration()}',
                  style: TextStyle(
                    color: (isDark ? Colors.white : Colors.black).withOpacity(
                      0.6,
                    ),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          if (showEditButton)
            IconButton(
              icon: FaIcon(
                FontAwesomeIcons.penToSquare,
                size: 16,
                color: (isDark ? Colors.white : Colors.black).withOpacity(0.7),
              ),
              onPressed: onEditPressed,
            ),
        ],
      ),
    );
  }
}
