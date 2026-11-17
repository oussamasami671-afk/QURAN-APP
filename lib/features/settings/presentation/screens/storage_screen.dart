
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:quran/quran.dart' as quran;

import '../../../../features/audio/presentation/screens/audio_screen.dart';

class _DownloadItem {
  final File file;
  final Moshaf? moshaf;
  final Reciter? reciter;
  final int surah;
  final int size;

  const _DownloadItem({
    required this.file,
    required this.moshaf,
    required this.reciter,
    required this.surah,
    required this.size,
  });
}

class StorageScreen extends StatefulWidget {
  const StorageScreen({super.key});

  @override
  State<StorageScreen> createState() => _StorageScreenState();
}

class _StorageScreenState extends State<StorageScreen> {
  String _surahName(BuildContext context, int number) {
    final language = Localizations.localeOf(context).languageCode;
    if (language == 'en') return quran.getSurahNameEnglish(number);
    if (language == 'fr') return quran.getSurahNameFrench(number);
    return quran.getSurahNameArabic(number);
  }

  String _tr(BuildContext context, String ar, String en, String fr) {
    final language = Localizations.localeOf(context).languageCode;
    if (language == 'en') return en;
    if (language == 'fr') return fr;
    return ar;
  }

  final AudioController _audio = AudioController.instance;

