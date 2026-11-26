import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
  FlutterLocalNotificationsPlugin();

  // Notification IDs untuk tracking
  static const int _tisuNotificationId = 1;
  static const int _sampahNotificationId = 2;
  static const int _generalNotificationId = 0;

  // Channel IDs
  static const String _criticalChannelId = 'sanova_critical';
  static const String _generalChannelId = 'sanova_general';

  static Future<void> initialize() async {
    const AndroidInitializationSettings androidSettings =
    AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings settings =
    InitializationSettings(android: androidSettings);

    await _notificationsPlugin.initialize(settings);

    // Create notification channels
    await _createNotificationChannels();
  }

  static Future<void> _createNotificationChannels() async {
    // Critical notifications channel (untuk tisu habis, sampah penuh)
    const AndroidNotificationChannel criticalChannel = AndroidNotificationChannel(
      _criticalChannelId,
      'Critical Alerts',
      description: 'Critical alerts for tissue and trash status',
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
    );

    // General notifications channel
    const AndroidNotificationChannel generalChannel = AndroidNotificationChannel(
      _generalChannelId,
      'General Notifications',
      description: 'General app notifications',
      importance: Importance.defaultImportance,
    );

    await _notificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(criticalChannel);

    await _notificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(generalChannel);
  }

  // Generic notification method
  static Future<void> showNotification(String title, String body, {bool isCritical = false}) async {
    final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      isCritical ? _criticalChannelId : _generalChannelId,
      isCritical ? 'Critical Alerts' : 'General Notifications',
      importance: isCritical ? Importance.max : Importance.defaultImportance,
      priority: isCritical ? Priority.high : Priority.defaultPriority,
      playSound: true,
      enableVibration: isCritical,
      icon: '@mipmap/ic_launcher',
    );

    final NotificationDetails notificationDetails =
    NotificationDetails(android: androidDetails);

    await _notificationsPlugin.show(
        _generalNotificationId,
        title,
        body,
        notificationDetails
    );
  }

  // Specific method untuk tissue critical
  static Future<void> showTisuCriticalNotification(double percentage) async {
    final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      _criticalChannelId,
      'Critical Alerts',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      icon: '@mipmap/ic_launcher', // Menggunakan default icon yang pasti ada
      color: const Color(0xFFFF5722), // Red color
    );

    final NotificationDetails notificationDetails =
    NotificationDetails(android: androidDetails);

    await _notificationsPlugin.show(
      _tisuNotificationId,
      '🧻 Tissue Hampir Habis!',
      'Sisa ${percentage.toInt()}%. Segera isi ulang dispenser tissue.',
      notificationDetails,
    );
  }

  // Specific method untuk sampah critical
  static Future<void> showSampahCriticalNotification(double percentage) async {
    final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      _criticalChannelId,
      'Critical Alerts',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      icon: '@mipmap/ic_launcher', // Menggunakan default icon yang pasti ada
      color: const Color(0xFF795548), // Brown color
    );

    final NotificationDetails notificationDetails =
    NotificationDetails(android: androidDetails);

    await _notificationsPlugin.show(
      _sampahNotificationId,
      '🗑️ Tempat Sampah Penuh!',
      'Kapasitas ${percentage.toInt()}%. Segera kosongkan tempat sampah.',
      notificationDetails,
    );
  }

  // Method untuk clear notifications
  static Future<void> clearTisuNotification() async {
    await _notificationsPlugin.cancel(_tisuNotificationId);
  }

  static Future<void> clearSampahNotification() async {
    await _notificationsPlugin.cancel(_sampahNotificationId);
  }

  static Future<void> clearAllNotifications() async {
    await _notificationsPlugin.cancelAll();
  }

  // Method untuk check permission (Android 13+)
  static Future<bool> requestPermission() async {
    final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
    _notificationsPlugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    if (androidImplementation != null) {
      // Check if the method exists (for newer versions of the plugin)
      try {
        final bool? granted = await androidImplementation.requestNotificationsPermission();
        return granted ?? false;
      } catch (e) {
        // Fallback for older plugin versions
        print('Permission request method not available: $e');
        return true; // Assume permission is granted for older Android versions
      }
    }
    return false;
  }

  // Method untuk check apakah notifications enabled
  static Future<bool> areNotificationsEnabled() async {
    final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
    _notificationsPlugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    if (androidImplementation != null) {
      try {
        final bool? enabled = await androidImplementation.areNotificationsEnabled();
        return enabled ?? false;
      } catch (e) {
        // Fallback for older plugin versions
        print('Notification check method not available: $e');
        return true; // Assume notifications are enabled
      }
    }
    return false;
  }
}