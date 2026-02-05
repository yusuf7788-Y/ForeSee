import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'dart:async';

class MultiAnswerSelectionPanel extends StatefulWidget {
  final List<String> answers;
  final Function(int selectedIndex) onAnswerSelected;
  final VoidCallback onDismiss;

  const MultiAnswerSelectionPanel({
    super.key,
    required this.answers,
    required this.onAnswerSelected,
    required this.onDismiss,
  });

  @override
  State<MultiAnswerSelectionPanel> createState() =>
      _MultiAnswerSelectionPanelState();
}

class _MultiAnswerSelectionPanelState extends State<MultiAnswerSelectionPanel> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  // Streaming states for each answer
  late List<String> _displayedAnswers;
  late List<bool> _isStreamingComplete;

  @override
  void initState() {
    super.initState();
    _displayedAnswers = List.generate(widget.answers.length, (_) => '');
    _isStreamingComplete = List.generate(widget.answers.length, (_) => false);
    _startStreaming();
  }

  void _startStreaming() async {
    // Start streaming all answers simultaneously
    for (int i = 0; i < widget.answers.length; i++) {
      _streamAnswer(i, widget.answers[i]);
    }
  }

  Future<void> _streamAnswer(int index, String fullText) async {
    const chunkDelay = Duration(milliseconds: 15);
    int charIndex = 0;

    while (charIndex < fullText.length) {
      if (!mounted) return;

      // Stream in chunks
      final chunkSize = (fullText.length - charIndex).clamp(1, 3);
      final chunk = fullText.substring(charIndex, charIndex + chunkSize);

      setState(() {
        _displayedAnswers[index] += chunk;
      });

      charIndex += chunkSize;
      await Future.delayed(chunkDelay);
    }

    if (mounted) {
      setState(() {
        _isStreamingComplete[index] = true;
      });
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      child: Container(
        color: (isDark ? Colors.black : Colors.white).withOpacity(0.95),
        child: SafeArea(
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.all(20.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Cevabını seç',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.close,
                        color: isDark ? Colors.white70 : Colors.black54,
                      ),
                      onPressed: widget.onDismiss,
                    ),
                  ],
                ),
              ),

              // Page Indicator
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(widget.answers.length, (index) {
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: _currentPage == index ? 24 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: _currentPage == index
                          ? (isDark ? Colors.white : Colors.black)
                          : (isDark ? Colors.white30 : Colors.black26),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  );
                }),
              ),

              const SizedBox(height: 16),

              // Answer Cards
              Expanded(
                child: Stack(
                  children: [
                    PageView.builder(
                      controller: _pageController,
                      onPageChanged: (page) {
                        setState(() {
                          _currentPage = page;
                        });
                      },
                      itemCount: widget.answers.length,
                      itemBuilder: (context, index) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: _buildAnswerCard(
                            index,
                            _displayedAnswers[index],
                            _isStreamingComplete[index],
                            isDark,
                          ),
                        );
                      },
                    ),

                    // Navigation Arrows
                    if (widget.answers.length > 1) ...[
                      // Left Arrow
                      if (_currentPage > 0)
                        Positioned(
                          left: 8,
                          top: 0,
                          bottom: 80,
                          child: Center(
                            child: IconButton(
                              icon: Icon(
                                Icons.chevron_left,
                                size: 32,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                              onPressed: () {
                                _pageController.previousPage(
                                  duration: const Duration(milliseconds: 300),
                                  curve: Curves.easeInOut,
                                );
                              },
                            ),
                          ),
                        ),
                      // Right Arrow
                      if (_currentPage < widget.answers.length - 1)
                        Positioned(
                          right: 8,
                          top: 0,
                          bottom: 80,
                          child: Center(
                            child: IconButton(
                              icon: Icon(
                                Icons.chevron_right,
                                size: 32,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                              onPressed: () {
                                _pageController.nextPage(
                                  duration: const Duration(milliseconds: 300),
                                  curve: Curves.easeInOut,
                                );
                              },
                            ),
                          ),
                        ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAnswerCard(
    int index,
    String displayedText,
    bool isComplete,
    bool isDark,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white12 : Colors.black12,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Answer Content
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.white.withOpacity(0.1)
                              : Colors.black.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          'Cevap ${index + 1}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white70 : Colors.black54,
                          ),
                        ),
                      ),
                      const Spacer(),
                      if (!isComplete)
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: isDark ? Colors.white70 : Colors.black54,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  MarkdownBody(
                    data: displayedText.isEmpty
                        ? 'Yazılıyor...'
                        : displayedText,
                    styleSheet: MarkdownStyleSheet(
                      p: TextStyle(
                        fontSize: 15,
                        height: 1.5,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                      strong: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                      em: TextStyle(
                        fontStyle: FontStyle.italic,
                        color: isDark ? Colors.white70 : Colors.black87,
                      ),
                      h1: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                      h2: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                      h3: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                      code: TextStyle(
                        backgroundColor: isDark
                            ? Colors.white10
                            : Colors.black.withOpacity(0.05),
                        color: isDark ? Colors.white : Colors.black,
                        fontFamily: 'monospace',
                      ),
                      codeblockDecoration: BoxDecoration(
                        color: isDark
                            ? Colors.white10
                            : Colors.black.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      blockquote: TextStyle(
                        color: isDark ? Colors.white70 : Colors.black54,
                        fontStyle: FontStyle.italic,
                      ),
                      blockquoteDecoration: BoxDecoration(
                        border: Border(
                          left: BorderSide(
                            color: isDark ? Colors.white24 : Colors.black12,
                            width: 4,
                          ),
                        ),
                      ),
                    ),
                    selectable: true,
                  ),
                ],
              ),
            ),
          ),

          // Select Button
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: isComplete
                  ? () => widget.onAnswerSelected(index)
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: isDark ? Colors.white : Colors.black,
                foregroundColor: isDark ? Colors.black : Colors.white,
                disabledBackgroundColor: isDark
                    ? Colors.white30
                    : Colors.black26,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                isComplete ? 'Bu cevabı seç' : 'Yazılıyor...',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
