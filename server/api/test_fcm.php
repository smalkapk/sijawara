<?php
// /server/api/test_fcm.php
// Script diagnostik untuk mengecek apakah FCM push bisa berjalan dari server.
// Akses via browser: https://portal-smalka.com/api/test_fcm.php
//
// Cara pakai:
//   GET  ?              → Diagnostik lengkap
//   GET  ?send=yes      → Kirim test ke token terakhir
//   GET  ?send=yes&user_id=2  → Kirim test ke user tertentu
//   GET  ?fix_dupes=yes → Bersihkan duplikat token
//
// ⚠️  HAPUS FILE INI SETELAH SELESAI TESTING!

header('Content-Type: application/json; charset=utf-8');

$results = [];
$allOk = true;

// ── 1. Cek file service account ──
$saPath = __DIR__ . '/../config/firebase-service-account.json';
if (file_exists($saPath)) {
    $sa = json_decode(file_get_contents($saPath), true);
    if ($sa && isset($sa['project_id'], $sa['client_email'], $sa['private_key'])) {
        $results['1_service_account'] = [
            'status' => '✅ OK',
            'project_id' => $sa['project_id'],
            'client_email' => $sa['client_email'],
            'private_key_length' => strlen($sa['private_key']),
        ];
    } else {
        $results['1_service_account'] = ['status' => '❌ INVALID', 'detail' => 'File ada tapi format JSON tidak valid'];
        $allOk = false;
    }
} else {
    $results['1_service_account'] = ['status' => '❌ NOT FOUND', 'expected_path' => $saPath];
    $allOk = false;
}

// ── 2. Cek PHP extensions ──
$results['2_php_extensions'] = [
    'openssl' => extension_loaded('openssl') ? '✅' : '❌ MISSING',
    'curl'    => extension_loaded('curl') ? '✅' : '❌ MISSING',
    'json'    => extension_loaded('json') ? '✅' : '❌ MISSING',
];
if (!extension_loaded('openssl') || !extension_loaded('curl')) {
    $allOk = false;
}

