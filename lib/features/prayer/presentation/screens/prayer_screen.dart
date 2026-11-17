
import 'dart:async';
import 'dart:math' as math;
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:quran_app/features/prayer/data/adhan_controller.dart';
import 'package:quran_app/core/services/notification_service.dart';
import 'package:quran_app/core/services/prayer_scheduler.dart';


class PrayerScreen extends StatefulWidget {
  const PrayerScreen({super.key});

  @override
  State<PrayerScreen> createState() => _PrayerScreenState();
}

class _PrayerScreenState extends State<PrayerScreen> {
  String _tr(BuildContext context, String ar, String en, String fr) {
    switch (Localizations.localeOf(context).languageCode) {
      case 'en':
        return en;
      case 'fr':
        return fr;
      default:
        return ar;
    }
  }

  String _prayerDisplayName(BuildContext context, String name) {
    switch (name) {
      case 'الفجر':
        return _tr(context, 'الفجر', 'Fajr', 'Fajr');
      case 'الظهر':
        return _tr(context, 'الظهر', 'Dhuhr', 'Dhuhr');
      case 'العصر':
        return _tr(context, 'العصر', 'Asr', 'Asr');
      case 'المغرب':
        return _tr(context, 'المغرب', 'Maghrib', 'Maghrib');
      case 'العشاء':
        return _tr(context, 'العشاء', 'Isha', 'Isha');
      default:
        return name;
    }
  }
  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
    ),
  );

  Timer? _timer;

  bool _loading = true;
  bool _useCurrentLocation = true;
  String? _error;

  Map<String, String> _times = {};
  Map<String, String> _tomorrowTimes = {};
  String? _tomorrowFajr;
  double? _qibla;

  String _selectedCity = 'البليدة';
  String _locationLabel = 'موقعي الحالي';
  final Map<String, bool> _adhanEnabled = {
  'Fajr': true,
  'Dhuhr': true,
  'Asr': true,
  'Maghrib': true,
  'Isha': true,
};
  DateTime _now = DateTime.now();
  static const Map<String, Map<String, double>> _cities = {
    'البليدة': {'lat': 36.4700, 'lon': 2.8300},
    'الجزائر العاصمة': {'lat': 36.7538, 'lon': 3.0588},
    'وهران': {'lat': 35.6969, 'lon': -0.6331},
    'قسنطينة': {'lat': 36.3650, 'lon': 6.6147},
    'سطيف': {'lat': 36.1900, 'lon': 5.4100},
    'عنابة': {'lat': 36.9000, 'lon': 7.7667},
    'تلمسان': {'lat': 34.8828, 'lon': -1.3167},
    'باتنة': {'lat': 35.5559, 'lon': 6.1741},
    'بجاية': {'lat': 36.7500, 'lon': 5.0567},
    'تيزي وزو': {'lat': 36.7169, 'lon': 4.0497},
    'بسكرة': {'lat': 34.8500, 'lon': 5.7333},
    'غرداية': {'lat': 32.4909, 'lon': 3.6735},
    'ورقلة': {'lat': 31.9500, 'lon': 5.3167},
    'أدرار': {'lat': 27.8743, 'lon': -0.2939},
  };

  static const List<Map<String, String>> _prayers = [
    {'key': 'Fajr', 'name': 'الفجر', 'icon': '🌙'},
    {'key': 'Dhuhr', 'name': 'الظهر', 'icon': '☀️'},
    {'key': 'Asr', 'name': 'العصر', 'icon': '🌤️'},
    {'key': 'Maghrib', 'name': 'المغرب', 'icon': '🌅'},
    {'key': 'Isha', 'name': 'العشاء', 'icon': '🌙'},
  ];

  @override
  void initState() {
    super.initState();
    _initializeLocation();

    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() => _now = DateTime.now());
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _dio.close();
    super.dispose();
  }

  Future<void> _initializeLocation() async {
    final prefs = await SharedPreferences.getInstance();
    for (final prayer in _prayers) {
  final key = prayer['key']!;
  _adhanEnabled[key] =
      prefs.getBool('adhan_enabled_$key') ?? true;
}

    if (!mounted) return;

    setState(() {
      _selectedCity = prefs.getString('prayer_city') ?? 'البليدة';
      _useCurrentLocation =
          prefs.getBool('prayer_use_current_location') ?? true;
      _locationLabel =
          _useCurrentLocation ? 'موقعي الحالي' : _selectedCity;
    });

    if (_useCurrentLocation) {
      await _loadPrayerTimes();
    } else {
      await _loadSelectedCity();
    }
  }

  Future<void> _saveLocationPreference() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString('prayer_city', _selectedCity);
    await prefs.setBool(
      'prayer_use_current_location',
      _useCurrentLocation,
    );
  }

  String _cityName(BuildContext context, String city) {
    const names = {
      'البليدة': ['Blida', 'Blida'],
      'الجزائر العاصمة': ['Algiers', 'Alger'],
      'وهران': ['Oran', 'Oran'],
      'قسنطينة': ['Constantine', 'Constantine'],
      'سطيف': ['Setif', 'Sétif'],
      'عنابة': ['Annaba', 'Annaba'],
      'تلمسان': ['Tlemcen', 'Tlemcen'],
      'باتنة': ['Batna', 'Batna'],
      'بجاية': ['Bejaia', 'Béjaïa'],
      'تيزي وزو': ['Tizi Ouzou', 'Tizi Ouzou'],
      'بسكرة': ['Biskra', 'Biskra'],
      'غرداية': ['Ghardaia', 'Ghardaïa'],
      'ورقلة': ['Ouargla', 'Ouargla'],
      'أدرار': ['Adrar', 'Adrar'],
    };

    final translated = names[city];
    if (translated == null) return city;

    switch (Localizations.localeOf(context).languageCode) {
      case 'en':
        return translated[0];
      case 'fr':
        return translated[1];
      default:
        return city;
    }
  }

  String _displayLocationLabel(BuildContext context) {
    if (_useCurrentLocation) {
      return _tr(
        context,
        'موقعي الحالي',
        'My current location',
        'Ma position actuelle',
      );
    }
    return _cityName(context, _selectedCity);
  }
  String _dateString(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day-$month-${date.year}';
  }

  Future<Map<String, String>> _fetchTimes(
    double latitude,
    double longitude,
    DateTime date,
  ) async {
    final response = await _dio.get(
      'https://api.aladhan.com/v1/timings/${_dateString(date)}',
      queryParameters: {
        'latitude': latitude,
        'longitude': longitude,
        'method': 19,
        'school': 0,
      },
    );

    final data = response.data['data']['timings'] as Map;

    return {
      for (final prayer in _prayers)
        prayer['key']!: data[prayer['key']]!.toString().split(' ').first,
      'Sunrise': data['Sunrise'].toString().split(' ').first,
    };
  }

  Future<void> _fetchAndDisplay(
    double latitude,
    double longitude,
  ) async {
    final today = DateTime.now();

    final results = await Future.wait([
      _fetchTimes(latitude, longitude, today),
      _fetchTimes(
        latitude,
        longitude,
        today.add(const Duration(days: 1)),
      ),
    ]);

    final qibla = _calculateQibla(latitude, longitude);

    if (!mounted) return;

    setState(() {
      _times = results[0];
      _tomorrowTimes = results[1];
      _tomorrowFajr = results[1]['Fajr'];
      _qibla = qibla;
      _loading = false;
      _error = null;
    });
await PrayerScheduler.instance.refresh(latitude: latitude, longitude: longitude);
  }

  int _prayerNotificationId(DateTime date, int index) {
    return (date.year % 100) * 1000000 +
        date.month * 10000 +
        date.day * 100 +
        index + 1;
  }

  DateTime _prayerDate(String time, DateTime day) {
    final parts = time.split(':');
    return DateTime(
      day.year,
      day.month,
      day.day,
      int.parse(parts[0]),
      int.parse(parts[1]),
    );
  }

  Future<void> _syncPrayerNotifications(
    Map<String, String> todayTimes,
    Map<String, String> tomorrowTimes,
  ) async {
    if (todayTimes.isEmpty || tomorrowTimes.isEmpty) return;

    final today = DateTime.now();
    final tomorrow = today.add(const Duration(days: 1));
    final days = [
      (today, todayTimes),
      (tomorrow, tomorrowTimes),
    ];

    for (var index = 0; index < _prayers.length; index++) {
      final prayer = _prayers[index];
      final key = prayer['key']!;

      for (final entry in days) {
        final day = entry.$1;
        final times = entry.$2;
        final id = _prayerNotificationId(day, index);

        await NotificationService.instance.cancel(id);

        if (_adhanEnabled[key] != true) continue;

        final time = times[key];
        if (time == null) continue;

        await NotificationService.instance.schedulePrayer(
          id: id,
          prayerName: prayer['name']!,
          prayerTime: _prayerDate(time, day),
        );
      }
    }
  }

  Future<void> _loadPrayerTimes({bool forceLocationRefresh = false}) async {
    if (!mounted) return;

    setState(() {
      _loading = true;
      _error = null;
      _useCurrentLocation = true;
      _locationLabel = 'موقعي الحالي';
    });

    await _saveLocationPreference();

    final prefs = await SharedPreferences.getInstance();

    final cachedLatitude = prefs.getDouble('prayer_screen_lat');
    final cachedLongitude = prefs.getDouble('prayer_screen_lon');
    final updatedAt = prefs.getInt('prayer_screen_location_updated_at');

    final hasCachedLocation =
        cachedLatitude != null && cachedLongitude != null;

    Future<void> useCachedLocationOrShowError(String message) async {
      if (hasCachedLocation) {
        await _fetchAndDisplay(cachedLatitude!, cachedLongitude!);
      } else {
        _showError(message);
      }
    }

    // استخدام الموقع المحفوظ إذا كان عمره أقل من 6 ساعات
    if (!forceLocationRefresh && hasCachedLocation && updatedAt != null) {
      final lastUpdate =
          DateTime.fromMillisecondsSinceEpoch(updatedAt);

      if (DateTime.now().difference(lastUpdate) <
          const Duration(hours: 6)) {
        await _fetchAndDisplay(cachedLatitude, cachedLongitude);
        return;
      }
    }

    try {
      final serviceEnabled =
          await Geolocator.isLocationServiceEnabled();

      if (!serviceEnabled) {
        throw Exception('خدمة الموقع غير مفعّلة.');
      }

      LocationPermission permission =
          await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied) {
        throw Exception(
          'لم يتم السماح للتطبيق باستخدام الموقع.',
        );
      }

      if (permission == LocationPermission.deniedForever) {
        throw Exception(
          'صلاحية الموقع مرفوضة. يمكنك اختيار المدينة يدوياً.',
        );
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.best,
          timeLimit: Duration(seconds: 30),
        ),
      );

      await prefs.setDouble(
        'prayer_screen_lat',
        position.latitude,
      );
      await prefs.setDouble(
        'prayer_screen_lon',
        position.longitude,
      );
      await prefs.setInt(
        'prayer_screen_location_updated_at',
        DateTime.now().millisecondsSinceEpoch,
      );

      await _fetchAndDisplay(
        position.latitude,
        position.longitude,
      );
    } on TimeoutException {
      await useCachedLocationOrShowError(
        'تعذر تحديد موقعك. اختر مدينتك يدوياً.',
      );
    } on DioException {
      _showError(
        'تعذر الاتصال بالإنترنت. تحقق من الاتصال وحاول مجدداً.',
      );
    } catch (e) {
      await useCachedLocationOrShowError(
        e.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  Future<void> _loadSelectedCity() async {
    if (!mounted) return;

    setState(() {
      _loading = true;
      _error = null;
      _useCurrentLocation = false;
      _locationLabel = _selectedCity;
    });

    await _saveLocationPreference();

    try {
      final city = _cities[_selectedCity]!;

      await _fetchAndDisplay(
        city['lat']!,
        city['lon']!,
      );
    } on DioException {
      _showError('تعذر جلب المواقيت. تحقق من الإنترنت.');
    } catch (e) {
      _showError('حدث خطأ أثناء تحميل المواقيت.');
    }
  }

  Future<void> _chooseCity() async {
    String temporaryCity = _selectedCity;

    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _tr(context, 'اختيار المدينة', 'Choose a city', 'Choisir une ville'),
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 20),
                   DropdownButtonFormField<String>(
  initialValue: temporaryCity,
  isExpanded: true,
  decoration: InputDecoration(
    labelText: _tr(context, 'المدينة', 'City', 'Ville'),
    border: const OutlineInputBorder(),
  ),
                      items: _cities.keys.map((city) {
                        return DropdownMenuItem(
                          value: city,
                          child: Text(_cityName(context, city)),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setSheetState(() {
                            temporaryCity = value;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () {
                          Navigator.pop(context, temporaryCity);
                        },
                        child: Text(_tr(context, 'تأكيد المدينة', 'Confirm city', 'Confirmer la ville')),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (result == null || !mounted) return;

    setState(() {
      _selectedCity = result;
      _useCurrentLocation = false;
      _locationLabel = result;
    });

    await _loadSelectedCity();
  }
Future<void> _setAdhanEnabled(
  String prayerKey,
  bool enabled,
) async {
  setState(() {
    _adhanEnabled[prayerKey] = enabled;
  });

  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool('adhan_enabled_$prayerKey', enabled);

  if (enabled) {
    await NotificationService.instance.requestPermissions();
  }

  await PrayerScheduler.instance.refresh(force: true);
}
  void _showError(String message) {
    if (!mounted) return;

    setState(() {
      _error = message;
      _loading = false;
    });
  }

  double _calculateQibla(double latitude, double longitude) {
    const kaabaLat = 21.4225;
    const kaabaLon = 39.8262;

    final lat1 = latitude * math.pi / 180;
    final lat2 = kaabaLat * math.pi / 180;
    final deltaLon = (kaabaLon - longitude) * math.pi / 180;

    final y = math.sin(deltaLon);
    final x = math.cos(lat1) * math.tan(lat2) -
        math.sin(lat1) * math.cos(deltaLon);

    final bearing = math.atan2(y, x) * 180 / math.pi;

    return (bearing + 360) % 360;
  }

  DateTime _timeToday(String time) {
    final parts = time.split(':');

    return DateTime(
      _now.year,
      _now.month,
      _now.day,
      int.parse(parts[0]),
      int.parse(parts[1]),
    );
  }

  Map<String, dynamic>? _nextPrayer() {
    if (_times.isEmpty) return null;

    for (final prayer in _prayers) {
      final time = _times[prayer['key']];

      if (time == null) continue;

      final date = _timeToday(time);

      if (date.isAfter(_now)) {
        return {
          'name': prayer['name'],
          'time': date,
        };
      }
    }

    if (_tomorrowFajr != null) {
      final parts = _tomorrowFajr!.split(':');

      return {
        'name': 'الفجر',
        'time': DateTime(
          _now.year,
          _now.month,
          _now.day + 1,
          int.parse(parts[0]),
          int.parse(parts[1]),
        ),
      };
    }

    return null;
  }

  String _formatTime(BuildContext context, String time) {
    if (time == '--:--') return time;

    final parts = time.split(':');
    final hour = int.parse(parts[0]);
    final minute = parts[1];
    final language = Localizations.localeOf(context).languageCode;

    if (language == 'fr') {
      final displayHour = hour.toString().padLeft(2, '0');
      return '$displayHour:$minute';
    }

    final displayHour = hour % 12 == 0 ? 12 : hour % 12;

    if (language == 'en') {
      final period = hour >= 12 ? 'PM' : 'AM';
      return '$displayHour:$minute $period';
    }

    final period = hour >= 12 ? 'مساءً' : 'صباحاً';
    return '$displayHour:$minute $period';
  }

  String _countdown(Duration duration) {
    final hours = duration.inHours.toString().padLeft(2, '0');
    final minutes =
        duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds =
        duration.inSeconds.remainder(60).toString().padLeft(2, '0');

    return '$hours:$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: Text(_tr(context, 'الصلاة والقبلة', 'Prayer and Qibla', 'Prière et Qibla')),
          centerTitle: true,
          actions: [
            IconButton(
              onPressed: _loading ? null : () => _loadPrayerTimes(forceLocationRefresh: true),
              icon: const Icon(Icons.my_location),
              tooltip: _tr(context, 'استخدام موقعي الحالي', 'Use my current location', 'Utiliser ma position actuelle'),
            ),
            IconButton(
              onPressed: _loading ? null : _chooseCity,
              icon: const Icon(Icons.location_city),
              tooltip: _tr(context, 'تغيير المدينة', 'Change city', 'Changer de ville'),
            ),
            IconButton(
              onPressed: _loading
                  ? null
                  : _useCurrentLocation
                      ? () => _loadPrayerTimes(forceLocationRefresh: true)
                      : _loadSelectedCity,
              icon: const Icon(Icons.refresh_rounded),
              tooltip: _tr(context, 'تحديث المواقيت', 'Refresh prayer times', 'Actualiser les horaires'),
            ),

          ],
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? _buildError(colors)
                : _buildContent(colors),
      ),
    );
  }

  Widget _buildLocationCard(ColorScheme colors) {
    return Card(
      elevation: 0,
      color: colors.surfaceContainerLow,
      child: ListTile(
        leading: const Icon(Icons.location_on_outlined),
        title: Text(_tr(context, 'الموقع الحالي', 'Current location', 'Position actuelle')),
        subtitle: Text(_displayLocationLabel(context)),
        trailing: TextButton(
          onPressed: _chooseCity,
          child: Text(_tr(context, 'تغيير', 'Change', 'Modifier')),
        ),
      ),
    );
  }
  // بطاقة الأذان
  Widget _buildAdhanCard(ColorScheme colors) {
    final controller = AdhanController.instance;

    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        return Card(
          elevation: 0,
          color: colors.surfaceContainerLow,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    const Icon(Icons.volume_up_rounded, size: 28),
                    const SizedBox(width: 10),
                    Text(
                      _tr(context, 'الأذان', 'Adhan', 'Adhan'),
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  controller.isPlaying
                      ? _tr(context, 'الأذان يعمل الآن', 'Adhan is playing', 'Adhan en cours')
                      : _tr(context, 'الأذان متوقف', 'Adhan stopped', 'Adhan arrêté'),
                  style: TextStyle(
                    color: controller.isPlaying
                        ? colors.primary
                        : colors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: controller.isPlaying
                            ? null
                            : () => controller.play(),
                        icon: const Icon(Icons.play_arrow),
                        label: Text(_tr(context, 'تجربة الأذان', 'Test Adhan', 'Tester l’Adhan')),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: controller.isPlaying
                            ? () => controller.stop()
                            : null,
                        icon: const Icon(Icons.stop),
                        label: Text(_tr(context, 'إيقاف', 'Stop', 'Arrêter')),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildError(ColorScheme colors) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.location_off_rounded, size: 48),
            const SizedBox(height: 16),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 15),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _chooseCity,
                icon: const Icon(Icons.location_city),
                label: Text(_tr(context, 'اختيار المدينة يدوياً', 'Choose city manually', 'Choisir une ville manuellement')),
              ),
            ),
            TextButton.icon(
              onPressed: () => _loadPrayerTimes(forceLocationRefresh: true),
              icon: const Icon(Icons.my_location),
              label: Text(_tr(context, 'استخدام موقعي الحالي', 'Use my current location', 'Utiliser ma position actuelle')),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(ColorScheme colors) {
    final next = _nextPrayer();

    return RefreshIndicator(
      onRefresh: _useCurrentLocation
          ? () => _loadPrayerTimes(forceLocationRefresh: true)
          : _loadSelectedCity,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildLocationCard(colors),

          _buildAdhanCard(colors),

const SizedBox(height: 12),


const SizedBox(height: 16),

          const SizedBox(height: 16),

          Card(
            color: colors.primaryContainer,
            elevation: 0,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Text(
                    _tr(context, 'الصلاة القادمة', 'Next prayer', 'Prochaine prière'),
                    style: TextStyle(
                      color: colors.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _prayerDisplayName(context, next?['name'] ?? 'غير متاح'),
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: colors.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    next == null
                        ? '--:--:--'
                        : _countdown(
                            (next['time'] as DateTime).difference(_now),
                          ),
                    style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.bold,
                      color: colors.onPrimaryContainer,
                      fontFeatures: const [
                        FontFeature.tabularFigures(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          Text(
            _tr(context, 'مواقيت الصلاة اليوم', "Today's prayer times", 'Horaires de prière du jour') + ' - ${_displayLocationLabel(context)}',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 12),

          ..._prayers.map((prayer) {
            final time = _times[prayer['key']] ?? '--:--';
            final isNext = next?['name'] == prayer['name'];

            return Card(
              elevation: 0,
              color: isNext
                  ? colors.primaryContainer.withValues(alpha: 0.5)
                  : colors.surfaceContainerLow,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    Text(
                      prayer['icon']!,
                      style: const TextStyle(fontSize: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _prayerDisplayName(context, prayer['name']!),
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Text(
                      _formatTime(context, time),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Switch(
                      value: _adhanEnabled[prayer['key']] ?? true,
                      onChanged: (value) {
                        _setAdhanEnabled(prayer['key']!, value);
                      },
                    ),
                  ],
                ),
              ),
            );
          }),

          const SizedBox(height: 8),

          Card(
            elevation: 0,
            color: colors.surfaceContainerLow,
            child: ListTile(
              leading: const Icon(Icons.wb_sunny_outlined),
              title: Text(_tr(context, 'الشروق', 'Sunrise', 'Lever du soleil')),
              trailing: Text(
                _formatTime(context, _times['Sunrise'] ?? '--:--'),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ),

          const SizedBox(height: 24),

          Card(
            elevation: 0,
            color: colors.surfaceContainerLow,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  const Icon(Icons.explore_rounded, size: 48),
                  const SizedBox(height: 10),
                  Text(
                    _tr(context, 'اتجاه القبلة', 'Qibla direction', 'Direction de la Qibla'),
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _qibla == null
                        ? '--'
                        : '${_qibla!.toStringAsFixed(1)}°',
                    style: TextStyle(
                      fontSize: 28,
                      color: colors.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    _tr(context, 'الزاوية محسوبة من اتجاه الشمال الجغرافي', 'Angle measured clockwise from geographic north', 'Angle calculé à partir du nord géographique'),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          Text(
            _tr(context, 'طريقة الحساب: الجزائر (AlAdhan). قد تختلف المواقيت قليلاً عن مواقيت المسجد المحلي.', 'Calculation method: Algeria (AlAdhan). Times may differ slightly from your local mosque.', 'Méthode de calcul : Algérie (AlAdhan). Les horaires peuvent légèrement différer de ceux de votre mosquée.'),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: colors.onSurfaceVariant,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}







