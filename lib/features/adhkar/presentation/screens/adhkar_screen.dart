import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:quran/quran.dart' as quran;
import 'package:quran_app/features/quran/data/translation_service.dart';

// النصوص هنا مطابقة لما ورد في «حصن المسلم» وكتب الحديث،
// ولكل ذكر مصدره. نصوص القرآن تُؤخذ من مكتبة quran.

class Dhikr {
  final String text;
  final int count;
  final String source;
  final String? note;
  final int? quranSurah;
  final int? quranStartAyah;
  final int? quranEndAyah;
  final String? englishText;
  final String? frenchText;

  const Dhikr(
    this.text,
    this.count,
    this.source, {
    this.note,
    this.quranSurah,
    this.quranStartAyah,
    this.quranEndAyah,
    this.englishText,
    this.frenchText,
  });
}

class AdhkarCategory {
  final String title;
  final IconData icon;
  final List<Dhikr> items;

  const AdhkarCategory(this.title, this.icon, this.items);
}

String _verse(int surah, int verse) =>
    quran.getVerse(surah, verse, verseEndSymbol: true);

String _surahText(int surah) => List.generate(
      quran.getVerseCount(surah),
      (i) => _verse(surah, i + 1),
    ).join(' ');
String _uiText(BuildContext context, String ar, String en, String fr) {
  switch (Localizations.localeOf(context).languageCode) {
    case 'en':
      return en;
    case 'fr':
      return fr;
    default:
      return ar;
  }
}

String _categoryName(BuildContext context, String title) {
  switch (title) {
    case 'أذكار الصباح':
      return _uiText(context, title, 'Morning Adhkar', 'Invocations du matin');
    case 'أذكار المساء':
      return _uiText(context, title, 'Evening Adhkar', 'Invocations du soir');
    case 'أذكار بعد الصلاة':
      return _uiText(context, title, 'After-prayer Adhkar', 'Invocations après la prière');
    case 'أذكار النوم':
      return _uiText(context, title, 'Before-sleep Adhkar', 'Invocations avant le sommeil');
    case 'أذكار الاستيقاظ':
      return _uiText(context, title, 'Upon waking', 'Au réveil');
    case 'دخول المنزل والخروج منه':
      return _uiText(context, title, 'Entering and leaving home', 'Entrer et sortir de la maison');
    default:
      return title;
  }
}

Dhikr _ayatAlKursi(String source) =>
    Dhikr(_verse(2, 255), 1, source, note: 'آية الكرسي', quranSurah: 2, quranStartAyah: 255, quranEndAyah: 255);

List<Dhikr> _threeQuls(String source) => [
      Dhikr(_surahText(112), 3, source, note: 'سورة الإخلاص', quranSurah: 112, quranStartAyah: 1, quranEndAyah: 4),
      Dhikr(_surahText(113), 3, source, note: 'سورة الفلق', quranSurah: 113, quranStartAyah: 1, quranEndAyah: 5),
      Dhikr(_surahText(114), 3, source, note: 'سورة الناس', quranSurah: 114, quranStartAyah: 1, quranEndAyah: 6),
    ];

