<?php
// /server/api/tahfidz.php
// Endpoint untuk fitur Tahfidz (setoran hafalan Al-Qur'an)
//
// Tabel: tahfidz_setoran, tahfidz_targets
//
// GET    ?action=classes                   -> daftar kelas (guru_tahfidz)
// GET    ?action=class_students&class_id=X -> daftar siswa per kelas (guru_tahfidz)
// GET    ?action=students                 -> daftar siswa (guru)
// GET    ?action=reports&student_id=X     -> riwayat setoran siswa (guru)
// GET    ?action=my_setoran               -> riwayat setoran sendiri (siswa)
// GET    ?action=wali_setoran[&student_id=X] -> riwayat setoran anak (orang_tua)
// POST                                    -> simpan / update setoran (multi-surah)
// DELETE ?id=X                            -> hapus setoran (by group_id or single id)

header('Content-Type: application/json; charset=utf-8');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, POST, DELETE, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit;
}

set_exception_handler(function ($e) {
    http_response_code(500);
    echo json_encode([
        'success' => false,
        'message' => 'Server error: ' . $e->getMessage(),
        'file'    => basename($e->getFile()) . ':' . $e->getLine(),
    ]);
    exit;
});

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

$stmtUser = $pdo->prepare('SELECT id, name, role FROM users WHERE id = :uid AND is_active = 1 LIMIT 1');
$stmtUser->execute(['uid' => $userId]);
$user = $stmtUser->fetch();

if (!$user) {
    http_response_code(403);
    echo json_encode(['success' => false, 'message' => 'Akses ditolak']);
    exit;
}

// ── Helper: grade mapping ──
function gradeToDb($letter) {
    $map = [
        'A'  => 'mumtaz',
        'B+' => 'jayyid_jiddan',
        'B'  => 'jayyid',
        'C'  => 'maqbul',
        'D'  => 'rasib',
    ];
    $key = strtoupper(trim($letter));
    return isset($map[$key]) ? $map[$key] : 'maqbul';
}

function dbToGrade($db) {
    $map = [
        'mumtaz'        => 'A',
        'jayyid_jiddan' => 'B+',
        'jayyid'        => 'B',
        'maqbul'        => 'C',
        'rasib'         => 'D',
    ];
    return isset($map[$db]) ? $map[$db] : 'C';
}

function dbToGradeLabel($db) {
    $map = [
        'mumtaz'        => 'Mumtaz',
        'jayyid_jiddan' => 'Jayyid Jiddan',
        'jayyid'        => 'Jayyid',
        'maqbul'        => 'Maqbul',
        'rasib'         => 'Rasib',
    ];
    return isset($map[$db]) ? $map[$db] : $db;
}

// ── Helper: recalculate total_points ──
function recalcTotalPoints($pdo, $studentId) {
    $grandTotal = 0;

    // Shalat points
    $s = $pdo->prepare('SELECT COALESCE(SUM(points_earned), 0) FROM prayer_logs WHERE student_id = :sid');
    $s->execute(['sid' => $studentId]);
    $grandTotal += (int) $s->fetchColumn();

    // Bonus 5/5
    $s = $pdo->prepare(
        "SELECT COUNT(*) FROM (
            SELECT prayer_date FROM prayer_logs
            WHERE student_id = :sid AND status IN ('done','done_jamaah')
            GROUP BY prayer_date HAVING COUNT(DISTINCT prayer_name) >= 5
        ) AS fd"
    );
    $s->execute(['sid' => $studentId]);
    $grandTotal += (int) $s->fetchColumn() * 3;

    // Daily extras
    $s = $pdo->prepare('SELECT COALESCE(SUM(total_extra_points), 0) FROM daily_extras WHERE student_id = :sid');
    $s->execute(['sid' => $studentId]);
    $grandTotal += (int) $s->fetchColumn();

    // Public speaking
    $s = $pdo->prepare('SELECT COALESCE(SUM(points_earned), 0) FROM public_speaking_logs WHERE student_id = :sid');
    $s->execute(['sid' => $studentId]);
    $grandTotal += (int) $s->fetchColumn();

    // Kajian/diskusi
    $s = $pdo->prepare('SELECT COALESCE(SUM(points_earned), 0) FROM kajian_logs WHERE student_id = :sid');
    $s->execute(['sid' => $studentId]);
    $grandTotal += (int) $s->fetchColumn();

    // Tahfidz points
    $s = $pdo->prepare('SELECT COALESCE(SUM(points_earned), 0) FROM tahfidz_setoran WHERE student_id = :sid');
    $s->execute(['sid' => $studentId]);
    $grandTotal += (int) $s->fetchColumn();

    $pdo->prepare('UPDATE students SET total_points = :tp WHERE id = :sid')
        ->execute(['tp' => $grandTotal, 'sid' => $studentId]);
}

