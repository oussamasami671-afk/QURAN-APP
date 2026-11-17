
import 'dart:async';


import 'package:flutter/material.dart';
import 'package:quran_app/features/quran/data/translation_service.dart';
import 'package:quran_app/features/quran/data/tafsir_service.dart';
import 'package:quran/quran.dart' as quran;
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'package:shared_preferences/shared_preferences.dart';

class QuranScreen extends StatefulWidget {
  final int? initialSurah;
  final int? initialVerse;

  const QuranScreen({
    super.key,
    this.initialSurah,
    this.initialVerse,
  });

  @override
  State<QuranScreen> createState() => _QuranScreenState();
}

class _QuranScreenState extends State<QuranScreen> {
  bool _quranIsArabic(BuildContext context) =>
      Localizations.localeOf(context).languageCode == 'ar';

  String _surahName(BuildContext context, int number) {
    switch (Localizations.localeOf(context).languageCode) {
      case 'en':
        return quran.getSurahNameEnglish(number);
      case 'fr':
        return quran.getSurahNameFrench(number);
      default:
        return quran.getSurahNameArabic(number);
    }
  }
  String _quranTr(BuildContext context, String ar, String en, String fr) {
    switch (Localizations.localeOf(context).languageCode) {
      case 'en':
        return en;
      case 'fr':
        return fr;
      default:
        return ar;
    }
  }
  static const double _defaultFontSize = 27;

  int? selectedSurah;
  int? lastSurah;
  int lastVerse = 1;
  int currentVerse = 1;

  String searchQuery = '';
  double fontSize = _defaultFontSize;

  bool tafsirLoading = false;
  String? tafsirError;

  String? selectedTafsirId;

  bool translationLoading = false;
  String? translationError;
  String? _translationLanguage;

  ItemScrollController _itemScrollController =
      ItemScrollController();

  ItemPositionsListener _positionsListener =
      ItemPositionsListener.create();

  Timer? _saveTimer;

  late final List<String> _normalizedNames;

  @override
  void initState() {
    super.initState();

    _normalizedNames = List.generate(
      114,
      (i) => _normalize(quran.getSurahNameArabic(i + 1)),
    );

    final initialSurah = widget.initialSurah;

    if (initialSurah != null &&
        initialSurah >= 1 &&
        initialSurah <= 114) {
      selectedSurah = initialSurah;

      final verseCount = quran.getVerseCount(initialSurah);
      currentVerse = (widget.initialVerse ?? 1)
          .clamp(1, verseCount)
          .toInt();
    }

    _positionsListener.itemPositions.addListener(
      _onPositionsChanged,
    );

    _loadPreferences();
    _loadTafsir();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final language = Localizations.localeOf(context).languageCode;

    if (_translationLanguage != language) {
      _translationLanguage = language;
      _loadTranslations(language);
    }
  }

  Future<void> _loadTranslations(String language) async {
    translationError = null;
    translationLoading = language != 'ar';

    try {
      await TranslationService.instance.load(language);
    } catch (e) {
      translationError = e.toString();
      debugPrint('TRANSLATION ERROR: $e');
    }

    if (!mounted || _translationLanguage != language) return;

    setState(() {
      translationLoading = false;
    });
  }
  @override
  void dispose() {
    _saveTimer?.cancel();

    _positionsListener.itemPositions.removeListener(
      _onPositionsChanged,
    );

    super.dispose();
  }

  // تطبيع النص العربي
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

  // تحميل التفسير
  Future<void> _loadTafsir() async {
    if (!mounted) return;

    setState(() {
      tafsirLoading = true;
      tafsirError = null;
    });

    try {
      await TafsirService.instance.initialize();
    } catch (e) {
      tafsirError = e.toString();
      debugPrint('TAFSIR ERROR: $e');
    }

    if (!mounted) return;

    setState(() {
      tafsirLoading = false;
    });
  }

  // تحميل إعدادات القراءة
  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();

    if (!mounted) return;