List<Dhikr> _morningEvening({required bool morning}) {
  return [
    _ayatAlKursi('رواه الحاكم، وصححه الألباني (صحيح الترغيب)'),
    ..._threeQuls('رواه أبو داود والترمذي والنسائي'),
    Dhikr(
      morning
          ? 'أَصْبَحْنَا وَأَصْبَحَ الْمُلْكُ لِلَّهِ، وَالْحَمْدُ لِلَّهِ، لَا إِلَهَ إِلَّا اللَّهُ وَحْدَهُ لَا شَرِيكَ لَهُ، لَهُ الْمُلْكُ وَلَهُ الْحَمْدُ وَهُوَ عَلَى كُلِّ شَيْءٍ قَدِيرٌ، رَبِّ أَسْأَلُكَ خَيْرَ مَا فِي هَذَا الْيَوْمِ وَخَيْرَ مَا بَعْدَهُ، وَأَعُوذُ بِكَ مِنْ شَرِّ مَا فِي هَذَا الْيَوْمِ وَشَرِّ مَا بَعْدَهُ، رَبِّ أَعُوذُ بِكَ مِنَ الْكَسَلِ وَسُوءِ الْكِبَرِ، رَبِّ أَعُوذُ بِكَ مِنْ عَذَابٍ فِي النَّارِ وَعَذَابٍ فِي الْقَبْرِ'
          : 'أَمْسَيْنَا وَأَمْسَى الْمُلْكُ لِلَّهِ، وَالْحَمْدُ لِلَّهِ، لَا إِلَهَ إِلَّا اللَّهُ وَحْدَهُ لَا شَرِيكَ لَهُ، لَهُ الْمُلْكُ وَلَهُ الْحَمْدُ وَهُوَ عَلَى كُلِّ شَيْءٍ قَدِيرٌ، رَبِّ أَسْأَلُكَ خَيْرَ مَا فِي هَذِهِ اللَّيْلَةِ وَخَيْرَ مَا بَعْدَهَا، وَأَعُوذُ بِكَ مِنْ شَرِّ مَا فِي هَذِهِ اللَّيْلَةِ وَشَرِّ مَا بَعْدَهَا، رَبِّ أَعُوذُ بِكَ مِنَ الْكَسَلِ وَسُوءِ الْكِبَرِ، رَبِّ أَعُوذُ بِكَ مِنْ عَذَابٍ فِي النَّارِ وَعَذَابٍ فِي الْقَبْرِ',
      1,
      'رواه مسلم',
      englishText: morning
          ? 'We have entered the morning, and all sovereignty belongs to Allah. Praise be to Allah. There is no god but Allah alone, without partner. To Him belongs the dominion and all praise, and He is capable of all things. My Lord, I ask You for the good of this day and what follows it, and I seek refuge in You from the evil of this day and what follows it. My Lord, I seek refuge in You from laziness, the difficulties of old age, the punishment of the Fire, and the punishment of the grave.'
          : 'We have entered the evening, and all sovereignty belongs to Allah. Praise be to Allah. There is no god but Allah alone, without partner. To Him belongs the dominion and all praise, and He is capable of all things. My Lord, I ask You for the good of this night and what follows it, and I seek refuge in You from the evil of this night and what follows it. My Lord, I seek refuge in You from laziness, the difficulties of old age, the punishment of the Fire, and the punishment of the grave.',
      frenchText: morning
          ? 'Nous voici au matin, et la royauté appartient à Allah. Louange à Allah. Il n’y a de divinité qu’Allah, Seul et sans associé. À Lui appartiennent la royauté et la louange, et Il est capable de toute chose. Seigneur, je Te demande le bien de ce jour et de ce qui vient après, et je cherche refuge auprès de Toi contre son mal et celui de ce qui vient après. Seigneur, je cherche refuge auprès de Toi contre la paresse, les difficultés de la vieillesse, le châtiment du Feu et celui de la tombe.'
          : 'Nous voici au soir, et la royauté appartient à Allah. Louange à Allah. Il n’y a de divinité qu’Allah, Seul et sans associé. À Lui appartiennent la royauté et la louange, et Il est capable de toute chose. Seigneur, je Te demande le bien de cette nuit et de ce qui vient après, et je cherche refuge auprès de Toi contre son mal et celui de ce qui vient après. Seigneur, je cherche refuge auprès de Toi contre la paresse, les difficultés de la vieillesse, le châtiment du Feu et celui de la tombe.',
    ),
    Dhikr(
      morning
          ? 'أَصْبَحْنَا وَأَصْبَحَ الْمُلْكُ لِلَّهِ رَبِّ الْعَالَمِينَ، اللَّهُمَّ إِنِّي أَسْأَلُكَ خَيْرَ هَذَا الْيَوْمِ، فَتْحَهُ وَنَصْرَهُ وَنُورَهُ وَبَرَكَتَهُ وَهُدَاهُ، وَأَعُوذُ بِكَ مِنْ شَرِّ مَا فِيهِ وَشَرِّ مَا بَعْدَهُ'
          : 'أَمْسَيْنَا وَأَمْسَى الْمُلْكُ لِلَّهِ رَبِّ الْعَالَمِينَ، اللَّهُمَّ إِنِّي أَسْأَلُكَ خَيْرَ هَذِهِ اللَّيْلَةِ، فَتْحَهَا وَنَصْرَهَا وَنُورَهَا وَبَرَكَتَهَا وَهُدَاهَا، وَأَعُوذُ بِكَ مِنْ شَرِّ مَا فِيهَا وَشَرِّ مَا بَعْدَهَا',
      1,
      'رواه أبو داود، وإسناده جيد (حصن المسلم)',
      englishText: morning
          ? 'We have entered the morning, and all sovereignty belongs to Allah, Lord of the worlds. O Allah, I ask You for the good of this day: its opening, victory, light, blessings, and guidance. I seek refuge in You from the evil within it and the evil that follows it.'
          : 'We have entered the evening, and all sovereignty belongs to Allah, Lord of the worlds. O Allah, I ask You for the good of this night: its opening, victory, light, blessings, and guidance. I seek refuge in You from the evil within it and the evil that follows it.',
      frenchText: morning
          ? 'Nous voici au matin, et la royauté appartient à Allah, Seigneur des mondes. Ô Allah, je Te demande le bien de ce jour : son ouverture, sa victoire, sa lumière, ses bénédictions et sa bonne direction. Je cherche refuge auprès de Toi contre le mal qu’il contient et celui qui vient après.'
          : 'Nous voici au soir, et la royauté appartient à Allah, Seigneur des mondes. Ô Allah, je Te demande le bien de cette nuit : son ouverture, sa victoire, sa lumière, ses bénédictions et sa bonne direction. Je cherche refuge auprès de Toi contre le mal qu’elle contient et celui qui vient après.',
    ),
    Dhikr(
      morning
          ? 'اللَّهُمَّ بِكَ أَصْبَحْنَا، وَبِكَ أَمْسَيْنَا، وَبِكَ نَحْيَا، وَبِكَ نَمُوتُ، وَإِلَيْكَ النُّشُورُ'
          : 'اللَّهُمَّ بِكَ أَمْسَيْنَا، وَبِكَ أَصْبَحْنَا، وَبِكَ نَحْيَا، وَبِكَ نَمُوتُ، وَإِلَيْكَ الْمَصِيرُ',
      1,
      'رواه أبو داود والترمذي',
      englishText: morning
          ? 'O Allah, by You we enter the morning, by You we enter the evening, by You we live, and by You we die, and to You is the resurrection.'
          : 'O Allah, by You we enter the evening, by You we enter the morning, by You we live, and by You we die, and to You is the final return.',
      frenchText: morning
          ? 'Ô Allah, c’est par Toi que nous entrons dans le matin et le soir, c’est par Toi que nous vivons et mourons, et c’est vers Toi que se fera la résurrection.'
          : 'Ô Allah, c’est par Toi que nous entrons dans le soir et le matin, c’est par Toi que nous vivons et mourons, et c’est vers Toi que sera le retour final.',
    ),
    const Dhikr(
      'اللَّهُمَّ أَنْتَ رَبِّي لَا إِلَهَ إِلَّا أَنْتَ، خَلَقْتَنِي وَأَنَا عَبْدُكَ، وَأَنَا عَلَى عَهْدِكَ وَوَعْدِكَ مَا اسْتَطَعْتُ، أَعُوذُ بِكَ مِنْ شَرِّ مَا صَنَعْتُ، أَبُوءُ لَكَ بِنِعْمَتِكَ عَلَيَّ، وَأَبُوءُ بِذَنْبِي فَاغْفِرْ لِي فَإِنَّهُ لَا يَغْفِرُ الذُّنُوبَ إِلَّا أَنْتَ',
      1,
      'رواه البخاري',
      note: 'سيد الاستغفار',
      englishText: 'O Allah, You are my Lord. There is no god but You. You created me, and I am Your servant. I remain faithful to my covenant and promise to You as much as I can. I seek refuge in You from the evil of what I have done. I acknowledge Your blessings upon me, and I confess my sins. So forgive me, for none forgives sins except You.',
      frenchText: 'Ô Allah, Tu es mon Seigneur. Il n’y a de divinité que Toi. Tu m’as créé et je suis Ton serviteur. Je reste fidèle à mon engagement et à ma promesse envers Toi autant que je le peux. Je cherche refuge auprès de Toi contre le mal de mes actes. Je reconnais Tes bienfaits envers moi et je reconnais mes péchés. Pardonne-moi donc, car nul autre que Toi ne pardonne les péchés.',
    ),
    const Dhikr(
      'اللَّهُمَّ إِنِّي أَسْأَلُكَ الْعَفْوَ وَالْعَافِيَةَ فِي الدُّنْيَا وَالْآخِرَةِ، اللَّهُمَّ إِنِّي أَسْأَلُكَ الْعَفْوَ وَالْعَافِيَةَ فِي دِينِي وَدُنْيَايَ وَأَهْلِي وَمَالِي، اللَّهُمَّ اسْتُرْ عَوْرَاتِي وَآمِنْ رَوْعَاتِي، اللَّهُمَّ احْفَظْنِي مِنْ بَيْنِ يَدَيَّ وَمِنْ خَلْفِي وَعَنْ يَمِينِي وَعَنْ شِمَالِي وَمِنْ فَوْقِي، وَأَعُوذُ بِعَظَمَتِكَ أَنْ أُغْتَالَ مِنْ تَحْتِي',
      1,
      'رواه أبو داود وابن ماجه',
      englishText: 'O Allah, I ask You for forgiveness and well-being in this world and the Hereafter. O Allah, I ask You for well-being in my religion, my worldly life, my family, and my wealth. O Allah, conceal my faults, calm my fears, and protect me from every direction.',
      frenchText: 'Ô Allah, je Te demande le pardon et le bien-être ici-bas et dans l’au-delà. Je Te demande le bien-être dans ma religion, ma vie, ma famille et mes biens. Ô Allah, couvre mes défauts, apaise mes craintes et protège-moi de toutes parts.',
    ),
    const Dhikr(
      'بِسْمِ اللَّهِ الَّذِي لَا يَضُرُّ مَعَ اسْمِهِ شَيْءٌ فِي الْأَرْضِ وَلَا فِي السَّمَاءِ وَهُوَ السَّمِيعُ الْعَلِيمُ',
      3,
      'رواه أبو داود والترمذي',
      englishText: 'In the name of Allah, with whose name nothing on earth or in heaven can cause harm. He is the All-Hearing, the All-Knowing.',
      frenchText: 'Au nom d’Allah, avec le nom duquel rien sur terre ni dans le ciel ne peut causer de mal. Il est Celui qui entend tout et qui sait tout.',
    ),
    const Dhikr(
      'رَضِيتُ بِاللَّهِ رَبًّا، وَبِالْإِسْلَامِ دِينًا، وَبِمُحَمَّدٍ ﷺ نَبِيًّا',
      3,
      'رواه أبو داود والترمذي',
      englishText: 'I am pleased with Allah as my Lord, Islam as my religion, and Muhammad ﷺ as my Prophet.',
      frenchText: 'J’agrée Allah comme Seigneur, l’islam comme religion et Muhammad ﷺ comme Prophète.',
    ),
    if (!morning)
      const Dhikr(
        'أَعُوذُ بِكَلِمَاتِ اللَّهِ التَّامَّاتِ مِنْ شَرِّ مَا خَلَقَ',
        3,
        'رواه مسلم',
        note: 'في المساء',
        englishText: 'I seek refuge in the perfect words of Allah from the evil of what He has created.',
        frenchText: 'Je cherche refuge dans les paroles parfaites d’Allah contre le mal de ce qu’Il a créé.',
      ),
    const Dhikr(
      'سُبْحَانَ اللَّهِ وَبِحَمْدِهِ',
      100,
      'رواه مسلم',
      englishText: 'Glory be to Allah and praise be to Him.',
      frenchText: 'Gloire à Allah et louange à Lui.',
    ),
    const Dhikr(
      'لَا إِلَهَ إِلَّا اللَّهُ وَحْدَهُ لَا شَرِيكَ لَهُ، لَهُ الْمُلْكُ وَلَهُ الْحَمْدُ وَهُوَ عَلَى كُلِّ شَيْءٍ قَدِيرٌ',
      10,
      'رواه النسائي في عمل اليوم والليلة، وصححه الألباني',
      englishText: 'There is no god but Allah alone, without partner. To Him belongs the dominion and all praise, and He is capable of all things.',
      frenchText: 'Il n’y a de divinité qu’Allah, Seul et sans associé. À Lui appartiennent la royauté et la louange, et Il est capable de toute chose.',
    ),
  ];
}

