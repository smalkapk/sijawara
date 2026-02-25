<?php
// /server/api/leaderboard.php
// Endpoint untuk leaderboard siswa (peringkat berdasarkan total poin)
// Method: GET
// Header: Authorization: Bearer <token>
// Query params (optional):
//   ?class_id=1    → filter by class
//   ?limit=20      → limit jumlah siswa (default 50)
//
// Response: daftar siswa beserta poin, streak, badges count

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
    // Ambil student_id user yang login
    $stmt = $pdo->prepare('SELECT id FROM students WHERE user_id = :uid LIMIT 1');
    $stmt->execute(['uid' => $userId]);
    $myStudent = $stmt->fetch();
    $myStudentId = $myStudent ? (int) $myStudent['id'] : 0;

    // Optional filters
    $classId = isset($_GET['class_id']) ? (int) $_GET['class_id'] : null;
    $limit   = isset($_GET['limit']) ? min((int) $_GET['limit'], 100) : 50;

    // Build query
    $where = '';
    $params = [];

    if ($classId) {
        $where = 'AND s.class_id = :cid';
        $params['cid'] = $classId;
    }

    $sql = "
        SELECT s.id AS student_id, s.total_points, s.current_level, s.streak,
               u.name, u.avatar_url,
               c.name AS class_name,
               (SELECT COUNT(*) FROM student_badges sb WHERE sb.student_id = s.id) AS badge_count
        FROM students s
        JOIN users u ON s.user_id = u.id
        LEFT JOIN classes c ON s.class_id = c.id
        WHERE u.is_active = 1 {$where}
        ORDER BY s.total_points DESC, s.streak DESC
        LIMIT {$limit}
    ";

    $stmt = $pdo->prepare($sql);
    $stmt->execute($params);
    $rows = $stmt->fetchAll();

    $leaderboard = [];
    $myRank = null;
    foreach ($rows as $index => $row) {
        $sid  = (int) $row['student_id'];
        $rank = $index + 1;

        $entry = [
            'student_id'   => $sid,
            'name'         => $row['name'],
            'avatar_url'   => $row['avatar_url'],
            'class_name'   => $row['class_name'] ?? '-',
            'total_points' => (int) $row['total_points'],
            'current_level'=> (int) $row['current_level'],
            'streak'       => (int) $row['streak'],
            'badge_count'  => (int) $row['badge_count'],
            'rank'         => $rank,
            'is_me'        => $sid === $myStudentId,
        ];

        if ($sid === $myStudentId) {
            $myRank = $rank;
        }

        $leaderboard[] = $entry;
    }

    // Jika user tidak ada di list (misal filter class), cari ranknya secara global
    if ($myRank === null && $myStudentId > 0) {
        $stmt = $pdo->prepare(
            "SELECT COUNT(*) + 1 AS my_rank
             FROM students s2
             JOIN users u2 ON s2.user_id = u2.id
             WHERE u2.is_active = 1
               AND s2.total_points > (SELECT total_points FROM students WHERE id = :sid)"
        );
        $stmt->execute(['sid' => $myStudentId]);
        $myRank = (int) $stmt->fetchColumn();
    }

    // ══════════════════════════════════════
    // Detail siswa tertentu (untuk bottom sheet)
    // ══════════════════════════════════════
    $detailStudentId = isset($_GET['detail_student_id']) ? (int) $_GET['detail_student_id'] : null;
    $studentDetail = null;

    if ($detailStudentId) {
        $stmt = $pdo->prepare(
            'SELECT s.id AS student_id, s.total_points, s.current_level, s.streak,
                    u.name, u.avatar_url,
                    c.name AS class_name
             FROM students s
             JOIN users u ON s.user_id = u.id
             LEFT JOIN classes c ON s.class_id = c.id
             WHERE s.id = :sid
             LIMIT 1'
        );
        $stmt->execute(['sid' => $detailStudentId]);
        $detail = $stmt->fetch();

        if ($detail) {
            // Ambil badges siswa tersebut
            $stmt = $pdo->prepare(
                'SELECT b.id, b.name, b.description, b.icon, b.gradient_colors,
                        b.requirement_type, b.requirement_value,
                        sb.achieved_at
                 FROM student_badges sb
                 JOIN badges b ON sb.badge_id = b.id
                 WHERE sb.student_id = :sid
                 ORDER BY sb.achieved_at DESC'
            );
            $stmt->execute(['sid' => $detailStudentId]);
            $detailBadges = $stmt->fetchAll();

            // Ambil juga semua badge (belum achieved)
            $stmt = $pdo->prepare(
                'SELECT b.* FROM badges b
                 WHERE b.id NOT IN (SELECT badge_id FROM student_badges WHERE student_id = :sid)
                 ORDER BY b.id ASC'
            );
            $stmt->execute(['sid' => $detailStudentId]);
            $unachievedBadges = $stmt->fetchAll();

            $allDetailBadges = [];
            foreach ($detailBadges as $b) {
                $allDetailBadges[] = [
                    'id'              => (int) $b['id'],
                    'name'            => $b['name'],
                    'description'     => $b['description'],
                    'icon'            => $b['icon'],
                    'gradient_colors' => $b['gradient_colors'],
                    'is_achieved'     => true,
                    'achieved_at'     => $b['achieved_at'],
                ];
            }
            foreach ($unachievedBadges as $b) {
                $allDetailBadges[] = [
                    'id'              => (int) $b['id'],
                    'name'            => $b['name'],
                    'description'     => $b['description'],
                    'icon'            => $b['icon'],
                    'gradient_colors' => $b['gradient_colors'],
                    'is_achieved'     => false,
                    'achieved_at'     => null,
                ];
            }

            $studentDetail = [
                'student_id'   => (int) $detail['student_id'],
                'name'         => $detail['name'],
                'avatar_url'   => $detail['avatar_url'],
                'class_name'   => $detail['class_name'] ?? '-',
                'total_points' => (int) $detail['total_points'],
                'current_level'=> (int) $detail['current_level'],
                'streak'       => (int) $detail['streak'],
                'badges'       => $allDetailBadges,
            ];
        }
    }

    echo json_encode([
        'success' => true,
        'data' => [
            'leaderboard'    => $leaderboard,
            'my_rank'        => $myRank,
            'my_student_id'  => $myStudentId,
            'total_students' => count($leaderboard),
            'student_detail' => $studentDetail,
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
