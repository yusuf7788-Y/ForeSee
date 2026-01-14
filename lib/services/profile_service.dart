import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/user_profile.dart';
import 'storage_service.dart';

class ProfileService {
  ProfileService._();

  static final ProfileService instance = ProfileService._();

  final _firestore = FirebaseFirestore.instance;
  final _storage = StorageService();

  Future<UserProfile> ensureProfile({String? preferredName}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('Aktif oturum bulunamadı');
    }

    try {
      final docRef = _firestore.collection('profiles').doc(user.uid);
      final snapshot = await docRef.get();

      if (snapshot.exists) {
        final data = snapshot.data() ?? {};
        final profile = UserProfile(
          name: (data['name'] as String?) ?? (user.displayName ?? 'Kullanıcı'),
          username:
              (data['username'] as String?) ??
              (user.displayName ?? 'Kullanıcı'),
          createdAt:
              DateTime.tryParse(data['createdAt'] as String? ?? '') ??
              DateTime.now(),
          profileImagePath: data['profileImagePath'] as String?,
          colorValue: (data['colorValue'] as int?) ?? 0xFF2196F3,
          email: user.email ?? (data['email'] as String? ?? ''),
        );
        await _storage.saveUserProfile(profile);
        return profile;
      }

      final now = DateTime.now();
      final profile = UserProfile(
        name: preferredName ?? user.displayName ?? 'Kullanıcı',
        username: preferredName ?? user.displayName ?? 'Kullanıcı',
        createdAt: now,
        email: user.email ?? '',
      );

      await docRef.set({
        'name': profile.name,
        'createdAt': now.toIso8601String(),
        'email': profile.email,
        'colorValue': profile.colorValue,
      });

      await _storage.saveUserProfile(profile);
      return profile;
    } catch (_) {
      final fallback = UserProfile(
        name: preferredName ?? user.displayName ?? 'Kullanıcı',
        username: preferredName ?? user.displayName ?? 'Kullanıcı',
        createdAt: DateTime.now(),
        email: user.email ?? '',
      );
      await _storage.saveUserProfile(fallback);
      return fallback;
    }
  }
}
