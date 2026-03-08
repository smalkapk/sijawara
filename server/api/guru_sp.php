<?php
// /server/api/guru_sp.php
// Endpoint untuk fitur Guru SP (Surat Peringatan) siswa
//
// GET    ?action=students                          -> daftar siswa yang diajar guru
// GET    ?action=reports&student_id=X              -> daftar laporan SP per siswa
// POST                                             -> simpan / update laporan SP
// DELETE ?id=X                                     -> hapus laporan SP

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

// Pastikan user adalah guru
$stmtUser = $pdo->prepare('SELECT id, name, role FROM users WHERE id = :uid AND is_active = 1 LIMIT 1');
$stmtUser->execute(['uid' => $userId]);
$guru = $stmtUser->fetch();

if (!$guru || !in_array($guru['role'], ['guru_kelas', 'guru_tahfidz'])) {
    http_response_code(403);
    echo json_encode(['success' => false, 'message' => 'Akses ditolak. Hanya guru yang dapat mengakses.']);
    exit;
}

// ════════════════════════════════════════════════════
// GET
// ════════════════════════════════════════════════════
if ($_SERVER['REQUEST_METHOD'] === 'GET') {
    $action = $_GET['action'] ?? '';

    // ── Students: Daftar siswa yang diajar guru ──
    if ($action === 'students') {
        try {
            // Guru kelas: ambil siswa berdasarkan class yang diajar
            // Guru tahfidz: ambil siswa berdasarkan guru_tahfidz_id
            if ($guru['role'] === 'guru_kelas') {
                $stmt = $pdo->prepare(
                    "SELECT s.id AS student_id, s.nis, u.name, c.name AS class_name
                     FROM students s
                     JOIN users u ON s.user_id = u.id
                     LEFT JOIN classes c ON s.class_id = c.id
                     WHERE s.class_id IN (SELECT id FROM classes WHERE guru_kelas_id = :gid)
                     ORDER BY u.name ASC"
                );
            } else {
                $stmt = $pdo->prepare(
                    "SELECT s.id AS student_id, s.nis, u.name, c.name AS class_name
                     FROM students s
                     JOIN users u ON s.user_id = u.id
                     LEFT JOIN classes c ON s.class_id = c.id
                     WHERE s.guru_tahfidz_id = :gid
                     ORDER BY u.name ASC"
                );
            }
            $stmt->execute(['gid' => $userId]);
            $rows = $stmt->fetchAll();

            $students = [];
            foreach ($rows as $row) {
                $students[] = [
                    'student_id'  => (int) $row['student_id'],
                    'nis'         => $row['nis'] ?? '',
                    'name'        => $row['name'],
                    'class_name'  => $row['class_name'] ?? '',
                ];
            }

            echo json_encode(['success' => true, 'data' => $students]);
        } catch (Exception $e) {
            http_response_code(500);
            echo json_encode(['success' => false, 'message' => 'Gagal mengambil daftar siswa']);
        }
        exit;
    }

    // ── Reports: Daftar laporan SP per siswa ──
    if ($action === 'reports') {
        $studentId = $_GET['student_id'] ?? null;

        if (!$studentId) {
            http_response_code(400);
            echo json_encode(['success' => false, 'message' => 'Parameter student_id diperlukan']);
            exit;
        }

        try {
            $stmt = $pdo->prepare(
                "SELECT r.id, r.sp_date, r.jenis_sp, r.alasan, r.tindakan, r.note, r.created_at,
                        u.name AS guru_name
                 FROM guru_sp_reports r
                 JOIN users u ON r.guru_id = u.id
                 WHERE r.student_id = :sid
                 ORDER BY r.sp_date DESC, r.created_at DESC"
            );
            $stmt->execute(['sid' => $studentId]);
            $rows = $stmt->fetchAll();

            $reports = [];
            foreach ($rows as $row) {
                $reports[] = [
                    'id'         => (string) $row['id'],
                    'date'       => date('d-m-Y', strtotime($row['sp_date'])),
                    'jenis_sp'   => $row['jenis_sp'],
                    'alasan'     => $row['alasan'] ?? '',
                    'tindakan'   => $row['tindakan'] ?? '',
                    'note'       => $row['note'] ?? '',
                    'guru_name'  => $row['guru_name'] ?? '',
                    'created_at' => $row['created_at'],
                ];
            }

            echo json_encode(['success' => true, 'data' => $reports]);
        } catch (Exception $e) {
            http_response_code(500);
            echo json_encode(['success' => false, 'message' => 'Gagal mengambil laporan SP']);
        }
        exit;
    }

    // action tidak dikenali
    http_response_code(400);
    echo json_encode(['success' => false, 'message' => 'Action tidak valid']);
    exit;
}

