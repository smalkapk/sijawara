import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../theme.dart';
import '../widgets/bottom_menu.dart';
import '../services/quran_reading_service.dart';
import '../services/tahfidz_service.dart';
import '../services/page_cache.dart';
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
  Surah(number: 1, name: 'Al-Fatihah', arabicName: 'الفاتحة', ayatCount: 7, type: 'Makkiyah'),
  Surah(number: 2, name: 'Al-Baqarah', arabicName: 'البقرة', ayatCount: 286, type: 'Madaniyah'),
  Surah(number: 3, name: 'Ali \'Imran', arabicName: 'آل عمران', ayatCount: 200, type: 'Madaniyah'),
  Surah(number: 4, name: 'An-Nisa\'', arabicName: 'النساء', ayatCount: 176, type: 'Madaniyah'),
  Surah(number: 5, name: 'Al-Ma\'idah', arabicName: 'المائدة', ayatCount: 120, type: 'Madaniyah'),
  Surah(number: 6, name: 'Al-An\'am', arabicName: 'الأنعام', ayatCount: 165, type: 'Makkiyah'),
  Surah(number: 7, name: 'Al-A\'raf', arabicName: 'الأعراف', ayatCount: 206, type: 'Makkiyah'),
  Surah(number: 8, name: 'Al-Anfal', arabicName: 'الأنفال', ayatCount: 75, type: 'Madaniyah'),
  Surah(number: 9, name: 'At-Taubah', arabicName: 'التوبة', ayatCount: 129, type: 'Madaniyah'),
  Surah(number: 10, name: 'Yunus', arabicName: 'يونس', ayatCount: 109, type: 'Makkiyah'),
  Surah(number: 11, name: 'Hud', arabicName: 'هود', ayatCount: 123, type: 'Makkiyah'),
  Surah(number: 12, name: 'Yusuf', arabicName: 'يوسف', ayatCount: 111, type: 'Makkiyah'),
  Surah(number: 13, name: 'Ar-Ra\'d', arabicName: 'الرعد', ayatCount: 43, type: 'Madaniyah'),
  Surah(number: 14, name: 'Ibrahim', arabicName: 'إبراهيم', ayatCount: 52, type: 'Makkiyah'),
  Surah(number: 15, name: 'Al-Hijr', arabicName: 'الحجر', ayatCount: 99, type: 'Makkiyah'),
  Surah(number: 16, name: 'An-Nahl', arabicName: 'النحل', ayatCount: 128, type: 'Makkiyah'),
  Surah(number: 17, name: 'Al-Isra\'', arabicName: 'الإسراء', ayatCount: 111, type: 'Makkiyah'),
  Surah(number: 18, name: 'Al-Kahf', arabicName: 'الكهف', ayatCount: 110, type: 'Makkiyah'),
  Surah(number: 19, name: 'Maryam', arabicName: 'مريم', ayatCount: 98, type: 'Makkiyah'),
  Surah(number: 20, name: 'Taha', arabicName: 'طه', ayatCount: 135, type: 'Makkiyah'),
  Surah(number: 21, name: 'Al-Anbiya\'', arabicName: 'الأنبياء', ayatCount: 112, type: 'Makkiyah'),
  Surah(number: 22, name: 'Al-Hajj', arabicName: 'الحج', ayatCount: 78, type: 'Madaniyah'),
  Surah(number: 23, name: 'Al-Mu\'minun', arabicName: 'المؤمنون', ayatCount: 118, type: 'Makkiyah'),
  Surah(number: 24, name: 'An-Nur', arabicName: 'النور', ayatCount: 64, type: 'Madaniyah'),
  Surah(number: 25, name: 'Al-Furqan', arabicName: 'الفرقان', ayatCount: 77, type: 'Makkiyah'),
  Surah(number: 26, name: 'Asy-Syu\'ara\'', arabicName: 'الشعراء', ayatCount: 227, type: 'Makkiyah'),
  Surah(number: 27, name: 'An-Naml', arabicName: 'النمل', ayatCount: 93, type: 'Makkiyah'),
  Surah(number: 28, name: 'Al-Qasas', arabicName: 'القصص', ayatCount: 88, type: 'Makkiyah'),
  Surah(number: 29, name: 'Al-\'Ankabut', arabicName: 'العنكبوت', ayatCount: 69, type: 'Makkiyah'),
  Surah(number: 30, name: 'Ar-Rum', arabicName: 'الروم', ayatCount: 60, type: 'Makkiyah'),
  Surah(number: 31, name: 'Luqman', arabicName: 'لقمان', ayatCount: 34, type: 'Makkiyah'),
  Surah(number: 32, name: 'As-Sajdah', arabicName: 'السجدة', ayatCount: 30, type: 'Makkiyah'),
  Surah(number: 33, name: 'Al-Ahzab', arabicName: 'الأحزاب', ayatCount: 73, type: 'Madaniyah'),
  Surah(number: 34, name: 'Saba\'', arabicName: 'سبأ', ayatCount: 54, type: 'Makkiyah'),
  Surah(number: 35, name: 'Fatir', arabicName: 'فاطر', ayatCount: 45, type: 'Makkiyah'),
  Surah(number: 36, name: 'Yasin', arabicName: 'يس', ayatCount: 83, type: 'Makkiyah'),
  Surah(number: 37, name: 'As-Saffat', arabicName: 'الصافات', ayatCount: 182, type: 'Makkiyah'),
  Surah(number: 38, name: 'Sad', arabicName: 'ص', ayatCount: 88, type: 'Makkiyah'),
  Surah(number: 39, name: 'Az-Zumar', arabicName: 'الزمر', ayatCount: 75, type: 'Makkiyah'),
  Surah(number: 40, name: 'Ghafir', arabicName: 'غافر', ayatCount: 85, type: 'Makkiyah'),
  Surah(number: 41, name: 'Fussilat', arabicName: 'فصلت', ayatCount: 54, type: 'Makkiyah'),
  Surah(number: 42, name: 'Asy-Syura', arabicName: 'الشورى', ayatCount: 53, type: 'Makkiyah'),
  Surah(number: 43, name: 'Az-Zukhruf', arabicName: 'الزخرف', ayatCount: 89, type: 'Makkiyah'),
  Surah(number: 44, name: 'Ad-Dukhan', arabicName: 'الدخان', ayatCount: 59, type: 'Makkiyah'),
  Surah(number: 45, name: 'Al-Jasiyah', arabicName: 'الجاثية', ayatCount: 37, type: 'Makkiyah'),
  Surah(number: 46, name: 'Al-Ahqaf', arabicName: 'الأحقاف', ayatCount: 35, type: 'Makkiyah'),
  Surah(number: 47, name: 'Muhammad', arabicName: 'محمد', ayatCount: 38, type: 'Madaniyah'),
  Surah(number: 48, name: 'Al-Fath', arabicName: 'الفتح', ayatCount: 29, type: 'Madaniyah'),
  Surah(number: 49, name: 'Al-Hujurat', arabicName: 'الحجرات', ayatCount: 18, type: 'Madaniyah'),
  Surah(number: 50, name: 'Qaf', arabicName: 'ق', ayatCount: 45, type: 'Makkiyah'),
  Surah(number: 51, name: 'Az-Zariyat', arabicName: 'الذاريات', ayatCount: 60, type: 'Makkiyah'),
  Surah(number: 52, name: 'At-Tur', arabicName: 'الطور', ayatCount: 49, type: 'Makkiyah'),
  Surah(number: 53, name: 'An-Najm', arabicName: 'النجم', ayatCount: 62, type: 'Makkiyah'),
  Surah(number: 54, name: 'Al-Qamar', arabicName: 'القمر', ayatCount: 55, type: 'Makkiyah'),
  Surah(number: 55, name: 'Ar-Rahman', arabicName: 'الرحمن', ayatCount: 78, type: 'Madaniyah'),
  Surah(number: 56, name: 'Al-Waqi\'ah', arabicName: 'الواقعة', ayatCount: 96, type: 'Makkiyah'),
  Surah(number: 57, name: 'Al-Hadid', arabicName: 'الحديد', ayatCount: 29, type: 'Madaniyah'),
  Surah(number: 58, name: 'Al-Mujadalah', arabicName: 'المجادلة', ayatCount: 22, type: 'Madaniyah'),
  Surah(number: 59, name: 'Al-Hasyr', arabicName: 'الحشر', ayatCount: 24, type: 'Madaniyah'),
  Surah(number: 60, name: 'Al-Mumtahanah', arabicName: 'الممتحنة', ayatCount: 13, type: 'Madaniyah'),
  Surah(number: 61, name: 'As-Saff', arabicName: 'الصف', ayatCount: 14, type: 'Madaniyah'),
  Surah(number: 62, name: 'Al-Jumu\'ah', arabicName: 'الجمعة', ayatCount: 11, type: 'Madaniyah'),
  Surah(number: 63, name: 'Al-Munafiqun', arabicName: 'المنافقون', ayatCount: 11, type: 'Madaniyah'),
  Surah(number: 64, name: 'At-Tagabun', arabicName: 'التغابن', ayatCount: 18, type: 'Madaniyah'),
  Surah(number: 65, name: 'At-Talaq', arabicName: 'الطلاق', ayatCount: 12, type: 'Madaniyah'),
  Surah(number: 66, name: 'At-Tahrim', arabicName: 'التحريم', ayatCount: 12, type: 'Madaniyah'),
  Surah(number: 67, name: 'Al-Mulk', arabicName: 'الملك', ayatCount: 30, type: 'Makkiyah'),
  Surah(number: 68, name: 'Al-Qalam', arabicName: 'القلم', ayatCount: 52, type: 'Makkiyah'),
  Surah(number: 69, name: 'Al-Haqqah', arabicName: 'الحاقة', ayatCount: 52, type: 'Makkiyah'),
  Surah(number: 70, name: 'Al-Ma\'arij', arabicName: 'المعارج', ayatCount: 44, type: 'Makkiyah'),
  Surah(number: 71, name: 'Nuh', arabicName: 'نوح', ayatCount: 28, type: 'Makkiyah'),
  Surah(number: 72, name: 'Al-Jinn', arabicName: 'الجن', ayatCount: 28, type: 'Makkiyah'),
  Surah(number: 73, name: 'Al-Muzzammil', arabicName: 'المزمل', ayatCount: 20, type: 'Makkiyah'),
  Surah(number: 74, name: 'Al-Muddassir', arabicName: 'المدثر', ayatCount: 56, type: 'Makkiyah'),
  Surah(number: 75, name: 'Al-Qiyamah', arabicName: 'القيامة', ayatCount: 40, type: 'Makkiyah'),
  Surah(number: 76, name: 'Al-Insan', arabicName: 'الإنسان', ayatCount: 31, type: 'Madaniyah'),
  Surah(number: 77, name: 'Al-Mursalat', arabicName: 'المرسلات', ayatCount: 50, type: 'Makkiyah'),
  Surah(number: 78, name: 'An-Naba\'', arabicName: 'النبأ', ayatCount: 40, type: 'Makkiyah'),
  Surah(number: 79, name: 'An-Nazi\'at', arabicName: 'النازعات', ayatCount: 46, type: 'Makkiyah'),
  Surah(number: 80, name: '\'Abasa', arabicName: 'عبس', ayatCount: 42, type: 'Makkiyah'),
  Surah(number: 81, name: 'At-Takwir', arabicName: 'التكوير', ayatCount: 29, type: 'Makkiyah'),
  Surah(number: 82, name: 'Al-Infitar', arabicName: 'الانفطار', ayatCount: 19, type: 'Makkiyah'),
  Surah(number: 83, name: 'Al-Mutaffifin', arabicName: 'المطففين', ayatCount: 36, type: 'Makkiyah'),
  Surah(number: 84, name: 'Al-Insyiqaq', arabicName: 'الانشقاق', ayatCount: 25, type: 'Makkiyah'),
  Surah(number: 85, name: 'Al-Buruj', arabicName: 'البروج', ayatCount: 22, type: 'Makkiyah'),
  Surah(number: 86, name: 'At-Tariq', arabicName: 'الطارق', ayatCount: 17, type: 'Makkiyah'),
  Surah(number: 87, name: 'Al-A\'la', arabicName: 'الأعلى', ayatCount: 19, type: 'Makkiyah'),
  Surah(number: 88, name: 'Al-Gasiyah', arabicName: 'الغاشية', ayatCount: 26, type: 'Makkiyah'),
  Surah(number: 89, name: 'Al-Fajr', arabicName: 'الفجر', ayatCount: 30, type: 'Makkiyah'),
  Surah(number: 90, name: 'Al-Balad', arabicName: 'البلد', ayatCount: 20, type: 'Makkiyah'),
  Surah(number: 91, name: 'Asy-Syams', arabicName: 'الشمس', ayatCount: 15, type: 'Makkiyah'),
  Surah(number: 92, name: 'Al-Lail', arabicName: 'الليل', ayatCount: 21, type: 'Makkiyah'),
  Surah(number: 93, name: 'Ad-Duha', arabicName: 'الضحى', ayatCount: 11, type: 'Makkiyah'),
  Surah(number: 94, name: 'Asy-Syarh', arabicName: 'الشرح', ayatCount: 8, type: 'Makkiyah'),
  Surah(number: 95, name: 'At-Tin', arabicName: 'التين', ayatCount: 8, type: 'Makkiyah'),
  Surah(number: 96, name: 'Al-\'Alaq', arabicName: 'العلق', ayatCount: 19, type: 'Makkiyah'),
  Surah(number: 97, name: 'Al-Qadr', arabicName: 'القدر', ayatCount: 5, type: 'Makkiyah'),
  Surah(number: 98, name: 'Al-Bayyinah', arabicName: 'البينة', ayatCount: 8, type: 'Madaniyah'),
  Surah(number: 99, name: 'Az-Zalzalah', arabicName: 'الزلزلة', ayatCount: 8, type: 'Madaniyah'),
  Surah(number: 100, name: 'Al-\'Adiyat', arabicName: 'العاديات', ayatCount: 11, type: 'Makkiyah'),
  Surah(number: 101, name: 'Al-Qari\'ah', arabicName: 'القارعة', ayatCount: 11, type: 'Makkiyah'),
  Surah(number: 102, name: 'At-Takasur', arabicName: 'التكاثر', ayatCount: 8, type: 'Makkiyah'),
  Surah(number: 103, name: 'Al-\'Asr', arabicName: 'العصر', ayatCount: 3, type: 'Makkiyah'),
  Surah(number: 104, name: 'Al-Humazah', arabicName: 'الهمزة', ayatCount: 9, type: 'Makkiyah'),
  Surah(number: 105, name: 'Al-Fil', arabicName: 'الفيل', ayatCount: 5, type: 'Makkiyah'),
  Surah(number: 106, name: 'Quraisy', arabicName: 'قريش', ayatCount: 4, type: 'Makkiyah'),
  Surah(number: 107, name: 'Al-Ma\'un', arabicName: 'الماعون', ayatCount: 7, type: 'Makkiyah'),
  Surah(number: 108, name: 'Al-Kausar', arabicName: 'الكوثر', ayatCount: 3, type: 'Makkiyah'),
  Surah(number: 109, name: 'Al-Kafirun', arabicName: 'الكافرون', ayatCount: 6, type: 'Makkiyah'),
  Surah(number: 110, name: 'An-Nasr', arabicName: 'النصر', ayatCount: 3, type: 'Madaniyah'),
  Surah(number: 111, name: 'Al-Lahab', arabicName: 'المسد', ayatCount: 5, type: 'Makkiyah'),
  Surah(number: 112, name: 'Al-Ikhlas', arabicName: 'الإخلاص', ayatCount: 4, type: 'Makkiyah'),
  Surah(number: 113, name: 'Al-Falaq', arabicName: 'الفلق', ayatCount: 5, type: 'Makkiyah'),
  Surah(number: 114, name: 'An-Nas', arabicName: 'الناس', ayatCount: 6, type: 'Makkiyah'),
];

