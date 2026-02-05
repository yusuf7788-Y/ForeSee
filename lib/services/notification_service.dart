import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  bool _isInitialized = false;
  bool _isTimeZoneInitialized = false;

  Future<void> initialize() async {
    if (_isInitialized) return;

    _ensureTimeZoneInitialized();

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (details) {
        // Bildirime tıklandığında yapılacak işlemler
      },
    );

    _isInitialized = true;
  }

  void _ensureTimeZoneInitialized() {
    if (_isTimeZoneInitialized) return;

    try {
      tz.initializeTimeZones();

      final currentOffset = DateTime.now().timeZoneOffset;
      tz.Location? matchedLocation;

      for (final location in tz.timeZoneDatabase.locations.values) {
        final now = tz.TZDateTime.now(location);
        if (now.timeZoneOffset == currentOffset) {
          matchedLocation = location;
          break;
        }
      }

      if (matchedLocation != null) {
        tz.setLocalLocation(matchedLocation);
      }
    } catch (_) {
      // Herhangi bir hata olursa varsayılan (UTC) ile devam et
    }

    _isTimeZoneInitialized = true;
  }

  Future<void> showContextualSuggestion(
    String suggestion,
    String context,
  ) async {
    if (!_isInitialized) {
      await initialize();
    }

    const androidDetails = AndroidNotificationDetails(
      'foresee_contextual_suggestions',
      'Akıllı Öneriler',
      channelDescription:
          'Diğer uygulamaları kullanırken proaktif öneriler sunar.',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(
      1, // Farklı bir ID
      'ForeSee bir fikir buldu!',
      suggestion,
      notificationDetails,
      payload: 'contextual_suggestion:$context',
    );
  }

  Future<void> showAIResponseNotification(String message) async {
    if (!_isInitialized) {
      await initialize();
    }

    // Mesajın ilk satırını al (maksimum 100 karakter)
    String firstLine = message.split('\n').first;
    if (firstLine.length > 100) {
      firstLine = '${firstLine.substring(0, 100)}...';
    }

    const androidDetails = AndroidNotificationDetails(
      'foresee_ai_responses',
      'AI Cevapları',
      channelDescription: 'ForeSee AI cevap bildirimleri',
      importance: Importance.high,
      priority: Priority.high,
      styleInformation: BigTextStyleInformation(''),
      icon: '@mipmap/ic_launcher',
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(
      0,
      'ForeSee size cevap verdi: ${firstLine.length > 30 ? '${firstLine.substring(0, 30)}...' : firstLine}',
      message, // Full message in body (or summary)
      notificationDetails,
    );
  }

  Future<void> scheduleReminder(DateTime dateTime, String message) async {
    if (!_isInitialized) {
      await initialize();
    }

    // Geçmiş bir zamana istek gelirse, güvenli tarafta kalmak için hemen göster
    final now = DateTime.now();
    if (dateTime.isBefore(now.add(const Duration(seconds: 5)))) {
      await _notifications.show(
        dateTime.millisecondsSinceEpoch ~/ 1000,
        'Hatırlatma',
        message,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'foresee_reminders',
            'Hatırlatıcılar',
            channelDescription: 'Kullanıcı hatırlatıcı bildirimleri',
            importance: Importance.high,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
      );
      return;
    }

    final scheduled = tz.TZDateTime.from(dateTime, tz.local);

    const androidDetails = AndroidNotificationDetails(
      'foresee_reminders',
      'Hatırlatıcılar',
      channelDescription: 'Kullanıcı hatırlatıcı bildirimleri',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    final id = scheduled.millisecondsSinceEpoch ~/ 1000;

    await _notifications.zonedSchedule(
      id,
      'Hatırlatma',
      message,
      scheduled,
      notificationDetails,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  Future<void> showOverlayTodoStarted(String title) async {
    if (!_isInitialized) {
      await initialize();
    }

    const androidDetails = AndroidNotificationDetails(
      'foresee_overlay_todo_started',
      'ForeSee Görev Başlatma',
      channelDescription: 'Overlay TODO başladığında kısa bildirim',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: false,
      presentSound: true,
    );

    const notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    const int notificationId = 1001;

    await _notifications.show(
      notificationId,
      'ForeSee TODO başlattı',
      'Bu görevi yaparken uygulamadan çıkabilirsiniz, size haber vereceğiz.',
      notificationDetails,
    );

    // 1 saniye sonra bildirimi otomatik kapat
    Future.delayed(const Duration(seconds: 1), () {
      _notifications.cancel(notificationId);
    });
  }

  Future<void> showOverlayTodoFinished(String title) async {
    if (!_isInitialized) {
      await initialize();
    }

    const androidDetails = AndroidNotificationDetails(
      'foresee_overlay_todo_finished',
      'ForeSee Görev Tamamlama',
      channelDescription: 'Overlay TODO tamamlandığında bildirim',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(
      1002,
      'ForeSee görevi bitirdi',
      title,
      notificationDetails,
    );
  }

  Future<void> showRecoveryNotification(
    String deviceName,
    int chatCount,
  ) async {
    if (!_isInitialized) {
      await initialize();
    }

    const androidDetails = AndroidNotificationDetails(
      'foresee_account_recovery',
      'Hesap Kurtarma',
      channelDescription: 'Eski hesap bulunduğunda bildirim',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(
      2001,
      'Eski hesabını bulduk!',
      '$deviceName cihazından $chatCount sohbetli bir yedek bulundu. Geri dönmek için tıklayın.',
      notificationDetails,
    );
  }

  Future<void> requestPermissions() async {
    if (!_isInitialized) {
      await initialize();
    }

    // Android 13+ için bildirim izni
    await _notifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();

    // iOS için bildirim izni
    await _notifications
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >()
        ?.requestPermissions(alert: true, badge: true, sound: true);
  }
}
