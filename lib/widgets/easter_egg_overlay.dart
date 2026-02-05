import 'package:flutter/material.dart';
import 'dart:async';

class EasterEggOverlay extends StatefulWidget {
  final VoidCallback onDismiss;

  const EasterEggOverlay({super.key, required this.onDismiss});

  @override
  State<EasterEggOverlay> createState() => _EasterEggOverlayState();
}

class _EasterEggOverlayState extends State<EasterEggOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacityAnimation;
  bool _showGif = false;
  Timer? _delayTimer;
  Timer? _dismissTimer;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _opacityAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

    // 1.5 saniye bekle, sonra GIF'i göster
    _delayTimer = Timer(const Duration(milliseconds: 1500), () {
      if (mounted) {
        setState(() {
          _showGif = true;
        });
        _controller.forward();

        // 3 saniye sonra otomatik kapat (GIF süresi)
        _dismissTimer = Timer(const Duration(seconds: 3), () {
          _dismiss();
        });
      }
    });
  }

  void _dismiss() {
    _controller.reverse().then((_) {
      if (mounted) {
        widget.onDismiss();
      }
    });
  }

  @override
  void dispose() {
    _delayTimer?.cancel();
    _dismissTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_showGif) {
      return const SizedBox.shrink();
    }

    return FadeTransition(
      opacity: _opacityAnimation,
      child: GestureDetector(
        onTap: _dismiss,
        child: Container(
          color: Colors.black.withOpacity(0.85),
          child: Center(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.asset(
                'assets/easteregg.gif',
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  // Fallback: GIF yüklenemezse placeholder göster
                  return Container(
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: Colors.grey[900],
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.error_outline,
                          color: Colors.white70,
                          size: 64,
                        ),
                        SizedBox(height: 16),
                        Text(
                          'Easter Egg GIF yüklenemedi',
                          style: TextStyle(color: Colors.white70),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}
