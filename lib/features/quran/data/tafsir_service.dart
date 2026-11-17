

import 'dart:convert';
import 'package:flutter/services.dart';

class TafsirBook {
  final String id;
  final String title;
  final String author;
  final String asset;
  final int ayahCount;

  const TafsirBook({
    required this.id,
    required this.title,
    required this.author,
    required this.asset,
    required this.ayahCount,
  });

  factory TafsirBook.fromJson(Map<String, dynamic> json) {
    return TafsirBook(
      id: json['id'],
      title: json['title'],
      author: json['author'],
      asset: json['asset'],
      ayahCount: json['ayahCount'],
    );
  }
}

/// Removes HTML tags/entities from tafsir text before display.
String cleanTafsirText(String input) {
  var t = input;

  // line breaks
  t = t.replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n');
  t = t.replaceAll(RegExp(r'</p\s*>', caseSensitive: false), '\n');

  // remove every remaining tag (<span ...>, </span>, ...)
  t = t.replaceAll(RegExp(r'<[^>]+>'), '');

  // common HTML entities
  t = t
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&amp;', '&')
      .replaceAll('&quot;', '"')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>');

  // stray carriage returns and extra blank lines
  t = t.replaceAll('\r', '');
  t = t.replaceAll(RegExp(r'[ \t]+\n'), '\n');
  t = t.replaceAll(RegExp(r'\n{3,}'), '\n\n');

  return t.trim();
}

class TafsirService {
  TafsirService._();

  static final TafsirService instance = TafsirService._();

  static const String _catalogPath =
      'assets/data/tafsir_catalog.json';

  List<TafsirBook> _books = [];
  Map<String, String> _tafsir = {};

  String? _selectedBookId;
  bool _isInitialized = false;
  bool _isLoaded = false;

  List<TafsirBook> get books => List.unmodifiable(_books);

  String? get selectedBookId => _selectedBookId;

  TafsirBook? get selectedBook {
    for (final book in _books) {
      if (book.id == _selectedBookId) return book;
    }
    return null;
  }

  bool get isLoaded => _isLoaded;

  Future<void> initialize() async {
    if (_isInitialized) return;

    final catalogString =
        await rootBundle.loadString(_catalogPath);

    final List<dynamic> data = jsonDecode(catalogString);

    _books = data
        .map((item) => TafsirBook.fromJson(
              item as Map<String, dynamic>,
            ))
        .toList();

    if (_books.isEmpty) {
      throw Exception('Ù„Ø§ ØªÙˆØ¬Ø¯ ÙƒØªØ¨ ØªÙØ³ÙŠØ±');
    }

    const defaultBookId = 'tafsir_muyassar';

    final defaultBook = _books.firstWhere(
      (book) => book.id == defaultBookId,
      orElse: () => _books.first,
    );

    await selectBook(defaultBook.id);

    _isInitialized = true;
  }

  Future<void> selectBook(String bookId) async {
    final book = _books.firstWhere(
      (item) => item.id == bookId,
      orElse: () => throw Exception('ÙƒØªØ§Ø¨ Ø§Ù„ØªÙØ³ÙŠØ± ØºÙŠØ± Ù…ÙˆØ¬ÙˆØ¯'),
    );

    if (_selectedBookId == bookId && _isLoaded) return;

    final jsonString = await rootBundle.loadString(book.asset);
    final List<dynamic> data = jsonDecode(jsonString);

    final Map<String, String> result = {};

    for (final item in data) {
      final surah = item['sura'] as int;
      final ayah = item['ayah'] as int;
      final text = item['text'] as String;

      result['$surah:$ayah'] = text;
    }

    _tafsir = result;
    _selectedBookId = book.id;
    _isLoaded = true;
  }

  String? getTafsir(int surah, int ayah) {
    if (!_isLoaded) return null;

    final raw = _tafsir['$surah:$ayah'];
    return raw == null ? null : cleanTafsirText(raw);
  }

  void clear() {
    _tafsir.clear();
    _isLoaded = false;
    _isInitialized = false;
    _selectedBookId = null;
    _books = [];
  }
}
