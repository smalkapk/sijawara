import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import '../theme.dart';
import '../services/quran_reading_service.dart';
import '../widgets/skeleton_loader.dart';

// ── Ayat Model ──
class Ayat {
  final int nomorAyat;
  final String teksArab; // Uthmani script
  final String teksLatin;
  final String teksIndonesia;

  const Ayat({
    required this.nomorAyat,
    required this.teksArab,
    required this.teksLatin,
    required this.teksIndonesia,
  });
}

// ── Surah Detail Model ──
class SurahDetail {
  final int nomor;
  final String namaArab;
  final String namaLatin;
  final int jumlahAyat;
  final String tempatTurun;
  final String arti;
  final List<Ayat> ayat;

  const SurahDetail({
    required this.nomor,
    required this.namaArab,
    required this.namaLatin,
    required this.jumlahAyat,
    required this.tempatTurun,
    required this.arti,
    required this.ayat,
  });
}

// ── Page ──
class SurahDetailPage extends StatefulWidget {
  final int surahNumber;
  final String surahName;
  final String arabicName;
  final int? initialAyat; // for auto-scroll to bookmarked ayat
  final bool disableLongPress; // hide long-press bottom sheet (e.g. tahfidz mode)

  const SurahDetailPage({
    super.key,
    required this.surahNumber,
    required this.surahName,
    required this.arabicName,
    this.initialAyat,
    this.disableLongPress = false,
  });

  @override
  State<SurahDetailPage> createState() => _SurahDetailPageState();
}

class _SurahDetailPageState extends State<SurahDetailPage> {
  late Future<SurahDetail> _surahFuture;
  bool _showLatin = true;
  final ItemScrollController _itemScrollController = ItemScrollController();
  final ItemPositionsListener _itemPositionsListener = ItemPositionsListener.create();
  final Set<int> _readAyats = {}; // track marked-as-read ayats
  final QuranReadingService _readingService = QuranReadingService();
  int _lastVisibleAyat = 1;
  SurahDetail? _loadedSurah;
  bool _hasScrolledToInitial = false;

  @override
  void initState() {
    super.initState();
    _surahFuture = _fetchSurah(widget.surahNumber);
    // Save reading position when user opens a surah
    _saveInitialPosition();
    // Load bookmarked ayats for this surah
    _loadBookmarks();
  }

  /// Load persisted bookmarks for this surah into _readAyats set
  void _loadBookmarks() async {
    final bookmarked =
        await _readingService.getBookmarkedAyats(widget.surahNumber);
    if (mounted && bookmarked.isNotEmpty) {
      setState(() {
        _readAyats.addAll(bookmarked);
      });
    }
  }

  @override
  void dispose() {
    // Save the last visible ayat when leaving
    _saveCurrentPosition();
    super.dispose();
  }

  void _saveInitialPosition() {
    _readingService.saveReadingPosition(
      surahName: widget.surahName,
      surahNumber: widget.surahNumber,
      arabicName: widget.arabicName,
      lastAyat: 1,
    );
  }

  void _saveCurrentPosition() {
    _readingService.saveReadingPosition(
      surahName: widget.surahName,
      surahNumber: widget.surahNumber,
      arabicName: widget.arabicName,
      lastAyat: _lastVisibleAyat,
    );
  }

  // ── Fetch from Al-Quran Cloud API (Uthmani + Indonesian + Transliteration) ──
  Future<SurahDetail> _fetchSurah(int number) async {
    final prefs = await SharedPreferences.getInstance();
    final cacheKey = 'surah_cache_$number';

    // 1. Try to load from cache
    final cachedData = prefs.getString(cacheKey);
    if (cachedData != null) {
      try {
        final body = jsonDecode(cachedData) as Map<String, dynamic>;
        return _parseSurahData(number, body);
      } catch (e) {
        // Obsolete or corrupted cache, fall through to fetch from API
      }
    }

    // 2. If not in cache, fetch from API
    final url = Uri.parse(
      'https://api.alquran.cloud/v1/surah/$number/editions/quran-uthmani,en.transliteration,id.indonesian',
    );
    final response = await http.get(url);

    if (response.statusCode != 200) {
      throw Exception('Gagal memuat surat (${response.statusCode})');
    }

    // 3. Save to cache before parsing
    await prefs.setString(cacheKey, response.body);

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return _parseSurahData(number, body);
  }

