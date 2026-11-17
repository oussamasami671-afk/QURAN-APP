import 'package:flutter/material.dart';
import '../../../../core/app_settings.dart';
import 'storage_screen.dart';
import 'reminders_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

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

 String getThemeName(BuildContext context, ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return _tr(context, 'فاتح', 'Light', 'Clair');
      case ThemeMode.dark:
        return _tr(context, 'داكن', 'Dark', 'Sombre');
      case ThemeMode.system:
        return _tr(context, 'حسب النظام', 'System default', 'Selon le système');
    }
  }

  String getLanguageName(Locale locale) {
    switch (locale.languageCode) {
      case 'en':
        return 'English';
      case 'fr':
        return 'Français';
      default:
        return 'العربية';
    }
  }

  Future<void> selectTheme(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                _tr(sheetContext, 'اختيار المظهر', 'Choose theme', 'Choisir le thème'),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            _themeTile(sheetContext, ThemeMode.light, getThemeName(sheetContext, ThemeMode.light)),
            _themeTile(sheetContext, ThemeMode.dark, getThemeName(sheetContext, ThemeMode.dark)),
            _themeTile(sheetContext, ThemeMode.system, getThemeName(sheetContext, ThemeMode.system)),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _themeTile(
    BuildContext context,
    ThemeMode mode,
    String title,
  ) {
    return ListTile(
      leading: Icon(
        mode == ThemeMode.light
            ? Icons.light_mode_outlined
            : mode == ThemeMode.dark
                ? Icons.dark_mode_outlined
                : Icons.settings_brightness,
      ),
      title: Text(title),
      trailing: appSettings.themeMode == mode
          ? const Icon(Icons.check_circle, color: Colors.green)
          : null,
      onTap: () async {
        await appSettings.setTheme(mode);
        if (context.mounted) {
          Navigator.pop(context);
        }
      },
    );
  }

  Future<void> selectLanguage(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                _tr(sheetContext, 'اختيار اللغة', 'Choose language', 'Choisir la langue'),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            _languageTile(sheetContext, 'ar', 'العربية'),
            _languageTile(sheetContext, 'en', 'English'),
            _languageTile(sheetContext, 'fr', 'Français'),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _languageTile(
    BuildContext context,
    String code,
    String title,
  ) {
    return ListTile(
      title: Text(title),
      trailing: appSettings.locale.languageCode == code
          ? const Icon(Icons.check_circle, color: Colors.green)
          : null,
      onTap: () async {
        await appSettings.setLanguage(code);
        if (context.mounted) {
          Navigator.pop(context);
        }
      },
    );
  }

  void showAbout(BuildContext context) {
    showAboutDialog(
      context: context,
      applicationName: 'Quran App',
      applicationVersion: '1.0.0',
      applicationLegalese: _tr(
        context,
        'تطبيق للقرآن الكريم والأذكار',
        'An app for the Holy Quran and Adhkar',
        'Une application pour le Saint Coran et les invocations',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isRtl = Directionality.of(context) == TextDirection.rtl;

    return Scaffold(
      appBar: AppBar(
        title: Text(_tr(context, 'الإعدادات', 'Settings', 'Paramètres')),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            _tr(context, 'التخصيص', 'Personalization', 'Personnalisation'),
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.palette_outlined),
                  title: Text(_tr(context, 'المظهر', 'Theme', 'Thème')),
                  subtitle: Text(getThemeName(context, appSettings.themeMode)),
                  trailing: Icon(isRtl ? Icons.chevron_left : Icons.chevron_right),
                  onTap: () => selectTheme(context),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.language),
                  title: Text(_tr(context, 'اللغة', 'Language', 'Langue')),
                  subtitle: Text(getLanguageName(appSettings.locale)),
                  trailing: Icon(isRtl ? Icons.chevron_left : Icons.chevron_right),
                  onTap: () => selectLanguage(context),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            _tr(context, 'التطبيق', 'Application', 'Application'),
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.notifications_active_outlined),
                  title: Text(_tr(context, 'التذكيرات والإشعارات', 'Reminders and notifications', 'Rappels et notifications')),
                  subtitle: Text(_tr(context, 'أذكار وقرآن وتذكيرات خاصة', 'Adhkar, Quran and custom reminders', 'Invocations, Coran et rappels personnalisés')),
                  trailing: Icon(isRtl ? Icons.chevron_left : Icons.chevron_right),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const RemindersScreen(),
                      ),
                    );
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.storage_outlined),
                  title: Text(_tr(context, 'التخزين', 'Storage', 'Stockage')),
                  subtitle: Text(_tr(context, 'إدارة البيانات والصوتيات', 'Manage data and audio files', 'Gérer les données et les fichiers audio')),
                  trailing: Icon(isRtl ? Icons.chevron_left : Icons.chevron_right),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const StorageScreen(),
                      ),
                    );
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.info_outline),
                  title: Text(_tr(context, 'حول التطبيق', 'About the app', 'À propos de l’application')),
                  subtitle: const Text('Quran App - 1.0.0'),
                  trailing: Icon(isRtl ? Icons.chevron_left : Icons.chevron_right),
                  onTap: () => showAbout(context),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}