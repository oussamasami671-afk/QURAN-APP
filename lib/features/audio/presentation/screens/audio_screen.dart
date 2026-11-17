
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:quran/quran.dart' as quran;
import 'package:shared_preferences/shared_preferences.dart';

String _pad(int n) => n.toString().padLeft(3, '0');
bool _audioIsArabic(BuildContext context) =>
    Localizations.localeOf(context).languageCode == 'ar';

String _audioTr(BuildContext context, String ar, String en, String fr) {
  switch (Localizations.localeOf(context).languageCode) {
    case 'en':
      return en;
    case 'fr':
      return fr;
    default:
      return ar;
  }
}

String _audioSurahName(BuildContext context, int number) {
  switch (Localizations.localeOf(context).languageCode) {
    case 'en':
      return quran.getSurahNameEnglish(number);
    case 'fr':
      return quran.getSurahNameFrench(number);
    default:
      return quran.getSurahNameArabic(number);
  }
}
String _normalize(String input) {
  return input
      .replaceAll(RegExp(r'[\u064B-\u065F\u0670\u0640]'), '')
      .replaceAll(RegExp(r'[أإآٱ]'), 'ا')
      .replaceAll('ى', 'ي')
      .replaceAll('ة', 'ه')
      .replaceAll('ؤ', 'و')
      .replaceAll('ئ', 'ي')
      .trim();
}

String _fmt(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
  final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  return h > 0 ? '$h:$m:$s' : '$m:$s';
}

// ───────────────────────── النماذج ─────────────────────────

class Moshaf {
  final int id;
  final String name;
  final String server;
  final List<int> surahs;

  const Moshaf({
    required this.id,
    required this.name,
    required this.server,
    required this.surahs,
  });

  factory Moshaf.fromJson(Map<String, dynamic> json) {
    final surahs = ((json['surah_list'] as String?) ?? '')
        .split(',')
        .map((e) => int.tryParse(e.trim()))
        .whereType<int>()
        .where((n) => n >= 1 && n <= 114)
        .toList()
      ..sort();

    final server = ((json['server'] as String?) ?? '').trim();

    return Moshaf(
      id: (json['id'] as num).toInt(),
      name: ((json['name'] as String?) ?? '').trim(),
      server: server.isEmpty || server.endsWith('/') ? server : '$server/',
      surahs: surahs,
    );
  }

  String urlFor(int surah) => '$server${_pad(surah)}.mp3';
}

class Reciter {
  final int id;
  final String name;
  final List<Moshaf> moshafs;

  const Reciter({
    required this.id,
    required this.name,
    required this.moshafs,
  });
}

// ───────────────────────── جلب القراء ─────────────────────────

class RecitersRepository {
  static const _cacheKey = 'reciters_cache_v1';
  static const _url = 'https://mp3quran.net/api/v3/reciters?language=ar';

  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 12),
      receiveTimeout: const Duration(seconds: 30),
    ),
  );

  Future<List<Reciter>> load({bool forceRefresh = false}) async {
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString(_cacheKey);

    if (cached != null && !forceRefresh) {
      final parsed = _parse(cached);
      if (parsed.isNotEmpty) {
        unawaited(_fetch(prefs).then((_) {}, onError: (_) {}));
        return parsed;
      }
    }

    try {
      return await _fetch(prefs);
    } catch (_) {
      if (cached != null) {
        final parsed = _parse(cached);
        if (parsed.isNotEmpty) return parsed;
      }
      rethrow;
    }
  }

  Future<List<Reciter>> _fetch(SharedPreferences prefs) async {
    final res = await _dio.get<String>(
      _url,
      options: Options(responseType: ResponseType.plain),
    );

    final body = res.data;
    if (body == null) throw Exception('empty response');

    final parsed = _parse(body);
    if (parsed.isEmpty) throw Exception('no reciters');

    await prefs.setString(_cacheKey, body);
    return parsed;
  }

  List<Reciter> _parse(String body) {
    try {
      final data = jsonDecode(body);
      final list = data is Map ? data['reciters'] : null;
      if (list is! List) return [];

      final out = <Reciter>[];

      for (final r in list) {
        if (r is! Map<String, dynamic>) continue;

        final moshafs = <Moshaf>[];
        final rawMoshafs = r['moshaf'];

        if (rawMoshafs is List) {
          for (final m in rawMoshafs) {
            if (m is! Map<String, dynamic>) continue;
            final moshaf = Moshaf.fromJson(m);
            if (moshaf.surahs.isNotEmpty && moshaf.server.isNotEmpty) {
              moshafs.add(moshaf);
            }
          }
        }

        if (moshafs.isEmpty) continue;

        out.add(
          Reciter(
            id: (r['id'] as num).toInt(),
            name: ((r['name'] as String?) ?? '').trim(),
            moshafs: moshafs,
          ),
        );
      }

      return out;
    } catch (_) {
      return [];
    }
  }
}

