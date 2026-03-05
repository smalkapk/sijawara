<?php
/**
 * Chat API – Diskusi Wali & Guru Kelas
 *
 * Endpoints (via GET parameter `action`):
 *   - guru_info       : Wali mendapatkan info guru kelas anaknya
 *   - contacts        : Guru mendapatkan daftar wali di kelasnya
 *   - history         : Riwayat chat antara 2 user
 *   - mark_read       : Tandai pesan sebagai sudah dibaca
 *   - send            : Kirim pesan (fallback HTTP jika WebSocket down)
 *   - upload          : Upload file/gambar + kirim pesan
 */

header('Content-Type: application/json; charset=utf-8');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization');

ini_set('display_errors', '0');
error_reporting(E_ALL);

// Tangkap fatal error → tetap balas JSON
ob_start();
register_shutdown_function(function () {
    $error = error_get_last();
    if ($error && in_array($error['type'], [E_ERROR, E_PARSE, E_CORE_ERROR, E_COMPILE_ERROR], true)) {
        ob_end_clean();
        if (!headers_sent()) {
            header('Content-Type: application/json; charset=utf-8');
            http_response_code(500);
        }
        echo json_encode([
            'success' => false,
            'message' => 'Fatal error: ' . $error['message'],
        ]);
    }
});

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit;
}

require_once __DIR__ . '/../config/conn.php';
require_once __DIR__ . '/../config/auth.php';

