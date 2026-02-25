<?php
// /server/api/update_profile.php
// Endpoint untuk mengupdate profil pengguna (nama, email, phone)
// Method: POST
// Header: Authorization: Bearer <token>
// Body JSON: { "name": "...", "email": "...", "phone": "..." }

header('Content-Type: application/json; charset=utf-8');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization');

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

// Ambil input JSON
$input = json_decode(file_get_contents('php://input'), true);
if (!$input) {
    http_response_code(400);
    echo json_encode(['success' => false, 'message' => 'Request body tidak valid']);
    exit;
}

$name  = trim($input['name']  ?? '');
$email = trim($input['email'] ?? '');
$phone = trim($input['phone'] ?? '');

// Validasi
if (empty($name)) {
    http_response_code(400);
    echo json_encode(['success' => false, 'message' => 'Nama tidak boleh kosong']);
    exit;
}

if (!empty($email) && !filter_var($email, FILTER_VALIDATE_EMAIL)) {
    http_response_code(400);
    echo json_encode(['success' => false, 'message' => 'Format email tidak valid']);
    exit;
}

try {
    // Cek apakah email sudah digunakan oleh user lain
    if (!empty($email)) {
        $stmt = $pdo->prepare(
            'SELECT id FROM users WHERE email = :email AND id != :uid LIMIT 1'
        );
        $stmt->execute(['email' => $email, 'uid' => $userId]);
        if ($stmt->fetch()) {
            http_response_code(409);
            echo json_encode(['success' => false, 'message' => 'Email sudah digunakan akun lain']);
            exit;
        }
    }

    // Cek apakah phone sudah digunakan oleh user lain
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

    // Update data user
    $fields = ['name = :name', 'updated_at = NOW()'];
    $params = ['name' => $name, 'uid' => $userId];

    if (!empty($email)) {
        $fields[] = 'email = :email';
        $params['email'] = $email;
    }

    if (!empty($phone)) {
        $fields[] = 'phone = :phone';
        $params['phone'] = $phone;
    }

    $sql = 'UPDATE users SET ' . implode(', ', $fields) . ' WHERE id = :uid';
    $stmt = $pdo->prepare($sql);
    $stmt->execute($params);

    // Ambil data terbaru
    $stmt = $pdo->prepare(
        'SELECT id, name, email, phone, avatar_url FROM users WHERE id = :uid LIMIT 1'
    );
    $stmt->execute(['uid' => $userId]);
    $updated = $stmt->fetch();

    echo json_encode([
        'success' => true,
        'message' => 'Profil berhasil diperbarui',
        'data'    => [
            'name'       => $updated['name'],
            'email'      => $updated['email'] ?? '',
            'phone'      => $updated['phone'] ?? '',
            'avatar_url' => $updated['avatar_url'] ?? '',
        ],
    ]);

} catch (PDOException $e) {
    http_response_code(500);
    echo json_encode(['success' => false, 'message' => 'Terjadi kesalahan server']);
}
