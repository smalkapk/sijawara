<?php
// ═══════════════════════════════════════════════════════════
// server/web/siswa/index.php
// Dashboard utama siswa — Portal Sijawara
// Tabs: Dashboard, Tugas, Evaluasi, Profil
// ═══════════════════════════════════════════════════════════

session_start(); 

// ─── Auth Check ───────────────────────────────────────────
if (!isset($_SESSION['web_user_id']) || ($_SESSION['web_role'] ?? '') !== 'siswa') {
    header('Location: ../../');
    exit;
}

require_once __DIR__ . '/../../config/conn.php';

$userId   = (int) $_SESSION['web_user_id'];
$hasError = false;

try {
    // ── Student Data ─────────────────────────────────────
    $stmt = $pdo->prepare(
        'SELECT s.id AS student_id, s.nis, s.total_points, s.current_level,
                s.streak, s.last_active_date,
                u.name, u.email, u.avatar_url,
                c.name AS class_name
         FROM students s
         JOIN users u ON s.user_id = u.id
         LEFT JOIN classes c ON s.class_id = c.id
         WHERE s.user_id = :uid LIMIT 1'
    );
    $stmt->execute(['uid' => $userId]);
    $student = $stmt->fetch();

    if (!$student) {
        session_destroy();
        header('Location: ../../');
        exit;
    }

    $studentId   = (int) $student['student_id'];
    $studentName = $student['name'] ?: 'Siswa';
    $className   = $student['class_name'] ?: '-';
    $totalPoints = (int) $student['total_points'];
    $streak      = (int) $student['streak'];
    $avatarUrl   = $student['avatar_url'] ?: '';
    $initial     = mb_strtoupper(mb_substr($studentName, 0, 1));

    // ── Today's Prayers ──────────────────────────────────
    $today = date('Y-m-d');
    $stmt  = $pdo->prepare(
        'SELECT prayer_name, status, points_earned
         FROM prayer_logs
         WHERE student_id = :sid AND prayer_date = :d'
    );
    $stmt->execute(['sid' => $studentId, 'd' => $today]);
    $prayerRows = $stmt->fetchAll();

    $prayers = [];
    foreach ($prayerRows as $row) {
        $prayers[$row['prayer_name']] = [
            'status' => $row['status'],
            'points' => (int) $row['points_earned'],
        ];
    }

    $prayerNames  = ['subuh', 'dzuhur', 'ashar', 'maghrib', 'isya'];
    $prayerLabels = ['Subuh', 'Dzuhur', 'Ashar', 'Maghrib', 'Isya'];
    $prayerIcons  = [
        '<i class="ti ti-sunrise text-orange-500 text-lg"></i>',
        '<i class="ti ti-sun text-amber-500 text-lg"></i>',
        '<i class="ti ti-cloud-sun text-amber-500 text-lg"></i>',
        '<i class="ti ti-sunset text-orange-500 text-lg"></i>',
        '<i class="ti ti-moon text-blue-500 text-lg"></i>'
    ];
    $doneToday    = count(array_filter($prayers, fn($p) => in_array($p['status'], ['done', 'done_jamaah'])));

    // ── Daily Extras ─────────────────────────────────────
    $stmt = $pdo->prepare(
        'SELECT wake_up_time, deeds FROM daily_extras
         WHERE student_id = :sid AND log_date = :d'
    );
    $stmt->execute(['sid' => $studentId, 'd' => $today]);
    $dailyExtras = $stmt->fetch();
    $wakeUpTime  = $dailyExtras ? $dailyExtras['wake_up_time'] : null;
    $deeds       = $dailyExtras && $dailyExtras['deeds'] ? json_decode($dailyExtras['deeds'], true) : [];

    // ── Points Breakdown (for dashboard) ─────────────────
    $stmt = $pdo->prepare("SELECT COALESCE(SUM(points_earned),0) AS pts, COUNT(*) AS cnt FROM prayer_logs WHERE student_id=:sid AND status='done'");
    $stmt->execute(['sid' => $studentId]);
    $r = $stmt->fetch();
    $bShalatSendiri = ['points' => (int)$r['pts'], 'count' => (int)$r['cnt']];

    $stmt = $pdo->prepare("SELECT COALESCE(SUM(points_earned),0) AS pts, COUNT(*) AS cnt FROM prayer_logs WHERE student_id=:sid AND status='done_jamaah'");
    $stmt->execute(['sid' => $studentId]);
    $r = $stmt->fetch();
    $bShalatJamaah = ['points' => (int)$r['pts'], 'count' => (int)$r['cnt']];

    $stmt = $pdo->prepare("SELECT COUNT(*) FROM (SELECT prayer_date FROM prayer_logs WHERE student_id=:sid AND status IN ('done','done_jamaah') GROUP BY prayer_date HAVING COUNT(DISTINCT prayer_name)>=5) t");
    $stmt->execute(['sid' => $studentId]);
    $fullDays = (int)$stmt->fetchColumn();
    $bBonus55 = ['points' => $fullDays * 3, 'count' => $fullDays];

    $stmt = $pdo->prepare("SELECT COALESCE(SUM(wake_up_points),0) AS pts, COUNT(CASE WHEN wake_up_points>0 THEN 1 END) AS cnt FROM daily_extras WHERE student_id=:sid");
    $stmt->execute(['sid' => $studentId]);
    $r = $stmt->fetch();
    $bBangunPagi = ['points' => (int)$r['pts'], 'count' => (int)$r['cnt']];

    $stmt = $pdo->prepare("SELECT COALESCE(SUM(deeds_points),0) FROM daily_extras WHERE student_id=:sid");
    $stmt->execute(['sid' => $studentId]);
    $deedsTotal = (int)$stmt->fetchColumn();
    $stmt = $pdo->prepare("SELECT deeds FROM daily_extras WHERE student_id=:sid AND deeds_points>0");
    $stmt->execute(['sid' => $studentId]);
    $totalDeedItems = 0;
    while ($dRow = $stmt->fetch()) {
        $d = json_decode($dRow['deeds'], true);
        if (is_array($d)) $totalDeedItems += count($d);
    }
    $bKebaikan = ['points' => $deedsTotal, 'count' => $totalDeedItems];

    $stmt = $pdo->prepare("SELECT COALESCE(SUM(combo_bonus),0) AS pts, COUNT(CASE WHEN combo_bonus>0 THEN 1 END) AS cnt FROM daily_extras WHERE student_id=:sid");
    $stmt->execute(['sid' => $studentId]);
    $r = $stmt->fetch();
    $bCombo = ['points' => (int)$r['pts'], 'count' => (int)$r['cnt']];

    $stmt = $pdo->prepare("SELECT COALESCE(SUM(points_earned),0) AS pts, COUNT(*) AS cnt FROM public_speaking_logs WHERE student_id=:sid");
    $stmt->execute(['sid' => $studentId]);
    $r = $stmt->fetch();
    $bPS = ['points' => (int)$r['pts'], 'count' => (int)$r['cnt']];

    $stmt = $pdo->prepare("SELECT COALESCE(SUM(points_earned),0) AS pts, COUNT(*) AS cnt FROM kajian_logs WHERE student_id=:sid");
    $stmt->execute(['sid' => $studentId]);
    $r = $stmt->fetch();
    $bDiskusi = ['points' => (int)$r['pts'], 'count' => (int)$r['cnt']];

    // ── Leaderboard (top 10) ─────────────────────────────
    $stmt = $pdo->prepare(
        'SELECT s.id AS student_id, s.total_points, s.streak,
                u.name, u.avatar_url, c.name AS class_name
         FROM students s
         JOIN users u ON s.user_id = u.id
         LEFT JOIN classes c ON s.class_id = c.id
         WHERE u.is_active = 1
         ORDER BY s.total_points DESC, s.streak DESC
         LIMIT 10'
    );
    $stmt->execute();
    $leaderboard = $stmt->fetchAll();

    // ── Greeting ─────────────────────────────────────────
    $hour = (int) date('H');
    if ($hour < 12)      { $greeting = 'Selamat Pagi';  $greetingEmoji = '<i class="ti ti-sun text-amber-500"></i>'; }
    elseif ($hour < 15)  { $greeting = 'Selamat Siang'; $greetingEmoji = '<i class="ti ti-sun text-amber-500"></i>'; }
    elseif ($hour < 18)  { $greeting = 'Selamat Sore';  $greetingEmoji = '<i class="ti ti-cloud-sun text-amber-500"></i>'; }
    else                 { $greeting = 'Selamat Malam'; $greetingEmoji = '<i class="ti ti-moon text-blue-500"></i>'; }

    $days   = ['Minggu','Senin','Selasa','Rabu','Kamis','Jumat','Sabtu'];
    $months = ['','Januari','Februari','Maret','April','Mei','Juni',
               'Juli','Agustus','September','Oktober','November','Desember'];
    $todayFormatted = $days[(int)date('w')] . ', ' . date('j') . ' ' . $months[(int)date('n')] . ' ' . date('Y');

} catch (Exception $e) {
    $hasError = true;
}
?>
<!DOCTYPE html>
<html lang="id">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Dashboard Siswa - Sijawara</title>
    <link rel="preconnect" href="https://fonts.googleapis.com">
    <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
    <link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700;800&display=swap" rel="stylesheet">
    <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/@tabler/icons-webfont@latest/tabler-icons.min.css" />
    <script src="https://cdn.tailwindcss.com"></script>
    <script>
        tailwind.config = {
            theme: {
                extend: {
                    colors: {
                        'green-forest': '#0D6E3B',
                        'green-primary': '#1B8A4A',
                        'green-light': '#E8F5EE',
                    },
                    fontFamily: { sans: ['Inter', 'system-ui', 'sans-serif'] },
                }
            }
        }
    </script>
    <style>
        .tab-btn { transition: all 0.2s ease; }
        .tab-btn.active { color: #1B8A4A; border-color: #1B8A4A; background-color: #E8F5EE; }
        .tab-btn:not(.active) { color: #6B7280; border-color: transparent; }
        .tab-btn:not(.active):hover { color: #374151; background-color: #F9FAFB; }
        .tab-content { display: none; }
        .tab-content.active { display: block; }
        .slide-in-right { animation: slideInRight 0.3s cubic-bezier(0.4, 0, 0.2, 1) forwards; }
        .slide-in-left { animation: slideInLeft 0.3s cubic-bezier(0.4, 0, 0.2, 1) forwards; }
        @keyframes slideInRight { from { opacity: 0; transform: translateX(20px); } to { opacity: 1; transform: translateX(0); } }
        @keyframes slideInLeft { from { opacity: 0; transform: translateX(-20px); } to { opacity: 1; transform: translateX(0); } }
        .card { transition: box-shadow 0.2s ease; }
        .card:hover { box-shadow: 0 4px 12px rgba(0,0,0,0.06); }
        .skeleton { background: linear-gradient(90deg, #f3f4f6 25%, #e5e7eb 50%, #f3f4f6 75%); background-size: 200% 100%; animation: shimmer 1.5s infinite; border-radius: 8px; }
        @keyframes shimmer { 0% { background-position: 200% 0; } 100% { background-position: -200% 0; } }
        #toast { transition: opacity 0.3s ease; }
        .modal-backdrop { background-color: rgba(0,0,0,0.4); backdrop-filter: blur(4px); }
    </style>
</head>
<body class="bg-gray-50 font-sans min-h-screen">

<!-- Toast -->
<div id="toast" class="fixed top-5 left-1/2 -translate-x-1/2 z-[9999] hidden opacity-0 pointer-events-none">
    <div id="toastContent" class="flex items-center gap-3 px-5 py-3 rounded-xl shadow-lg text-sm font-medium text-white"></div>
</div>

<?php if ($hasError): ?>
<div class="flex items-center justify-center min-h-screen">
    <div class="text-center p-8">
        <div class="w-16 h-16 bg-red-100 rounded-full flex items-center justify-center mx-auto mb-4">
            <svg class="w-8 h-8 text-red-500" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2"><path stroke-linecap="round" stroke-linejoin="round" d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z"/></svg>
        </div>
        <h2 class="text-lg font-semibold text-gray-900 mb-2">Terjadi Kesalahan</h2>
        <p class="text-gray-500 text-sm mb-4">Gagal memuat data. Silakan coba lagi.</p>
        <a href="../../" class="inline-flex items-center px-4 py-2 bg-green-primary text-white text-sm font-medium rounded-lg hover:bg-green-forest transition-colors">Kembali ke Login</a>
    </div>
</div>
<?php else: ?>

<!-- ═══════════════ Navbar ═══════════════ -->
<nav class="bg-white border-b border-gray-200 sticky top-0 z-50">
    <div class="max-w-6xl mx-auto px-4 sm:px-6">
        <div class="flex items-center justify-between h-16">
            <div class="flex items-center gap-3">
                <div class="w-9 h-9 bg-green-primary rounded-lg flex items-center justify-center">
                    <svg class="w-5 h-5 text-white" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2"><path stroke-linecap="round" stroke-linejoin="round" d="M12 6.253v13m0-13C10.832 5.477 9.246 5 7.5 5S4.168 5.477 3 6.253v13C4.168 18.477 5.754 18 7.5 18s3.332.477 4.5 1.253m0-13C13.168 5.477 14.754 5 16.5 5c1.747 0 3.332.477 4.5 1.253v13C19.832 18.477 18.247 18 16.5 18c-1.746 0-3.332.477-4.5 1.253"/></svg>
                </div>
                <div>
                    <span class="text-base font-bold text-gray-900">Sijawara</span>
                    <span class="hidden sm:inline text-xs text-gray-400 ml-1.5">Dashboard Siswa</span>
                </div>
            </div>
            <div class="flex items-center gap-3">
                <div class="hidden sm:flex items-center gap-2 text-sm">
                    <?php if ($avatarUrl): ?>
                        <img src="../../<?= htmlspecialchars($avatarUrl) ?>" class="w-8 h-8 rounded-full object-cover border border-gray-200" alt="">
                    <?php else: ?>
                        <div class="w-8 h-8 bg-green-100 text-green-700 rounded-full flex items-center justify-center text-sm font-bold"><?= $initial ?></div>
                    <?php endif; ?>
                    <span class="font-medium text-gray-700"><?= htmlspecialchars($studentName) ?></span>
                </div>
                <button onclick="handleLogout()" class="inline-flex items-center gap-1.5 px-3 py-1.5 text-sm font-medium text-gray-500 hover:text-red-600 hover:bg-red-50 rounded-lg transition-colors">
                    <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2"><path stroke-linecap="round" stroke-linejoin="round" d="M17 16l4-4m0 0l-4-4m4 4H7m6 4v1a3 3 0 01-3 3H6a3 3 0 01-3-3V7a3 3 0 013-3h4a3 3 0 013 3v1"/></svg>
                    <span class="hidden sm:inline">Keluar</span>
                </button>
            </div>
        </div>
    </div>
</nav>

<!-- ═══════════════ Main Content ═══════════════ -->
<main class="max-w-6xl mx-auto px-4 sm:px-6 py-6 sm:py-8">

    <!-- Welcome -->
    <div class="mb-6">
        <div class="flex items-center gap-2 text-sm text-gray-500 mb-1">
            <span class="flex items-center justify-center"><?= $greetingEmoji ?></span>
            <span><?= $greeting ?></span>
        </div>
        <h1 class="text-2xl sm:text-3xl font-extrabold text-gray-900 tracking-tight"><?= htmlspecialchars($studentName) ?></h1>
        <p class="text-sm text-gray-400 mt-1"><?= $todayFormatted ?> · <?= htmlspecialchars($className) ?></p>
    </div>

    <!-- ═══════════════ Tabs ═══════════════ -->
    <div class="flex gap-1 mb-6 bg-white rounded-xl border border-gray-200 p-1 shadow-sm overflow-x-auto">
        <button onclick="switchTab('dashboard', 'left')" class="tab-btn active flex-1 flex items-center justify-center gap-2 px-4 py-2.5 rounded-lg text-sm font-semibold border-2 whitespace-nowrap" data-tab="dashboard">
            <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2"><path stroke-linecap="round" stroke-linejoin="round" d="M3 12l2-2m0 0l7-7 7 7M5 10v10a1 1 0 001 1h3m10-11l2 2m-2-2v10a1 1 0 01-1 1h-3m-6 0a1 1 0 001-1v-4a1 1 0 011-1h2a1 1 0 011 1v4a1 1 0 001 1m-6 0h6"/></svg>
            Dashboard
        </button>
        <button onclick="switchTab('tugas', 'right')" class="tab-btn flex-1 flex items-center justify-center gap-2 px-4 py-2.5 rounded-lg text-sm font-semibold border-2 whitespace-nowrap" data-tab="tugas">
            <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2"><path stroke-linecap="round" stroke-linejoin="round" d="M9 5H7a2 2 0 00-2 2v12a2 2 0 002 2h10a2 2 0 002-2V7a2 2 0 00-2-2h-2M9 5a2 2 0 002 2h2a2 2 0 002-2M9 5a2 2 0 012-2h2a2 2 0 012 2m-6 9l2 2 4-4"/></svg>
            Tugas
        </button>
        <button onclick="switchTab('evaluasi', 'right')" class="tab-btn flex-1 flex items-center justify-center gap-2 px-4 py-2.5 rounded-lg text-sm font-semibold border-2 whitespace-nowrap" data-tab="evaluasi">
            <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2"><path stroke-linecap="round" stroke-linejoin="round" d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z"/></svg>
            Evaluasi
        </button>
        <button onclick="switchTab('profil', 'right')" class="tab-btn flex-1 flex items-center justify-center gap-2 px-4 py-2.5 rounded-lg text-sm font-semibold border-2 whitespace-nowrap" data-tab="profil">
            <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2"><path stroke-linecap="round" stroke-linejoin="round" d="M16 7a4 4 0 11-8 0 4 4 0 018 0zM12 14a7 7 0 00-7 7h14a7 7 0 00-7-7z"/></svg>
            Profil
        </button>
    </div>

    <!-- ══════════════════════════════════════════
         TAB 1: DASHBOARD
         ══════════════════════════════════════════ -->
    <div id="tab-dashboard" class="tab-content active">

        <!-- Stats Grid -->
        <div class="grid grid-cols-1 sm:grid-cols-3 gap-4 mb-6">
            <div class="card bg-white rounded-xl border border-gray-200 shadow-sm p-5">
                <div class="flex items-center justify-between">
                    <div>
                        <p class="text-sm font-medium text-gray-500">Total Poin</p>
                        <p class="text-2xl font-extrabold text-gray-900 mt-1"><?= number_format($totalPoints) ?></p>
                    </div>
                    <div class="w-12 h-12 bg-amber-50 rounded-xl flex items-center justify-center">
                        <svg class="w-6 h-6 text-amber-500" fill="currentColor" viewBox="0 0 24 24"><path fill-rule="evenodd" d="M10.788 3.21c.448-1.077 1.976-1.077 2.424 0l2.082 5.007 5.404.433c1.164.093 1.636 1.545.749 2.305l-4.117 3.527 1.257 5.273c.271 1.136-.964 2.033-1.96 1.425L12 18.354 7.373 21.18c-.996.608-2.231-.29-1.96-1.425l1.257-5.273-4.117-3.527c-.887-.76-.415-2.212.749-2.305l5.404-.433 2.082-5.006z" clip-rule="evenodd"/></svg>
                    </div>
                </div>
            </div>
            <div class="card bg-white rounded-xl border border-gray-200 shadow-sm p-5">
                <div class="flex items-center justify-between">
                    <div>
                        <p class="text-sm font-medium text-gray-500">Streak</p>
                        <p class="text-2xl font-extrabold text-gray-900 mt-1"><?= $streak ?> <span class="text-base font-medium text-gray-400">hari</span></p>
                    </div>
                    <div class="w-12 h-12 bg-red-50 rounded-xl flex items-center justify-center">
                        <svg class="w-6 h-6 text-red-500" fill="currentColor" viewBox="0 0 24 24"><path fill-rule="evenodd" d="M12.963 2.286a.75.75 0 00-1.071-.136 9.742 9.742 0 00-3.539 6.177A7.547 7.547 0 016.648 6.61a.75.75 0 00-1.152-.082A9 9 0 1015.68 4.534a7.46 7.46 0 01-2.717-2.248zM15.75 14.25a3.75 3.75 0 11-7.313-1.172c.628.465 1.35.81 2.133 1a5.99 5.99 0 011.925-3.545 3.75 3.75 0 013.255 3.717z" clip-rule="evenodd"/></svg>
                    </div>
                </div>
            </div>
            <div class="card bg-white rounded-xl border border-gray-200 shadow-sm p-5">
                <div class="flex items-center justify-between">
                    <div>
                        <p class="text-sm font-medium text-gray-500">Shalat Hari Ini</p>
                        <p class="text-2xl font-extrabold text-gray-900 mt-1"><?= $doneToday ?><span class="text-base font-medium text-gray-400">/5</span></p>
                    </div>
                    <div class="w-12 h-12 bg-green-50 rounded-xl flex items-center justify-center">
                        <svg class="w-6 h-6 text-green-600" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2"><path stroke-linecap="round" stroke-linejoin="round" d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z"/></svg>
                    </div>
                </div>
                <div class="mt-3 h-2 bg-gray-100 rounded-full overflow-hidden">
                    <div class="h-full bg-green-600 rounded-full transition-all duration-500" style="width: <?= ($doneToday / 5) * 100 ?>%"></div>
                </div>
            </div>
        </div>

        <!-- Two-Column: Prayers + Leaderboard -->
        <div class="grid grid-cols-1 lg:grid-cols-5 gap-6 mb-6">
            <!-- Shalat Hari Ini -->
            <div class="lg:col-span-3 card bg-white rounded-xl border border-gray-200 shadow-sm">
                <div class="p-5 border-b border-gray-100">
                    <div class="flex items-center justify-between">
                        <h2 class="text-base font-semibold text-gray-900 flex items-center gap-2">
                            <svg class="w-5 h-5 text-green-600" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2"><path stroke-linecap="round" stroke-linejoin="round" d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z"/></svg>
                            Shalat Hari Ini
                        </h2>
                        <span class="text-xs font-medium text-gray-400"><?= $todayFormatted ?></span>
                    </div>
                </div>
                <div class="divide-y divide-gray-50">
                    <?php foreach ($prayerNames as $i => $pName):
                        $p = $prayers[$pName] ?? null;
                        $status = $p['status'] ?? null;
                        $pts = $p['points'] ?? 0;
                        if ($status === 'done_jamaah') { $statusLabel = "Jama'ah"; $statusClass = 'bg-green-600 text-white'; }
                        elseif ($status === 'done') { $statusLabel = 'Sendiri'; $statusClass = 'bg-green-50 text-green-700'; }
                        else { $statusLabel = 'Belum'; $statusClass = 'bg-gray-100 text-gray-400'; }
                    ?>
                    <div class="flex items-center justify-between px-5 py-3.5 hover:bg-gray-50/50 transition-colors">
                    <div class="flex items-center gap-3">
                        <span class="w-6 h-6 flex items-center justify-center"><?= $prayerIcons[$i] ?></span>
                        <span class="text-sm font-medium text-gray-900"><?= $prayerLabels[$i] ?></span>
                        </div>
                        <div class="flex items-center gap-3">
                            <?php if ($pts > 0): ?><span class="text-xs font-medium text-gray-400">+<?= $pts ?> poin</span><?php endif; ?>
                            <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-semibold <?= $statusClass ?>"><?= $statusLabel ?></span>
                        </div>
                    </div>
                    <?php endforeach; ?>
                </div>
                <?php if ($wakeUpTime || !empty($deeds)): ?>
                <div class="px-5 py-3.5 border-t border-gray-100 bg-gray-50/50 space-y-1.5">
                    <?php if ($wakeUpTime): ?>
                <div class="flex items-center gap-2 text-xs text-gray-500">
                    <i class="ti ti-alarm text-blue-500 text-base"></i>
                    <span>Bangun pagi: <strong class="text-gray-700"><?= htmlspecialchars($wakeUpTime) ?></strong></span>
                </div>
                <?php endif; ?>
                <?php if (!empty($deeds)): ?>
                <div class="flex items-start gap-2 text-xs text-gray-500">
                    <i class="ti ti-heart-handshake text-pink-500 text-base mt-0.5"></i>
                    <span>Amal: <?= htmlspecialchars(implode(', ', $deeds)) ?></span>
                </div>
                <?php endif; ?>
            </div>
            <?php endif; ?>
            </div>

            <!-- Leaderboard -->
            <div class="lg:col-span-2 card bg-white rounded-xl border border-gray-200 shadow-sm">
                <div class="p-5 border-b border-gray-100">
                    <h2 class="text-base font-semibold text-gray-900 flex items-center gap-2">
                        <svg class="w-5 h-5 text-amber-500" fill="currentColor" viewBox="0 0 24 24"><path fill-rule="evenodd" d="M5.166 2.621v.858c-1.035.148-2.059.33-3.071.543a.75.75 0 00-.584.859 6.753 6.753 0 006.138 5.6 6.73 6.73 0 002.743 1.346A6.707 6.707 0 019.279 15H8.54c-1.036 0-1.875.84-1.875 1.875V19.5h-.375a.75.75 0 000 1.5h11.25a.75.75 0 000-1.5h-.375v-2.625c0-1.036-.84-1.875-1.875-1.875h-.74a6.707 6.707 0 01-1.112-3.173 6.73 6.73 0 002.743-1.347 6.753 6.753 0 006.139-5.6.75.75 0 00-.585-.858 47.077 47.077 0 00-3.07-.543V2.62a.75.75 0 00-.658-.744 49.22 49.22 0 00-6.093-.377c-2.063 0-4.096.128-6.093.377a.75.75 0 00-.657.744z" clip-rule="evenodd"/></svg>
                        Leaderboard
                    </h2>
                </div>
                <div class="divide-y divide-gray-50 max-h-96 overflow-y-auto">
                    <?php if (empty($leaderboard)): ?>
                        <div class="p-8 text-center text-sm text-gray-400">Belum ada data</div>
                    <?php endif; ?>
                    <?php foreach ($leaderboard as $idx => $lb):
                    $rank      = $idx + 1;
                    $isMe      = ((int) $lb['student_id'] === $studentId);
                    $lbInitial = mb_strtoupper(mb_substr($lb['name'], 0, 1));
                    $medal     = '';
                    if ($rank === 1) $medal = '<i class="ti ti-medal text-amber-400 text-xl"></i>';
                    elseif ($rank === 2) $medal = '<i class="ti ti-medal text-gray-400 text-xl"></i>';
                    elseif ($rank === 3) $medal = '<i class="ti ti-medal text-amber-700 text-xl"></i>';
                ?>
                <div class="flex items-center gap-3 px-5 py-3 <?= $isMe ? 'bg-green-50/70' : 'hover:bg-gray-50/50' ?> transition-colors">
                    <span class="w-7 flex items-center justify-center text-sm font-bold <?= $isMe ? 'text-green-700' : 'text-gray-400' ?>">
                        <?= $medal ?: $rank ?>
                    </span>
                    <?php if ($lb['avatar_url']): ?>
                        <img src="../../<?= htmlspecialchars($lb['avatar_url']) ?>" class="w-8 h-8 rounded-full object-cover border border-gray-200" alt="">
                    <?php else: ?>
                        <div class="w-8 h-8 <?= $isMe ? 'bg-green-200 text-green-800' : 'bg-gray-100 text-gray-500' ?> rounded-full flex items-center justify-center text-xs font-bold"><?= $lbInitial ?></div>
                    <?php endif; ?>
                        <div class="flex-1 min-w-0">
                            <p class="text-sm font-medium <?= $isMe ? 'text-green-900' : 'text-gray-900' ?> truncate"><?= htmlspecialchars($lb['name']) ?> <?php if ($isMe): ?><span class="text-xs text-green-600 font-semibold">(Kamu)</span><?php endif; ?></p>
                            <p class="text-xs text-gray-400"><?= htmlspecialchars($lb['class_name'] ?? '-') ?></p>
                        </div>
                        <div class="text-right flex-shrink-0">
                            <span class="text-sm font-bold <?= $isMe ? 'text-green-700' : 'text-gray-900' ?>"><?= number_format((int)$lb['total_points']) ?></span>
                            <span class="text-xs text-gray-400 block">poin</span>
                        </div>
                    </div>
                    <?php endforeach; ?>
                </div>
            </div>
        </div>

        <!-- Points Breakdown -->
        <div class="card bg-white rounded-xl border border-gray-200 shadow-sm">
            <div class="p-5 border-b border-gray-100">
                <div class="flex items-center justify-between">
                    <h2 class="text-base font-semibold text-gray-900 flex items-center gap-2">
                        <svg class="w-5 h-5 text-green-600" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2"><path stroke-linecap="round" stroke-linejoin="round" d="M9 19v-6a2 2 0 00-2-2H5a2 2 0 00-2 2v6a2 2 0 002 2h2a2 2 0 002-2zm0 0V9a2 2 0 012-2h2a2 2 0 012 2v10m-6 0a2 2 0 002 2h2a2 2 0 002-2m0 0V5a2 2 0 012-2h2a2 2 0 012 2v14a2 2 0 01-2 2h-2a2 2 0 01-2-2z"/></svg>
                        Rincian Poin
                    </h2>
                    <span class="inline-flex items-center px-3 py-1 rounded-full text-sm font-bold bg-amber-50 text-amber-700 border border-amber-200"><?= number_format($totalPoints) ?> poin</span>
                </div>
            </div>
            <div class="p-5 space-y-5">
                <!-- Shalat -->
                <div>
                    <div class="flex items-center gap-2 mb-3"><div class="h-5 w-1 bg-green-600 rounded-full"></div><h3 class="text-sm font-semibold text-green-700">Shalat</h3><div class="flex-1 h-px bg-green-100"></div></div>
                    <!-- Shalat Sendiri -->
                    <div class="flex items-center justify-between py-2.5 px-3 rounded-lg hover:bg-gray-50 transition-colors">
                        <div class="flex items-center gap-3">
                            <i class="ti ti-user text-green-600 text-xl w-6 text-center"></i>
                            <div>
                                <p class="text-sm font-medium text-gray-900">Shalat Sendiri</p>
                                <p class="text-xs text-gray-400">1 poin per shalat · <?= $bShalatSendiri['count'] ?> kali</p></div></div><span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-bold bg-green-50 text-green-700">+<?= $bShalatSendiri['points'] ?></span></div>
                        <div class="flex items-center justify-between py-2.5 px-3 rounded-lg hover:bg-gray-50"><div class="flex items-center gap-3"><i class="ti ti-users text-green-600 text-xl w-6 text-center"></i><div><p class="text-sm font-medium text-gray-900">Shalat Jama'ah</p><p class="text-xs text-gray-400">2 poin per shalat · <?= $bShalatJamaah['count'] ?> kali</p></div></div><span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-bold bg-green-50 text-green-700">+<?= $bShalatJamaah['points'] ?></span></div>
                </div>
                <!-- Bonus -->
                <div>
                    <div class="flex items-center gap-2 mb-3"><div class="h-5 w-1 bg-amber-500 rounded-full"></div><h3 class="text-sm font-semibold text-amber-700">Bonus & Extras</h3><div class="flex-1 h-px bg-amber-100"></div></div>
                    <!-- Bonus 5/5 -->
                    <div class="flex items-center justify-between py-2.5 px-3 rounded-lg hover:bg-gray-50 transition-colors">
                        <div class="flex items-center gap-3">
                            <i class="ti ti-trophy text-amber-500 text-xl w-6 text-center"></i>
                            <div>
                                <p class="text-sm font-medium text-gray-900">Bonus 5/5 Shalat</p>
                                <p class="text-xs text-gray-400">+3 poin saat 5 shalat tercatat · <?= $bBonus55['count'] ?> hari</p></div></div><span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-bold bg-amber-50 text-amber-700">+<?= $bBonus55['points'] ?></span></div>
                    <!-- Bangun Pagi -->
                    <div class="flex items-center justify-between py-2.5 px-3 rounded-lg hover:bg-gray-50 transition-colors">
                        <div class="flex items-center gap-3">
                            <i class="ti ti-alarm text-blue-500 text-xl w-6 text-center"></i>
                            <div>
                                <p class="text-sm font-medium text-gray-900">Bangun Pagi</p>
                                <p class="text-xs text-gray-400">+1 poin bangun 03:00–04:00 · <?= $bBangunPagi['count'] ?> hari</p></div></div><span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-bold bg-blue-50 text-blue-700">+<?= $bBangunPagi['points'] ?></span></div>
                        <div class="flex items-center justify-between py-2.5 px-3 rounded-lg hover:bg-gray-50"><div class="flex items-center gap-3"><i class="ti ti-heart-handshake text-pink-500 text-xl w-6 text-center"></i><div><p class="text-sm font-medium text-gray-900">Kebaikan</p><p class="text-xs text-gray-400">+1 poin per amal baik · <?= $bKebaikan['count'] ?> amal</p></div></div><span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-bold bg-pink-50 text-pink-700">+<?= $bKebaikan['points'] ?></span></div>
                        <div class="flex items-center justify-between py-2.5 px-3 rounded-lg hover:bg-gray-50"><div class="flex items-center gap-3"><i class="ti ti-target text-purple-500 text-xl w-6 text-center"></i><div><p class="text-sm font-medium text-gray-900">Combo Bonus</p><p class="text-xs text-gray-400">+3 poin kombinasi harian · <?= $bCombo['count'] ?> hari</p></div></div><span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-bold bg-purple-50 text-purple-700">+<?= $bCombo['points'] ?></span></div>
                        <?php if ($bPS['count'] > 0): ?>
                        <div class="flex items-center justify-between py-2.5 px-3 rounded-lg hover:bg-gray-50"><div class="flex items-center gap-3"><i class="ti ti-microphone text-indigo-500 text-xl w-6 text-center"></i><div><p class="text-sm font-medium text-gray-900">Public Speaking</p><p class="text-xs text-gray-400">+2 poin per sesi · <?= $bPS['count'] ?> sesi</p></div></div><span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-bold bg-indigo-50 text-indigo-700">+<?= $bPS['points'] ?></span></div>
                        <?php endif; ?>
                        <?php if ($bDiskusi['count'] > 0): ?>
                        <div class="flex items-center justify-between py-2.5 px-3 rounded-lg hover:bg-gray-50"><div class="flex items-center gap-3"><i class="ti ti-message-circle text-teal-500 text-xl w-6 text-center"></i><div><p class="text-sm font-medium text-gray-900">Diskusi</p><p class="text-xs text-gray-400">+2 poin per kajian · <?= $bDiskusi['count'] ?> kajian</p></div></div><span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-bold bg-teal-50 text-teal-700">+<?= $bDiskusi['points'] ?></span></div>
                        <?php endif; ?>
                </div>
                <!-- Streak -->
                <div class="border-t border-gray-100 pt-4">
                <div class="flex items-center justify-between bg-red-50 border border-red-100 rounded-lg p-4">
                    <div class="flex items-center gap-3">
                        <i class="ti ti-flame text-red-500 text-2xl"></i>
                        <div>
                            <p class="text-sm font-semibold text-gray-900">Streak: <?= $streak ?> hari berturut-turut</p><p class="text-xs text-gray-500">Terus semangat menjaga streak!</p></div></div></div>
                </div>
                <!-- Info Box -->
                <div class="bg-green-50 border border-green-200 rounded-lg p-4">
                    <div class="flex items-start gap-3">
                        <svg class="w-5 h-5 text-green-600 mt-0.5 flex-shrink-0" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2"><path stroke-linecap="round" stroke-linejoin="round" d="M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"/></svg>
                        <p class="text-xs text-green-800 leading-relaxed">Poin dihitung dari rekap shalat harian, bonus kehadiran penuh, bangun pagi, amal kebaikan, dan aktivitas lainnya. Catat shalatmu melalui aplikasi <strong>Sijawara</strong>.</p>
                    </div>
                </div>
            </div>
        </div>
    </div>

    <!-- ══════════════════════════════════════════
         TAB 2: TUGAS
         ══════════════════════════════════════════ -->
    <div id="tab-tugas" class="tab-content">
        <h2 class="text-lg font-bold text-gray-900 mb-4" id="tugas-menu-title">Pilih Materi Tugas</h2>
        <div class="space-y-4 mb-6" id="tugas-menu-cards">
            <!-- Diskusi Card -->
            <div onclick="loadTugasDetail('diskusi')" class="card bg-white rounded-xl border border-gray-200 shadow-sm p-5 cursor-pointer hover:border-green-300 transition-colors">
                <div class="flex items-center gap-4">
                    <div class="w-14 h-14 bg-purple-50 rounded-full flex items-center justify-center flex-shrink-0">
                        <svg class="w-7 h-7 text-purple-600" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2"><path stroke-linecap="round" stroke-linejoin="round" d="M12 6.253v13m0-13C10.832 5.477 9.246 5 7.5 5S4.168 5.477 3 6.253v13C4.168 18.477 5.754 18 7.5 18s3.332.477 4.5 1.253m0-13C13.168 5.477 14.754 5 16.5 5c1.747 0 3.332.477 4.5 1.253v13C19.832 18.477 18.247 18 16.5 18c-1.746 0-3.332.477-4.5 1.253"/></svg>
                    </div>
                    <div class="flex-1">
                        <p class="text-base font-bold text-gray-900">Diskusi Keislaman dan Kebangsaan</p>
                        <p class="text-sm text-gray-500 mt-0.5">Catatan diskusi kajian keislaman</p>
                    </div>
                    <svg class="w-5 h-5 text-gray-400" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2"><path stroke-linecap="round" stroke-linejoin="round" d="M9 5l7 7-7 7"/></svg>
                </div>
            </div>
            <!-- Public Speaking Card -->
            <div onclick="loadTugasDetail('public_speaking')" class="card bg-white rounded-xl border border-gray-200 shadow-sm p-5 cursor-pointer hover:border-green-300 transition-colors">
                <div class="flex items-center gap-4">
                    <div class="w-14 h-14 bg-teal-50 rounded-full flex items-center justify-center flex-shrink-0">
                        <svg class="w-7 h-7 text-teal-600" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2"><path stroke-linecap="round" stroke-linejoin="round" d="M19 11a7 7 0 01-7 7m0 0a7 7 0 01-7-7m7 7v4m0 0H8m4 0h4m-4-8a3 3 0 01-3-3V5a3 3 0 116 0v6a3 3 0 01-3 3z"/></svg>
                    </div>
                    <div class="flex-1">
                        <p class="text-base font-bold text-gray-900">Public Speaking</p>
                        <p class="text-sm text-gray-500 mt-0.5">Catatan sesi public speaking</p>
                    </div>
                    <svg class="w-5 h-5 text-gray-400" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2"><path stroke-linecap="round" stroke-linejoin="round" d="M9 5l7 7-7 7"/></svg>
                </div>
            </div>
        </div>

        <!-- Tugas detail container (populated via AJAX) -->
        <div id="tugas-detail" class="hidden">
            <button onclick="closeTugasDetail()" class="inline-flex items-center gap-1.5 text-sm font-medium text-gray-500 hover:text-gray-700 mb-4 transition-colors">
                <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2"><path stroke-linecap="round" stroke-linejoin="round" d="M15 19l-7-7 7-7"/></svg>
                Kembali
            </button>
            <div id="tugas-detail-title" class="text-lg font-bold text-gray-900 mb-4"></div>
            <div id="tugas-detail-content"></div>
        </div>
    </div>

    <!-- ══════════════════════════════════════════
         TAB 3: EVALUASI
         ══════════════════════════════════════════ -->
    <div id="tab-evaluasi" class="tab-content">
        <div id="evaluasi-loading" class="hidden">
            <div class="space-y-4"><?php for ($i = 0; $i < 3; $i++): ?><div class="skeleton h-24 w-full"></div><?php endfor; ?></div>
        </div>
        <div id="evaluasi-content"></div>
        <div id="evaluasi-empty" class="hidden text-center py-16">
            <svg class="w-16 h-16 text-gray-200 mx-auto mb-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="1"><path stroke-linecap="round" stroke-linejoin="round" d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z"/></svg>
            <p class="text-base font-semibold text-gray-400 mb-1">Belum ada evaluasi</p>
            <p class="text-sm text-gray-400">Evaluasi dari guru akan tampil di sini</p>
        </div>
        <div id="evaluasi-error" class="hidden text-center py-16">
            <svg class="w-12 h-12 text-gray-300 mx-auto mb-3" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="1.5"><path stroke-linecap="round" stroke-linejoin="round" d="M12 9v2m0 4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"/></svg>
            <p class="text-sm text-gray-500 mb-3">Gagal memuat evaluasi</p>
            <button onclick="loadEvaluasi()" class="text-sm text-green-primary font-medium hover:underline">Coba Lagi</button>
        </div>
    </div>

    <!-- ══════════════════════════════════════════
         TAB 4: PROFIL
         ══════════════════════════════════════════ -->
    <div id="tab-profil" class="tab-content">
        <div id="profil-loading" class="hidden">
            <div class="space-y-4"><div class="skeleton h-48 w-full"></div><div class="skeleton h-64 w-full"></div><div class="skeleton h-48 w-full"></div></div>
        </div>
        <div id="profil-content" class="hidden"></div>
    </div>

</main>

<!-- Footer -->
<footer class="border-t border-gray-200 bg-white py-6 text-center">
    <p class="text-xs text-gray-400">&copy; <?= date('Y') ?> Sijawara &middot; SMA Muhammadiyah Al Kautsar Program Khusus</p>
</footer>

<?php endif; ?>

<!-- ═══════════════════════════════════════════════
     EVALUASI DETAIL MODAL
     ═══════════════════════════════════════════════ -->
<div id="evalModal" class="fixed inset-0 z-[100] hidden items-center justify-center p-4">
    <div class="modal-backdrop absolute inset-0" onclick="closeEvalModal()"></div>
    <div class="relative bg-white rounded-2xl shadow-2xl w-full max-w-lg max-h-[80vh] overflow-y-auto z-10">
        <div class="sticky top-0 bg-white border-b border-gray-100 p-5 rounded-t-2xl flex items-center justify-between">
            <h3 id="evalModalTitle" class="text-base font-bold text-gray-900"></h3>
            <button onclick="closeEvalModal()" class="w-8 h-8 rounded-lg bg-gray-100 hover:bg-gray-200 flex items-center justify-center transition-colors">
                <svg class="w-4 h-4 text-gray-500" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2"><path stroke-linecap="round" stroke-linejoin="round" d="M6 18L18 6M6 6l12 12"/></svg>
            </button>
        </div>
        <div id="evalModalBody" class="p-5"></div>
    </div>
</div>

<!-- ═══════════════ CHANGE PASSWORD MODAL ═══════════════ -->
<div id="pwModal" class="fixed inset-0 z-[100] hidden items-center justify-center p-4">
    <div class="modal-backdrop absolute inset-0" onclick="closePwModal()"></div>
    <div class="relative bg-white rounded-2xl shadow-2xl w-full max-w-sm z-10 p-6">
        <h3 class="text-base font-bold text-gray-900 mb-4">Ubah Kata Sandi</h3>
        <div class="space-y-3">
            <div>
                <label class="block text-sm font-medium text-gray-700 mb-1">Password Lama</label>
                <input id="pwOld" type="password" class="w-full border border-gray-200 rounded-lg px-3.5 py-2.5 text-sm focus:outline-none focus:ring-2 focus:ring-green-primary/20 focus:border-green-primary" placeholder="Masukkan password lama">
            </div>
            <div>
                <label class="block text-sm font-medium text-gray-700 mb-1">Password Baru</label>
                <input id="pwNew" type="password" class="w-full border border-gray-200 rounded-lg px-3.5 py-2.5 text-sm focus:outline-none focus:ring-2 focus:ring-green-primary/20 focus:border-green-primary" placeholder="Minimal 6 karakter">
            </div>
            <p id="pwError" class="text-xs text-red-500 hidden"></p>
        </div>
        <div class="flex gap-3 mt-5">
            <button onclick="closePwModal()" class="flex-1 py-2.5 text-sm font-medium text-gray-600 bg-gray-100 rounded-lg hover:bg-gray-200 transition-colors">Batal</button>
            <button onclick="submitChangePassword()" id="pwSubmitBtn" class="flex-1 py-2.5 text-sm font-semibold text-white bg-green-primary rounded-lg hover:bg-green-forest transition-colors disabled:opacity-50" disabled>Simpan</button>
        </div>
    </div>
</div>

<script>
const API_URL = '../../config/web/siswa_data.php';
let evaluasiLoaded = false;
let profilLoaded = false;
let currentTugasType = null;

// ═══════════════ TAB SWITCHING ═══════════════
const tabsList = ['dashboard', 'tugas', 'evaluasi', 'profil'];
let currentActiveTab = 'dashboard';

function switchTab(tab, manualDirection = 'right') {
    if (tab === currentActiveTab) return;
    
    // Auto-detect direction based on tab order
    const oldIdx = tabsList.indexOf(currentActiveTab);
    const newIdx = tabsList.indexOf(tab);
    const direction = (oldIdx !== -1 && newIdx !== -1) ? (newIdx > oldIdx ? 'right' : 'left') : manualDirection;
    
    currentActiveTab = tab;

    document.querySelectorAll('.tab-btn').forEach(b => b.classList.remove('active'));
    document.querySelector(`[data-tab="${tab}"]`).classList.add('active');
    
    document.querySelectorAll('.tab-content').forEach(c => {
        c.classList.remove('active', 'slide-in-left', 'slide-in-right');
    });
    
    const target = document.getElementById('tab-' + tab);
    target.classList.add('active');
    
    if (direction === 'left') {
        target.classList.add('slide-in-left');
    } else {
        target.classList.add('slide-in-right');
    }

    if (tab === 'evaluasi' && !evaluasiLoaded) loadEvaluasi();
    if (tab === 'profil' && !profilLoaded) loadProfil();
}

// ═══════════════ TOAST ═══════════════
function showToast(msg, isError = true) {
    const toast = document.getElementById('toast');
    const content = document.getElementById('toastContent');
    content.className = `flex items-center gap-3 px-5 py-3 rounded-xl shadow-lg text-sm font-medium text-white ${isError ? 'bg-red-500' : 'bg-green-primary'}`;
    content.textContent = msg;
    toast.classList.remove('hidden', 'opacity-0', 'pointer-events-none');
    setTimeout(() => { toast.classList.add('opacity-0'); setTimeout(() => toast.classList.add('hidden', 'pointer-events-none'), 300); }, 4000);
}

// ═══════════════ LOGOUT ═══════════════
async function handleLogout() {
    if (!confirm('Yakin ingin keluar?')) return;
    try { await fetch('../../config/web/siswa_auth.php', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ action: 'logout' }) }); } catch (e) {}
    window.location.href = '../../';
}

// ═══════════════ TUGAS ═══════════════
async function loadTugasDetail(type) {
    currentTugasType = type;
    const title = type === 'diskusi' ? 'Diskusi Keislaman dan Kebangsaan' : 'Public Speaking';
    const action = type === 'diskusi' ? 'tugas_diskusi' : 'tugas_public_speaking';

    document.getElementById('tugas-detail').classList.remove('hidden');
    document.getElementById('tugas-detail-title').textContent = title;
    document.getElementById('tugas-detail-content').innerHTML = '<div class="space-y-3"><div class="skeleton h-20 w-full"></div><div class="skeleton h-20 w-full"></div><div class="skeleton h-20 w-full"></div></div>';

    document.getElementById('tugas-menu-title').classList.add('hidden');
    document.getElementById('tugas-menu-cards').classList.add('hidden');

    try {
        const res = await fetch(API_URL, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ action }) });
        const data = await res.json();

        if (!data.success) throw new Error(data.message || 'Gagal memuat');

        if (data.data.length === 0) {
            document.getElementById('tugas-detail-content').innerHTML = `
                <div class="text-center py-16">
                    <svg class="w-16 h-16 text-gray-200 mx-auto mb-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="1"><path stroke-linecap="round" stroke-linejoin="round" d="M9 5H7a2 2 0 00-2 2v12a2 2 0 002 2h10a2 2 0 002-2V7a2 2 0 00-2-2h-2M9 5a2 2 0 002 2h2a2 2 0 002-2M9 5a2 2 0 012-2h2a2 2 0 012 2"/></svg>
                    <p class="text-base font-semibold text-gray-400 mb-1">Belum ada catatan</p>
                    <p class="text-sm text-gray-400">Catatan ${title.toLowerCase()} kamu akan muncul di sini</p>
                </div>`;
            return;
        }

        let html = '<div class="space-y-3">';
        data.data.forEach(item => {
            const iconColor = type === 'diskusi' ? 'purple' : 'teal';
            const dateFormatted = formatDate(item.date);
            html += `
            <div class="card bg-white rounded-xl border border-gray-200 shadow-sm p-4 hover:border-green-200 transition-colors">
                <div class="flex items-start gap-3">
                    <div class="w-10 h-10 bg-${iconColor}-50 rounded-lg flex items-center justify-center flex-shrink-0 mt-0.5">
                        <svg class="w-5 h-5 text-${iconColor}-600" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2"><path stroke-linecap="round" stroke-linejoin="round" d="M9 5H7a2 2 0 00-2 2v12a2 2 0 002 2h10a2 2 0 002-2V7a2 2 0 00-2-2h-2M9 5a2 2 0 002 2h2a2 2 0 002-2M9 5a2 2 0 012-2h2a2 2 0 012 2m-6 9l2 2 4-4"/></svg>
                    </div>
                    <div class="flex-1 min-w-0">
                        <div class="flex items-center justify-between mb-1">
                            <p class="text-sm font-semibold text-gray-900 truncate">${escapeHtml(item.materi || item.title || 'Tanpa Judul')}</p>
                            ${item.points > 0 ? `<span class="inline-flex items-center px-2 py-0.5 rounded-full text-xs font-bold bg-green-50 text-green-700 flex-shrink-0 ml-2">+${item.points}</span>` : ''}
                        </div>
                        <p class="text-xs text-gray-400 mb-1">${dateFormatted}${item.mentor ? ' &middot; Mentor: ' + escapeHtml(item.mentor) : ''}</p>
                        ${item.note ? `<p class="text-xs text-gray-500 line-clamp-2">${escapeHtml(item.note)}</p>` : ''}
                    </div>
                </div>
            </div>`;
        });
        html += '</div>';
        document.getElementById('tugas-detail-content').innerHTML = html;

    } catch (e) {
        document.getElementById('tugas-detail-content').innerHTML = `
            <div class="text-center py-12">
                <p class="text-sm text-gray-500 mb-3">Gagal memuat data</p>
                <button onclick="loadTugasDetail('${type}')" class="text-sm text-green-primary font-medium hover:underline">Coba Lagi</button>
            </div>`;
    }
}

