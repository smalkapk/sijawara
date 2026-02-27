<?php
// /server/api/guru_evaluasi.php
// Endpoint untuk fitur Guru Evaluasi bulanan siswa
//
// Struktur evaluasi (15 item dalam 3 kategori):
//   A. KARAKTER : Kedisiplinan, Kerjasama, Kemandirian, Kepedulian,
//                 Keberanian, Tanggung Jawab, Kepemimpinan
//   B. KBM      : Keaktifan di kelas, Adab dengan guru, Adab dengan teman,
//                 Tugas, Tahfidz/Hafalan Doa
//   C. IBADAH   : Sholat Wajib, Sholat Sunnah, Puasa
//
// GET    ?action=reports&student_id=X                        -> laporan evaluasi siswa
// GET    ?action=riwayat&student_id=X&type=TYPE&month=YYYY-MM -> riwayat data bulanan
// POST                                                       -> simpan / update laporan evaluasi
// DELETE ?id=X                                               -> hapus laporan evaluasi

header('Content-Type: application/json; charset=utf-8');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, POST, DELETE, OPTIONS');
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
// GET: Laporan Evaluasi / Riwayat
// ════════════════════════════════════════════════════
if ($_SERVER['REQUEST_METHOD'] === 'GET') {
    $action = $_GET['action'] ?? '';

    // ── Reports: Daftar evaluasi per siswa ──
    if ($action === 'reports') {
        $studentId = $_GET['student_id'] ?? null;

        if (!$studentId) {
            http_response_code(400);
            echo json_encode(['success' => false, 'message' => 'Parameter student_id diperlukan']);
            exit;
        }

        try {
            $stmt = $pdo->prepare(
                "SELECT id, evaluasi_number, bulan, nilai_data, keterangan_data, catatan, evaluasi_date, created_at
                 FROM guru_evaluasi_logs
                 WHERE student_id = :sid
                 ORDER BY evaluasi_number ASC, created_at DESC"
            );
            $stmt->execute(['sid' => $studentId]);
            $rows = $stmt->fetchAll();

            $reports = [];
            foreach ($rows as $row) {
                $reports[] = [
                    'id'               => (string) $row['id'],
                    'evaluasi_number'  => (int) $row['evaluasi_number'],
                    'bulan'            => $row['bulan'] ?? '',
                    'nilai_data'       => $row['nilai_data'] ?? '{}',
                    'keterangan_data'  => $row['keterangan_data'] ?? '{}',
                    'catatan'          => $row['catatan'] ?? '',
                    'evaluasi_date'    => $row['evaluasi_date'],
                    'created_at'       => $row['created_at'],
                ];
            }

            echo json_encode(['success' => true, 'data' => $reports]);
        } catch (Exception $e) {
            http_response_code(500);
            echo json_encode(['success' => false, 'message' => 'Gagal mengambil laporan evaluasi']);
        }
        exit;
    }

    // ── Riwayat: Data bulanan untuk rekomendasi ──
    if ($action === 'riwayat') {
        $studentId = $_GET['student_id'] ?? null;
        $type      = $_GET['type'] ?? '';    // tugas, tahfidz, ibadah
        $month     = $_GET['month'] ?? '';   // YYYY-MM

        if (!$studentId || empty($type) || empty($month)) {
            http_response_code(400);
            echo json_encode(['success' => false, 'message' => 'Parameter student_id, type, dan month diperlukan']);
            exit;
        }

        $monthLike = $month . '%'; // e.g. "2026-02%"

        try {
            $data = [];

            if ($type === 'tugas') {
                // ── Public Speaking Logs ──
                // Kolom: id, student_id, title, materi, mentor, note, speaking_date, points_earned
                $stmt = $pdo->prepare(
                    "SELECT id, title, materi, mentor, note, speaking_date, points_earned
                     FROM public_speaking_logs
                     WHERE student_id = :sid AND speaking_date LIKE :m
                     ORDER BY speaking_date DESC"
                );
                $stmt->execute(['sid' => $studentId, 'm' => $monthLike]);
                $rows = $stmt->fetchAll();
                foreach ($rows as $r) {
                    $pts = (int)($r['points_earned'] ?? 0);
                    $data[] = [
                        'title'    => 'Public Speaking: ' . ($r['title'] ?? '-'),
                        'subtitle' => 'Mentor: ' . ($r['mentor'] ?? '-') . ($r['note'] ? ' | ' . $r['note'] : ''),
                        'date'     => $r['speaking_date'] ?? '',
                        'badge'    => $pts . ' poin',
                    ];
                }

                // ── Kajian Logs ──
                // Kolom: id, student_id, title, materi, mentor, note, kajian_date, points_earned
                $stmt2 = $pdo->prepare(
                    "SELECT id, title, materi, mentor, note, kajian_date, points_earned
                     FROM kajian_logs
                     WHERE student_id = :sid AND kajian_date LIKE :m
                     ORDER BY kajian_date DESC"
                );
                $stmt2->execute(['sid' => $studentId, 'm' => $monthLike]);
                $rows2 = $stmt2->fetchAll();
                foreach ($rows2 as $r) {
                    $pts = (int)($r['points_earned'] ?? 0);
                    $data[] = [
                        'title'    => 'Kajian: ' . ($r['title'] ?? '-'),
                        'subtitle' => 'Mentor: ' . ($r['mentor'] ?? '-') . ($r['note'] ? ' | ' . $r['note'] : ''),
                        'date'     => $r['kajian_date'] ?? '',
                        'badge'    => $pts . ' poin',
                    ];
                }

            } elseif ($type === 'tahfidz') {
                // ── Tahfidz Setoran ──
                // Kolom: id, target_id, student_id, guru_tahfidz_id, surah_number,
                //        ayat_from, ayat_to, grade (mumtaz/jayyid_jiddan/jayyid/maqbul/rasib),
                //        notes, points_earned, setoran_at
                $stmt = $pdo->prepare(
                    "SELECT ts.id, ts.surah_number, ts.ayat_from, ts.ayat_to,
                            ts.grade, ts.notes, ts.points_earned, ts.setoran_at
                     FROM tahfidz_setoran ts
                     WHERE ts.student_id = :sid AND ts.setoran_at LIKE :m
                     ORDER BY ts.setoran_at DESC"
                );
                $stmt->execute(['sid' => $studentId, 'm' => $monthLike]);
                $rows = $stmt->fetchAll();
                foreach ($rows as $r) {
                    // Mapping grade ke badge
                    $grade = strtolower($r['grade'] ?? '');
                    $badge = 'Cukup';
                    $gradeLabel = ucfirst(str_replace('_', ' ', $r['grade'] ?? ''));
                    if ($grade === 'mumtaz') {
                        $badge = 'Sangat Baik';
                    } elseif ($grade === 'jayyid_jiddan' || $grade === 'jayyid') {
                        $badge = 'Baik';
                    } elseif ($grade === 'maqbul') {
                        $badge = 'Cukup';
                    } elseif ($grade === 'rasib') {
                        $badge = 'Perlu Perbaikan';
                    }

                    $ayat = '';
                    if (!empty($r['ayat_from']) && !empty($r['ayat_to'])) {
                        $ayat = " (Ayat {$r['ayat_from']}-{$r['ayat_to']})";
                    }

                    $data[] = [
                        'title'    => 'Surah ' . ($r['surah_number'] ?? '-') . $ayat,
                        'subtitle' => 'Grade: ' . $gradeLabel . ($r['notes'] ? ' | ' . $r['notes'] : ''),
                        'date'     => $r['setoran_at'] ?? '',
                        'badge'    => $badge,
                    ];
                }

            } elseif ($type === 'ibadah') {
                // ═══════════════════════════════════════
                // SHOLAT WAJIB: dari tabel prayer_logs
                // Kolom: prayer_date, prayer_name (enum Subuh/Dzuhur/Ashar/Maghrib/Isya),
                //        status (enum done/done_jamaah/missed)
                // ═══════════════════════════════════════
                $stmt = $pdo->prepare(
                    "SELECT prayer_date, prayer_name, status
                     FROM prayer_logs
                     WHERE student_id = :sid AND prayer_date LIKE :m
                     ORDER BY prayer_date ASC, FIELD(prayer_name, 'Subuh','Dzuhur','Ashar','Maghrib','Isya')"
                );
                $stmt->execute(['sid' => $studentId, 'm' => $monthLike]);
                $prayerRows = $stmt->fetchAll();

                // Kelompokkan per tanggal
                $prayerByDate = [];
                foreach ($prayerRows as $r) {
                    $date = $r['prayer_date'];
                    if (!isset($prayerByDate[$date])) $prayerByDate[$date] = [];
                    $prayerByDate[$date][] = $r;
                }

                // Hitung statistik sholat wajib
                $totalWajib = 0;
                $hadirWajib = 0;
                foreach ($prayerRows as $r) {
                    $totalWajib++;
                    if ($r['status'] === 'done' || $r['status'] === 'done_jamaah') {
                        $hadirWajib++;
                    }
                }

                // Summary sholat wajib
                $jumlahHari = count($prayerByDate);
                if ($totalWajib > 0) {
                    $pctW = round(($hadirWajib / $totalWajib) * 100);
                    $badgeW = $pctW >= 85 ? 'Sangat Baik' : ($pctW >= 70 ? 'Baik' : ($pctW >= 50 ? 'Cukup' : 'Perlu Perbaikan'));
                    $data[] = [
                        'title'    => 'Sholat Wajib',
                        'subtitle' => "Kehadiran $hadirWajib/$totalWajib ($pctW%) dari $jumlahHari hari",
                        'date'     => $month,
                        'badge'    => $badgeW,
                    ];
                }

                // ═══════════════════════════════════════
                // SHOLAT SUNNAH & PUASA: dari tabel daily_extras
                // Kolom: log_date, deeds (JSON array, e.g. ["Tahajjud","Dhuha","Puasa Sunnah"])
                // ═══════════════════════════════════════
                $stmtExtras = $pdo->prepare(
                    "SELECT log_date, deeds
                     FROM daily_extras
                     WHERE student_id = :sid AND log_date LIKE :m
                     ORDER BY log_date ASC"
                );
                $stmtExtras->execute(['sid' => $studentId, 'm' => $monthLike]);
                $extrasRows = $stmtExtras->fetchAll();

                $totalSunnahDays = count($extrasRows);
                $hadirDhuha = 0;
                $hadirTahajud = 0;
                $hadirPuasa = 0;

                foreach ($extrasRows as $r) {
                    $deeds = json_decode($r['deeds'] ?? '[]', true);
                    if (!is_array($deeds)) $deeds = [];

                    if (in_array('Dhuha', $deeds)) $hadirDhuha++;
                    if (in_array('Tahajjud', $deeds)) $hadirTahajud++;
                    if (in_array('Puasa Sunnah', $deeds)) $hadirPuasa++;
                }

                // Summary sholat sunnah (Dhuha + Tahajud)
                if ($totalSunnahDays > 0) {
                    $totalSunnahSlots = $totalSunnahDays * 2; // Dhuha + Tahajud per hari
                    $hadirSunnah = $hadirDhuha + $hadirTahajud;
                    $pctS = round(($hadirSunnah / $totalSunnahSlots) * 100);
                    $badgeS = $pctS >= 85 ? 'Sangat Baik' : ($pctS >= 70 ? 'Baik' : ($pctS >= 50 ? 'Cukup' : 'Perlu Perbaikan'));
                    $data[] = [
                        'title'    => 'Sholat Sunnah',
                        'subtitle' => "Dhuha: $hadirDhuha/$totalSunnahDays, Tahajud: $hadirTahajud/$totalSunnahDays ($pctS%)",
                        'date'     => $month,
                        'badge'    => $badgeS,
                    ];
                }

                // Summary puasa (dari daily_extras + fasting_logs)
                $stmtFasting = $pdo->prepare(
                    "SELECT id, fasting_date, fasting_type
                     FROM fasting_logs
                     WHERE student_id = :sid AND fasting_date LIKE :m
                     ORDER BY fasting_date ASC"
                );
                $stmtFasting->execute(['sid' => $studentId, 'm' => $monthLike]);
                $fastingRows = $stmtFasting->fetchAll();

                $totalPuasaCount = $hadirPuasa + count($fastingRows);
                if ($totalPuasaCount > 0) {
                    $data[] = [
                        'title'    => 'Puasa Sunnah',
                        'subtitle' => "Total $totalPuasaCount kali puasa sunnah di bulan ini",
                        'date'     => $month,
                        'badge'    => $totalPuasaCount >= 8 ? 'Sangat Baik' : ($totalPuasaCount >= 4 ? 'Baik' : ($totalPuasaCount >= 2 ? 'Cukup' : 'Perlu Perbaikan')),
                    ];
                }

                // Detail per hari: sholat wajib
                foreach ($prayerByDate as $date => $prayers) {
                    $wajibList = [];
                    foreach ($prayers as $p) {
                        $statusLabel = $p['status'] === 'done_jamaah' ? 'Jamaah' : ($p['status'] === 'done' ? 'Sendiri' : 'Tidak');
                        $wajibList[] = $p['prayer_name'] . ': ' . $statusLabel;
                    }
                    $data[] = [
                        'title'    => 'Sholat ' . $date,
                        'subtitle' => implode(', ', $wajibList),
                        'date'     => $date,
                        'badge'    => null,
                    ];
                }
            }

            echo json_encode(['success' => true, 'data' => $data]);
        } catch (Exception $e) {
            http_response_code(500);
            echo json_encode(['success' => false, 'message' => 'Gagal mengambil data riwayat: ' . $e->getMessage()]);
        }
        exit;
    }

    http_response_code(400);
    echo json_encode(['success' => false, 'message' => 'Parameter action tidak valid (reports/riwayat)']);
    exit;
}