List<AdhkarCategory> _buildCategories() {
  return [
    AdhkarCategory(
      'أذكار الصباح',
      Icons.wb_sunny_rounded,
      _morningEvening(morning: true),
    ),
    AdhkarCategory(
      'أذكار المساء',
      Icons.nights_stay_rounded,
      _morningEvening(morning: false),
    ),
    AdhkarCategory(
      'أذكار بعد الصلاة',
      Icons.mosque_rounded,
      [
        const Dhikr(
          'أَسْتَغْفِرُ اللَّهَ',
          3,
          'رواه مسلم',
          englishText: 'I ask Allah for forgiveness.',
          frenchText: 'Je demande pardon à Allah.',
        ),
        const Dhikr(
          'اللَّهُمَّ أَنْتَ السَّلَامُ وَمِنْكَ السَّلَامُ، تَبَارَكْتَ يَا ذَا الْجَلَالِ وَالْإِكْرَامِ',
          1,
          'رواه مسلم',
          englishText: 'O Allah, You are Peace, and from You comes peace. Blessed are You, Owner of Majesty and Honor.',
          frenchText: 'Ô Allah, Tu es la Paix et la paix vient de Toi. Béni sois-Tu, Détenteur de la majesté et de la générosité.',
        ),
        _ayatAlKursi('رواه النسائي في الكبرى، وصححه الألباني'),
        const Dhikr('سُبْحَانَ اللَّهِ', 33, 'رواه مسلم',
          englishText: 'Glory be to Allah.',
          frenchText: 'Gloire à Allah.',
        ),
        const Dhikr('الْحَمْدُ لِلَّهِ', 33, 'رواه مسلم',
          englishText: 'All praise is due to Allah.',
          frenchText: 'Louange à Allah.',
        ),
        const Dhikr('اللَّهُ أَكْبَرُ', 33, 'رواه مسلم',
          englishText: 'Allah is the Greatest.',
          frenchText: 'Allah est le plus Grand.',
        ),
        const Dhikr(
          'لَا إِلَهَ إِلَّا اللَّهُ وَحْدَهُ لَا شَرِيكَ لَهُ، لَهُ الْمُلْكُ وَلَهُ الْحَمْدُ وَهُوَ عَلَى كُلِّ شَيْءٍ قَدِيرٌ',
          1,
          'رواه مسلم',
          note: 'تمام المئة بعد التسبيح والتحميد والتكبير',
          englishText: 'There is no god but Allah alone, without partner. To Him belongs the dominion and all praise, and He is capable of all things.',
          frenchText: 'Il n’y a de divinité qu’Allah, Seul et sans associé. À Lui appartiennent la royauté et la louange, et Il est capable de toute chose.',
        ),
        const Dhikr(
          'اللَّهُمَّ أَعِنِّي عَلَى ذِكْرِكَ وَشُكْرِكَ وَحُسْنِ عِبَادَتِكَ',
          1,
          'رواه أبو داود، وصححه الألباني',
          englishText: 'O Allah, help me to remember You, thank You, and worship You in the best way.',
          frenchText: 'Ô Allah, aide-moi à me souvenir de Toi, à Te remercier et à T’adorer de la meilleure manière.',
        ),
      ],
    ),
    AdhkarCategory(
      'أذكار النوم',
      Icons.bedtime_rounded,
      [
        _ayatAlKursi('رواه البخاري'),
        Dhikr(
          '${_verse(2, 285)} ${_verse(2, 286)}',
          1,
          'رواه البخاري ومسلم',
          note: 'آخر آيتين من سورة البقرة',
          quranSurah: 2,
          quranStartAyah: 285,
          quranEndAyah: 286,
        ),
        ..._threeQuls('رواه البخاري'),
        const Dhikr(
          'بِاسْمِكَ اللَّهُمَّ أَمُوتُ وَأَحْيَا',
          1,
          'رواه البخاري',
          englishText: 'In Your name, O Allah, I die and I live.',
          frenchText: 'En Ton nom, ô Allah, je meurs et je vis.',
        ),
        const Dhikr(
          'اللَّهُمَّ قِنِي عَذَابَكَ يَوْمَ تَبْعَثُ عِبَادَكَ',
          3,
          'رواه أبو داود، وصححه ابن حجر',
          englishText: 'O Allah, protect me from Your punishment on the Day You resurrect Your servants.',
          frenchText: 'Ô Allah, protège-moi de Ton châtiment le jour où Tu ressusciteras Tes serviteurs.',
        ),
        const Dhikr('سُبْحَانَ اللَّهِ', 33, 'رواه البخاري ومسلم'),
        const Dhikr('الْحَمْدُ لِلَّهِ', 33, 'رواه البخاري ومسلم'),
        const Dhikr('اللَّهُ أَكْبَرُ', 34, 'رواه البخاري ومسلم'),
      ],
    ),
    AdhkarCategory(
      'أذكار الاستيقاظ',
      Icons.alarm_rounded,
      [
        const Dhikr(
          'الْحَمْدُ لِلَّهِ الَّذِي أَحْيَانَا بَعْدَ مَا أَمَاتَنَا وَإِلَيْهِ النُّشُورُ',
          1,
          'رواه البخاري',
          englishText: 'All praise is due to Allah, who gave us life after causing us to die, and to Him is the resurrection.',
          frenchText: 'Louange à Allah qui nous a rendu la vie après nous avoir fait mourir, et c’est vers Lui que se fera la résurrection.',
        ),
      ],
    ),
    AdhkarCategory(
      'دخول المنزل والخروج منه',
      Icons.home_rounded,
      [
        const Dhikr(
          'بِسْمِ اللَّهِ وَلَجْنَا، وَبِسْمِ اللَّهِ خَرَجْنَا، وَعَلَى اللَّهِ رَبِّنَا تَوَكَّلْنَا',
          1,
          'رواه أبو داود',
          note: 'عند دخول المنزل، ثم يسلّم على أهله',
          englishText: 'In the name of Allah we enter, and in the name of Allah we leave, and in our Lord we put our trust.',
          frenchText: 'Au nom d’Allah, nous entrons et au nom d’Allah, nous sortons, et c’est en notre Seigneur que nous plaçons notre confiance.',
        ),
        const Dhikr(
          'بِسْمِ اللَّهِ، تَوَكَّلْتُ عَلَى اللَّهِ، وَلَا حَوْلَ وَلَا قُوَّةَ إِلَّا بِاللَّهِ',
          1,
          'رواه أبو داود والترمذي',
          note: 'عند الخروج من المنزل',
          englishText: 'In the name of Allah, I place my trust in Allah; there is no might or power except through Allah.',
          frenchText: 'Au nom d’Allah, je place ma confiance en Allah. Il n’y a de force ni de puissance qu’en Allah.',
        ),
      ],
    ),
  ];
}

