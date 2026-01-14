import 'package:flutter/material.dart';

class MultiAnswerSwitcher extends StatelessWidget {
  final List<String> alternatives;
  final int currentIndex;
  final ValueChanged<int> onAlternativeSelected;
  final VoidCallback onDismiss;

  const MultiAnswerSwitcher({
    super.key,
    required this.alternatives,
    required this.currentIndex,
    required this.onAlternativeSelected,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.close, size: 18, color: Colors.white70),
            onPressed: onDismiss,
          ),
          Text(
            '${currentIndex + 1} / ${alternatives.length}',
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_left, size: 22, color: Colors.white),
                onPressed: currentIndex > 0
                    ? () => onAlternativeSelected(currentIndex - 1)
                    : null,
              ),
              IconButton(
                icon: const Icon(Icons.arrow_right, size: 22, color: Colors.white),
                onPressed: currentIndex < alternatives.length - 1
                    ? () => onAlternativeSelected(currentIndex + 1)
                    : null,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
