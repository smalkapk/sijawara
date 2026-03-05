<?php
// /server/api/seed_dummy.php
// Script untuk mengisi akun dummy ke database.
// Jalankan sekali di browser: https://domain-anda.com/api/seed_dummy.php
// HAPUS FILE INI SETELAH SELESAI DIGUNAKAN!

header('Content-Type: application/json; charset=utf-8');

require_once __DIR__ . '/../config/conn.php';

// Password default untuk semua akun dummy
$defaultPassword = password_hash('123456', PASSWORD_DEFAULT);

try {
    $pdo->beginTransaction();

    // ══════════════════════════════════════════════
    // 1. GURU TAHFIDZ
    // ══════════════════════════════════════════════
    $pdo->prepare(
        "INSERT INTO users (name, email, phone, password, role, is_active)
         VALUES (:name, :email, :phone, :password, :role, 1)"
    )->execute([
        'name'     => 'Ustadz Ahmad Fauzi',
        'email'    => 'guru.tahfidz@smalka.com',
        'phone'    => '081234567001',
        'password' => $defaultPassword,
        'role'     => 'guru_tahfidz',
    ]);
    $guruTahfidzId = (int) $pdo->lastInsertId();

    // ══════════════════════════════════════════════
    // 2. GURU KELAS
    // ══════════════════════════════════════════════
    $pdo->prepare(
        "INSERT INTO users (name, email, phone, password, role, is_active)
         VALUES (:name, :email, :phone, :password, :role, 1)"
    )->execute([
        'name'     => 'Ibu Siti Nurhaliza',
        'email'    => 'guru.kelas@smalka.com',
        'phone'    => '081234567002',
        'password' => $defaultPassword,
        'role'     => 'guru_kelas',
    ]);
    $guruKelasId = (int) $pdo->lastInsertId();

    // ══════════════════════════════════════════════
    // 3. KELAS
    // ══════════════════════════════════════════════
    $pdo->prepare(
        "INSERT INTO classes (name, academic_year, guru_kelas_id)
         VALUES (:name, :year, :guru)"
    )->execute([
        'name' => '7A',
        'year' => '2025/2026',
        'guru' => $guruKelasId,
    ]);
    $classId = (int) $pdo->lastInsertId();

    // ══════════════════════════════════════════════
    // 4. SISWA 1
    // ══════════════════════════════════════════════
    $pdo->prepare(
        "INSERT INTO users (name, email, phone, password, role, is_active)
         VALUES (:name, :email, :phone, :password, :role, 1)"
    )->execute([
        'name'     => 'Muhammad Rizky',
        'email'    => 'siswa1@smalka.com',
        'phone'    => '081234567003',
        'password' => $defaultPassword,
        'role'     => 'siswa',
    ]);
    $siswa1UserId = (int) $pdo->lastInsertId();

    $pdo->prepare(
        "INSERT INTO students (user_id, nis, class_id, guru_tahfidz_id, total_points, current_level, streak)
         VALUES (:uid, :nis, :cid, :gid, :pts, :lvl, :str)"
    )->execute([
        'uid' => $siswa1UserId,
        'nis' => '2025001',
        'cid' => $classId,
        'gid' => $guruTahfidzId,
        'pts' => 150,
        'lvl' => 3,
        'str' => 5,
    ]);
    $student1Id = (int) $pdo->lastInsertId();

    // ══════════════════════════════════════════════
    // 5. SISWA 2
    // ══════════════════════════════════════════════
    $pdo->prepare(
        "INSERT INTO users (name, email, phone, password, role, is_active)
         VALUES (:name, :email, :phone, :password, :role, 1)"
    )->execute([
        'name'     => 'Aisyah Putri',
        'email'    => 'siswa2@smalka.com',
        'phone'    => '081234567004',
        'password' => $defaultPassword,
        'role'     => 'siswa',
    ]);
    $siswa2UserId = (int) $pdo->lastInsertId();

    $pdo->prepare(
        "INSERT INTO students (user_id, nis, class_id, guru_tahfidz_id, total_points, current_level, streak)
         VALUES (:uid, :nis, :cid, :gid, :pts, :lvl, :str)"
    )->execute([
        'uid' => $siswa2UserId,
        'nis' => '2025002',
        'cid' => $classId,
        'gid' => $guruTahfidzId,
        'pts' => 200,
        'lvl' => 4,
        'str' => 12,
    ]);
    $student2Id = (int) $pdo->lastInsertId();

    // ══════════════════════════════════════════════
    // 6. ORANG TUA (wali dari siswa 1 dan siswa 2)
    // ══════════════════════════════════════════════
    $pdo->prepare(
        "INSERT INTO users (name, email, phone, password, role, is_active)
         VALUES (:name, :email, :phone, :password, :role, 1)"
    )->execute([
        'name'     => 'Bapak Hasan',
        'email'    => 'ortu@smalka.com',
        'phone'    => '081234567005',
        'password' => $defaultPassword,
        'role'     => 'orang_tua',
    ]);
    $ortuUserId = (int) $pdo->lastInsertId();

    // Relasi orang tua - siswa 1 (ayah)
    $pdo->prepare(
        "INSERT INTO parent_student (parent_id, student_id, relationship)
         VALUES (:pid, :sid, :rel)"
    )->execute([
        'pid' => $ortuUserId,
        'sid' => $student1Id,
        'rel' => 'ayah',
    ]);

    // Relasi orang tua - siswa 2 (ayah)
    $pdo->prepare(
        "INSERT INTO parent_student (parent_id, student_id, relationship)
         VALUES (:pid, :sid, :rel)"
    )->execute([
        'pid' => $ortuUserId,
        'sid' => $student2Id,
        'rel' => 'ayah',
    ]);

    $pdo->commit();

    // ══════════════════════════════════════════════
    // OUTPUT RINGKASAN
    // ══════════════════════════════════════════════
    echo json_encode([
        'success' => true,
        'message' => 'Dummy data berhasil dibuat!',
        'password_semua_akun' => '123456',
        'akun' => [
            [
                'role'  => 'siswa',
                'nama'  => 'Muhammad Rizky',
                'email' => 'siswa1@smalka.com',
                'nis'   => '2025001',
            ],
            [
                'role'  => 'siswa',
                'nama'  => 'Aisyah Putri',
                'email' => 'siswa2@smalka.com',
                'nis'   => '2025002',
            ],
            [
                'role'  => 'orang_tua',
                'nama'  => 'Bapak Hasan',
                'email' => 'ortu@smalka.com',
                'note'  => 'Wali dari Muhammad Rizky & Aisyah Putri',
            ],
            [
                'role'  => 'guru_tahfidz',
                'nama'  => 'Ustadz Ahmad Fauzi',
                'email' => 'guru.tahfidz@smalka.com',
            ],
            [
                'role'  => 'guru_kelas',
                'nama'  => 'Ibu Siti Nurhaliza',
                'email' => 'guru.kelas@smalka.com',
                'note'  => 'Wali kelas 7A',
            ],
        ],
    ], JSON_PRETTY_PRINT);

} catch (PDOException $e) {
    $pdo->rollBack();
    http_response_code(500);
    echo json_encode([
        'success' => false,
        'message' => 'Gagal membuat dummy data: ' . $e->getMessage(),
    ], JSON_PRETTY_PRINT);
}