class AdhkarScreen extends StatefulWidget {
  final String? initialCategory;

  const AdhkarScreen({
    super.key,
    this.initialCategory,
  });

  @override
  State<AdhkarScreen> createState() => _AdhkarScreenState();
}

class _AdhkarScreenState extends State<AdhkarScreen> {
  late final List<AdhkarCategory> _categories = _buildCategories();

  String? _translationLanguage;
  bool _translationLoading = false;
  String? _translationError;

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
    _translationError = null;
    _translationLoading = language != 'ar';

    try {
      await TranslationService.instance.load(language);
    } catch (e) {
      _translationError = e.toString();
      debugPrint('ADHKAR TRANSLATION ERROR: $e');
    }

    if (!mounted || _translationLanguage != language) return;

    setState(() {
      _translationLoading = false;
    });
  }

  
  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      final categoryName = switch (widget.initialCategory) {
        'morning' => 'أذكار الصباح',
        'evening' => 'أذكار المساء',
        _ => null,
      };

      if (categoryName == null) return;

      AdhkarCategory? target;

      for (final category in _categories) {
        if (category.title == categoryName) {
          target = category;
          break;
        }
      }

      final selected = target;
      if (selected == null) return;

      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => AdhkarCategoryScreen(
            title: selected.title,
            items: selected.items,
          ),
        ),
      );
    });
  }
