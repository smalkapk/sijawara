<?php
/**
 * /server/api/chat_notify.php
 * 
 * Internal endpoint untuk mengirim FCM push notification chat.
 * Dipanggil oleh WebSocket server (Node.js) ketika penerima offline.
 * 
 * POST body JSON:
 *   sender_id    : int    – ID pengirim
 *   receiver_id  : int    – ID penerima
 *   message      : string – Isi pesan (atau empty jika attachment)
 *   attachment_type : string – 'none', 'image', 'document'
 *   internal_key : string – Key rahasia untuk validasi internal
 */

header('Content-Type: application/json; charset=utf-8');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit;
}

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    http_response_code(405);
    echo json_encode(['success' => false, 'message' => 'Method not allowed']);
    exit;
}

require_once __DIR__ . '/../config/conn.php';
require_once __DIR__ . '/../config/fcm_helper.php';

$input = json_decode(file_get_contents('php://input'), true);

// Validasi internal key (agar tidak bisa dipanggil sembarang orang)
$internalKey = trim($input['internal_key'] ?? '');
if ($internalKey !== 'smalka_ws_internal_2026') {
    http_response_code(403);
    echo json_encode(['success' => false, 'message' => 'Unauthorized']);
    exit;
}

$senderId       = (int) ($input['sender_id'] ?? 0);
$receiverId     = (int) ($input['receiver_id'] ?? 0);
$message        = trim($input['message'] ?? '');
$attachmentType = trim($input['attachment_type'] ?? 'none');

if ($senderId <= 0 || $receiverId <= 0) {
    http_response_code(400);
    echo json_encode(['success' => false, 'message' => 'sender_id dan receiver_id diperlukan']);
    exit;
}

try {
    // Ambil nama pengirim dan role
    $stmtSender = $pdo->prepare('SELECT name, role, avatar_url FROM users WHERE id = :uid LIMIT 1');
    $stmtSender->execute(['uid' => $senderId]);
    $sender = $stmtSender->fetch();

    if (!$sender) {
        error_log("[FCM Chat] Sender not found: sender_id=$senderId");
        echo json_encode(['success' => false, 'message' => 'Sender not found']);
        exit;
    }

    $senderName = $sender['name'];
    $senderRole = $sender['role'];
    $senderAvatar = $sender['avatar_url'] ?? '';
    if ($senderAvatar && strpos($senderAvatar, 'http') !== 0) {
        $senderAvatar = 'https://portal-smalka.com/' . $senderAvatar;
    }

    // Tentukan isi notifikasi berdasarkan tipe
    if ($attachmentType === 'image') {
        $notifBody = '📷 Mengirim foto';
    } elseif ($attachmentType === 'document') {
        $notifBody = '📄 Mengirim dokumen';
    } elseif (!empty($message)) {
        // Potong pesan agar tidak terlalu panjang
        $notifBody = mb_strlen($message) > 100 ? mb_substr($message, 0, 100) . '...' : $message;
    } else {
        $notifBody = 'Mengirim pesan';
    }

    error_log("[FCM Chat] Sending: {$senderId}({$senderName}) → {$receiverId}, body='{$notifBody}'");

    // Kirim FCM ke penerima
    $fcmResult = sendFcmToUsers(
        $pdo,
        [$receiverId],
        $senderName,
        $notifBody,
        [
            'type'          => 'chat',
            'sender_id'     => (string) $senderId,
            'sender_name'   => $senderName,
            'sender_role'   => $senderRole,
            'sender_avatar' => $senderAvatar,
            'channel_id'    => 'chat_channel',
        ]
    );

    error_log("[FCM Chat] Result: sent={$fcmResult['sent']}, failed={$fcmResult['failed']}, errors=" . json_encode($fcmResult['errors']));

    echo json_encode([
        'success' => true,
        'fcm'     => $fcmResult,
    ]);

} catch (Exception $e) {
    error_log("[FCM Chat] Error: " . $e->getMessage());
    http_response_code(500);
    echo json_encode(['success' => false, 'message' => $e->getMessage()]);
}