  SurahDetail _parseSurahData(int number, Map<String, dynamic> body) {
    if (body['code'] != 200) {
      throw Exception('API error: ${body['status']}');
    }

    final dataList = body['data'] as List;
    // dataList[0] = quran-uthmani, dataList[1] = en.transliteration, dataList[2] = id.indonesian
    final uthmaniData = dataList[0] as Map<String, dynamic>;
    final translitData = dataList[1] as Map<String, dynamic>;
    final indonesianData = dataList[2] as Map<String, dynamic>;

    final uthmaniAyahs = uthmaniData['ayahs'] as List;
    final translitAyahs = translitData['ayahs'] as List;
    final indonesianAyahs = indonesianData['ayahs'] as List;

    // Map revelationType to Indonesian
    final revelationType = uthmaniData['revelationType'] as String;
    final tempatTurun =
        revelationType == 'Meccan' ? 'Makkiyyah' : 'Madaniyyah';

    // Combine all editions into unified Ayat list
    final List<Ayat> ayatList = [];
    for (int i = 0; i < uthmaniAyahs.length; i++) {
      String arabText = uthmaniAyahs[i]['text'] as String;

      // Remove Bismillah from the beginning of the first ayat for all surahs except Al-Fatihah (1) and At-Taubah (9)
      if (number != 1 && number != 9 && i == 0) {
        if (arabText.startsWith('بِسْمِ ٱللَّهِ ٱلرَّحْمَٰنِ ٱلرَّحِيمِ')) {
          arabText = arabText.replaceFirst('بِسْمِ ٱللَّهِ ٱلرَّحْمَٰنِ ٱلرَّحِيمِ', '').trim();
        } else if (arabText.startsWith('بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ')) {
          arabText = arabText.replaceFirst('بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ', '').trim();
        }
      }

      ayatList.add(Ayat(
        nomorAyat: uthmaniAyahs[i]['numberInSurah'] as int,
        teksArab: arabText,
        teksLatin: translitAyahs[i]['text'] as String,
        teksIndonesia: indonesianAyahs[i]['text'] as String,
      ));
    }

    return SurahDetail(
      nomor: uthmaniData['number'] as int,
      namaArab: uthmaniData['name'] as String,
      namaLatin: uthmaniData['englishName'] as String,
      jumlahAyat: uthmaniData['numberOfAyahs'] as int,
      tempatTurun: tempatTurun,
      arti: uthmaniData['englishNameTranslation'] as String,
      ayat: ayatList,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgColor,
      body: SafeArea(
        child: Column(
          children: [
            _buildAppBar(),
            Expanded(
              child: FutureBuilder<SurahDetail>(
                future: _surahFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return _buildLoading();
                  }
                  if (snapshot.hasError) {
                    return _buildError(snapshot.error.toString());
                  }
                  if (!snapshot.hasData) {
                    return _buildError('Data tidak ditemukan');
                  }
                  return _buildContent(snapshot.data!);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── App Bar ──
  Widget _buildAppBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 8),
      decoration: BoxDecoration(
        color: AppTheme.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back_rounded, size: 22),
            color: AppTheme.textPrimary,
            splashRadius: 20,
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.surahName,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
                Text(
                  widget.arabicName,
                  style: GoogleFonts.amiri(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.primaryGreen.withOpacity(0.7),
                  ),
                ),
              ],
            ),
          ),
          // Toggle latin
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              setState(() => _showLatin = !_showLatin);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: _showLatin
                    ? AppTheme.primaryGreen.withOpacity(0.1)
                    : AppTheme.grey100,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.translate_rounded,
                    size: 14,
                    color:
                        _showLatin ? AppTheme.primaryGreen : AppTheme.grey400,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Latin',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: _showLatin
                          ? AppTheme.primaryGreen
                          : AppTheme.grey400,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Loading ──
  Widget _buildLoading() {
    return ListView.builder(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(0, 0, 0, 40),
      itemCount: 6,
      itemBuilder: (context, index) {
        if (index == 0) {
          return _buildHeaderSkeleton();
        }
        return _buildAyatSkeleton();
      },
    );
  }

  Widget _buildHeaderSkeleton() {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.grey100),
      ),
      child: Column(
        children: [
          const SkeletonLoader(height: 40, width: 150),
          const SizedBox(height: 6),
          const SkeletonLoader(height: 20, width: 100),
          const SizedBox(height: 4),
          const SkeletonLoader(height: 16, width: 200),
          const SizedBox(height: 14),
          Container(height: 1, color: AppTheme.grey100),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SkeletonLoader(height: 30, width: 80, borderRadius: BorderRadius.circular(10)),
              const SizedBox(width: 16),
              SkeletonLoader(height: 30, width: 80, borderRadius: BorderRadius.circular(10)),
            ],
          ),
          const SizedBox(height: 20),
          const SkeletonLoader(height: 30, width: 200),
        ],
      ),
    );
  }

  Widget _buildAyatSkeleton() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      decoration: const BoxDecoration(
        color: AppTheme.white,
        border: Border(bottom: BorderSide(color: AppTheme.grey100, width: 1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              SkeletonLoader(height: 32, width: 32, borderRadius: BorderRadius.circular(10)),
              const Spacer(),
              SkeletonLoader(height: 24, width: 24, borderRadius: BorderRadius.circular(12)),
            ],
          ),
          const SizedBox(height: 16),
          const Align(
            alignment: Alignment.centerRight,
            child: SkeletonLoader(height: 32, width: 250),
          ),
          const SizedBox(height: 8),
          const Align(
            alignment: Alignment.centerRight,
            child: SkeletonLoader(height: 32, width: 200),
          ),
          const SizedBox(height: 20),
          const SkeletonLoader(height: 16, width: double.infinity),
          const SizedBox(height: 8),
          const SkeletonLoader(height: 16, width: 200),
          const SizedBox(height: 12),
          const SkeletonLoader(height: 14, width: double.infinity),
          const SizedBox(height: 6),
          const SkeletonLoader(height: 14, width: 250),
        ],
      ),
    );
  }

  // ── Error ──
  Widget _buildError(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.wifi_off_rounded,
                size: 40,
                color: Color(0xFFEF4444),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Gagal Memuat Data',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: AppTheme.grey400,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                setState(() {
                  _surahFuture = _fetchSurah(widget.surahNumber);
                });
              },
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Coba Lagi'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryGreen,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Content ──
  Widget _buildContent(SurahDetail surah) {
    _loadedSurah = surah;

    // Auto-scroll to initialAyat if provided (only once)
    if (!_hasScrolledToInitial &&
        widget.initialAyat != null &&
        widget.initialAyat! > 1) {
      _hasScrolledToInitial = true;
      // index 0 = header, so ayat N is at index N
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_itemScrollController.isAttached) {
          _itemScrollController.scrollTo(
            index: widget.initialAyat!,
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeInOutCubic,
          );
        }
      });
    }

    // Listen for position changes to track last visible ayat
    _itemPositionsListener.itemPositions.addListener(_updateLastVisibleAyat);

    return ScrollablePositionedList.builder(
      itemScrollController: _itemScrollController,
      itemPositionsListener: _itemPositionsListener,
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(0, 0, 0, 40),
      itemCount: surah.ayat.length + 1, // +1 for header
      itemBuilder: (context, index) {
        if (index == 0) {
          return _buildSurahHeader(surah);
        }
        final ayat = surah.ayat[index - 1];
        final isLast = index == surah.ayat.length;
        return _buildAyatItem(ayat, isLast);
      },
    );
  }

  void _updateLastVisibleAyat() {
    if (_loadedSurah == null) return;
    final positions = _itemPositionsListener.itemPositions.value;
    if (positions.isEmpty) return;
    // Find the max visible ayat index (index 0 is header, so ayat = index)
    final maxIndex = positions
        .where((p) => p.index > 0) // skip header
        .fold<int>(0, (prev, p) => p.index > prev ? p.index : prev);
    if (maxIndex > _lastVisibleAyat) {
      _lastVisibleAyat = maxIndex;
    }
  }

  // ── Surah header card ──
  Widget _buildSurahHeader(SurahDetail surah) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppTheme.mainGradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppTheme.greenGlow,
      ),
      child: Column(
        children: [
          Text(
            surah.namaArab,
            style: GoogleFonts.amiri(
              fontSize: 32,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              height: 1.8,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            surah.namaLatin,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.white.withOpacity(0.9),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            surah.arti,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w400,
              color: Colors.white.withOpacity(0.7),
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(height: 14),
          Container(
            height: 1,
            color: Colors.white.withOpacity(0.15),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildHeaderChip(
                Icons.location_on_outlined,
                surah.tempatTurun,
              ),
              const SizedBox(width: 16),
              _buildHeaderChip(
                Icons.format_list_numbered_rounded,
                '${surah.jumlahAyat} Ayat',
              ),
            ],
          ),
          // Bismillah for surahs except At-Taubah (9) and Al-Fatihah (1)
          if (surah.nomor != 1 && surah.nomor != 9) ...[
            const SizedBox(height: 20),
            Text(
              '\u0628\u0650\u0633\u0652\u0645\u0650 \u0627\u0644\u0644\u0651\u064e\u0647\u0650 \u0627\u0644\u0631\u0651\u064e\u062d\u0652\u0645\u064e\u0670\u0646\u0650 \u0627\u0644\u0631\u0651\u064e\u062d\u0650\u064a\u0645\u0650',
              style: GoogleFonts.amiri(
                fontSize: 26,
                fontWeight: FontWeight.w400,
                color: Colors.white,
                height: 2.0,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildHeaderChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white70),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  // ── Long-press bottom sheet ──
  void _showAyatOptions(Ayat ayat) {
    HapticFeedback.mediumImpact();
    final isRead = _readAyats.contains(ayat.nomorAyat);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          decoration: const BoxDecoration(
            color: AppTheme.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
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
                // Title
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          gradient: AppTheme.mainGradient,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${ayat.nomorAyat}',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${widget.surahName} : ${ayat.nomorAyat}',
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                            Text(
                              'Pilih aksi',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppTheme.grey400,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1, color: AppTheme.grey100),

                // ── Tandai dibaca ──
                _buildBottomSheetOption(
                  icon: isRead
                      ? Icons.check_circle_rounded
                      : Icons.check_circle_outline_rounded,
                  iconColor:
                      isRead ? AppTheme.primaryGreen : AppTheme.grey400,
                  label: isRead ? 'Sudah ditandai dibaca' : 'Tandai dibaca',
                  subtitle: isRead
                      ? 'Ketuk untuk membatalkan'
                      : 'Tandai ayat ini sudah dibaca',
                  onTap: () {
                    setState(() {
                      if (isRead) {
                        _readAyats.remove(ayat.nomorAyat);
                        // Remove bookmark from persistent storage
                        _readingService.removeBookmark(
                          surahNumber: widget.surahNumber,
                          ayatNumber: ayat.nomorAyat,
                        );
                      } else {
                        _readAyats.add(ayat.nomorAyat);
                        // Save bookmark to persistent storage
                        _readingService.saveBookmark(
                          surahName: widget.surahName,
                          surahNumber: widget.surahNumber,
                          arabicName: widget.arabicName,
                          ayatNumber: ayat.nomorAyat,
                        );
                        // Update last read position
                        _lastVisibleAyat = ayat.nomorAyat;
                        _saveCurrentPosition();
                      }
                    });
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          isRead
                              ? 'Tanda baca ayat ${ayat.nomorAyat} dihapus'
                              : 'Ayat ${ayat.nomorAyat} ditandai sudah dibaca',
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
                  },
                ),

                // ── Salin ──
                _buildBottomSheetOption(
                  icon: Icons.copy_rounded,
                  iconColor: AppTheme.softBlue,
                  label: 'Salin',
                  subtitle: 'Salin teks Arab, Latin & terjemah',
                  onTap: () {
                    final text =
                        '${ayat.teksArab}\n\n${ayat.teksLatin}\n\n${ayat.teksIndonesia}\n\n(QS. ${widget.surahName}: ${ayat.nomorAyat})';
                    Clipboard.setData(ClipboardData(text: text));
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Ayat ${ayat.nomorAyat} disalin',
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
                  },
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildBottomSheetOption({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 20, color: iconColor),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 11,
                      color: AppTheme.grey400,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, size: 20, color: AppTheme.grey200),
          ],
        ),
      ),
    );
  }

  // ── Ayat Item (simple, separated by divider, with long-press) ──
  Widget _buildAyatItem(Ayat ayat, bool isLast) {
    final isRead = _readAyats.contains(ayat.nomorAyat);

    return GestureDetector(
      onLongPress: widget.disableLongPress ? null : () => _showAyatOptions(ayat),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
        decoration: BoxDecoration(
          color: isRead
              ? AppTheme.primaryGreen.withOpacity(0.04)
              : AppTheme.white,
          border: isLast
              ? null
              : Border(
                  bottom: BorderSide(
                    color: AppTheme.grey100,
                    width: 1,
                  ),
                ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Ayat number badge + read indicator ──
            Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: isRead
                        ? AppTheme.primaryGreen.withOpacity(0.15)
                        : AppTheme.primaryGreen.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${ayat.nomorAyat}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.primaryGreen,
                    ),
                  ),
                ),
                if (isRead) ...[
                  const SizedBox(width: 8),
                  Icon(
                    Icons.check_circle_rounded,
                    size: 16,
                    color: AppTheme.primaryGreen.withOpacity(0.6),
                  ),
                ],
                const Spacer(),
                // Quick copy button
                GestureDetector(
                  onTap: () {
                    final text =
                        '${ayat.teksArab}\n\n${ayat.teksIndonesia}\n\n(QS. ${widget.surahName}: ${ayat.nomorAyat})';
                    Clipboard.setData(ClipboardData(text: text));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Ayat ${ayat.nomorAyat} disalin',
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
                  },
                  child: Icon(
                    Icons.copy_rounded,
                    size: 16,
                    color: AppTheme.grey400,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // ── Arabic text (Uthmani with Amiri font) ──
            Text(
              ayat.teksArab,
              textAlign: TextAlign.right,
              textDirection: TextDirection.rtl,
              style: GoogleFonts.amiri(
                fontSize: 28,
                fontWeight: FontWeight.w400,
                color: AppTheme.textPrimary,
                height: 2.2,
                letterSpacing: 0.5,
              ),
            ),

            const SizedBox(height: 14),

            // ── Latin transliteration ──
            if (_showLatin) ...[
              Text(
                ayat.teksLatin,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                  color: AppTheme.primaryGreen.withOpacity(0.7),
                  fontStyle: FontStyle.italic,
                  height: 1.6,
                ),
              ),
              const SizedBox(height: 8),
            ],

            // ── Indonesian translation ──
            Text(
              ayat.teksIndonesia,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w400,
                color: AppTheme.textSecondary,
                height: 1.6,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