@override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: Text(_uiText(context, 'الأذكار والأدعية', 'Adhkar and Supplications', 'Invocations et supplications')),
          centerTitle: true,
        ),
        body: ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: _categories.length + 1,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            if (index == _categories.length) {
              return Padding(
                padding: const EdgeInsets.all(8),
                child: Text(
                  _uiText(context, 'الأذكار مأخوذة من «حصن المسلم» وكتب الحديث، مع ذكر مصدر كل ذكر.', 'These adhkar are based on Hisn al-Muslim and Hadith books, with the source of each dhikr.', 'Ces invocations proviennent de Hisn al-Muslim et des recueils de hadiths, avec la source de chacune.'),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: colors.onSurfaceVariant,
                  ),
                ),
              );
            }

            final category = _categories[index];

            return Card(
              elevation: 0,
              color: colors.surfaceContainerLow,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                leading: CircleAvatar(
                  backgroundColor: colors.primaryContainer,
                  child: Icon(
                    category.icon,
                    color: colors.onPrimaryContainer,
                  ),
                ),
                title: Text(
                  _categoryName(context, category.title),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                subtitle: Text(_uiText(context, '${category.items.length} أذكار', '${category.items.length} adhkar', '${category.items.length} invocations')),
                trailing: Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 17,
                  color: colors.primary,
                ),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => AdhkarCategoryScreen(
                        title: _categoryName(context, category.title),
                        items: category.items,
                      ),
                    ),
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }
}

