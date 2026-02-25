<?php
// /server/api/change_password.php
// Endpoint untuk mengubah password pengguna
// Method: POST
// Header: Authorization: Bearer <token>
// Body JSON: { "current_password": "...", "new_password": "..." }

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

$currentPassword = $input['current_password'] ?? '';
$newPassword     = $input['new_password']     ?? '';

// Validasi
if (empty($currentPassword) || empty($newPassword)) {
    http_response_code(400);
    echo json_encode(['success' => false, 'message' => 'Password lama dan password baru wajib diisi']);
    exit;
}

if (strlen($newPassword) < 6) {
    http_response_code(400);
    echo json_encode(['success' => false, 'message' => 'Password baru minimal 6 karakter']);
    exit;
}

if ($currentPassword === $newPassword) {
    http_response_code(400);
    echo json_encode(['success' => false, 'message' => 'Password baru tidak boleh sama dengan password lama']);
    exit;
}

try {
    // Ambil password hash saat ini
    $stmt = $pdo->prepare('SELECT password FROM users WHERE id = :uid LIMIT 1');
    $stmt->execute(['uid' => $userId]);
    $user = $stmt->fetch();

    if (!$user) {
        http_response_code(404);
        echo json_encode(['success' => false, 'message' => 'Akun tidak ditemukan']);
        exit;
    }

    // Verifikasi password lama
    if (!password_verify($currentPassword, $user['password'])) {
        http_response_code(401);
        echo json_encode(['success' => false, 'message' => 'Password lama tidak sesuai']);
        exit;
    }

    // Hash password baru
    $newHash = password_hash($newPassword, PASSWORD_BCRYPT);

    // Update password
    $stmt = $pdo->prepare(
        'UPDATE users SET password = :pwd, updated_at = NOW() WHERE id = :uid'
    );
    $stmt->execute(['pwd' => $newHash, 'uid' => $userId]);

    echo json_encode([
        'success' => true,
        'message' => 'Password berhasil diubah',
    ]);

} catch (PDOException $e) {
    http_response_code(500);
    echo json_encode(['success' => false, 'message' => 'Terjadi kesalahan server']);
}
