import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:quran/quran.dart' as quran;
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/services/notification_service.dart';

class RemindersScreen extends StatefulWidget {
  const RemindersScreen({super.key});

  @override
  State<RemindersScreen> createState() => _RemindersScreenState();
}

class _RemindersScreenState extends State<RemindersScreen> {
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

  String _presetText(String key, bool isTitle) {
    switch (key) {
      case 'morning_adhkar':
        return isTitle
            ? _tr(context, 'أذكار الصباح', 'Morning adhkar', 'Adhkar du matin')
            : _tr(context, 'حان وقت أذكار الصباح', 'Time for morning adhkar', 'C’est l’heure des adhkar du matin');
      case 'evening_adhkar':
        return isTitle
            ? _tr(context, 'أذكار المساء', 'Evening adhkar', 'Adhkar du soir')
            : _tr(context, 'حان وقت أذكار المساء', 'Time for evening adhkar', 'C’est l’heure des adhkar du soir');
      case 'quran_reading':
        return isTitle
            ? _tr(context, 'قراءة القرآن', 'Quran reading', 'Lecture du Coran')
            : _tr(context, 'خصص وقتاً لقراءة القرآن الكريم', 'Set aside time to read the Holy Quran', 'Prenez un moment pour lire le Saint Coran');
      case 'daily_ayah':
        return isTitle
            ? _tr(context, 'آية قرآنية', 'Quranic verse', 'Verset coranique')
            : _tr(context, 'افتح التطبيق لقراءة آية من القرآن الكريم', 'Open the app to read a Quranic verse', 'Ouvrez l’application pour lire un verset du Coran');
      case 'hadith':
        return isTitle
            ? _tr(context, 'حديث وفائدة', 'Hadith & benefit', 'Hadith et enseignement')
            : _tr(context, 'افتح التطبيق للاطلاع على حديث وفائدة إسلامية', 'Open the app for a hadith and an Islamic reminder', 'Ouvrez l’application pour découvrir un hadith et un enseignement islamique');
      case 'istighfar':
        return isTitle
            ? _tr(context, 'الاستغفار', 'Seeking forgiveness', 'Demande de pardon')
            : _tr(context, 'لا تنسَ الإكثار من الاستغفار', 'Remember to seek Allah’s forgiveness often', 'N’oubliez pas de demander souvent pardon à Allah');
      default:
        return '';
    }
  }

  static const int _maxTimes = 20;

  static const List<Map<String, dynamic>> _presets = [
    {
      'key': 'morning_adhkar',
      'id': 2001,
      'title': 'أذكار الصباح',
      'body': 'حان وقت أذكار الصباح',
      'hour': 7,
      'minute': 0,
      'icon': Icons.wb_sunny_outlined,
    },
    {
      'key': 'evening_adhkar',
      'id': 2002,
      'title': 'أذكار المساء',
      'body': 'حان وقت أذكار المساء',
      'hour': 17,
      'minute': 0,
      'icon': Icons.nights_stay_outlined,
    },
    {
      'key': 'quran_reading',
      'id': 2003,
      'title': 'قراءة القرآن',
      'body': 'خصص وقتاً لقراءة القرآن الكريم',
      'hour': 20,
      'minute': 0,
      'icon': Icons.menu_book_outlined,
    },
    {
      'key': 'daily_ayah',
      'id': 2004,
      'title': 'آية قرآنية',
      'body': 'افتح التطبيق لقراءة آية من القرآن الكريم',
      'hour': 12,
      'minute': 0,
      'icon': Icons.auto_stories_outlined,
    },
    {
      'key': 'hadith',
      'id': 2005,
      'title': 'حديث وفائدة',
      'body': 'افتح التطبيق للاطلاع على حديث وفائدة إسلامية',
      'hour': 10,
      'minute': 0,
      'icon': Icons.lightbulb_outline,
    },
    {
      'key': 'istighfar',
      'id': 2006,
      'title': 'الاستغفار',
      'body': 'لا تنسَ الإكثار من الاستغفار',
      'hour': 15,
      'minute': 0,
      'icon': Icons.favorite_border,
    },
  ];

