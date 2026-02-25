<?php
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: POST, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type, Authorization");
header("Content-Type: application/json");

// Handle preflight request
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    http_response_code(405);
    echo json_encode(["error" => "Method not allowed"]);
    exit();
}

$input = json_decode(file_get_contents('php://input'), true);
$title = $input['title'] ?? '';
$content = $input['content'] ?? '';

if (empty($content)) {
    http_response_code(400);
    echo json_encode(["error" => "Content is required"]);
    exit();
}

// Batasi panjang konten agar tidak melebihi limit token
$content = mb_substr($content, 0, 3000);

$systemPrompt = [
    "role" => "system",
    "content" => "Anda adalah ALKA AI, asisten cerdas milik sekolah SMALKA. Tugas Anda adalah merangkum artikel berita sekolah dengan ringkas dan informatif dalam Bahasa Indonesia.

Format jawaban Anda HARUS seperti ini:
1. Satu paragraf ringkasan singkat (2-3 kalimat) yang menjelaskan inti artikel.
2. Lalu berikan poin-poin penting dari artikel dengan format bullet (gunakan tanda •).

Aturan:
- Gunakan bahasa yang mudah dipahami orang tua siswa.
- Jangan menambahkan informasi yang tidak ada di artikel.
- Jangan gunakan heading atau markdown formatting selain bullet point (•).
- Langsung tulis ringkasan tanpa kata pembuka seperti 'Berikut ringkasannya' atau sejenisnya.
- Maksimal 5 poin penting."
];

$userMessage = [
    "role" => "user",
    "content" => "Rangkum artikel berita sekolah berikut ini:\n\nJudul: $title\n\nIsi artikel:\n$content"
];

$apiKey = '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';
$groqUrl = 'https://api.groq.com/openai/v1/chat/completions';

$data = [
    "model" => "moonshotai/kimi-k2-instruct",
    "messages" => [$systemPrompt, $userMessage],
    "temperature" => 0.2,
    "max_tokens" => 500,
];

$ch = curl_init($groqUrl);
curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
curl_setopt($ch, CURLOPT_POST, true);
curl_setopt($ch, CURLOPT_POSTFIELDS, json_encode($data));
curl_setopt($ch, CURLOPT_HTTPHEADER, [
    'Content-Type: application/json',
    'Authorization: Bearer ' . $apiKey
]);
curl_setopt($ch, CURLOPT_TIMEOUT, 30);

$response = curl_exec($ch);
$httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
$error = curl_error($ch);
curl_close($ch);

if ($error) {
    http_response_code(500);
    echo json_encode(["error" => "cURL Error: " . $error]);
    exit();
}

// Parse response to extract summary text
$result = json_decode($response, true);

if ($httpCode !== 200 || !isset($result['choices'][0]['message']['content'])) {
    http_response_code($httpCode ?: 500);
    echo json_encode([
        "success" => false,
        "error" => $result['error']['message'] ?? "Gagal merangkum artikel"
    ]);
    exit();
}

$summary = trim($result['choices'][0]['message']['content']);

echo json_encode([
    "success" => true,
    "summary" => $summary,
], JSON_UNESCAPED_UNICODE);
?>