// ════════════════════════════════════════════════════
// POST: Simpan / Update Laporan Evaluasi
// Body JSON: { id?, student_id, bulan, nilai_data:{...}, keterangan_data:{...}, catatan, evaluasi_date }
// ════════════════════════════════════════════════════
if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $input = json_decode(file_get_contents('php://input'), true);
    if (!$input) {
        http_response_code(400);
        echo json_encode(['success' => false, 'message' => 'Body JSON tidak valid']);
        exit;
    }

    $noteId         = $input['id'] ?? null;
    $studentId      = $input['student_id'] ?? null;
    $bulan          = $input['bulan'] ?? '';
    $nilaiData      = $input['nilai_data'] ?? [];
    $keteranganData = $input['keterangan_data'] ?? [];
    $catatan        = $input['catatan'] ?? '';
    $evalDate       = $input['evaluasi_date'] ?? date('Y-m-d');

    // Encode ke JSON jika masih array
    $nilaiJson      = is_string($nilaiData) ? $nilaiData : json_encode($nilaiData);
    $keteranganJson = is_string($keteranganData) ? $keteranganData : json_encode($keteranganData);

    // Validasi
    if (!$studentId) {
        http_response_code(400);
        echo json_encode(['success' => false, 'message' => 'student_id wajib diisi']);
        exit;
    }
    if (empty($bulan)) {
        http_response_code(400);
        echo json_encode(['success' => false, 'message' => 'Bulan evaluasi wajib diisi']);
        exit;
    }
    if (empty($nilaiJson) || $nilaiJson === '{}' || $nilaiJson === '[]') {
        http_response_code(400);
        echo json_encode(['success' => false, 'message' => 'Minimal satu item evaluasi harus diisi']);
        exit;
    }

    try {
        $pdo->beginTransaction();

        if ($noteId) {
            // ── Update ──
            $check = $pdo->prepare("SELECT id FROM guru_evaluasi_logs WHERE id = :id AND student_id = :sid");
            $check->execute(['id' => $noteId, 'sid' => $studentId]);
            if (!$check->fetch()) {
                $pdo->rollBack();
                http_response_code(404);
                echo json_encode(['success' => false, 'message' => 'Laporan tidak ditemukan']);
                exit;
            }

            $stmt = $pdo->prepare(
                "UPDATE guru_evaluasi_logs
                 SET bulan = :bulan, nilai_data = :nilai, keterangan_data = :keterangan,
                     catatan = :catatan, evaluasi_date = :d
                 WHERE id = :id AND student_id = :sid"
            );
            $stmt->execute([
                'bulan'      => $bulan,
                'nilai'      => $nilaiJson,
                'keterangan' => $keteranganJson,
                'catatan'    => $catatan,
                'd'          => $evalDate,
                'id'         => $noteId,
                'sid'        => $studentId,
            ]);

            $resultId = $noteId;
        } else {
            // ── Insert baru: auto-increment evaluasi_number per siswa ──
            $stmtMax = $pdo->prepare(
                "SELECT COALESCE(MAX(evaluasi_number), 0) AS max_num
                 FROM guru_evaluasi_logs
                 WHERE student_id = :sid"
            );
            $stmtMax->execute(['sid' => $studentId]);
            $nextNumber = (int) $stmtMax->fetchColumn() + 1;

            $stmt = $pdo->prepare(
                "INSERT INTO guru_evaluasi_logs
                    (student_id, guru_id, evaluasi_number, bulan, nilai_data, keterangan_data, catatan, evaluasi_date)
                 VALUES (:sid, :gid, :num, :bulan, :nilai, :keterangan, :catatan, :d)"
            );
            $stmt->execute([
                'sid'        => $studentId,
                'gid'        => $userId,
                'num'        => $nextNumber,
                'bulan'      => $bulan,
                'nilai'      => $nilaiJson,
                'keterangan' => $keteranganJson,
                'catatan'    => $catatan,
                'd'          => $evalDate,
            ]);
            $resultId = $pdo->lastInsertId();
        }

        $pdo->commit();

        echo json_encode([
            'success' => true,
            'message' => $noteId ? 'Evaluasi diperbarui' : 'Evaluasi disimpan',
            'data'    => ['id' => (string) $resultId],
        ]);
    } catch (Exception $e) {
        $pdo->rollBack();
        http_response_code(500);
        echo json_encode(['success' => false, 'message' => 'Gagal menyimpan evaluasi']);
    }
    exit;
}