class AdhkarCategoryScreen extends StatefulWidget {
  final String title;
  final List<Dhikr> items;

  const AdhkarCategoryScreen({
    super.key,
    required this.title,
    required this.items,
  });

  @override
  State<AdhkarCategoryScreen> createState() => _AdhkarCategoryScreenState();
}

class _AdhkarCategoryScreenState extends State<AdhkarCategoryScreen> {
  late List<int> _remaining;

  @override
  void initState() {
    super.initState();
    _resetAll();
  }

  void _resetAll() {
    _remaining = widget.items.map((e) => e.count).toList();
  }

  int get _completed => _remaining.where((r) => r == 0).length;

  void _tap(int index) {
    if (_remaining[index] == 0) return;

    HapticFeedback.selectionClick();

    setState(() => _remaining[index]--);

    if (_remaining[index] == 0) {
      HapticFeedback.mediumImpact();
    }
  }

  String? _getQuranTranslation(Dhikr dhikr) {
    if (dhikr.quranSurah == null ||
        dhikr.quranStartAyah == null ||
        dhikr.quranEndAyah == null) {
      return null;
    }

    final translations = <String>[];

    for (var ayah = dhikr.quranStartAyah!;
        ayah <= dhikr.quranEndAyah!;
        ayah++) {
      final translation =
          TranslationService.instance.getTranslation(
        dhikr.quranSurah!,
        ayah,
      );

      if (translation != null) {
        translations.add(translation);
      }
    }

    return translations.isEmpty ? null : translations.join(' ');
  }

