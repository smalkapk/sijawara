import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Model untuk riwayat bacaan Al-Qur'an
class ReadingHistoryEntry {
  final String surahName;
  final int surahNumber;
  final String arabicName;
  final int lastAyat;
  final DateTime readAt;

  const ReadingHistoryEntry({
    required this.surahName,
    required this.surahNumber,
    required this.arabicName,
    required this.lastAyat,
    required this.readAt,
  });

  Map<String, dynamic> toJson() => {
        'surahName': surahName,
        'surahNumber': surahNumber,
        'arabicName': arabicName,
        'lastAyat': lastAyat,
        'readAt': readAt.toIso8601String(),
      };

  factory ReadingHistoryEntry.fromJson(Map<String, dynamic> json) {
    return ReadingHistoryEntry(
      surahName: json['surahName'] as String,
      surahNumber: json['surahNumber'] as int,
      arabicName: json['arabicName'] as String,
      lastAyat: json['lastAyat'] as int,
      readAt: DateTime.parse(json['readAt'] as String),
    );
  }
}

/// Model untuk bookmark (tandai) ayat Al-Qur'an
class BookmarkEntry {
  final String surahName;
  final int surahNumber;
  final String arabicName;
  final int ayatNumber;
  final DateTime createdAt;

  const BookmarkEntry({
    required this.surahName,
    required this.surahNumber,
    required this.arabicName,
    required this.ayatNumber,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'surahName': surahName,
        'surahNumber': surahNumber,
        'arabicName': arabicName,
        'ayatNumber': ayatNumber,
        'createdAt': createdAt.toIso8601String(),
      };

  factory BookmarkEntry.fromJson(Map<String, dynamic> json) {
    return BookmarkEntry(
      surahName: json['surahName'] as String,
      surahNumber: json['surahNumber'] as int,
      arabicName: json['arabicName'] as String,
      ayatNumber: json['ayatNumber'] as int,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  /// Unique key for comparing bookmarks (same surah + same ayat)
  String get key => '${surahNumber}_$ayatNumber';
}

/// Service untuk menyimpan & membaca riwayat bacaan Al-Qur'an
/// Menggunakan SharedPreferences (persistent, bukan cache)
class QuranReadingService {
  static const String _historyKey = 'quran_reading_history';
  static const String _lastReadKey = 'quran_last_read';
  static const String _bookmarksKey = 'quran_bookmarks';
  static const int _maxHistoryItems = 10;

  // ── Singleton ──
  static final QuranReadingService _instance = QuranReadingService._();
  factory QuranReadingService() => _instance;
  QuranReadingService._();

  // ── Save reading position (called when user reads a surah) ──
  Future<void> saveReadingPosition({
    required String surahName,
    required int surahNumber,
    required String arabicName,
    required int lastAyat,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    final entry = ReadingHistoryEntry(
      surahName: surahName,
      surahNumber: surahNumber,
      arabicName: arabicName,
      lastAyat: lastAyat,
      readAt: DateTime.now(),
    );

    // Save as last read
    await prefs.setString(_lastReadKey, jsonEncode(entry.toJson()));

    // Add to history
    final history = await getReadingHistory();

    // Remove existing entry for same surah (update it)
    history.removeWhere((h) => h.surahNumber == surahNumber);

    // Insert at the beginning (most recent first)
    history.insert(0, entry);

    // Limit history size
    if (history.length > _maxHistoryItems) {
      history.removeRange(_maxHistoryItems, history.length);
    }

    // Save history
    final jsonList = history.map((h) => jsonEncode(h.toJson())).toList();
    await prefs.setStringList(_historyKey, jsonList);
  }

  // ── Get last read position ──
  Future<ReadingHistoryEntry?> getLastRead() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString(_lastReadKey);
    if (data == null) return null;

    try {
      return ReadingHistoryEntry.fromJson(
        jsonDecode(data) as Map<String, dynamic>,
      );
    } catch (_) {
      return null;
    }
  }

  // ── Get reading history (sorted by most recent) ──
  Future<List<ReadingHistoryEntry>> getReadingHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = prefs.getStringList(_historyKey);
    if (jsonList == null) return [];

    try {
      return jsonList
          .map((s) =>
              ReadingHistoryEntry.fromJson(jsonDecode(s) as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  // ── Clear all history ──
  Future<void> clearHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_historyKey);
    await prefs.remove(_lastReadKey);
  }

  // ══════════════════════════════════════════
  // ── BOOKMARKS (Tandai) ──
  // ══════════════════════════════════════════

  // ── Save a bookmark ──
  Future<void> saveBookmark({
    required String surahName,
    required int surahNumber,
    required String arabicName,
    required int ayatNumber,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final bookmarks = await getBookmarks();

    final entry = BookmarkEntry(
      surahName: surahName,
      surahNumber: surahNumber,
      arabicName: arabicName,
      ayatNumber: ayatNumber,
      createdAt: DateTime.now(),
    );

    // Remove existing bookmark for same surah+ayat (avoid duplicates)
    bookmarks.removeWhere((b) => b.key == entry.key);

    // Insert at the beginning (most recent first)
    bookmarks.insert(0, entry);

    final jsonList = bookmarks.map((b) => jsonEncode(b.toJson())).toList();
    await prefs.setStringList(_bookmarksKey, jsonList);
  }

  // ── Remove a bookmark ──
  Future<void> removeBookmark({
    required int surahNumber,
    required int ayatNumber,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final bookmarks = await getBookmarks();
    final key = '${surahNumber}_$ayatNumber';
    bookmarks.removeWhere((b) => b.key == key);

    final jsonList = bookmarks.map((b) => jsonEncode(b.toJson())).toList();
    await prefs.setStringList(_bookmarksKey, jsonList);
  }

  // ── Check if a specific ayat is bookmarked ──
  Future<bool> isBookmarked({
    required int surahNumber,
    required int ayatNumber,
  }) async {
    final bookmarks = await getBookmarks();
    final key = '${surahNumber}_$ayatNumber';
    return bookmarks.any((b) => b.key == key);
  }

  // ── Get bookmarked ayats for a specific surah ──
  Future<Set<int>> getBookmarkedAyats(int surahNumber) async {
    final bookmarks = await getBookmarks();
    return bookmarks
        .where((b) => b.surahNumber == surahNumber)
        .map((b) => b.ayatNumber)
        .toSet();
  }

  // ── Get all bookmarks ──
  Future<List<BookmarkEntry>> getBookmarks() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = prefs.getStringList(_bookmarksKey);
    if (jsonList == null) return [];

    try {
      return jsonList
          .map((s) =>
              BookmarkEntry.fromJson(jsonDecode(s) as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }
}