// ── Main Page ──
class QuranPage extends StatefulWidget {
  const QuranPage({super.key});

  @override
  State<QuranPage> createState() => _QuranPageState();
}

class _QuranPageState extends State<QuranPage> with TickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  final QuranReadingService _readingService = QuranReadingService();

  // Real reading history from persistent storage
  List<ReadingHistoryEntry> _readingHistory = [];

  // Bookmarks (tandai) from persistent storage
  List<BookmarkEntry> _bookmarks = [];

  // ── Setoran (loaded from API) ──
  List<TahfidzSetoran> _setoranList = [];
  bool _isLoadingSetoran = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadReadingHistory();
    _loadSetoran();
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

  Future<void> _loadSetoran() async {
    // Gunakan cache jika masih segar (30 menit)
    if (PageCache.setoranList != null &&
        PageCache.isFresh(PageCache.setoranTimestamp)) {
      if (mounted) {
        setState(() {
          _setoranList = PageCache.setoranList!;
          _isLoadingSetoran = false;
        });
      }
      return;
    }

    try {
      final data = await TahfidzService.getMySetoran();
      if (mounted) {
        final list = data.reversed.toList();
        // Simpan ke cache
        PageCache.setoranList = list;
        PageCache.setoranTimestamp = DateTime.now();
        setState(() {
          // API returns DESC, reverse to ASC for display logic
          _setoranList = list;
          _isLoadingSetoran = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingSetoran = false);
      }
    }
  }

  /// Pull-to-refresh: hapus cache dan fetch ulang dari server
  Future<void> _refreshSetoran() async {
    PageCache.clearQuran();
    setState(() => _isLoadingSetoran = true);
    await _loadSetoran();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  // Pertahankan state agar tidak di-dispose saat scroll horizontal PageView
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context); // diperlukan oleh AutomaticKeepAliveClientMixin
    return Scaffold(
      backgroundColor: AppTheme.bgColor,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildTabBar(),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildBacaTab(),
                  _buildProgressTab(),
                ],
              ),
            ),
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
              Icon(Icons.auto_stories_rounded,
                  size: 14, color: AppTheme.primaryGreen),
              const SizedBox(width: 6),
              Text(
                'Bacaan Harian',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
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
    );
  }

  // ── Tab Bar ──
  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
      padding: const EdgeInsets.all(4),
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
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          gradient: AppTheme.mainGradient,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primaryGreen.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerHeight: 0,
        labelColor: AppTheme.white,
        unselectedLabelColor: AppTheme.grey400,
        labelStyle: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
        unselectedLabelStyle: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
        tabs: const [
          Tab(
            height: 40,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.menu_book_rounded, size: 16),
                SizedBox(width: 6),
                Text('Baca'),
              ],
            ),
          ),
          Tab(
            height: 40,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.insights_rounded, size: 16),
                SizedBox(width: 6),
                Text('Progress'),
              ],
            ),
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
        // ── Tandai (Bookmark) Section ──
        SliverToBoxAdapter(
          child: _buildTandaiSection(),
        ),

        // ── Search Bar ──
        SliverToBoxAdapter(
          child: _buildSearchBar(),
        ),

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
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(width: 6),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
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
                Icon(Icons.bookmark_added_rounded,
                    size: 12, color: AppTheme.primaryGreen),
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
                Icon(Icons.arrow_forward_ios_rounded,
                    size: 10, color: AppTheme.grey400),
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
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text(
          'Hapus Tandai?',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Text(
          'Hapus tandai ${bookmark.surahName} ayat ${bookmark.ayatNumber}?',
          style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Batal',
              style: TextStyle(color: AppTheme.grey400),
            ),
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
            hintStyle: TextStyle(
              fontSize: 13,
              color: AppTheme.grey400,
            ),
            icon: Icon(Icons.search_rounded, size: 20, color: AppTheme.grey400),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 14),
            suffixIcon: _searchQuery.isNotEmpty
                ? GestureDetector(
                    onTap: () {
                      _searchController.clear();
                      setState(() => _searchQuery = '');
                    },
                    child: Icon(Icons.close_rounded,
                        size: 18, color: AppTheme.grey400),
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

  // ══════════════════════════════════════════
  // ── TAB: PROGRESS (Setoran Al-Qur'an) ──
  // ══════════════════════════════════════════
  Widget _buildProgressTab() {
    if (_isLoadingSetoran) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.only(top: 80),
          child: CircularProgressIndicator(),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _refreshSetoran,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        slivers: [
        // ── Summary Card ──
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
            child: _buildSetoranSummary(),
          ),
        ),

        // ── Stats mini row ──
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
            child: _buildSetoranStatsRow(),
          ),
        ),

        // ── Section Label ──
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
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
                  'Riwayat Setoran',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const Spacer(),
                Text(
                  '${_setoranList.length} setoran',
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

        // ── Setoran List ──
        _setoranList.isEmpty
            ? SliverToBoxAdapter(child: _buildEmptySetoran())
            : SliverPadding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 100),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final setoran = _setoranList[_setoranList.length - 1 - index];
                      final setoranNo = _setoranList.length - index;
                      return _buildSetoranCard(setoran, index, setoranNo);
                    },
                    childCount: _setoranList.length,
                  ),
                ),
              ),
      ],
      ),
    );
  }

  // ── Setoran Summary Card ──
  Widget _buildSetoranSummary() {
    final totalSetoran = _setoranList.length;
    final sudahParaf = _setoranList.where((s) => s.guruName.isNotEmpty).length;
    final lastSetoran = _setoranList.isNotEmpty ? _setoranList.last : null;

    // Hitung nilai rata-rata
    String rataRata = '-';
    if (_setoranList.isNotEmpty) {
      final nilaiMap = {'A': 4.0, 'B+': 3.5, 'B': 3.0, 'C': 2.0, 'D': 1.0};
      final total = _setoranList.fold<double>(
          0, (sum, s) => sum + (nilaiMap[s.grade] ?? 0));
      final avg = total / _setoranList.length;
      if (avg >= 3.5) {
        rataRata = 'A';
      } else if (avg >= 2.5) {
        rataRata = 'B';
      } else if (avg >= 1.5) {
        rataRata = 'C';
      } else {
        rataRata = 'D';
      }
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppTheme.mainGradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppTheme.greenGlow,
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.menu_book_rounded,
                  color: Colors.white70, size: 18),
              const SizedBox(width: 8),
              Text(
                'Setoran Al-Qur\'an',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withOpacity(0.85),
                ),
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  'Rata-rata: $rataRata',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              // Circular total setoran
              SizedBox(
                width: 80,
                height: 80,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 80,
                      height: 80,
                      child: CircularProgressIndicator(
                        value: totalSetoran > 0
                            ? (sudahParaf / totalSetoran).clamp(0.0, 1.0)
                            : 0,
                        strokeWidth: 6,
                        strokeCap: StrokeCap.round,
                        backgroundColor: Colors.white.withOpacity(0.2),
                        color: Colors.white,
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '$totalSetoran',
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          'setoran',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                            color: Colors.white.withOpacity(0.8),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 24),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      lastSetoran != null
                          ? 'Terakhir: ${lastSetoran.surahName}'
                          : 'Belum ada setoran',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      lastSetoran != null
                          ? 'Ayat ${lastSetoran.ayatFrom} - ${lastSetoran.ayatTo}'
                          : 'Mulai setoran pertamamu',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Colors.white.withOpacity(0.8),
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '$sudahParaf/$totalSetoran sudah diparaf guru',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: Colors.white.withOpacity(0.7),
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

  // ── Stats Row (mini) ──
  Widget _buildSetoranStatsRow() {
    // Collect setoran values per grade (B+ grouped with B)
    final listA = _setoranList.where((s) => s.grade == 'A').toList();
    final listB = _setoranList.where((s) => s.grade == 'B' || s.grade == 'B+').toList();
    final listC = _setoranList.where((s) => s.grade == 'C').toList();
    final listD = _setoranList.where((s) => s.grade == 'D').toList();

    return Row(
      children: [
        Expanded(
          child: _buildMiniStat('A', '${listA.length}', const Color(0xFF059669), () => _showGradeDetails('A', listA, const Color(0xFF059669))),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildMiniStat('B', '${listB.length}', AppTheme.softBlue, () => _showGradeDetails('B', listB, AppTheme.softBlue)),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildMiniStat('C', '${listC.length}', AppTheme.gold, () => _showGradeDetails('C', listC, AppTheme.gold)),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildMiniStat('D', '${listD.length}', const Color(0xFFEF4444), () => _showGradeDetails('D', listD, const Color(0xFFEF4444))),
        ),
      ],
    );
  }

  Widget _buildMiniStat(String label, String value, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        decoration: BoxDecoration(
          color: AppTheme.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              width: 28,
              height: 28,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'Nilai $label',
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w500,
                color: AppTheme.grey400,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showGradeDetails(String grade, List<TahfidzSetoran> list, Color color) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.7,
          decoration: const BoxDecoration(
            color: AppTheme.bgColor,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
          ),
          child: Column(
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.grey200,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              // Title
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        grade,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: color,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Daftar Nilai $grade',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          Text(
                            '${list.length} surat dengan nilai ini',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppTheme.grey400,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(ctx),
                      icon: Icon(Icons.close_rounded, color: AppTheme.grey400, size: 24),
                      style: IconButton.styleFrom(
                        backgroundColor: AppTheme.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Divider(height: 1, color: AppTheme.grey100),
              
              // List
              Expanded(
                child: list.isEmpty
                    ? Center(
                        child: Text(
                          'Belum ada surat dengan nilai $grade',
                          style: TextStyle(
                            color: AppTheme.grey400,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
                        physics: const BouncingScrollPhysics(),
                        itemCount: list.length,
                        itemBuilder: (context, index) {
                          final setoran = list[index];
                          final dateFormat = DateFormat('dd MMM yyyy', 'id_ID');

                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppTheme.white,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: AppTheme.softShadow,
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: color.withOpacity(0.08),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(
                                    Icons.auto_stories_rounded,
                                    size: 20,
                                    color: color,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'QS. ${setoran.surahName}',
                                        style: const TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w700,
                                          color: AppTheme.textPrimary,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Ayat ${setoran.ayatFrom} - ${setoran.ayatTo}  •  ${dateFormat.format(setoran.setoranAt)}',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                          color: AppTheme.grey400,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: color.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    setoran.grade,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w800,
                                      color: color,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ── Empty State ──
  Widget _buildEmptySetoran() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 40, 24, 100),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppTheme.bgColor,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.menu_book_rounded,
              size: 48,
              color: AppTheme.grey400,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Belum Ada Setoran',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppTheme.grey400,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Riwayat setoran akan muncul di sini',
            style: TextStyle(
              fontSize: 12,
              color: AppTheme.grey400,
            ),
          ),
        ],
      ),
    );
  }

  // ── Setoran Card ──
  Widget _buildSetoranCard(TahfidzSetoran setoran, int animIndex, int setoranNo) {
    final dateFormat = DateFormat('EEEE, d MMMM yyyy', 'id_ID');
    final formattedDate = dateFormat.format(setoran.setoranAt);

    // Nilai badge color
    Color nilaiColor;
    switch (setoran.grade) {
      case 'A':
        nilaiColor = const Color(0xFF059669);
        break;
      case 'B+':
      case 'B':
        nilaiColor = AppTheme.softBlue;
        break;
      case 'C':
        nilaiColor = AppTheme.gold;
        break;
      case 'D':
        nilaiColor = const Color(0xFFEF4444);
        break;
      default:
        nilaiColor = AppTheme.grey400;
    }

    // Setoran range text
    final setoranRange =
        'QS. ${setoran.surahName}: ${setoran.ayatFrom} — ${setoran.ayatTo}';

    final sudahParaf = setoran.guruName.isNotEmpty;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 400 + (animIndex * 60)),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 20 * (1 - value)),
            child: child,
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: AppTheme.white,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          boxShadow: AppTheme.softShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Date header strip ──
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                gradient: AppTheme.mainGradient,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  // Nomor urut
                  Container(
                    width: 24,
                    height: 24,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(7),
                    ),
                    child: Text(
                      '$setoranNo',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Icon(
                    Icons.calendar_today_rounded,
                    color: Colors.white70,
                    size: 13,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      formattedDate,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                  // Nilai badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      setoran.grade,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: nilaiColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── Content ──
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Setoran range
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryGreen.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.auto_stories_rounded,
                          size: 16,
                          color: AppTheme.primaryGreen,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Setoran',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.grey400,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              setoranRange,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textPrimary,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),
                  Container(height: 1, color: AppTheme.grey100),
                  const SizedBox(height: 12),

                  // Nilai & Paraf row
                  Row(
                    children: [
                      // Nilai
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: nilaiColor.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.grade_rounded,
                          size: 16,
                          color: nilaiColor,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Nilai',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.grey400,
                              letterSpacing: 0.5,
                            ),
                          ),
                          Text(
                            setoran.grade,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: nilaiColor,
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      // Paraf guru
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: sudahParaf
                              ? AppTheme.primaryGreen.withValues(alpha: 0.08)
                              : AppTheme.gold.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          sudahParaf
                              ? Icons.verified_rounded
                              : Icons.pending_rounded,
                          size: 16,
                          color: sudahParaf
                              ? AppTheme.primaryGreen
                              : AppTheme.gold,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Paraf Guru',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.grey400,
                              letterSpacing: 0.5,
                            ),
                          ),
                          Text(
                            sudahParaf
                                ? (setoran.guruName.isNotEmpty ? setoran.guruName : 'Sudah')
                                : 'Menunggu',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: sudahParaf
                                  ? AppTheme.primaryGreen
                                  : AppTheme.gold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
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