function closeTugasDetail() {
    document.getElementById('tugas-detail').classList.add('hidden');
    document.getElementById('tugas-menu-title').classList.remove('hidden');
    document.getElementById('tugas-menu-cards').classList.remove('hidden');
    currentTugasType = null;
}

// ═══════════════ EVALUASI ═══════════════
async function loadEvaluasi() {
    const loading = document.getElementById('evaluasi-loading');
    const content = document.getElementById('evaluasi-content');
    const empty   = document.getElementById('evaluasi-empty');
    const error   = document.getElementById('evaluasi-error');

    loading.classList.remove('hidden'); content.innerHTML = ''; empty.classList.add('hidden'); error.classList.add('hidden');

    try {
        const res = await fetch(API_URL, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ action: 'evaluasi_list' }) });
        const data = await res.json();
        loading.classList.add('hidden');

        if (!data.success) throw new Error(data.message);

        if (data.data.length === 0) {
            empty.classList.remove('hidden');
            evaluasiLoaded = true;
            return;
        }

        let html = '<div class="space-y-3">';
        data.data.forEach(ev => {
            const ordinals = ['','Pertama','Kedua','Ketiga','Keempat','Kelima','Keenam','Ketujuh','Kedelapan','Kesembilan','Kesepuluh','Kesebelas','Kedua Belas'];
            const title = 'Laporan Evaluasi ' + (ordinals[ev.evaluasi_number] || ('Ke-' + ev.evaluasi_number));
            html += `
            <div onclick="showEvalDetail(${ev.id})" class="card bg-white rounded-xl border border-gray-200 shadow-sm p-4 cursor-pointer hover:border-green-200 transition-colors">
                <div class="flex items-center gap-3.5">
                    <div class="w-11 h-11 bg-blue-50 rounded-xl flex items-center justify-center flex-shrink-0">
                        <svg class="w-5 h-5 text-blue-600" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2"><path stroke-linecap="round" stroke-linejoin="round" d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z"/></svg>
                    </div>
                    <div class="flex-1 min-w-0">
                        <p class="text-sm font-bold text-gray-900">${escapeHtml(title)}</p>
                        <p class="text-xs text-gray-500 mt-0.5">${escapeHtml(ev.bulan)}</p>
                        ${ev.guru_name ? `<div class="flex items-center gap-1 mt-1"><svg class="w-3 h-3 text-green-600" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2"><path stroke-linecap="round" stroke-linejoin="round" d="M16 7a4 4 0 11-8 0 4 4 0 018 0zM12 14a7 7 0 00-7 7h14a7 7 0 00-7-7z"/></svg><span class="text-xs font-medium text-green-700">${escapeHtml(ev.guru_name)}</span></div>` : ''}
                    </div>
                    <svg class="w-5 h-5 text-gray-400 flex-shrink-0" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2"><path stroke-linecap="round" stroke-linejoin="round" d="M9 5l7 7-7 7"/></svg>
                </div>
            </div>`;
        });
        html += '</div>';
        content.innerHTML = html;
        evaluasiLoaded = true;

    } catch (e) {
        loading.classList.add('hidden');
        error.classList.remove('hidden');
    }
}

async function showEvalDetail(id) {
    const modal = document.getElementById('evalModal');
    const title = document.getElementById('evalModalTitle');
    const body  = document.getElementById('evalModalBody');

    modal.classList.remove('hidden'); modal.classList.add('flex');
    title.textContent = 'Memuat...';
    body.innerHTML = '<div class="flex justify-center py-8"><div class="w-8 h-8 border-2 border-green-primary border-t-transparent rounded-full animate-spin"></div></div>';

    try {
        const res = await fetch(API_URL, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ action: 'evaluasi_detail', id }) });
        const data = await res.json();
        if (!data.success) throw new Error(data.message);

        const ev = data.data;
        const ordinals = ['','Pertama','Kedua','Ketiga','Keempat','Kelima','Keenam','Ketujuh','Kedelapan','Kesembilan','Kesepuluh','Kesebelas','Kedua Belas'];
        title.textContent = 'Laporan Evaluasi ' + (ordinals[ev.evaluasi_number] || ('Ke-' + ev.evaluasi_number));

        let nilai = {};
        try { nilai = typeof ev.nilai_data === 'string' ? JSON.parse(ev.nilai_data) : (ev.nilai_data || {}); } catch(e) {}
        let ket = {};
        try { ket = typeof ev.keterangan_data === 'string' ? JSON.parse(ev.keterangan_data) : (ev.keterangan_data || {}); } catch(e) {}

        let html = `
            <div class="mb-4 flex items-center gap-2 text-sm text-gray-500">
                <span class="flex items-center gap-1.5"><i class="ti ti-calendar text-gray-500 text-base"></i> ${escapeHtml(ev.bulan)}</span>
                ${ev.guru_name ? `<span>&middot; Guru: <strong class="text-green-700">${escapeHtml(ev.guru_name)}</strong></span>` : ''}
            </div>
            <div class="space-y-2">`;

        const nilaiColors = { 'A': 'bg-green-100 text-green-800', 'B': 'bg-blue-100 text-blue-800', 'C': 'bg-amber-100 text-amber-800', 'D': 'bg-red-100 text-red-800' };
        Object.keys(nilai).forEach(key => {
            const val = nilai[key];
            const ketText = ket[key] || '';
            const colorClass = nilaiColors[val] || 'bg-gray-100 text-gray-700';
            html += `
                <div class="flex items-center justify-between py-3 px-3 rounded-lg hover:bg-gray-50 border border-gray-100">
                    <div class="flex-1 min-w-0 pr-2">
                        <p class="text-sm font-medium text-gray-900">${escapeHtml(key)}</p>
                        ${ketText ? `<p class="text-xs text-gray-500 mt-0.5">${escapeHtml(ketText)}</p>` : ''}
                    </div>
                    <span class="inline-flex items-center justify-center w-8 h-8 rounded-lg text-sm font-bold ${colorClass}">${escapeHtml(val)}</span>
                </div>`;
        });
        html += '</div>';

        if (ev.catatan) {
            html += `
            <div class="mt-4 bg-amber-50 border border-amber-200 rounded-lg p-4">
                <p class="text-xs font-semibold text-amber-700 mb-1">Catatan Guru</p>
                <p class="text-sm text-amber-900">${escapeHtml(ev.catatan)}</p>
            </div>`;
        }

        body.innerHTML = html;

    } catch (e) {
        title.textContent = 'Error';
        body.innerHTML = '<p class="text-sm text-gray-500 text-center py-8">Gagal memuat detail evaluasi</p>';
    }
}

function closeEvalModal() {
    const modal = document.getElementById('evalModal');
    modal.classList.add('hidden'); modal.classList.remove('flex');
}

// ═══════════════ PROFIL ═══════════════
async function loadProfil() {
    const loading = document.getElementById('profil-loading');
    const content = document.getElementById('profil-content');
    loading.classList.remove('hidden'); content.classList.add('hidden');

    try {
        const res = await fetch(API_URL, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ action: 'profile' }) });
        const data = await res.json();
        loading.classList.add('hidden');

        if (!data.success) throw new Error(data.message);

        const p = data.data;
        const initial = (p.name || 'S').charAt(0).toUpperCase();
        const progress = p.points_for_next_level > 0 ? Math.min((p.total_points / p.points_for_next_level) * 100, 100) : 0;
        const remaining = Math.max(0, p.points_for_next_level - p.total_points);

        // Weekly chart
        const maxWeekly = Math.max(...p.weekly_points, 1);
        let chartBars = '';
        p.weekly_points.forEach((val, i) => {
            const pct = (val / maxWeekly * 100).toFixed(1);
            chartBars += `
            <div class="flex flex-col items-center gap-1 flex-1">
                <span class="text-xs font-bold text-gray-600">${val}</span>
                <div class="w-full bg-gray-100 rounded-full overflow-hidden relative" style="height:80px">
                    <div class="bg-green-primary rounded-full w-full absolute bottom-0 transition-all duration-500" style="height:${pct}%"></div>
                </div>
                <span class="text-xs text-gray-400 font-medium">${p.day_labels[i]}</span>
            </div>`;
        });

        // Badges
        let badgesHtml = '';
        const achieved = p.badges.filter(b => b.is_achieved);
        const locked   = p.badges.filter(b => !b.is_achieved);
        if (achieved.length > 0) {
            badgesHtml += '<div class="grid grid-cols-2 sm:grid-cols-3 gap-3 mb-4">';
            achieved.forEach(b => {
                badgesHtml += `
                <div class="bg-white border border-green-200 rounded-xl p-3.5 text-center">
                    <div class="text-2xl mb-1 flex justify-center text-amber-500">${b.icon ? escapeHtml(b.icon) : '<i class="ti ti-medal"></i>'}</div>
                    <p class="text-xs font-bold text-gray-900">${escapeHtml(b.name)}</p>
                    <p class="text-[10px] text-gray-400 mt-0.5">${escapeHtml(b.description)}</p>
                </div>`;
            });
            badgesHtml += '</div>';
        }
        if (locked.length > 0) {
            badgesHtml += '<p class="text-xs font-semibold text-gray-400 mb-2 flex items-center gap-1"><i class="ti ti-lock"></i> Belum Tercapai</p><div class="grid grid-cols-2 sm:grid-cols-3 gap-3">';
            locked.forEach(b => {
                badgesHtml += `
                <div class="bg-gray-50 border border-gray-200 rounded-xl p-3.5 text-center opacity-60">
                    <div class="text-2xl mb-1 grayscale flex justify-center">${b.icon ? escapeHtml(b.icon) : '<i class="ti ti-medal"></i>'}</div>
                    <p class="text-xs font-bold text-gray-500">${escapeHtml(b.name)}</p>
                    <p class="text-[10px] text-gray-400 mt-0.5">${escapeHtml(b.description)}</p>
                </div>`;
            });
            badgesHtml += '</div>';
        }
        if (p.badges.length === 0) {
            badgesHtml = '<p class="text-sm text-gray-400 text-center py-6">Belum ada badge tersedia</p>';
        }

        // Points breakdown
        let breakdownHtml = '';
        p.points_breakdown.forEach(bd => {
            breakdownHtml += `
            <div class="flex items-center justify-between py-2">
                <span class="text-sm text-gray-700">${escapeHtml(bd.label)}</span>
                <span class="text-sm font-bold text-green-700">${bd.points} poin</span>
            </div>`;
        });

        content.innerHTML = `
        <!-- Profile Card -->
        <div class="card bg-white rounded-xl border border-gray-200 shadow-sm mb-5">
            <div class="p-6 text-center">
                ${p.avatar_url ? `<img src="../../${escapeHtml(p.avatar_url)}" class="w-24 h-24 rounded-full object-cover border-4 border-green-100 mx-auto mb-4" alt="">` :
                `<div class="w-24 h-24 bg-green-100 text-green-700 rounded-full flex items-center justify-center text-3xl font-bold mx-auto mb-4 border-4 border-green-50">${initial}</div>`}
                <h2 class="text-xl font-extrabold text-gray-900">${escapeHtml(p.name)}</h2>
                <p class="text-sm text-gray-500 mt-1">${escapeHtml(p.class_name)} &middot; ${escapeHtml(p.school_name)}</p>
                ${p.nis ? `<p class="text-xs text-gray-400 mt-1">NIS: ${escapeHtml(p.nis)}</p>` : ''}
                ${p.email ? `<p class="text-xs text-gray-400">Email: ${escapeHtml(p.email)}</p>` : ''}
                ${p.phone ? `<p class="text-xs text-gray-400">HP: ${escapeHtml(p.phone)}</p>` : ''}
            </div>
        </div>

        <!-- Points & Level Card -->
        <div class="card bg-white rounded-xl border border-gray-200 shadow-sm mb-5">
            <div class="p-5">
                <div class="flex items-center justify-between mb-4">
                    <div>
                        <p class="text-sm font-medium text-gray-500">Level ${p.current_level}</p>
                        <p class="text-2xl font-extrabold text-gray-900">${p.total_points.toLocaleString()} <span class="text-base font-medium text-gray-400">poin</span></p>
                    </div>
                    <div class="flex items-center gap-2 bg-red-50 px-3 py-1.5 rounded-full">
                        <i class="ti ti-flame text-red-500 text-xl"></i>
                        <span class="text-sm font-bold text-red-700">${p.streak} hari</span>
                    </div>
                </div>
                <div class="h-3 bg-gray-100 rounded-full overflow-hidden mb-2">
                    <div class="h-full bg-green-primary rounded-full transition-all duration-700" style="width:${progress.toFixed(1)}%"></div>
                </div>
                <p class="text-xs text-gray-400">${remaining > 0 ? remaining + ' poin lagi ke Level ' + (p.current_level + 1) : 'Level maksimum tercapai!'}</p>
            </div>
        </div>

        <!-- Weekly Chart -->
        <div class="card bg-white rounded-xl border border-gray-200 shadow-sm mb-5">
            <div class="p-5">
                <h3 class="text-base font-semibold text-gray-900 mb-4 flex items-center gap-2">
                    <svg class="w-5 h-5 text-green-600" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2"><path stroke-linecap="round" stroke-linejoin="round" d="M9 19v-6a2 2 0 00-2-2H5a2 2 0 00-2 2v6a2 2 0 002 2h2a2 2 0 002-2zm0 0V9a2 2 0 012-2h2a2 2 0 012 2v10m-6 0a2 2 0 002 2h2a2 2 0 002-2m0 0V5a2 2 0 012-2h2a2 2 0 012 2v14a2 2 0 01-2 2h-2a2 2 0 01-2-2z"/></svg>
                    Poin Mingguan
                </h3>
                <div class="flex gap-2 items-end">${chartBars}</div>
            </div>
        </div>

        <!-- Points Breakdown -->
        ${p.points_breakdown.length > 0 ? `
        <div class="card bg-white rounded-xl border border-gray-200 shadow-sm mb-5">
            <div class="p-5">
                <h3 class="text-base font-semibold text-gray-900 mb-3 flex items-center gap-2">
                    <svg class="w-5 h-5 text-amber-500" fill="currentColor" viewBox="0 0 24 24"><path fill-rule="evenodd" d="M10.788 3.21c.448-1.077 1.976-1.077 2.424 0l2.082 5.007 5.404.433c1.164.093 1.636 1.545.749 2.305l-4.117 3.527 1.257 5.273c.271 1.136-.964 2.033-1.96 1.425L12 18.354 7.373 21.18c-.996.608-2.231-.29-1.96-1.425l1.257-5.273-4.117-3.527c-.887-.76-.415-2.212.749-2.305l5.404-.433 2.082-5.006z" clip-rule="evenodd"/></svg>
                    Sumber Poin
                </h3>
                <div class="divide-y divide-gray-100">${breakdownHtml}</div>
            </div>
        </div>` : ''}

        <!-- Badges -->
        <div class="card bg-white rounded-xl border border-gray-200 shadow-sm mb-5">
            <div class="p-5">
                <h3 class="text-base font-semibold text-gray-900 mb-4 flex items-center gap-2">
                    <i class="ti ti-medal text-amber-500 text-xl"></i> Badge
                    <span class="text-xs font-medium text-gray-400 ml-auto">${achieved.length}/${p.badges.length} tercapai</span>
                </h3>
                ${badgesHtml}
            </div>
        </div>

        <!-- Settings -->
        <div class="card bg-white rounded-xl border border-gray-200 shadow-sm mb-5">
            <div class="divide-y divide-gray-100">
                <button onclick="openPwModal()" class="w-full flex items-center gap-3 px-5 py-4 hover:bg-gray-50 transition-colors text-left">
                    <div class="w-9 h-9 bg-blue-50 rounded-lg flex items-center justify-center">
                        <svg class="w-5 h-5 text-blue-600" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2"><path stroke-linecap="round" stroke-linejoin="round" d="M12 15v2m-6 4h12a2 2 0 002-2v-6a2 2 0 00-2-2H6a2 2 0 00-2 2v6a2 2 0 002 2zm10-10V7a4 4 0 00-8 0v4h8z"/></svg>
                    </div>
                    <div class="flex-1"><p class="text-sm font-semibold text-gray-900">Ubah Kata Sandi</p><p class="text-xs text-gray-400">Ganti password akun Anda</p></div>
                    <svg class="w-4 h-4 text-gray-400" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2"><path stroke-linecap="round" stroke-linejoin="round" d="M9 5l7 7-7 7"/></svg>
                </button>
                <button onclick="handleLogout()" class="w-full flex items-center gap-3 px-5 py-4 hover:bg-red-50 transition-colors text-left">
                    <div class="w-9 h-9 bg-red-50 rounded-lg flex items-center justify-center">
                        <svg class="w-5 h-5 text-red-500" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2"><path stroke-linecap="round" stroke-linejoin="round" d="M17 16l4-4m0 0l-4-4m4 4H7m6 4v1a3 3 0 01-3 3H6a3 3 0 01-3-3V7a3 3 0 013-3h4a3 3 0 013 3v1"/></svg>
                    </div>
                    <div class="flex-1"><p class="text-sm font-semibold text-red-600">Keluar</p><p class="text-xs text-gray-400">Keluar dari akun Anda</p></div>
                </button>
            </div>
        </div>`;

        content.classList.remove('hidden');
        profilLoaded = true;

    } catch (e) {
        loading.classList.add('hidden');
        content.innerHTML = `<div class="text-center py-16"><p class="text-sm text-gray-500 mb-3">Gagal memuat profil</p><button onclick="loadProfil()" class="text-sm text-green-primary font-medium hover:underline">Coba Lagi</button></div>`;
        content.classList.remove('hidden');
    }
}

// ═══════════════ CHANGE PASSWORD ═══════════════
function openPwModal() {
    document.getElementById('pwModal').classList.remove('hidden');
    document.getElementById('pwModal').classList.add('flex');
    document.getElementById('pwOld').value = '';
    document.getElementById('pwNew').value = '';
    document.getElementById('pwError').classList.add('hidden');
    validatePwForm();
}
function closePwModal() {
    document.getElementById('pwModal').classList.add('hidden');
    document.getElementById('pwModal').classList.remove('flex');
}
function validatePwForm() {
    const old = document.getElementById('pwOld').value;
    const newPw = document.getElementById('pwNew').value;
    document.getElementById('pwSubmitBtn').disabled = !(old.length > 0 && newPw.length >= 6);
}
document.getElementById('pwOld').addEventListener('input', validatePwForm);
document.getElementById('pwNew').addEventListener('input', validatePwForm);

async function submitChangePassword() {
    const btn = document.getElementById('pwSubmitBtn');
    const err = document.getElementById('pwError');
    btn.disabled = true; err.classList.add('hidden');

    try {
        const res = await fetch(API_URL, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
                action: 'change_password',
                current_password: document.getElementById('pwOld').value,
                new_password: document.getElementById('pwNew').value,
            }),
        });
        const data = await res.json();
        if (!data.success) throw new Error(data.message || 'Gagal mengubah password');

        closePwModal();
        showToast('Password berhasil diubah!', false);
    } catch (e) {
        err.textContent = e.message;
        err.classList.remove('hidden');
        btn.disabled = false;
    }
}

// ═══════════════ UTILS ═══════════════
function escapeHtml(str) {
    if (!str) return '';
    const div = document.createElement('div');
    div.textContent = str;
    return div.innerHTML;
}

function formatDate(dateStr) {
    if (!dateStr) return '';
    const months = ['Jan','Feb','Mar','Apr','Mei','Jun','Jul','Agu','Sep','Okt','Nov','Des'];
    const d = new Date(dateStr);
    if (isNaN(d)) return dateStr;
    return d.getDate() + ' ' + months[d.getMonth()] + ' ' + d.getFullYear();
}
</script>
</body>
</html>
