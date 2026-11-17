import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  void Function(String payload)? _onNotificationTap;
  String? _pendingPayload;

  void setNotificationTapHandler(
    void Function(String payload) handler,
  ) {
    _onNotificationTap = handler;

    final pending = _pendingPayload;
    if (pending != null) {
      _pendingPayload = null;
      handler(pending);
    }
  }

  void _handleNotificationTap(String? payload) {
    if (payload == null || payload.isEmpty) return;

    final handler = _onNotificationTap;

    if (handler != null) {
      handler(payload);
    } else {
      _pendingPayload = payload;
    }
  }

  Future<void> initialize() async {
    if (_initialized) return;

    tz_data.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Africa/Algiers'));

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const settings = InitializationSettings(
      android: androidSettings,
    );

    await _notifications.initialize(
      settings: settings,
      onDidReceiveNotificationResponse: (response) {
        _handleNotificationTap(response.payload);
      },
    );

    final launchDetails =
        await _notifications.getNotificationAppLaunchDetails();

    if (launchDetails?.didNotificationLaunchApp == true) {
      _handleNotificationTap(
        launchDetails?.notificationResponse?.payload,
      );
    }

    _initialized = true;
  }

  Future<void> requestBatteryExemption() async {
    if (await Permission.ignoreBatteryOptimizations.isGranted) return;
    await Permission.ignoreBatteryOptimizations.request();
  }

  Future<void> requestPermissions() async {
    await initialize();

    final android = _notifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    await android?.requestNotificationsPermission();
    await android?.requestExactAlarmsPermission();
    await requestBatteryExemption();
  }

  /// Ø¬Ø¯ÙˆÙ„Ø© Ø¥Ø´Ø¹Ø§Ø± Ù„Ù…Ø±Ø© ÙˆØ§Ø­Ø¯Ø©.
  /// [soundResource]: Ø§Ø³Ù… Ù…Ù„Ù Ø§Ù„ØµÙˆØª Ø¯Ø§Ø®Ù„ android/app/src/main/res/raw
  /// Ø¨Ø¯ÙˆÙ† Ø§Ù„Ø§Ù…ØªØ¯Ø§Ø¯ (Ù…Ø«Ø§Ù„: 'adhan_short').
  Future<void> scheduleNotification({
    required int id,
    required String channelId,
    required String channelName,
    required String channelDescription,
    required String title,
    required String body,
    required DateTime scheduledAt,
    String? payload,
    String? soundResource,
  }) async {
    await initialize();

    final scheduledDate = tz.TZDateTime.from(scheduledAt, tz.local);

    if (!scheduledDate.isAfter(tz.TZDateTime.now(tz.local))) {
      return;
    }

    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        channelId,
        channelName,
        channelDescription: channelDescription,
        importance: Importance.max,
        priority: Priority.max,
        playSound: true,
        sound: soundResource == null
            ? null
            : RawResourceAndroidNotificationSound(soundResource),
        audioAttributesUsage: soundResource == null
            ? AudioAttributesUsage.notification
            : AudioAttributesUsage.alarm,
        enableVibration: true,
        category: AndroidNotificationCategory.alarm,
        styleInformation: BigTextStyleInformation(body),
      ),
    );

    try {
      await _notifications.zonedSchedule(
        id: id,
        title: title,
        body: body,
        scheduledDate: scheduledDate,
        notificationDetails: details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        payload: payload,
      );
    } on PlatformException {
      // Ø¥Ø°Ø§ Ù„Ù… ØªÙÙ…Ù†Ø­ ØµÙ„Ø§Ø­ÙŠØ© Ø§Ù„Ù…Ù†Ø¨Ù‘Ù‡ Ø§Ù„Ø¯Ù‚ÙŠÙ‚ØŒ Ù†Ø±Ø¬Ø¹ Ù„Ù„Ø¬Ø¯ÙˆÙ„Ø© ØºÙŠØ± Ø§Ù„Ø¯Ù‚ÙŠÙ‚Ø©
      // Ø¨Ø¯Ù„ Ø£Ù† ÙŠÙØ´Ù„ Ø§Ù„Ø¥Ø´Ø¹Ø§Ø± ØªÙ…Ø§Ù…Ù‹Ø§.
      await _notifications.zonedSchedule(
        id: id,
        title: title,
        body: body,
        scheduledDate: scheduledDate,
        notificationDetails: details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        payload: payload,
      );
    }
  }

  Future<void> scheduleDaily({
    required int id,
    required String channelId,
    required String channelName,
    required String channelDescription,
    required String title,
    required String body,
    required int hour,
    required int minute,
    String? payload,
  }) async {
    await initialize();

    if (hour < 0 || hour > 23 || minute < 0 || minute > 59) {
      throw ArgumentError('Invalid notification time');
    }

    final now = tz.TZDateTime.now(tz.local);

    var scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );

    if (!scheduledDate.isAfter(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        channelId,
        channelName,
        channelDescription: channelDescription,
        importance: Importance.high,
        priority: Priority.high,
        styleInformation: BigTextStyleInformation(body),
      ),
    );

    await _notifications.zonedSchedule(
      id: id,
      title: title,
      body: body,
      scheduledDate: scheduledDate,
      notificationDetails: details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
      payload: payload,
    );
  }

  Future<void> schedulePrayer({
    required int id,
    required String prayerName,
    required DateTime prayerTime,
  }) async {
    await scheduleNotification(
      id: id,
      // Ù‚Ù†Ø§Ø© Ø¬Ø¯ÙŠØ¯Ø©: Android ÙŠØ«Ø¨Ù‘Øª ØµÙˆØª Ø§Ù„Ù‚Ù†Ø§Ø© Ø¹Ù†Ø¯ Ø¥Ù†Ø´Ø§Ø¦Ù‡Ø§ Ø£ÙˆÙ„ Ù…Ø±Ø©ØŒ
      // ÙÙ„Ø§Ø²Ù… Ø§Ø³Ù… Ø¬Ø¯ÙŠØ¯ Ø­ØªÙ‰ ÙŠÙØ·Ø¨ÙŽÙ‘Ù‚ ØµÙˆØª Ø§Ù„Ø£Ø°Ø§Ù†.
      channelId: 'prayer_adhan_v3',
      channelName: 'Ù…ÙˆØ§Ù‚ÙŠØª Ø§Ù„ØµÙ„Ø§Ø© (Ø§Ù„Ø£Ø°Ø§Ù†)',
      channelDescription: 'ØªÙ†Ø¨ÙŠÙ‡Ø§Øª Ø¯Ø®ÙˆÙ„ ÙˆÙ‚Øª Ø§Ù„ØµÙ„Ø§Ø© Ù…Ø¹ ØµÙˆØª Ø§Ù„Ø£Ø°Ø§Ù†',
      title: 'Ø­Ø§Ù† ÙˆÙ‚Øª ØµÙ„Ø§Ø© $prayerName',
      body: 'Ø­Ø§ÙØ¸ Ø¹Ù„Ù‰ ØµÙ„Ø§ØªÙƒ',
      scheduledAt: prayerTime,
      soundResource: 'adhan_short',
    );
  }

  Future<void> cancel(int id) async {
    await initialize();
    await _notifications.cancel(id: id);
  }

  Future<void> cancelPrayer(int id) async {
    await cancel(id);
  }

  Future<void> cancelAll() async {
    await initialize();
    await _notifications.cancelAll();
  }

  Future<List<PendingNotificationRequest>> getPendingNotifications() async {
    await initialize();
    return _notifications.pendingNotificationRequests();
    }
}
