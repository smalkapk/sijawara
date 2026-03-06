<?php
// /server/api/guru_ibadah.php
// Endpoint untuk fitur Guru - Monitoring Ibadah siswa
//
// GET    ?action=students                                  -> daftar siswa yang diajar guru
// GET    ?action=month&student_id=X&month=YYYY-MM          -> summary bulanan ibadah siswa
// GET    ?action=day&student_id=X&date=YYYY-MM-DD          -> detail ibadah per hari
// POST                                                      -> guru edit/update ibadah siswa

header('Content-Type: application/json; charset=utf-8');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, POST, OPTIONS');
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

    // ── Month: Summary ibadah bulanan siswa ──
    if ($action === 'month') {
        $studentId = $_GET['student_id'] ?? null;
        $month = $_GET['month'] ?? date('Y-m'); // YYYY-MM

        if (!$studentId) {
            http_response_code(400);
            echo json_encode(['success' => false, 'message' => 'Parameter student_id diperlukan']);
            exit;
        }

        try {
            $stmt = $pdo->prepare(
                "SELECT prayer_date, COUNT(*) AS done_count
                 FROM prayer_logs
                 WHERE student_id = :sid
                   AND prayer_date LIKE :m
                   AND status IN ('done','done_jamaah')
                 GROUP BY prayer_date"
            );
            $stmt->execute(['sid' => $studentId, 'm' => "$month%"]);
            $rows = $stmt->fetchAll();

            $summary = [];
            foreach ($rows as $row) {
                $summary[$row['prayer_date']] = (int) $row['done_count'];
            }

            echo json_encode([
                'success' => true,
                'data'    => [
                    'month'        => $month,
                    'daily_counts' => $summary,
                ],
            ]);
        } catch (Exception $e) {
            http_response_code(500);
            echo json_encode(['success' => false, 'message' => 'Gagal mengambil data bulanan']);
        }
        exit;
    }

    // ── Day: Detail ibadah per hari siswa ──
    if ($action === 'day') {
        $studentId = $_GET['student_id'] ?? null;
        $date = $_GET['date'] ?? date('Y-m-d');

        if (!$studentId) {
            http_response_code(400);
            echo json_encode(['success' => false, 'message' => 'Parameter student_id diperlukan']);
            exit;
        }

        try {
            $stmt = $pdo->prepare(
                'SELECT prayer_name, status, points_earned, latitude, longitude, location_name
                 FROM prayer_logs
                 WHERE student_id = :sid AND prayer_date = :d'
            );
            $stmt->execute(['sid' => $studentId, 'd' => $date]);
            $logs = $stmt->fetchAll();

            $prayers = [];
            foreach ($logs as $log) {
                $prayers[$log['prayer_name']] = [
                    'status'        => $log['status'],
                    'points'        => (int) $log['points_earned'],
                    'latitude'      => $log['latitude'] ? (float) $log['latitude'] : null,
                    'longitude'     => $log['longitude'] ? (float) $log['longitude'] : null,
                    'location_name' => $log['location_name'],
                ];
            }

            // Ambil daily_extras
            $extrasStmt = $pdo->prepare(
                'SELECT wake_up_time, deeds FROM daily_extras WHERE student_id = :sid AND log_date = :d'
            );
            $extrasStmt->execute(['sid' => $studentId, 'd' => $date]);
            $extras = $extrasStmt->fetch();

            echo json_encode([
                'success' => true,
                'data'    => [
                    'date'         => $date,
                    'prayers'      => $prayers,
                    'wake_up_time' => $extras ? $extras['wake_up_time'] : null,
                    'deeds'        => $extras && $extras['deeds'] ? json_decode($extras['deeds'], true) : [],
                ],
            ]);
        } catch (Exception $e) {
            http_response_code(500);
            echo json_encode(['success' => false, 'message' => 'Gagal mengambil data ibadah']);
        }
        exit;
    }

    http_response_code(400);
    echo json_encode(['success' => false, 'message' => 'Action tidak valid']);
    exit;
}

