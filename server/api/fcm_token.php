<?php
// /server/api/fcm_token.php
// Endpoint untuk menyimpan dan menghapus FCM device token
//
// POST  action=register    -> simpan token FCM
// POST  action=unregister  -> hapus token FCM

header('Content-Type: application/json; charset=utf-8');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST, OPTIONS');
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

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    http_response_code(405);
    echo json_encode(['success' => false, 'message' => 'Method not allowed']);
    exit;
}

$input = json_decode(file_get_contents('php://input'), true);
$action   = trim($input['action'] ?? '');
$fcmToken = trim($input['fcm_token'] ?? '');

if (empty($fcmToken)) {
    http_response_code(400);
    echo json_encode(['success' => false, 'message' => 'fcm_token wajib diisi']);
    exit;
}

// ════════════════════════════════════════════════════
// REGISTER: Simpan/update FCM token
// ════════════════════════════════════════════════════
if ($action === 'register') {
    try {
        // STEP 1: SELALU hapus token ini dari SEMUA user terlebih dulu.
        // Ini mencegah satu token terdaftar untuk >1 user (duplikat).
        // Satu device = satu FCM token = satu user aktif.
        $stmt = $pdo->prepare('DELETE FROM fcm_tokens WHERE token = :token');
        $stmt->execute(['token' => $fcmToken]);

        // STEP 2: Hapus juga token-token LAMA milik user ini yang sudah stale (>7 hari).
        // Ini mencegah akumulasi token lama yang tidak valid.
        $stmt = $pdo->prepare(
            'DELETE FROM fcm_tokens WHERE user_id = :uid AND updated_at < DATE_SUB(NOW(), INTERVAL 7 DAY)'
        );
        $stmt->execute(['uid' => $userId]);

        // STEP 3: Insert token baru untuk user saat ini.
        $stmt = $pdo->prepare(
            'INSERT INTO fcm_tokens (user_id, token, created_at, updated_at)
             VALUES (:uid, :token, NOW(), NOW())'
        );
        $stmt->execute(['uid' => $userId, 'token' => $fcmToken]);

        echo json_encode(['success' => true, 'message' => 'FCM token registered']);
    } catch (PDOException $e) {
        http_response_code(500);
        echo json_encode(['success' => false, 'message' => 'Gagal menyimpan token', 'debug' => $e->getMessage()]);
    }
    exit;
}

// ════════════════════════════════════════════════════
// UNREGISTER: Hapus FCM token (saat logout)
// ════════════════════════════════════════════════════
if ($action === 'unregister') {
    try {
        // Hapus token dari semua user (1 device = 1 token, bersihkan semuanya)
        $stmt = $pdo->prepare(
            'DELETE FROM fcm_tokens WHERE token = :token'
        );
        $stmt->execute(['token' => $fcmToken]);

        echo json_encode(['success' => true, 'message' => 'FCM token removed']);
    } catch (PDOException $e) {
        http_response_code(500);
        echo json_encode(['success' => false, 'message' => 'Gagal menghapus token', 'debug' => $e->getMessage()]);
    }
    exit;
}

http_response_code(400);
echo json_encode(['success' => false, 'message' => 'Action tidak dikenal. Gunakan register atau unregister']);