// ── 3. Cek tabel fcm_tokens ──
try {
    require_once __DIR__ . '/../config/conn.php';
    $stmt = $pdo->query('SELECT COUNT(*) as total FROM fcm_tokens');
    $row = $stmt->fetch();
    $results['3_fcm_tokens_table'] = [
        'status' => '✅ OK',
        'total_tokens' => (int) $row['total'],
    ];

    // Tampilkan sample tokens
    $stmt2 = $pdo->query('SELECT ft.id, ft.user_id, u.name, u.role, LEFT(ft.token, 20) as token_prefix, ft.updated_at 
                           FROM fcm_tokens ft 
                           JOIN users u ON ft.user_id = u.id 
                           ORDER BY ft.updated_at DESC LIMIT 10');
    $results['3_fcm_tokens_detail'] = $stmt2->fetchAll();

    // Cek duplikat token (1 token terdaftar untuk >1 user)
    $stmtDupes = $pdo->query('
        SELECT LEFT(token, 20) as token_prefix, GROUP_CONCAT(user_id) as user_ids, COUNT(*) as count
        FROM fcm_tokens
        GROUP BY token
        HAVING COUNT(*) > 1
    ');
    $dupes = $stmtDupes->fetchAll();
    if (!empty($dupes)) {
        $results['3_DUPLICATE_TOKENS'] = [
            'status' => '⚠️ FOUND DUPLICATES',
            'duplicates' => $dupes,
            'fix_url' => '?fix_dupes=yes',
        ];
    }
} catch (PDOException $e) {
    $results['3_fcm_tokens_table'] = ['status' => '❌ ERROR', 'detail' => $e->getMessage()];
    $allOk = false;
}

// ── 3b. Fix duplikat jika diminta ──
if (isset($_GET['fix_dupes']) && $_GET['fix_dupes'] === 'yes' && isset($pdo)) {
    try {
        // Cari semua token yang terdaftar untuk >1 user
        $stmtDup = $pdo->query('
            SELECT token, GROUP_CONCAT(user_id ORDER BY updated_at DESC) as user_ids
            FROM fcm_tokens
            GROUP BY token
            HAVING COUNT(*) > 1
        ');
        $dupTokens = $stmtDup->fetchAll();
        
        $fixed = 0;
        foreach ($dupTokens as $dup) {
            $userIds = explode(',', $dup['user_ids']);
            $keepUserId = (int) $userIds[0]; // keep the most recent
            
            // Hapus token untuk semua user kecuali yang paling baru
            $delStmt = $pdo->prepare('DELETE FROM fcm_tokens WHERE token = ? AND user_id != ?');
            $delStmt->execute([$dup['token'], $keepUserId]);
            $fixed += $delStmt->rowCount();
        }
        
        // Juga hapus token yang sudah stale (>30 hari)
        $staleStmt = $pdo->prepare('DELETE FROM fcm_tokens WHERE updated_at < DATE_SUB(NOW(), INTERVAL 30 DAY)');
        $staleStmt->execute();
        $staleCount = $staleStmt->rowCount();
        
        $results['FIX_DUPES_RESULT'] = [
            'duplicates_removed' => $fixed,
            'stale_tokens_removed' => $staleCount,
        ];
    } catch (Exception $e) {
        $results['FIX_DUPES_ERROR'] = $e->getMessage();
    }
}

// ── 4. Cek OAuth2 access token ──
if ($allOk) {
    try {
        require_once __DIR__ . '/../config/fcm_helper.php';
        $accessToken = getAccessToken();
        $results['4_oauth2_token'] = [
            'status' => '✅ OK',
            'token_prefix' => substr($accessToken, 0, 30) . '...',
        ];
    } catch (Exception $e) {
        $results['4_oauth2_token'] = ['status' => '❌ ERROR', 'detail' => $e->getMessage()];
        $allOk = false;
    }
}

// ── 5. Cek koneksi ke FCM API ──
$results['5_fcm_api_connectivity'] = [];
try {
    $ch = curl_init('https://fcm.googleapis.com/');
    curl_setopt_array($ch, [
        CURLOPT_RETURNTRANSFER => true,
        CURLOPT_TIMEOUT => 5,
        CURLOPT_NOBODY => true,
    ]);
    curl_exec($ch);
    $httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
    $curlError = curl_error($ch);
    $curlErrno = curl_errno($ch);
    curl_close($ch);
    
    if ($curlError) {
        $results['5_fcm_api_connectivity'] = [
            'status' => '❌ CANNOT REACH',
            'curl_errno' => $curlErrno,
            'curl_error' => $curlError,
        ];
        $allOk = false;
    } else {
        $results['5_fcm_api_connectivity'] = [
            'status' => '✅ REACHABLE',
            'http_code' => $httpCode,
        ];
    }
} catch (Exception $e) {
    $results['5_fcm_api_connectivity'] = ['status' => '❌ ERROR', 'detail' => $e->getMessage()];
}

// ── 6. Test kirim notifikasi ──
$sendTest = isset($_GET['send']) && $_GET['send'] === 'yes';
$targetUserId = isset($_GET['user_id']) ? (int) $_GET['user_id'] : 0;

if ($allOk && $sendTest && isset($pdo)) {
    if ($targetUserId > 0) {
        // Kirim ke user tertentu
        $stmt = $pdo->prepare('SELECT ft.token, ft.user_id, u.name FROM fcm_tokens ft JOIN users u ON ft.user_id = u.id WHERE ft.user_id = ? ORDER BY ft.updated_at DESC');
        $stmt->execute([$targetUserId]);
    } else {
        // Kirim ke token terakhir
        $stmt = $pdo->query('SELECT ft.token, ft.user_id, u.name FROM fcm_tokens ft JOIN users u ON ft.user_id = u.id ORDER BY ft.updated_at DESC LIMIT 1');
    }
    $targetTokens = $stmt->fetchAll();

    if (!empty($targetTokens)) {
        $sendResults = [];
        foreach ($targetTokens as $t) {
            $result = sendFcmNotification(
                $t['token'],
                '🔔 Test FCM Sijawara',
                'Test push notification. User: ' . $t['name'] . ' (' . $t['user_id'] . '). Time: ' . date('H:i:s'),
                [
                    'type' => 'chat',
                    'sender_id' => '0',
                    'sender_name' => 'FCM Tester',
                    'sender_role' => 'system',
                    'channel_id' => 'chat_channel',
                ]
            );
            $sendResults[] = [
                'user' => $t['name'] . ' (ID:' . $t['user_id'] . ')',
                'token_prefix' => substr($t['token'], 0, 20) . '...',
                'fcm_success' => $result['success'],
                'http_code' => $result['http_code'] ?? 'N/A',
                'fcm_response' => $result['response'],
            ];
        }
        $results['6_send_test'] = $sendResults;
    } else {
        $results['6_send_test'] = [
            'status' => '⚠️ NO TOKEN',
            'detail' => $targetUserId > 0 
                ? "Tidak ada FCM token untuk user_id=$targetUserId" 
                : 'Tidak ada FCM token sama sekali',
        ];
    }
} elseif ($allOk) {
    $results['6_send_test'] = [
        'status' => '⏸️ READY',
        'note' => 'Gunakan URL berikut untuk test:',
        'test_last_token' => '?send=yes',
        'test_user_2' => '?send=yes&user_id=2',
        'test_user_3' => '?send=yes&user_id=3',
        'test_user_5' => '?send=yes&user_id=5',
    ];
}

// ── 7. Token cache ──
$cachePath = __DIR__ . '/../uploads/.fcm_token_cache.json';
if (file_exists($cachePath)) {
    $cache = json_decode(file_get_contents($cachePath), true);
    $results['7_token_cache'] = [
        'status' => '✅ EXISTS',
        'expires_at' => isset($cache['expires_at']) ? date('Y-m-d H:i:s', $cache['expires_at']) : 'N/A',
        'is_expired' => isset($cache['expires_at']) ? (time() > $cache['expires_at'] ? 'YES ⚠️' : 'NO ✅') : 'N/A',
    ];
} else {
    $results['7_token_cache'] = ['status' => 'ℹ️ Not cached yet'];
}

// ── Summary ──
echo json_encode([
    'fcm_diagnostic' => $allOk ? '✅ ALL CHECKS PASSED' : '❌ ISSUES FOUND - lihat detail di bawah',
    'server_time' => date('Y-m-d H:i:s T'),
    'php_version' => PHP_VERSION,
    'results' => $results,
], JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE);
