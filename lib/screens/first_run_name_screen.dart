import 'dart:async';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../models/user_profile.dart';
import '../services/storage_service.dart';
import '../services/firestore_service.dart';
import '../services/auth_service.dart';
import '../widgets/auth/auth_screen_wrapper.dart';
import '../widgets/grey_notification.dart';
import 'chat_screen.dart';

class FirstRunNameScreen extends StatefulWidget {
  const FirstRunNameScreen({super.key});

  @override
  State<FirstRunNameScreen> createState() => _FirstRunNameScreenState();
}

class _FirstRunNameScreenState extends State<FirstRunNameScreen> {
  final TextEditingController _nameController = TextEditingController();
  final StorageService _storageService = StorageService();
  final FirestoreService _firestoreService = FirestoreService.instance;

  bool _isSubmitting = false;
  bool _isValidating = false;
  bool? _isAvailable;
  String? _errorMessage;
  Timer? _debounceTimer;

  @override
  void dispose() {
    _nameController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _onChanged(String value) {
    setState(() {
      _isAvailable = null;
      _errorMessage = null;
      _isValidating = false;
    });

    _debounceTimer?.cancel();
    if (value.trim().length < 3) {
      if (value.trim().isNotEmpty) {
        setState(() => _errorMessage = 'En az 3 karakter olmalı');
      }
      return;
    }

    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      _checkUsernameAvailability(value.trim());
    });
  }

  Future<void> _checkUsernameAvailability(String username) async {
    setState(() {
      _isValidating = true;
    });

    try {
      final available = await _firestoreService.isUsernameAvailable(username);
      if (mounted) {
        setState(() {
          _isAvailable = available;
          if (!available) {
            _errorMessage = 'Bu kullanıcı adı zaten alınmış';
          }
          _isValidating = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isValidating = false;
          _errorMessage = 'Kontrol edilemedi, lütfen tekrar deneyin';
        });
      }
    }
  }

  bool get _canSubmit =>
      _isAvailable == true && !_isSubmitting && !_isValidating;

  Future<void> _submit() async {
    if (!_canSubmit) return;
    setState(() {
      _isSubmitting = true;
    });

    try {
      final name = _nameController.text.trim();

      // Önce anonim giriş yap (eğer yoksa) ki Firestore'a kaydedebilelim
      var user = AuthService
          .instance
          .authStateChanges; // This is a stream, not current user
      // Corrected access below

      final auth = AuthService.instance;
      // We need the current user, so we check through the service or direct FirebaseAuth
      final fbUser = await auth.signInAnonymously();

      if (fbUser.user == null) throw Exception('Google/Firebase hatası');

      // Firestore'a kaydet
      await _firestoreService.createUserProfile(
        uid: fbUser.user!.uid,
        email: 'anon@foresee.app',
        displayName: name,
        username: name,
      );

      // Local storage'a kaydet
      final profile = UserProfile(
        name: name,
        username: name,
        createdAt: DateTime.now(),
        email: 'anon@foresee.app',
      );
      await _storageService.saveUserProfile(profile);

      if (!mounted) return;
      Navigator.of(
        context,
      ).pushReplacement(MaterialPageRoute(builder: (_) => const ChatScreen()));
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AuthScreenWrapper(
      headline: 'ForeSee Online\nKullanıcı adını belirle',
      subtitle: 'Her grupta gözükcek olan sana özel kullanıcı adını belirle',
      showText: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 5),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Stack(
                  alignment: Alignment.centerRight,
                  children: [
                    TextField(
                      controller: _nameController,
                      style: TextStyle(
                        color: theme.textTheme.bodyMedium?.color,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                      decoration: InputDecoration(
                        labelText: 'Kullanıcı Adı',
                        labelStyle: TextStyle(
                          color: theme.textTheme.bodySmall?.color?.withOpacity(
                            0.7,
                          ),
                          fontSize: 13,
                        ),
                        enabledBorder: UnderlineInputBorder(
                          borderSide: BorderSide(color: theme.dividerColor),
                        ),
                        focusedBorder: UnderlineInputBorder(
                          borderSide: BorderSide(color: theme.primaryColor),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 8,
                          horizontal: 0,
                        ),
                        hintText: 'örn: kedi_sever',
                        hintStyle: TextStyle(
                          color: theme.textTheme.bodySmall?.color?.withOpacity(
                            0.3,
                          ),
                          fontSize: 13,
                        ),
                      ),
                      onChanged: _onChanged,
                    ),
                    if (_isValidating)
                      const SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    else if (_isAvailable == true)
                      const Icon(
                        Icons.check_circle,
                        color: Colors.green,
                        size: 20,
                      )
                    else if (_isAvailable == false)
                      const Icon(
                        Icons.cancel,
                        color: Colors.redAccent,
                        size: 20,
                      ),
                  ],
                ),
                if (_errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(
                        color: Colors.redAccent,
                        fontSize: 12,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 40),
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(40),
                    ),
                  ),
                  child: Text(
                    'İptal',
                    style: TextStyle(
                      color: theme.textTheme.bodySmall?.color?.withOpacity(0.6),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: _canSubmit ? _submit : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.brightness == Brightness.dark
                        ? Colors.white
                        : Colors.black,
                    foregroundColor: theme.brightness == Brightness.dark
                        ? Colors.black
                        : Colors.white,
                    disabledBackgroundColor: theme.brightness == Brightness.dark
                        ? Colors.white.withOpacity(0.1)
                        : Colors.black.withOpacity(0.1),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(40),
                    ),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text(
                          'Kaydet',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
