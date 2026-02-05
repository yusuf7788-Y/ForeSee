import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'storage_service.dart';
import '../models/chat.dart';
import '../models/user_profile.dart';
import '../models/player_inventory.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'dart:io';

class CloudBackupService {
  CloudBackupService._();
  static final CloudBackupService instance = CloudBackupService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final StorageService _storageService = StorageService();

  Future<void> backupData({
    required Function(double progress, String status) onProgress,
    bool isAuto = false,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      debugPrint('DEBUG: Backup failed - No Firebase user found');
      throw Exception('Yedekleme için giriş yapmalısınız.');
    }
    debugPrint('DEBUG: Starting backup for UID: ${user.uid}');

    try {
      onProgress(0.05, 'Veriler hazırlanıyor...');
      final chats = await _storageService.loadChats();
      final userProfile = await _storageService.loadUserProfile();
      final memory = await _storageService.getUserMemory();
      final prompt = await _storageService.getCustomPrompt();
      final inventory = await _storageService.loadPlayerInventory();

      // Device Info
      String deviceName = 'Unknown Device';
      final deviceInfo = DeviceInfoPlugin();
      try {
        if (kIsWeb) {
          deviceName = 'Web Browser';
        } else if (Platform.isAndroid) {
          final androidInfo = await deviceInfo.androidInfo;
          deviceName = '${androidInfo.brand} ${androidInfo.model}';
        } else if (Platform.isIOS) {
          final iosInfo = await deviceInfo.iosInfo;
          deviceName = iosInfo.utsname.machine;
        } else if (Platform.isWindows) {
          final windowsInfo = await deviceInfo.windowsInfo;
          deviceName = windowsInfo.computerName;
        }
      } catch (_) {}

      final now = DateTime.now();
      final backupId =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}-${now.minute.toString().padLeft(2, '0')}';

      final userBackupsRef = _firestore
          .collection('users')
          .doc(user.uid)
          .collection('backups');

      final latestRef = userBackupsRef.doc('latest');
      final versionRef = userBackupsRef.doc(backupId);

      onProgress(0.15, 'Ayarlar yükleniyor...');
      final manifest = {
        'id': backupId,
        'timestamp': FieldValue.serverTimestamp(),
        'deviceName': deviceName,
        'chatCount': chats.length,
        'appVersion': '1.0.0',
        'profile': userProfile?.toJson(),
        'memory': memory,
        'customPrompt': prompt,
        'inventory': inventory.toJson(),
        'isAuto': isAuto,
        'settings': {
          'themeIndex': await _storageService.getThemeIndex(),
          'fontSizeIndex': await _storageService.getFontSizeIndex(),
          'notificationsEnabled': await _storageService
              .getNotificationsEnabled(),
          'isSmartContextEnabled': await _storageService
              .getIsSmartContextEnabled(),
        },
      };

      await latestRef.set(manifest);
      await versionRef.set(manifest);

      onProgress(0.25, 'Sohbetler yedekleniyor...');

      final latestChatsCollection = latestRef.collection('chats');
      final versionChatsCollection = versionRef.collection('chats');

      int batchOperations = 0;
      int estimatedBatchBytes = 0;
      WriteBatch batch = _firestore.batch();

      for (int i = 0; i < chats.length; i++) {
        final chat = chats[i];
        if (chat.id.isEmpty) continue;

        final chatData = chat.toJson();
        // Rough estimate of serialized size
        final int chatSizeBytes = chatData.toString().length;

        // Safety check: Firestore document limit is 1 MiB (1,048,576 bytes)
        if (chatSizeBytes > 1000000) {
          debugPrint('Sohbet limit dışı (1MB+), atlanıyor: ${chat.title}');
          continue;
        }

        // Firestore limits: 500 operations per batch, 10 MiB payload limit.
        // We use 400 ops and 5 MiB as conservative triggers for maximum speed with safety.
        if (batchOperations + 2 > 400 ||
            estimatedBatchBytes + (chatSizeBytes * 2) > 5000000) {
          await batch.commit();
          batch = _firestore.batch();
          batchOperations = 0;
          estimatedBatchBytes = 0;
          double p = 0.25 + (0.7 * (i / chats.length));
          onProgress(p, 'Sohbetler yedekleniyor (${i + 1}/${chats.length})...');
        }

        batch.set(latestChatsCollection.doc(chat.id), chatData);
        batch.set(versionChatsCollection.doc(chat.id), chatData);

        batchOperations += 2;
        estimatedBatchBytes += (chatSizeBytes * 2);
      }

      if (batchOperations > 0) {
        await batch.commit();
      }

      onProgress(1.0, 'Yedekleme tamamlandı.');
    } catch (e) {
      throw Exception('Yedekleme başarısız: $e');
    }
  }

  Future<void> restoreData({
    required Function(double progress, String status) onProgress,
    String? backupId,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Geri yükleme için giriş yapmalısınız.');

    try {
      onProgress(0.1, 'Yedek aranıyor...');
      final backupRef = _firestore
          .collection('users')
          .doc(user.uid)
          .collection('backups')
          .doc(backupId ?? 'latest');

      final docSnap = await backupRef.get();
      if (!docSnap.exists) {
        throw Exception('Kayıtlı yedek bulunamadı.');
      }

      final data = docSnap.data()!;
      await _restoreFromData(data, backupRef, onProgress);
    } catch (e) {
      throw Exception('Geri yükleme başarısız: $e');
    }
  }

  Future<DateTime?> getLastBackupTime() async {
    final user = _auth.currentUser;
    if (user == null) return null;

    final doc = await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('backups')
        .doc('latest')
        .get();

    if (doc.exists && doc.data() != null) {
      final ts = doc.data()!['timestamp'];
      if (ts is Timestamp) return ts.toDate();
    }
    return null;
  }

  Future<Map<String, dynamic>?> checkExistingBackup(String name) async {
    try {
      // Search for any user who has a profile name matching 'name'
      // This is a simple heuristic for recovery.
      final query = await _firestore
          .collection('users')
          .where('profile.name', isEqualTo: name)
          .limit(1)
          .get();

      if (query.docs.isNotEmpty) {
        final userDoc = query.docs.first;
        final backupSnap = await userDoc.reference
            .collection('backups')
            .doc('latest')
            .get();
        if (backupSnap.exists) {
          return {'uid': userDoc.id, 'data': backupSnap.data()};
        }
      }
    } catch (e) {
      debugPrint('Error checking existing backup: $e');
    }
    return null;
  }

  Future<void> restoreDataFromSpecificUid(
    String uid, {
    required Function(double progress, String status) onProgress,
    String? backupId,
  }) async {
    try {
      onProgress(0.1, 'Yedek aranıyor...');
      final backupRef = _firestore
          .collection('users')
          .doc(uid)
          .collection('backups')
          .doc(backupId ?? 'latest');

      final docSnap = await backupRef.get();
      if (!docSnap.exists) throw Exception('Yedek bulunamadı.');

      final data = docSnap.data()!;
      await _restoreFromData(data, backupRef, onProgress);
    } catch (e) {
      throw Exception('Geri yükleme başarısız: $e');
    }
  }

  Future<void> _restoreFromData(
    Map<String, dynamic> data,
    DocumentReference backupRef,
    Function(double progress, String status) onProgress,
  ) async {
    // 1. Ayarları Geri Yükle
    onProgress(0.3, 'Ayarlar geri yükleniyor...');

    if (data['profile'] != null) {
      await _storageService.saveUserProfile(
        UserProfile.fromJson(data['profile']),
      );
    }

    if (data['memory'] != null) {
      await _storageService.saveUserMemory(data['memory']);
    }

    if (data['customPrompt'] != null) {
      await _storageService.saveCustomPrompt(data['customPrompt']);
    }

    if (data['inventory'] != null) {
      final invParams = data['inventory'] as Map<String, dynamic>;
      await _storageService.savePlayerInventory(
        PlayerInventory.fromJson(invParams),
      );
    }

    final settings = data['settings'] as Map<String, dynamic>?;
    if (settings != null) {
      if (settings['themeIndex'] != null)
        await _storageService.setThemeIndex(settings['themeIndex']);
      if (settings['fontSizeIndex'] != null)
        await _storageService.setFontSizeIndex(settings['fontSizeIndex']);
      if (settings['notificationsEnabled'] != null)
        await _storageService.setNotificationsEnabled(
          settings['notificationsEnabled'],
        );
      if (settings['isSmartContextEnabled'] != null)
        await _storageService.saveIsSmartContextEnabled(
          settings['isSmartContextEnabled'],
        );
    }

    // 2. Sohbetleri Geri Yükle (TEMİZ GERİ YÜKLEME - ÜZERİNE YAZMA)
    onProgress(0.6, 'Sohbetler indiriliyor...');
    final chatsQuery = await backupRef.collection('chats').get();
    final List<Chat> restoredChats = [];

    for (var doc in chatsQuery.docs) {
      try {
        restoredChats.add(Chat.fromJson(doc.data()));
      } catch (e) {
        print('Sohbet parse hatası (${doc.id}): $e');
      }
    }

    // Tarihe göre sırala
    restoredChats.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

    // Yerel veriyi tamamen silip yerine yedeği yaz (Merge yerine Overwrite)
    await _storageService.saveChats(restoredChats);
  }

  Future<List<Map<String, dynamic>>> listBackups() async {
    final user = _auth.currentUser;
    if (user == null) return [];

    try {
      final query = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('backups')
          .where('id', isNotEqualTo: null)
          .orderBy('timestamp', descending: true)
          .get();

      return query.docs.map((doc) => doc.data()).toList();
    } catch (e) {
      debugPrint('Error listing backups: $e');
      return [];
    }
  }
}
