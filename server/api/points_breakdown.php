<?php
// /server/api/points_breakdown.php
// Endpoint untuk mendapatkan rincian total poin siswa
// Method: GET
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
    // Ambil student_id
    $stmt = $pdo->prepare('SELECT id, total_points, streak FROM students WHERE user_id = :uid LIMIT 1');
    $stmt->execute(['uid' => $userId]);
    $student = $stmt->fetch();

    if (!$student) {
        http_response_code(404);
        echo json_encode(['success' => false, 'message' => 'Data siswa tidak ditemukan']);
        exit;
    }

    $studentId = (int) $student['id'];

    // 1. Poin shalat sendiri (status = done, 1pt each)
    $stmt = $pdo->prepare(
        "SELECT COALESCE(SUM(points_earned), 0) FROM prayer_logs
         WHERE student_id = :sid AND status = 'done'"
    );
    $stmt->execute(['sid' => $studentId]);
    $shalatSendiri = (int) $stmt->fetchColumn();

    // Jumlah shalat sendiri
    $stmt = $pdo->prepare(
        "SELECT COUNT(*) FROM prayer_logs
         WHERE student_id = :sid AND status = 'done'"
    );
    $stmt->execute(['sid' => $studentId]);
    $countSendiri = (int) $stmt->fetchColumn();

    // 2. Poin shalat jamaah (status = done_jamaah, 2pt each)
    $stmt = $pdo->prepare(
        "SELECT COALESCE(SUM(points_earned), 0) FROM prayer_logs
         WHERE student_id = :sid AND status = 'done_jamaah'"
    );
    $stmt->execute(['sid' => $studentId]);
    $shalatJamaah = (int) $stmt->fetchColumn();

    // Jumlah shalat jamaah
    $stmt = $pdo->prepare(
        "SELECT COUNT(*) FROM prayer_logs
         WHERE student_id = :sid AND status = 'done_jamaah'"
    );
    $stmt->execute(['sid' => $studentId]);
    $countJamaah = (int) $stmt->fetchColumn();

    // 3. Bonus 5/5 — hitung berapa hari yang punya 5 shalat done
    $stmt = $pdo->prepare(
        "SELECT COUNT(*) AS full_days FROM (
            SELECT prayer_date
            FROM prayer_logs
            WHERE student_id = :sid AND status IN ('done','done_jamaah')
            GROUP BY prayer_date
            HAVING COUNT(DISTINCT prayer_name) >= 5
        ) AS t"
    );
    $stmt->execute(['sid' => $studentId]);
    $fullDays = (int) $stmt->fetchColumn();
    $bonus5of5 = $fullDays * 3;

    // 4. Poin bangun pagi
    $stmt = $pdo->prepare(
        "SELECT COALESCE(SUM(wake_up_points), 0) FROM daily_extras
         WHERE student_id = :sid"
    );
    $stmt->execute(['sid' => $studentId]);
    $wakeUpTotal = (int) $stmt->fetchColumn();

    // Jumlah hari bangun pagi
    $stmt = $pdo->prepare(
        "SELECT COUNT(*) FROM daily_extras
         WHERE student_id = :sid AND wake_up_points > 0"
    );
    $stmt->execute(['sid' => $studentId]);
    $countWakeUp = (int) $stmt->fetchColumn();

    // 5. Poin kebaikan
    $stmt = $pdo->prepare(
        "SELECT COALESCE(SUM(deeds_points), 0) FROM daily_extras
         WHERE student_id = :sid"
    );
    $stmt->execute(['sid' => $studentId]);
    $deedsTotal = (int) $stmt->fetchColumn();

    // Jumlah total deed items
    $stmt = $pdo->prepare(
        "SELECT deeds FROM daily_extras
         WHERE student_id = :sid AND deeds_points > 0"
    );
    $stmt->execute(['sid' => $studentId]);
    $totalDeedItems = 0;
    while ($row = $stmt->fetch()) {
        $deeds = json_decode($row['deeds'], true);
        if (is_array($deeds)) {
            $totalDeedItems += count($deeds);
        }
    }

    // 6. Combo bonus
    $stmt = $pdo->prepare(
        "SELECT COALESCE(SUM(combo_bonus), 0) FROM daily_extras
         WHERE student_id = :sid"
    );
    $stmt->execute(['sid' => $studentId]);
    $comboTotal = (int) $stmt->fetchColumn();

    // Jumlah hari combo
    $stmt = $pdo->prepare(
        "SELECT COUNT(*) FROM daily_extras
         WHERE student_id = :sid AND combo_bonus > 0"
    );
    $stmt->execute(['sid' => $studentId]);
    $countCombo = (int) $stmt->fetchColumn();

    // 7. Poin public speaking
    $stmt = $pdo->prepare(
        "SELECT COALESCE(SUM(points_earned), 0) FROM public_speaking_logs
         WHERE student_id = :sid"
    );
    $stmt->execute(['sid' => $studentId]);
    $psTotal = (int) $stmt->fetchColumn();

    // Jumlah catatan public speaking
    $stmt = $pdo->prepare(
        "SELECT COUNT(*) FROM public_speaking_logs
         WHERE student_id = :sid"
    );
    $stmt->execute(['sid' => $studentId]);
    $countPS = (int) $stmt->fetchColumn();

    // 8. Poin diskusi (kajian)
    $stmt = $pdo->prepare(
        "SELECT COALESCE(SUM(points_earned), 0) FROM kajian_logs
         WHERE student_id = :sid"
    );
    $stmt->execute(['sid' => $studentId]);
    $diskusiTotal = (int) $stmt->fetchColumn();

    // Jumlah catatan diskusi
    $stmt = $pdo->prepare(
        "SELECT COUNT(*) FROM kajian_logs
         WHERE student_id = :sid"
    );
    $stmt->execute(['sid' => $studentId]);
    $countDiskusi = (int) $stmt->fetchColumn();

    // Total
    $grandTotal = $shalatSendiri + $shalatJamaah + $bonus5of5 + $wakeUpTotal + $deedsTotal + $comboTotal + $psTotal + $diskusiTotal;

    echo json_encode([
        'success' => true,
        'data' => [
            'total_points' => (int) $student['total_points'],
            'streak' => (int) $student['streak'],
            'breakdown' => [
                'shalat_sendiri' => [
                    'points' => $shalatSendiri,
                    'count' => $countSendiri,
                    'per_item' => 1,
                ],
                'shalat_jamaah' => [
                    'points' => $shalatJamaah,
                    'count' => $countJamaah,
                    'per_item' => 2,
                ],
                'bonus_5_5' => [
                    'points' => $bonus5of5,
                    'count' => $fullDays,
                    'per_item' => 3,
                ],
                'bangun_pagi' => [
                    'points' => $wakeUpTotal,
                    'count' => $countWakeUp,
                    'per_item' => 1,
                ],
                'kebaikan' => [
                    'points' => $deedsTotal,
                    'count' => $totalDeedItems,
                    'per_item' => 1,
                ],
                'combo_bonus' => [
                    'points' => $comboTotal,
                    'count' => $countCombo,
                    'per_item' => 3,
                ],
                'public_speaking' => [
                    'points' => $psTotal,
                    'count' => $countPS,
                    'per_item' => 2,
                ],
                'diskusi' => [
                    'points' => $diskusiTotal,
                    'count' => $countDiskusi,
                    'per_item' => 2,
                ],
            ],
            'computed_total' => $grandTotal,
        ],
    ]);

} catch (PDOException $e) {
    http_response_code(500);
    echo json_encode([
        'success' => false,
        'message' => 'Kesalahan server',
        'debug' => $e->getMessage(),
    ]);
}
