<?php
// /server/api/wali_account_center.php
// Endpoint untuk pusat akun wali murid (orang tua)
// Kelola relasi parent-student
//
// GET    : Ambil daftar anak yang ditautkan
// POST   : Tambah siswa ke relasi parent
// DELETE : Hapus relasi parent-student
//
// Header: Authorization: Bearer <token>

header('Content-Type: application/json; charset=utf-8');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, POST, DELETE, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit;
}

require_once __DIR__ . '/../config/conn.php';
require_once __DIR__ . '/../config/auth.php';

// Ambil & validasi token
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

// Pastikan user adalah orang_tua
$stmtUser = $pdo->prepare('SELECT id, name, email, phone, role, avatar_url FROM users WHERE id = :uid');
$stmtUser->execute(['uid' => $userId]);
$parentUser = $stmtUser->fetch();

if (!$parentUser || $parentUser['role'] !== 'orang_tua') {
    http_response_code(403);
    echo json_encode(['success' => false, 'message' => 'Akses hanya untuk orang tua']);
    exit;
}

$method = $_SERVER['REQUEST_METHOD'];

try {
    // ═══════════════════════════════════════
    // GET: Daftar anak yang ditautkan
    // ═══════════════════════════════════════
    if ($method === 'GET') {
        $stmtChildren = $pdo->prepare(
            'SELECT ps.id AS relation_id, ps.relationship, ps.student_id,
                    s.nis, s.total_points, s.current_level, s.streak, s.last_active_date,
                    u.name AS student_name, u.avatar_url AS student_avatar,
                    c.name AS class_name, c.academic_year,
                    uk.name AS wali_kelas, ut.name AS guru_tahfidz
             FROM parent_student ps
             JOIN students s ON ps.student_id = s.id
             JOIN users u ON s.user_id = u.id
             LEFT JOIN classes c ON s.class_id = c.id
             LEFT JOIN users uk ON c.guru_kelas_id = uk.id
             LEFT JOIN users ut ON s.guru_tahfidz_id = ut.id
             WHERE ps.parent_id = :uid
             ORDER BY ps.id ASC'
        );
        $stmtChildren->execute(['uid' => $userId]);
        $children = $stmtChildren->fetchAll();

        $result = array_map(function ($c) {
            return [
                'relation_id'      => (int) $c['relation_id'],
                'student_id'       => (int) $c['student_id'],
                'student_name'     => $c['student_name'],
                'student_avatar'   => $c['student_avatar'],
                'nis'              => $c['nis'],
                'class_name'       => $c['class_name'],
                'academic_year'    => $c['academic_year'],
                'relationship'     => $c['relationship'],
                'total_points'     => (int) $c['total_points'],
                'current_level'    => (int) $c['current_level'],
                'streak'           => (int) $c['streak'],
                'last_active_date' => $c['last_active_date'],
                'wali_kelas'       => $c['wali_kelas'],
                'guru_tahfidz'     => $c['guru_tahfidz'],
            ];
        }, $children);

        echo json_encode([
            'success' => true,
            'data' => [
                'parent' => [
                    'name'       => $parentUser['name'],
                    'email'      => $parentUser['email'],
                    'phone'      => $parentUser['phone'],
                    'avatar_url' => $parentUser['avatar_url'],
                ],
                'linked_students' => $result,
                'total_linked'    => count($result),
            ],
        ]);
        exit;
    }

    // ═══════════════════════════════════════
    // POST: Tambah siswa via login akun siswa
    // ═══════════════════════════════════════
    if ($method === 'POST') {
        $input = json_decode(file_get_contents('php://input'), true);

        $email = trim($input['email'] ?? '');
        $password = $input['password'] ?? '';
        $relationship = trim($input['relationship'] ?? 'wali');

        if (empty($email) || empty($password)) {
            http_response_code(400);
            echo json_encode(['success' => false, 'message' => 'Email/No. HP dan password wajib diisi']);
            exit;
        }

        // Validasi relationship
        $validRelations = ['ayah', 'ibu', 'wali'];
        if (!in_array($relationship, $validRelations)) {
            $relationship = 'wali';
        }

        // Cari user siswa berdasarkan email/phone
        $stmtFind = $pdo->prepare(
            'SELECT id, name, email, phone, password AS pwd_hash, role, is_active
             FROM users
             WHERE (email = :email1 OR phone = :email2)
             LIMIT 1'
        );
        $stmtFind->execute(['email1' => $email, 'email2' => $email]);
        $studentUser = $stmtFind->fetch();

        if (!$studentUser) {
            http_response_code(401);
            echo json_encode(['success' => false, 'message' => 'Akun tidak ditemukan']);
            exit;
        }

        // Pastikan akun aktif
        if (!$studentUser['is_active']) {
            http_response_code(403);
            echo json_encode(['success' => false, 'message' => 'Akun siswa tidak aktif']);
            exit;
        }

        // Hanya terima akun siswa
        if ($studentUser['role'] !== 'siswa') {
            http_response_code(403);
            echo json_encode(['success' => false, 'message' => 'Akun tersebut bukan akun siswa. Hanya akun siswa yang dapat ditautkan.']);
            exit;
        }

        // Verifikasi password
        if (!password_verify($password, $studentUser['pwd_hash'])) {
            http_response_code(401);
            echo json_encode(['success' => false, 'message' => 'Password salah']);
            exit;
        }

        // Ambil data student
        $stmtStudent = $pdo->prepare(
            'SELECT s.id AS student_id, s.nis, s.total_points, s.current_level, s.streak, s.last_active_date,
                    u.name AS student_name, u.avatar_url AS student_avatar,
                    c.name AS class_name, c.academic_year,
                    uk.name AS wali_kelas, ut.name AS guru_tahfidz
             FROM students s
             JOIN users u ON s.user_id = u.id
             LEFT JOIN classes c ON s.class_id = c.id
             LEFT JOIN users uk ON c.guru_kelas_id = uk.id
             LEFT JOIN users ut ON s.guru_tahfidz_id = ut.id
             WHERE s.user_id = :uid
             LIMIT 1'
        );
        $stmtStudent->execute(['uid' => $studentUser['id']]);
        $student = $stmtStudent->fetch();

        if (!$student) {
            http_response_code(404);
            echo json_encode(['success' => false, 'message' => 'Data siswa tidak ditemukan']);
            exit;
        }

        // Cek apakah sudah ditautkan
        $stmtCheck = $pdo->prepare(
            'SELECT id FROM parent_student
             WHERE parent_id = :pid AND student_id = :sid
             LIMIT 1'
        );
        $stmtCheck->execute([
            'pid' => $userId,
            'sid' => $student['student_id'],
        ]);

        if ($stmtCheck->fetch()) {
            http_response_code(409);
            echo json_encode(['success' => false, 'message' => 'Siswa sudah ditautkan ke akun Anda']);
            exit;
        }

        // Insert relasi baru
        $stmtInsert = $pdo->prepare(
            'INSERT INTO parent_student (parent_id, student_id, relationship)
             VALUES (:pid, :sid, :rel)'
        );
        $stmtInsert->execute([
            'pid' => $userId,
            'sid' => $student['student_id'],
            'rel' => $relationship,
        ]);

        echo json_encode([
            'success' => true,
            'message' => 'Siswa berhasil ditautkan',
            'data' => [
                'relation_id'      => (int) $pdo->lastInsertId(),
                'student_id'       => (int) $student['student_id'],
                'student_name'     => $student['student_name'],
                'student_avatar'   => $student['student_avatar'],
                'nis'              => $student['nis'],
                'class_name'       => $student['class_name'],
                'academic_year'    => $student['academic_year'],
                'relationship'     => $relationship,
                'total_points'     => (int) $student['total_points'],
                'current_level'    => (int) $student['current_level'],
                'streak'           => (int) $student['streak'],
                'last_active_date' => $student['last_active_date'],
                'wali_kelas'       => $student['wali_kelas'],
                'guru_tahfidz'     => $student['guru_tahfidz'],
            ],
        ]);
        exit;
    }

    // ═══════════════════════════════════════
    // DELETE: Hapus relasi parent-student
    // ═══════════════════════════════════════
    if ($method === 'DELETE') {
        $input = json_decode(file_get_contents('php://input'), true);
        $relationId = (int) ($input['relation_id'] ?? 0);

        if ($relationId <= 0) {
            http_response_code(400);
            echo json_encode(['success' => false, 'message' => 'ID relasi wajib diisi']);
            exit;
        }

        // Pastikan relasi milik parent ini
        $stmtCheck = $pdo->prepare(
            'SELECT id FROM parent_student
             WHERE id = :rid AND parent_id = :pid
             LIMIT 1'
        );
        $stmtCheck->execute([
            'rid' => $relationId,
            'pid' => $userId,
        ]);

        if (!$stmtCheck->fetch()) {
            http_response_code(404);
            echo json_encode(['success' => false, 'message' => 'Relasi tidak ditemukan']);
            exit;
        }

        // Cek jumlah relasi, minimal harus punya 1 anak
        $stmtCount = $pdo->prepare(
            'SELECT COUNT(*) AS total FROM parent_student WHERE parent_id = :pid'
        );
        $stmtCount->execute(['pid' => $userId]);
        $totalRelations = (int) $stmtCount->fetchColumn();

        if ($totalRelations <= 1) {
            http_response_code(400);
            echo json_encode(['success' => false, 'message' => 'Tidak dapat menghapus. Minimal harus memiliki 1 anak yang ditautkan']);
            exit;
        }

        // Hapus relasi
        $stmtDelete = $pdo->prepare(
            'DELETE FROM parent_student WHERE id = :rid AND parent_id = :pid'
        );
        $stmtDelete->execute([
            'rid' => $relationId,
            'pid' => $userId,
        ]);

        echo json_encode([
            'success' => true,
            'message' => 'Relasi berhasil dihapus',
        ]);
        exit;
    }

    // Method tidak didukung
    http_response_code(405);
    echo json_encode(['success' => false, 'message' => 'Method not allowed']);

} catch (PDOException $e) {
    http_response_code(500);
    echo json_encode([
        'success' => false,
        'message' => 'Terjadi kesalahan server',
        'debug'   => $e->getMessage(),
    ]);
}
