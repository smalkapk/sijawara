<?php
// /server/api/wali_live_timeline.php
// Endpoint untuk live timeline aktivitas siswa (dilihat oleh wali/orang tua)
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
require_once __DIR__ . '/../config/surah_names.php';

// ═══════════════════════════════════════
// Autentikasi
// ═══════════════════════════════════════
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
$stmtUser = $pdo->prepare('SELECT id, name, role FROM users WHERE id = :uid');
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
                'children'       => [],
                'selected_child' => null,
                'date'           => date('Y-m-d'),
                'timeline'       => [],
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
    if (!$selectedChild) {
        $selectedChild = $children[0];
    }

    $studentId = (int) $selectedChild['student_id'];
    $date = isset($_GET['date']) ? $_GET['date'] : date('Y-m-d');

    // ═══════════════════════════════════════
    // 3. Kumpulkan semua aktivitas ke timeline events
    // ═══════════════════════════════════════
    $events = [];

    // ── 3a. Shalat (prayer_logs) ──
    $stmtPrayers = $pdo->prepare(
        'SELECT prayer_name, status, points_earned, created_at
         FROM prayer_logs
         WHERE student_id = :sid AND prayer_date = :d
         ORDER BY FIELD(prayer_name, "Subuh", "Dzuhur", "Ashar", "Maghrib", "Isya")'
    );
    $stmtPrayers->execute(['sid' => $studentId, 'd' => $date]);
    $prayers = $stmtPrayers->fetchAll();

    foreach ($prayers as $p) {
        if ($p['status'] === 'missed') continue; // Abaikan yang missed

        $statusLabel = $p['status'] === 'done_jamaah' ? 'secara berjamaah' : 'secara mandiri';
        $events[] = [
            'group'       => 'Ibadah',
            'description' => "Melaporkan Shalat {$p['prayer_name']} {$statusLabel}",
            'timestamp'   => $p['created_at'],
            'points'      => (int) $p['points_earned'],
            'type'        => 'shalat',
            'badge'       => $p['status'] === 'done_jamaah' ? 'jamaah' : null,
        ];
    }

    // ── 3b. Puasa (fasting_logs) ──
    $stmtFasting = $pdo->prepare(
        'SELECT fasting_type, points_earned, created_at
         FROM fasting_logs
         WHERE student_id = :sid AND fasting_date = :d'
    );
    $stmtFasting->execute(['sid' => $studentId, 'd' => $date]);
    $fastings = $stmtFasting->fetchAll();

    foreach ($fastings as $f) {
        $type = $f['fasting_type'] ? $f['fasting_type'] : 'Sunnah';
        $events[] = [
            'group'       => 'Ibadah',
            'description' => "Melaporkan Puasa {$type}",
            'timestamp'   => $f['created_at'],
            'points'      => (int) $f['points_earned'],
            'type'        => 'puasa',
            'badge'       => null,
        ];
    }

    // ── 3c. Daily Extras / Kebaikan ──
    $stmtExtras = $pdo->prepare(
        'SELECT wake_up_time, wake_up_points, deeds, deeds_points,
                combo_bonus, total_extra_points, created_at, updated_at
         FROM daily_extras
         WHERE student_id = :sid AND log_date = :d
         LIMIT 1'
    );
    $stmtExtras->execute(['sid' => $studentId, 'd' => $date]);
    $extras = $stmtExtras->fetch();

    if ($extras) {
        // Bangun pagi
        if (!empty($extras['wake_up_time'])) {
            $events[] = [
                'group'       => 'Kebaikan',
                'description' => "Melaporkan Bangun Pagi pukul {$extras['wake_up_time']}",
                'timestamp'   => $extras['created_at'],
                'points'      => (int) $extras['wake_up_points'],
                'type'        => 'bangun_pagi',
                'badge'       => null,
            ];
        }

        // Kebaikan / deeds
        $deeds = json_decode($extras['deeds'] ?: '[]', true);
        if (is_array($deeds) && count($deeds) > 0) {
            foreach ($deeds as $deed) {
                $events[] = [
                    'group'       => 'Kebaikan',
                    'description' => "Melaporkan Kebaikan: {$deed}",
                    'timestamp'   => $extras['updated_at'] ?: $extras['created_at'],
                    'points'      => 1,
                    'type'        => 'kebaikan',
                    'badge'       => null,
                ];
            }
        }

        // Combo bonus
        if ((int) $extras['combo_bonus'] > 0) {
            $events[] = [
                'group'       => 'Kebaikan',
                'description' => "Mendapatkan Bonus Combo (bangun pagi + kebaikan)",
                'timestamp'   => $extras['updated_at'] ?: $extras['created_at'],
                'points'      => (int) $extras['combo_bonus'],
                'type'        => 'combo',
                'badge'       => 'combo',
            ];
        }
    }

    // ── 3d. Sedekah (charity_logs) ──
    $stmtCharity = $pdo->prepare(
        'SELECT description, points_earned, created_at
         FROM charity_logs
         WHERE student_id = :sid AND charity_date = :d
         ORDER BY created_at ASC'
    );
    $stmtCharity->execute(['sid' => $studentId, 'd' => $date]);
    $charities = $stmtCharity->fetchAll();

    foreach ($charities as $ch) {
        $desc = $ch['description'] ? "Melaporkan Kebaikan Sedekah: {$ch['description']}" : 'Melaporkan Kebaikan Sedekah';
        $events[] = [
            'group'       => 'Kebaikan',
            'description' => $desc,
            'timestamp'   => $ch['created_at'],
            'points'      => (int) $ch['points_earned'],
            'type'        => 'sedekah',
            'badge'       => null,
        ];
    }

    // ── 3e. Public Speaking ──
    $stmtSpeaking = $pdo->prepare(
        'SELECT title, materi, mentor, points_earned, created_at
         FROM public_speaking_logs
         WHERE student_id = :sid AND speaking_date = :d
         ORDER BY created_at ASC'
    );
    $stmtSpeaking->execute(['sid' => $studentId, 'd' => $date]);
    $speakings = $stmtSpeaking->fetchAll();

    foreach ($speakings as $sp) {
        $events[] = [
            'group'       => 'Kegiatan',
            'description' => "Mengumpulkan Tugas Public Speaking: {$sp['title']}",
            'timestamp'   => $sp['created_at'],
            'points'      => (int) $sp['points_earned'],
            'type'        => 'public_speaking',
            'badge'       => null,
            'detail'      => $sp['mentor'] ? "Mentor: {$sp['mentor']}" : null,
        ];
    }

    // ── 3f. Kajian / Diskusi ──
    $stmtKajian = $pdo->prepare(
        'SELECT title, mentor, points_earned, created_at
         FROM kajian_logs
         WHERE student_id = :sid AND kajian_date = :d
         ORDER BY created_at ASC'
    );
    $stmtKajian->execute(['sid' => $studentId, 'd' => $date]);
    $kajians = $stmtKajian->fetchAll();

    foreach ($kajians as $kj) {
        $events[] = [
            'group'       => 'Kegiatan',
            'description' => "Mengikuti Kajian: {$kj['title']}",
            'timestamp'   => $kj['created_at'],
            'points'      => (int) $kj['points_earned'],
            'type'        => 'kajian',
            'badge'       => null,
            'detail'      => $kj['mentor'] ? "Mentor: {$kj['mentor']}" : null,
        ];
    }

    // ── 3g. Baca Quran ──
    $stmtQuran = $pdo->prepare(
        'SELECT surah_name, last_ayat, duration_minutes, points_earned, read_at
         FROM quran_reading_logs
         WHERE student_id = :sid AND DATE(read_at) = :d
         ORDER BY read_at ASC'
    );
    $stmtQuran->execute(['sid' => $studentId, 'd' => $date]);
    $qurans = $stmtQuran->fetchAll();

    foreach ($qurans as $q) {
        $desc = "Melaporkan Membaca Al-Quran Surah {$q['surah_name']} ayat {$q['last_ayat']}";
        if ((int) $q['duration_minutes'] > 0) {
            $desc .= " selama {$q['duration_minutes']} menit";
        }
        $events[] = [
            'group'       => 'Ibadah',
            'description' => $desc,
            'timestamp'   => $q['read_at'],
            'points'      => (int) $q['points_earned'],
            'type'        => 'quran',
            'badge'       => null,
        ];
    }

    // ── 3h. Tahfidz Setoran ──
    $stmtTahfidz = $pdo->prepare(
        'SELECT ts.surah_number, ts.ayat_from, ts.ayat_to, ts.grade, ts.group_id,
                ts.points_earned, ts.setoran_at, u.name AS guru_name
         FROM tahfidz_setoran ts
         LEFT JOIN users u ON ts.guru_tahfidz_id = u.id
         WHERE ts.student_id = :sid AND DATE(ts.setoran_at) = :d
         ORDER BY ts.setoran_at ASC, ts.group_id, ts.id'
    );
    $stmtTahfidz->execute(['sid' => $studentId, 'd' => $date]);
    $tahfidzs = $stmtTahfidz->fetchAll();

    // Group by group_id for multi-surah reports
    $tahfidzGrouped = [];
    foreach ($tahfidzs as $tf) {
        $gid = $tf['group_id'] ?? ('single_' . $tf['surah_number'] . '_' . $tf['setoran_at']);
        if (!isset($tahfidzGrouped[$gid])) {
            $tahfidzGrouped[$gid] = [
                'items' => [],
                'grade' => $tf['grade'],
                'points' => 0,
                'setoran_at' => $tf['setoran_at'],
                'guru_name' => $tf['guru_name'],
            ];
        }
        $tahfidzGrouped[$gid]['points'] += (int) $tf['points_earned'];
        $tahfidzGrouped[$gid]['items'][] = $tf;
    }

    // Helper: map old Arabic grades to letter grades
    $mapGrade = function ($g) {
        switch (strtolower(trim($g))) {
            case 'mumtaz':        return 'A';
            case 'jayyid_jiddan':
            case 'jayyid jiddan': return 'B+';
            case 'jayyid':        return 'B';
            case 'maqbul':        return 'C';
            case 'rasib':         return 'D';
            default:              return $g; // already A/B+/B/C/D
        }
    };

    foreach ($tahfidzGrouped as $group) {
        $parts = [];
        $badges = [];
        foreach ($group['items'] as $tf) {
            $sName = getSurahName($tf['surah_number']);
            $parts[] = "{$sName} ayat {$tf['ayat_from']}-{$tf['ayat_to']}";
            $badges[] = [
                'surah' => $sName,
                'grade' => $mapGrade($tf['grade']),
            ];
        }
        $desc = 'Menyetorkan Hafalan Tahfidz ' . implode(', ', $parts);
        // For single badge (backward compat), use first grade letter
        $firstGrade = count($badges) > 0 ? $badges[0]['grade'] : $mapGrade($group['grade']);
        $events[] = [
            'group'       => 'Kegiatan',
            'description' => $desc,
            'timestamp'   => $group['setoran_at'],
            'points'      => $group['points'],
            'type'        => 'tahfidz',
            'badge'       => $firstGrade,
            'badges'      => $badges,
            'detail'      => $group['guru_name'] ? "Guru: {$group['guru_name']}" : null,
        ];
    }

    // ── 3i. Jurnal ──
    $stmtJournal = $pdo->prepare(
        'SELECT title, created_at
         FROM journals
         WHERE student_id = :sid AND journal_date = :d
         ORDER BY created_at ASC'
    );
    $stmtJournal->execute(['sid' => $studentId, 'd' => $date]);
    $journals = $stmtJournal->fetchAll();

    foreach ($journals as $jn) {
        $events[] = [
            'group'       => 'Kegiatan',
            'description' => "Menulis Jurnal: {$jn['title']}",
            'timestamp'   => $jn['created_at'],
            'points'      => 0,
            'type'        => 'jurnal',
            'badge'       => null,
        ];
    }

    // ── 3j. Evaluasi Guru ──
    $stmtEval = $pdo->prepare(
        'SELECT g.id, g.evaluasi_number, g.bulan, g.nilai_data, g.keterangan_data,
                g.catatan, g.evaluasi_date, g.created_at,
                u.name AS guru_name
         FROM guru_evaluasi_logs g
         JOIN users u ON g.guru_id = u.id
         WHERE g.student_id = :sid AND DATE(g.created_at) = :d
         ORDER BY g.created_at ASC'
    );
    $stmtEval->execute(['sid' => $studentId, 'd' => $date]);
    $evaluasis = $stmtEval->fetchAll();

    foreach ($evaluasis as $ev) {
        $ordinals = ['', 'Pertama', 'Kedua', 'Ketiga', 'Keempat', 'Kelima',
                      'Keenam', 'Ketujuh', 'Kedelapan', 'Kesembilan', 'Kesepuluh',
                      'Kesebelas', 'Kedua Belas'];
        $ordLabel = isset($ordinals[$ev['evaluasi_number']]) ? $ordinals[$ev['evaluasi_number']] : "Ke-{$ev['evaluasi_number']}";

        $events[] = [
            'group'       => 'Evaluasi',
            'description' => "Wali Kelas {$ev['guru_name']} melaporkan Evaluasi {$ordLabel} ({$ev['bulan']})",
            'timestamp'   => $ev['created_at'],
            'points'      => 0,
            'type'        => 'evaluasi',
            'badge'       => null,
            'detail'      => 'Buka',
            'evaluasi_id' => (int) $ev['id'],
            'evaluasi_data' => [
                'id'               => (int) $ev['id'],
                'evaluasi_number'  => (int) $ev['evaluasi_number'],
                'bulan'            => $ev['bulan'],
                'nilai_data'       => $ev['nilai_data'],
                'keterangan_data'  => $ev['keterangan_data'],
                'catatan'          => $ev['catatan'] ?? '',
                'evaluasi_date'    => $ev['evaluasi_date'],
                'guru_name'        => $ev['guru_name'],
                'created_at'       => $ev['created_at'],
            ],
        ];
    }

    // ═══════════════════════════════════════
    // 4. Sort events by timestamp (newest first)
    // ═══════════════════════════════════════
    usort($events, function ($a, $b) {
        return strcmp($b['timestamp'], $a['timestamp']);
    });

    // ═══════════════════════════════════════
    // 5. Build flat timeline (no grouping)
    // ═══════════════════════════════════════
    $timeline = [];
    foreach ($events as $ev) {
        $item = [
            'description' => $ev['description'],
            'timestamp'   => $ev['timestamp'],
            'points'      => $ev['points'],
            'type'        => $ev['type'],
            'badge'       => $ev['badge'] ?? null,
            'badges'      => $ev['badges'] ?? null,
            'detail'      => $ev['detail'] ?? null,
        ];
        // Tambahkan data evaluasi jika tipe = evaluasi
        if (isset($ev['evaluasi_id'])) {
            $item['evaluasi_id']   = $ev['evaluasi_id'];
            $item['evaluasi_data'] = $ev['evaluasi_data'];
        }
        $timeline[] = $item;
    }

    // ═══════════════════════════════════════
    // 6. Hitung ringkasan
    // ═══════════════════════════════════════
    $prayerNames = ['Subuh', 'Dzuhur', 'Ashar', 'Maghrib', 'Isya'];
    $prayerMap = [];
    foreach ($prayerNames as $pn) {
        $prayerMap[$pn] = 'upcoming';
    }
    foreach ($prayers as $p) {
        $prayerMap[$p['prayer_name']] = $p['status'];
    }

    $todayPrayers = [];
    foreach ($prayerMap as $name => $status) {
        $todayPrayers[] = [
            'name'   => $name,
            'status' => $status,
        ];
    }

    $donePrayers = 0;
    foreach ($todayPrayers as $tp) {
        if (in_array($tp['status'], ['done', 'done_jamaah'])) {
            $donePrayers++;
        }
    }

    // Total poin hari ini
    $stmtPointsToday = $pdo->prepare(
        'SELECT COALESCE(SUM(points), 0) AS pts
         FROM points_log
         WHERE student_id = :sid AND DATE(earned_at) = :d'
    );
    $stmtPointsToday->execute(['sid' => $studentId, 'd' => $date]);
    $pointsToday = (int) $stmtPointsToday->fetchColumn();

    // Cek apakah hari ini masih aktif (ada data hari ini)
    $isOnline = ($selectedChild['last_active_date'] === $date);

    $summary = [
        'prayers_done'  => $donePrayers,
        'prayers_total' => 5,
        'points_today'  => $pointsToday,
        'total_points'  => (int) $selectedChild['total_points'],
        'streak'        => (int) $selectedChild['streak'],
        'current_level' => (int) $selectedChild['current_level'],
        'total_events'  => count($events),
        'is_online'     => $isOnline,
    ];

    // ═══════════════════════════════════════
    // 7. Kirim response
    // ═══════════════════════════════════════
    echo json_encode([
        'success' => true,
        'data' => [
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
                'student_id'      => (int) $selectedChild['student_id'],
                'student_name'    => $selectedChild['student_name'],
                'student_avatar'  => $selectedChild['student_avatar'],
                'nis'             => $selectedChild['nis'],
                'class_name'      => $selectedChild['class_name'],
                'academic_year'   => $selectedChild['academic_year'],
                'relationship'    => $selectedChild['relationship'],
                'total_points'    => (int) $selectedChild['total_points'],
                'current_level'   => (int) $selectedChild['current_level'],
                'streak'          => (int) $selectedChild['streak'],
                'last_active_date'=> $selectedChild['last_active_date'],
            ],
            'date'           => $date,
            'today_prayers'  => $todayPrayers,
            'summary'        => $summary,
            'timeline'       => $timeline,
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
