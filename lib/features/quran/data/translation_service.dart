import 'dart:convert';
import 'package:flutter/services.dart';

class TranslationService {
  TranslationService._();

  static final TranslationService instance =
      TranslationService._();

  Map<String, String> _translations = {};
  String? _loadedLanguage;

  Future<void> load(String language) async {
    if (language == 'ar') {
      _translations = {};
      _loadedLanguage = 'ar';
      return;
    }

    if (_loadedLanguage == language &&
        _translations.isNotEmpty) {
      return;
    }

    final path = language == 'fr'
        ? 'assets/data/translations/fr.json'
        : 'assets/data/translations/en.json';

    final content = await rootBundle.loadString(path);
    final Map<String, dynamic> data = jsonDecode(content);

    final List<dynamic> verses = data['verses'];
    final Map<String, String> result = {};

    for (final verse in verses) {
      final surah = verse['sura'].toString();
      final ayah = verse['aya'].toString();
      final translation = verse['translation'] as String;

      result['$surah:$ayah'] = translation;
    }

    _translations = result;
    _loadedLanguage = language;
  }

  String? getTranslation(int surah, int ayah) {
    return _translations['$surah:$ayah'];
  }

  bool get isLoaded => _loadedLanguage != null;
}