import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../models/auth_models.dart';
import '../models/user_profile.dart';
import 'otp_service.dart';
import 'profile_service.dart';
import 'storage_service.dart';

class AuthService {
  AuthService._();

  static final AuthService instance = AuthService._();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final OtpService _otpService = OtpService();
  final StorageService _storage = StorageService();

  bool get authBypass =>
      (dotenv.env['AUTH_BYPASS'] ?? 'false').toLowerCase() == 'true';

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<EmailCheckResult> checkEmailStatus(String email) async {
    final trimmed = email.trim();
    if (trimmed.isEmpty) {
      return const EmailCheckResult(state: EmailValidationState.empty);
    }
    if (!trimmed.contains('@') || !trimmed.contains('.')) {
      return const EmailCheckResult(
        state: EmailValidationState.invalid,
        message: 'Geçerli bir e-posta girin',
      );
    }

    try {
      final methods = await _auth.fetchSignInMethodsForEmail(trimmed);
      if (methods.isEmpty) {
        return const EmailCheckResult(state: EmailValidationState.available);
      }
      return const EmailCheckResult(
        state: EmailValidationState.exists,
        message: 'Bu e-posta zaten kayıtlı',
      );
    } on FirebaseAuthException catch (e) {
      final msg = e.message ?? '';
      if (msg.contains('CONFIGRATION_NOT_FOUND')) {
        // Firebase yapılandırma hatası varsa kullanıcıyı bloklamayalım
        return const EmailCheckResult(state: EmailValidationState.available);
      }
      return EmailCheckResult(
        state: EmailValidationState.error,
        message: 'Hata: ${e.code}', // Hata kodunu göster
      );
    } catch (e) {
      return EmailCheckResult(
        state: EmailValidationState.error,
        message: 'Doğrulama hatası',
      );
    }
  }

  Future<EmailCheckResult> checkEmailForLogin(String email) async {
    final trimmed = email.trim();
    if (trimmed.isEmpty) {
      return const EmailCheckResult(state: EmailValidationState.empty);
    }
    if (!trimmed.contains('@') || !trimmed.contains('.')) {
      return const EmailCheckResult(
        state: EmailValidationState.invalid,
        message: 'Geçerli bir e-posta girin',
      );
    }

    try {
      final methods = await _auth.fetchSignInMethodsForEmail(trimmed);
      if (methods.isEmpty) {
        return const EmailCheckResult(
          state: EmailValidationState.notFound,
          message: 'Böyle kayıtlı e-posta yok',
        );
      }
      return const EmailCheckResult(state: EmailValidationState.available);
    } on FirebaseAuthException catch (e) {
      final msg = e.message ?? '';
      if (msg.contains('CONFIGRATION_NOT_FOUND')) {
        // Firebase yapılandırma hatası varsa kullanıcıyı bloklamayalım
        return const EmailCheckResult(state: EmailValidationState.available);
      }
      return EmailCheckResult(
        state: EmailValidationState.error,
        message: 'Hata: ${e.code}',
      );
    } catch (e) {
      return EmailCheckResult(
        state: EmailValidationState.error,
        message: 'Doğrulama hatası',
      );
    }
  }

  Future<OtpRequestResult> startEmailFlow({
    required String email,
    required AuthFlow flow,
    String? name,
  }) async {
    if (flow == AuthFlow.register) {
      final status = await checkEmailStatus(email);
      if (status.state == EmailValidationState.exists) {
        throw Exception('Bu e-posta zaten kayıtlı');
      }
    } else {
      final status = await checkEmailForLogin(email);
      if (status.state == EmailValidationState.notFound) {
        throw Exception('Böyle kayıtlı e-posta yok');
      }
    }

    return _otpService.requestOtp(email: email, flow: flow, name: name);
  }

  Future<void> verifyOtpAndSignIn({
    required String email,
    required String code,
    required AuthFlow flow,
    required String sessionId,
    String? name,
  }) async {
    final result = await _otpService.verifyOtp(
      email: email,
      code: code,
      flow: flow,
      sessionId: sessionId,
    );

    UserCredential credential;
    // Mock veya Local SMTP ise Anonim Giriş yap
    if (_otpService.isMock || _otpService.usingLocalSmtp) {
      // Önce mevcut bir anonim oturum varsa onu kullanmayı dene veya yeni aç
      try {
        if (_auth.currentUser != null) {
          // Zaten bir oturum varsa (örn first run'dan kalma), onu kullan
          credential = await _auth.currentUser!.reload().then(
            (_) =>
                // Burada aslında UserCredential döndüremeyiz reload void döner.
                // O yüzden basitçe signInAnonymously çağırıyoruz,
                // Firebase zaten varsa mevcutu döner veya hata verir.
                _auth.signInAnonymously(),
          );
        } else {
          credential = await _auth.signInAnonymously();
        }
      } catch (e) {
        // Hata durumunda (örn user silinmişse) yeni anonim oturum
        credential = await _auth.signInAnonymously();
      }

      if (kDebugMode) {
        debugPrint(
          'Lokal/Mock sign-in kullanıldı (anonim): ${credential.user?.uid}',
        );
      }

      // Kullanıcının emailini profil servisine kaydetmek için (Firebase Auth'a değil)
      // Aşağıdaki profil oluşturma adımı halledecek.
    } else if (result.customToken != null) {
      credential = await _auth.signInWithCustomToken(result.customToken!);
    } else {
      throw Exception('Sunucu custom token döndürmedi');
    }

    final currentUser = credential.user;
    if (currentUser == null) {
      throw Exception('Firebase oturumu açılamadı');
    }

    if (_otpService.isMock || _otpService.usingLocalSmtp) {
      final profile = UserProfile(
        name: name ?? 'Kullanıcı',
        username: name ?? 'Kullanıcı',
        createdAt: DateTime.now(),
        email: email,
      );
      await _storage.saveUserProfile(profile);
      return;
    }

    await ProfileService.instance.ensureProfile(
      preferredName: name ?? result.profileName,
    );
  }

  Future<bool> signInWithEmailAndPassword(String email, String password) async {
    try {
      // For now, we'll use anonymous sign-in as a placeholder
      // In a real implementation, this would verify email/password against Firebase Auth
      final result = await _auth.signInAnonymously();
      
      if (kDebugMode) {
        debugPrint('Email/Password sign-in (mock): ${result.user?.uid}');
      }
      
      return result.user != null;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Email/Password sign-in error: $e');
      }
      return false;
    }
  }

  Future<void> signInWithGoogle(AuthFlow flow) async {
    throw Exception(
      'Google ile giriş şu an kullanılamıyor. Lütfen e-posta ile devam edin.',
    );
  }

  Future<UserCredential> signInAnonymously() async {
    return await _auth.signInAnonymously();
  }

  Future<void> signOut() async {
    try {
      await GoogleSignIn().signOut();
    } catch (_) {}
    await _auth.signOut();
    await _storage.resetAll();
  }
}
