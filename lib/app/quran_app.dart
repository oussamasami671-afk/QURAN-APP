import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';
import '../core/app_settings.dart';
import '../core/theme/app_theme.dart';
import '../core/services/notification_service.dart';

import '../features/adhkar/presentation/screens/adhkar_screen.dart';
import '../features/audio/presentation/screens/audio_screen.dart';
import '../features/home/presentation/screens/home_screen.dart';
import '../features/prayer/presentation/screens/prayer_screen.dart';
import '../features/quran/presentation/screens/quran_screen.dart';
import '../features/settings/presentation/screens/settings_screen.dart';

final _router = GoRouter(
  initialLocation: '/',
  routes: [
    ShellRoute(
      builder: (context, state, child) {
        return MainNavigationShell(child: child);
      },
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const HomeScreen(),
        ),
        GoRoute(
          path: '/quran',
          builder: (context, state) {
            final surah = int.tryParse(
              state.uri.queryParameters['surah'] ?? '',
            );
            final verse = int.tryParse(
              state.uri.queryParameters['verse'] ?? '',
            );

            return QuranScreen(
              initialSurah: surah,
              initialVerse: verse,
            );
          },
        ),
        GoRoute(
          path: '/adhkar',
          builder: (context, state) => AdhkarScreen(
            initialCategory: state.uri.queryParameters['category'],
          ),
        ),
      ],
    ),
    GoRoute(
      path: '/audio',
      builder: (context, state) => const AudioScreen(),
    ),
    GoRoute(
      path: '/prayer',
      builder: (context, state) => const PrayerScreen(),
    ),
    GoRoute(
      path: '/settings',
      builder: (context, state) => const SettingsScreen(),
    ),
  ],
);


String _navigationTr(BuildContext context, String ar, String en, String fr) {
  switch (Localizations.localeOf(context).languageCode) {
    case 'en':
      return en;
    case 'fr':
      return fr;
    default:
      return ar;
  }
}
class MainNavigationShell extends StatelessWidget {
  final Widget child;

  const MainNavigationShell({
    super.key,
    required this.child,
  });

  int _currentIndex(String location) {
    if (location.startsWith('/quran')) return 1;
    if (location.startsWith('/adhkar')) return 2;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;

    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex(location),
        onDestinationSelected: (index) {
          switch (index) {
            case 0:
              context.go('/');
              break;
            case 1:
              context.go('/quran');
              break;
            case 2:
              context.go('/adhkar');
              break;
          }
        },
        destinations: [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: _navigationTr(context, 'الرئيسية', 'Home', 'Accueil'),
          ),
          NavigationDestination(
            icon: Icon(Icons.menu_book_outlined),
            selectedIcon: Icon(Icons.menu_book_rounded),
            label: _navigationTr(context, 'المصحف', 'Quran', 'Coran'),
          ),
          NavigationDestination(
            icon: Icon(Icons.auto_awesome_outlined),
            selectedIcon: Icon(Icons.auto_awesome_rounded),
            label: _navigationTr(context, 'الأذكار', 'Adhkar', 'Adhkar'),
          ),
        ],
      ),
    );
  }
}

class QuranApp extends StatefulWidget {
  const QuranApp({super.key});

  @override
  State<QuranApp> createState() => _QuranAppState();
}

class _QuranAppState extends State<QuranApp> {
  @override
  void initState() {
    super.initState();

    NotificationService.instance.setNotificationTapHandler(
      _handleNotificationPayload,
    );

    unawaited(NotificationService.instance.initialize());
  }

  void _handleNotificationPayload(String payload) {
    if (!mounted) return;

    if (payload.startsWith('ayah:')) {
      final parts = payload.split(':');

      if (parts.length == 3) {
        final surah = int.tryParse(parts[1]);
        final verse = int.tryParse(parts[2]);

        if (surah != null &&
            verse != null &&
            surah >= 1 &&
            surah <= 114 &&
            verse >= 1) {
          _router.go('/quran?surah=$surah&verse=$verse');
          return;
        }
      }
    }

    if (payload.startsWith('preset:')) {
      final key = payload.substring('preset:'.length);

      switch (key) {
        case 'morning_adhkar':
          _router.go('/adhkar?category=morning');
          return;
        case 'evening_adhkar':
          _router.go('/adhkar?category=evening');
          return;
        case 'quran_reading':
        case 'daily_ayah':
          _router.go('/quran');
          return;
        case 'istighfar':
          _router.go('/adhkar');
          return;
        case 'hadith':
          _router.go('/');
          return;
      }
    }

    if (payload.startsWith('custom:')) {
      _router.go('/');
      return;
    }

    _router.go('/');
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: appSettings,
      builder: (context, child) {
        return MaterialApp.router(
          title: 'Quran',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: appSettings.themeMode,
          routerConfig: _router,
          locale: appSettings.locale,
          supportedLocales: const [
            Locale('ar'),
            Locale('en'),
            Locale('fr'),
          ],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
        );
      },
    );
  }
}
