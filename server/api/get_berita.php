<?php
// /server/api/get_berita.php
// Proxy API: mengambil berita dari website sekolah, parse HTML, return JSON bersih.
// Parameter opsional: ?limit=3 (default tampilkan semua)

// ── CORS Headers ──
header('Content-Type: application/json; charset=utf-8');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(204);
    exit;
}

if ($_SERVER['REQUEST_METHOD'] !== 'GET') {
    http_response_code(405);
    echo json_encode(['success' => false, 'message' => 'Method not allowed']);
    exit;
}

// ── Konfigurasi ──
$baseUrl     = 'https://smamalkautsarpk.sch.id';
$beritaBase  = $baseUrl . '/berita';
$kategori    = '1'; // 1 = Berita
$limit       = isset($_GET['limit']) ? (int) $_GET['limit'] : 0; // 0 = semua

try {
    // ── Step 1: Buat session dengan mengakses halaman berita dulu ──
    $cookieFile = tempnam(sys_get_temp_dir(), 'berita_cookie_');

    $ch = curl_init();
    curl_setopt_array($ch, [
        CURLOPT_URL            => $beritaBase . '/k/' . $kategori . '/berita',
        CURLOPT_RETURNTRANSFER => true,
        CURLOPT_FOLLOWLOCATION => true,
        CURLOPT_TIMEOUT        => 15,
        CURLOPT_COOKIEJAR      => $cookieFile,
        CURLOPT_COOKIEFILE     => $cookieFile,
        CURLOPT_HTTPHEADER     => [
            'User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
            'Accept: text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
        ],
        CURLOPT_SSL_VERIFYPEER => false,
        CURLOPT_SSL_VERIFYHOST => false,
    ]);
    curl_exec($ch);
    curl_close($ch);

    // ── Step 2: Ambil semua halaman berita via AJAX pagination ──
    $allNews  = [];
    $lid      = ''; // Cursor pagination, mulai kosong
    $maxPages = 10; // Safety limit

    for ($page = 1; $page <= $maxPages; $page++) {
        $ajaxUrl = $baseUrl . '/blog/get_blog/' . $kategori . '?l=' . urlencode($lid);

        $ch = curl_init();
        curl_setopt_array($ch, [
            CURLOPT_URL            => $ajaxUrl,
            CURLOPT_RETURNTRANSFER => true,
            CURLOPT_FOLLOWLOCATION => true,
            CURLOPT_TIMEOUT        => 15,
            CURLOPT_COOKIEFILE     => $cookieFile,
            CURLOPT_HTTPHEADER     => [
                'User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
                'X-Requested-With: XMLHttpRequest',
                'Accept: application/json, text/javascript, */*; q=0.01',
            ],
            CURLOPT_SSL_VERIFYPEER => false,
            CURLOPT_SSL_VERIFYHOST => false,
        ]);

        $response = curl_exec($ch);
        $httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
        curl_close($ch);

        if ($httpCode !== 200 || empty($response)) {
            break;
        }

        $json = @json_decode($response, true);
        if (!$json || ($json['code'] ?? '') !== '200') {
            break; // Tidak ada data lagi
        }

        $html = $json['data'] ?? '';
        if (empty($html)) {
            break;
        }

        // Parse HTML fragment menjadi berita
        $pageNews = _parseHtml($html, $baseUrl, $beritaBase);

        if (empty($pageNews)) {
            break;
        }

        $allNews = array_merge($allNews, $pageNews);

        // Update cursor untuk halaman berikutnya
        $lid = $json['lid'] ?? '';
        if (empty($lid)) {
            break;
        }

        // Jika ada limit dan sudah cukup, stop
        if ($limit > 0 && count($allNews) >= $limit) {
            break;
        }
    }

    // Deduplikasi berdasarkan ID
    $seen = [];
    $unique = [];
    foreach ($allNews as $item) {
        if (!in_array($item['id'], $seen)) {
            $seen[] = $item['id'];
            $unique[] = $item;
        }
    }

    // Sort by ID descending (terbaru dulu)
    usort($unique, function ($a, $b) {
        return $b['id'] - $a['id'];
    });

    // Apply limit
    if ($limit > 0) {
        $unique = array_slice($unique, 0, $limit);
    }

    echo json_encode([
        'success' => true,
        'count'   => count($unique),
        'data'    => $unique,
    ], JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES | JSON_PRETTY_PRINT);

    // Hapus cookie temp file
    @unlink($cookieFile);

} catch (Exception $e) {
    // Hapus cookie temp file jika ada error
    if (isset($cookieFile) && file_exists($cookieFile)) {
        @unlink($cookieFile);
    }

    http_response_code(500);
    echo json_encode([
        'success' => false,
        'message' => $e->getMessage(),
    ], JSON_UNESCAPED_UNICODE);
}