  List<_DownloadItem> _items = [];
  bool _loading = true;
  int _totalSize = 0;

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  Future<void> _loadDownloads() async {
    setState(() => _loading = true);

    final items = <_DownloadItem>[];
    var total = 0;

    try {
      List<Reciter> reciters = [];

      try {
        reciters = await RecitersRepository().load();
      } catch (_) {
        // نعرض الملفات حتى لو تعذر تحميل قائمة القراء.
      }

      final moshafMap = <int, (Moshaf, Reciter)>{};

      for (final reciter in reciters) {
        for (final moshaf in reciter.moshafs) {
          moshafMap[moshaf.id] = (moshaf, reciter);
        }
      }

      final docs = await getApplicationDocumentsDirectory();
      final root = Directory(p.join(docs.path, 'quran_audio'));

      if (await root.exists()) {
        await for (final entity in root.list(recursive: true)) {
          if (entity is! File || !entity.path.endsWith('.mp3')) {
            continue;
          }

          final parts = p.split(entity.path);
          if (parts.length < 2) continue;

          final moshafId = int.tryParse(parts[parts.length - 2]);
          final surahText = p.basenameWithoutExtension(entity.path);
          final surah = int.tryParse(surahText);

          if (moshafId == null ||
              surah == null ||
              surah < 1 ||
              surah > 114) {
            continue;
          }

          final size = await entity.length();
          final match = moshafMap[moshafId];

          items.add(
            _DownloadItem(
              file: entity,
              moshaf: match?.$1,
              reciter: match?.$2,
              surah: surah,
              size: size,
            ),
          );

          total += size;
        }
      }

      items.sort((a, b) {
        final nameA = a.reciter?.name ?? '';
        final nameB = b.reciter?.name ?? '';
        final compare = nameA.compareTo(nameB);
        return compare != 0 ? compare : a.surah.compareTo(b.surah);
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_tr(context, 'تعذر قراءة ملفات التخزين', 'Could not read storage files', 'Impossible de lire les fichiers de stockage'))),
        );
      }
    }

    if (!mounted) return;

    setState(() {
      _items = items;
      _totalSize = total;
      _loading = false;
    });
  }

  Future<void> _deleteItem(_DownloadItem item) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_tr(context, 'حذف التنزيل', 'Delete download', 'Supprimer le téléchargement')),
        content: Text(
          _tr(context, 'هل تريد حذف سورة ${_surahName(context, item.surah)}؟', 'Do you want to delete Surah ${_surahName(context, item.surah)}?', 'Voulez-vous supprimer la sourate ${_surahName(context, item.surah)} ?'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(_tr(context, 'إلغاء', 'Cancel', 'Annuler')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(_tr(context, 'حذف', 'Delete', 'Supprimer')),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      if (await item.file.exists()) {
        await item.file.delete();
      }

      if (item.moshaf != null) {
        await _audio.refreshDownloaded(item.moshaf!);
      }

      await _loadDownloads();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_tr(context, 'تعذر حذف الملف', 'Could not delete file', 'Impossible de supprimer le fichier'))),
        );
      }
    }
  }

  Future<void> _deleteAll() async {
    if (_items.isEmpty) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_tr(context, 'حذف جميع التنزيلات', 'Delete all downloads', 'Supprimer tous les téléchargements')),
        content: Text(
          _tr(context, 'هل تريد حذف جميع السور المحمّلة من الجهاز؟', 'Do you want to delete all downloaded surahs from this device?', 'Voulez-vous supprimer toutes les sourates téléchargées de cet appareil ?'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(_tr(context, 'إلغاء', 'Cancel', 'Annuler')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(_tr(context, 'حذف الكل', 'Delete all', 'Tout supprimer')),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final docs = await getApplicationDocumentsDirectory();
      final root = Directory(p.join(docs.path, 'quran_audio'));

      if (await root.exists()) {
        await root.delete(recursive: true);
      }

      for (final item in _items) {
        if (item.moshaf != null) {
          await _audio.refreshDownloaded(item.moshaf!);
        }
      }

      await _loadDownloads();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_tr(context, 'تعذر حذف جميع الملفات', 'Could not delete all files', 'Impossible de supprimer tous les fichiers'))),
        );
      }
    }
  }

  Future<void> _play(_DownloadItem item) async {
    if (item.moshaf == null || item.reciter == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_tr(context, 'تعذر تحديد القارئ لهذا الملف', 'Could not identify the reciter for this file', 'Impossible d’identifier le récitant de ce fichier')),
        ),
      );
      return;
    }

    final error = await _audio.play(
      item.reciter!,
      item.moshaf!,
      item.surah,
      surahTitle: _tr(context, 'سورة ${_surahName(context, item.surah)}', 'Surah ${_surahName(context, item.surah)}', 'Sourate ${_surahName(context, item.surah)}'),
    );

    if (error != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error)),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    _loadDownloads();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(_tr(context, 'التخزين', 'Storage', 'Stockage')),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: _loading ? null : _loadDownloads,
            icon: const Icon(Icons.refresh_rounded),
            tooltip: _tr(context, 'تحديث', 'Refresh', 'Actualiser'),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadDownloads,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Card(
                    elevation: 0,
                    color: colors.primaryContainer,
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          Icon(
                            Icons.storage_rounded,
                            size: 38,
                            color: colors.onPrimaryContainer,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _formatSize(_totalSize),
                            style: Theme.of(context)
                                .textTheme
                                .headlineMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: colors.onPrimaryContainer,
                                ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _tr(context, ' سورة محمّلة', ' surahs downloaded', ' sourates téléchargées'),
                            style: TextStyle(
                              color: colors.onPrimaryContainer,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (_items.isNotEmpty)
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            _tr(context, 'السور المحمّلة', 'Downloaded surahs', 'Sourates téléchargées'),
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        TextButton.icon(
                          onPressed: _deleteAll,
                          icon: const Icon(Icons.delete_outline),
                          label: Text(_tr(context, 'حذف الكل', 'Delete all', 'Tout supprimer')),
                          style: TextButton.styleFrom(
                            foregroundColor: colors.error,
                          ),
                        ),
                      ],
                    ),
                  if (_items.isEmpty)
                    Padding(
                      padding: EdgeInsets.only(top: 60),
                      child: Column(
                        children: [
                          Icon(
                            Icons.download_for_offline_outlined,
                            size: 64,
                            color: Colors.grey,
                          ),
                          SizedBox(height: 16),
                          Text(
                            _tr(context, 'لا توجد سور محمّلة', 'No surahs downloaded', 'Aucune sourate téléchargée'),
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            _tr(context, 'السور التي تنزّلها ستظهر هنا', 'Your downloaded surahs will appear here', 'Les sourates téléchargées apparaîtront ici'),
                            style: TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  ..._items.map((item) {
                    final surahName =
                        _surahName(context, item.surah);

                    return Card(
                      elevation: 0,
                      color: colors.surfaceContainerLow,
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: colors.primaryContainer,
                          child: Icon(
                            Icons.download_done_rounded,
                            color: colors.onPrimaryContainer,
                          ),
                        ),
                        title: Text(
                          surahName,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        subtitle: Text(
                          '${item.reciter?.name ?? _tr(context, 'قارئ غير معروف', 'Unknown reciter', 'Récitant inconnu')}'
                          ' • ${_formatSize(item.size)}',
                        ),
                        onTap: () => _play(item),
                        trailing: IconButton(
                          icon: Icon(
                            Icons.delete_outline,
                            color: colors.error,
                          ),
                          tooltip: _tr(context, 'حذف', 'Delete', 'Supprimer'),
                          onPressed: () => _deleteItem(item),
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
    );
  }
}
