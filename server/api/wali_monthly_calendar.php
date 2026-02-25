<?php
// /server/api/wali_monthly_calendar.php
// Endpoint untuk rekap kalender bulanan shalat siswa (untuk wali/orang tua)
// Method: GET
// Params:
//   ?student_id=X          (wajib — ID siswa yang akan ditampilkan)
//   ?month=YYYY-MM         (opsional, default bulan berjalan)
//   ?day_detail=YYYY-MM-DD (opsional — jika diisi, kembalikan detail hari tsb)
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

// ── Validasi token ──
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

// ── Pastikan user = orang_tua ──
$stmtUser = $pdo->prepare('SELECT id, role FROM users WHERE id = :uid');
$stmtUser->execute(['uid' => $userId]);
$user = $stmtUser->fetch();

if (!$user || $user['role'] !== 'orang_tua') {
    http_response_code(403);
    echo json_encode(['success' => false, 'message' => 'Akses hanya untuk orang tua']);
    exit;
}

// ── Ambil student_id & validasi kepemilikan ──
$studentId = isset($_GET['student_id']) ? (int) $_GET['student_id'] : 0;
if ($studentId <= 0) {
    http_response_code(400);
    echo json_encode(['success' => false, 'message' => 'student_id wajib diisi']);
    exit;
}

// Pastikan siswa ini milik orang tua yang login (multi-akun safe)
$stmtOwner = $pdo->prepare(
    'SELECT ps.student_id
     FROM parent_student ps
     WHERE ps.parent_id = :uid AND ps.student_id = :sid
     LIMIT 1'
);
$stmtOwner->execute(['uid' => $userId, 'sid' => $studentId]);
if (!$stmtOwner->fetch()) {
    http_response_code(403);
    echo json_encode(['success' => false, 'message' => 'Siswa bukan milik akun Anda']);
    exit;
}

