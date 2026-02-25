<?php
// /server/api/profile.php
// Endpoint lengkap untuk halaman Profil Siswa
// Method: GET
// Header: Authorization: Bearer <token>
//
// Response: profil siswa, poin mingguan, rincian poin, badges (auto-check & award)

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

try {
    // ══════════════════════════════════════
    // 1. DATA PROFIL SISWA
    // ══════════════════════════════════════
    $stmt = $pdo->prepare(
        'SELECT s.id AS student_id, s.nis, s.total_points, s.current_level,
                s.streak, s.last_active_date,
                u.name, u.email, u.phone, u.avatar_url, u.role,
                c.name AS class_name
         FROM students s
         JOIN users u ON s.user_id = u.id
         LEFT JOIN classes c ON s.class_id = c.id
         WHERE s.user_id = :uid
         LIMIT 1'
    );
    $stmt->execute(['uid' => $userId]);
    $student = $stmt->fetch();

    if (!$student) {
        http_response_code(404);
        echo json_encode(['success' => false, 'message' => 'Data siswa tidak ditemukan']);
        exit;
    }

    $studentId    = (int) $student['student_id'];
    $totalPoints  = (int) $student['total_points'];
    $currentLevel = (int) $student['current_level'];
    $streak       = (int) $student['streak'];

    // Hitung level & points_for_next_level
    // Formula: level N membutuhkan N * 300 poin kumulatif
    // Misal level 1 = 300, level 2 = 600, dst.
    $pointsForNextLevel = ($currentLevel + 1) * 300;

    // Nama sekolah (bisa dari config, hardcode dulu)
    $schoolName = 'SMA Muhammadiyah Al Kautsar Program Khusus';

    // ══════════════════════════════════════
    // 2. POIN MINGGUAN (7 hari terakhir)
    // ══════════════════════════════════════
    $weeklyPoints = [];
    $dayLabels    = [];

    for ($i = 6; $i >= 0; $i--) {
        $date = date('Y-m-d', strtotime("-{$i} days"));
        $dayOfWeek = (int) date('w', strtotime($date)); // 0=Sun, 1=Mon, ...
        $labelMap = ['Min', 'Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab'];

        // Total poin di tanggal itu dari points_log
        $stmt = $pdo->prepare(
            "SELECT COALESCE(SUM(points), 0) AS day_points
             FROM points_log
             WHERE student_id = :sid
               AND DATE(earned_at) = :d"
        );
        $stmt->execute(['sid' => $studentId, 'd' => $date]);
        $dayPoints = (int) $stmt->fetchColumn();

        // Tambahkan poin dari daily_extras jika ada
        $stmt = $pdo->prepare(
            "SELECT COALESCE(SUM(total_extra_points), 0)
             FROM daily_extras
             WHERE student_id = :sid AND log_date = :d"
        );
        $stmt->execute(['sid' => $studentId, 'd' => $date]);
        $dayPoints += (int) $stmt->fetchColumn();

        $weeklyPoints[] = $dayPoints;
        $dayLabels[]    = $labelMap[$dayOfWeek];
    }

    // ══════════════════════════════════════
    // 3. RINCIAN POIN PER SUMBER
    // ══════════════════════════════════════
    $sources = [
        'shalat'          => ['label' => 'Shalat',          'icon' => 'mosque_rounded',                'color' => '#059669'],
        'quran'           => ['label' => "Al-Qur'an",       'icon' => 'menu_book_rounded',             'color' => '#0D9488'],
        'tahfidz'         => ['label' => 'Tahfidz',         'icon' => 'menu_book_rounded',             'color' => '#0891B2'],
        'puasa'           => ['label' => 'Puasa Sunnah',    'icon' => 'favorite_rounded',              'color' => '#EA580C'],
        'sedekah'         => ['label' => 'Sedekah',         'icon' => 'volunteer_activism_rounded',    'color' => '#7C3AED'],
        'public_speaking' => ['label' => 'Public Speaking', 'icon' => 'record_voice_over_rounded',     'color' => '#2563EB'],
        'kajian'          => ['label' => 'Kajian',          'icon' => 'school_rounded',                'color' => '#D97706'],
        'jurnal'          => ['label' => 'Jurnal',          'icon' => 'edit_note_rounded',             'color' => '#DC2626'],
    ];

    $pointsBreakdown = [];
    foreach ($sources as $sourceKey => $info) {
        $stmt = $pdo->prepare(
            "SELECT COALESCE(SUM(points), 0) AS total
             FROM points_log
             WHERE student_id = :sid AND source = :src"
        );
        $stmt->execute(['sid' => $studentId, 'src' => $sourceKey]);
        $srcPoints = (int) $stmt->fetchColumn();

        if ($srcPoints > 0) {
            $pointsBreakdown[] = [
                'source' => $sourceKey,
                'label'  => $info['label'],
                'icon'   => $info['icon'],
                'color'  => $info['color'],
                'points' => $srcPoints,
            ];
        }
    }

    // Tambahkan poin dari bonus (daily_extras: bangun pagi, kebaikan, combo)
    $stmt = $pdo->prepare(
        "SELECT COALESCE(SUM(wake_up_points), 0) AS wake,
                COALESCE(SUM(deeds_points), 0) AS deeds,
                COALESCE(SUM(combo_bonus), 0) AS combo
         FROM daily_extras
         WHERE student_id = :sid"
    );
    $stmt->execute(['sid' => $studentId]);
    $extras = $stmt->fetch();

    $wakeUp = (int) ($extras['wake'] ?? 0);
    $deeds  = (int) ($extras['deeds'] ?? 0);
    $combo  = (int) ($extras['combo'] ?? 0);

    if ($wakeUp > 0) {
        $pointsBreakdown[] = [
            'source' => 'bangun_pagi',
            'label'  => 'Bangun Pagi',
            'icon'   => 'wb_sunny_rounded',
            'color'  => '#F59E0B',
            'points' => $wakeUp,
        ];
    }
    if ($deeds > 0) {
        $pointsBreakdown[] = [
            'source' => 'kebaikan',
            'label'  => 'Kebaikan Harian',
            'icon'   => 'volunteer_activism_rounded',
            'color'  => '#10B981',
            'points' => $deeds,
        ];
    }
    if ($combo > 0) {
        $pointsBreakdown[] = [
            'source' => 'combo_bonus',
            'label'  => 'Combo Bonus',
            'icon'   => 'bolt_rounded',
            'color'  => '#EF4444',
            'points' => $combo,
        ];
    }

    // Sort by points descending
    usort($pointsBreakdown, function($a, $b) {
        return $b['points'] - $a['points'];
    });

    // ══════════════════════════════════════
    // 4. BADGES - Auto-check & Award
    // ══════════════════════════════════════

    // Ambil semua badge definition
    $allBadges = $pdo->query('SELECT * FROM badges ORDER BY id ASC')->fetchAll();

    // Ambil badge yg sudah dimiliki
    $stmt = $pdo->prepare(
        'SELECT badge_id, achieved_at FROM student_badges WHERE student_id = :sid'
    );
    $stmt->execute(['sid' => $studentId]);
    $achievedMap = [];
    foreach ($stmt->fetchAll() as $row) {
        $achievedMap[(int) $row['badge_id']] = $row['achieved_at'];
    }

    // Pre-compute stats untuk pengecekan badge
    // Shalat full days (5/5)
    $stmt = $pdo->prepare(
        "SELECT COUNT(*) FROM (
            SELECT prayer_date FROM prayer_logs
            WHERE student_id = :sid AND status IN ('done','done_jamaah')
            GROUP BY prayer_date
            HAVING COUNT(DISTINCT prayer_name) >= 5
        ) AS t"
    );
    $stmt->execute(['sid' => $studentId]);
    $shalatFullDays = (int) $stmt->fetchColumn();

    // Distinct surah count
    $stmt = $pdo->prepare(
        "SELECT COUNT(DISTINCT surah_number) FROM quran_reading_logs WHERE student_id = :sid"
    );
    $stmt->execute(['sid' => $studentId]);
    $quranSurahCount = (int) $stmt->fetchColumn();

    // Fasting count
    $stmt = $pdo->prepare(
        "SELECT COUNT(*) FROM fasting_logs WHERE student_id = :sid"
    );
    $stmt->execute(['sid' => $studentId]);
    $fastingCount = (int) $stmt->fetchColumn();

    // Charity count
    $stmt = $pdo->prepare(
        "SELECT COUNT(*) FROM charity_logs WHERE student_id = :sid"
    );
    $stmt->execute(['sid' => $studentId]);
    $charityCount = (int) $stmt->fetchColumn();

    // Check & award badges
    $newBadges = [];
    foreach ($allBadges as $badge) {
        $badgeId = (int) $badge['id'];
        if (isset($achievedMap[$badgeId])) continue; // sudah punya

        $achieved = false;
        $type  = $badge['requirement_type'];
        $value = (int) $badge['requirement_value'];

        switch ($type) {
            case 'streak':
                $achieved = $streak >= $value;
                break;
            case 'points':
                $achieved = $totalPoints >= $value;
                break;
            case 'level':
                $achieved = $currentLevel >= $value;
                break;
            case 'shalat_full_days':
                $achieved = $shalatFullDays >= $value;
                break;
            case 'quran_surah_count':
                $achieved = $quranSurahCount >= $value;
                break;
            case 'fasting_count':
                $achieved = $fastingCount >= $value;
                break;
            case 'charity_count':
                $achieved = $charityCount >= $value;
                break;
        }

        if ($achieved) {
            // Award badge
            $stmt = $pdo->prepare(
                'INSERT IGNORE INTO student_badges (student_id, badge_id) VALUES (:sid, :bid)'
            );
            $stmt->execute(['sid' => $studentId, 'bid' => $badgeId]);
            $achievedMap[$badgeId] = date('Y-m-d H:i:s');
            $newBadges[] = $badge['name'];
        }
    }

    // Build badges response
    $badgesResponse = [];
    foreach ($allBadges as $badge) {
        $badgeId = (int) $badge['id'];
        $badgesResponse[] = [
            'id'              => $badgeId,
            'name'            => $badge['name'],
            'description'     => $badge['description'],
            'icon'            => $badge['icon'],
            'requirement_type'  => $badge['requirement_type'],
            'requirement_value' => (int) $badge['requirement_value'],
            'gradient_colors' => $badge['gradient_colors'],
            'is_achieved'     => isset($achievedMap[$badgeId]),
            'achieved_at'     => $achievedMap[$badgeId] ?? null,
        ];
    }

    // ══════════════════════════════════════
    // 5. TRACKING STATS (ringkasan)
    // ══════════════════════════════════════
    $trackingStats = [
        'shalat_full_days'  => $shalatFullDays,
        'quran_surah_count' => $quranSurahCount,
        'fasting_count'     => $fastingCount,
        'charity_count'     => $charityCount,
    ];

    // ══════════════════════════════════════
    // OUTPUT
    // ══════════════════════════════════════
    echo json_encode([
        'success' => true,
        'data' => [
            'profile' => [
                'student_id'          => $studentId,
                'name'                => $student['name'],
                'email'               => $student['email'],
                'phone'               => $student['phone'],
                'avatar_url'          => $student['avatar_url'],
                'class_name'          => $student['class_name'] ?? '-',
                'school_name'         => $schoolName,
                'total_points'        => $totalPoints,
                'current_level'       => $currentLevel,
                'points_for_next_level' => $pointsForNextLevel,
                'streak'              => $streak,
                'last_active_date'    => $student['last_active_date'],
            ],
            'weekly_points' => $weeklyPoints,
            'day_labels'    => $dayLabels,
            'points_breakdown' => $pointsBreakdown,
            'badges'        => $badgesResponse,
            'new_badges'    => $newBadges, // badge baru yg baru di-award saat ini
            'tracking_stats' => $trackingStats,
        ],
    ]);

} catch (PDOException $e) {
    http_response_code(500);
    echo json_encode([
        'success' => false,
        'message' => 'Kesalahan server',
        'debug'   => $e->getMessage(),
    ]);
}
