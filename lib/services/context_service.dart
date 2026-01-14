import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:io';
import 'package:android_intent_plus/android_intent.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:geolocator/geolocator.dart';

class ContextService {
  static final ContextService _instance = ContextService._internal();
  factory ContextService() => _instance;

  static const _accessibilityChannel = MethodChannel('com.example.foresee/accessibility');
  static const _usageTrackerChannel = MethodChannel('com.example.foresee/usage_tracker');
  final _controller = StreamController<String>.broadcast();

  Stream<String> get onScreenContentChanged => _controller.stream;

  ContextService._internal() {
    _accessibilityChannel.setMethodCallHandler(_handleMethodCall);
  }

  Future<void> _handleMethodCall(MethodCall call) async {
    if (call.method == 'onScreenContent') {
      final content = call.arguments as String?;
      if (content != null) {
        _controller.add(content);
      }
    }
  }

  Future<bool> hasUsageStatsPermission() async {
    return await _usageTrackerChannel.invokeMethod('hasUsageStatsPermission') ?? false;
  }

  Future<void> requestUsageStatsPermission() async {
    await _usageTrackerChannel.invokeMethod('requestUsageStatsPermission');
  }

  Future<void> startUsageTrackerService({int timeThresholdMinutes = 90}) async {
    await _usageTrackerChannel.invokeMethod('startUsageTracker', {'timeThreshold': timeThresholdMinutes * 60 * 1000});
  }

  Future<void> stopUsageTrackerService() async {
    await _usageTrackerChannel.invokeMethod('stopUsageTracker');
  }

  Future<void> openAccessibilitySettings() async {
    if (Platform.isAndroid) {
      const intent = AndroidIntent(
        action: 'android.settings.ACCESSIBILITY_SETTINGS',
      );
      await intent.launch();
    }
  }

  // Tarih bilgisini al
  String getCurrentDateInfo() {
    final now = DateTime.now();
    final months = [
      'Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran',
      'Temmuz', 'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık'
    ];
    
    return 'Şu anki tarih: ${now.day} ${months[now.month - 1]} ${now.year}, ${now.hour}:${now.minute.toString().padLeft(2, '0')}';
  }

  // Konum bilgisini al
  Future<String?> getCurrentLocation() async {
    try {
      // İzin kontrolü
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return null; // İzin reddedildi
        }
      }

      if (permission == LocationPermission.deniedForever) {
        return null; // İzin kalıcı olarak reddedildi
      }

      // Konum servisleri açık mı kontrol et
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return null; // Konum servisleri kapalı
      }

      // Konumu al
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 5),
      );

      // Konum bilgisini döndür (koordinatlar)
      return 'Kullanıcının konumu: ${position.latitude.toStringAsFixed(6)}, ${position.longitude.toStringAsFixed(6)}';
    } catch (e) {
      print('Konum hatası: $e');
      return null;
    }
  }

  // İzinleri kontrol et ve iste
  Future<Map<String, bool>> checkPermissions() async {
    final calendar = await Permission.calendar.status;
    final location = await Permission.location.status;
    final contacts = await Permission.contacts.status;

    return {
      'calendar': calendar.isGranted,
      'location': location.isGranted,
      'contacts': contacts.isGranted,
    };
  }

  Future<bool> requestCalendarPermission() async {
    final status = await Permission.calendar.request();
    return status.isGranted;
  }

  Future<bool> requestLocationPermission() async {
    final status = await Permission.location.request();
    return status.isGranted;
  }

  Future<bool> requestContactsPermission() async {
    final status = await Permission.contacts.request();
    return status.isGranted;
  }
}

