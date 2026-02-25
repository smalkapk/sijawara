# Sijawara

Aplikasi manajemen akademik berbasis Flutter untuk SMA Muhammadiyah Al Kautsar Program Khusus Kartasura. Menghubungkan guru, siswa, dan wali murid dalam satu platform terpadu.

## Fitur Utama

- **Multi-role**: Login sebagai siswa, guru, atau wali murid
- **Dashboard**: Ringkasan akademik dan aktivitas harian per role
- **Ibadah**: Pencatatan dan monitoring shalat harian
- **Tahfidz**: Laporan hafalan Al-Quran oleh guru
- **Diskusi**: Forum komunikasi antara guru dan wali murid
- **Public Speaking**: Pencatatan kegiatan latihan berbicara
- **Leaderboard**: Peringkat siswa berdasarkan poin aktivitas
- **ALKA AI**: Asisten AI untuk ringkasan berita dan tanya jawab
- **Berita dan Maklumat**: Informasi dan pengumuman sekolah
- **Al-Quran**: Baca Al-Quran dalam aplikasi

## Tech Stack

| Layer | Teknologi |
|-------|-----------|
| Mobile | Flutter (Dart) |
| Backend | PHP |
| Database | MySQL |

## Struktur Project

```
sijawara/
├── lib/
│   ├── main.dart
│   ├── theme.dart
│   ├── assets/          # Aset statis (gambar, audio)
│   ├── pages/           # Halaman aplikasi
│   ├── services/        # Service layer (API calls)
│   └── widgets/         # Widget reusable
├── server/
│   ├── api/             # Endpoint API (public_html/api)
│   ├── config/          # Konfigurasi database dan auth
│   └── db/              # File database
└── android/ios/web/     # Platform-specific files
```

## Cara Menjalankan

### Prasyarat

- Flutter SDK 3.10.4 atau lebih baru
- PHP 7.4+ dengan MySQL
- Web server (Apache/Nginx)

### Mobile App

```bash
flutter pub get
flutter run
```

### Backend

1. Salin folder `server/` ke `public_html` di hosting
2. Konfigurasi koneksi database di `server/config/`
3. Impor file SQL dari `server/db/`

## Catatan

- Folder `server/config/` dan `server/db/` tidak di-track oleh Git (berisi kredensial)
- File `server/api/alka_ai.php` juga tidak di-track (berisi API key)
- Lihat `.gitignore` untuk daftar lengkap file yang dikecualikan
