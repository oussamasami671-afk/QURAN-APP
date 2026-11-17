import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:quran_app/core/services/notification_service.dart';

/// Schedules adhan notifications for the next [daysAhead] days,
/// independent of any screen.
class PrayerScheduler with WidgetsBindingObserver {
  PrayerScheduler._();

  static final PrayerScheduler instance = PrayerScheduler._();

  static const int daysAhead = 14;
  static const Duration _minInterval = Duration(hours: 6);

  // Arabic names written as unicode escapes (safe for any terminal encoding).
  static const List<(String, String)> _prayers = [
    ('Fajr', '\u0627\u0644\u0641\u062C\u0631'),
    ('Dhuhr', '\u0627\u0644\u0638\u0647\u0631'),
    ('Asr', '\u0627\u0644\u0639\u0635\u0631'),
    ('Maghrib', '\u0627\u0644\u0645\u063A\u0631\u0628'),
    ('Isha', '\u0627\u0644\u0639\u0634\u0627\u0621'),
  ];

  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
    ),
  );

  Future<void> _queue = Future.value();
  bool _started = false;

  void start() {
    if (_started) return;
    _started = true;

    WidgetsBinding.instance.addObserver(this);

    Connectivity().onConnectivityChanged.listen((results) {
      if (!results.contains(ConnectivityResult.none)) {
        refresh();
      }
    });

    refresh();
    Future.delayed(const Duration(seconds: 2), _askPermissionsOnce);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) refresh();
  }

  Future<void> _askPermissionsOnce() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool('perm_requested_v1') == true) return;
      await prefs.setBool('perm_requested_v1', true);
      await NotificationService.instance.requestPermissions();
    } catch (_) {}
  }

  /// Safe to call often: runs are serialized and throttled unless [force].
  Future<void> refresh({
    bool force = false,
    double? latitude,
    double? longitude,
  }) {
    final next = _queue.then(
      (_) => _run(force: force, latitude: latitude, longitude: longitude),
    );
    _queue = next.catchError((_) {});
    return next;
  }

  Future<void> _run({
    required bool force,
    double? latitude,
    double? longitude,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final now = DateTime.now();

      final last = prefs.getInt('sched_last_sync') ?? 0;
      if (!force &&
          now.millisecondsSinceEpoch - last < _minInterval.inMilliseconds) {
        return;
      }

      var lat = latitude;
      var lon = longitude;

      if (lat == null || lon == null) {
        final useCurrent =
            prefs.getBool('prayer_use_current_location') ?? true;
        if (useCurrent) {
          final position = await _tryPosition();
          lat = position?.latitude;
          lon = position?.longitude;
        }
        lat ??= prefs.getDouble('sched_lat');
        lon ??= prefs.getDouble('sched_lon');
      }

      if (lat == null || lon == null) return;

      final times = await _fetchRange(lat, lon, now);
      if (times.isEmpty) return;

      await prefs.setDouble('sched_lat', lat);
      await prefs.setDouble('sched_lon', lon);

      await _schedule(prefs, times, now);

      await prefs.setInt(
        'sched_last_sync',
        DateTime.now().millisecondsSinceEpoch,
      );
    } catch (_) {
      // No internet or no location: keep what is already scheduled.
    }
  }

  Future<Position?> _tryPosition() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return null;

      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return null;
      }

      final lastKnown = await Geolocator.getLastKnownPosition();

      try {
        return await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.low,
            timeLimit: Duration(seconds: 15),
          ),
        );
      } catch (_) {
        return lastKnown;
      }
    } catch (_) {
      return null;
    }
  }

  String _dateKey(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-${d.year}';

  Future<Map<String, Map<String, String>>> _fetchRange(
    double lat,
    double lon,
    DateTime from,
  ) async {
    final months = <(int, int)>{};
    for (var i = 0; i < daysAhead; i++) {
      final d = DateTime(from.year, from.month, from.day + i);
      months.add((d.year, d.month));
    }

    final result = <String, Map<String, String>>{};

    for (final (year, month) in months) {
      final response = await _dio.get(
        'https://api.aladhan.com/v1/calendar/$year/$month',
        queryParameters: {
          'latitude': lat,
          'longitude': lon,
          'method': 19,
          'school': 0,
        },
      );

      final days = response.data['data'] as List;
      for (final item in days) {
        final key = item['date']['gregorian']['date'].toString();
        final timings = item['timings'] as Map;
        result[key] = {
          for (final p in _prayers)
            p.$1: timings[p.$1].toString().split(' ').first,
        };
      }
    }

    return result;
  }

  // Same id scheme used before, so old notifications get replaced.
  int _id(DateTime date, int index) {
    return (date.year % 100) * 1000000 +
        date.month * 10000 +
        date.day * 100 +
        index +
        1;
  }

  Future<void> _schedule(
    SharedPreferences prefs,
    Map<String, Map<String, String>> times,
    DateTime now,
  ) async {
    final service = NotificationService.instance;

    for (var d = 0; d < daysAhead; d++) {
      final day = DateTime(now.year, now.month, now.day + d);
      final dayTimes = times[_dateKey(day)];
      if (dayTimes == null) continue;

      for (var i = 0; i < _prayers.length; i++) {
        final key = _prayers[i].$1;
        final name = _prayers[i].$2;
        final id = _id(day, i);

        await service.cancel(id);

        if (!(prefs.getBool('adhan_enabled_$key') ?? true)) continue;

        final raw = dayTimes[key];
        if (raw == null) continue;

        final parts = raw.split(':');
        await service.schedulePrayer(
          id: id,
          prayerName: name,
          prayerTime: DateTime(
            day.year,
            day.month,
            day.day,
            int.parse(parts[0]),
            int.parse(parts[1]),
          ),
        );
      }
    }
  }
}