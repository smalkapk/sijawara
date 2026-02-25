import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class AduanAplikasiTicket {
  final String id;
  final DateTime date;
  final String judul;
  final String deskripsi;
  final String status; // 'Menunggu', 'Diproses', 'Selesai'
  final String tanggapan;
  final DateTime createdAt;

  AduanAplikasiTicket({
    required this.id,
    required this.date,
    this.judul = '',
    this.deskripsi = '',
    this.status = 'Menunggu',
    this.tanggapan = '',
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
    'id': id,
    'date': date.toIso8601String().substring(0, 10),
    'judul': judul,
    'deskripsi': deskripsi,
    'status': status,
    'tanggapan': tanggapan,
    'created_at': createdAt.toIso8601String(),
  };

  factory AduanAplikasiTicket.fromJson(Map<String, dynamic> json) {
    return AduanAplikasiTicket(
      id: json['id']?.toString() ?? '',
      date: DateTime.parse(json['date'] as String),
      judul: json['judul'] as String? ?? '',
      deskripsi: json['deskripsi'] as String? ?? '',
      status: json['status'] as String? ?? 'Menunggu',
      tanggapan: json['tanggapan'] as String? ?? '',
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }

  AduanAplikasiTicket copyWith({
    String? id,
    DateTime? date,
    String? judul,
    String? deskripsi,
    String? status,
    String? tanggapan,
    DateTime? createdAt,
  }) {
    return AduanAplikasiTicket(
      id: id ?? this.id,
      date: date ?? this.date,
      judul: judul ?? this.judul,
      deskripsi: deskripsi ?? this.deskripsi,
      status: status ?? this.status,
      tanggapan: tanggapan ?? this.tanggapan,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

/// Service dummy lokal menggunakan SharedPreferences
class AduanAplikasiService {
  static const String _cacheKey = 'aduan_aplikasi_tickets';

  static Future<List<AduanAplikasiTicket>> getTickets() async {
    // Simulasi delay jaringan
    await Future.delayed(const Duration(milliseconds: 600));
    return _getFromCache();
  }

  static Future<void> addTicket(AduanAplikasiTicket ticket) async {
    await Future.delayed(const Duration(milliseconds: 600));
    final tickets = await _getFromCache();
    tickets.insert(0, ticket);
    await _saveToCache(tickets);
  }

  static Future<void> updateTicket(AduanAplikasiTicket updated) async {
    await Future.delayed(const Duration(milliseconds: 600));
    final tickets = await _getFromCache();
    final index = tickets.indexWhere((n) => n.id == updated.id);
    if (index != -1) {
      tickets[index] = updated;
      await _saveToCache(tickets);
    } else {
      throw Exception('Tiket tidak ditemukan');
    }
  }

  static Future<void> deleteTicket(String id) async {
    await Future.delayed(const Duration(milliseconds: 600));
    final tickets = await _getFromCache();
    tickets.removeWhere((n) => n.id == id);
    await _saveToCache(tickets);
  }

  static Future<List<AduanAplikasiTicket>> _getFromCache() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_cacheKey);
    if (jsonStr == null || jsonStr.isEmpty) return [];

    final List<dynamic> jsonList = jsonDecode(jsonStr);
    final tickets = jsonList
        .map((e) => AduanAplikasiTicket.fromJson(e))
        .toList();
    tickets.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return tickets;
  }

  static Future<void> _saveToCache(List<AduanAplikasiTicket> tickets) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = jsonEncode(tickets.map((n) => n.toJson()).toList());
    await prefs.setString(_cacheKey, jsonStr);
  }
}
