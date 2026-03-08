<?php
// /server/api/guru_tugas.php
// Endpoint untuk fitur Guru Tugas (melihat & mengelola tugas siswa)
//
// Data dibaca/ditulis dari tabel yang sudah ada:
//   - subject "Public Speaking"       -> public_speaking_logs
//   - subject "Diskusi Keislaman"     -> kajian_logs
//
// GET    ?action=students                          -> daftar siswa untuk kelas guru
// GET    ?action=reports&student_id=X&subject=X    -> laporan tugas siswa
// POST                                             -> simpan / update laporan tugas
// DELETE ?id=X&subject=X                           -> hapus laporan tugas

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

// Pastikan user adalah guru (guru_kelas atau guru_tahfidz)
$stmtUser = $pdo->prepare('SELECT id, name, role FROM users WHERE id = :uid AND is_active = 1 LIMIT 1');
$stmtUser->execute(['uid' => $userId]);
$guru = $stmtUser->fetch();

if (!$guru || !in_array($guru['role'], ['guru_kelas', 'guru_tahfidz'])) {
    http_response_code(403);
    echo json_encode(['success' => false, 'message' => 'Akses ditolak. Hanya guru yang dapat mengakses.']);
    exit;
}

// ── Helper: tentukan tabel & kolom tanggal berdasarkan subject ──
function getTableInfo(string $subject): ?array {
    $subjectLower = strtolower(trim($subject));
    if (strpos($subjectLower, 'public speaking') !== false) {
        return [
            'table'      => 'public_speaking_logs',
            'date_col'   => 'speaking_date',
        ];
    } elseif (strpos($subjectLower, 'diskusi') !== false || strpos($subjectLower, 'kajian') !== false) {
        return [
            'table'      => 'kajian_logs',
            'date_col'   => 'kajian_date',
        ];
    }
    return null;
}

// ════════════════════════════════════════════════════
// GET: Daftar Siswa atau Laporan Tugas
// ════════════════════════════════════════════════════
if ($_SERVER['REQUEST_METHOD'] === 'GET') {
    $action = $_GET['action'] ?? '';

    // ── GET Students ──
    if ($action === 'students') {
        try {
            if ($guru['role'] === 'guru_kelas') {
                $stmt = $pdo->prepare(
                    'SELECT s.id AS student_id, s.nis, u.name AS student_name, c.name AS class_name, u.avatar_url
                     FROM students s
                     JOIN users u ON s.user_id = u.id
                     JOIN classes c ON s.class_id = c.id
                     WHERE c.guru_kelas_id = :guru_id
                     ORDER BY u.name ASC'
                );
                $stmt->execute(['guru_id' => $userId]);
            } else {
                $stmt = $pdo->prepare(
                    'SELECT s.id AS student_id, s.nis, u.name AS student_name, c.name AS class_name, u.avatar_url
                     FROM students s
                     JOIN users u ON s.user_id = u.id
                     LEFT JOIN classes c ON s.class_id = c.id
                     WHERE s.guru_tahfidz_id = :guru_id
                     ORDER BY u.name ASC'
                );
                $stmt->execute(['guru_id' => $userId]);
            }

            $rows = $stmt->fetchAll();
            $students = [];
            foreach ($rows as $row) {
                $students[] = [
                    'student_id'   => (int) $row['student_id'],
                    'nis'          => $row['nis'] ?? '',
                    'name'         => $row['student_name'],
                    'class_name'   => $row['class_name'] ?? '',
                    'avatar_url'   => $row['avatar_url'] ?? '',
                ];
            }

            echo json_encode(['success' => true, 'data' => $students]);
        } catch (Exception $e) {
            http_response_code(500);
            echo json_encode(['success' => false, 'message' => 'Gagal mengambil daftar siswa']);
        }
        exit;
    }

    // ── GET Reports ──
    if ($action === 'reports') {
        $studentId = $_GET['student_id'] ?? null;
        $subject   = $_GET['subject'] ?? '';

        if (!$studentId || empty($subject)) {
            http_response_code(400);
            echo json_encode(['success' => false, 'message' => 'Parameter student_id dan subject diperlukan']);
            exit;
        }

        $tableInfo = getTableInfo($subject);
        if (!$tableInfo) {
            http_response_code(400);
            echo json_encode(['success' => false, 'message' => 'Subject tidak dikenali']);
            exit;
        }

        $table   = $tableInfo['table'];
        $dateCol = $tableInfo['date_col'];

        try {
            $stmt = $pdo->prepare(
                "SELECT id, title, materi, mentor, note, {$dateCol} AS tugas_date, points_earned, created_at
                 FROM {$table}
                 WHERE student_id = :sid
                 ORDER BY {$dateCol} DESC, created_at DESC"
            );
            $stmt->execute(['sid' => $studentId]);
            $rows = $stmt->fetchAll();

            $reports = [];
            foreach ($rows as $row) {
                $reports[] = [
                    'id'         => (string) $row['id'],
                    'date'       => $row['tugas_date'],
                    'judul'      => $row['title'] ?? '',
                    'materi'     => $row['materi'] ?? '',
                    'mentor'     => $row['mentor'] ?? '',
                    'note'       => $row['note'] ?? '',
                    'subject'    => $subject,
                    'points'     => (int) $row['points_earned'],
                    'created_at' => $row['created_at'],
                ];
            }

            echo json_encode(['success' => true, 'data' => $reports]);
        } catch (Exception $e) {
            http_response_code(500);
            echo json_encode(['success' => false, 'message' => 'Gagal mengambil laporan tugas']);
        }
        exit;
    }

    http_response_code(400);
    echo json_encode(['success' => false, 'message' => 'Parameter action tidak valid (students/reports)']);
    exit;
}