    setState(() {
      lastSurah = prefs.getInt('last_read_surah');
      lastVerse = prefs.getInt('last_read_verse') ?? 1;
      fontSize =
          prefs.getDouble('reader_font_size') ??
          _defaultFontSize;
    });
  }

  // حفظ حجم الخط
  Future<void> _saveFontSize(double value) async {
    setState(() => fontSize = value);

    final prefs = await SharedPreferences.getInstance();

    await prefs.setDouble('reader_font_size', value);
  }

  // حفظ موضع القراءة
  Future<void> _saveReadingPosition(
    int number,
    int verse,
  ) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setInt('last_read_surah', number);
    await prefs.setInt('last_read_verse', verse);

    if (!mounted) return;

    setState(() {
      lastSurah = number;
      lastVerse = verse;
      currentVerse = verse;
    });
  }

  // فتح سورة
  void _openSurah(int number, {bool resume = false}) {
    final verseCount = quran.getVerseCount(number);

    int targetVerse =
        resume && lastSurah == number ? lastVerse : 1;

    targetVerse = targetVerse.clamp(1, verseCount);

    _saveTimer?.cancel();

    _positionsListener.itemPositions.removeListener(
      _onPositionsChanged,
    );

    setState(() {
      selectedSurah = number;
      currentVerse = targetVerse;

      _itemScrollController = ItemScrollController();
      _positionsListener = ItemPositionsListener.create();
    });

    _positionsListener.itemPositions.addListener(
      _onPositionsChanged,
    );

    _saveReadingPosition(number, targetVerse);
  }

  // إغلاق السورة
  void _closeSurah() {
    _saveTimer?.cancel();
    _saveVisibleVerse();

    setState(() {
      selectedSurah = null;
    });
  }

  // مراقبة التمرير
  void _onPositionsChanged() {
    if (selectedSurah == null) return;

    _saveTimer?.cancel();

    _saveTimer = Timer(
      const Duration(milliseconds: 500),
      _saveVisibleVerse,
    );
  }

  // حفظ أول آية ظاهرة
  void _saveVisibleVerse() {
    final number = selectedSurah;

    if (number == null) return;

    final positions = _positionsListener.itemPositions.value;

    if (positions.isEmpty) return;

    int? visibleVerse;

    for (final position in positions) {
      if (position.index < 1) continue;

      if (position.itemTrailingEdge <= 0.1) continue;

      if (visibleVerse == null ||
          position.index < visibleVerse) {
        visibleVerse = position.index;
      }
    }

    if (visibleVerse != null &&
        visibleVerse != currentVerse) {
      _saveReadingPosition(number, visibleVerse);
    }
  }

  // اختيار التفسير
  Future<void> _selectTafsir(String bookId) async {
    if (tafsirLoading) return;

    setState(() {
      tafsirLoading = true;
      tafsirError = null;
    });

    try {
      await TafsirService.instance.selectBook(bookId);

      if (!mounted) return;

      setState(() {
        selectedTafsirId = bookId;
        tafsirLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        tafsirError = e.toString();
        tafsirLoading = false;
      });

      debugPrint('TAFSIR SELECTION ERROR: $e');
    }
  }

  // عرض تفسير الآية
  void _showTafsir(int surah, int ayah) {
    final tafsir = TafsirService.instance.getTafsir(
      surah,
      ayah,
    );

    final bookTitle =
        TafsirService.instance.selectedBook?.title ?? 'التفسير';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (sheetContext) {
        final colors = Theme.of(sheetContext).colorScheme;

        return Directionality(
          textDirection: _quranIsArabic(sheetContext) ? TextDirection.rtl : TextDirection.ltr,
          child: SafeArea(
            child: Padding(
              padding: EdgeInsets.only(
                right: 22,
                left: 22,
                top: 8,
                bottom: MediaQuery.of(sheetContext)
                        .viewInsets
                        .bottom +
                    24,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'تفسير $bookTitle',
                      style: TextStyle(
                        fontSize: 23,
                        fontWeight: FontWeight.bold,
                        color: colors.primary,
                      ),
                    ),

                    const SizedBox(height: 8),

                    Text(
                      'سورة ${_surahName(context, surah)}'
                      ' • الآية $ayah',
                      style: TextStyle(
                        fontSize: 14,
                        color: colors.onSurfaceVariant,
                      ),
                    ),

                    const SizedBox(height: 16),

                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: colors.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        quran.getVerse(
                          surah,
                          ayah,
                          verseEndSymbol: true,
                        ),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 23,
                          height: 2,
                          color: colors.onSurface,
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    Row(
                      children: [
                        Icon(
                          Icons.menu_book_rounded,
                          color: colors.primary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          "تفسير ${TafsirService.instance.selectedBook?.title ?? 'التفسير'}",
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    if (tafsirLoading)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(20),
                          child: CircularProgressIndicator(),
                        ),
                      )
                    else if (tafsirError != null)
                      Text(
                        'تعذر تحميل التفسير. تحقق من ملف البيانات.',
                        style: TextStyle(
                          color: colors.error,
                          fontSize: 15,
                        ),
                      )
                    else if (tafsir == null || tafsir.isEmpty)
                      Text(
                        'لم تتم إضافة تفسير هذه الآية بعد.',
                        style: TextStyle(
                          fontSize: 16,
                          height: 1.9,
                          color: colors.onSurfaceVariant,
                        ),
                      )
                    else
                      Text(
                        tafsir,
                        textAlign: TextAlign.justify,
                        style: TextStyle(
                          fontSize: 17,
                          height: 2,
                          color: colors.onSurface,
                        ),
                      ),

                    const SizedBox(height: 20),

                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: () {
                          Navigator.pop(sheetContext);
                        },
                        child: const Text('إغلاق'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Directionality(
      textDirection: _quranIsArabic(context) ? TextDirection.rtl : TextDirection.ltr,
      child: PopScope(
        canPop: selectedSurah == null,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _closeSurah();
        },
        child: Scaffold(
          appBar: AppBar(
            title: Text(
              selectedSurah == null
                  ? _quranTr(context, 'المصحف الشريف', 'The Holy Quran', 'Le Saint Coran')
                  : _surahName(context, selectedSurah!),
            ),
            centerTitle: true,
            leading: selectedSurah != null
                ? IconButton(
                    icon: const Icon(Icons.arrow_back_rounded),
                    onPressed: _closeSurah,
                  )
                : null,
            actions: [
              if (selectedSurah != null) ...[
                PopupMenuButton<String>(
                  tooltip: _quranTr(context, 'اختيار التفسير', 'Choose tafsir', 'Choisir le tafsir'),
                  enabled: !tafsirLoading,
                  initialValue: selectedTafsirId,
                  icon: const Icon(Icons.menu_book_rounded),
                  onSelected: _selectTafsir,
                  itemBuilder: (context) {
                    return TafsirService.instance.books.map((book) {
                      return PopupMenuItem<String>(
                        value: book.id,
                        child: Text(book.title),
                      );
                    }).toList();
                  },
                ),

                PopupMenuButton<double>(
                  icon: const Icon(Icons.text_fields_rounded),
                  tooltip: _quranTr(context, 'حجم الخط', 'Font size', 'Taille du texte'),
                  initialValue: fontSize,
                  onSelected: _saveFontSize,
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 22.0,
                      child: Text(_quranTr(context, 'خط صغير', 'Small', 'Petit')),
                    ),
                    PopupMenuItem(
                      value: 27.0,
                      child: Text(_quranTr(context, 'خط متوسط', 'Medium', 'Moyen')),
                    ),
                    PopupMenuItem(
                      value: 32.0,
                      child: Text(_quranTr(context, 'خط كبير', 'Large', 'Grand')),
                    ),
                    PopupMenuItem(
                      value: 36.0,
                      child: Text(_quranTr(context, 'خط كبير جداً', 'Extra large', 'Très grand')),
                    ),
                  ],
                ),
              ],
            ],
          ),

          body: selectedSurah == null
              ? _buildSurahList(colors)
              : _buildReader(colors),
        ),
      ),
    );
  }

  // قائمة السور
  Widget _buildSurahList(ColorScheme colors) {
    final query = _normalize(searchQuery);

    final surahs = List.generate(114, (index) => index + 1)
        .where(
          (number) =>
              _normalizedNames[number - 1].contains(query),
        )
        .toList();

    return Column(
      children: [
        if (lastSurah != null && searchQuery.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Card(
              elevation: 0,
              color: colors.primaryContainer,
              child: ListTile(
                leading: Icon(
                  Icons.menu_book_rounded,
                  color: colors.onPrimaryContainer,
                ),
                title: Text(
                  _quranTr(context, 'متابعة القراءة', 'Continue reading', 'Continuer la lecture'),
                  style: TextStyle(
                    color: colors.onPrimaryContainer,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                subtitle: Text(
                  '${_surahName(context, lastSurah!)}'
                  ' • ${_quranTr(context, "الآية", "Verse", "Verset")} $lastVerse',
                  style: TextStyle(
                    color: colors.onPrimaryContainer,
                  ),
                ),
                trailing: Icon(
                  Icons.arrow_forward_rounded,
                  color: colors.onPrimaryContainer,
                ),
                onTap: () => _openSurah(
                  lastSurah!,
                  resume: true,
                ),
              ),
            ),
          ),

        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          child: TextField(
            onChanged: (value) {
              setState(() => searchQuery = value);
            },
            decoration: InputDecoration(
              hintText: _quranTr(context, 'ابحث عن سورة...', 'Search for a surah...', 'Rechercher une sourate...'),
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
          child: surahs.isEmpty
              ? Center(
                  child: Text(
                    _quranTr(context, 'لا توجد نتائج', 'No results found', 'Aucun résultat'),
                    style: TextStyle(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(
                    16,
                    4,
                    16,
                    20,
                  ),
                  itemCount: surahs.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final number = surahs[index];
                    final name =
                        _surahName(context, number);
                    final verses =
                        quran.getVerseCount(number);

                    return Card(
                      elevation: 0,
                      color: colors.surfaceContainerLow,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: ListTile(
                        contentPadding:
                            const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 7,
                        ),
                        leading: CircleAvatar(
                          backgroundColor: colors.primaryContainer,
                          child: Text(
                            '$number',
                            style: TextStyle(
                              color: colors.onPrimaryContainer,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        title: Text(
                          name,
                          style: const TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        subtitle: Text(_quranTr(context, '$verses آيات', '$verses verses', '$verses versets')),
                        trailing: Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 17,
                          color: colors.primary,
                        ),
                        onTap: () => _openSurah(number),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  // صفحة القراءة
  Widget _buildReader(ColorScheme colors) {
    final number = selectedSurah!;
    final surahName =
        _surahName(context, number);
    final verseCount =
        quran.getVerseCount(number);

    final showBasmala = number != 1 && number != 9;

    final itemCount = verseCount + 1;

    return Column(
      children: [
        Expanded(
          child: ScrollablePositionedList.builder(
            key: ValueKey(number),
            itemScrollController: _itemScrollController,
            itemPositionsListener: _positionsListener,
            initialScrollIndex:
                currentVerse.clamp(0, verseCount),
            initialAlignment: 0.02,
            padding: const EdgeInsets.fromLTRB(
              20,
              20,
              20,
              24,
            ),
            itemCount: itemCount,
            itemBuilder: (context, index) {
              if (index == 0) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 22,
                    ),
                    decoration: BoxDecoration(
                      color: colors.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      children: [
                        Text(
                          surahName,
                          style: TextStyle(
                            fontSize: 25,
                            fontWeight: FontWeight.bold,
                            color: colors.primary,
                          ),
                        ),

                        const SizedBox(height: 10),

                        Text(
                          _quranTr(context, 'السورة رقم $number • $verseCount آيات', 'Surah $number • $verseCount verses', 'Sourate $number • $verseCount versets'),
                          style: TextStyle(
                            color: colors.onSurfaceVariant,
                            fontSize: 13,
                          ),
                        ),

                        if (showBasmala) ...[
                          const SizedBox(height: 16),
                          Text(
                            quran.basmala,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: fontSize,
                              height: 2,
                              color: colors.onSurface,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              }

              final verseNumber = index;

              final verse = quran.getVerse(
                number,
                verseNumber,
                verseEndSymbol: true,
              );

              final isCurrent =
                  currentVerse == verseNumber;

              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Material(
                  color: isCurrent
                      ? colors.primaryContainer.withValues(
                          alpha: 0.35,
                        )
                      : colors.surface,
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),

                    onTap: () {
                      _saveReadingPosition(
                        number,
                        verseNumber,
                      );

                      _showTafsir(
                        number,
                        verseNumber,
                      );
                    },

                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            verse,
                            textAlign: TextAlign.justify,
                            style: TextStyle(
                              fontSize: fontSize,
                              height: 2.1,
                              color: colors.onSurface,
                            ),
                          ),

                          if (Localizations.localeOf(context).languageCode != 'ar') ...[
                            const SizedBox(height: 12),
                            const Divider(),
                            const SizedBox(height: 8),

                            Builder(
                              builder: (context) {
                                final translation =
                                    TranslationService.instance.getTranslation(
                                  number,
                                  verseNumber,
                                );

                                if (translationLoading) {
                                  return const Center(
                                    child: CircularProgressIndicator(),
                                  );
                                }

                                if (translationError != null || translation == null) {
                                  return Text(
                                    'Translation unavailable',
                                    textDirection: TextDirection.ltr,
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: colors.error,
                                    ),
                                  );
                                }

                                return Directionality(
                                  textDirection: TextDirection.ltr,
                                  child: Text(
                                    translation,
                                    textAlign: TextAlign.start,
                                    style: TextStyle(
                                      fontSize: 16,
                                      height: 1.8,
                                      color: colors.onSurfaceVariant,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),

        // التنقل بين السور
        Container(
          padding: const EdgeInsets.fromLTRB(
            16,
            12,
            16,
            18,
          ),
          decoration: BoxDecoration(
            color: colors.surface,
            border: Border(
              top: BorderSide(
                color: colors.outlineVariant,
              ),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: number > 1
                      ? () => _openSurah(number - 1)
                      : null,
                  icon: const Icon(Icons.arrow_back_rounded),
                  label: Text(_quranTr(context, 'السابق', 'Previous', 'Précédent')),
                ),
              ),

              const SizedBox(width: 12),

              Expanded(
                child: FilledButton.icon(
                  onPressed: number < 114
                      ? () => _openSurah(number + 1)
                      : null,
                  icon: const Icon(
                    Icons.arrow_forward_rounded,
                  ),
                  label: Text(_quranTr(context, 'التالي', 'Next', 'Suivant')),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}





