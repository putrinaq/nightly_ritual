import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:shared_preferences/shared_preferences.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  static const int _reminderNotificationId = 1;
  static const String _channelId = 'nightly_ritual_reminders';
  static const String _channelName = 'Ritual Reminders';
  static const String _channelDescription =
      'Daily reminders for your nightly ritual';

  bool _isInitialized = false;

  Future<void> init() async {
    if (_isInitialized) return;

    // Initialize timezone
    tz_data.initializeTimeZones();

    // Android settings
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');

    // iOS/macOS settings
    const darwinSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: darwinSettings,
      macOS: darwinSettings,
    );

    await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Create notification channel for Android
    await _createNotificationChannel();

    _isInitialized = true;
  }

  Future<void> _createNotificationChannel() async {
    const androidChannel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: _channelDescription,
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
    );

    await _notifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(androidChannel);
  }

  void _onNotificationTapped(NotificationResponse response) {
    debugPrint('Notification tapped: ${response.payload}');
    // App will open automatically when notification is tapped
  }

  // Request notification permissions
  Future<bool> requestPermissions() async {
    // Skip permission check on web - notifications not supported
    if (kIsWeb) {
      debugPrint('Notifications not supported on web');
      return false;
    }

    try {
      // For Android 13+, request permission through the plugin
      final androidPlugin = _notifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      if (androidPlugin != null) {
        final granted = await androidPlugin.requestNotificationsPermission();
        return granted ?? true;
      }

      // For iOS, request permission through the plugin
      final iosPlugin = _notifications
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>();
      if (iosPlugin != null) {
        final granted = await iosPlugin.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
        return granted ?? false;
      }

      // For other platforms, assume granted
      return true;
    } catch (e) {
      debugPrint('Error requesting permissions: $e');
      return false;
    }
  }

  // Schedule daily reminder at specified time
  Future<bool> scheduleReminderAt(int hour, int minute) async {
    // Notifications not supported on web
    if (kIsWeb) {
      debugPrint('Notifications not supported on web');
      return false;
    }

    try {
      // Request permissions first
      final hasPermission = await requestPermissions();
      if (!hasPermission) {
        debugPrint('Notification permission denied');
        return false;
      }

      // Cancel any existing reminder
      await cancelReminder();

      // Calculate next occurrence of the specified time
      final now = tz.TZDateTime.now(tz.local);
      var scheduledDate = tz.TZDateTime(
        tz.local,
        now.year,
        now.month,
        now.day,
        hour,
        minute,
      );

      // If the time has already passed today, schedule for tomorrow
      if (scheduledDate.isBefore(now)) {
        scheduledDate = scheduledDate.add(const Duration(days: 1));
      }

      // Notification details
      const androidDetails = AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDescription,
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
        largeIcon: DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
        styleInformation: BigTextStyleInformation(
          'The moon awaits. Take a moment to align your energy and manifest your intentions.',
          contentTitle: '🌙 Time for Your Nightly Ritual',
          summaryText: 'Nightly Ritual',
        ),
      );

      const darwinDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      const notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: darwinDetails,
        macOS: darwinDetails,
      );

      // Schedule the notification to repeat daily
      await _notifications.zonedSchedule(
        _reminderNotificationId,
        '🌙 Time for Your Nightly Ritual',
        'The moon awaits. Tap to begin your manifestation.',
        scheduledDate,
        notificationDetails,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time, // Repeat daily
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );

      debugPrint('Reminder scheduled for $hour:${minute.toString().padLeft(2, '0')}');
      return true;
    } catch (e) {
      debugPrint('Error scheduling reminder: $e');
      return false;
    }
  }

  // Cancel the reminder
  Future<void> cancelReminder() async {
    await _notifications.cancel(_reminderNotificationId);
    debugPrint('Reminder cancelled');
  }

  // Check if there's a pending reminder
  Future<bool> hasActiveReminder() async {
    final pendingNotifications =
        await _notifications.pendingNotificationRequests();
    return pendingNotifications
        .any((n) => n.id == _reminderNotificationId);
  }

  // Show a test notification immediately
  Future<void> showTestNotification() async {
    const androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDescription,
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );

    const darwinDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: darwinDetails,
      macOS: darwinDetails,
    );

    await _notifications.show(
      0,
      '🌙 Nightly Ritual',
      'Your reminder is set! This is a test notification.',
      notificationDetails,
    );
  }
}

// Helper class for reminder storage preferences
class ReminderPreferences {
  static const String _reminderEnabledKey = 'reminder_enabled';
  static const String _reminderHourKey = 'reminder_hour';
  static const String _reminderMinuteKey = 'reminder_minute';

  final SharedPreferences _prefs;

  ReminderPreferences(this._prefs);

  bool get isEnabled => _prefs.getBool(_reminderEnabledKey) ?? false;

  int get hour => _prefs.getInt(_reminderHourKey) ?? 21; // Default 9 PM

  int get minute => _prefs.getInt(_reminderMinuteKey) ?? 0;

  Future<void> setEnabled(bool enabled) async {
    await _prefs.setBool(_reminderEnabledKey, enabled);
  }

  Future<void> setTime(int hour, int minute) async {
    await _prefs.setInt(_reminderHourKey, hour);
    await _prefs.setInt(_reminderMinuteKey, minute);
  }

  String get timeFormatted {
    final h = hour;
    final m = minute;
    final period = h >= 12 ? 'PM' : 'AM';
    final displayHour = h > 12 ? h - 12 : (h == 0 ? 12 : h);
    return '$displayHour:${m.toString().padLeft(2, '0')} $period';
  }

  TimeOfDay get timeOfDay => TimeOfDay(hour: hour, minute: minute);
}