// ── Helper: ensure group_id column exists ──
function ensureGroupIdColumn($pdo) {
    try {
        $pdo->query("SELECT group_id FROM tahfidz_setoran LIMIT 1");
    } catch (Exception $e) {
        $pdo->exec("ALTER TABLE tahfidz_setoran ADD COLUMN group_id VARCHAR(36) DEFAULT NULL AFTER target_id");
        $pdo->exec("CREATE INDEX idx_tahfidz_group ON tahfidz_setoran(group_id)");
    }
}
ensureGroupIdColumn($pdo);

// ── Helper: group setoran rows into reports ──
function groupSetoran($rows) {
    $grouped = [];
    foreach ($rows as $r) {
        $gid = $r['group_id'] ?? null;
        $key = $gid ?: ('single_' . $r['id']); // ungrouped rows = own group

        if (!isset($grouped[$key])) {
            $grouped[$key] = [
                'id'          => (string) $r['id'],
                'group_id'    => $gid,
                'grade'       => $r['grade_letter'] ?? dbToGrade($r['grade']),
                'grade_label' => $r['grade_label_text'] ?? dbToGradeLabel($r['grade']),
                'notes'       => $r['notes'] ?? '',
                'points'      => 0,
                'guru_name'   => $r['guru_name'] ?? '',
                'setoran_at'  => $r['setoran_at'],
                'items'       => [],
            ];
        }
        $grouped[$key]['points'] += (int) $r['points_earned'];
        $grouped[$key]['items'][] = [
            'id'           => (string) $r['id'],
            'surah_number' => (int) $r['surah_number'],
            'ayat_from'    => (int) $r['ayat_from'],
            'ayat_to'      => (int) $r['ayat_to'],
            'grade'        => $r['grade_letter'] ?? dbToGrade($r['grade']),
            'grade_label'  => $r['grade_label_text'] ?? dbToGradeLabel($r['grade']),
        ];
    }
    return array_values($grouped);
}

