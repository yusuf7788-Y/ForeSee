import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../models/user_profile.dart';
import '../services/storage_service.dart';
import '../widgets/grey_notification.dart';
import 'chat_screen.dart';
import '../services/cloud_backup_service.dart';
import '../widgets/user_profile_panel.dart';

class FirstRunNameScreen extends StatefulWidget {
  const FirstRunNameScreen({super.key});

  @override
  State<FirstRunNameScreen> createState() => _FirstRunNameScreenState();
}

class _FirstRunNameScreenState extends State<FirstRunNameScreen> {
  final TextEditingController _nameController = TextEditingController();
  final StorageService _storageService = StorageService();

  bool _isSubmitting = false;
  String? _errorMessage;

  Timer? _debounceTimer;

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _nameController.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    setState(() {
      _errorMessage = null;
    });

    if (value.trim().length < 3) {
      if (value.trim().isNotEmpty) {
        setState(() => _errorMessage = 'En az 3 karakter olmalı');
      }
      return;
    }

    // Debounced Check
    if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();
    _debounceTimer = Timer(const Duration(seconds: 1), () {
      if (value.trim().length >= 3) {
        _checkAutomaticRecovery(value.trim());
      }
    });
  }

  Future<void> _checkAutomaticRecovery(String name) async {
    try {
      final backupInfo = await CloudBackupService.instance.checkExistingBackup(
        name,
      );

      if (backupInfo != null && mounted) {
        // Stop any pending checks or typing interactions
        FocusScope.of(context).unfocus();

        final shouldRestore = await _showRecoveryDialog(backupInfo);
        if (shouldRestore == true) {
          setState(() => _isSubmitting = true); // Show loading

          await CloudBackupService.instance.restoreDataFromSpecificUid(
            backupInfo['uid'],
            onProgress: (p, status) => debugPrint(status),
          );

          if (!mounted) return;
          Navigator.of(
            context,
          ).pushReplacement(MaterialPageRoute(builder: (_) => ChatScreen()));
        }
      }
    } catch (e) {
      debugPrint('Silent check failed: $e');
    }
  }

  bool get _canSubmit =>
      _nameController.text.trim().length >= 3 && !_isSubmitting;

  Future<void> _submit() async {
    if (!_canSubmit) return;
    setState(() {
      _isSubmitting = true;
    });

    try {
      final name = _nameController.text.trim();

      // We still check here just in case the timer didn't fire or user was fast
      // But we can rely on the same helper method logic, effectively duplicating the check but safe.
      // Optimization: use _checkAutomaticRecovery logic but handle specific "New Account" case manually if not found?
      // Actually, original logic checked, then created new.
      // Let's keep the check here to be sure.

      // Check for existing backup in Firestore (Active blocking check)
      final backupInfo = await CloudBackupService.instance.checkExistingBackup(
        name,
      );

      if (backupInfo != null && mounted) {
        final shouldRestore = await _showRecoveryDialog(backupInfo);
        if (shouldRestore == true) {
          await CloudBackupService.instance.restoreDataFromSpecificUid(
            backupInfo['uid'],
            onProgress: (p, status) => debugPrint(status),
          );
          if (!mounted) return;
          Navigator.of(
            context,
          ).pushReplacement(MaterialPageRoute(builder: (_) => ChatScreen()));
          return;
        }
      }

      // Firebase Anonim Giriş (Yedekleme için gerekli)
      try {
        await FirebaseAuth.instance.signInAnonymously();
      } catch (e) {
        print('Anonim giriş hatası (Offline olabilir): $e');
      }

      // Local storage'a kaydet (Yeni Hesap)
      final profile = UserProfile(
        name: name,
        username: name,
        createdAt: DateTime.now(),
        email: 'local@foresee.app',
      );
      await _storageService.saveUserProfile(profile);

      // Auto-enable logic for first run?

      if (!mounted) return;
      Navigator.of(
        context,
      ).pushReplacement(MaterialPageRoute(builder: (_) => ChatScreen()));
    } catch (e) {
      if (!mounted) return;
      GreyNotification.show(context, 'Bir hata oluştu: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  Future<bool?> _showRecoveryDialog(Map<String, dynamic> backupInfo) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final data = backupInfo['data'] as Map<String, dynamic>;
    final deviceName = data['deviceName'] ?? 'Bilinmeyen Cihaz';
    final chatCount = data['chatCount'] ?? 0;

    // Construct a UserProfile object from backup data for display
    UserProfile? profile;
    if (data['profile'] != null) {
      try {
        profile = UserProfile.fromJson(data['profile']);
      } catch (_) {}
    }

    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1A1A1A) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Eski hesabını bulduk!',
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black87,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Geri dönmek ister misin?',
              style: TextStyle(color: isDark ? Colors.white70 : Colors.black54),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            if (profile != null)
              UserProfilePanel(userProfile: profile, showEditButton: false),
            if (profile == null)
              Text(
                '$deviceName cihazından $chatCount sohbetli bir yedek.',
                style: TextStyle(
                  color: isDark ? Colors.white70 : Colors.black54,
                ),
                textAlign: TextAlign.center,
              ),
          ],
        ),
        actionsAlignment: MainAxisAlignment.spaceBetween,
        actionsPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Yeni Hesap İle Devam et',
              style: TextStyle(
                color: isDark ? Colors.white38 : Colors.black38,
                fontSize: 13,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blueAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            child: const Text('Geçmiş Hesaba Geç'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Asset selections based on theme
    final bgImage = isDark
        ? 'assets/background1.png'
        : 'assets/background1w.png';
    // User clarification:
    // logo.png = White Logo (Visible on Dark Background)
    // logow.png = Black Logo (Visible on Light Background)
    final logoImage = isDark ? 'assets/logo.png' : 'assets/logow.png';

    // Text colors
    final headlineColor = isDark ? const Color(0xFFF2F5FC) : Colors.black87;
    final subtextColor = isDark
        ? Colors.white.withOpacity(0.65)
        : Colors.black54;
    final inputColor = isDark ? Colors.white : Colors.black;
    final lineColor = isDark ? Colors.white24 : Colors.black12;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        backgroundColor: isDark ? Colors.black : const Color(0xFFEEEEEE),
        body: Stack(
          fit: StackFit.expand,
          children: [
            // Background Image
            Image.asset(
              bgImage,
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
            ),

            // Content
            SafeArea(
              child: Column(
                children: [
                  // Top Bar
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24.0,
                      vertical: 16.0,
                    ),
                    child: Row(
                      children: [
                        // Back / Exit Button
                        GestureDetector(
                          onTap: () {
                            // Exit functionality
                            if (Navigator.of(context).canPop()) {
                              Navigator.of(context).pop();
                            } else {
                              // If it's the root, just clear input
                              _nameController.clear();
                            }
                          },
                          child: Row(
                            children: [
                              FaIcon(
                                FontAwesomeIcons.arrowLeft,
                                color: headlineColor,
                                size: 16,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Çıkış yap',
                                style: TextStyle(
                                  color: headlineColor,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Spacer(),
                        // Logo
                        Image.asset(logoImage, height: 40, fit: BoxFit.contain),
                      ],
                    ),
                  ),

                  const Spacer(flex: 2), // Push content slightly up/centered
                  // Centered Content (Circle Area)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Headline
                        Text(
                          'Size nasıl hitap edelim',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: headlineColor,
                            fontSize: 28,
                            fontWeight: FontWeight.w400,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Subtext
                        Text(
                          'ForeSee\'nin size nasıl hitap etmesini istersiniz. Özel olmasına gerek yok adınızı veya lakabınızı girebilirsiniz',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: subtextColor,
                            fontSize: 12.5,
                            height: 1.5,
                          ),
                        ),

                        const SizedBox(height: 40),

                        // Input Field
                        Stack(
                          alignment: Alignment.centerRight,
                          children: [
                            TextField(
                              controller: _nameController,
                              textAlign: TextAlign.left,
                              style: TextStyle(
                                color: inputColor,
                                fontSize: 18,
                                fontWeight: FontWeight.w500,
                              ),
                              cursorColor: inputColor,
                              decoration: InputDecoration(
                                labelText: 'Kullanıcı adı',
                                labelStyle: TextStyle(
                                  color: subtextColor,
                                  fontSize: 16,
                                ),
                                filled: true,
                                fillColor: isDark
                                    ? const Color(0xFF000000)
                                    : const Color(0xFFF1F4FB),
                                enabledBorder: UnderlineInputBorder(
                                  borderSide: BorderSide(
                                    color: lineColor,
                                    width: 1,
                                  ),
                                ),
                                focusedBorder: UnderlineInputBorder(
                                  borderSide: BorderSide(
                                    color: isDark ? Colors.white : Colors.black,
                                    width: 2.0,
                                  ),
                                ),
                                contentPadding: const EdgeInsets.only(
                                  bottom: 8,
                                  left: 8,
                                  right: 8,
                                  top: 4,
                                ),
                                floatingLabelBehavior:
                                    FloatingLabelBehavior.auto,
                              ),
                              onChanged: _onChanged,
                            ),

                            // Simple validation tick
                            if (_canSubmit)
                              const FaIcon(
                                FontAwesomeIcons.check,
                                color: Colors.green,
                                size: 16,
                              ),
                          ],
                        ),

                        // Error Message
                        if (_errorMessage != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 8, left: 0),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                _errorMessage!,
                                style: const TextStyle(
                                  color: Colors.redAccent,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ),

                        const SizedBox(
                          height: 45,
                        ), // Space between input and button
                        // Continue Button
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 30.0),
                          child: SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: ElevatedButton(
                              onPressed: _canSubmit ? _submit : null,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: isDark
                                    ? Colors.white
                                    : Colors.black, // Inverted for contrast
                                foregroundColor: isDark
                                    ? Colors.black
                                    : Colors.white,
                                disabledBackgroundColor:
                                    (isDark ? Colors.white : Colors.black)
                                        .withOpacity(0.3),
                                disabledForegroundColor:
                                    (isDark ? Colors.black : Colors.white)
                                        .withOpacity(0.3),
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(30),
                                ),
                              ),
                              child: _isSubmitting
                                  ? Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: isDark
                                                ? Colors.black
                                                : Colors.white,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Hesap oluşturuluyor...',
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: isDark
                                                ? Colors.black54
                                                : Colors.white70,
                                          ),
                                        ),
                                      ],
                                    )
                                  : const Text(
                                      'Devam et',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),
                  // "Geçmiş hesaplarımı kontrol et" butonu
                  TextButton(
                    onPressed: _checkPastAccounts,
                    child: const Text(
                      'Geçmiş hesaplarımı kontrol et.',
                      style: TextStyle(
                        color: Colors.blueAccent,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),

                  if (_isCheckingPastAccounts)
                    Padding(
                      padding: const EdgeInsets.only(
                        top: 16.0,
                        left: 40,
                        right: 40,
                      ),
                      child: Column(
                        children: [
                          LinearProgressIndicator(
                            backgroundColor: isDark
                                ? Colors.white10
                                : Colors.black12,
                            valueColor: const AlwaysStoppedAnimation<Color>(
                              Colors.blueAccent,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Yedekler aranıyor...',
                            style: TextStyle(color: subtextColor, fontSize: 12),
                          ),
                        ],
                      ),
                    ),

                  const Spacer(
                    flex: 3,
                  ), // Bottom spacing, pushing content slightly up from absolute bottom
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _isCheckingPastAccounts = false;

  Future<void> _checkPastAccounts() async {
    setState(() {
      _isCheckingPastAccounts = true;
    });

    try {
      // 1. Check by entered name first if available
      String queryName = _nameController.text.trim();

      // 2. If no name, maybe we could support device-based check in future?
      // For now, if name is empty, we can't search by name.
      // But the user might expect us to check for *any* backup on this device or previous logins.

      // NOTE: Since CloudBackupService currently requires a name to "find" the UID via the public mapping,
      // we must rely on the name. If name is empty, we should perhaps prompt or just wait.
      // However, the user request implies they might have "deleted the app" which means local storage is gone.
      // If they haven't typed a name, we can't magically find them unless we stored device ID -> UID mapping globally.
      // Assuming for now we use the name in the box if present, or if empty, maybe the user expects to "login" (not implemented yet).

      // Let's assume we use the name they typed, or if empty, we can't do much yet.
      // But to be helpful, let's try to query with what we have.

      if (queryName.length < 3) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Lütfen önce bir isim giriniz.')),
          );
        }
        return;
      }

      await Future.delayed(
        const Duration(seconds: 1),
      ); // UX delay for "Searching" feel

      final backupInfo = await CloudBackupService.instance.checkExistingBackup(
        queryName,
      );

      if (backupInfo != null && mounted) {
        final shouldRestore = await _showRecoveryDialog(backupInfo);
        if (shouldRestore == true) {
          setState(() => _isSubmitting = true);

          await CloudBackupService.instance.restoreDataFromSpecificUid(
            backupInfo['uid'],
            onProgress: (p, status) => debugPrint(status),
          );

          if (!mounted) return;
          Navigator.of(
            context,
          ).pushReplacement(MaterialPageRoute(builder: (_) => ChatScreen()));
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Bu isimle eşleşen bir yedek bulunamadı.'),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Manual check failed: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isCheckingPastAccounts = false;
        });
      }
    }
  }
}