// ════════════════════════════════════════════════════
// POST: Simpan / Update Laporan Tugas
// Body JSON: { id?, student_id, subject, date, judul, materi, mentor, note }
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
    $subject   = $input['subject'] ?? '';
    $date      = $input['date'] ?? date('Y-m-d');
    $judul     = $input['judul'] ?? '';
    $materi    = $input['materi'] ?? '';
    $mentor    = $input['mentor'] ?? '';
    $note      = $input['note'] ?? '';

    // Validasi
    if (empty($judul)) {
        http_response_code(400);
        echo json_encode(['success' => false, 'message' => 'Judul wajib diisi']);
        exit;
    }
    if (empty($materi)) {
        http_response_code(400);
        echo json_encode(['success' => false, 'message' => 'Materi wajib diisi']);
        exit;
    }
    if (!$studentId) {
        http_response_code(400);
        echo json_encode(['success' => false, 'message' => 'student_id wajib diisi']);
        exit;
    }
    if (empty($subject)) {
        http_response_code(400);
        echo json_encode(['success' => false, 'message' => 'subject wajib diisi']);
        exit;
    }

    $tableInfo = getTableInfo($subject);
    if (!$tableInfo) {
        http_response_code(400);
        echo json_encode(['success' => false, 'message' => 'Subject tidak dikenali']);
        exit;
    }

    $table   = $tableInfo['table'];
    $dateCol = $tableInfo['date_col'];

    try {
        $pdo->beginTransaction();

        if ($noteId) {
            // ── Update ──
            $check = $pdo->prepare("SELECT id FROM {$table} WHERE id = :id AND student_id = :sid");
            $check->execute(['id' => $noteId, 'sid' => $studentId]);
            if (!$check->fetch()) {
                $pdo->rollBack();
                http_response_code(404);
                echo json_encode(['success' => false, 'message' => 'Laporan tidak ditemukan']);
                exit;
            }

            $stmt = $pdo->prepare(
                "UPDATE {$table}
                 SET title = :title, materi = :materi, mentor = :mentor,
                     note = :note, {$dateCol} = :d
                 WHERE id = :id AND student_id = :sid"
            );
            $stmt->execute([
                'title'  => $judul,
                'materi' => $materi,
                'mentor' => $mentor,
                'note'   => $note,
                'd'      => $date,
                'id'     => $noteId,
                'sid'    => $studentId,
            ]);

            $resultId = $noteId;
        } else {
            // ── Insert baru ──
            $points = 2; // Poin per catatan

            $stmt = $pdo->prepare(
                "INSERT INTO {$table} (student_id, title, {$dateCol}, materi, mentor, note, points_earned)
                 VALUES (:sid, :title, :d, :materi, :mentor, :note, :pts)"
            );
            $stmt->execute([
                'sid'    => $studentId,
                'title'  => $judul,
                'd'      => $date,
                'materi' => $materi,
                'mentor' => $mentor,
                'note'   => $note,
                'pts'    => $points,
            ]);
            $resultId = $pdo->lastInsertId();

            // Recalculate total points
            $grandTotal = 0;

            // Shalat points
            $stmt = $pdo->prepare('SELECT COALESCE(SUM(points_earned), 0) FROM prayer_logs WHERE student_id = :sid');
            $stmt->execute(['sid' => $studentId]);
            $grandTotal += (int) $stmt->fetchColumn();

            // Bonus 5/5
            $stmt = $pdo->prepare(
                "SELECT COUNT(*) FROM (
                    SELECT prayer_date FROM prayer_logs
                    WHERE student_id = :sid AND status IN ('done','done_jamaah')
                    GROUP BY prayer_date HAVING COUNT(DISTINCT prayer_name) >= 5
                ) AS fd"
            );
            $stmt->execute(['sid' => $studentId]);
            $grandTotal += (int) $stmt->fetchColumn() * 3;

            // Extras
            $stmt = $pdo->prepare('SELECT COALESCE(SUM(total_extra_points), 0) FROM daily_extras WHERE student_id = :sid');
            $stmt->execute(['sid' => $studentId]);
            $grandTotal += (int) $stmt->fetchColumn();

            // Public speaking
            $stmt = $pdo->prepare('SELECT COALESCE(SUM(points_earned), 0) FROM public_speaking_logs WHERE student_id = :sid');
            $stmt->execute(['sid' => $studentId]);
            $grandTotal += (int) $stmt->fetchColumn();

            // Kajian/diskusi
            $stmt = $pdo->prepare('SELECT COALESCE(SUM(points_earned), 0) FROM kajian_logs WHERE student_id = :sid');
            $stmt->execute(['sid' => $studentId]);
            $grandTotal += (int) $stmt->fetchColumn();

            $pdo->prepare('UPDATE students SET total_points = :tp WHERE id = :sid')
                ->execute(['tp' => $grandTotal, 'sid' => $studentId]);

            // Log poin
            $source = ($table === 'public_speaking_logs') ? 'public_speaking' : 'kajian';
            $sourceLabel = ($table === 'public_speaking_logs') ? 'Public Speaking' : 'Diskusi';
            $pdo->prepare(
                'INSERT INTO points_log (student_id, source, source_id, points, description)
                 VALUES (:sid, :src, :srcid, :pts, :desc)'
            )->execute([
                'sid'   => $studentId,
                'src'   => $source,
                'srcid' => $resultId,
                'pts'   => $points,
                'desc'  => "{$sourceLabel}: {$judul}",
            ]);
        }

        $pdo->commit();

        echo json_encode([
            'success' => true,
            'message' => $noteId ? 'Laporan diperbarui' : 'Laporan disimpan',
            'data'    => ['id' => (string) $resultId],
        ]);
    } catch (Exception $e) {
        $pdo->rollBack();
        http_response_code(500);
        echo json_encode(['success' => false, 'message' => 'Gagal menyimpan laporan']);
    }
    exit;
}