// ════════════════════════════════════════════════════
// GET
// ════════════════════════════════════════════════════
if ($_SERVER['REQUEST_METHOD'] === 'GET') {
    $action = $_GET['action'] ?? '';

    // ── GET Classes (guru_tahfidz: kelas yang punya siswa di-assign) ──
    if ($action === 'classes') {
        if ($user['role'] !== 'guru_tahfidz') {
            http_response_code(403);
            echo json_encode(['success' => false, 'message' => 'Akses ditolak']);
            exit;
        }

        try {
            $stmt = $pdo->prepare(
                'SELECT DISTINCT c.id, c.name, c.academic_year,
                        COUNT(s.id) AS student_count
                 FROM classes c
                 JOIN students s ON s.class_id = c.id
                 WHERE s.guru_tahfidz_id = :guru_id
                 GROUP BY c.id, c.name, c.academic_year
                 ORDER BY c.name ASC'
            );
            $stmt->execute(['guru_id' => $userId]);
            $rows = $stmt->fetchAll();

            $classes = [];
            foreach ($rows as $r) {
                $classes[] = [
                    'id'            => (int) $r['id'],
                    'name'          => $r['name'],
                    'academic_year' => $r['academic_year'] ?? '',
                    'student_count' => (int) $r['student_count'],
                ];
            }

            echo json_encode(['success' => true, 'data' => $classes]);
        } catch (Exception $e) {
            http_response_code(500);
            echo json_encode(['success' => false, 'message' => 'Gagal mengambil data kelas']);
        }
        exit;
    }

    // ── GET Class Students (guru_tahfidz: siswa per kelas) ──
    if ($action === 'class_students') {
        if ($user['role'] !== 'guru_tahfidz') {
            http_response_code(403);
            echo json_encode(['success' => false, 'message' => 'Akses ditolak']);
            exit;
        }

        $classId = $_GET['class_id'] ?? null;
        if (!$classId) {
            http_response_code(400);
            echo json_encode(['success' => false, 'message' => 'class_id diperlukan']);
            exit;
        }

        try {
            $stmt = $pdo->prepare(
                'SELECT s.id AS student_id, s.nis, u.name AS student_name, c.name AS class_name
                 FROM students s
                 JOIN users u ON s.user_id = u.id
                 LEFT JOIN classes c ON s.class_id = c.id
                 WHERE s.guru_tahfidz_id = :guru_id AND s.class_id = :class_id
                 ORDER BY u.name ASC'
            );
            $stmt->execute(['guru_id' => $userId, 'class_id' => $classId]);
            $rows = $stmt->fetchAll();

            $students = [];
            foreach ($rows as $r) {
                $students[] = [
                    'student_id' => (int) $r['student_id'],
                    'nis'        => $r['nis'] ?? '',
                    'name'       => $r['student_name'],
                    'class_name' => $r['class_name'] ?? '',
                ];
            }

            echo json_encode(['success' => true, 'data' => $students]);
        } catch (Exception $e) {
            http_response_code(500);
            echo json_encode(['success' => false, 'message' => 'Gagal mengambil data siswa']);
        }
        exit;
    }

    // ── GET Students (guru only) ──
    if ($action === 'students') {
        if (!in_array($user['role'], ['guru_kelas', 'guru_tahfidz'])) {
            http_response_code(403);
            echo json_encode(['success' => false, 'message' => 'Akses ditolak']);
            exit;
        }

        try {
            if ($user['role'] === 'guru_tahfidz') {
                $stmt = $pdo->prepare(
                    'SELECT s.id AS student_id, s.nis, u.name AS student_name, c.name AS class_name
                     FROM students s
                     JOIN users u ON s.user_id = u.id
                     LEFT JOIN classes c ON s.class_id = c.id
                     WHERE s.guru_tahfidz_id = :guru_id
                     ORDER BY u.name ASC'
                );
            } else {
                $stmt = $pdo->prepare(
                    'SELECT s.id AS student_id, s.nis, u.name AS student_name, c.name AS class_name
                     FROM students s
                     JOIN users u ON s.user_id = u.id
                     JOIN classes c ON s.class_id = c.id
                     WHERE c.guru_kelas_id = :guru_id
                     ORDER BY u.name ASC'
                );
            }
            $stmt->execute(['guru_id' => $userId]);
            $rows = $stmt->fetchAll();

            $students = [];
            foreach ($rows as $r) {
                $students[] = [
                    'student_id' => (int) $r['student_id'],
                    'nis'        => $r['nis'] ?? '',
                    'name'       => $r['student_name'],
                    'class_name' => $r['class_name'] ?? '',
                ];
            }

            echo json_encode(['success' => true, 'data' => $students]);
        } catch (Exception $e) {
            http_response_code(500);
            echo json_encode(['success' => false, 'message' => 'Gagal mengambil data siswa']);
        }
        exit;
    }

    // ── GET Reports (guru melihat setoran siswa) ──
    if ($action === 'reports') {
        if (!in_array($user['role'], ['guru_kelas', 'guru_tahfidz'])) {
            http_response_code(403);
            echo json_encode(['success' => false, 'message' => 'Akses ditolak']);
            exit;
        }

        $studentId = $_GET['student_id'] ?? null;
        if (!$studentId) {
            http_response_code(400);
            echo json_encode(['success' => false, 'message' => 'student_id diperlukan']);
            exit;
        }

        try {
            $stmt = $pdo->prepare(
                'SELECT ts.id, ts.group_id, ts.surah_number, ts.ayat_from, ts.ayat_to,
                        ts.grade, ts.notes, ts.points_earned, ts.setoran_at,
                        u.name AS guru_name
                 FROM tahfidz_setoran ts
                 LEFT JOIN users u ON ts.guru_tahfidz_id = u.id
                 WHERE ts.student_id = :sid
                 ORDER BY ts.setoran_at DESC, ts.group_id, ts.id'
            );
            $stmt->execute(['sid' => $studentId]);
            $rows = $stmt->fetchAll();

            $reports = groupSetoran($rows);

            echo json_encode(['success' => true, 'data' => $reports]);
        } catch (Exception $e) {
            http_response_code(500);
            echo json_encode(['success' => false, 'message' => 'Gagal mengambil data setoran']);
        }
        exit;
    }

    // ── GET My Setoran (siswa melihat riwayat sendiri) ──
    if ($action === 'my_setoran') {
        if ($user['role'] !== 'siswa') {
            http_response_code(403);
            echo json_encode(['success' => false, 'message' => 'Akses ditolak']);
            exit;
        }

        $stmtStudent = $pdo->prepare('SELECT id FROM students WHERE user_id = :uid LIMIT 1');
        $stmtStudent->execute(['uid' => $userId]);
        $student = $stmtStudent->fetch();

        if (!$student) {
            http_response_code(404);
            echo json_encode(['success' => false, 'message' => 'Data siswa tidak ditemukan']);
            exit;
        }

        try {
            $stmt = $pdo->prepare(
                'SELECT ts.id, ts.group_id, ts.surah_number, ts.ayat_from, ts.ayat_to,
                        ts.grade, ts.notes, ts.points_earned, ts.setoran_at,
                        u.name AS guru_name
                 FROM tahfidz_setoran ts
                 LEFT JOIN users u ON ts.guru_tahfidz_id = u.id
                 WHERE ts.student_id = :sid
                 ORDER BY ts.setoran_at DESC, ts.group_id, ts.id'
            );
            $stmt->execute(['sid' => $student['id']]);
            $rows = $stmt->fetchAll();

            $reports = groupSetoran($rows);

            echo json_encode(['success' => true, 'data' => $reports]);
        } catch (Exception $e) {
            http_response_code(500);
            echo json_encode(['success' => false, 'message' => 'Gagal mengambil data setoran']);
        }
        exit;
    }

    // ── GET Wali Setoran (orang_tua melihat riwayat setoran anak) ──
    if ($action === 'wali_setoran') {
        if ($user['role'] !== 'orang_tua') {
            http_response_code(403);
            echo json_encode(['success' => false, 'message' => 'Akses ditolak']);
            exit;
        }

        // Resolve student_id dari parent_student
        $requestedStudentId = isset($_GET['student_id']) ? (int) $_GET['student_id'] : null;

        if ($requestedStudentId) {
            // Validasi anak ini milik parent ini
            $stmtChild = $pdo->prepare(
                'SELECT s.id FROM parent_student ps
                 JOIN students s ON ps.student_id = s.id
                 WHERE ps.parent_id = :uid AND s.id = :sid LIMIT 1'
            );
            $stmtChild->execute(['uid' => $userId, 'sid' => $requestedStudentId]);
            $childRow = $stmtChild->fetch();
        } else {
            // Ambil anak pertama
            $stmtChild = $pdo->prepare(
                'SELECT s.id FROM parent_student ps
                 JOIN students s ON ps.student_id = s.id
                 WHERE ps.parent_id = :uid LIMIT 1'
            );
            $stmtChild->execute(['uid' => $userId]);
            $childRow = $stmtChild->fetch();
        }

        if (!$childRow) {
            http_response_code(404);
            echo json_encode(['success' => false, 'message' => 'Data anak tidak ditemukan']);
            exit;
        }

        $studentId = $childRow['id'];

        try {
            $stmt = $pdo->prepare(
                'SELECT ts.id, ts.group_id, ts.surah_number, ts.ayat_from, ts.ayat_to,
                        ts.grade, ts.notes, ts.points_earned, ts.setoran_at,
                        u.name AS guru_name
                 FROM tahfidz_setoran ts
                 LEFT JOIN users u ON ts.guru_tahfidz_id = u.id
                 WHERE ts.student_id = :sid
                 ORDER BY ts.setoran_at DESC, ts.group_id, ts.id'
            );
            $stmt->execute(['sid' => $studentId]);
            $rows = $stmt->fetchAll();

            $reports = groupSetoran($rows);

            echo json_encode(['success' => true, 'data' => $reports]);
        } catch (Exception $e) {
            http_response_code(500);
            echo json_encode(['success' => false, 'message' => 'Gagal mengambil data setoran']);
        }
        exit;
    }

    http_response_code(400);
    echo json_encode(['success' => false, 'message' => 'Parameter action tidak valid (students/reports/my_setoran/wali_setoran)']);
    exit;
}

