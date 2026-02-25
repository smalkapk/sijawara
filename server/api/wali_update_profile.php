<?php
header('Content-Type: application/json; charset=utf-8');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit;
}

require_once __DIR__ . '/../config/conn.php';
require_once __DIR__ . '/../config/auth.php';

// Autentikasi
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

// Cek apakah kolom address sudah ada di tabel users
$hasAddressColumns = false;
try {
    $colCheck = $pdo->query("SHOW COLUMNS FROM users LIKE 'address'");
    $hasAddressColumns = ($colCheck && $colCheck->rowCount() > 0);
} catch (Exception $e) {
    $hasAddressColumns = false;
}

// Build SELECT query sesuai kolom yang tersedia
$selectCols = 'id, name, email, phone, role, avatar_url';
if ($hasAddressColumns) {
    $selectCols .= ', address, address_lat, address_lng';
}

$stmtUser = $pdo->prepare("SELECT $selectCols FROM users WHERE id = :uid");
$stmtUser->execute(['uid' => $userId]);
$user = $stmtUser->fetch();

if (!$user || $user['role'] !== 'orang_tua') {
    http_response_code(403);
    echo json_encode(['success' => false, 'message' => 'Akses hanya untuk orang tua']);
    exit;
}

// Helper: build profile response data
function buildProfileData($userData, $hasAddr) {
    $data = [
        'name'        => $userData['name'],
        'email'       => $userData['email'] ?? '',
        'phone'       => $userData['phone'] ?? '',
        'avatar_url'  => $userData['avatar_url'] ?? '',
    ];
    if ($hasAddr) {
        $data['address']     = $userData['address'] ?? '';
        $data['address_lat'] = !empty($userData['address_lat']) ? (float) $userData['address_lat'] : null;
        $data['address_lng'] = !empty($userData['address_lng']) ? (float) $userData['address_lng'] : null;
    } else {
        $data['address']     = '';
        $data['address_lat'] = null;
        $data['address_lng'] = null;
    }
    return $data;
}

// GET: Ambil data profil saat ini
if ($_SERVER['REQUEST_METHOD'] === 'GET') {
    echo json_encode([
        'success' => true,
        'data' => buildProfileData($user, $hasAddressColumns),
    ]);
    exit;
}

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    http_response_code(405);
    echo json_encode(['success' => false, 'message' => 'Method not allowed']);
    exit;
}

