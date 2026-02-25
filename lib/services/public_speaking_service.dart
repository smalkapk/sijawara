import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'auth_service.dart';

/// Model data catatan Public Speaking
class PublicSpeakingNote {
  final String id;
  final DateTime date;
  final String judul;
  final String materi;
  final String mentor;
  final String note;
  final DateTime createdAt;

  PublicSpeakingNote({
    required this.id,
    required this.date,
    this.judul = '',
    required this.materi,
    this.mentor = '',
    this.note = '',
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'id': id,
        'date': date.toIso8601String().substring(0, 10),
        'judul': judul,
        'materi': materi,
        'mentor': mentor,
        'note': note,
        'created_at': createdAt.toIso8601String(),
      };

  factory PublicSpeakingNote.fromJson(Map<String, dynamic> json) {
    return PublicSpeakingNote(
      id: json['id']?.toString() ?? '',
      date: DateTime.parse(json['date'] as String),
      judul: json['judul'] as String? ?? '',
      materi: json['materi'] as String? ?? '',
      mentor: json['mentor'] as String? ?? '',
      note: json['note'] as String? ?? '',
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }

  PublicSpeakingNote copyWith({
    String? id,
    DateTime? date,
    String? judul,
    String? materi,
    String? mentor,
    String? note,
    DateTime? createdAt,
  }) {
    return PublicSpeakingNote(
      id: id ?? this.id,
      date: date ?? this.date,
      judul: judul ?? this.judul,
      materi: materi ?? this.materi,
      mentor: mentor ?? this.mentor,
      note: note ?? this.note,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

/// Service untuk catatan Public Speaking – sinkron ke server, fallback ke cache lokal.
class PublicSpeakingService {
  static const String _baseUrl = 'https://portal-smalka.com/api';
  static const String _cacheKey = 'public_speaking_notes';

  // ═══════════════════════════════════════
  // GET: Ambil semua catatan
  // ═══════════════════════════════════════
  static Future<List<PublicSpeakingNote>> getNotes() async {
    try {
      final token = await AuthService.getToken();
      final response = await http.get(
        Uri.parse('$_baseUrl/public_speaking.php'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 15));

      final body = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200 && body['success'] == true) {
        final List<dynamic> dataList = body['data'] ?? [];
        final notes =
            dataList.map((e) => PublicSpeakingNote.fromJson(e)).toList();
        notes.sort((a, b) => b.date.compareTo(a.date));

        // Simpan ke cache lokal sebagai backup
        await _saveToCache(notes);
        return notes;
      }
    } on TimeoutException {
      debugPrint('Public Speaking: timeout, pakai cache lokal');
    } catch (e) {
      debugPrint('Public Speaking: gagal fetch dari server ($e), pakai cache lokal');
    }

    // Fallback: baca dari cache lokal
    return _getFromCache();
  }

  // ═══════════════════════════════════════
  // POST: Simpan catatan baru
  // ═══════════════════════════════════════
  static Future<void> addNote(PublicSpeakingNote note) async {
    try {
      final token = await AuthService.getToken();
      final response = await http.post(
        Uri.parse('$_baseUrl/public_speaking.php'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'date': note.date.toIso8601String().substring(0, 10),
          'judul': note.judul,
          'materi': note.materi,
          'mentor': note.mentor,
          'note': note.note,
        }),
      ).timeout(const Duration(seconds: 15));

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode == 200 && body['success'] == true) {
        return; // Berhasil disimpan di server
      }
      throw Exception(body['message'] ?? 'Gagal menyimpan');
    } catch (e) {
      debugPrint('Public Speaking addNote gagal: $e');
      // Fallback: simpan ke cache lokal
      final notes = await _getFromCache();
      notes.insert(0, note);
      await _saveToCache(notes);
      rethrow;
    }
  }

  // ═══════════════════════════════════════
  // POST: Update catatan yang sudah ada
  // ═══════════════════════════════════════
  static Future<void> updateNote(PublicSpeakingNote updated) async {
    try {
      final token = await AuthService.getToken();
      final response = await http.post(
        Uri.parse('$_baseUrl/public_speaking.php'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'id': updated.id,
          'date': updated.date.toIso8601String().substring(0, 10),
          'judul': updated.judul,
          'materi': updated.materi,
          'mentor': updated.mentor,
          'note': updated.note,
        }),
      ).timeout(const Duration(seconds: 15));

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode == 200 && body['success'] == true) {
        return;
      }
      throw Exception(body['message'] ?? 'Gagal memperbarui');
    } catch (e) {
      debugPrint('Public Speaking updateNote gagal: $e');
      // Fallback: update di cache lokal
      final notes = await _getFromCache();
      final index = notes.indexWhere((n) => n.id == updated.id);
      if (index != -1) {
        notes[index] = updated;
        await _saveToCache(notes);
      }
      rethrow;
    }
  }

  // ═══════════════════════════════════════
  // DELETE: Hapus catatan
  // ═══════════════════════════════════════
  static Future<void> deleteNote(String id) async {
    try {
      final token = await AuthService.getToken();
      final response = await http.delete(
        Uri.parse('$_baseUrl/public_speaking.php?id=$id'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 15));

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode == 200 && body['success'] == true) {
        return;
      }
      throw Exception(body['message'] ?? 'Gagal menghapus');
    } catch (e) {
      debugPrint('Public Speaking deleteNote gagal: $e');
      // Fallback: hapus dari cache lokal
      final notes = await _getFromCache();
      notes.removeWhere((n) => n.id == id);
      await _saveToCache(notes);
      rethrow;
    }
  }

  // ═══════════════════════════════════════
  // Cache helpers (SharedPreferences)
  // ═══════════════════════════════════════
  static Future<List<PublicSpeakingNote>> _getFromCache() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_cacheKey);
    if (jsonStr == null || jsonStr.isEmpty) return [];

    final List<dynamic> jsonList = jsonDecode(jsonStr);
    final notes =
        jsonList.map((e) => PublicSpeakingNote.fromJson(e)).toList();
    notes.sort((a, b) => b.date.compareTo(a.date));
    return notes;
  }

  static Future<void> _saveToCache(List<PublicSpeakingNote> notes) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = jsonEncode(notes.map((n) => n.toJson()).toList());
    await prefs.setString(_cacheKey, jsonStr);
  }
}
