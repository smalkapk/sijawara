<?php
// /server/api/guru_profile.php
// Endpoint untuk halaman Profil Anda (Guru)
// Method: GET
// Header: Authorization: Bearer <token>
//
// Response: profil guru, posisi jabatan, kelas yang diampu

header('Content-Type: application/json; charset=utf-8');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit;
}

if ($_SERVER['REQUEST_METHOD'] !== 'GET') {
    http_response_code(405);
    echo json_encode(['success' => false, 'message' => 'Method not allowed']);
    exit;
}

require_once __DIR__ . '/../config/conn.php';
require_once __DIR__ . '/../config/auth.php';

$token = getBearerToken();

if (empty($token)) {
    http_response_code(401);
    echo json_encode(['success' => false, 'message' => 'Token diperlukan']);
    exit;
}

$userId = getUserIdFromToken($token);
if (!$userId) {
    http_response_code(401);
    echo json_encode(['success' => false, 'message' => 'Token tidak valid']);
    exit;
}

try {
    // ══════════════════════════════════════
    // 1. DATA PROFIL GURU
    // ══════════════════════════════════════
    $stmt = $pdo->prepare(
        'SELECT id, name, email, phone, role, avatar_url, created_at
         FROM users
         WHERE id = :uid
           AND role IN ("guru_tahfidz", "guru_kelas")
         LIMIT 1'
    );
    $stmt->execute(['uid' => $userId]);
    $guru = $stmt->fetch();

    if (!$guru) {
        http_response_code(404);
        echo json_encode(['success' => false, 'message' => 'Data guru tidak ditemukan']);
        exit;
    }

    // Role label
    $roleLabel = 'Guru';
    if ($guru['role'] === 'guru_tahfidz') {
        $roleLabel = 'Guru Tahfidz';
    } elseif ($guru['role'] === 'guru_kelas') {
        $roleLabel = 'Guru Kelas';
    }

    // ══════════════════════════════════════
    // 2. POSISI JABATAN
    // ══════════════════════════════════════
    $positions = [];

    // Posisi utama (role)
    $positions[] = [
        'type'     => 'role',
        'title'    => $roleLabel,
        'subtitle' => 'Tugas Utama',
        'icon'     => 'work',
        'color'    => '#7C3AED',
    ];

    // Cek kelas yang diampu (guru_kelas)
    $stmt = $pdo->prepare(
        'SELECT c.id, c.name, c.academic_year,
                (SELECT COUNT(*) FROM students s WHERE s.class_id = c.id) AS student_count
         FROM classes c
         WHERE c.guru_kelas_id = :uid'
    );
    $stmt->execute(['uid' => $userId]);
    $classes = $stmt->fetchAll();

    foreach ($classes as $class) {
        $studentCount = (int) $class['student_count'];
        $positions[] = [
            'type'     => 'class',
            'title'    => $class['name'],
            'subtitle' => "Kelas yang diampu ($studentCount siswa)",
            'icon'     => 'class',
            'color'    => '#059669',
        ];
    }

    // Cek siswa binaan tahfidz (guru_tahfidz)
    if ($guru['role'] === 'guru_tahfidz') {
        $stmt = $pdo->prepare(
            'SELECT COUNT(*) AS total FROM students WHERE guru_tahfidz_id = :uid'
        );
        $stmt->execute(['uid' => $userId]);
        $tahfidzCount = (int) $stmt->fetchColumn();

        if ($tahfidzCount > 0) {
            $positions[] = [
                'type'     => 'tahfidz',
                'title'    => "$tahfidzCount Siswa Binaan",
                'subtitle' => 'Bimbingan Tahfidz',
                'icon'     => 'menu_book',
                'color'    => '#0891B2',
            ];
        }
    }

    // ══════════════════════════════════════
    // OUTPUT
    // ══════════════════════════════════════
    echo json_encode([
        'success' => true,
        'data' => [
            'profile' => [
                'user_id'    => (int) $guru['id'],
                'name'       => $guru['name'],
                'email'      => $guru['email'],
                'phone'      => $guru['phone'],
                'avatar_url' => $guru['avatar_url'],
                'role'       => $guru['role'],
                'role_label' => $roleLabel,
                'created_at' => $guru['created_at'],
            ],
            'positions' => $positions,
        ],
    ]);

} catch (PDOException $e) {
    http_response_code(500);
    echo json_encode([
        'success' => false,
        'message' => 'Kesalahan server',
        'debug'   => $e->getMessage(),
    ]);
}
