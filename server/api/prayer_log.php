<?php
// /server/api/prayer_log.php
// Endpoint untuk CRUD log shalat siswa + tracking lokasi GPS
// Method: GET  -> ambil data shalat (by date / range)
// Method: POST -> simpan/update rekap shalat + hitung poin & streak

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

// ── Ambil token dari header ──
$token = getBearerToken();

// ════════════════════════════════════════
// GET: Ambil data shalat
// Query params: date=YYYY-MM-DD (opsional, default hari ini)
//               month=YYYY-MM (opsional, untuk kalender bulanan)
// ════════════════════════════════════════
if ($_SERVER['REQUEST_METHOD'] === 'GET') {
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

    try {
        // Mode 1: Ambil shalat per tanggal tertentu
        if (isset($_GET['date'])) {
            $date = $_GET['date'];
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

            // Ambil daily_extras untuk tanggal ini
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
                    'total_points' => (int) $student['total_points'],
                    'streak'       => (int) $student['streak'],
                    'wake_up_time' => $extras ? $extras['wake_up_time'] : null,
                    'deeds'        => $extras && $extras['deeds'] ? json_decode($extras['deeds'], true) : [],
                ],
            ]);
            exit;
        }

        // Mode 2: Ambil summary shalat sebulan (untuk kalender)
        if (isset($_GET['month'])) {
            $month = $_GET['month']; // YYYY-MM
            $stmt = $pdo->prepare(
                "SELECT prayer_date, COUNT(*) AS done_count
                 FROM prayer_logs
                 WHERE student_id = :sid
                   AND prayer_date LIKE :m
                   AND prayer_name IN ('Subuh','Dzuhur','Ashar','Maghrib','Isya')
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
                    'total_points' => (int) $student['total_points'],
                    'streak'       => (int) $student['streak'],
                ],
            ]);
            exit;
        }

        // Default: hari ini
        $today = date('Y-m-d');
        $stmt = $pdo->prepare(
            'SELECT prayer_name, status, points_earned, latitude, longitude, location_name
             FROM prayer_logs
             WHERE student_id = :sid AND prayer_date = :d'
        );
        $stmt->execute(['sid' => $studentId, 'd' => $today]);
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

        // Ambil daily_extras untuk hari ini
        $extrasStmt = $pdo->prepare(
            'SELECT wake_up_time, deeds FROM daily_extras WHERE student_id = :sid AND log_date = :d'
        );
        $extrasStmt->execute(['sid' => $studentId, 'd' => $today]);
        $extras = $extrasStmt->fetch();

        echo json_encode([
            'success' => true,
            'data'    => [
                'date'         => $today,
                'prayers'      => $prayers,
                'total_points' => (int) $student['total_points'],
                'streak'       => (int) $student['streak'],
                'wake_up_time' => $extras ? $extras['wake_up_time'] : null,
                'deeds'        => $extras && $extras['deeds'] ? json_decode($extras['deeds'], true) : [],
            ],
        ]);
    } catch (PDOException $e) {
        http_response_code(500);
        echo json_encode(['success' => false, 'message' => 'Kesalahan server', 'debug' => $e->getMessage()]);
    }
    exit;
}