  final Map<String, bool> _enabled = {};
  final Map<String, List<TimeOfDay>> _times = {};
  List<Map<String, dynamic>> _customReminders = [];

  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadReminders();
  }

  List<TimeOfDay> _decodeTimes(dynamic value) {
    if (value is! List) return [];

    return value.map((item) {
      final map = Map<String, dynamic>.from(item as Map);
      return TimeOfDay(
        hour: (map['hour'] as num).toInt(),
        minute: (map['minute'] as num).toInt(),
      );
    }).toList();
  }

  List<Map<String, int>> _encodeTimes(List<TimeOfDay> times) {
    return times.map((time) => {
      'hour': time.hour,
      'minute': time.minute,
    }).toList();
  }

  Future<void> _loadReminders() async {
    final prefs = await SharedPreferences.getInstance();

    for (final item in _presets) {
      final key = item['key'] as String;
      _enabled[key] = prefs.getBool('reminder_enabled_$key') ?? false;

      final savedTimes = prefs.getString('reminder_times_$key');
      List<TimeOfDay> times = [];

      if (savedTimes != null) {
        try {
          times = _decodeTimes(jsonDecode(savedTimes));
        } catch (_) {}
      }

      if (times.isEmpty) {
        times = [
          TimeOfDay(
            hour: prefs.getInt('reminder_hour_$key') ?? item['hour'] as int,
            minute:
                prefs.getInt('reminder_minute_$key') ?? item['minute'] as int,
          ),
        ];
      }

      _times[key] = times;
    }

    final saved = prefs.getString('custom_reminders');
    if (saved != null) {
      try {
        _customReminders = List<Map<String, dynamic>>.from(
          (jsonDecode(saved) as List).map((raw) {
            final item = Map<String, dynamic>.from(raw);
            if (item['times'] is! List) {
              item['times'] = [
                {
                  'hour': item['hour'] ?? 9,
                  'minute': item['minute'] ?? 0,
                }
              ];
            }
            return item;
          }),
        );
      } catch (_) {
        _customReminders = [];
      }
    }

    if (mounted) {
      setState(() => _loading = false);
    }

    for (final item in _presets) {
      if (_enabled[item['key']] == true) {
        await _schedulePreset(item);
      }
    }

    for (final item in _customReminders) {
      if (item['enabled'] == true) {
        await _scheduleCustom(item);
      }
    }
  }

  Future<void> _cancelSlots(int baseId) async {
    for (var i = 0; i < _maxTimes; i++) {
      await NotificationService.instance.cancel(baseId + i);
    }
  }

  Future<void> _scheduleSlots({
    required int baseId,
    required String title,
    required String body,
    required List<TimeOfDay> times,
    required String channelId,
    required String channelName,
    required String channelDescription,
    required String payload,
  }) async {
    await _cancelSlots(baseId);

    for (var i = 0; i < times.length && i < _maxTimes; i++) {
      final time = times[i];

      await NotificationService.instance.scheduleDaily(
        id: baseId + i,
        channelId: channelId,
        channelName: channelName,
        channelDescription: channelDescription,
        title: title,
        body: body,
        hour: time.hour,
        minute: time.minute,
        payload: payload,
      );
    }
  }

  Future<void> _togglePreset(
    Map<String, dynamic> item,
    bool value,
  ) async {
    final key = item['key'] as String;
    final prefs = await SharedPreferences.getInstance();

    if (value) {
      await NotificationService.instance.requestPermissions();
    }

    setState(() => _enabled[key] = value);
    await prefs.setBool('reminder_enabled_$key', value);

    if (value) {
      await _schedulePreset(item);
    } else {
      await _cancelSlots(item['id'] as int);
    }
  }

  Future<void> _schedulePreset(Map<String, dynamic> item) async {
    final key = item['key'] as String;
    final baseId = item['id'] as int;
    final times = _times[key] ?? [];

    if (key == 'daily_ayah') {
      await _cancelSlots(baseId);

      final random = math.Random();
      final usedAyat = <String>{};

      for (var i = 0; i < times.length && i < _maxTimes; i++) {
        late int surah;
        late int verse;

        do {
          surah = random.nextInt(114) + 1;
          final verseCount = quran.getVerseCount(surah);
          verse = random.nextInt(verseCount) + 1;
        } while (!usedAyat.add('$surah:$verse'));

        final time = times[i];
        final surahName = quran.getSurahNameArabic(surah);
        final verseText = quran.getVerse(
          surah,
          verse,
          verseEndSymbol: true,
        );

        await NotificationService.instance.scheduleDaily(
          id: baseId + i,
          channelId: 'general_reminders',
          channelName: _tr(context, 'التذكيرات الإسلامية', 'Islamic reminders', 'Rappels islamiques'),
          channelDescription: _tr(context, 'تذكيرات القرآن والأذكار والفوائد', 'Quran, adhkar and Islamic reminders', 'Rappels du Coran, adhkar et enseignements islamiques'),
          title: _tr(context, 'آية قرآنية', 'Quranic verse', 'Verset coranique'),
          body: '$verseText\n${_tr(context, 'سورة', 'Surah', 'Sourate')} $surahName • ${_tr(context, 'الآية', 'Verse', 'Verset')} $verse',
          hour: time.hour,
          minute: time.minute,
          payload: 'ayah:$surah:$verse',
        );
      }

      return;
    }

    await _scheduleSlots(
      baseId: baseId,
      title: _presetText(key, true),
      body: _presetText(key, false),
      times: times,
      channelId: 'general_reminders',
      channelName: _tr(context, 'التذكيرات الإسلامية', 'Islamic reminders', 'Rappels islamiques'),
      channelDescription: _tr(context, 'تذكيرات القرآن والأذكار والفوائد', 'Quran, adhkar and Islamic reminders', 'Rappels du Coran, adhkar et enseignements islamiques'),
      payload: 'preset:$key',
    );
  }
  Future<List<TimeOfDay>?> _showTimesDialog(
    List<TimeOfDay> initialTimes,
  ) async {
    final selected = List<TimeOfDay>.from(initialTimes);

    return showDialog<List<TimeOfDay>>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, updateDialog) {
            return AlertDialog(
              title: Text(_tr(context, 'أوقات التذكير', 'Reminder times', 'Heures des rappels')),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: selected.length,
                        itemBuilder: (context, index) {
                          final time = selected[index];

                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.access_time),
                            title: Text(time.format(context)),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  tooltip: _tr(context, 'تعديل الوقت', 'Edit time', 'Modifier l’heure'),
                                  icon: const Icon(Icons.edit_outlined),
                                  onPressed: () async {
                                    final picked = await showTimePicker(
                                      context: context,
                                      initialTime: time,
                                    );
                                    if (picked != null) {
                                      updateDialog(
                                        () => selected[index] = picked,
                                      );
                                    }
                                  },
                                ),
                                IconButton(
                                  tooltip: _tr(context, 'حذف الوقت', 'Delete time', 'Supprimer l’heure'),
                                  icon: const Icon(Icons.delete_outline),
                                  onPressed: selected.length <= 1
                                      ? null
                                      : () {
                                          updateDialog(
                                            () => selected.removeAt(index),
                                          );
                                        },
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: selected.length >= _maxTimes
                          ? null
                          : () async {
                              final picked = await showTimePicker(
                                context: context,
                                initialTime: TimeOfDay.now(),
                              );
                              if (picked != null) {
                                updateDialog(() => selected.add(picked));
                              }
                            },
                      icon: const Icon(Icons.add),
                      label: Text(_tr(context, 'إضافة وقت آخر', 'Add another time', 'Ajouter une autre heure')),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _tr(context, 'يمكنك إضافة حتى $_maxTimes موعداً يومياً', 'You can add up to $_maxTimes times per day', 'Vous pouvez ajouter jusqu’à $_maxTimes horaires par jour'),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: Text(_tr(context, 'إلغاء', 'Cancel', 'Annuler')),
                ),
                FilledButton(
                  onPressed: () {
                    selected.sort((a, b) {
                      final first = a.hour * 60 + a.minute;
                      final second = b.hour * 60 + b.minute;
                      return first.compareTo(second);
                    });
                    Navigator.pop(dialogContext, selected);
                  },
                  child: Text(_tr(context, 'حفظ', 'Save', 'Enregistrer')),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _changePresetTimes(Map<String, dynamic> item) async {
    final key = item['key'] as String;
    final selected = await _showTimesDialog(_times[key] ?? []);

    if (selected == null || selected.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();

    setState(() => _times[key] = selected);

    await prefs.setString(
      'reminder_times_$key',
      jsonEncode(_encodeTimes(selected)),
    );

    if (_enabled[key] == true) {
      await _schedulePreset(item);
    }
  }

  Future<void> _saveCustomReminders() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString(
      'custom_reminders',
      jsonEncode(_customReminders),
    );
  }

  List<TimeOfDay> _customTimes(Map<String, dynamic> item) {
    try {
      final times = _decodeTimes(item['times']);
      if (times.isNotEmpty) return times;
    } catch (_) {}

    return [
      TimeOfDay(
        hour: item['hour'] as int? ?? 9,
        minute: item['minute'] as int? ?? 0,
      ),
    ];
  }

  Future<void> _scheduleCustom(Map<String, dynamic> item) async {
    await _scheduleSlots(
      baseId: item['id'] as int,
      title: item['title'] as String? ?? '',
      body: item['body'] as String? ?? '',
      times: _customTimes(item),
      channelId: 'custom_reminders',
      channelName: _tr(context, 'تذكيراتي الخاصة', 'My custom reminders', 'Mes rappels personnalisés'),
      channelDescription: _tr(context, 'التذكيرات التي أنشأتها بنفسك', 'Reminders you created yourself', 'Les rappels que vous avez créés'),
      payload: 'custom:${item['id']}',
    );
  }

  Future<void> _showCustomDialog({
    Map<String, dynamic>? existing,
  }) async {
    final initialTimes = existing == null
        ? [const TimeOfDay(hour: 9, minute: 0)]
        : _customTimes(existing);

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) {
        return _CustomReminderDialog(
          initialTitle: existing?['title'] as String? ?? '',
          initialBody: existing?['body'] as String? ?? '',
          isEditing: existing != null,
          initialTimes: initialTimes,
          onPickTimes: _showTimesDialog,
        );
      },
    );
    if (result == null) return;

    final selectedTimes = result.remove('selectedTimes') as List<TimeOfDay>;
    result['times'] = _encodeTimes(selectedTimes);

    final wasEnabled = existing?['enabled'] as bool? ?? true;

    final reminder = <String, dynamic>{
      'id': existing?['id'] ??
          (500000000 +
              DateTime.now().millisecondsSinceEpoch.remainder(1000000000)),
      ...result,
      'enabled': wasEnabled,
    };

    if (existing == null) {
      await NotificationService.instance.requestPermissions();
      setState(() => _customReminders.add(reminder));
    } else {
      final index = _customReminders.indexWhere(
        (item) => item['id'] == existing['id'],
      );

      if (index == -1) return;

      setState(() => _customReminders[index] = reminder);
    }

    await _saveCustomReminders();

    if (wasEnabled) {
      await _scheduleCustom(reminder);
    }
  }

  Future<void> _toggleCustom(
    Map<String, dynamic> item,
    bool value,
  ) async {
    if (value) {
      await NotificationService.instance.requestPermissions();
    }

    setState(() => item['enabled'] = value);
    await _saveCustomReminders();

    if (value) {
      await _scheduleCustom(item);
    } else {
      await _cancelSlots(item['id'] as int);
    }
  }

  Future<void> _deleteCustom(Map<String, dynamic> item) async {
    await _cancelSlots(item['id'] as int);

    setState(() {
      _customReminders.removeWhere(
        (reminder) => reminder['id'] == item['id'],
      );
    });

    await _saveCustomReminders();
  }

  String _formatTimes(List<TimeOfDay> times) {
    return times.map((time) => time.format(context)).join(' • ');
  }

  Widget _buildPresetCard(Map<String, dynamic> item) {
    final key = item['key'] as String;
    final times = _times[key] ?? [];
    final enabled = _enabled[key] ?? false;

    return Card(
      child: ListTile(
        leading: Icon(item['icon'] as IconData),
        title: Text(_presetText(key, true)),
        subtitle: InkWell(
          onTap: () => _changePresetTimes(item),
          child: Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Row(
              children: [
                const Icon(Icons.access_time, size: 16),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    '${_formatTimes(times)}  •  ${_tr(context, 'تعديل الأوقات', 'Edit times', 'Modifier les horaires')}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
        trailing: Switch(
          value: enabled,
          onChanged: (value) => _togglePreset(item, value),
        ),
      ),
    );
  }

  Widget _buildCustomCard(Map<String, dynamic> item) {
    final times = _customTimes(item);
    final enabled = item['enabled'] as bool? ?? true;

    return Card(
      child: ListTile(
        leading: const Icon(Icons.notifications_active_outlined),
        title: Text(item['title'] as String? ?? ''),
        subtitle: Text(
          '${_formatTimes(times)}\n${item['body']}',
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
        ),
        isThreeLine: true,
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            if (value == 'toggle') {
              _toggleCustom(item, !enabled);
            } else if (value == 'edit') {
              _showCustomDialog(existing: item);
            } else if (value == 'delete') {
              _deleteCustom(item);
            }
          },
          itemBuilder: (_) => [
            PopupMenuItem(
              value: 'toggle',
              child: Text(enabled ? _tr(context, 'إيقاف التذكير', 'Turn off reminder', 'Désactiver le rappel') : _tr(context, 'تشغيل التذكير', 'Turn on reminder', 'Activer le rappel')),
            ),
            PopupMenuItem(
              value: 'edit',
              child: Text(_tr(context, 'تعديل', 'Edit', 'Modifier')),
            ),
            PopupMenuItem(
              value: 'delete',
              child: Text(_tr(context, 'حذف', 'Delete', 'Supprimer')),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_tr(context, 'التذكيرات والإشعارات', 'Reminders and notifications', 'Rappels et notifications')),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  _tr(context, 'التذكيرات اليومية', 'Daily reminders', 'Rappels quotidiens'),
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                ..._presets.map(_buildPresetCard),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _tr(context, 'تذكيراتي الخاصة', 'My custom reminders', 'Mes rappels personnalisés'),
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton.filled(
                      onPressed: () => _showCustomDialog(),
                      icon: const Icon(Icons.add),
                      tooltip: _tr(context, 'إضافة تذكير', 'Add reminder', 'Ajouter un rappel'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (_customReminders.isEmpty)
                  Card(
                    child: Padding(
                      padding: EdgeInsets.all(20),
                      child: Center(
                        child: Text(_tr(context, 'لم تضف أي تذكيرات خاصة بعد', 'You have not added any custom reminders yet', 'Vous n’avez pas encore ajouté de rappels personnalisés')),
                      ),
                    ),
                  )
                else
                  ..._customReminders.map(_buildCustomCard),
                const SizedBox(height: 16),
                Text(
                  _tr(context, 'ملاحظة: قد يتأخر وصول الإشعار قليلاً حسب قيود النظام وتوفير البطارية.', 'Note: Notifications may be slightly delayed due to system restrictions and battery optimization.', 'Remarque : les notifications peuvent être légèrement retardées en raison des restrictions du système et de l’optimisation de la batterie.'),
                  style: TextStyle(fontSize: 12),
                ),
              ],
            ),
    );
  }
}

class _CustomReminderDialog extends StatefulWidget {
  const _CustomReminderDialog({
    required this.initialTitle,
    required this.initialBody,
    required this.isEditing,
    required this.initialTimes,
    required this.onPickTimes,
  });

  final String initialTitle;
  final String initialBody;
  final bool isEditing;
  final List<TimeOfDay> initialTimes;
  final Future<List<TimeOfDay>?> Function(List<TimeOfDay>) onPickTimes;

  @override
  State<_CustomReminderDialog> createState() =>
      _CustomReminderDialogState();
}

class _CustomReminderDialogState extends State<_CustomReminderDialog> {
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
  late final TextEditingController _titleController;
  late final TextEditingController _bodyController;
  late List<TimeOfDay> _selectedTimes;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.initialTitle);
    _bodyController = TextEditingController(text: widget.initialBody);
    _selectedTimes = List<TimeOfDay>.from(widget.initialTimes);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.isEditing ? _tr(context, 'تعديل التذكير', 'Edit reminder', 'Modifier le rappel') : _tr(context, 'إضافة تذكير', 'Add reminder', 'Ajouter un rappel'),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _titleController,
              maxLength: 50,
              decoration: InputDecoration(
                labelText: _tr(context, 'عنوان التذكير', 'Reminder title', 'Titre du rappel'),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _bodyController,
              maxLength: 150,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: _tr(context, 'محتوى الإشعار', 'Notification message', 'Contenu de la notification'),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.access_time),
              title: Text(_tr(context, 'أوقات التذكير اليومية', 'Daily reminder times', 'Heures quotidiennes des rappels')),
              subtitle: Text(
                _selectedTimes
                    .map((time) => time.format(context))
                    .join('، '),
              ),
              trailing: const Icon(Icons.edit_outlined),
              onTap: () async {
                final picked = await widget.onPickTimes(_selectedTimes);
                if (!mounted || picked == null || picked.isEmpty) return;
                setState(() => _selectedTimes = picked);
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(_tr(context, 'إلغاء', 'Cancel', 'Annuler')),
        ),
        FilledButton(
          onPressed: () {
            final title = _titleController.text.trim();
            final body = _bodyController.text.trim();

            if (title.isEmpty || body.isEmpty) return;

            Navigator.pop(context, {
              'title': title,
              'body': body,
              'selectedTimes': _selectedTimes,
            });
          },
          child: Text(_tr(context, 'حفظ', 'Save', 'Enregistrer')),
        ),
      ],
    );
  }
}


