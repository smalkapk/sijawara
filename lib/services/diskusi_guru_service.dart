import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class DiskusiGuruNote {
  final String id;
  final DateTime date;
  final String topik;
  final String namaGuru;
  final String pesan;
  final String balasan;
  final DateTime createdAt;

  DiskusiGuruNote({
    required this.id,
    required this.date,
    this.topik = '',
    this.namaGuru = '',
    this.pesan = '',
    this.balasan = '',
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
    'id': id,
    'date': date.toIso8601String().substring(0, 10),
    'topik': topik,
    'namaGuru': namaGuru,
    'pesan': pesan,
    'balasan': balasan,
    'created_at': createdAt.toIso8601String(),
  };

  factory DiskusiGuruNote.fromJson(Map<String, dynamic> json) {
    return DiskusiGuruNote(
      id: json['id']?.toString() ?? '',
      date: DateTime.parse(json['date'] as String),
      topik: json['topik'] as String? ?? '',
      namaGuru: json['namaGuru'] as String? ?? '',
      pesan: json['pesan'] as String? ?? '',
      balasan: json['balasan'] as String? ?? '',
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }

  DiskusiGuruNote copyWith({
    String? id,
    DateTime? date,
    String? topik,
    String? namaGuru,
    String? pesan,
    String? balasan,
    DateTime? createdAt,
  }) {
    return DiskusiGuruNote(
      id: id ?? this.id,
      date: date ?? this.date,
      topik: topik ?? this.topik,
      namaGuru: namaGuru ?? this.namaGuru,
      pesan: pesan ?? this.pesan,
      balasan: balasan ?? this.balasan,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

/// Service dummy lokal menggunakan SharedPreferences
class DiskusiGuruService {
  static const String _cacheKey = 'diskusi_guru_notes';

  static Future<List<DiskusiGuruNote>> getNotes() async {
    // Simulasi delay jaringan
    await Future.delayed(const Duration(milliseconds: 600));
    return _getFromCache();
  }

  static Future<void> addNote(DiskusiGuruNote note) async {
    await Future.delayed(const Duration(milliseconds: 600));
    final notes = await _getFromCache();
    notes.insert(0, note);
    await _saveToCache(notes);
  }

  static Future<void> updateNote(DiskusiGuruNote updated) async {
    await Future.delayed(const Duration(milliseconds: 600));
    final notes = await _getFromCache();
    final index = notes.indexWhere((n) => n.id == updated.id);
    if (index != -1) {
      notes[index] = updated;
      await _saveToCache(notes);
    } else {
      throw Exception('Catatan tidak ditemukan');
    }
  }

  static Future<void> deleteNote(String id) async {
    await Future.delayed(const Duration(milliseconds: 600));
    final notes = await _getFromCache();
    notes.removeWhere((n) => n.id == id);
    await _saveToCache(notes);
  }

  static Future<List<DiskusiGuruNote>> _getFromCache() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_cacheKey);
    if (jsonStr == null || jsonStr.isEmpty) return [];

    final List<dynamic> jsonList = jsonDecode(jsonStr);
    final notes = jsonList.map((e) => DiskusiGuruNote.fromJson(e)).toList();
    notes.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return notes;
  }

  static Future<void> _saveToCache(List<DiskusiGuruNote> notes) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = jsonEncode(notes.map((n) => n.toJson()).toList());
    await prefs.setString(_cacheKey, jsonStr);
  }
}
