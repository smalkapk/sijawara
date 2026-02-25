<?php
// /server/api/login.php
// Endpoint autentikasi login untuk aplikasi Sijawara
// Method: POST
// Body JSON: { "email": "...", "password": "...", "role_tab": "siswa|orang_tua|guru" }

header('Content-Type: application/json; charset=utf-8');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type');

// Handle preflight OPTIONS
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit;
}

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    http_response_code(405);
    echo json_encode(['success' => false, 'message' => 'Method not allowed']);
    exit;
}

require_once __DIR__ . '/../config/conn.php';
require_once __DIR__ . '/../config/auth.php';

// Ambil input JSON
$input = json_decode(file_get_contents('php://input'), true);

if (!$input) {
    http_response_code(400);
    echo json_encode(['success' => false, 'message' => 'Request body tidak valid']);
    exit;
}

$email    = trim($input['email'] ?? '');
$password = $input['password'] ?? '';
$roleTab  = $input['role_tab'] ?? ''; // siswa, orang_tua, guru

// Validasi input
if (empty($email) || empty($password)) {
    http_response_code(400);
    echo json_encode(['success' => false, 'message' => 'Email dan password wajib diisi']);
    exit;
}

$validTabs = ['siswa', 'orang_tua', 'guru'];
if (!in_array($roleTab, $validTabs)) {
    http_response_code(400);
    echo json_encode(['success' => false, 'message' => 'Tab role tidak valid']);
    exit;
}

try {
    // Cari user berdasarkan email/phone
    $stmt = $pdo->prepare(
        'SELECT id, name, email, phone, password, role, avatar_url, is_active
         FROM users
         WHERE (email = :email1 OR phone = :email2)
         LIMIT 1'
    );
    $stmt->execute(['email1' => $email, 'email2' => $email]);
    $user = $stmt->fetch();

    if (!$user) {
        http_response_code(401);
        echo json_encode(['success' => false, 'message' => 'Akun tidak ditemukan']);
        exit;
    }

    // Cek apakah akun aktif
    if (!$user['is_active']) {
        http_response_code(403);
        echo json_encode(['success' => false, 'message' => 'Akun Anda tidak aktif. Hubungi admin.']);
        exit;
    }

    // Verifikasi password
    if (!password_verify($password, $user['password'])) {
        http_response_code(401);
        echo json_encode(['success' => false, 'message' => 'Password salah']);
        exit;
    }

    // Validasi role sesuai tab yang dipilih
    $userRole = $user['role'];
    $roleAllowed = false;

    switch ($roleTab) {
        case 'siswa':
            $roleAllowed = ($userRole === 'siswa');
            break;
        case 'orang_tua':
            $roleAllowed = ($userRole === 'orang_tua');
            break;
        case 'guru':
            $roleAllowed = in_array($userRole, ['guru_tahfidz', 'guru_kelas']);
            break;
    }

    if (!$roleAllowed) {
        $tabLabel = [
            'siswa' => 'Siswa',
            'orang_tua' => 'Orang Tua',
            'guru' => 'Guru',
        ][$roleTab] ?? $roleTab;

        http_response_code(403);
        echo json_encode([
            'success' => false,
            'message' => "Akun Anda bukan akun $tabLabel. Silakan pilih tab yang sesuai.",
        ]);
        exit;
    }

    // Ambil data tambahan sesuai role
    $extra = [];

    if ($userRole === 'siswa') {
        $stmt = $pdo->prepare(
            'SELECT s.id AS student_id, s.nis, s.total_points, s.current_level,
                    s.streak, s.last_active_date, c.name AS class_name
             FROM students s
             LEFT JOIN classes c ON s.class_id = c.id
             WHERE s.user_id = :uid
             LIMIT 1'
        );
        $stmt->execute(['uid' => $user['id']]);
        $student = $stmt->fetch();
        if ($student) {
            $extra['student'] = $student;
        }
    } elseif ($userRole === 'orang_tua') {
        // Ambil daftar anak
        $stmt = $pdo->prepare(
            'SELECT ps.relationship, s.id AS student_id, s.nis,
                    s.total_points, s.current_level, s.streak,
                    u.name AS student_name, u.avatar_url AS student_avatar,
                    c.name AS class_name
             FROM parent_student ps
             JOIN students s ON ps.student_id = s.id
             JOIN users u ON s.user_id = u.id
             LEFT JOIN classes c ON s.class_id = c.id
             WHERE ps.parent_id = :uid'
        );
        $stmt->execute(['uid' => $user['id']]);
        $children = $stmt->fetchAll();
        $extra['children'] = $children;
    } elseif (in_array($userRole, ['guru_tahfidz', 'guru_kelas'])) {
        if ($userRole === 'guru_kelas') {
            // Ambil kelas yang diajar
            $stmt = $pdo->prepare(
                'SELECT id AS class_id, name AS class_name, academic_year
                 FROM classes
                 WHERE guru_kelas_id = :uid'
            );
            $stmt->execute(['uid' => $user['id']]);
            $classes = $stmt->fetchAll();
            $extra['classes'] = $classes;
        } elseif ($userRole === 'guru_tahfidz') {
            // Hitung jumlah siswa tahfidz
            $stmt = $pdo->prepare(
                'SELECT COUNT(*) AS total_students
                 FROM students
                 WHERE guru_tahfidz_id = :uid'
            );
            $stmt->execute(['uid' => $user['id']]);
            $count = $stmt->fetch();
            $extra['total_students'] = (int)($count['total_students'] ?? 0);
        }
    }

    // Generate token menggunakan helper
    $token = generateToken((int) $user['id']);

    // Response sukses
    $data = array_merge([
        'token'      => $token,
        'user_id'    => (int) $user['id'],
        'name'       => $user['name'],
        'email'      => $user['email'],
        'phone'      => $user['phone'],
        'role'       => $user['role'],
        'avatar_url' => $user['avatar_url'],
    ], $extra);

    echo json_encode([
        'success' => true,
        'message' => 'Login berhasil',
        'data'    => $data,
    ]);

} catch (PDOException $e) {
    http_response_code(500);
    echo json_encode([
        'success' => false,
        'message' => 'Terjadi kesalahan server',
        'debug' => $e->getMessage(), // Hapus baris ini di produksi
    ]);
}
