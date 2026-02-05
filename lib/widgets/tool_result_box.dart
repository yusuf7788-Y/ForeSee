import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class ToolResultBox extends StatelessWidget {
  final String title;
  final String? subtitle;
  final int addedLines;
  final int removedLines;
  final bool isLoading;
  final VoidCallback? onApprove;
  final VoidCallback? onShare;
  final VoidCallback? onTap;

  const ToolResultBox({
    super.key,
    required this.title,
    this.subtitle,
    this.addedLines = 0,
    this.removedLines = 0,
    this.isLoading = false,
    this.onApprove,
    this.onShare,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withOpacity(0.05)
            : Colors.black.withOpacity(0.03),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: isLoading
                        ? _buildLoadingIndicator()
                        : Text(
                            title,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                  ),
                  if (!isLoading) ...[
                    const SizedBox(width: 8),
                    _buildStats(),
                    const SizedBox(width: 12),
                    if (onApprove != null) _buildApproveButton(context),
                    if (onShare != null) ...[
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.share, size: 18),
                        onPressed: onShare,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        color: isDark ? Colors.white60 : Colors.black54,
                      ),
                    ],
                  ],
                ],
              ),
              if (subtitle != null && !isLoading) ...[
                const SizedBox(height: 4),
                Text(
                  subtitle!,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white54 : Colors.black54,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingIndicator() {
    return const Row(
      children: [
        SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        SizedBox(width: 10),
        Text(
          'Hazırlanıyor...',
          style: TextStyle(fontSize: 13, fontStyle: FontStyle.italic),
        ),
      ],
    );
  }

  Widget _buildStats() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (addedLines > 0)
          Text(
            '$addedLines+',
            style: const TextStyle(
              color: Colors.greenAccent,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        if (addedLines > 0 && removedLines > 0) const SizedBox(width: 4),
        if (removedLines > 0)
          Text(
            '$removedLines-',
            style: const TextStyle(
              color: Colors.redAccent,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
      ],
    );
  }

  Widget _buildApproveButton(BuildContext context) {
    return GestureDetector(
      onTap: onApprove,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.greenAccent.withOpacity(0.2),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.greenAccent.withOpacity(0.5)),
        ),
        child: const Text(
          'Onayla',
          style: TextStyle(
            color: Colors.greenAccent,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}
