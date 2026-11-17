import 'package:flutter/material.dart';

import 'core/app_settings.dart';
import 'core/services/notification_service.dart';
import 'core/services/prayer_scheduler.dart';
import 'app/quran_app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await appSettings.load();
  await NotificationService.instance.initialize();

  runApp(const QuranApp());

  PrayerScheduler.instance.start();
}