// ════════════════════════════════════════════════════
// POST: Simpan / Update Setoran
// Body JSON: { id?, student_id, surah_number, ayat_from, ayat_to, grade, notes }
// ════════════════════════════════════════════════════
if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    if (!in_array($user['role'], ['guru_kelas', 'guru_tahfidz'])) {
        http_response_code(403);
        echo json_encode(['success' => false, 'message' => 'Akses ditolak. Hanya guru yang dapat mengakses.']);
        exit;
    }

    $input = json_decode(file_get_contents('php://input'), true);
    if (!$input) {
        http_response_code(400);
        echo json_encode(['success' => false, 'message' => 'Body JSON tidak valid']);
        exit;
    }

    $noteId    = $input['id'] ?? null;
    $groupId   = $input['group_id'] ?? null;
    $studentId = $input['student_id'] ?? null;
    $grade     = $input['grade'] ?? 'C';
    $notes     = $input['notes'] ?? '';

    // Multi-surah: accept "surahs" array, OR legacy single surah fields
    $surahs = $input['surahs'] ?? null;
    if (!$surahs) {
        // Backward compat: single surah
        $sn = $input['surah_number'] ?? null;
        $af = $input['ayat_from'] ?? null;
        $at = $input['ayat_to'] ?? null;
        if ($sn && $af && $at) {
            $surahs = [['surah_number' => $sn, 'ayat_from' => $af, 'ayat_to' => $at]];
        }
    }

    if (!$studentId || !$surahs || empty($surahs)) {
        http_response_code(400);
        echo json_encode(['success' => false, 'message' => 'student_id dan minimal 1 surah wajib diisi']);
        exit;
    }

    $dbGrade = gradeToDb($grade);

    try {
        $pdo->beginTransaction();

        if ($noteId || $groupId) {
            // ── Update existing report ──
            // Delete old rows by group_id (or single id), then re-insert
            if ($groupId) {
                $pdo->prepare('DELETE FROM tahfidz_setoran WHERE group_id = :gid AND student_id = :sid')
                    ->execute(['gid' => $groupId, 'sid' => $studentId]);
            } elseif ($noteId) {
                $pdo->prepare('DELETE FROM tahfidz_setoran WHERE id = :id AND student_id = :sid')
                    ->execute(['id' => $noteId, 'sid' => $studentId]);
            }

            // Re-insert with same group_id (or generate new one)
            $newGroupId = $groupId ?: bin2hex(random_bytes(18));
            $resultIds = [];
            $isFirstItem = true;

            foreach ($surahs as $s) {
                $sn = $s['surah_number'];
                $af = $s['ayat_from'];
                $at = $s['ayat_to'];

                // Ensure target exists
                $stmtTarget = $pdo->prepare(
                    'SELECT id FROM tahfidz_targets
                     WHERE student_id = :sid AND guru_tahfidz_id = :gid AND surah_number = :sn LIMIT 1'
                );
                $stmtTarget->execute(['sid' => $studentId, 'gid' => $userId, 'sn' => $sn]);
                $target = $stmtTarget->fetch();
                if (!$target) {
                    $pdo->prepare(
                        'INSERT INTO tahfidz_targets (student_id, guru_tahfidz_id, surah_number, start_ayat, end_ayat, status)
                         VALUES (:sid, :gid, :sn, :sa, :ea, :st)'
                    )->execute(['sid' => $studentId, 'gid' => $userId, 'sn' => $sn, 'sa' => $af, 'ea' => $at, 'st' => 'setor']);
                    $targetId = $pdo->lastInsertId();
                } else {
                    $targetId = $target['id'];
                }

                // 1 laporan = 5 point (hanya di baris pertama)
                $pts = $isFirstItem ? 5 : 0;
                $isFirstItem = false;

                // Per-surah grade (fallback ke grade global)
                $itemGrade = isset($s['grade']) ? gradeToDb($s['grade']) : $dbGrade;

                $pdo->prepare(
                    'INSERT INTO tahfidz_setoran
                        (target_id, group_id, student_id, guru_tahfidz_id, surah_number, ayat_from, ayat_to, grade, notes, points_earned)
                     VALUES (:tid, :gid, :sid, :uid, :sn, :af, :at, :g, :n, :pts)'
                )->execute([
                    'tid' => $targetId, 'gid' => $newGroupId, 'sid' => $studentId,
                    'uid' => $userId, 'sn' => $sn, 'af' => $af, 'at' => $at,
                    'g' => $itemGrade, 'n' => $notes, 'pts' => $pts,
                ]);
                $resultIds[] = $pdo->lastInsertId();
            }

            recalcTotalPoints($pdo, (int) $studentId);
            $pdo->commit();

            echo json_encode([
                'success' => true,
                'message' => 'Setoran diperbarui',
                'data'    => ['id' => (string) $resultIds[0], 'group_id' => $newGroupId],
            ]);
        } else {
            // ── Insert baru ──
            $newGroupId = count($surahs) > 1 ? bin2hex(random_bytes(18)) : null;
            $resultIds = [];
            $isFirstItem = true;

            foreach ($surahs as $s) {
                $sn = $s['surah_number'];
                $af = $s['ayat_from'];
                $at = $s['ayat_to'];

                // Pastikan ada target (FK constraint)
                $stmtTarget = $pdo->prepare(
                    'SELECT id FROM tahfidz_targets
                     WHERE student_id = :sid AND guru_tahfidz_id = :gid AND surah_number = :sn LIMIT 1'
                );
                $stmtTarget->execute(['sid' => $studentId, 'gid' => $userId, 'sn' => $sn]);
                $target = $stmtTarget->fetch();

                if (!$target) {
                    $pdo->prepare(
                        'INSERT INTO tahfidz_targets (student_id, guru_tahfidz_id, surah_number, start_ayat, end_ayat, status)
                         VALUES (:sid, :gid, :sn, :sa, :ea, :st)'
                    )->execute(['sid' => $studentId, 'gid' => $userId, 'sn' => $sn, 'sa' => $af, 'ea' => $at, 'st' => 'setor']);
                    $targetId = $pdo->lastInsertId();
                } else {
                    $targetId = $target['id'];
                    $pdo->prepare('UPDATE tahfidz_targets SET status = :st WHERE id = :id')
                        ->execute(['st' => 'setor', 'id' => $targetId]);
                }

                // 1 laporan = 5 point (hanya di baris pertama, sisanya 0)
                $pts = $isFirstItem ? 5 : 0;
                $isFirstItem = false;

                // Per-surah grade (fallback ke grade global)
                $itemGrade = isset($s['grade']) ? gradeToDb($s['grade']) : $dbGrade;

                $pdo->prepare(
                    'INSERT INTO tahfidz_setoran
                        (target_id, group_id, student_id, guru_tahfidz_id, surah_number, ayat_from, ayat_to, grade, notes, points_earned)
                     VALUES (:tid, :gid, :sid, :uid, :sn, :af, :at, :g, :n, :pts)'
                )->execute([
                    'tid' => $targetId, 'gid' => $newGroupId, 'sid' => $studentId,
                    'uid' => $userId, 'sn' => $sn, 'af' => $af, 'at' => $at,
                    'g' => $itemGrade, 'n' => $notes, 'pts' => $pts,
                ]);
                $rid = $pdo->lastInsertId();
                $resultIds[] = $rid;
            }

            // Log poin 1x per laporan (bukan per surah)
            $firstSn = $surahs[0]['surah_number'];
            $desc = count($surahs) > 1
                ? 'Setoran Tahfidz: ' . count($surahs) . ' surah'
                : "Setoran Tahfidz: Surah {$firstSn} ayat {$surahs[0]['ayat_from']}-{$surahs[0]['ayat_to']}";
            $pdo->prepare(
                'INSERT INTO points_log (student_id, source, source_id, points, description)
                 VALUES (:sid, :src, :srcid, :pts, :desc)'
            )->execute([
                'sid' => $studentId, 'src' => 'tahfidz', 'srcid' => $resultIds[0],
                'pts' => 5, 'desc' => $desc,
            ]);

            recalcTotalPoints($pdo, (int) $studentId);
            $pdo->commit();

            echo json_encode([
                'success' => true,
                'message' => 'Setoran disimpan',
                'data'    => ['id' => (string) $resultIds[0], 'group_id' => $newGroupId],
            ]);
        }
    } catch (Exception $e) {
        if ($pdo->inTransaction()) $pdo->rollBack();
        http_response_code(500);
        echo json_encode([
            'success' => false,
            'message' => 'Gagal menyimpan setoran: ' . $e->getMessage(),
        ]);
    }
    exit;
}

