# Setup Firebase Cloud Messaging (FCM) - Sijawara

## Langkah-langkah Setup

### 1. Buat Proyek Firebase

1. Buka [Firebase Console](https://console.firebase.google.com/)
2. Klik **"Create a project"** (atau **"Add project"**)
3. Nama proyek: `Sijawara` (atau nama lain yang diinginkan)
4. Aktifkan/nonaktifkan Google Analytics sesuai kebutuhan
5. Klik **Create project**

### 2. Daftarkan Aplikasi Android

1. Di Firebase Console, klik ikon **Android** untuk tambah app
2. Isi **Android package name**: `com.smalka.sijawara`
3. App nickname: `Sijawara`
4. (Opsional) SHA-1: jalankan di terminal:
   ```bash
   cd android && ./gradlew signingReport
   ```
5. Klik **Register app**

### 3. Download google-services.json

1. Download file `google-services.json` yang disediakan Firebase
2. **Pindahkan file ke**: `android/app/google-services.json`
   ```
   sijawara/
   ├── android/
   │   ├── app/
   │   │   ├── google-services.json  ← TARUH DI SINI
   │   │   ├── build.gradle.kts
   │   │   └── src/
   ```
3. Klik **Next** > **Next** > **Continue to console**

### 4. Setup Server (Firebase Service Account)

1. Di Firebase Console, buka **Project Settings** (ikon gear ⚙️)
2. Pilih tab **Service Accounts**
3. Klik **"Generate new private key"**
4. Download file JSON yang di-generate
5. **Rename** file menjadi `firebase-service-account.json`
6. **Upload** ke server di path: `config/firebase-service-account.json`
   (yaitu di folder yang sama dengan `conn.php` dan `auth.php`)

   > ⚠️ **PENTING**: File ini berisi private key. Jangan commit ke git!
   > Tambahkan ke `.gitignore`: `server/config/firebase-service-account.json`

### 5. Jalankan Migration Database

Jalankan SQL berikut di phpMyAdmin atau MySQL client:

```sql
CREATE TABLE IF NOT EXISTS `fcm_tokens` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `user_id` INT NOT NULL,
    `token` TEXT NOT NULL,
    `created_at` DATETIME DEFAULT CURRENT_TIMESTAMP,
    `updated_at` DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX `idx_fcm_user_id` (`user_id`),
    CONSTRAINT `fk_fcm_user` FOREIGN KEY (`user_id`) REFERENCES `users`(`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
```

File SQL juga tersedia di: `server/db/migration_fcm_tokens.sql`

### 6. Install Dependencies Flutter

```bash
flutter pub get
```

### 7. Build & Test

```bash
flutter run
```

---

## Alur Kerja FCM

```
┌──────────────────────────────────────────────────────────────────┐
│                        ALUR NOTIFIKASI                          │
├──────────────────────────────────────────────────────────────────┤
│                                                                  │
│  1. App Start / Login                                           │
│     └── FCM Token didapat dari Firebase                         │
│     └── Token dikirim ke server (POST /api/fcm_token.php)       │
│     └── Server simpan di tabel `fcm_tokens`                     │
│                                                                  │
│  2. Guru buat Maklumat (POST /api/maklumat.php)                 │
│     └── Maklumat disimpan di database                           │
│     └── Server ambil FCM token siswa/ortu di kelas tersebut     │
│     └── Server kirim push via FCM HTTP v1 API                   │
│     └── Firebase kirim push ke device (even if app killed!)     │
│                                                                  │
│  3. Device menerima push                                        │
│     ├── App killed/background → system tray notification        │
│     └── App foreground → flutter_local_notifications            │
│                                                                  │
│  4. Logout                                                      │
│     └── FCM token dihapus dari server                           │
│                                                                  │
└──────────────────────────────────────────────────────────────────┘
```

## File yang Dibuat/Dimodifikasi

### Flutter (Client)
| File | Perubahan |
|------|-----------|
| `pubspec.yaml` | Tambah `firebase_core`, `firebase_messaging` |
| `lib/main.dart` | Init Firebase, register background handler, init FCM service |
| `lib/services/fcm_service.dart` | **BARU** - FCM token management, foreground/background handler |
| `lib/services/auth_service.dart` | Import FCM, hapus token saat logout |
| `lib/pages/login_page.dart` | Register FCM token setelah login |
| `android/settings.gradle.kts` | Tambah `google-services` plugin |
| `android/app/build.gradle.kts` | Tambah `google-services` plugin |
| `android/app/src/main/AndroidManifest.xml` | Tambah FCM notification channel metadata |

### Server (PHP)
| File | Perubahan |
|------|-----------|
| `server/api/fcm_token.php` | **BARU** - API register/unregister FCM token |
| `server/config/fcm_helper.php` | **BARU** - Helper kirim push FCM (JWT + HTTP v1 API) |
| `server/api/maklumat.php` | Tambah push notification setelah buat maklumat |
| `server/db/migration_fcm_tokens.sql` | **BARU** - Tabel FCM tokens |

### File Manual (Harus Dibuat User)
| File | Keterangan |
|------|------------|
| `android/app/google-services.json` | Download dari Firebase Console |
| `server/config/firebase-service-account.json` | Download dari Firebase Console > Service Accounts |

## Troubleshooting

### Build error: google-services.json not found
- Pastikan file `google-services.json` ada di `android/app/`
- Pastikan package name di Firebase Console sama: `com.smalka.sijawara`

### FCM token not sent to server
- Cek logcat: `adb logcat | grep FCM`
- Pastikan user sudah login (auth_token ada di SharedPreferences)
- Pastikan endpoint `fcm_token.php` bisa diakses

### Push notification not received
- Cek apakah service account JSON sudah di-upload ke server
- Cek error_log di server untuk melihat error FCM
- Pastikan tabel `fcm_tokens` sudah dibuat
- Pastikan PHP extension `openssl` dan `curl` aktif di server