// ════════════════════════════════════════════════════
// POST: Guru update ibadah siswa
// Body JSON: {
//   "student_id": 123,
//   "date": "2026-03-06",
//   "prayers": {
//     "Subuh": { "status": "done" },
//     "Dzuhur": { "status": "done_jamaah" },
//     ...
//   }
// }
// ════════════════════════════════════════════════════
if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $input = json_decode(file_get_contents('php://input'), true);
    if (!$input) {
        http_response_code(400);
        echo json_encode(['success' => false, 'message' => 'Body JSON tidak valid']);
        exit;
    }

    $studentId = $input['student_id'] ?? null;
    $date      = $input['date'] ?? date('Y-m-d');
    $prayers   = $input['prayers'] ?? [];

    if (!$studentId) {
        http_response_code(400);
        echo json_encode(['success' => false, 'message' => 'student_id wajib diisi']);
        exit;
    }

    if (empty($prayers)) {
        http_response_code(400);
        echo json_encode(['success' => false, 'message' => 'Data shalat wajib diisi']);
        exit;
    }

    $validPrayers  = ['Subuh', 'Dzuhur', 'Ashar', 'Maghrib', 'Isya'];
    $validStatuses = ['done', 'done_jamaah', 'missed'];
    $pointsMap = [
        'done'        => 1,
        'done_jamaah' => 2,
        'missed'      => 0,
    ];

    try {
        $pdo->beginTransaction();

        $doneCount = 0;
        $totalEarnedPoints = 0;

        foreach ($prayers as $prayerName => $prayerData) {
            if (!in_array($prayerName, $validPrayers)) continue;

            $status = $prayerData['status'] ?? 'missed';
            if (!in_array($status, $validStatuses)) $status = 'missed';

            $pointsEarned = $pointsMap[$status] ?? 0;

            if ($status === 'done' || $status === 'done_jamaah') {
                $doneCount++;
            }

            $totalEarnedPoints += $pointsEarned;

            // UPSERT
            $stmt = $pdo->prepare(
                'INSERT INTO prayer_logs (student_id, prayer_date, prayer_name, status, points_earned)
                 VALUES (:sid, :d, :pn, :st, :pts)
                 ON DUPLICATE KEY UPDATE
                    status = VALUES(status),
                    points_earned = VALUES(points_earned)'
            );
            $stmt->execute([
                'sid' => $studentId,
                'd'   => $date,
                'pn'  => $prayerName,
                'st'  => $status,
                'pts' => $pointsEarned,
            ]);
        }

        // Bonus 5/5
        $bonusToday = ($doneCount >= 5) ? 3 : 0;

        // ── Hitung ulang total poin dari semua prayer_logs ──
        $stmt = $pdo->prepare(
            'SELECT COALESCE(SUM(points_earned), 0) FROM prayer_logs WHERE student_id = :sid'
        );
        $stmt->execute(['sid' => $studentId]);
        $grandTotal = (int) $stmt->fetchColumn();

        // Bonus 5/5 per hari
        $stmt = $pdo->prepare(
            "SELECT COUNT(*) FROM (
                SELECT prayer_date FROM prayer_logs
                WHERE student_id = :sid AND status IN ('done','done_jamaah')
                GROUP BY prayer_date HAVING COUNT(*) >= 5
            ) AS fd"
        );
        $stmt->execute(['sid' => $studentId]);
        $fullDays = (int) $stmt->fetchColumn();
        $grandTotal += ($fullDays * 3);

        // Extras
        $stmt = $pdo->prepare(
            'SELECT COALESCE(SUM(total_extra_points), 0) FROM daily_extras WHERE student_id = :sid'
        );
        $stmt->execute(['sid' => $studentId]);
        $grandTotal += (int) $stmt->fetchColumn();

        // Public speaking
        $stmt = $pdo->prepare(
            'SELECT COALESCE(SUM(points_earned), 0) FROM public_speaking_logs WHERE student_id = :sid'
        );
        $stmt->execute(['sid' => $studentId]);
        $grandTotal += (int) $stmt->fetchColumn();

        // Kajian
        $stmt = $pdo->prepare(
            'SELECT COALESCE(SUM(points_earned), 0) FROM kajian_logs WHERE student_id = :sid'
        );
        $stmt->execute(['sid' => $studentId]);
        $grandTotal += (int) $stmt->fetchColumn();

        // Streak
        $streak = calculateStreakForGuru($pdo, $studentId, $date);

        // Update student
        $stmt = $pdo->prepare(
            'UPDATE students SET total_points = :tp, streak = :streak, last_active_date = :lad WHERE id = :sid'
        );
        $stmt->execute([
            'tp'     => $grandTotal,
            'streak' => $streak,
            'lad'    => $date,
            'sid'    => $studentId,
        ]);

        // Points log (UPSERT)
        $newDayPoints = $totalEarnedPoints + $bonusToday;
        if ($newDayPoints > 0) {
            $stmt = $pdo->prepare(
                "DELETE FROM points_log WHERE student_id = :sid AND source = 'shalat' AND description LIKE :dp"
            );
            $stmt->execute(['sid' => $studentId, 'dp' => "Rekap shalat $date%"]);

            $stmt = $pdo->prepare(
                'INSERT INTO points_log (student_id, source, points, description)
                 VALUES (:sid, :src, :pts, :desc)'
            );
            $stmt->execute([
                'sid'  => $studentId,
                'src'  => 'shalat',
                'pts'  => $newDayPoints,
                'desc' => "Rekap shalat $date ($doneCount/5 shalat) [guru:{$guru['name']}]",
            ]);
        }

        $pdo->commit();

        echo json_encode([
            'success' => true,
            'message' => 'Data ibadah siswa berhasil diperbarui',
            'data'    => [
                'date'       => $date,
                'done_count' => $doneCount,
                'total_points' => $grandTotal,
                'streak'     => $streak,
            ],
        ]);
    } catch (Exception $e) {
        $pdo->rollBack();
        http_response_code(500);
        echo json_encode(['success' => false, 'message' => 'Gagal menyimpan data ibadah']);
    }
    exit;
}

http_response_code(405);
echo json_encode(['success' => false, 'message' => 'Method tidak didukung']);

// ════════════════════════════════════════
// Helper: Hitung streak
// ════════════════════════════════════════
function calculateStreakForGuru(PDO $pdo, int $studentId, string $currentDate): int {
    $stmt = $pdo->prepare(
        "SELECT DISTINCT prayer_date
         FROM prayer_logs
         WHERE student_id = :sid AND status IN ('done', 'done_jamaah')
         ORDER BY prayer_date DESC"
    );
    $stmt->execute(['sid' => $studentId]);
    $dates = $stmt->fetchAll(PDO::FETCH_COLUMN);

    if (empty($dates)) return 0;

    $streak = 0;
    $checkDate = new DateTime($currentDate);

    foreach ($dates as $d) {
        $logDate = new DateTime($d);
        if ($logDate->format('Y-m-d') === $checkDate->format('Y-m-d')) {
            $streak++;
            $checkDate->modify('-1 day');
        } else {
            break;
        }
    }

    return $streak;
}