// ════════════════════════════════════════════════════
// POST: Simpan / Update Laporan SP
// Body JSON: { id?, student_id, sp_date, jenis_sp, alasan, tindakan?, note? }
// ════════════════════════════════════════════════════
if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $input = json_decode(file_get_contents('php://input'), true);
    if (!$input) {
        http_response_code(400);
        echo json_encode(['success' => false, 'message' => 'Body JSON tidak valid']);
        exit;
    }

    $noteId    = $input['id'] ?? null;
    $studentId = $input['student_id'] ?? null;
    $spDate    = $input['sp_date'] ?? date('Y-m-d');
    $jenisSp   = trim($input['jenis_sp'] ?? '');
    $alasan    = trim($input['alasan'] ?? '');
    $tindakan  = trim($input['tindakan'] ?? '');
    $note      = trim($input['note'] ?? '');

    // Validasi
    if (!$studentId) {
        http_response_code(400);
        echo json_encode(['success' => false, 'message' => 'student_id wajib diisi']);
        exit;
    }
    if (empty($jenisSp)) {
        http_response_code(400);
        echo json_encode(['success' => false, 'message' => 'Jenis SP wajib diisi']);
        exit;
    }
    if (empty($alasan)) {
        http_response_code(400);
        echo json_encode(['success' => false, 'message' => 'Alasan/Pelanggaran wajib diisi']);
        exit;
    }

    try {
        $pdo->beginTransaction();

        if ($noteId) {
            // ── Update ──
            $check = $pdo->prepare("SELECT id FROM guru_sp_reports WHERE id = :id AND student_id = :sid");
            $check->execute(['id' => $noteId, 'sid' => $studentId]);
            if (!$check->fetch()) {
                $pdo->rollBack();
                http_response_code(404);
                echo json_encode(['success' => false, 'message' => 'Laporan SP tidak ditemukan']);
                exit;
            }

            $stmt = $pdo->prepare(
                "UPDATE guru_sp_reports
                 SET sp_date = :sp_date, jenis_sp = :jenis_sp, alasan = :alasan,
                     tindakan = :tindakan, note = :note
                 WHERE id = :id AND student_id = :sid"
            );
            $stmt->execute([
                'sp_date'  => $spDate,
                'jenis_sp' => $jenisSp,
                'alasan'   => $alasan,
                'tindakan' => $tindakan,
                'note'     => $note,
                'id'       => $noteId,
                'sid'      => $studentId,
            ]);

            $resultId = $noteId;
        } else {
            // ── Insert baru ──
            $stmt = $pdo->prepare(
                "INSERT INTO guru_sp_reports (student_id, guru_id, sp_date, jenis_sp, alasan, tindakan, note)
                 VALUES (:sid, :gid, :sp_date, :jenis_sp, :alasan, :tindakan, :note)"
            );
            $stmt->execute([
                'sid'      => $studentId,
                'gid'      => $userId,
                'sp_date'  => $spDate,
                'jenis_sp' => $jenisSp,
                'alasan'   => $alasan,
                'tindakan' => $tindakan,
                'note'     => $note,
            ]);
            $resultId = $pdo->lastInsertId();
        }

        $pdo->commit();

        echo json_encode([
            'success' => true,
            'message' => $noteId ? 'Laporan SP diperbarui' : 'Laporan SP disimpan',
            'data'    => ['id' => (string) $resultId],
        ]);
    } catch (Exception $e) {
        $pdo->rollBack();
        http_response_code(500);
        echo json_encode(['success' => false, 'message' => 'Gagal menyimpan laporan SP']);
    }
    exit;
}

// ════════════════════════════════════════════════════
// DELETE: Hapus laporan SP
// Query param: id=<report_id>
// ════════════════════════════════════════════════════
if ($_SERVER['REQUEST_METHOD'] === 'DELETE') {
    $noteId = $_GET['id'] ?? null;

    if (!$noteId) {
        http_response_code(400);
        echo json_encode(['success' => false, 'message' => 'Parameter id diperlukan']);
        exit;
    }

    try {
        $check = $pdo->prepare("SELECT id FROM guru_sp_reports WHERE id = :id");
        $check->execute(['id' => $noteId]);
        $row = $check->fetch();

        if (!$row) {
            http_response_code(404);
            echo json_encode(['success' => false, 'message' => 'Laporan SP tidak ditemukan']);
            exit;
        }

        $stmt = $pdo->prepare("DELETE FROM guru_sp_reports WHERE id = :id");
        $stmt->execute(['id' => $noteId]);

        echo json_encode(['success' => true, 'message' => 'Laporan SP dihapus']);
    } catch (Exception $e) {
        http_response_code(500);
        echo json_encode(['success' => false, 'message' => 'Gagal menghapus laporan SP']);
    }
    exit;
}

http_response_code(405);
echo json_encode(['success' => false, 'message' => 'Method tidak didukung']);