// ═══════════════════════════════════════
// Parse HTML menjadi array berita
// ═══════════════════════════════════════

function _parseHtml(string $html, string $baseUrl, string $beritaBase): array {
    libxml_use_internal_errors(true);
    $dom = new DOMDocument();
    $dom->loadHTML('<?xml encoding="utf-8" ?><div>' . $html . '</div>', LIBXML_NOWARNING | LIBXML_NOERROR);
    libxml_clear_errors();

    $xpath       = new DOMXPath($dom);
    $newsList    = [];
    $processedIds = [];

    // Setiap artikel dibungkus <article class="entry">
    $articles = $xpath->query('//article[contains(@class, "entry")]');

    foreach ($articles as $article) {
        // ── URL Detail & ID ──
        $titleLink = $xpath->query('.//h2[contains(@class, "entry-title")]//a', $article);
        if ($titleLink->length === 0) {
            // Fallback: cari link apapun dengan /d/ pattern
            $titleLink = $xpath->query('.//a[contains(@href, "/d/")]', $article);
            if ($titleLink->length === 0) continue;
        }

        $href = $titleLink->item(0)->getAttribute('href');
        if (!preg_match('/\/d\/(\d+)\//', $href, $matches)) continue;

        $id = (int) $matches[1];
        if (in_array($id, $processedIds)) continue;
        $processedIds[] = $id;

        // ── Judul ──
        $title = '';
        $h2 = $xpath->query('.//h2[contains(@class, "entry-title")]', $article);
        if ($h2->length > 0) {
            $title = trim($h2->item(0)->textContent);
        }
        if (empty($title)) {
            $title = trim($titleLink->item(0)->textContent);
        }
        $title = preg_replace('/\s+/', ' ', $title);
        if (strlen($title) < 5) continue;

        // ── URL Detail (absolute) ──
        $detailUrl = $href;
        if (strpos($href, 'http') !== 0) {
            // Relative: ../../d/333/slug => /berita/d/333/slug
            $detailUrl = preg_replace('/^(\.\.\/)+/', '', $href);
            $detailUrl = $beritaBase . '/' . ltrim($detailUrl, '/');
        }

        // ── Gambar ──
        $imageUrl = '';
        $imgs = $xpath->query('.//div[contains(@class, "entry-img")]//img', $article);
        if ($imgs->length === 0) {
            $imgs = $xpath->query('.//img', $article);
        }
        if ($imgs->length > 0) {
            $src = $imgs->item(0)->getAttribute('src');
            if (!empty($src)) {
                $imageUrl = _absoluteUrl($src, $baseUrl);
            }
        }

        // ── Excerpt ──
        $excerpt = '';
        $excerptDiv = $xpath->query('.//div[contains(@class, "entry-content")]', $article);
        if ($excerptDiv->length > 0) {
            $excerpt = trim($excerptDiv->item(0)->textContent);
            $excerpt = preg_replace('/\s+/', ' ', $excerpt);
            // Hapus "Read More" di akhir
            $excerpt = preg_replace('/\s*Read More\s*$/i', '', $excerpt);
            $excerpt = mb_substr($excerpt, 0, 200);
        }

        $newsList[] = [
            'id'         => $id,
            'title'      => $title,
            'image_url'  => $imageUrl,
            'detail_url' => $detailUrl,
            'excerpt'    => $excerpt,
        ];
    }

    return $newsList;
}

function _absoluteUrl(string $url, string $baseUrl): string {
    if (strpos($url, 'http') === 0 || strpos($url, '//') === 0) {
        return $url;
    }
    return $baseUrl . '/' . ltrim($url, '/');
}