// ════════════════════════════════════════════════════
// DELETE: Hapus laporan evaluasi
// Query param: id=<report_id>
// ════════════════════════════════════════════════════
if ($_SERVER['REQUEST_METHOD'] === 'DELETE') {
    $noteId = $_GET['id'] ?? null;

    if (!$noteId) {
        http_response_code(400);
        echo json_encode(['success' => false, 'message' => 'Parameter id diperlukan']);
        exit;
    }

    try {
        $check = $pdo->prepare("SELECT id, student_id, evaluasi_number FROM guru_evaluasi_logs WHERE id = :id");
        $check->execute(['id' => $noteId]);
        $row = $check->fetch();

        if (!$row) {
            http_response_code(404);
            echo json_encode(['success' => false, 'message' => 'Laporan tidak ditemukan']);
            exit;
        }

        $studentId = (int) $row['student_id'];
        $deletedNumber = (int) $row['evaluasi_number'];

        $pdo->beginTransaction();

        // Hapus record
        $stmt = $pdo->prepare("DELETE FROM guru_evaluasi_logs WHERE id = :id");
        $stmt->execute(['id' => $noteId]);

        // Re-number evaluasi setelah yang dihapus
        $stmt = $pdo->prepare(
            "UPDATE guru_evaluasi_logs
             SET evaluasi_number = evaluasi_number - 1
             WHERE student_id = :sid AND evaluasi_number > :num"
        );
        $stmt->execute(['sid' => $studentId, 'num' => $deletedNumber]);

        $pdo->commit();

        echo json_encode(['success' => true, 'message' => 'Evaluasi dihapus']);
    } catch (Exception $e) {
        if ($pdo->inTransaction()) $pdo->rollBack();
        http_response_code(500);
        echo json_encode(['success' => false, 'message' => 'Gagal menghapus evaluasi']);
    }
    exit;
}

http_response_code(405);
echo json_encode(['success' => false, 'message' => 'Method tidak didukung']);