  Future<void> _copy(Dhikr dhikr) async {
    await Clipboard.setData(
      ClipboardData(text: '${dhikr.text}\n(${dhikr.source})'),
    );

    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(_uiText(context, 'تم النسخ', 'Copied', 'Copié')),
          duration: const Duration(seconds: 1),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final total = widget.items.length;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: Text(_categoryName(context, widget.title)),
          centerTitle: true,
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              tooltip: _uiText(context, 'إعادة العدّ', 'Reset count', 'Réinitialiser le compteur'),
              onPressed: () => setState(_resetAll),
            ),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(4),
            child: LinearProgressIndicator(
              value: total == 0 ? 0 : _completed / total,
              minHeight: 4,
            ),
          ),
        ),
        body: ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          itemCount: total,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final dhikr = widget.items[index];
            final language = Localizations.localeOf(context).languageCode;
            final quranTranslation = _getQuranTranslation(dhikr);
            final dhikrTranslation = language == 'en'
                ? dhikr.englishText
                : language == 'fr'
                    ? dhikr.frenchText
                    : null;
            final remaining = _remaining[index];
            final done = remaining == 0;

            return Opacity(
              opacity: done ? 0.55 : 1,
              child: Material(
                color: done
                    ? colors.primaryContainer.withValues(alpha: 0.35)
                    : colors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(16),
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => _tap(index),
                  onLongPress: () => _copy(dhikr),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        if (dhikr.note != null) ...[
                          Text(
                            dhikr.note!,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: colors.primary,
                            ),
                          ),
                          const SizedBox(height: 8),
                        ],
                        Text(
                          dhikr.text,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 22,
                            height: 2,
                            color: colors.onSurface,
                          ),
                        ),
                        if (language != 'ar' &&
                            (quranTranslation != null || dhikrTranslation != null)) ...[
                          const SizedBox(height: 8),
                          Directionality(
                            textDirection: TextDirection.ltr,
                            child: Text(
                              quranTranslation ?? dhikrTranslation!,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 15,
                                height: 1.6,
                                color: colors.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 8),
                        Text(
                          dhikr.source,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12,
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.copy_rounded, size: 20),
                              tooltip: _uiText(context, 'نسخ', 'Copy', 'Copier'),
                              onPressed: () => _copy(dhikr),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: colors.primaryContainer,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: done
                                  ? Icon(
                                      Icons.check_rounded,
                                      color: colors.onPrimaryContainer,
                                    )
                                  : Text(
                                      '$remaining / ${dhikr.count}',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: colors.onPrimaryContainer,
                                      ),
                                    ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}