// ════════════════════════════════════════════════════
// DELETE: Hapus laporan
// Query param: id=<report_id>&subject=<subject>
// ════════════════════════════════════════════════════
if ($_SERVER['REQUEST_METHOD'] === 'DELETE') {
    $noteId  = $_GET['id'] ?? null;
    $subject = $_GET['subject'] ?? '';

    if (!$noteId) {
        http_response_code(400);
        echo json_encode(['success' => false, 'message' => 'Parameter id diperlukan']);
        exit;
    }
    if (empty($subject)) {
        http_response_code(400);
        echo json_encode(['success' => false, 'message' => 'Parameter subject diperlukan']);
        exit;
    }

    $tableInfo = getTableInfo($subject);
    if (!$tableInfo) {
        http_response_code(400);
        echo json_encode(['success' => false, 'message' => 'Subject tidak dikenali']);
        exit;
    }

    $table = $tableInfo['table'];

    try {
        // Ambil data sebelum hapus
        $check = $pdo->prepare("SELECT id, student_id, points_earned FROM {$table} WHERE id = :id");
        $check->execute(['id' => $noteId]);
        $row = $check->fetch();

        if (!$row) {
            http_response_code(404);
            echo json_encode(['success' => false, 'message' => 'Laporan tidak ditemukan']);
            exit;
        }

        $studentId    = (int) $row['student_id'];
        $earnedPoints = (int) $row['points_earned'];

        $pdo->beginTransaction();

        // Hapus catatan
        $stmt = $pdo->prepare("DELETE FROM {$table} WHERE id = :id");
        $stmt->execute(['id' => $noteId]);

        // Recalculate total points
        $grandTotal = 0;

        $stmtPts = $pdo->prepare('SELECT COALESCE(SUM(points_earned), 0) FROM prayer_logs WHERE student_id = :sid');
        $stmtPts->execute(['sid' => $studentId]);
        $grandTotal += (int) $stmtPts->fetchColumn();

        $stmtPts = $pdo->prepare(
            "SELECT COUNT(*) FROM (
                SELECT prayer_date FROM prayer_logs
                WHERE student_id = :sid AND status IN ('done','done_jamaah')
                GROUP BY prayer_date HAVING COUNT(DISTINCT prayer_name) >= 5
            ) AS fd"
        );
        $stmtPts->execute(['sid' => $studentId]);
        $grandTotal += (int) $stmtPts->fetchColumn() * 3;

        $stmtPts = $pdo->prepare('SELECT COALESCE(SUM(total_extra_points), 0) FROM daily_extras WHERE student_id = :sid');
        $stmtPts->execute(['sid' => $studentId]);
        $grandTotal += (int) $stmtPts->fetchColumn();

        $stmtPts = $pdo->prepare('SELECT COALESCE(SUM(points_earned), 0) FROM public_speaking_logs WHERE student_id = :sid');
        $stmtPts->execute(['sid' => $studentId]);
        $grandTotal += (int) $stmtPts->fetchColumn();

        $stmtPts = $pdo->prepare('SELECT COALESCE(SUM(points_earned), 0) FROM kajian_logs WHERE student_id = :sid');
        $stmtPts->execute(['sid' => $studentId]);
        $grandTotal += (int) $stmtPts->fetchColumn();

        $pdo->prepare('UPDATE students SET total_points = :tp WHERE id = :sid')
            ->execute(['tp' => $grandTotal, 'sid' => $studentId]);

        if ($earnedPoints > 0) {
            $source = ($table === 'public_speaking_logs') ? 'public_speaking' : 'kajian';
            $pdo->prepare(
                'INSERT INTO points_log (student_id, source, source_id, points, description)
                 VALUES (:sid, :src, :srcid, :pts, :desc)'
            )->execute([
                'sid'   => $studentId,
                'src'   => $source,
                'srcid' => $noteId,
                'pts'   => -$earnedPoints,
                'desc'  => 'Hapus catatan oleh guru',
            ]);
        }

        $pdo->commit();

        echo json_encode(['success' => true, 'message' => 'Laporan dihapus']);
    } catch (Exception $e) {
        if ($pdo->inTransaction()) $pdo->rollBack();
        http_response_code(500);
        echo json_encode(['success' => false, 'message' => 'Gagal menghapus laporan']);
    }
    exit;
}

http_response_code(405);
echo json_encode(['success' => false, 'message' => 'Method tidak didukung']);