try {

    // ═══════════════════════════════════════════════
    // CASE A: Detail satu hari (day_detail diisi)
    // ═══════════════════════════════════════════════
    if (!empty($_GET['day_detail'])) {
        $date = $_GET['day_detail'];

        // Validasi format tanggal
        if (!preg_match('/^\d{4}-\d{2}-\d{2}$/', $date)) {
            http_response_code(400);
            echo json_encode(['success' => false, 'message' => 'Format tanggal tidak valid (YYYY-MM-DD)']);
            exit;
        }

        // 1. Ambil prayer_logs hari itu
        $stmtPrayers = $pdo->prepare(
            'SELECT prayer_name, status, points_earned
             FROM prayer_logs
             WHERE student_id = :sid AND prayer_date = :d
             ORDER BY FIELD(prayer_name, "Subuh", "Dzuhur", "Ashar", "Maghrib", "Isya")'
        );
        $stmtPrayers->execute(['sid' => $studentId, 'd' => $date]);
        $prayerRows = $stmtPrayers->fetchAll();

        // Map ke 5 waktu — dengan cek jadwal shalat Sukoharjo
        $prayerDeadlines = [
            'Subuh'   => '05:30',
            'Dzuhur'  => '14:30',
            'Ashar'   => '17:30',
            'Maghrib' => '18:45',
            'Isya'    => '23:59',
        ];
        $currentTime = date('H:i');
        $isToday = ($date === date('Y-m-d'));

        $prayerNames = ['Subuh', 'Dzuhur', 'Ashar', 'Maghrib', 'Isya'];
        $prayerMap = [];
        foreach ($prayerNames as $pn) {
            if (!$isToday) {
                // Hari lampau: default missed
                $prayerMap[$pn] = ['status' => 'missed', 'points' => 0];
            } elseif ($currentTime > $prayerDeadlines[$pn]) {
                // Hari ini tapi sudah lewat deadline
                $prayerMap[$pn] = ['status' => 'missed', 'points' => 0];
            } else {
                // Belum lewat waktu
                $prayerMap[$pn] = ['status' => 'upcoming', 'points' => 0];
            }
        }
        foreach ($prayerRows as $p) {
            $prayerMap[$p['prayer_name']] = [
                'status' => $p['status'],
                'points' => (int) $p['points_earned'],
            ];
        }

        $prayers = [];
        foreach ($prayerMap as $name => $data) {
            $prayers[] = [
                'name'   => $name,
                'status' => $data['status'],
                'points' => $data['points'],
            ];
        }

        // 2. Ambil daily_extras hari itu
        $stmtExtras = $pdo->prepare(
            'SELECT wake_up_time, wake_up_points, deeds, deeds_points,
                    combo_bonus, total_extra_points
             FROM daily_extras
             WHERE student_id = :sid AND log_date = :d
             LIMIT 1'
        );
        $stmtExtras->execute(['sid' => $studentId, 'd' => $date]);
        $extras = $stmtExtras->fetch();

        $dayExtras = null;
        if ($extras) {
            $dayExtras = [
                'wake_up_time'       => $extras['wake_up_time'],
                'wake_up_points'     => (int) $extras['wake_up_points'],
                'deeds'              => json_decode($extras['deeds'] ?: '[]', true),
                'deeds_points'       => (int) $extras['deeds_points'],
                'combo_bonus'        => (int) $extras['combo_bonus'],
                'total_extra_points' => (int) $extras['total_extra_points'],
            ];
        }

        // Hitung jumlah shalat selesai
        $prayersDone = 0;
        foreach ($prayers as $tp) {
            if (in_array($tp['status'], ['done', 'done_jamaah'])) {
                $prayersDone++;
            }
        }

        echo json_encode([
            'success' => true,
            'data' => [
                'date'         => $date,
                'prayers'      => $prayers,
                'extras'       => $dayExtras,
                'prayers_done' => $prayersDone,
                'prayers_total'=> 5,
                'has_data'     => count($prayerRows) > 0 || $extras !== false,
            ],
        ]);
        exit;
    }

    // ═══════════════════════════════════════════════
    // CASE B: Data heatmap bulanan (default)
    // ═══════════════════════════════════════════════
    $monthParam = isset($_GET['month']) ? $_GET['month'] : date('Y-m');

    // Validasi format bulan
    if (!preg_match('/^\d{4}-\d{2}$/', $monthParam)) {
        http_response_code(400);
        echo json_encode(['success' => false, 'message' => 'Format bulan tidak valid (YYYY-MM)']);
        exit;
    }

    $yearMonth = explode('-', $monthParam);
    $year  = (int) $yearMonth[0];
    $month = (int) $yearMonth[1];

    $startDate = sprintf('%04d-%02d-01', $year, $month);
    $endDate   = date('Y-m-t', strtotime($startDate)); // last day of month

    // Query: hitung jumlah shalat done/done_jamaah per hari
    $stmtHeatmap = $pdo->prepare(
        'SELECT prayer_date,
                SUM(CASE WHEN status IN ("done", "done_jamaah") THEN 1 ELSE 0 END) AS prayer_count
         FROM prayer_logs
         WHERE student_id = :sid
           AND prayer_date BETWEEN :start AND :end
         GROUP BY prayer_date
         ORDER BY prayer_date ASC'
    );
    $stmtHeatmap->execute([
        'sid'   => $studentId,
        'start' => $startDate,
        'end'   => $endDate,
    ]);
    $heatmapRows = $stmtHeatmap->fetchAll();

    // Build day -> count map
    $heatmap = [];
    foreach ($heatmapRows as $row) {
        $heatmap[$row['prayer_date']] = (int) $row['prayer_count'];
    }

    // Stats: hari lengkap (5/5), rata-rata, streak terpanjang bulan ini
    $fullDays     = 0;
    $totalPrayers = 0;
    $daysWithData = 0;

    foreach ($heatmap as $date => $count) {
        $daysWithData++;
        $totalPrayers += $count;
        if ($count >= 5) {
            $fullDays++;
        }
    }

    $avgPrayer = $daysWithData > 0 ? round($totalPrayers / $daysWithData, 1) : 0;

    // Streak bulan ini (hari berturut-turut dengan minimal 1 shalat)
    $daysInMonth = (int) date('t', strtotime($startDate));
    $today = date('Y-m-d');
    $currentStreak = 0;
    $maxStreak     = 0;

    for ($d = 1; $d <= $daysInMonth; $d++) {
        $dateStr = sprintf('%04d-%02d-%02d', $year, $month, $d);
        if ($dateStr > $today) break;

        if (isset($heatmap[$dateStr]) && $heatmap[$dateStr] > 0) {
            $currentStreak++;
            if ($currentStreak > $maxStreak) {
                $maxStreak = $currentStreak;
            }
        } else {
            $currentStreak = 0;
        }
    }

    echo json_encode([
        'success' => true,
        'data' => [
            'month'   => $monthParam,
            'heatmap' => $heatmap,  // { "2026-02-15": 2, "2026-02-17": 5, ... }
            'stats'   => [
                'full_days'     => $fullDays,
                'avg_prayer'    => $avgPrayer,
                'max_streak'    => $maxStreak,
                'days_with_data'=> $daysWithData,
                'total_prayers' => $totalPrayers,
            ],
        ],
    ]);

} catch (PDOException $e) {
    http_response_code(500);
    echo json_encode([
        'success' => false,
        'message' => 'Terjadi kesalahan server',
        'debug'   => $e->getMessage(),
    ]);
}
