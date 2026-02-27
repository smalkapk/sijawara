<?php
// /server/api/maklumat.php
// Endpoint untuk fitur Maklumat (pengumuman guru kelas)
//
// GET    ?action=list                              -> daftar maklumat guru (untuk guru)
// GET    ?action=student_list&student_id=X         -> daftar maklumat untuk siswa/orang_tua
// POST                                             -> buat maklumat baru
// DELETE ?id=X                                     -> hapus maklumat

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

// ── Autentikasi ──
$token = getBearerToken();
if (empty($token)) {
    http_response_code(401);
    echo json_encode(['success' => false, 'message' => 'Token diperlukan']);
    exit;
}

$userId = getUserIdFromToken($token);
if (!$userId) {
    http_response_code(403);
    echo json_encode(['success' => false, 'message' => 'Token tidak valid']);
    exit;
}

// Ambil data user
$stmtUser = $pdo->prepare('SELECT id, name, role FROM users WHERE id = :uid AND is_active = 1 LIMIT 1');
$stmtUser->execute(['uid' => $userId]);
$user = $stmtUser->fetch();

if (!$user) {
    http_response_code(403);
    echo json_encode(['success' => false, 'message' => 'User tidak ditemukan']);
    exit;
}

// ════════════════════════════════════════════════════
// GET: Daftar Maklumat
// ════════════════════════════════════════════════════
if ($_SERVER['REQUEST_METHOD'] === 'GET') {
    $action = $_GET['action'] ?? '';

    // ── GET: Daftar maklumat untuk GURU ──
    if ($action === 'list') {
        if (!in_array($user['role'], ['guru_kelas', 'guru_tahfidz'])) {
            http_response_code(403);
            echo json_encode(['success' => false, 'message' => 'Akses ditolak']);
            exit;
        }

        try {
            $stmt = $pdo->prepare(
                'SELECT m.id, m.judul, m.deskripsi, m.kategori, m.prioritas,
                        m.target_audience, m.icon, m.image_url, m.pdf_url,
                        m.created_at, c.name AS class_name
                 FROM maklumat m
                 JOIN classes c ON m.class_id = c.id
                 WHERE m.guru_id = :guru_id
                 ORDER BY m.created_at DESC'
            );
            $stmt->execute(['guru_id' => $userId]);
            $rows = $stmt->fetchAll();

            echo json_encode([
                'success' => true,
                'data' => $rows,
            ]);
        } catch (PDOException $e) {
            http_response_code(500);
            echo json_encode(['success' => false, 'message' => 'Gagal memuat data', 'debug' => $e->getMessage()]);
        }
        exit;
    }

    // ── GET: Daftar maklumat untuk SISWA / ORANG TUA ──
    if ($action === 'student_list') {
        $role = $user['role'];

        // Tentukan class_id siswa
        $classId = null;

        if ($role === 'siswa') {
            // Ambil class_id dari students
            $stmt = $pdo->prepare('SELECT class_id FROM students WHERE user_id = :uid LIMIT 1');
            $stmt->execute(['uid' => $userId]);
            $student = $stmt->fetch();
            $classId = $student ? (int) $student['class_id'] : null;
        } elseif ($role === 'orang_tua') {
            // Ambil class_id dari student_id yang diberikan
            $requestedStudentId = isset($_GET['student_id']) ? (int) $_GET['student_id'] : null;

            if ($requestedStudentId) {
                // Validasi bahwa student_id milik parent ini
                $stmt = $pdo->prepare(
                    'SELECT s.class_id
                     FROM parent_student ps
                     JOIN students s ON ps.student_id = s.id
                     WHERE ps.parent_id = :uid AND s.id = :sid
                     LIMIT 1'
                );
                $stmt->execute(['uid' => $userId, 'sid' => $requestedStudentId]);
            } else {
                // Ambil anak pertama
                $stmt = $pdo->prepare(
                    'SELECT s.class_id
                     FROM parent_student ps
                     JOIN students s ON ps.student_id = s.id
                     WHERE ps.parent_id = :uid
                     LIMIT 1'
                );
                $stmt->execute(['uid' => $userId]);
            }
            $row = $stmt->fetch();
            $classId = $row ? (int) $row['class_id'] : null;
        } else {
            http_response_code(403);
            echo json_encode(['success' => false, 'message' => 'Akses ditolak']);
            exit;
        }

        if (!$classId) {
            echo json_encode(['success' => true, 'data' => []]);
            exit;
        }

        try {
            // Filter berdasarkan target_audience sesuai role
            $audienceFilter = '';
            if ($role === 'siswa') {
                $audienceFilter = "AND (m.target_audience = 'siswa' OR m.target_audience = 'keduanya')";
            } elseif ($role === 'orang_tua') {
                $audienceFilter = "AND (m.target_audience = 'orang_tua' OR m.target_audience = 'keduanya')";
            }

            $stmt = $pdo->prepare(
                "SELECT m.id, m.judul, m.deskripsi, m.kategori, m.prioritas,
                        m.target_audience, m.icon, m.image_url, m.pdf_url,
                        m.created_at, u.name AS guru_name
                 FROM maklumat m
                 JOIN users u ON m.guru_id = u.id
                 WHERE m.class_id = :class_id
                 {$audienceFilter}
                 ORDER BY
                    CASE m.prioritas
                        WHEN 'Tinggi' THEN 1
                        WHEN 'Sedang' THEN 2
                        WHEN 'Rendah' THEN 3
                    END,
                    m.created_at DESC"
            );
            $stmt->execute(['class_id' => $classId]);
            $rows = $stmt->fetchAll();

            echo json_encode([
                'success' => true,
                'data' => $rows,
            ]);
        } catch (PDOException $e) {
            http_response_code(500);
            echo json_encode(['success' => false, 'message' => 'Gagal memuat data', 'debug' => $e->getMessage()]);
        }
        exit;
    }

    http_response_code(400);
    echo json_encode(['success' => false, 'message' => 'Action tidak dikenal']);
    exit;
}