// ───────────────────────── المشغل والتنزيلات ─────────────────────────

class AudioController extends ChangeNotifier {
  AudioController._();

  static final AudioController instance = AudioController._();

  final AudioPlayer player = AudioPlayer();
  final Dio _dio = Dio();

  Reciter? reciter;
  Moshaf? moshaf;
  int? surah;

  final Set<String> downloaded = {};
  final Map<String, double> progress = {};
  final Map<String, CancelToken> _cancelTokens = {};

  bool _listening = false;
  Directory? _root;

  String key(Moshaf m, int s) => '${m.id}/${_pad(s)}';

  Future<Directory> _audioDir() async {
    final cached = _root;
    if (cached != null) return cached;

    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docs.path, 'quran_audio'));
    await dir.create(recursive: true);

    _root = dir;
    return dir;
  }

  Future<File> _fileFor(Moshaf m, int s) async {
    final root = await _audioDir();
    return File(p.join(root.path, '${m.id}', '${_pad(s)}.mp3'));
  }

  Future<void> refreshDownloaded(Moshaf m) async {
    downloaded.removeWhere((k) => k.startsWith('${m.id}/'));

    final root = await _audioDir();
    final dir = Directory(p.join(root.path, '${m.id}'));

    if (await dir.exists()) {
      await for (final entity in dir.list()) {
        if (entity is File && entity.path.endsWith('.mp3')) {
          downloaded.add(
            '${m.id}/${p.basenameWithoutExtension(entity.path)}',
          );
        }
      }
    }

    notifyListeners();
  }

  // تنزيل سورة مع إمكانية الإلغاء
  Future<String?> download(Moshaf m, int s) async {
    final k = key(m, s);

    if (progress.containsKey(k) || downloaded.contains(k)) {
      return null;
    }

    final cancelToken = CancelToken();
    _cancelTokens[k] = cancelToken;

    progress[k] = 0;
    notifyListeners();

    File? part;

    try {
      final file = await _fileFor(m, s);
      part = File('${file.path}.part');

      await file.parent.create(recursive: true);

      await _dio.download(
        m.urlFor(s),
        part.path,
        cancelToken: cancelToken,
        onReceiveProgress: (received, total) {
          if (total <= 0) return;

          final value = received / total;

          if (value - (progress[k] ?? 0) >= 0.01 || value >= 1) {
            progress[k] = value;
            notifyListeners();
          }
        },
      );

      await part.rename(file.path);
      downloaded.add(k);

      return null;
    } catch (e) {
      if (part != null && await part.exists()) {
        await part.delete();
      }

     if (e is DioException && CancelToken.isCancel(e)) {
  return null;
}
        

      return 'تعذر التنزيل، تحقق من الاتصال بالإنترنت';
    } finally {
      _cancelTokens.remove(k);
      progress.remove(k);
      notifyListeners();
    }
  }

  // إلغاء التنزيل
  void cancelDownload(Moshaf m, int s) {
    final k = key(m, s);
    _cancelTokens[k]?.cancel('تم إلغاء التنزيل');
  }

  // حذف سورة محملة
  Future<void> deleteDownload(Moshaf m, int s) async {
    final file = await _fileFor(m, s);

    if (await file.exists()) {
      await file.delete();
    }

    downloaded.remove(key(m, s));
    notifyListeners();
  }

  // تشغيل سورة من الجهاز أو بالبث المباشر
  Future<String?> play(Reciter r, Moshaf m, int s, {required String surahTitle}) async {
    try {
      reciter = r;
      moshaf = m;
      surah = s;
      notifyListeners();

      final file = await _fileFor(m, s);
      final isLocal = await file.exists();

      final item = MediaItem(
        id: key(m, s),
        title: surahTitle,
        artist: r.name,
        album: m.name,
      );

      final source = isLocal
          ? AudioSource.file(file.path, tag: item)
          : AudioSource.uri(Uri.parse(m.urlFor(s)), tag: item);

      await player.setAudioSource(source);
      _ensureListening();

      unawaited(player.play());
      return null;
    } catch (_) {
      return 'تعذر التشغيل، تحقق من الاتصال بالإنترنت';
    }
  }

  void _ensureListening() {
    if (_listening) return;
    _listening = true;

    player.processingStateStream.listen((state) {
      if (state == ProcessingState.completed) {
        next();
      }
    });
  }

  Future<void> next() async {
    final r = reciter, m = moshaf, s = surah;
    if (r == null || m == null || s == null) return;

    final i = m.surahs.indexOf(s);
    if (i >= 0 && i + 1 < m.surahs.length) {
      await play(
        r,
        m,
        m.surahs[i + 1],
        surahTitle: 'سورة ${quran.getSurahNameArabic(m.surahs[i + 1])}',
      );
    }
  }

  Future<void> previous() async {
    final r = reciter, m = moshaf, s = surah;
    if (r == null || m == null || s == null) return;

    final i = m.surahs.indexOf(s);
    if (i > 0) {
      await play(
        r,
        m,
        m.surahs[i - 1],
        surahTitle: 'سورة ${quran.getSurahNameArabic(m.surahs[i - 1])}',
      );
    }
  }

  void toggle() {
    if (player.processingState == ProcessingState.completed) {
      player.seek(Duration.zero);
      player.play();
    } else if (player.playing) {
      player.pause();
    } else {
      player.play();
    }
  }
}

