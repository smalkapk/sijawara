<?php
// /server/api/wali_dashboard.php
// Endpoint untuk dashboard wali murid (orang tua)
// Method: GET
// Params: ?student_id=X (opsional, default anak pertama)
//         ?date=YYYY-MM-DD (opsional, default hari ini)
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

try {
    // ═══════════════════════════════════════
    // 1. Ambil daftar anak
    // ═══════════════════════════════════════
    $stmtChildren = $pdo->prepare(
        'SELECT ps.relationship, ps.student_id,
                s.nis, s.total_points, s.current_level, s.streak, s.last_active_date,
                u.name AS student_name, u.avatar_url AS student_avatar,
                c.name AS class_name, c.academic_year
         FROM parent_student ps
         JOIN students s ON ps.student_id = s.id
         JOIN users u ON s.user_id = u.id
         LEFT JOIN classes c ON s.class_id = c.id
         WHERE ps.parent_id = :uid
         ORDER BY ps.id ASC'
    );
    $stmtChildren->execute(['uid' => $userId]);
    $children = $stmtChildren->fetchAll();

    if (empty($children)) {
        echo json_encode([
            'success' => true,
            'data' => [
                'parent' => [
                    'name'       => $parentUser['name'],
                    'email'      => $parentUser['email'],
                    'phone'      => $parentUser['phone'],
                    'avatar_url' => $parentUser['avatar_url'],
                ],
                'children'         => [],
                'selected_child'   => null,
                'today_prayers'    => [],
                'today_extras'     => null,
                'today_summary'    => null,
            ],
        ]);
        exit;
    }

    // ═══════════════════════════════════════
    // 2. Tentukan anak yang dipilih
    // ═══════════════════════════════════════
    $requestedStudentId = isset($_GET['student_id']) ? (int) $_GET['student_id'] : 0;
    $selectedChild = null;

    if ($requestedStudentId > 0) {
        foreach ($children as $child) {
            if ((int) $child['student_id'] === $requestedStudentId) {
                $selectedChild = $child;
                break;
            }
        }
    }

    // Jika tidak ditemukan atau tidak di-request, pakai anak pertama
    if (!$selectedChild) {
        $selectedChild = $children[0];
    }

    $studentId = (int) $selectedChild['student_id'];
    $date = isset($_GET['date']) ? $_GET['date'] : date('Y-m-d');

    // ═══════════════════════════════════════
    // 3. Ambil data shalat hari ini
    // ═══════════════════════════════════════
    $stmtPrayers = $pdo->prepare(
        'SELECT prayer_name, status, points_earned
         FROM prayer_logs
         WHERE student_id = :sid AND prayer_date = :d
         ORDER BY FIELD(prayer_name, "Subuh", "Dzuhur", "Ashar", "Maghrib", "Isya")'
    );
    $stmtPrayers->execute(['sid' => $studentId, 'd' => $date]);
    $prayers = $stmtPrayers->fetchAll();

    // Jadwal batas akhir waktu shalat daerah Sukoharjo (WIB)
    // Deadline = batas sebelum masuk waktu shalat berikutnya
    $prayerDeadlines = [
        'Subuh'   => '05:30',  // sebelum matahari terbit
        'Dzuhur'  => '14:30',  // sebelum Ashar
        'Ashar'   => '17:30',  // sebelum Maghrib
        'Maghrib' => '18:45',  // sebelum Isya
        'Isya'    => '23:59',  // akhir hari
    ];
    $currentTime = date('H:i');
    $isToday = ($date === date('Y-m-d'));

    $prayerMap = [];
    $prayerNames = ['Subuh', 'Dzuhur', 'Ashar', 'Maghrib', 'Isya'];
    foreach ($prayerNames as $pn) {
        if (!$isToday) {
            // Hari lampau: semua yang tidak ada data = missed
            $prayerMap[$pn] = ['status' => 'missed', 'points' => 0];
        } elseif ($currentTime > $prayerDeadlines[$pn]) {
            // Hari ini tapi sudah lewat deadline waktu shalat
            $prayerMap[$pn] = ['status' => 'missed', 'points' => 0];
        } else {
            // Belum lewat waktu
            $prayerMap[$pn] = ['status' => 'upcoming', 'points' => 0];
        }
    }
    foreach ($prayers as $p) {
        $prayerMap[$p['prayer_name']] = [
            'status' => $p['status'],
            'points' => (int) $p['points_earned'],
        ];
    }

    $todayPrayers = [];
    foreach ($prayerMap as $name => $data) {
        $todayPrayers[] = [
            'name'   => $name,
            'status' => $data['status'],
            'points' => $data['points'],
        ];
    }

    // ═══════════════════════════════════════
    // 4. Ambil daily_extras hari ini
    // ═══════════════════════════════════════
    $stmtExtras = $pdo->prepare(
        'SELECT wake_up_time, wake_up_points, deeds, deeds_points,
                combo_bonus, total_extra_points
         FROM daily_extras
         WHERE student_id = :sid AND log_date = :d
         LIMIT 1'
    );
    $stmtExtras->execute(['sid' => $studentId, 'd' => $date]);
    $extras = $stmtExtras->fetch();

    $todayExtras = null;
    if ($extras) {
        $todayExtras = [
            'wake_up_time'      => $extras['wake_up_time'],
            'wake_up_points'    => (int) $extras['wake_up_points'],
            'deeds'             => json_decode($extras['deeds'] ?: '[]', true),
            'deeds_points'      => (int) $extras['deeds_points'],
            'combo_bonus'       => (int) $extras['combo_bonus'],
            'total_extra_points'=> (int) $extras['total_extra_points'],
        ];
    }

    // ═══════════════════════════════════════
    // 5. Hitung summary poin hari ini
    // ═══════════════════════════════════════
    $stmtPointsToday = $pdo->prepare(
        'SELECT COALESCE(SUM(points), 0) AS points_today
         FROM points_log
         WHERE student_id = :sid AND DATE(earned_at) = :d'
    );
    $stmtPointsToday->execute(['sid' => $studentId, 'd' => $date]);
    $pointsToday = (int) $stmtPointsToday->fetchColumn();

    $donePrayers = 0;
    foreach ($todayPrayers as $tp) {
        if (in_array($tp['status'], ['done', 'done_jamaah'])) {
            $donePrayers++;
        }
    }

    $todaySummary = [
        'date'            => $date,
        'prayers_done'    => $donePrayers,
        'prayers_total'   => 5,
        'points_today'    => $pointsToday,
        'total_points'    => (int) $selectedChild['total_points'],
        'streak'          => (int) $selectedChild['streak'],
        'current_level'   => (int) $selectedChild['current_level'],
        'last_active_date'=> $selectedChild['last_active_date'],
    ];

    // ═══════════════════════════════════════
    // 6. Ambil badges anak
    // ═══════════════════════════════════════
    $stmtBadges = $pdo->prepare(
        'SELECT b.name, b.description, b.icon, b.gradient_colors, sb.achieved_at
         FROM student_badges sb
         JOIN badges b ON sb.badge_id = b.id
         WHERE sb.student_id = :sid
         ORDER BY sb.achieved_at DESC
         LIMIT 5'
    );
    $stmtBadges->execute(['sid' => $studentId]);
    $badges = $stmtBadges->fetchAll();

    // ═══════════════════════════════════════
    // 7. Kirim response
    // ═══════════════════════════════════════
    echo json_encode([
        'success' => true,
        'data' => [
            'parent' => [
                'name'       => $parentUser['name'],
                'email'      => $parentUser['email'],
                'phone'      => $parentUser['phone'],
                'avatar_url' => $parentUser['avatar_url'],
            ],
            'children' => array_map(function ($c) {
                return [
                    'student_id'    => (int) $c['student_id'],
                    'student_name'  => $c['student_name'],
                    'student_avatar'=> $c['student_avatar'],
                    'nis'           => $c['nis'],
                    'class_name'    => $c['class_name'],
                    'academic_year' => $c['academic_year'],
                    'relationship'  => $c['relationship'],
                    'total_points'  => (int) $c['total_points'],
                    'current_level' => (int) $c['current_level'],
                    'streak'        => (int) $c['streak'],
                ];
            }, $children),
            'selected_child' => [
                'student_id'    => (int) $selectedChild['student_id'],
                'student_name'  => $selectedChild['student_name'],
                'student_avatar'=> $selectedChild['student_avatar'],
                'nis'           => $selectedChild['nis'],
                'class_name'    => $selectedChild['class_name'],
                'academic_year' => $selectedChild['academic_year'],
                'relationship'  => $selectedChild['relationship'],
                'total_points'  => (int) $selectedChild['total_points'],
                'current_level' => (int) $selectedChild['current_level'],
                'streak'        => (int) $selectedChild['streak'],
            ],
            'today_prayers'  => $todayPrayers,
            'today_extras'   => $todayExtras,
            'today_summary'  => $todaySummary,
            'badges'         => $badges,
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
