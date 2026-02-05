import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import '../models/lock_type.dart';

class SecurityService {
  static final SecurityService instance = SecurityService._privateConstructor();
  final LocalAuthentication auth = LocalAuthentication();
  final FlutterSecureStorage secureStorage = const FlutterSecureStorage();

  SecurityService._privateConstructor();

  /// Hashing helper (SHA-256)
  String hashData(String input) {
    var bytes = utf8.encode(input);
    var digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// Verify App-Level Locks (Pattern, PIN, Password)
  /// [lockType]: The type of lock set by the user
  /// [storedHash]: The hashed lock data stored in the model
  /// [input]: The user's current input (e.g. entered PIN)
  bool verifyCustomLock(LockType lockType, String? storedHash, String input) {
    if (lockType == LockType.none) {
      return true;
    }
    if (storedHash == null) return false;

    // Pattern is usually stored as a sequence string "01254", we can hash it too for security
    // or store plaintext if it's just a sequence. Let's assume we hash everything.
    final inputHash = hashData(input);
    return inputHash == storedHash;
  }

  /// Create a lock hash
  String createLockHash(String input) {
    return hashData(input);
  }
}
