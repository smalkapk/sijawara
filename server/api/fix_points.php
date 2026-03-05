<?php
// /server/api/fix_points.php
// ONE-TIME SCRIPT: Fix existing points_earned di public_speaking_logs & kajian_logs
// dari nilai lama (5, 3, dsb.) menjadi 2 per catatan,
// lalu recalculate students.total_points untuk semua siswa.
//
// Jalankan 1x saja lewat browser: https://portal-smalka.com/api/fix_points.php
// Setelah selesai, HAPUS file ini dari server.

header('Content-Type: application/json; charset=utf-8');

require_once __DIR__ . '/../config/conn.php';

try {
    $pdo->beginTransaction();

    // 1. Fix public_speaking_logs: set semua points_earned = 2
    $stmt = $pdo->prepare('UPDATE public_speaking_logs SET points_earned = 2 WHERE points_earned != 2');
    $stmt->execute();
    $fixedPS = $stmt->rowCount();

    // 2. Fix kajian_logs: set semua points_earned = 2
    $stmt = $pdo->prepare('UPDATE kajian_logs SET points_earned = 2 WHERE points_earned != 2');
    $stmt->execute();
    $fixedKajian = $stmt->rowCount();

    // 3. Recalculate total_points untuk SEMUA siswa
    $students = $pdo->query('SELECT id FROM students')->fetchAll();
    $recalculated = 0;

    foreach ($students as $student) {
        $sid = (int) $student['id'];
        $grandTotal = 0;

        // Shalat points
        $s = $pdo->prepare('SELECT COALESCE(SUM(points_earned), 0) FROM prayer_logs WHERE student_id = :sid');
        $s->execute(['sid' => $sid]);
        $grandTotal += (int) $s->fetchColumn();

        // Bonus 5/5
        $s = $pdo->prepare(
            "SELECT COUNT(*) FROM (
                SELECT prayer_date FROM prayer_logs
                WHERE student_id = :sid AND status IN ('done','done_jamaah')
                GROUP BY prayer_date HAVING COUNT(DISTINCT prayer_name) >= 5
            ) AS fd"
        );
        $s->execute(['sid' => $sid]);
        $grandTotal += (int) $s->fetchColumn() * 3;

        // Daily extras
        $s = $pdo->prepare('SELECT COALESCE(SUM(total_extra_points), 0) FROM daily_extras WHERE student_id = :sid');
        $s->execute(['sid' => $sid]);
        $grandTotal += (int) $s->fetchColumn();

        // Public speaking
        $s = $pdo->prepare('SELECT COALESCE(SUM(points_earned), 0) FROM public_speaking_logs WHERE student_id = :sid');
        $s->execute(['sid' => $sid]);
        $grandTotal += (int) $s->fetchColumn();

        // Kajian/diskusi
        $s = $pdo->prepare('SELECT COALESCE(SUM(points_earned), 0) FROM kajian_logs WHERE student_id = :sid');
        $s->execute(['sid' => $sid]);
        $grandTotal += (int) $s->fetchColumn();

        // Tahfidz setoran
        $s = $pdo->prepare('SELECT COALESCE(SUM(points_earned), 0) FROM tahfidz_setoran WHERE student_id = :sid');
        $s->execute(['sid' => $sid]);
        $grandTotal += (int) $s->fetchColumn();

        // Update
        $pdo->prepare('UPDATE students SET total_points = :tp WHERE id = :sid')
            ->execute(['tp' => $grandTotal, 'sid' => $sid]);

        $recalculated++;
    }

    $pdo->commit();

    echo json_encode([
        'success' => true,
        'message' => 'Fix selesai',
        'details' => [
            'public_speaking_fixed' => $fixedPS,
            'kajian_fixed' => $fixedKajian,
            'students_recalculated' => $recalculated,
        ],
    ], JSON_PRETTY_PRINT);

} catch (Exception $e) {
    $pdo->rollBack();
    http_response_code(500);
    echo json_encode([
        'success' => false,
        'message' => 'Gagal: ' . $e->getMessage(),
    ]);
}
