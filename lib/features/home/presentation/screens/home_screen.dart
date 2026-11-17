import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:go_router/go_router.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int? _lastSurah;
  int _lastVerse = 1;
  bool _isLoading = true;

  static const Color _green = Color(0xFF145C45);
  static const Color _darkGreen = Color(0xFF0D3F32);

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

  @override
  void initState() {
    super.initState();
    _loadLastReading();
  }

  Future<void> refreshLastReading() async {
    await _loadLastReading();
  }

  Future<void> _loadLastReading() async {
    final prefs = await SharedPreferences.getInstance();

    final surah = prefs.getInt('last_read_surah');
    final verse = prefs.getInt('last_read_verse') ?? 1;

    if (!mounted) return;

    setState(() {
      _lastSurah = surah;
      _lastVerse = verse;
      _isLoading = false;
    });
  }

  Widget _sectionTitle(
    BuildContext context,
    String title, {
    Widget? trailing,
  }) {
    final colors = Theme.of(context).colorScheme;

    return Row(
      children: [
        Container(
          width: 4,
          height: 23,
          decoration: BoxDecoration(
            color: colors.primary,
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        const SizedBox(width: 9),
        Text(
          title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: colors.onSurface,
          ),
        ),
        const Spacer(),
        if (trailing != null) trailing,
      ],
    );
  }

  Widget _featureCard({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    final colors = Theme.of(context).colorScheme;

    return Material(
      color: colors.surface,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: colors.outlineVariant),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 49,
                height: 49,
                decoration: BoxDecoration(
                  color: colors.primaryContainer,
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(
                  icon,
                  color: colors.onPrimaryContainer,
                  size: 27,
                ),
              ),
              const Spacer(),
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: colors.onSurface,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 12,
                  color: colors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final hasReading = _lastSurah != null && _lastSurah! > 0;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        title: Text(
          _tr(context, 'القرآن الكريم', 'The Holy Quran', 'Le Saint Coran'),
          style: TextStyle(
            color: colors.onSurface,
            fontWeight: FontWeight.bold,
            fontSize: 21,
          ),
        ),
        actions: [
          IconButton(
            tooltip: _tr(context, 'الإعدادات', 'Settings', 'Paramètres'),
            onPressed: () => context.push('/settings'),
            icon: Icon(Icons.settings_outlined, color: colors.primary),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
          children: [
            Container(
              padding: const EdgeInsets.all(23),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                  colors: [_green, _darkGreen],
                ),
                borderRadius: BorderRadius.circular(25),
                boxShadow: [
                  BoxShadow(
                    color: _green.withValues(alpha: 0.18),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  Positioned(
                    left: -12,
                    top: -15,
                    child: Icon(
                      Icons.auto_awesome,
                      size: 105,
                      color: Colors.white.withValues(alpha: 0.07),
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _tr(
                          context,
                          'بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ\nابدأ يومك مع القرآن',
                          'Begin your day with the Quran',
                          'Commencez votre journée avec le Coran',
                        ),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _tr(
                          context,
                          'اقرأ، وتدبّر، واجعل القرآن نور يومك',
                          'Read, reflect, and let the Quran illuminate your day',
                          'Lisez, méditez et faites du Coran la lumière de votre journée',
                        ),
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 22),
                      FilledButton.icon(
                        onPressed: () => context.push('/quran'),
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: _darkGreen,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 12,
                          ),
                        ),
                        icon: const Icon(Icons.menu_book_rounded, size: 19),
                        label: Text(
                          _tr(context, 'ابدأ القراءة', 'Start reading', 'Commencer la lecture'),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            _sectionTitle(
              context,
              _tr(context, 'متابعة القراءة', 'Continue reading', 'Continuer la lecture'),
            ),
            const SizedBox(height: 13),
            Material(
              color: colors.surface,
              borderRadius: BorderRadius.circular(20),
              child: InkWell(
                onTap: _isLoading ? null : () => context.push('/quran'),
                borderRadius: BorderRadius.circular(20),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: colors.primaryContainer,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Icon(
                          Icons.bookmark_outline_rounded,
                          color: colors.onPrimaryContainer,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 13),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _isLoading
                                  ? _tr(context, 'جارٍ تحميل موضع القراءة...', 'Loading reading position...', 'Chargement de la position de lecture...')
                                  : hasReading
                                      ? _tr(context, 'أكمل من حيث وصلت', 'Continue where you left off', 'Reprendre là où vous vous êtes arrêté')
                                      : _tr(context, 'لم تبدأ القراءة بعد', 'You have not started reading yet', 'Vous n’avez pas encore commencé la lecture'),
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                                color: colors.onSurface,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              _isLoading
                                  ? _tr(context, 'يرجى الانتظار', 'Please wait', 'Veuillez patienter')
                                  : hasReading
                                      ? _tr(
                                          context,
                                          'السورة رقم $_lastSurah • الآية $_lastVerse',
                                          'Surah $_lastSurah • Verse $_lastVerse',
                                          'Sourate $_lastSurah • Verset $_lastVerse',
                                        )
                                      : _tr(context, 'ابدأ رحلتك مع القرآن الكريم', 'Start your journey with the Holy Quran', 'Commencez votre parcours avec le Saint Coran'),
                              style: TextStyle(
                                color: colors.onSurfaceVariant,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 17,
                        color: colors.primary,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 29),
            _sectionTitle(
              context,
              _tr(context, 'استكشف التطبيق', 'Explore the app', 'Explorer l’application'),
            ),
            const SizedBox(height: 14),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.12,
              children: [
                _featureCard(
                  context: context,
                  title: _tr(context, 'المصحف', 'Quran', 'Coran'),
                  subtitle: _tr(context, 'قراءة وتدبّر', 'Read and reflect', 'Lire et méditer'),
                  icon: Icons.menu_book_rounded,
                  onTap: () => context.push('/quran'),
                ),
                _featureCard(
                  context: context,
                  title: _tr(context, 'التلاوات', 'Recitations', 'Récitations'),
                  subtitle: _tr(context, 'استمع إلى القرآن', 'Listen to the Quran', 'Écouter le Coran'),
                  icon: Icons.headphones_rounded,
                  onTap: () => context.push('/audio'),
                ),
                _featureCard(
                  context: context,
                  title: _tr(context, 'الأذكار', 'Adhkar', 'Invocations'),
                  subtitle: _tr(context, 'أذكار وأدعية', 'Remembrances and supplications', 'Évocations et invocations'),
                  icon: Icons.auto_awesome_rounded,
                  onTap: () => context.push('/adhkar'),
                ),
                _featureCard(
                  context: context,
                  title: _tr(context, 'مواقيت الصلاة', 'Prayer times', 'Heures de prière'),
                  subtitle: _tr(context, 'الصلاة والقبلة', 'Prayer and Qibla', 'Prière et Qibla'),
                  icon: Icons.mosque_outlined,
                  onTap: () => context.push('/prayer'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}