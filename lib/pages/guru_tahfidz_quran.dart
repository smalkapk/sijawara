import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme.dart';
import '../services/quran_reading_service.dart';
import 'surah_detail_page.dart';

// ── Data Model ──
class Surah {
  final int number;
  final String name;
  final String arabicName;
  final int ayatCount;
  final String type; // Makkiyah / Madaniyah

  const Surah({
    required this.number,
    required this.name,
    required this.arabicName,
    required this.ayatCount,
    required this.type,
  });
}

// ── Surah Data (114 Surahs) ──
const List<Surah> allSurahs = [
  Surah(
    number: 1,
    name: 'Al-Fatihah',
    arabicName: 'الفاتحة',
    ayatCount: 7,
    type: 'Makkiyah',
  ),
  Surah(
    number: 2,
    name: 'Al-Baqarah',
    arabicName: 'البقرة',
    ayatCount: 286,
    type: 'Madaniyah',
  ),
  Surah(
    number: 3,
    name: 'Ali \'Imran',
    arabicName: 'آل عمران',
    ayatCount: 200,
    type: 'Madaniyah',
  ),
  Surah(
    number: 4,
    name: 'An-Nisa\'',
    arabicName: 'النساء',
    ayatCount: 176,
    type: 'Madaniyah',
  ),
  Surah(
    number: 5,
    name: 'Al-Ma\'idah',
    arabicName: 'المائدة',
    ayatCount: 120,
    type: 'Madaniyah',
  ),
  Surah(
    number: 6,
    name: 'Al-An\'am',
    arabicName: 'الأنعام',
    ayatCount: 165,
    type: 'Makkiyah',
  ),
  Surah(
    number: 7,
    name: 'Al-A\'raf',
    arabicName: 'الأعراف',
    ayatCount: 206,
    type: 'Makkiyah',
  ),
  Surah(
    number: 8,
    name: 'Al-Anfal',
    arabicName: 'الأنفال',
    ayatCount: 75,
    type: 'Madaniyah',
  ),
  Surah(
    number: 9,
    name: 'At-Taubah',
    arabicName: 'التوبة',
    ayatCount: 129,
    type: 'Madaniyah',
  ),
  Surah(
    number: 10,
    name: 'Yunus',
    arabicName: 'يونس',
    ayatCount: 109,
    type: 'Makkiyah',
  ),
  Surah(
    number: 11,
    name: 'Hud',
    arabicName: 'هود',
    ayatCount: 123,
    type: 'Makkiyah',
  ),
  Surah(
    number: 12,
    name: 'Yusuf',
    arabicName: 'يوسف',
    ayatCount: 111,
    type: 'Makkiyah',
  ),
  Surah(
    number: 13,
    name: 'Ar-Ra\'d',
    arabicName: 'الرعد',
    ayatCount: 43,
    type: 'Madaniyah',
  ),
  Surah(
    number: 14,
    name: 'Ibrahim',
    arabicName: 'إبراهيم',
    ayatCount: 52,
    type: 'Makkiyah',
  ),
  Surah(
    number: 15,
    name: 'Al-Hijr',
    arabicName: 'الحجر',
    ayatCount: 99,
    type: 'Makkiyah',
  ),
  Surah(
    number: 16,
    name: 'An-Nahl',
    arabicName: 'النحل',
    ayatCount: 128,
    type: 'Makkiyah',
  ),
  Surah(
    number: 17,
    name: 'Al-Isra\'',
    arabicName: 'الإسراء',
    ayatCount: 111,
    type: 'Makkiyah',
  ),
  Surah(
    number: 18,
    name: 'Al-Kahf',
    arabicName: 'الكهف',
    ayatCount: 110,
    type: 'Makkiyah',
  ),
  Surah(
    number: 19,
    name: 'Maryam',
    arabicName: 'مريم',
    ayatCount: 98,
    type: 'Makkiyah',
  ),
  Surah(
    number: 20,
    name: 'Taha',
    arabicName: 'طه',
    ayatCount: 135,
    type: 'Makkiyah',
  ),
  Surah(
    number: 21,
    name: 'Al-Anbiya\'',
    arabicName: 'الأنبياء',
    ayatCount: 112,
    type: 'Makkiyah',
  ),
  Surah(
    number: 22,
    name: 'Al-Hajj',
    arabicName: 'الحج',
    ayatCount: 78,
    type: 'Madaniyah',
  ),
  Surah(
    number: 23,
    name: 'Al-Mu\'minun',
    arabicName: 'المؤمنون',
    ayatCount: 118,
    type: 'Makkiyah',
  ),
  Surah(
    number: 24,
    name: 'An-Nur',
    arabicName: 'النور',
    ayatCount: 64,
    type: 'Madaniyah',
  ),
  Surah(
    number: 25,
    name: 'Al-Furqan',
    arabicName: 'الفرقان',
    ayatCount: 77,
    type: 'Makkiyah',
  ),
  Surah(
    number: 26,
    name: 'Asy-Syu\'ara\'',
    arabicName: 'الشعراء',
    ayatCount: 227,
    type: 'Makkiyah',
  ),
  Surah(
    number: 27,
    name: 'An-Naml',
    arabicName: 'النمل',
    ayatCount: 93,
    type: 'Makkiyah',
  ),
  Surah(
    number: 28,
    name: 'Al-Qasas',
    arabicName: 'القصص',
    ayatCount: 88,
    type: 'Makkiyah',
  ),
  Surah(
    number: 29,
    name: 'Al-\'Ankabut',
    arabicName: 'العنكبوت',
    ayatCount: 69,
    type: 'Makkiyah',
  ),
  Surah(
    number: 30,
    name: 'Ar-Rum',
    arabicName: 'الروم',
    ayatCount: 60,
    type: 'Makkiyah',
  ),
  Surah(
    number: 31,
    name: 'Luqman',
    arabicName: 'لقمان',
    ayatCount: 34,
    type: 'Makkiyah',
  ),
  Surah(
    number: 32,
    name: 'As-Sajdah',
    arabicName: 'السجدة',
    ayatCount: 30,
    type: 'Makkiyah',
  ),
  Surah(
    number: 33,
    name: 'Al-Ahzab',
    arabicName: 'الأحزاب',
    ayatCount: 73,
    type: 'Madaniyah',
  ),
  Surah(
    number: 34,
    name: 'Saba\'',
    arabicName: 'سبأ',
    ayatCount: 54,
    type: 'Makkiyah',
  ),
  Surah(
    number: 35,
    name: 'Fatir',
    arabicName: 'فاطر',
    ayatCount: 45,
    type: 'Makkiyah',
  ),
  Surah(
    number: 36,
    name: 'Yasin',
    arabicName: 'يس',
    ayatCount: 83,
    type: 'Makkiyah',
  ),
  Surah(
    number: 37,
    name: 'As-Saffat',
    arabicName: 'الصافات',
    ayatCount: 182,
    type: 'Makkiyah',
  ),
  Surah(
    number: 38,
    name: 'Sad',
    arabicName: 'ص',
    ayatCount: 88,
    type: 'Makkiyah',
  ),
  Surah(
    number: 39,
    name: 'Az-Zumar',
    arabicName: 'الزمر',
    ayatCount: 75,
    type: 'Makkiyah',
  ),
  Surah(
    number: 40,
    name: 'Ghafir',
    arabicName: 'غافر',
    ayatCount: 85,
    type: 'Makkiyah',
  ),
  Surah(
    number: 41,
    name: 'Fussilat',
    arabicName: 'فصلت',
    ayatCount: 54,
    type: 'Makkiyah',
  ),
  Surah(
    number: 42,
    name: 'Asy-Syura',
    arabicName: 'الشورى',
    ayatCount: 53,
    type: 'Makkiyah',
  ),
  Surah(
    number: 43,
    name: 'Az-Zukhruf',
    arabicName: 'الزخرف',
    ayatCount: 89,
    type: 'Makkiyah',
  ),
  Surah(
    number: 44,
    name: 'Ad-Dukhan',
    arabicName: 'الدخان',
    ayatCount: 59,
    type: 'Makkiyah',
  ),
  Surah(
    number: 45,
    name: 'Al-Jasiyah',
    arabicName: 'الجاثية',
    ayatCount: 37,
    type: 'Makkiyah',
  ),
  Surah(
    number: 46,
    name: 'Al-Ahqaf',
    arabicName: 'الأحقاف',
    ayatCount: 35,
    type: 'Makkiyah',
  ),
  Surah(
    number: 47,
    name: 'Muhammad',
    arabicName: 'محمد',
    ayatCount: 38,
    type: 'Madaniyah',
  ),
  Surah(
    number: 48,
    name: 'Al-Fath',
    arabicName: 'الفتح',
    ayatCount: 29,
    type: 'Madaniyah',
  ),
  Surah(
    number: 49,
    name: 'Al-Hujurat',
    arabicName: 'الحجرات',
    ayatCount: 18,
    type: 'Madaniyah',
  ),
  Surah(
    number: 50,
    name: 'Qaf',
    arabicName: 'ق',
    ayatCount: 45,
    type: 'Makkiyah',
  ),
  Surah(
    number: 51,
    name: 'Az-Zariyat',
    arabicName: 'الذاريات',
    ayatCount: 60,
    type: 'Makkiyah',
  ),
  Surah(
    number: 52,
    name: 'At-Tur',
    arabicName: 'الطور',
    ayatCount: 49,
    type: 'Makkiyah',
  ),
  Surah(
    number: 53,
    name: 'An-Najm',
    arabicName: 'النجم',
    ayatCount: 62,
    type: 'Makkiyah',
  ),
  Surah(
    number: 54,
    name: 'Al-Qamar',
    arabicName: 'القمر',
    ayatCount: 55,
    type: 'Makkiyah',
  ),
  Surah(
    number: 55,
    name: 'Ar-Rahman',
    arabicName: 'الرحمن',
    ayatCount: 78,
    type: 'Madaniyah',
  ),
  Surah(
    number: 56,
    name: 'Al-Waqi\'ah',
    arabicName: 'الواقعة',
    ayatCount: 96,
    type: 'Makkiyah',
  ),
  Surah(
    number: 57,
    name: 'Al-Hadid',
    arabicName: 'الحديد',
    ayatCount: 29,
    type: 'Madaniyah',
  ),
  Surah(
    number: 58,
    name: 'Al-Mujadalah',
    arabicName: 'المجادلة',
    ayatCount: 22,
    type: 'Madaniyah',
  ),
  Surah(
    number: 59,
    name: 'Al-Hasyr',
    arabicName: 'الحشر',
    ayatCount: 24,
    type: 'Madaniyah',
  ),
  Surah(
    number: 60,
    name: 'Al-Mumtahanah',
    arabicName: 'الممتحنة',
    ayatCount: 13,
    type: 'Madaniyah',
  ),
  Surah(
    number: 61,
    name: 'As-Saff',
    arabicName: 'الصف',
    ayatCount: 14,
    type: 'Madaniyah',
  ),
  Surah(
    number: 62,
    name: 'Al-Jumu\'ah',
    arabicName: 'الجمعة',
    ayatCount: 11,
    type: 'Madaniyah',
  ),
  Surah(
    number: 63,
    name: 'Al-Munafiqun',
    arabicName: 'المنافقون',
    ayatCount: 11,
    type: 'Madaniyah',
  ),
  Surah(
    number: 64,
    name: 'At-Tagabun',
    arabicName: 'التغابن',
    ayatCount: 18,
    type: 'Madaniyah',
  ),
  Surah(
    number: 65,
    name: 'At-Talaq',
    arabicName: 'الطلاق',
    ayatCount: 12,
    type: 'Madaniyah',
  ),
  Surah(
    number: 66,
    name: 'At-Tahrim',
    arabicName: 'التحريم',
    ayatCount: 12,
    type: 'Madaniyah',
  ),
  Surah(
    number: 67,
    name: 'Al-Mulk',
    arabicName: 'الملك',
    ayatCount: 30,
    type: 'Makkiyah',
  ),
  Surah(
    number: 68,
    name: 'Al-Qalam',
    arabicName: 'القلم',
    ayatCount: 52,
    type: 'Makkiyah',
  ),
  Surah(
    number: 69,
    name: 'Al-Haqqah',
    arabicName: 'الحاقة',
    ayatCount: 52,
    type: 'Makkiyah',
  ),
  Surah(
    number: 70,
    name: 'Al-Ma\'arij',
    arabicName: 'المعارج',
    ayatCount: 44,
    type: 'Makkiyah',
  ),
  Surah(
    number: 71,
    name: 'Nuh',
    arabicName: 'نوح',
    ayatCount: 28,
    type: 'Makkiyah',
  ),
  Surah(
    number: 72,
    name: 'Al-Jinn',
    arabicName: 'الجن',
    ayatCount: 28,
    type: 'Makkiyah',
  ),
  Surah(
    number: 73,
    name: 'Al-Muzzammil',
    arabicName: 'المزمل',
    ayatCount: 20,
    type: 'Makkiyah',
  ),
  Surah(
    number: 74,
    name: 'Al-Muddassir',
    arabicName: 'المدثر',
    ayatCount: 56,
    type: 'Makkiyah',
  ),
  Surah(
    number: 75,
    name: 'Al-Qiyamah',
    arabicName: 'القيامة',
    ayatCount: 40,
    type: 'Makkiyah',
  ),
  Surah(
    number: 76,
    name: 'Al-Insan',
    arabicName: 'الإنسان',
    ayatCount: 31,
    type: 'Madaniyah',
  ),
  Surah(
    number: 77,
    name: 'Al-Mursalat',
    arabicName: 'المرسلات',
    ayatCount: 50,
    type: 'Makkiyah',
  ),
  Surah(
    number: 78,
    name: 'An-Naba\'',
    arabicName: 'النبأ',
    ayatCount: 40,
    type: 'Makkiyah',
  ),
  Surah(
    number: 79,
    name: 'An-Nazi\'at',
    arabicName: 'النازعات',
    ayatCount: 46,
    type: 'Makkiyah',
  ),
  Surah(
    number: 80,
    name: '\'Abasa',
    arabicName: 'عبس',
    ayatCount: 42,
    type: 'Makkiyah',
  ),
  Surah(
    number: 81,
    name: 'At-Takwir',
    arabicName: 'التكوير',
    ayatCount: 29,
    type: 'Makkiyah',
  ),
  Surah(
    number: 82,
    name: 'Al-Infitar',
    arabicName: 'الانفطار',
    ayatCount: 19,
    type: 'Makkiyah',
  ),
  Surah(
    number: 83,
    name: 'Al-Mutaffifin',
    arabicName: 'المطففين',
    ayatCount: 36,
    type: 'Makkiyah',
  ),
  Surah(
    number: 84,
    name: 'Al-Insyiqaq',
    arabicName: 'الانشقاق',
    ayatCount: 25,
    type: 'Makkiyah',
  ),
  Surah(
    number: 85,
    name: 'Al-Buruj',
    arabicName: 'البروج',
    ayatCount: 22,
    type: 'Makkiyah',
  ),
  Surah(
    number: 86,
    name: 'At-Tariq',
    arabicName: 'الطارق',
    ayatCount: 17,
    type: 'Makkiyah',
  ),
  Surah(
    number: 87,
    name: 'Al-A\'la',
    arabicName: 'الأعلى',
    ayatCount: 19,
    type: 'Makkiyah',
  ),
  Surah(
    number: 88,
    name: 'Al-Gasiyah',
    arabicName: 'الغاشية',
    ayatCount: 26,
    type: 'Makkiyah',
  ),
  Surah(
    number: 89,
    name: 'Al-Fajr',
    arabicName: 'الفجر',
    ayatCount: 30,
    type: 'Makkiyah',
  ),
  Surah(
    number: 90,
    name: 'Al-Balad',
    arabicName: 'البلد',
    ayatCount: 20,
    type: 'Makkiyah',
  ),
  Surah(
    number: 91,
    name: 'Asy-Syams',
    arabicName: 'الشمس',
    ayatCount: 15,
    type: 'Makkiyah',
  ),
  Surah(
    number: 92,
    name: 'Al-Lail',
    arabicName: 'الليل',
    ayatCount: 21,
    type: 'Makkiyah',
  ),
  Surah(
    number: 93,
    name: 'Ad-Duha',
    arabicName: 'الضحى',
    ayatCount: 11,
    type: 'Makkiyah',
  ),
  Surah(
    number: 94,
    name: 'Asy-Syarh',
    arabicName: 'الشرح',
    ayatCount: 8,
    type: 'Makkiyah',
  ),
  Surah(
    number: 95,
    name: 'At-Tin',
    arabicName: 'التين',
    ayatCount: 8,
    type: 'Makkiyah',
  ),
  Surah(
    number: 96,
    name: 'Al-\'Alaq',
    arabicName: 'العلق',
    ayatCount: 19,
    type: 'Makkiyah',
  ),
  Surah(
    number: 97,
    name: 'Al-Qadr',
    arabicName: 'القدر',
    ayatCount: 5,
    type: 'Makkiyah',
  ),
  Surah(
    number: 98,
    name: 'Al-Bayyinah',
    arabicName: 'البينة',
    ayatCount: 8,
    type: 'Madaniyah',
  ),
  Surah(
    number: 99,
    name: 'Az-Zalzalah',
    arabicName: 'الزلزلة',
    ayatCount: 8,
    type: 'Madaniyah',
  ),
  Surah(
    number: 100,
    name: 'Al-\'Adiyat',
    arabicName: 'العاديات',
    ayatCount: 11,
    type: 'Makkiyah',
  ),
  Surah(
    number: 101,
    name: 'Al-Qari\'ah',
    arabicName: 'القارعة',
    ayatCount: 11,
    type: 'Makkiyah',
  ),
  Surah(
    number: 102,
    name: 'At-Takasur',
    arabicName: 'التكاثر',
    ayatCount: 8,
    type: 'Makkiyah',
  ),
  Surah(
    number: 103,
    name: 'Al-\'Asr',
    arabicName: 'العصر',
    ayatCount: 3,
    type: 'Makkiyah',
  ),
  Surah(
    number: 104,
    name: 'Al-Humazah',
    arabicName: 'الهمزة',
    ayatCount: 9,
    type: 'Makkiyah',
  ),
  Surah(
    number: 105,
    name: 'Al-Fil',
    arabicName: 'الفيل',
    ayatCount: 5,
    type: 'Makkiyah',
  ),
  Surah(
    number: 106,
    name: 'Quraisy',
    arabicName: 'قريش',
    ayatCount: 4,
    type: 'Makkiyah',
  ),
  Surah(
    number: 107,
    name: 'Al-Ma\'un',
    arabicName: 'الماعون',
    ayatCount: 7,
    type: 'Makkiyah',
  ),
  Surah(
    number: 108,
    name: 'Al-Kausar',
    arabicName: 'الكوثر',
    ayatCount: 3,
    type: 'Makkiyah',
  ),
  Surah(
    number: 109,
    name: 'Al-Kafirun',
    arabicName: 'الكافرون',
    ayatCount: 6,
    type: 'Makkiyah',
  ),
  Surah(
    number: 110,
    name: 'An-Nasr',
    arabicName: 'النصر',
    ayatCount: 3,
    type: 'Madaniyah',
  ),
  Surah(
    number: 111,
    name: 'Al-Lahab',
    arabicName: 'المسد',
    ayatCount: 5,
    type: 'Makkiyah',
  ),
  Surah(
    number: 112,
    name: 'Al-Ikhlas',
    arabicName: 'الإخلاص',
    ayatCount: 4,
    type: 'Makkiyah',
  ),
  Surah(
    number: 113,
    name: 'Al-Falaq',
    arabicName: 'الفلق',
    ayatCount: 5,
    type: 'Makkiyah',
  ),
  Surah(
    number: 114,
    name: 'An-Nas',
    arabicName: 'الناس',
    ayatCount: 6,
    type: 'Makkiyah',
  ),
];