// ════════════════════════════════════════════════════
// DELETE: Hapus setoran
// Query param: id=<setoran_id> OR group_id=<group_id>
// ════════════════════════════════════════════════════
if ($_SERVER['REQUEST_METHOD'] === 'DELETE') {
    if (!in_array($user['role'], ['guru_kelas', 'guru_tahfidz'])) {
        http_response_code(403);
        echo json_encode(['success' => false, 'message' => 'Akses ditolak']);
        exit;
    }

    $noteId  = $_GET['id'] ?? null;
    $groupId = $_GET['group_id'] ?? null;

    if (!$noteId && !$groupId) {
        http_response_code(400);
        echo json_encode(['success' => false, 'message' => 'Parameter id atau group_id diperlukan']);
        exit;
    }

    try {
        // Collect rows to delete
        if ($groupId) {
            $check = $pdo->prepare('SELECT id, student_id, points_earned, group_id FROM tahfidz_setoran WHERE group_id = :gid');
            $check->execute(['gid' => $groupId]);
        } else {
            // Check if this row has a group_id — if so, delete all in group
            $check = $pdo->prepare('SELECT id, student_id, points_earned, group_id FROM tahfidz_setoran WHERE id = :id');
            $check->execute(['id' => $noteId]);
        }
        $rows = $check->fetchAll();

        if (empty($rows)) {
            http_response_code(404);
            echo json_encode(['success' => false, 'message' => 'Setoran tidak ditemukan']);
            exit;
        }

        // If the first row has a group_id and we queried by id, get all group rows
        $firstRow = $rows[0];
        if (!$groupId && $firstRow['group_id']) {
            $check2 = $pdo->prepare('SELECT id, student_id, points_earned, group_id FROM tahfidz_setoran WHERE group_id = :gid');
            $check2->execute(['gid' => $firstRow['group_id']]);
            $rows = $check2->fetchAll();
        }

        $studentId    = (int) $firstRow['student_id'];
        $totalEarned  = 0;

        $pdo->beginTransaction();

        foreach ($rows as $row) {
            $totalEarned += (int) $row['points_earned'];
            $pdo->prepare('DELETE FROM tahfidz_setoran WHERE id = :id')->execute(['id' => $row['id']]);
        }

        recalcTotalPoints($pdo, $studentId);

        if ($totalEarned > 0) {
            $pdo->prepare(
                'INSERT INTO points_log (student_id, source, source_id, points, description)
                 VALUES (:sid, :src, :srcid, :pts, :desc)'
            )->execute([
                'sid'   => $studentId,
                'src'   => 'tahfidz',
                'srcid' => $firstRow['id'],
                'pts'   => -$totalEarned,
                'desc'  => 'Hapus setoran oleh guru',
            ]);
        }

        $pdo->commit();
        echo json_encode(['success' => true, 'message' => 'Setoran dihapus']);
    } catch (Exception $e) {
        if ($pdo->inTransaction()) $pdo->rollBack();
        http_response_code(500);
        echo json_encode(['success' => false, 'message' => 'Gagal menghapus setoran']);
    }
    exit;
}

http_response_code(405);
echo json_encode(['success' => false, 'message' => 'Method tidak didukung']);
