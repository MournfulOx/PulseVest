import 'dart:io';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:shared_preferences/shared_preferences.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  bool get _isPlatformSupported => Platform.isAndroid || Platform.isIOS;

  Future<void> initialize() async {
    if (_initialized) return;
    if (!_isPlatformSupported) {
      _initialized = true;
      return;
    }

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    await _plugin.initialize(
      const InitializationSettings(android: androidSettings, iOS: iosSettings),
    );
    _initialized = true;
  }

  Future<void> scheduleMonthlyReminder(int dayOfMonth) async {
    await initialize();
    if (!_isPlatformSupported) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('reminder_day', dayOfMonth);
      await prefs.setBool('reminder_enabled', true);
      return;
    }
    await _plugin.cancelAll();

    final now = tz.TZDateTime.now(tz.local);
    var scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      dayOfMonth,
      9,
      0,
    );

    if (scheduledDate.isBefore(now)) {
      scheduledDate = tz.TZDateTime(
        tz.local,
        now.year,
        now.month + 1,
        dayOfMonth,
        9,
        0,
      );
    }

    await _plugin.zonedSchedule(
      1,
      '📈 定投提醒',
      '今天是你的定投日！打开App查看计划并完成投入。',
      scheduledDate,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'dca_reminder',
          '定投提醒',
          channelDescription: '每月定投提醒通知',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.dayOfMonthAndTime,
    );

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('reminder_day', dayOfMonth);
    await prefs.setBool('reminder_enabled', true);
  }

  Future<void> cancelReminder() async {
    if (_isPlatformSupported) await _plugin.cancelAll();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('reminder_enabled', false);
  }

  Future<bool> isReminderEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('reminder_enabled') ?? false;
  }

  Future<int> getReminderDay() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('reminder_day') ?? 1;
  }
}
