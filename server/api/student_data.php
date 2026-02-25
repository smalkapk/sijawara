<?php
// /server/api/student_data.php
// Endpoint untuk mengambil data student (poin, streak, level, badges)
// Method: GET
// Header: Authorization: Bearer <token>

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

// Ambil token
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
    // Ambil data student
    $stmt = $pdo->prepare(
        'SELECT s.id AS student_id, s.nis, s.total_points, s.current_level,
                s.streak, s.last_active_date,
                u.name, u.email, u.avatar_url, u.role,
                c.name AS class_name
         FROM students s
         JOIN users u ON s.user_id = u.id
         LEFT JOIN classes c ON s.class_id = c.id
         WHERE s.user_id = :uid
         LIMIT 1'
    );
    $stmt->execute(['uid' => $userId]);
    $student = $stmt->fetch();

    if (!$student) {
        http_response_code(404);
        echo json_encode(['success' => false, 'message' => 'Data siswa tidak ditemukan']);
        exit;
    }

    // Ambil badges yang dimiliki
    $stmt = $pdo->prepare(
        'SELECT b.name, b.description, b.icon, b.gradient_colors, sb.achieved_at
         FROM student_badges sb
         JOIN badges b ON sb.badge_id = b.id
         WHERE sb.student_id = :sid
         ORDER BY sb.achieved_at DESC'
    );
    $stmt->execute(['sid' => $student['student_id']]);
    $badges = $stmt->fetchAll();

    // Hitung shalat hari ini
    $today = date('Y-m-d');
    $stmt = $pdo->prepare(
        "SELECT COUNT(*) AS done_today
         FROM prayer_logs
         WHERE student_id = :sid
           AND prayer_date = :d
           AND status IN ('done','done_jamaah')"
    );
    $stmt->execute(['sid' => $student['student_id'], 'd' => $today]);
    $doneToday = (int) $stmt->fetchColumn();

    echo json_encode([
        'success' => true,
        'data'    => [
            'student_id'       => (int) $student['student_id'],
            'name'             => $student['name'],
            'email'            => $student['email'],
            'avatar_url'       => $student['avatar_url'],
            'class_name'       => $student['class_name'],
            'total_points'     => (int) $student['total_points'],
            'current_level'    => (int) $student['current_level'],
            'streak'           => (int) $student['streak'],
            'last_active_date' => $student['last_active_date'],
            'done_today'       => $doneToday,
            'badges'           => $badges,
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