// ════════════════════════════════════════
// POST: Simpan / update rekap shalat
// Body JSON:
// {
//   "date": "2026-02-15",
//   "prayers": {
//     "Subuh":   { "status": "done_jamaah", "latitude": -6.xxx, "longitude": 106.xxx, "location_name": "Masjid Al-Ikhlas" },
//     "Dzuhur":  { "status": "done", "latitude": ..., "longitude": ... },
//     ...
//   }
// }
// ════════════════════════════════════════
if ($_SERVER['REQUEST_METHOD'] === 'POST') {
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

    $input = json_decode(file_get_contents('php://input'), true);
    if (!$input || !isset($input['prayers'])) {
        http_response_code(400);
        echo json_encode(['success' => false, 'message' => 'Data shalat diperlukan']);
        exit;
    }

    $studentId = $student['student_id'];
    $date      = $input['date'] ?? date('Y-m-d');
    $prayers   = $input['prayers'];
    $wakeUpTime = $input['wake_up_time'] ?? null;
    $deeds      = $input['deeds'] ?? [];

    $validPrayers  = ['Subuh', 'Dzuhur', 'Ashar', 'Maghrib', 'Isya'];
    $validStatuses = ['done', 'done_jamaah', 'missed'];

    // Poin per shalat
    $pointsMap = [
        'done'        => 1,
        'done_jamaah' => 2,
        'missed'      => 0,
    ];

    try {
        $pdo->beginTransaction();

        // ── Ambil poin LAMA untuk tanggal ini (sebelum update) ──
        $stmt = $pdo->prepare(
            'SELECT COALESCE(SUM(points_earned), 0) AS old_points
             FROM prayer_logs
             WHERE student_id = :sid AND prayer_date = :d'
        );
        $stmt->execute(['sid' => $studentId, 'd' => $date]);
        $oldDayPoints = (int) $stmt->fetchColumn();

        // Cek apakah sudah pernah dapat bonus 5/5 hari ini
        $stmt = $pdo->prepare(
            "SELECT COUNT(*) FROM prayer_logs
             WHERE student_id = :sid AND prayer_date = :d
               AND status IN ('done','done_jamaah')"
        );
        $stmt->execute(['sid' => $studentId, 'd' => $date]);
        $oldDoneCount = (int) $stmt->fetchColumn();

        $totalEarnedPoints = 0;
        $doneCount = 0;

        foreach ($prayers as $prayerName => $prayerData) {
            if (!in_array($prayerName, $validPrayers)) continue;

            $status = $prayerData['status'] ?? 'missed';
            if (!in_array($status, $validStatuses)) $status = 'missed';

            $lat          = isset($prayerData['latitude']) ? (float) $prayerData['latitude'] : null;
            $lng          = isset($prayerData['longitude']) ? (float) $prayerData['longitude'] : null;
            $locationName = $prayerData['location_name'] ?? null;
            $pointsEarned = $pointsMap[$status] ?? 0;

            if ($status === 'done' || $status === 'done_jamaah') {
                $doneCount++;
            }

            // UPSERT: insert atau update jika sudah ada
            $stmt = $pdo->prepare(
                'INSERT INTO prayer_logs (student_id, prayer_date, prayer_name, status, points_earned, latitude, longitude, location_name)
                 VALUES (:sid, :d, :pn, :st, :pts, :lat, :lng, :loc)
                 ON DUPLICATE KEY UPDATE
                    status = VALUES(status),
                    points_earned = VALUES(points_earned),
                    latitude = VALUES(latitude),
                    longitude = VALUES(longitude),
                    location_name = VALUES(location_name)'
            );
            $stmt->execute([
                'sid' => $studentId,
                'd'   => $date,
                'pn'  => $prayerName,
                'st'  => $status,
                'pts' => $pointsEarned,
                'lat' => $lat,
                'lng' => $lng,
                'loc' => $locationName,
            ]);

            $totalEarnedPoints += $pointsEarned;
        }

        // Bonus 3 poin jika semua 5 shalat done
        $bonusToday = 0;
        if ($doneCount >= 5) {
            $bonusToday = 3;
        }

        // ── Hitung selisih poin (delta) ──
        $oldBonusToday = ($oldDoneCount >= 5) ? 3 : 0;
        // Delta poin shalat saja (tanpa bonus)
        $deltaPrayerPoints = $totalEarnedPoints - $oldDayPoints;
        // Delta bonus
        $deltaBonusPoints = $bonusToday - $oldBonusToday;
        // Total delta
        $deltaPoints = $deltaPrayerPoints + $deltaBonusPoints;

        // ── Hitung ulang total poin dari semua prayer_logs ──
        $stmt = $pdo->prepare(
            'SELECT COALESCE(SUM(points_earned), 0) AS total
             FROM prayer_logs WHERE student_id = :sid'
        );
        $stmt->execute(['sid' => $studentId]);
        $totalAllPoints = (int) $stmt->fetchColumn();

        // Tambah bonus hari-hari yang 5/5 (hitung dari semua tanggal)
        $stmt = $pdo->prepare(
            "SELECT COUNT(*) AS full_days FROM (
                SELECT prayer_date
                FROM prayer_logs
                WHERE student_id = :sid AND status IN ('done','done_jamaah')
                GROUP BY prayer_date
                HAVING COUNT(*) >= 5
            ) AS fd"
        );
        $stmt->execute(['sid' => $studentId]);
        $fullDays = (int) $stmt->fetchColumn();
        $totalAllPoints += ($fullDays * 3);

        // ── Hitung streak ──
        $streak = calculateStreak($pdo, $studentId, $date);

        // ── Update student record (streak only, total_points updated after extras) ──
        $stmt = $pdo->prepare(
            'UPDATE students
             SET streak = :streak,
                 last_active_date = :lad
             WHERE id = :sid'
        );
        $stmt->execute([
            'streak' => $streak,
            'lad'    => $date,
            'sid'    => $studentId,
        ]);

        // ── Catat ke points_log (UPSERT per tanggal, tidak duplikat) ──
        $newDayPoints = $totalEarnedPoints + $bonusToday;
        if ($newDayPoints > 0) {
            // Hapus log lama untuk tanggal+sumber ini, lalu insert baru
            $stmt = $pdo->prepare(
                "DELETE FROM points_log
                 WHERE student_id = :sid AND source = 'shalat'
                   AND description LIKE :datePattern"
            );
            $stmt->execute([
                'sid'         => $studentId,
                'datePattern' => "Rekap shalat $date%",
            ]);

            $stmt = $pdo->prepare(
                'INSERT INTO points_log (student_id, source, points, description)
                 VALUES (:sid, :src, :pts, :desc)'
            );
            $stmt->execute([
                'sid'  => $studentId,
                'src'  => 'shalat',
                'pts'  => $newDayPoints,
                'desc' => "Rekap shalat $date ($doneCount/5 shalat)",
            ]);
        }

        // ══════════════════════════════════
        // ── EXTRAS: Wake-up time & Deeds ──
        // ══════════════════════════════════
        $wakeUpPoints = 0;
        $deedsPoints = 0;
        $comboBonus = 0;
        $deltaExtras = 0;

        // Ambil extras lama (detail per field untuk delta)
        $stmt = $pdo->prepare(
            'SELECT wake_up_points, deeds_points, combo_bonus, total_extra_points FROM daily_extras
             WHERE student_id = :sid AND log_date = :d'
        );
        $stmt->execute(['sid' => $studentId, 'd' => $date]);
        $oldExtras = $stmt->fetch();
        $oldExtraPoints = $oldExtras ? (int) $oldExtras['total_extra_points'] : 0;
        $oldWakeUpPoints = $oldExtras ? (int) $oldExtras['wake_up_points'] : 0;
        $oldDeedsPoints = $oldExtras ? (int) $oldExtras['deeds_points'] : 0;
        $oldComboBonus = $oldExtras ? (int) $oldExtras['combo_bonus'] : 0;

        // Hitung poin wake-up
        if ($wakeUpTime === '03:00' || $wakeUpTime === '04:00') {
            $wakeUpPoints = 1;
        }

        // Hitung poin deeds
        if (is_array($deeds)) {
            $deedsPoints = count($deeds);
        }

        // Combo bonus: +3 jika keduanya terisi
        if ($wakeUpPoints > 0 && $deedsPoints > 0) {
            $comboBonus = 3;
        }

        $totalExtraPoints = $wakeUpPoints + $deedsPoints + $comboBonus;
        $deltaExtras = $totalExtraPoints - $oldExtraPoints;

        // Delta per komponen extras
        $deltaWakeUp = $wakeUpPoints - $oldWakeUpPoints;
        $deltaDeeds = $deedsPoints - $oldDeedsPoints;
        $deltaCombo = $comboBonus - $oldComboBonus;

        // UPSERT daily_extras (selalu jalankan agar bisa clear data)
        if ($wakeUpTime !== null || !empty($deeds)) {
            // Ada data extras — upsert
            $deedsJson = json_encode(is_array($deeds) ? $deeds : []);
            $stmt = $pdo->prepare(
                'INSERT INTO daily_extras (student_id, log_date, wake_up_time, wake_up_points, deeds, deeds_points, combo_bonus, total_extra_points)
                 VALUES (:sid, :d, :wt, :wp, :dj, :dp, :cb, :tp)
                 ON DUPLICATE KEY UPDATE
                    wake_up_time = VALUES(wake_up_time),
                    wake_up_points = VALUES(wake_up_points),
                    deeds = VALUES(deeds),
                    deeds_points = VALUES(deeds_points),
                    combo_bonus = VALUES(combo_bonus),
                    total_extra_points = VALUES(total_extra_points)'
            );
            $stmt->execute([
                'sid' => $studentId,
                'd'   => $date,
                'wt'  => $wakeUpTime,
                'wp'  => $wakeUpPoints,
                'dj'  => $deedsJson,
                'dp'  => $deedsPoints,
                'cb'  => $comboBonus,
                'tp'  => $totalExtraPoints,
            ]);

            // Catat ke points_log
            // Hapus log lama dulu
            $stmt = $pdo->prepare(
                "DELETE FROM points_log
                 WHERE student_id = :sid AND source = 'extras'
                   AND description LIKE :datePattern"
            );
            $stmt->execute([
                'sid'         => $studentId,
                'datePattern' => "Extras $date%",
            ]);

            if ($totalExtraPoints > 0) {
                $stmt = $pdo->prepare(
                    'INSERT INTO points_log (student_id, source, points, description)
                     VALUES (:sid, :src, :pts, :desc)'
                );
                $extrasDesc = "Extras $date";
                if ($wakeUpPoints > 0) $extrasDesc .= " bangun $wakeUpTime";
                if ($deedsPoints > 0) $extrasDesc .= " $deedsPoints kebaikan";
                if ($comboBonus > 0) $extrasDesc .= " +bonus";
                $stmt->execute([
                    'sid'  => $studentId,
                    'src'  => 'extras',
                    'pts'  => $totalExtraPoints,
                    'desc' => $extrasDesc,
                ]);
            }
        } else if ($oldExtras) {
            // User cleared semua extras — hapus row dan points_log
            $stmt = $pdo->prepare(
                'DELETE FROM daily_extras WHERE student_id = :sid AND log_date = :d'
            );
            $stmt->execute(['sid' => $studentId, 'd' => $date]);

            $stmt = $pdo->prepare(
                "DELETE FROM points_log
                 WHERE student_id = :sid AND source = 'extras'
                   AND description LIKE :datePattern"
            );
            $stmt->execute([
                'sid'         => $studentId,
                'datePattern' => "Extras $date%",
            ]);
        }

        // ── Hitung ulang total semua poin (shalat + extras + public_speaking) ──
        $stmt = $pdo->prepare(
            'SELECT COALESCE(SUM(points_earned), 0) FROM prayer_logs WHERE student_id = :sid'
        );
        $stmt->execute(['sid' => $studentId]);
        $grandTotal = (int) $stmt->fetchColumn();
        $grandTotal += ($fullDays * 3); // bonus 5/5

        $stmt = $pdo->prepare(
            'SELECT COALESCE(SUM(total_extra_points), 0) FROM daily_extras WHERE student_id = :sid'
        );
        $stmt->execute(['sid' => $studentId]);
        $grandTotal += (int) $stmt->fetchColumn();

        // Tambah poin public speaking
        $stmt = $pdo->prepare(
            'SELECT COALESCE(SUM(points_earned), 0) FROM public_speaking_logs WHERE student_id = :sid'
        );
        $stmt->execute(['sid' => $studentId]);
        $grandTotal += (int) $stmt->fetchColumn();

        // Tambah poin diskusi/kajian
        $stmt = $pdo->prepare(
            'SELECT COALESCE(SUM(points_earned), 0) FROM kajian_logs WHERE student_id = :sid'
        );
        $stmt->execute(['sid' => $studentId]);
        $grandTotal += (int) $stmt->fetchColumn();

        // Update student total_points with grand total
        $stmt = $pdo->prepare('UPDATE students SET total_points = :tp WHERE id = :sid');
        $stmt->execute(['tp' => $grandTotal, 'sid' => $studentId]);

        $pdo->commit();

        echo json_encode([
            'success' => true,
            'message' => 'Rekap shalat berhasil disimpan',
            'data'    => [
                'date'           => $date,
                'done_count'     => $doneCount,
                'earned_points'  => max(0, $deltaPrayerPoints) + max(0, $deltaBonusPoints) + max(0, $deltaWakeUp) + max(0, $deltaDeeds) + max(0, $deltaCombo),
                'bonus_points'   => max(0, $deltaBonusPoints),
                'wake_up_points' => max(0, $deltaWakeUp),
                'deeds_points'   => max(0, $deltaDeeds),
                'combo_bonus'    => max(0, $deltaCombo),
                'total_points'   => $grandTotal,
                'streak'         => $streak,
            ],
        ]);

    } catch (PDOException $e) {
        $pdo->rollBack();
        http_response_code(500);
        echo json_encode([
            'success' => false,
            'message' => 'Gagal menyimpan rekap shalat',
            'debug'   => $e->getMessage(),
        ]);
    }
    exit;
}

// Method tidak diizinkan
http_response_code(405);
echo json_encode(['success' => false, 'message' => 'Method not allowed']);

// ════════════════════════════════════════
// Helper: Hitung streak shalat
// Streak = hari berturut-turut di mana siswa shalat minimal 1x
// ════════════════════════════════════════
function calculateStreak(PDO $pdo, int $studentId, string $currentDate): int {
    // Ambil semua tanggal yang memiliki shalat done, urut desc
    $stmt = $pdo->prepare(
        "SELECT DISTINCT prayer_date
         FROM prayer_logs
         WHERE student_id = :sid
           AND status IN ('done', 'done_jamaah')
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