// ── Main Page ──
class GuruTahfidzQuran extends StatefulWidget {
  const GuruTahfidzQuran({super.key});

  @override
  State<GuruTahfidzQuran> createState() => _GuruTahfidzQuranState();
}

class _GuruTahfidzQuranState extends State<GuruTahfidzQuran> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  final QuranReadingService _readingService = QuranReadingService();

  // Real reading history from persistent storage
  List<ReadingHistoryEntry> _readingHistory = [];

  // Bookmarks (tandai) from persistent storage
  List<BookmarkEntry> _bookmarks = [];

  @override
  void initState() {
    super.initState();
    _loadReadingHistory();
  }

  void _loadReadingHistory() async {
    final history = await _readingService.getReadingHistory();
    final bookmarks = await _readingService.getBookmarks();
    if (mounted) {
      setState(() {
        _readingHistory = history;
        _bookmarks = bookmarks;
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgColor,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(child: _buildBacaTab()),
          ],
        ),
      ),
    );
  }

  // ── Header ──
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    gradient: AppTheme.mainGradient,
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.arrow_back_rounded,
                      color: AppTheme.primaryGreen,
                      size: 20,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.auto_stories_rounded,
                          size: 14,
                          color: AppTheme.primaryGreen,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Bacaan Harian',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: AppTheme.textSecondary,
                                fontWeight: FontWeight.w500,
                              ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      "Al-Qur'an",
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════
  // ── TAB: BACA ──
  // ══════════════════════════════════════════
  Widget _buildBacaTab() {
    final filteredSurahs = allSurahs.where((s) {
      if (_searchQuery.isEmpty) return true;
      return s.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          s.arabicName.contains(_searchQuery) ||
          s.number.toString() == _searchQuery;
    }).toList();

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        // ── Riwayat Section ──
        SliverToBoxAdapter(child: _buildRiwayatSection()),

        // ── Tandai (Bookmark) Section ──
        SliverToBoxAdapter(child: _buildTandaiSection()),

        // ── Search Bar ──
        SliverToBoxAdapter(child: _buildSearchBar()),

        // ── Section Label ──
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
            child: Row(
              children: [
                Container(
                  width: 3,
                  height: 16,
                  decoration: BoxDecoration(
                    gradient: AppTheme.mainGradient,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Daftar Surat',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                Text(
                  '${filteredSurahs.length} surat',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppTheme.grey400,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),

        // ── Surah List ──
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 100),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) => _buildSurahItem(filteredSurahs[index]),
              childCount: filteredSurahs.length,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRiwayatSection() {
    if (_readingHistory.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 3,
                height: 16,
                decoration: BoxDecoration(
                  gradient: AppTheme.mainGradient,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Riwayat Bacaan',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () {
                  // TODO: show all history
                },
                child: Text(
                  'Lihat Semua',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppTheme.primaryGreen,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 88,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: _readingHistory.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                final history = _readingHistory[index];
                return _buildHistoryCard(history);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryCard(ReadingHistoryEntry history) {
    final timeAgo = _formatTimeAgo(history.readAt);
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => SurahDetailPage(
              surahNumber: history.surahNumber,
              surahName: history.surahName,
              arabicName: history.arabicName,
            ),
          ),
        ).then((_) => _loadReadingHistory());
      },
      child: Container(
        width: 170,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    gradient: AppTheme.mainGradient,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${history.surahNumber}',
                    style: const TextStyle(
                      color: AppTheme.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    history.surahName,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            Row(
              children: [
                Icon(
                  Icons.bookmark_rounded,
                  size: 12,
                  color: AppTheme.primaryGreen,
                ),
                const SizedBox(width: 4),
                Text(
                  'Ayat ${history.lastAyat}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.primaryGreen,
                  ),
                ),
                const Spacer(),
                Text(
                  timeAgo,
                  style: TextStyle(
                    fontSize: 9,
                    color: AppTheme.grey400,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── Tandai (Bookmark) Section ──
  Widget _buildTandaiSection() {
    if (_bookmarks.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 3,
                height: 16,
                decoration: BoxDecoration(
                  gradient: AppTheme.mainGradient,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Tandai',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.primaryGreen.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${_bookmarks.length}',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.primaryGreen,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 88,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: _bookmarks.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                return _buildBookmarkCard(_bookmarks[index]);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBookmarkCard(BookmarkEntry bookmark) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => SurahDetailPage(
              surahNumber: bookmark.surahNumber,
              surahName: bookmark.surahName,
              arabicName: bookmark.arabicName,
              initialAyat: bookmark.ayatNumber,
            ),
          ),
        ).then((_) => _loadReadingHistory());
      },
      onLongPress: () {
        HapticFeedback.mediumImpact();
        _showRemoveBookmarkDialog(bookmark);
      },
      child: Container(
        width: 170,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppTheme.primaryGreen.withOpacity(0.15),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    gradient: AppTheme.mainGradient,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${bookmark.surahNumber}',
                    style: const TextStyle(
                      color: AppTheme.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    bookmark.surahName,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            Row(
              children: [
                Icon(
                  Icons.bookmark_added_rounded,
                  size: 12,
                  color: AppTheme.primaryGreen,
                ),
                const SizedBox(width: 4),
                Text(
                  'Ayat ${bookmark.ayatNumber}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.primaryGreen,
                  ),
                ),
                const Spacer(),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 10,
                  color: AppTheme.grey400,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showRemoveBookmarkDialog(BookmarkEntry bookmark) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Hapus Tandai?',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        content: Text(
          'Hapus tandai ${bookmark.surahName} ayat ${bookmark.ayatNumber}?',
          style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Batal', style: TextStyle(color: AppTheme.grey400)),
          ),
          TextButton(
            onPressed: () async {
              await _readingService.removeBookmark(
                surahNumber: bookmark.surahNumber,
                ayatNumber: bookmark.ayatNumber,
              );
              Navigator.pop(ctx);
              _loadReadingHistory();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Tandai ${bookmark.surahName}: ${bookmark.ayatNumber} dihapus',
                      style: const TextStyle(fontSize: 12),
                    ),
                    backgroundColor: AppTheme.primaryGreen,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    duration: const Duration(seconds: 2),
                  ),
                );
              }
            },
            child: const Text(
              'Hapus',
              style: TextStyle(color: Color(0xFFEF4444)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: AppTheme.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: TextField(
          controller: _searchController,
          onChanged: (value) => setState(() => _searchQuery = value),
          style: const TextStyle(fontSize: 13, color: AppTheme.textPrimary),
          decoration: InputDecoration(
            hintText: 'Cari surat...',
            hintStyle: TextStyle(fontSize: 13, color: AppTheme.grey400),
            icon: Icon(Icons.search_rounded, size: 20, color: AppTheme.grey400),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 14),
            suffixIcon: _searchQuery.isNotEmpty
                ? GestureDetector(
                    onTap: () {
                      _searchController.clear();
                      setState(() => _searchQuery = '');
                    },
                    child: Icon(
                      Icons.close_rounded,
                      size: 18,
                      color: AppTheme.grey400,
                    ),
                  )
                : null,
          ),
        ),
      ),
    );
  }

  Widget _buildSurahItem(Surah surah) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(14),
        elevation: 0,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () {
            HapticFeedback.lightImpact();
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => SurahDetailPage(
                  surahNumber: surah.number,
                  surahName: surah.name,
                  arabicName: surah.arabicName,
                ),
              ),
            ).then((_) => _loadReadingHistory());
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                // Number badge
                Container(
                  width: 36,
                  height: 36,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppTheme.bgColor,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${surah.number}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.primaryGreen,
                    ),
                  ),
                ),
                const SizedBox(width: 14),

                // Surah info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        surah.name,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${surah.type}  •  ${surah.ayatCount} ayat',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppTheme.grey400,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),

                // Arabic name
                Text(
                  surah.arabicName,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.primaryGreen.withOpacity(0.7),
                    fontFamily: 'serif',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Helpers ──
  String _formatTimeAgo(DateTime dateTime) {
    final diff = DateTime.now().difference(dateTime);
    if (diff.inMinutes < 60) return '${diff.inMinutes} mnt lalu';
    if (diff.inHours < 24) return '${diff.inHours} jam lalu';
    if (diff.inDays < 7) return '${diff.inDays} hari lalu';
    return '${(diff.inDays / 7).floor()} minggu lalu';
  }
}