// ════════════════════════════════════════════════════
// POST: Buat maklumat baru
// ════════════════════════════════════════════════════
if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    if ($user['role'] !== 'guru_kelas') {
        http_response_code(403);
        echo json_encode(['success' => false, 'message' => 'Hanya guru kelas yang dapat membuat maklumat']);
        exit;
    }

    $input = json_decode(file_get_contents('php://input'), true);

    $judul      = trim($input['judul'] ?? '');
    $deskripsi  = trim($input['deskripsi'] ?? '');
    $kategori   = trim($input['kategori'] ?? 'Info');
    $prioritas  = trim($input['prioritas'] ?? 'Sedang');
    $target     = trim($input['target_audience'] ?? 'keduanya');
    $icon       = trim($input['icon'] ?? 'campaign');
    $imageUrl   = isset($input['image_url']) ? trim($input['image_url']) : null;
    $pdfUrl     = isset($input['pdf_url']) ? trim($input['pdf_url']) : null;

    // Validasi
    if (empty($judul) || empty($deskripsi)) {
        http_response_code(400);
        echo json_encode(['success' => false, 'message' => 'Judul dan deskripsi wajib diisi']);
        exit;
    }

    $validPrioritas = ['Tinggi', 'Sedang', 'Rendah'];
    if (!in_array($prioritas, $validPrioritas)) {
        $prioritas = 'Sedang';
    }

    $validTarget = ['siswa', 'orang_tua', 'keduanya'];
    if (!in_array($target, $validTarget)) {
        $target = 'keduanya';
    }

    // Cari class_id dari guru
    $stmtClass = $pdo->prepare('SELECT id FROM classes WHERE guru_kelas_id = :uid LIMIT 1');
    $stmtClass->execute(['uid' => $userId]);
    $classRow = $stmtClass->fetch();

    if (!$classRow) {
        http_response_code(400);
        echo json_encode(['success' => false, 'message' => 'Anda belum memiliki kelas yang ditetapkan']);
        exit;
    }

    $classId = (int) $classRow['id'];

    try {
        $stmt = $pdo->prepare(
            'INSERT INTO maklumat (guru_id, class_id, judul, deskripsi, kategori, prioritas, target_audience, icon, image_url, pdf_url)
             VALUES (:guru_id, :class_id, :judul, :deskripsi, :kategori, :prioritas, :target, :icon, :image_url, :pdf_url)'
        );
        $stmt->execute([
            'guru_id'   => $userId,
            'class_id'  => $classId,
            'judul'     => $judul,
            'deskripsi' => $deskripsi,
            'kategori'  => $kategori,
            'prioritas' => $prioritas,
            'target'    => $target,
            'icon'      => $icon,
            'image_url' => $imageUrl,
            'pdf_url'   => $pdfUrl,
        ]);

        $newId = $pdo->lastInsertId();

        echo json_encode([
            'success' => true,
            'message' => 'Maklumat berhasil dibuat',
            'data'    => ['id' => $newId],
        ]);
    } catch (PDOException $e) {
        http_response_code(500);
        echo json_encode(['success' => false, 'message' => 'Gagal menyimpan maklumat', 'debug' => $e->getMessage()]);
    }
    exit;
}

// ════════════════════════════════════════════════════
// DELETE: Hapus maklumat
// ════════════════════════════════════════════════════
if ($_SERVER['REQUEST_METHOD'] === 'DELETE') {
    if ($user['role'] !== 'guru_kelas') {
        http_response_code(403);
        echo json_encode(['success' => false, 'message' => 'Akses ditolak']);
        exit;
    }

    $id = isset($_GET['id']) ? (int) $_GET['id'] : 0;
    if ($id <= 0) {
        http_response_code(400);
        echo json_encode(['success' => false, 'message' => 'ID maklumat tidak valid']);
        exit;
    }

    try {
        // Pastikan maklumat milik guru ini
        $stmt = $pdo->prepare('DELETE FROM maklumat WHERE id = :id AND guru_id = :guru_id');
        $stmt->execute(['id' => $id, 'guru_id' => $userId]);

        if ($stmt->rowCount() === 0) {
            http_response_code(404);
            echo json_encode(['success' => false, 'message' => 'Maklumat tidak ditemukan']);
            exit;
        }

        echo json_encode(['success' => true, 'message' => 'Maklumat berhasil dihapus']);
    } catch (PDOException $e) {
        http_response_code(500);
        echo json_encode(['success' => false, 'message' => 'Gagal menghapus', 'debug' => $e->getMessage()]);
    }
    exit;
}

http_response_code(405);
echo json_encode(['success' => false, 'message' => 'Method not allowed']);
