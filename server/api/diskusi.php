<?php
// /server/api/diskusi.php
// Endpoint CRUD catatan Diskusi Keislaman & Kebangsaan siswa
// GET    -> ambil semua catatan milik siswa (terbaru dulu)
// POST   -> simpan catatan baru / update catatan yang ada
// DELETE -> hapus catatan berdasarkan ID

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

$student = getStudentFromToken($pdo, $token);
if (!$student) {
    http_response_code(403);
    echo json_encode(['success' => false, 'message' => 'Siswa tidak ditemukan']);
    exit;
}

$studentId = $student['student_id'];

// ════════════════════════════════════════
// GET: Ambil semua catatan diskusi
// ════════════════════════════════════════
if ($_SERVER['REQUEST_METHOD'] === 'GET') {
    try {
        $stmt = $pdo->prepare(
            'SELECT id, title, kajian_date, materi, mentor, note, signature_base64, points_earned, created_at
             FROM kajian_logs
             WHERE student_id = :sid
             ORDER BY kajian_date DESC, created_at DESC'
        );
        $stmt->execute(['sid' => $studentId]);
        $rows = $stmt->fetchAll();

        $notes = [];
        foreach ($rows as $row) {
            $notes[] = [
                'id'               => (string) $row['id'],
                'date'             => $row['kajian_date'],
                'judul'            => $row['title'] ?? '',
                'materi'           => $row['materi'] ?? '',
                'mentor'           => $row['mentor'] ?? '',
                'note'             => $row['note'] ?? '',
                'signature_base64' => $row['signature_base64'] ?? '',
                'points'           => (int) $row['points_earned'],
                'created_at'       => $row['created_at'],
            ];
        }

        echo json_encode(['success' => true, 'data' => $notes]);
    } catch (Exception $e) {
        http_response_code(500);
        echo json_encode(['success' => false, 'message' => 'Gagal mengambil data']);
    }
    exit;
}

// ════════════════════════════════════════
// POST: Simpan / Update catatan
// Body JSON: { id?, date, judul, materi, mentor, note, signature_base64 }
// Jika id dikirim -> update, jika tidak -> insert baru
// ════════════════════════════════════════
if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $input = json_decode(file_get_contents('php://input'), true);
    if (!$input) {
        http_response_code(400);
        echo json_encode(['success' => false, 'message' => 'Body JSON tidak valid']);
        exit;
    }

    $date            = $input['date'] ?? date('Y-m-d');
    $judul           = $input['judul'] ?? '';
    $materi          = $input['materi'] ?? '';
    $mentor          = $input['mentor'] ?? '';
    $note            = $input['note'] ?? '';
    $signatureBase64 = $input['signature_base64'] ?? '';
    $noteId          = $input['id'] ?? null;

    if (empty($materi)) {
        http_response_code(400);
        echo json_encode(['success' => false, 'message' => 'Materi wajib diisi']);
        exit;
    }

    try {
        $pdo->beginTransaction();

        if ($noteId) {
            // ── Update ──
            $check = $pdo->prepare('SELECT id FROM kajian_logs WHERE id = :id AND student_id = :sid');
            $check->execute(['id' => $noteId, 'sid' => $studentId]);
            if (!$check->fetch()) {
                $pdo->rollBack();
                http_response_code(404);
                echo json_encode(['success' => false, 'message' => 'Catatan tidak ditemukan']);
                exit;
            }

            $stmt = $pdo->prepare(
                'UPDATE kajian_logs
                 SET title = :title, kajian_date = :d, materi = :materi, mentor = :mentor,
                     note = :note, signature_base64 = :sig
                 WHERE id = :id AND student_id = :sid'
            );
            $stmt->execute([
                'title'  => $judul,
                'd'      => $date,
                'materi' => $materi,
                'mentor' => $mentor,
                'note'   => $note,
                'sig'    => $signatureBase64,
                'id'     => $noteId,
                'sid'    => $studentId,
            ]);

            $resultId = $noteId;
        } else {
            // ── Insert baru + hitung poin ──
            $points = 2; // Poin per catatan diskusi

            $stmt = $pdo->prepare(
                'INSERT INTO kajian_logs (student_id, title, kajian_date, materi, mentor, note, signature_base64, points_earned)
                 VALUES (:sid, :title, :d, :materi, :mentor, :note, :sig, :pts)'
            );
            $stmt->execute([
                'sid'    => $studentId,
                'title'  => $judul,
                'd'      => $date,
                'materi' => $materi,
                'mentor' => $mentor,
                'note'   => $note,
                'sig'    => $signatureBase64,
                'pts'    => $points,
            ]);
            $resultId = $pdo->lastInsertId();

            // Recalculate grand total dari semua sumber
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

            // Kajian/diskusi (including the one just inserted)
            $stmt = $pdo->prepare('SELECT COALESCE(SUM(points_earned), 0) FROM kajian_logs WHERE student_id = :sid');
            $stmt->execute(['sid' => $studentId]);
            $grandTotal += (int) $stmt->fetchColumn();

            $pdo->prepare('UPDATE students SET total_points = :tp WHERE id = :sid')
                ->execute(['tp' => $grandTotal, 'sid' => $studentId]);

            // Log ke points_log
            $pdo->prepare(
                'INSERT INTO points_log (student_id, source, source_id, points, description)
                 VALUES (:sid, :src, :srcid, :pts, :desc)'
            )->execute([
                'sid'   => $studentId,
                'src'   => 'kajian',
                'srcid' => $resultId,
                'pts'   => $points,
                'desc'  => "Diskusi: $judul",
            ]);
        }

        $pdo->commit();

        echo json_encode([
            'success' => true,
            'message' => $noteId ? 'Catatan diperbarui' : 'Catatan disimpan',
            'data'    => ['id' => (string) $resultId],
        ]);
    } catch (Exception $e) {
        $pdo->rollBack();
        http_response_code(500);
        echo json_encode(['success' => false, 'message' => 'Gagal menyimpan catatan']);
    }
    exit;
}