try {
    // Cek apakah ini upload avatar (multipart)
    if (isset($_FILES['avatar']) && $_FILES['avatar']['error'] === UPLOAD_ERR_OK) {
        $file = $_FILES['avatar'];

        // Validasi tipe file
        $allowedTypes = ['image/jpeg', 'image/png', 'image/webp'];
        $finfo = finfo_open(FILEINFO_MIME_TYPE);
        $mimeType = finfo_file($finfo, $file['tmp_name']);
        finfo_close($finfo);

        if (!in_array($mimeType, $allowedTypes)) {
            http_response_code(400);
            echo json_encode(['success' => false, 'message' => 'Format file tidak didukung. Gunakan JPG, PNG, atau WebP.']);
            exit;
        }

        // Validasi ukuran (maks 5MB)
        if ($file['size'] > 5 * 1024 * 1024) {
            http_response_code(400);
            echo json_encode(['success' => false, 'message' => 'Ukuran file maksimal 5MB']);
            exit;
        }

        // Buat direktori jika belum ada
        $uploadDir = __DIR__ . '/../uploads/avatars/';
        if (!is_dir($uploadDir)) {
            mkdir($uploadDir, 0755, true);
        }

        // Hapus avatar lama jika ada
        if (!empty($user['avatar_url'])) {
            $oldPath = __DIR__ . '/../' . ltrim($user['avatar_url'], '/');
            if (file_exists($oldPath)) {
                unlink($oldPath);
            }
        }

        // Generate nama unik
        $extMap = [
            'image/jpeg' => 'jpg',
            'image/png'  => 'png',
            'image/webp' => 'webp',
        ];
        $ext = isset($extMap[$mimeType]) ? $extMap[$mimeType] : 'jpg';
        $filename = 'wali_' . $userId . '_' . time() . '.' . $ext;
        $targetPath = $uploadDir . $filename;

        if (!move_uploaded_file($file['tmp_name'], $targetPath)) {
            http_response_code(500);
            echo json_encode(['success' => false, 'message' => 'Gagal menyimpan file']);
            exit;
        }

        // Update avatar_url di database
        $avatarUrl = 'uploads/avatars/' . $filename;
        $stmt = $pdo->prepare('UPDATE users SET avatar_url = :url, updated_at = NOW() WHERE id = :uid');
        $stmt->execute(['url' => $avatarUrl, 'uid' => $userId]);

        echo json_encode([
            'success' => true,
            'message' => 'Foto profil berhasil diperbarui',
            'data' => [
                'avatar_url' => $avatarUrl,
            ],
        ]);
        exit;
    }

    // POST JSON: Update data profil
    $input = json_decode(file_get_contents('php://input'), true);
    if (!$input) {
        http_response_code(400);
        echo json_encode(['success' => false, 'message' => 'Request body tidak valid']);
        exit;
    }

    // Cek apakah ini hanya update avatar_url (untuk DiceBear)
    if (isset($input['avatar_url']) && !isset($input['name'])) {
        $newAvatarUrl = trim($input['avatar_url']);
        $stmt = $pdo->prepare('UPDATE users SET avatar_url = :url, updated_at = NOW() WHERE id = :uid');
        $stmt->execute(['url' => $newAvatarUrl, 'uid' => $userId]);
        echo json_encode([
            'success' => true,
            'message' => 'Avatar berhasil diperbarui',
            'data' => ['avatar_url' => $newAvatarUrl],
        ]);
        exit;
    }

    $name    = trim($input['name'] ?? '');
    $phone   = trim($input['phone'] ?? '');
    $address = trim($input['address'] ?? '');
    $lat     = isset($input['address_lat']) ? (float) $input['address_lat'] : null;
    $lng     = isset($input['address_lng']) ? (float) $input['address_lng'] : null;

    // Validasi
    if (empty($name)) {
        http_response_code(400);
        echo json_encode(['success' => false, 'message' => 'Nama tidak boleh kosong']);
        exit;
    }

    // Cek duplikasi phone
    if (!empty($phone)) {
        $stmt = $pdo->prepare(
            'SELECT id FROM users WHERE phone = :phone AND id != :uid LIMIT 1'
        );
        $stmt->execute(['phone' => $phone, 'uid' => $userId]);
        if ($stmt->fetch()) {
            http_response_code(409);
            echo json_encode(['success' => false, 'message' => 'Nomor HP sudah digunakan akun lain']);
            exit;
        }
    }

    // Build update query
    $fields = ['name = :name', 'updated_at = NOW()'];
    $params = ['name' => $name, 'uid' => $userId];

    if (!empty($phone)) {
        $fields[] = 'phone = :phone';
        $params['phone'] = $phone;
    }

    if ($hasAddressColumns) {
        $fields[] = 'address = :address';
        $params['address'] = !empty($address) ? $address : null;

        $fields[] = 'address_lat = :lat';
        $params['lat'] = $lat;

        $fields[] = 'address_lng = :lng';
        $params['lng'] = $lng;
    }

    $sql = 'UPDATE users SET ' . implode(', ', $fields) . ' WHERE id = :uid';
    $stmt = $pdo->prepare($sql);
    $stmt->execute($params);

    // Ambil data terbaru
    $stmt = $pdo->prepare("SELECT $selectCols FROM users WHERE id = :uid LIMIT 1");
    $stmt->execute(['uid' => $userId]);
    $updated = $stmt->fetch();

    echo json_encode([
        'success' => true,
        'message' => 'Profil berhasil diperbarui',
        'data' => buildProfileData($updated, $hasAddressColumns),
    ]);

} catch (PDOException $e) {
    http_response_code(500);
    echo json_encode(['success' => false, 'message' => 'Terjadi kesalahan server', 'debug' => $e->getMessage()]);
}