try {

// ── Auth ──
$token = getBearerToken();
$userId = getUserIdFromToken($token);
if (!$userId) {
    http_response_code(401);
    echo json_encode(['success' => false, 'message' => 'Token tidak valid']);
    exit;
}

// Ambil info user
$stmtUser = $pdo->prepare('SELECT id, name, role, avatar_url FROM users WHERE id = :uid');
$stmtUser->execute(['uid' => $userId]);
$currentUser = $stmtUser->fetch();
if (!$currentUser) {
    http_response_code(401);
    echo json_encode(['success' => false, 'message' => 'User tidak ditemukan']);
    exit;
}

$action = $_GET['action'] ?? $_POST['action'] ?? '';

switch ($action) {

    // ═══════════════════════════════════════
    // GURU INFO: Wali mendapatkan guru kelas
    // ═══════════════════════════════════════
    case 'guru_info':
        if ($currentUser['role'] !== 'orang_tua') {
            echo json_encode(['success' => false, 'message' => 'Hanya untuk orang tua']);
            exit;
        }

        $stmt = $pdo->prepare('
            SELECT DISTINCT u.id, u.name, u.avatar_url, c.name AS class_name
            FROM parent_student ps
            JOIN students s ON ps.student_id = s.id
            JOIN classes c ON s.class_id = c.id
            JOIN users u ON c.guru_kelas_id = u.id
            WHERE ps.parent_id = :pid
        ');
        $stmt->execute(['pid' => $userId]);
        $gurus = $stmt->fetchAll();

        if (empty($gurus)) {
            echo json_encode(['success' => false, 'message' => 'Guru kelas tidak ditemukan']);
            exit;
        }

        $guru = $gurus[0];

        $stmtChildren = $pdo->prepare('
            SELECT u.name AS child_name
            FROM parent_student ps
            JOIN students s ON ps.student_id = s.id
            JOIN users u ON s.user_id = u.id
            WHERE ps.parent_id = :pid
        ');
        $stmtChildren->execute(['pid' => $userId]);
        $children = $stmtChildren->fetchAll(PDO::FETCH_COLUMN);

        echo json_encode([
            'success' => true,
            'data' => [
                'guru_id' => (int) $guru['id'],
                'guru_name' => $guru['name'],
                'guru_avatar' => $guru['avatar_url'],
                'class_name' => $guru['class_name'],
                'children' => $children,
            ]
        ]);
        break;

    // ═══════════════════════════════════════
    // CONTACTS: Guru mendapatkan daftar wali
    // ═══════════════════════════════════════
    case 'contacts':
        if ($currentUser['role'] !== 'guru_kelas') {
            echo json_encode(['success' => false, 'message' => 'Hanya untuk guru kelas']);
            exit;
        }

        $stmt = $pdo->prepare('
            SELECT DISTINCT
                u.id AS wali_id,
                u.name AS wali_name,
                u.avatar_url,
                GROUP_CONCAT(DISTINCT child_u.name SEPARATOR ", ") AS children_names,
                c.name AS class_name
            FROM classes c
            JOIN students s ON s.class_id = c.id
            JOIN parent_student ps ON ps.student_id = s.id
            JOIN users u ON ps.parent_id = u.id
            JOIN users child_u ON s.user_id = child_u.id
            WHERE c.guru_kelas_id = :guru_id
            GROUP BY u.id, u.name, u.avatar_url, c.name
            ORDER BY u.name ASC
        ');
        $stmt->execute(['guru_id' => $userId]);
        $contacts = $stmt->fetchAll();

        $result = [];
        foreach ($contacts as $c) {
            $waliId = (int) $c['wali_id'];

            $stmtLast = $pdo->prepare('
                SELECT message, created_at, sender_id, attachment_type
                FROM chat_messages
                WHERE (sender_id = :uid AND receiver_id = :wid)
                   OR (sender_id = :wid2 AND receiver_id = :uid2)
                ORDER BY created_at DESC
                LIMIT 1
            ');
            $stmtLast->execute([
                'uid' => $userId, 'wid' => $waliId,
                'wid2' => $waliId, 'uid2' => $userId,
            ]);
            $lastMsg = $stmtLast->fetch();

            // Format last message preview
            $lastMsgText = null;
            if ($lastMsg) {
                if ($lastMsg['attachment_type'] === 'image') {
                    $lastMsgText = '📷 Foto';
                } elseif ($lastMsg['attachment_type'] === 'document') {
                    $lastMsgText = '📄 Dokumen';
                } else {
                    $lastMsgText = $lastMsg['message'];
                }
            }

            $stmtUnread = $pdo->prepare('
                SELECT COUNT(*) AS cnt
                FROM chat_messages
                WHERE sender_id = :wid AND receiver_id = :uid AND is_read = 0
            ');
            $stmtUnread->execute(['wid' => $waliId, 'uid' => $userId]);
            $unread = (int) $stmtUnread->fetch()['cnt'];

            $result[] = [
                'wali_id' => $waliId,
                'wali_name' => $c['wali_name'],
                'avatar_url' => $c['avatar_url'],
                'children_names' => $c['children_names'],
                'class_name' => $c['class_name'],
                'last_message' => $lastMsgText,
                'last_message_time' => $lastMsg ? $lastMsg['created_at'] : null,
                'last_message_is_me' => $lastMsg ? ((int)$lastMsg['sender_id'] === $userId) : false,
                'unread_count' => $unread,
            ];
        }

        usort($result, function ($a, $b) {
            if (!$a['last_message_time'] && !$b['last_message_time']) return 0;
            if (!$a['last_message_time']) return 1;
            if (!$b['last_message_time']) return -1;
            return strcmp($b['last_message_time'], $a['last_message_time']);
        });

        echo json_encode(['success' => true, 'data' => $result]);
        break;

    // ═══════════════════════════════════════
    // HISTORY: Riwayat chat
    // ═══════════════════════════════════════
    case 'history':
        $partnerId = (int) ($_GET['partner_id'] ?? 0);
        $limit = (int) ($_GET['limit'] ?? 50);
        $beforeId = (int) ($_GET['before_id'] ?? 0);

        if ($partnerId <= 0) {
            echo json_encode(['success' => false, 'message' => 'partner_id diperlukan']);
            exit;
        }

        $sql = '
            SELECT id, sender_id, receiver_id, message,
                   attachment_type, attachment_url, attachment_name, attachment_size,
                   is_read, created_at
            FROM chat_messages
            WHERE ((sender_id = :uid AND receiver_id = :pid)
                OR (sender_id = :pid2 AND receiver_id = :uid2))
        ';
        $params = [
            'uid' => $userId, 'pid' => $partnerId,
            'pid2' => $partnerId, 'uid2' => $userId,
        ];

        if ($beforeId > 0) {
            $sql .= ' AND id < :before_id';
            $params['before_id'] = $beforeId;
        }

        $sql .= ' ORDER BY created_at DESC LIMIT :lim';

        $stmt = $pdo->prepare($sql);
        foreach ($params as $k => $v) {
            $stmt->bindValue($k, $v, PDO::PARAM_INT);
        }
        $stmt->bindValue('lim', $limit, PDO::PARAM_INT);
        $stmt->execute();
        $messages = $stmt->fetchAll();

        $messages = array_reverse($messages);

        $formatted = array_map(function ($m) use ($userId) {
            return [
                'id' => (int) $m['id'],
                'sender_id' => (int) $m['sender_id'],
                'receiver_id' => (int) $m['receiver_id'],
                'message' => $m['message'],
                'attachment_type' => $m['attachment_type'] ?? 'none',
                'attachment_url' => $m['attachment_url'],
                'attachment_name' => $m['attachment_name'],
                'attachment_size' => $m['attachment_size'] ? (int) $m['attachment_size'] : null,
                'is_me' => ((int) $m['sender_id'] === $userId),
                'is_read' => (bool) $m['is_read'],
                'created_at' => $m['created_at'],
            ];
        }, $messages);

        echo json_encode(['success' => true, 'data' => $formatted]);
        break;

    // ═══════════════════════════════════════
    // MARK READ
    // ═══════════════════════════════════════
    case 'mark_read':
        // Support JSON body (Flutter sends application/json) + fallback ke POST/GET
        $markInput = json_decode(file_get_contents('php://input'), true);
        $partnerId = (int) ($markInput['partner_id'] ?? $_POST['partner_id'] ?? $_GET['partner_id'] ?? 0);
        if ($partnerId <= 0) {
            echo json_encode(['success' => false, 'message' => 'partner_id diperlukan']);
            exit;
        }

        $stmt = $pdo->prepare('
            UPDATE chat_messages
            SET is_read = 1
            WHERE sender_id = :pid AND receiver_id = :uid AND is_read = 0
        ');
        $stmt->execute(['pid' => $partnerId, 'uid' => $userId]);

        echo json_encode(['success' => true, 'updated' => $stmt->rowCount()]);
        break;

    // ═══════════════════════════════════════
    // SEND: Kirim pesan teks via HTTP
    // ═══════════════════════════════════════
    case 'send':
        if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
            echo json_encode(['success' => false, 'message' => 'Gunakan POST']);
            exit;
        }

        $input = json_decode(file_get_contents('php://input'), true);
        $receiverId = (int) ($input['receiver_id'] ?? 0);
        $message = trim($input['message'] ?? '');

        if ($receiverId <= 0 || $message === '') {
            echo json_encode(['success' => false, 'message' => 'receiver_id dan message diperlukan']);
            exit;
        }

        $stmt = $pdo->prepare('
            INSERT INTO chat_messages (sender_id, receiver_id, message) 
            VALUES (:sid, :rid, :msg)
        ');
        $stmt->execute(['sid' => $userId, 'rid' => $receiverId, 'msg' => $message]);
        $msgId = (int) $pdo->lastInsertId();

        echo json_encode([
            'success' => true,
            'data' => [
                'id' => $msgId,
                'sender_id' => $userId,
                'receiver_id' => $receiverId,
                'message' => $message,
                'attachment_type' => 'none',
                'attachment_url' => null,
                'attachment_name' => null,
                'attachment_size' => null,
                'is_me' => true,
                'is_read' => false,
                'created_at' => date('Y-m-d H:i:s'),
            ]
        ]);
        break;

    // ═══════════════════════════════════════
    // UPLOAD: Upload file/gambar + kirim pesan
    // ═══════════════════════════════════════
    case 'upload':
        if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
            echo json_encode(['success' => false, 'message' => 'Gunakan POST']);
            exit;
        }

        $receiverId = (int) ($_POST['receiver_id'] ?? 0);
        $message = trim($_POST['message'] ?? '');
        $attachType = $_POST['attachment_type'] ?? 'document'; // image atau document

        if ($receiverId <= 0) {
            echo json_encode(['success' => false, 'message' => 'receiver_id diperlukan']);
            exit;
        }

        if (!isset($_FILES['file']) || $_FILES['file']['error'] !== UPLOAD_ERR_OK) {
            echo json_encode(['success' => false, 'message' => 'File tidak valid']);
            exit;
        }

        $file = $_FILES['file'];
        $maxSize = ($attachType === 'image') ? 10 * 1024 * 1024 : 25 * 1024 * 1024; // 10MB img, 25MB doc

        if ($file['size'] > $maxSize) {
            $maxMB = $maxSize / 1024 / 1024;
            echo json_encode(['success' => false, 'message' => "File terlalu besar (maks {$maxMB}MB)"]);
            exit;
        }

        // Validasi tipe file
        $allowedImage = ['image/jpeg', 'image/png', 'image/gif', 'image/webp'];
        $allowedDoc = [
            'application/pdf',
            'application/msword',
            'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
            'application/vnd.ms-excel',
            'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
            'application/vnd.ms-powerpoint',
            'application/vnd.openxmlformats-officedocument.presentationml.presentation',
            'text/plain',
        ];

        $mime = null;
        if (function_exists('mime_content_type')) {
            $mime = mime_content_type($file['tmp_name']);
        }
        if (!$mime && function_exists('finfo_open')) {
            $finfo = finfo_open(FILEINFO_MIME_TYPE);
            if ($finfo) {
                $mime = finfo_file($finfo, $file['tmp_name']);
                finfo_close($finfo);
            }
        }

        if (!$mime) {
            echo json_encode(['success' => false, 'message' => 'Gagal mendeteksi tipe file']);
            exit;
        }

        $mime = strtolower(trim($mime));
        if ($attachType === 'image' && !in_array($mime, $allowedImage)) {
            echo json_encode(['success' => false, 'message' => 'Format gambar tidak didukung']);
            exit;
        }
        if ($attachType === 'document' && !in_array($mime, array_merge($allowedDoc, $allowedImage))) {
            echo json_encode(['success' => false, 'message' => 'Format file tidak didukung']);
            exit;
        }

        // Buat folder upload
        $uploadDir = __DIR__ . '/../uploads/chat/';
        if (!is_dir($uploadDir)) {
            mkdir($uploadDir, 0755, true);
        }

        // Generate nama file unik
        $ext = pathinfo($file['name'], PATHINFO_EXTENSION);
        $filename = 'chat_' . $userId . '_' . time() . '_' . bin2hex(random_bytes(4)) . '.' . $ext;
        $filePath = $uploadDir . $filename;

        if (!move_uploaded_file($file['tmp_name'], $filePath)) {
            echo json_encode(['success' => false, 'message' => 'Gagal menyimpan file']);
            exit;
        }

        $fileUrl = 'https://portal-smalka.com/uploads/chat/' . $filename;

        // Simpan ke DB
        $stmt = $pdo->prepare('
            INSERT INTO chat_messages (sender_id, receiver_id, message, attachment_type, attachment_url, attachment_name, attachment_size)
            VALUES (:sid, :rid, :msg, :atype, :aurl, :aname, :asize)
        ');
        $stmt->execute([
            'sid' => $userId,
            'rid' => $receiverId,
            'msg' => $message,
            'atype' => $attachType,
            'aurl' => $fileUrl,
            'aname' => $file['name'],
            'asize' => (int) $file['size'],
        ]);
        $msgId = (int) $pdo->lastInsertId();

        echo json_encode([
            'success' => true,
            'data' => [
                'id' => $msgId,
                'sender_id' => $userId,
                'receiver_id' => $receiverId,
                'message' => $message,
                'attachment_type' => $attachType,
                'attachment_url' => $fileUrl,
                'attachment_name' => $file['name'],
                'attachment_size' => (int) $file['size'],
                'is_me' => true,
                'is_read' => false,
                'created_at' => date('Y-m-d H:i:s'),
            ]
        ]);
        break;

    default:
        echo json_encode(['success' => false, 'message' => 'Action tidak dikenal: ' . $action]);
        break;
}

} catch (Throwable $e) {
    if (!headers_sent()) {
        http_response_code(500);
    }
    echo json_encode([
        'success' => false,
        'message' => 'Terjadi error server',
        'debug' => $e->getMessage(),
    ]);
}
