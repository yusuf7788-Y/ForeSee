import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'storage_service.dart';

/// Firebase Cloud Messaging ile admin bildirimleri
/// Admin Firebase Console'dan veya Cloud Functions ile bildirim gönderebilir
class FCMService {
  static final FCMService _instance = FCMService._internal();
  factory FCMService() => _instance;
  FCMService._internal();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  bool _isInitialized = false;

  Future<void> initialize() async {
    if (_isInitialized) return;

    // Bildirim izinlerini iste
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      // FCM token'ı al ve Firestore'a kaydet
      await _saveTokenToFirestore();

      // Tüm kullanıcıları 'all_users' topic'ine abone et (admin push için)
      await _messaging.subscribeToTopic('all_users');

      // Token yenilendiğinde güncelle
      _messaging.onTokenRefresh.listen(_updateTokenInFirestore);

      // Ön plandayken gelen mesajları dinle
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

      // Arka plandan açılınca
      FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpenedApp);

      // Uygulama kapalıyken gelen mesajla açılınca
      final initialMessage = await _messaging.getInitialMessage();
      if (initialMessage != null) {
        _handleMessageOpenedApp(initialMessage);
      }
    }

    _isInitialized = true;
  }

  /// FCM token'ı Firestore'a kaydet
  Future<void> _saveTokenToFirestore() async {
    try {
      final token = await _messaging.getToken();
      if (token == null) return;

      print('🔔 FCM TOKEN: $token'); // Debug için token'ı göster

      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        // Giriş yapmış kullanıcı için
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'fcmToken': token,
          'lastTokenUpdate': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      } else {
        // Anonim kullanıcılar için genel koleksiyon
        await FirebaseFirestore.instance
            .collection('fcm_tokens')
            .doc(token)
            .set({
              'token': token,
              'createdAt': FieldValue.serverTimestamp(),
              'platform': 'android', // veya Platform.isIOS ? 'ios' : 'android'
            });
      }
    } catch (e) {
      // Token kaydetme hatası - sessizce geç
    }
  }

  /// Token yenilendiğinde güncelle
  Future<void> _updateTokenInFirestore(String token) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .update({
              'fcmToken': token,
              'lastTokenUpdate': FieldValue.serverTimestamp(),
            });
      } else {
        await FirebaseFirestore.instance
            .collection('fcm_tokens')
            .doc(token)
            .set({
              'token': token,
              'createdAt': FieldValue.serverTimestamp(),
              'platform': 'android',
            });
      }
    } catch (e) {
      // Sessizce geç
    }
  }

  /// Ön planda mesaj geldiğinde yerel bildirim göster
  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    // Check if notifications are enabled in settings
    final storage = StorageService();
    if (!await storage.getNotificationsEnabled()) return;

    final notification = message.notification;
    if (notification == null) return;

    const androidDetails = AndroidNotificationDetails(
      'foresee_custom_sound', // New channel ID for custom sound
      'ForeSee Bildirimleri',
      channelDescription: 'ForeSee Bildirimleri',
      importance: Importance.max,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      sound: RawResourceAndroidNotificationSound(
        'notification',
      ), // Custom sound
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      sound: 'notification.wav', // Custom sound for iOS
    );

    const notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      notification.title ?? 'ForeSee',
      notification.body ?? '',
      notificationDetails,
      payload: message.data['action'],
    );
  }

  /// Bildirime tıklandığında
  void _handleMessageOpenedApp(RemoteMessage message) {
    // Burada deep link veya özel aksiyon işlenebilir
    final action = message.data['action'];
    if (action != null) {
      // Örneğin: action == 'open_games' ise oyun hub'a yönlendir
      // Bu GlobalKey veya Navigator ile yapılabilir
    }
  }

  /// Mevcut FCM token'ı al
  Future<String?> getToken() async {
    return await _messaging.getToken();
  }

  /// Belirli bir konuya abone ol (örn: "announcements", "promotions")
  Future<void> subscribeToTopic(String topic) async {
    await _messaging.subscribeToTopic(topic);
  }

  /// Konu aboneliğini iptal et
  Future<void> unsubscribeFromTopic(String topic) async {
    await _messaging.unsubscribeFromTopic(topic);
  }
}