// ───────────────────────── شاشة القراء ─────────────────────────

class AudioScreen extends StatefulWidget {
  const AudioScreen({super.key});

  @override
  State<AudioScreen> createState() => _AudioScreenState();
}

class _AudioScreenState extends State<AudioScreen> {
  final RecitersRepository _repo = RecitersRepository();

  List<Reciter> _reciters = [];
  bool _loading = true;
  String? _error;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool force = false}) async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final list = await _repo.load(forceRefresh: force);
      if (!mounted) return;

      setState(() {
        _reciters = list;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _error = _audioTr(context, 'تعذر تحميل قائمة القرّاء.\nتحقق من الاتصال بالإنترنت ثم أعد المحاولة.', 'Could not load the reciters list.\nCheck your internet connection and try again.', 'Impossible de charger la liste des récitateurs.\nVérifiez votre connexion Internet puis réessayez.');
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final query = _normalize(_query);

    final visible = _reciters
        .where((r) => _normalize(r.name).contains(query))
        .toList();

    return Directionality(
      textDirection: _audioIsArabic(context) ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        appBar: AppBar(
          title: Text(_audioTr(context, 'التلاوات', 'Recitations', 'Récitations')),
          centerTitle: true,
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              tooltip: _audioTr(context, 'تحديث القائمة', 'Refresh list', 'Actualiser la liste'),
              onPressed: _loading ? null : () => _load(force: true),
            ),
          ],
        ),
        bottomNavigationBar: const _MiniPlayer(),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(_error!, textAlign: TextAlign.center),
                          const SizedBox(height: 16),
                          FilledButton.icon(
                            onPressed: () => _load(force: true),
                            icon: const Icon(Icons.refresh_rounded),
                            label: Text(_audioTr(context, 'إعادة المحاولة', 'Try again', 'Réessayer')),
                          ),
                        ],
                      ),
                    ),
                  )
                : Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                        child: TextField(
                          onChanged: (v) => setState(() => _query = v),
                          decoration: InputDecoration(
                            hintText: _audioTr(context, 'ابحث عن قارئ...', 'Search for a reciter...', 'Rechercher un récitant...'),
                            prefixIcon: const Icon(Icons.search_rounded),
                            filled: true,
                            fillColor: colors.surfaceContainerHighest,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: visible.isEmpty
                            ? Center(
                                child: Text(
                                  _audioTr(context, 'لا توجد نتائج', 'No results found', 'Aucun résultat'),
                                  style: TextStyle(
                                    color: colors.onSurfaceVariant,
                                  ),
                                ),
                              )
                            : ListView.builder(
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  4,
                                  16,
                                  16,
                                ),
                                itemCount: visible.length,
                                itemBuilder: (context, index) {
                                  final reciter = visible[index];

                                  return Card(
                                    elevation: 0,
                                    color: colors.surfaceContainerLow,
                                    margin: const EdgeInsets.only(bottom: 8),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: ListTile(
                                      leading: CircleAvatar(
                                        backgroundColor:
                                            colors.primaryContainer,
                                        child: Icon(
                                          Icons.record_voice_over_rounded,
                                          color: colors.onPrimaryContainer,
                                        ),
                                      ),
                                      title: Text(
                                        reciter.name,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      subtitle: Text(
                                        reciter.moshafs.length == 1
                                            ? reciter.moshafs.first.name
                                            : _audioTr(context, ' روايات', '${reciter.moshafs.length} recitations', '${reciter.moshafs.length} récitations'),
                                      ),
                                      trailing: Icon(
                                        Icons.arrow_forward_ios_rounded,
                                        size: 17,
                                        color: colors.primary,
                                      ),
                                      onTap: () {
                                        Navigator.of(context).push(
                                          MaterialPageRoute(
                                            builder: (_) => ReciterScreen(
                                              reciter: reciter,
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
      ),
    );
  }
}

// ───────────────────────── شاشة سور القارئ ─────────────────────────

class ReciterScreen extends StatefulWidget {
  final Reciter reciter;

  const ReciterScreen({super.key, required this.reciter});

  @override
  State<ReciterScreen> createState() => _ReciterScreenState();
}

class _ReciterScreenState extends State<ReciterScreen> {
  final AudioController _ctrl = AudioController.instance;
  late int _moshafIndex;

  Moshaf get _moshaf => widget.reciter.moshafs[_moshafIndex];

  @override
  void initState() {
    super.initState();

    final hafs = widget.reciter.moshafs.indexWhere(
      (m) => m.name.contains('حفص'),
    );
    _moshafIndex = hafs >= 0 ? hafs : 0;

    _ctrl.refreshDownloaded(_moshaf);
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _play(int surah) async {
    final error = await _ctrl.play(
      widget.reciter,
      _moshaf,
      surah,
      surahTitle: _audioTr(
        context,
        'سورة ${_audioSurahName(context, surah)}',
        'Surah ${_audioSurahName(context, surah)}',
        'Sourate ${_audioSurahName(context, surah)}',
      ),
    );
    if (!mounted || error == null) return;

    _showMessage(_audioTr(
      context,
      error,
      error == 'تعذر التشغيل، تحقق من الاتصال بالإنترنت'
          ? 'Playback failed. Check your internet connection.'
          : 'Download failed. Check your internet connection.',
      error == 'تعذر التشغيل، تحقق من الاتصال بالإنترنت'
          ? 'Lecture impossible. Vérifiez votre connexion Internet.'
          : 'Téléchargement impossible. Vérifiez votre connexion Internet.',
    ));
  }

  Future<void> _download(int surah) async {
    final error = await _ctrl.download(_moshaf, surah);
    if (!mounted || error == null) return;

    _showMessage(_audioTr(
      context,
      error,
      error == 'تعذر التشغيل، تحقق من الاتصال بالإنترنت'
          ? 'Playback failed. Check your internet connection.'
          : 'Download failed. Check your internet connection.',
      error == 'تعذر التشغيل، تحقق من الاتصال بالإنترنت'
          ? 'Lecture impossible. Vérifiez votre connexion Internet.'
          : 'Téléchargement impossible. Vérifiez votre connexion Internet.',
    ));
  }
  Future<void> _confirmDelete(int surah) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => Directionality(
        textDirection: _audioIsArabic(context) ? TextDirection.rtl : TextDirection.ltr,
        child: AlertDialog(
          title: Text(_audioTr(context, 'حذف التنزيل', 'Delete download', 'Supprimer le téléchargement')),
          content: Text(
            _audioTr(context, 'هل تريد حذف سورة ${_audioSurahName(context, surah)} من الجهاز؟', 'Do you want to delete Surah ${_audioSurahName(context, surah)} from the device?', 'Voulez-vous supprimer la sourate ${_audioSurahName(context, surah)} de l’appareil ?'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(_audioTr(context, 'إلغاء', 'Cancel', 'Annuler')),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(_audioTr(context, 'حذف', 'Delete', 'Supprimer')),
            ),
          ],
        ),
      ),
    );

    if (ok == true) {
      await _ctrl.deleteDownload(_moshaf, surah);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final moshafs = widget.reciter.moshafs;

    return Directionality(
      textDirection: _audioIsArabic(context) ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.reciter.name),
          centerTitle: true,
        ),
        bottomNavigationBar: const _MiniPlayer(),
        body: Column(
          children: [
            if (moshafs.length > 1)
              SizedBox(
                height: 56,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  itemCount: moshafs.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    return ChoiceChip(
                      label: Text(moshafs[index].name),
                      selected: index == _moshafIndex,
                      onSelected: (_) {
                        setState(() => _moshafIndex = index);
                        _ctrl.refreshDownloaded(_moshaf);
                      },
                    );
                  },
                ),
              ),
            Expanded(
              child: ListenableBuilder(
                listenable: _ctrl,
                builder: (context, _) {
                  final moshaf = _moshaf;

                  return ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    itemCount: moshaf.surahs.length,
                    itemBuilder: (context, index) {
                      final surah = moshaf.surahs[index];
                      final k = _ctrl.key(moshaf, surah);
                      final isCurrent =
                          _ctrl.moshaf?.id == moshaf.id &&
                          _ctrl.surah == surah;

                      final Widget trailing;

                      if (_ctrl.progress.containsKey(k)) {
                        trailing = Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                value: _ctrl.progress[k],
                                strokeWidth: 2.5,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close_rounded),
                              tooltip: _audioTr(context, 'إلغاء التنزيل', 'Cancel download', 'Annuler le téléchargement'),
                              onPressed: () =>
                                  _ctrl.cancelDownload(moshaf, surah),
                            ),
                          ],
                        );
                      } else if (_ctrl.downloaded.contains(k)) {
                        trailing = IconButton(
                          icon: Icon(
                            Icons.download_done_rounded,
                            color: colors.primary,
                          ),
                          tooltip: _audioTr(context, 'حذف التنزيل', 'Delete download', 'Supprimer le téléchargement'),
                          onPressed: () => _confirmDelete(surah),
                        );
                      } else {
                        trailing = IconButton(
                          icon: const Icon(Icons.download_rounded),
                          tooltip: _audioTr(context, 'تنزيل للاستماع دون إنترنت', 'Download for offline listening', 'Télécharger pour écouter hors ligne'),
                          onPressed: () => _download(surah),
                        );
                      }

                      return Card(
                        elevation: 0,
                        color: isCurrent
                            ? colors.primaryContainer.withValues(alpha: 0.5)
                            : colors.surfaceContainerLow,
                        margin: const EdgeInsets.only(bottom: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: colors.primaryContainer,
                            child: Text(
                              '$surah',
                              style: TextStyle(
                                color: colors.onPrimaryContainer,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          title: Text(
                            _audioSurahName(context, surah),
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          subtitle: _ctrl.downloaded.contains(k)
                              ? Text(_audioTr(context, 'محمّلة على الجهاز', 'Downloaded to device', 'Téléchargée sur l’appareil'))
                              : null,
                          trailing: trailing,
                          onTap: () => _play(surah),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ───────────────────────── المشغل المصغر ─────────────────────────

class _MiniPlayer extends StatelessWidget {
  const _MiniPlayer();

  @override
  Widget build(BuildContext context) {
    final ctrl = AudioController.instance;
    final colors = Theme.of(context).colorScheme;

    return ListenableBuilder(
      listenable: ctrl,
      builder: (context, _) {
        final surah = ctrl.surah;
        final reciter = ctrl.reciter;

        if (surah == null || reciter == null) {
          return const SizedBox.shrink();
        }

        return Material(
          color: colors.surfaceContainerHigh,
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _audioTr(context, 'سورة ${_audioSurahName(context, surah)}', 'Surah ${_audioSurahName(context, surah)}', 'Sourate ${_audioSurahName(context, surah)}'),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            Text(
                              reciter.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                color: colors.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.skip_previous_rounded),
                        tooltip: _audioTr(context, 'السورة السابقة', 'Previous surah', 'Sourate précédente'),
                        onPressed: ctrl.previous,
                      ),
                      StreamBuilder<PlayerState>(
                        stream: ctrl.player.playerStateStream,
                        builder: (context, snapshot) {
                          final state = snapshot.data;
                          final processing = state?.processingState;

                          final loading =
                              processing == ProcessingState.loading ||
                              processing == ProcessingState.buffering;

                          if (loading) {
                            return const SizedBox(
                              width: 48,
                              height: 48,
                              child: Padding(
                                padding: EdgeInsets.all(13),
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                ),
                              ),
                            );
                          }

                          final playing = (state?.playing ?? false) &&
                              processing != ProcessingState.completed;

                          return IconButton.filled(
                            icon: Icon(
                              playing
                                  ? Icons.pause_rounded
                                  : Icons.play_arrow_rounded,
                            ),
                            tooltip: playing ? _audioTr(context, 'إيقاف مؤقت', 'Pause', 'Pause') : _audioTr(context, 'تشغيل', 'Play', 'Lecture'),
                            onPressed: ctrl.toggle,
                          );
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.skip_next_rounded),
                        tooltip: _audioTr(context, 'السورة التالية', 'Next surah', 'Sourate suivante'),
                        onPressed: ctrl.next,
                      ),
                    ],
                  ),
                  _SeekBar(player: ctrl.player),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SeekBar extends StatefulWidget {
  final AudioPlayer player;

  const _SeekBar({required this.player});

  @override
  State<_SeekBar> createState() => _SeekBarState();
}

class _SeekBarState extends State<_SeekBar> {
  double? _drag;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final small = TextStyle(
      fontSize: 11,
      color: colors.onSurfaceVariant,
    );

    return StreamBuilder<Duration?>(
      stream: widget.player.durationStream,
      builder: (context, durationSnapshot) {
        final duration = durationSnapshot.data ?? Duration.zero;
        final maxMs = duration.inMilliseconds > 0
            ? duration.inMilliseconds.toDouble()
            : 1.0;

        return StreamBuilder<Duration>(
          stream: widget.player.positionStream,
          builder: (context, positionSnapshot) {
            final position = positionSnapshot.data ?? Duration.zero;

            final value = (_drag ?? position.inMilliseconds.toDouble())
                .clamp(0.0, maxMs)
                .toDouble();

            return Row(
              children: [
                Text(
                  _fmt(Duration(milliseconds: value.round())),
                  style: small,
                ),
                Expanded(
                  child: Slider(
                    value: value,
                    max: maxMs,
                    onChanged: (v) => setState(() => _drag = v),
                    onChangeEnd: (v) {
                      widget.player.seek(
                        Duration(milliseconds: v.round()),
                      );
                      setState(() => _drag = null);
                    },
                  ),
                ),
                Text(_fmt(duration), style: small),
              ],
            );
          },
        );
      },
    );
  }
}
