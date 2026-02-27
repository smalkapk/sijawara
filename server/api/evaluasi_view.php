<?php
// /server/api/evaluasi_view.php
// Endpoint untuk siswa & orang tua melihat hasil evaluasi dari guru.
//
// GET ?action=list               -> daftar evaluasi (siswa: diri sendiri, wali: anak-anak)
// GET ?action=detail&id=X        -> detail 1 laporan evaluasi
//
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

// ── Autentikasi ──
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

// Ambil user
$stmtUser = $pdo->prepare('SELECT id, name, role FROM users WHERE id = :uid AND is_active = 1 LIMIT 1');
$stmtUser->execute(['uid' => $userId]);
$user = $stmtUser->fetch();

if (!$user) {
    http_response_code(403);
    echo json_encode(['success' => false, 'message' => 'User tidak ditemukan']);
    exit;
}

$role = $user['role'];

// Hanya siswa & orang_tua boleh akses
if (!in_array($role, ['siswa', 'orang_tua'])) {
    http_response_code(403);
    echo json_encode(['success' => false, 'message' => 'Akses hanya untuk siswa dan orang tua']);
    exit;
}

$action = $_GET['action'] ?? 'list';

try {
    // ════════════════════════════════════════
    // Tentukan student_id yang boleh diakses
    // ════════════════════════════════════════
    $allowedStudentIds = [];

    if ($role === 'siswa') {
        // Ambil student_id dari tabel students
        $stmtStudent = $pdo->prepare('SELECT id FROM students WHERE user_id = :uid LIMIT 1');
        $stmtStudent->execute(['uid' => $userId]);
        $student = $stmtStudent->fetch();
        if ($student) {
            $allowedStudentIds[] = (int) $student['id'];
        }
    } else {
        // orang_tua: ambil semua anak yang ditautkan
        $stmtChildren = $pdo->prepare(
            'SELECT ps.student_id
             FROM parent_student ps
             WHERE ps.parent_id = :uid'
        );
        $stmtChildren->execute(['uid' => $userId]);
        $children = $stmtChildren->fetchAll();
        foreach ($children as $c) {
            $allowedStudentIds[] = (int) $c['student_id'];
        }
    }

    if (empty($allowedStudentIds)) {
        echo json_encode(['success' => true, 'data' => []]);
        exit;
    }

    // ════════════════════════════════════════
    // ACTION: list
    // ════════════════════════════════════════
    if ($action === 'list') {
        // Opsional: filter student_id tertentu (untuk wali yang punya banyak anak)
        $filterStudentId = isset($_GET['student_id']) ? (int) $_GET['student_id'] : 0;

        // Kalau ada filter, pastikan boleh diakses
        if ($filterStudentId > 0 && !in_array($filterStudentId, $allowedStudentIds)) {
            http_response_code(403);
            echo json_encode(['success' => false, 'message' => 'Akses ditolak']);
            exit;
        }

        $targetIds = ($filterStudentId > 0)
            ? [$filterStudentId]
            : $allowedStudentIds;

        $placeholders = implode(',', array_fill(0, count($targetIds), '?'));

        $sql = "SELECT g.id, g.student_id, g.guru_id, g.evaluasi_number, g.bulan,
                       g.nilai_data, g.keterangan_data, g.catatan,
                       g.evaluasi_date, g.created_at,
                       u_guru.name AS guru_name,
                       u_siswa.name AS student_name,
                       s.nis AS student_nis,
                       c.name AS class_name
                FROM guru_evaluasi_logs g
                JOIN users u_guru ON g.guru_id = u_guru.id
                JOIN students s ON g.student_id = s.id
                JOIN users u_siswa ON s.user_id = u_siswa.id
                LEFT JOIN classes c ON s.class_id = c.id
                WHERE g.student_id IN ($placeholders)
                ORDER BY g.evaluasi_date DESC, g.evaluasi_number DESC";

        $stmt = $pdo->prepare($sql);
        $stmt->execute($targetIds);
        $rows = $stmt->fetchAll();

        $data = [];
        foreach ($rows as $r) {
            $data[] = [
                'id'               => (int) $r['id'],
                'student_id'       => (int) $r['student_id'],
                'student_name'     => $r['student_name'],
                'student_nis'      => $r['student_nis'],
                'class_name'       => $r['class_name'],
                'guru_name'        => $r['guru_name'],
                'evaluasi_number'  => (int) $r['evaluasi_number'],
                'bulan'            => $r['bulan'],
                'nilai_data'       => $r['nilai_data'],
                'keterangan_data'  => $r['keterangan_data'],
                'catatan'          => $r['catatan'] ?? '',
                'evaluasi_date'    => $r['evaluasi_date'],
                'created_at'       => $r['created_at'],
            ];
        }

        echo json_encode(['success' => true, 'data' => $data]);
        exit;
    }

    // ════════════════════════════════════════
    // ACTION: detail
    // ════════════════════════════════════════
    if ($action === 'detail') {
        $evalId = isset($_GET['id']) ? (int) $_GET['id'] : 0;

        if ($evalId <= 0) {
            http_response_code(400);
            echo json_encode(['success' => false, 'message' => 'Parameter id diperlukan']);
            exit;
        }

        $placeholders = implode(',', array_fill(0, count($allowedStudentIds), '?'));

        $sql = "SELECT g.id, g.student_id, g.guru_id, g.evaluasi_number, g.bulan,
                       g.nilai_data, g.keterangan_data, g.catatan,
                       g.evaluasi_date, g.created_at,
                       u_guru.name AS guru_name,
                       u_siswa.name AS student_name,
                       s.nis AS student_nis,
                       c.name AS class_name
                FROM guru_evaluasi_logs g
                JOIN users u_guru ON g.guru_id = u_guru.id
                JOIN students s ON g.student_id = s.id
                JOIN users u_siswa ON s.user_id = u_siswa.id
                LEFT JOIN classes c ON s.class_id = c.id
                WHERE g.id = ? AND g.student_id IN ($placeholders)
                LIMIT 1";

        $params = array_merge([$evalId], $allowedStudentIds);
        $stmt = $pdo->prepare($sql);
        $stmt->execute($params);
        $r = $stmt->fetch();

        if (!$r) {
            http_response_code(404);
            echo json_encode(['success' => false, 'message' => 'Evaluasi tidak ditemukan']);
            exit;
        }

        echo json_encode([
            'success' => true,
            'data'    => [
                'id'               => (int) $r['id'],
                'student_id'       => (int) $r['student_id'],
                'student_name'     => $r['student_name'],
                'student_nis'      => $r['student_nis'],
                'class_name'       => $r['class_name'],
                'guru_name'        => $r['guru_name'],
                'evaluasi_number'  => (int) $r['evaluasi_number'],
                'bulan'            => $r['bulan'],
                'nilai_data'       => $r['nilai_data'],
                'keterangan_data'  => $r['keterangan_data'],
                'catatan'          => $r['catatan'] ?? '',
                'evaluasi_date'    => $r['evaluasi_date'],
                'created_at'       => $r['created_at'],
            ],
        ]);
        exit;
    }

    http_response_code(400);
    echo json_encode(['success' => false, 'message' => 'Action tidak dikenali']);

} catch (PDOException $e) {
    http_response_code(500);
    echo json_encode([
        'success' => false,
        'message' => 'Terjadi kesalahan server',
        'debug'   => $e->getMessage(),
    ]);
}
