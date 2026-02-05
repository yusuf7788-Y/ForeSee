import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/theme_service.dart';

class AuthScreenWrapper extends StatelessWidget {
  final Widget child;
  final String headline;
  final String? subtitle;
  final VoidCallback? onBack;
  final bool showText;

  const AuthScreenWrapper({
    super.key,
    required this.child,
    required this.headline,
    this.subtitle,
    this.onBack,
    this.showText = true,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset('assets/background1.png', fit: BoxFit.cover),
          SafeArea(
            child: Column(
              children: [
                _buildHeader(context),
                Expanded(
                  child: Align(
                    alignment: const Alignment(0, -0.1),
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 40),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (showText && headline.isNotEmpty) ...[
                            const SizedBox(height: 40),
                            Text(
                              headline,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (subtitle != null) ...[
                              const SizedBox(height: 8),
                              Text(
                                subtitle!,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                            const SizedBox(height: 26),
                          ] else ...[
                            const SizedBox(height: 24),
                          ],
                          child,
                        ],
                      ),
                    ),
                  ),
                ),
                _buildFooter(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          GestureDetector(
            onTap:
                onBack ??
                () {
                  if (Navigator.of(context).canPop()) {
                    Navigator.of(context).pop();
                  } else {
                    SystemNavigator.pop();
                  }
                },
            child: Row(
              children: [
                Icon(
                  Icons.arrow_back,
                  color: theme.brightness == Brightness.dark
                      ? Colors.white
                      : Colors.black87,
                  size: 20,
                ),
                const SizedBox(width: 6),
                Text(
                  'Çıkış yap',
                  style: TextStyle(
                    color: theme.brightness == Brightness.dark
                        ? Colors.white
                        : Colors.black87,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          Transform.translate(
            offset: const Offset(0, 3),
            child: Image.asset(
              themeService.getLogoPath('assets/logo.png'),
              height: 53,
              fit: BoxFit.contain,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Text(
        'Destek/İleti: yus7f42@gmail.com',
        style: TextStyle(
          color: Colors.blueGrey.withOpacity(0.5),
          fontSize: 11,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