// ════════════════════════════════════════
// DELETE: Hapus catatan
// Query param: id=<note_id>
// ════════════════════════════════════════
if ($_SERVER['REQUEST_METHOD'] === 'DELETE') {
    $noteId = $_GET['id'] ?? null;
    if (!$noteId) {
        http_response_code(400);
        echo json_encode(['success' => false, 'message' => 'Parameter id diperlukan']);
        exit;
    }

    try {
        // Ambil poin yang pernah diberikan untuk catatan ini
        $check = $pdo->prepare('SELECT id, points_earned FROM kajian_logs WHERE id = :id AND student_id = :sid');
        $check->execute(['id' => $noteId, 'sid' => $studentId]);
        $row = $check->fetch();

        if (!$row) {
            http_response_code(404);
            echo json_encode(['success' => false, 'message' => 'Catatan tidak ditemukan']);
            exit;
        }

        $pdo->beginTransaction();

        $earnedPoints = (int) $row['points_earned'];

        // Hapus catatan
        $stmt = $pdo->prepare('DELETE FROM kajian_logs WHERE id = :id AND student_id = :sid');
        $stmt->execute(['id' => $noteId, 'sid' => $studentId]);

        // Recalculate grand total dari semua sumber
        $grandTotal = 0;

        // Shalat points
        $stmtPts = $pdo->prepare('SELECT COALESCE(SUM(points_earned), 0) FROM prayer_logs WHERE student_id = :sid');
        $stmtPts->execute(['sid' => $studentId]);
        $grandTotal += (int) $stmtPts->fetchColumn();

        // Bonus 5/5
        $stmtPts = $pdo->prepare(
            "SELECT COUNT(*) FROM (
                SELECT prayer_date FROM prayer_logs
                WHERE student_id = :sid AND status IN ('done','done_jamaah')
                GROUP BY prayer_date HAVING COUNT(DISTINCT prayer_name) >= 5
            ) AS fd"
        );
        $stmtPts->execute(['sid' => $studentId]);
        $grandTotal += (int) $stmtPts->fetchColumn() * 3;

        // Extras
        $stmtPts = $pdo->prepare('SELECT COALESCE(SUM(total_extra_points), 0) FROM daily_extras WHERE student_id = :sid');
        $stmtPts->execute(['sid' => $studentId]);
        $grandTotal += (int) $stmtPts->fetchColumn();

        // Public speaking
        $stmtPts = $pdo->prepare('SELECT COALESCE(SUM(points_earned), 0) FROM public_speaking_logs WHERE student_id = :sid');
        $stmtPts->execute(['sid' => $studentId]);
        $grandTotal += (int) $stmtPts->fetchColumn();

        // Kajian/diskusi (after deletion)
        $stmtPts = $pdo->prepare('SELECT COALESCE(SUM(points_earned), 0) FROM kajian_logs WHERE student_id = :sid');
        $stmtPts->execute(['sid' => $studentId]);
        $grandTotal += (int) $stmtPts->fetchColumn();

        $pdo->prepare('UPDATE students SET total_points = :tp WHERE id = :sid')
            ->execute(['tp' => $grandTotal, 'sid' => $studentId]);

        if ($earnedPoints > 0) {
            // Log pengurangan poin
            $pdo->prepare(
                'INSERT INTO points_log (student_id, source, source_id, points, description)
                 VALUES (:sid, :src, :srcid, :pts, :desc)'
            )->execute([
                'sid'   => $studentId,
                'src'   => 'kajian_delete',
                'srcid' => $noteId,
                'pts'   => -$earnedPoints,
                'desc'  => 'Hapus catatan Diskusi',
            ]);
        }

        $pdo->commit();

        echo json_encode(['success' => true, 'message' => 'Catatan dihapus']);
    } catch (Exception $e) {
        http_response_code(500);
        echo json_encode(['success' => false, 'message' => 'Gagal menghapus catatan']);
    }
    exit;
}

http_response_code(405);
echo json_encode(['success' => false, 'message' => 'Method tidak didukung']);
